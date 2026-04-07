import AppKit
import Foundation
@preconcurrency import WebKit

@MainActor
final class GitHubCopilotWebSession {
    static let featuresURL = URL(string: "https://github.com/settings/copilot/features")!

    var onUsageDetected: (@MainActor () -> Void)?

    private let fetchOverride: (@MainActor () async -> CopilotSnapshot)?
    private let openLoginOverride: (@MainActor () -> Void)?
    private var loginWindowController: GitHubCopilotLoginWindowController?

    init(
        fetchOverride: (@MainActor () async -> CopilotSnapshot)? = nil,
        openLoginOverride: (@MainActor () -> Void)? = nil
    ) {
        self.fetchOverride = fetchOverride
        self.openLoginOverride = openLoginOverride
    }

    func fetchUsage() async -> CopilotSnapshot {
        if let fetchOverride {
            return await fetchOverride()
        }

        do {
            let webView = makeWebView()
            try await load(Self.featuresURL, in: webView)
            return try await extractSnapshot(from: webView)
        } catch {
            return CopilotSnapshot(
                primary: CopilotUsageWindow(kind: .premiumRequests, valueText: nil, progressPercent: nil, resetsAt: nil, message: error.localizedDescription),
                secondary: nil,
                detail: nil,
                footer: nil
            )
        }
    }

    func openLoginWindow() {
        if let openLoginOverride {
            openLoginOverride()
            return
        }

        if let loginWindowController {
            loginWindowController.show()
            return
        }

        let controller = GitHubCopilotLoginWindowController(session: self)
        loginWindowController = controller
        controller.show()
    }

    func loginWindowDidClose(_ controller: GitHubCopilotLoginWindowController) {
        if loginWindowController === controller {
            loginWindowController = nil
        }
    }

    func loginWindowDidFinishLoading(_ webView: WKWebView, controller: GitHubCopilotLoginWindowController) async {
        do {
            _ = try await extractSnapshot(from: webView)
            onUsageDetected?()
            controller.close()
        } catch {
            // Keep the window open until the page reaches an authenticated Copilot usage view.
        }
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return WKWebView(frame: .zero, configuration: configuration)
    }

    private func load(_ url: URL, in webView: WKWebView) async throws {
        let delegate = NavigationDelegate()
        webView.navigationDelegate = delegate
        _ = webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        try await delegate.waitForCompletion()
        webView.navigationDelegate = nil
    }

    private func extractSnapshot(from webView: WKWebView) async throws -> CopilotSnapshot {
        let script = """
        (() => {
          const loginRequired = Boolean(
            document.querySelector('#login_field') ||
            document.querySelector('input[name="login"]') ||
            document.querySelector('form[action*="/session"]')
          );

          const row = [...document.querySelectorAll('li.Box-row')].find((node) => node.innerText.includes('Premium requests'));
          const managed = [...document.querySelectorAll('body *')]
            .map((node) => (node.innerText || '').trim())
            .find((text) => text.startsWith('Managed by ')) || null;

          if (!row) {
            return JSON.stringify({
              loginRequired,
              found: false,
              title: document.title,
              url: location.href,
            });
          }

          const text = row.innerText || '';
          const percentageMatch = text.match(/(\\d+(?:\\.\\d+)?)%/);
          const note = text.includes('Please note')
            ? text.slice(text.indexOf('Please note')).replace(/\\s+/g, ' ').trim()
            : null;

          return JSON.stringify({
            loginRequired,
            found: true,
            percentageText: percentageMatch ? `${percentageMatch[1]}%` : null,
            percentageValue: percentageMatch ? Number(percentageMatch[1]) : null,
            managedBy: managed,
            note,
          });
        })()
        """

        guard let raw = try await webView.evaluateJavaScript(script) as? String,
              let data = raw.data(using: .utf8) else {
            throw ProcessRunnerError.invalidResponse("GitHub Copilot page returned an unreadable result.")
        }

        let payload = try JSONDecoder().decode(GitHubCopilotPagePayload.self, from: data)
        if payload.found, let percentageText = payload.percentageText {
            return CopilotSnapshot(
                primary: CopilotUsageWindow(
                    kind: .premiumRequests,
                    valueText: percentageText,
                    progressPercent: payload.percentageValue,
                    resetsAt: nil,
                    message: nil
                ),
                secondary: nil,
                detail: payload.managedBy,
                footer: payload.note
            )
        }

        if payload.loginRequired {
            throw ProcessRunnerError.invalidResponse("GitHub sign in required.")
        }

        throw ProcessRunnerError.invalidResponse("GitHub Copilot usage was not found on the page.")
    }
}

private final class NavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var completionResult: Result<Void, Error>?

    func waitForCompletion() async throws {
        if let completionResult {
            return try completionResult.get()
        }

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        resolve(with: .success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resolve(with: .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        resolve(with: .failure(error))
    }

    private func resolve(with result: Result<Void, Error>) {
        completionResult = result
        switch result {
        case .success:
            continuation?.resume()
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

private struct GitHubCopilotPagePayload: Decodable {
    let loginRequired: Bool
    let found: Bool
    let percentageText: String?
    let percentageValue: Double?
    let managedBy: String?
    let note: String?
}

@MainActor
final class GitHubCopilotLoginWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate {
    private let session: GitHubCopilotWebSession
    private let webView: WKWebView

    init(session: GitHubCopilotWebSession) {
        self.session = session

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Connect GitHub Copilot"
        window.contentView = webView
        window.center()
        window.minSize = NSSize(width: 800, height: 640)

        super.init(window: window)

        webView.navigationDelegate = self
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if webView.url == nil {
            webView.load(URLRequest(url: GitHubCopilotWebSession.featuresURL))
        }
    }

    func windowWillClose(_ notification: Notification) {
        session.loginWindowDidClose(self)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await session.loginWindowDidFinishLoading(webView, controller: self)
        }
    }
}
