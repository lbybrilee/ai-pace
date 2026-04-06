import Foundation
import AppKit
import Security
import UserNotifications

@MainActor
protocol NotificationManaging: AnyObject {
    func requestAuthorizationIfNeeded() async -> Bool
    func sendRefreshNotification(for key: UsageWindowKey, sound: NotificationSoundOption) async
    func preview(sound: NotificationSoundOption)
}

@MainActor
final class NotificationManager: NotificationManaging {
    private var prefersUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.bundleIdentifier != nil
            && hasUsableCodeSignature
    }

    private var hasUsableCodeSignature: Bool {
        var staticCode: SecStaticCode?
        let creationStatus = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &staticCode)
        guard creationStatus == errSecSuccess, let staticCode else {
            return false
        }

        let validationStatus = SecStaticCodeCheckValidity(staticCode, [], nil)
        return validationStatus == errSecSuccess
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

    func sendRefreshNotification(for key: UsageWindowKey, sound: NotificationSoundOption) async {
        let title = "\(key.provider.rawValue) \(key.kind.rawValue) refreshed"
        let body = "A new \(key.kind.rawValue) usage period is available."

        if prefersUserNotifications {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = sound == .silent || sound.soundName != nil ? nil : .default

            let request = UNNotificationRequest(
                identifier: "refresh-\(key.storageKey)-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )

            try? await UNUserNotificationCenter.current().add(request)
            playLocalSoundIfNeeded(sound)
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
        playLocalSoundIfNeeded(sound)
    }

    func preview(sound: NotificationSoundOption) {
        switch sound {
        case .systemDefault:
            NSSound.beep()
        case .silent:
            return
        default:
            playLocalSoundIfNeeded(sound)
        }
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func playLocalSoundIfNeeded(_ sound: NotificationSoundOption) {
        switch sound {
        case .silent, .systemDefault:
            return
        default:
            guard let name = sound.soundName else {
                return
            }
            NSSound(named: NSSound.Name(name))?.play()
        }
    }
}
