import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let logger: AppLogger

    init(logger: AppLogger) {
        self.logger = logger
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { [logger] granted, error in
            if let error {
                logger.write("Notification authorization failed: \(error.localizedDescription)")
            } else {
                logger.write("Notification authorization granted: \(granted)")
            }
        }
    }

    func notify(_ message: NotificationMessage) async {
        do {
            try await notifyWithUserNotifications(message)
        } catch {
            logger.write("UserNotifications delivery failed: \(error.localizedDescription)")
            notifyWithAppleScript(message)
        }
    }

    private func notifyWithUserNotifications(_ message: NotificationMessage) async throws {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.subtitle = message.subtitle
        content.body = message.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "ruok-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func notifyWithAppleScript(_ message: NotificationMessage) {
        let script = """
        on run argv
          display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)
        end run
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script, message.title, message.subtitle, message.body]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                logger.write("AppleScript notification fallback exited \(process.terminationStatus)")
            }
        } catch {
            logger.write("AppleScript notification fallback failed: \(error.localizedDescription)")
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
