import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    private var prefersUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        guard prefersUserNotifications else {
            return true
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    func sendRefreshNotification(for key: UsageWindowKey) async {
        let title = "\(key.provider.rawValue) \(key.kind.rawValue) refreshed"
        let body = "A new \(key.kind.rawValue) usage period is available."

        if prefersUserNotifications {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "refresh-\(key.storageKey)-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )

            try? await UNUserNotificationCenter.current().add(request)
            return
        }

        let script = """
        display notification "\(escape(body))" with title "\(escape(title))"
        """

        _ = try? await ProcessRunner.run(
            executable: "osascript",
            arguments: ["-e", script],
            timeout: 5
        )
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
