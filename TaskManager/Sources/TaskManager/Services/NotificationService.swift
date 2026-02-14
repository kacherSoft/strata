import AppKit
import UserNotifications

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    
    // Category identifiers
    private static let taskReminderCategory = "TASK_REMINDER"
    
    // Action identifiers
    private static let completeAction = "COMPLETE_ACTION"
    private static let snoozeAction = "SNOOZE_ACTION"
    
    // Available reminder sounds
    static let availableSounds: [(name: String, id: String)] = [
        ("Default", "default"),
        ("Tri-tone", "tri-tone"),
        ("Chime", "chime"),
        ("Glass", "glass"),
        ("Ping", "ping"),
    ]
    
    private override init() {
        super.init()
        setupCategories()
        center.delegate = self
    }
    
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    private func setupCategories() {
        let completeAction = UNNotificationAction(
            identifier: Self.completeAction,
            title: "Complete",
            options: .foreground
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: "Snooze 15 min",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: Self.taskReminderCategory,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: []
        )
        
        center.setNotificationCategories([category])
    }
    
    private func notificationSound(for soundId: String) -> UNNotificationSound {
        switch soundId {
        case "tri-tone":
            return UNNotificationSound(named: UNNotificationSoundName("Tri-tone.aiff"))
        case "chime":
            return UNNotificationSound(named: UNNotificationSoundName("Chime.aiff"))
        case "glass":
            return UNNotificationSound(named: UNNotificationSoundName("Glass.aiff"))
        case "ping":
            return UNNotificationSound(named: UNNotificationSoundName("Ping.aiff"))
        default:
            return .default
        }
    }
    
    func scheduleReminder(for taskId: UUID, title: String, dueDate: Date, soundId: String = "default") {
        center.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = title
        content.sound = notificationSound(for: soundId)
        content.categoryIdentifier = Self.taskReminderCategory
        content.userInfo = ["taskId": taskId.uuidString]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: taskId.uuidString,
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    func scheduleTimerReminder(for taskId: UUID, title: String, duration: TimeInterval, soundId: String = "default") {
        let reminderId = "reminder-\(taskId.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [reminderId])
        
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = title
        content.sound = notificationSound(for: soundId)
        content.categoryIdentifier = Self.taskReminderCategory
        content.userInfo = ["taskId": taskId.uuidString]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, duration),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: reminderId,
            content: content,
            trigger: trigger
        )
        
        center.add(request)
    }
    
    func previewSound(for soundId: String) {
        let soundName: String? = switch soundId {
        case "tri-tone": "Tink"
        case "chime": "Blow"
        case "glass": "Glass"
        case "ping": "Ping"
        default: nil
        }
        if let soundName, let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
    
    func cancelReminder(for taskId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            taskId.uuidString,
            "reminder-\(taskId.uuidString)"
        ])
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let taskIdString = userInfo["taskId"] as? String else {
            completionHandler()
            return
        }
        
        let actionId = response.actionIdentifier
        let taskTitle = response.notification.request.content.body
        
        Task { @MainActor in
            switch actionId {
            case NotificationService.completeAction:
                NotificationCenter.default.post(
                    name: .taskCompletedFromNotification,
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
            case NotificationService.snoozeAction:
                if let taskId = UUID(uuidString: taskIdString) {
                    let snoozeDate = Date().addingTimeInterval(15 * 60)
                    NotificationService.shared.scheduleReminder(
                        for: taskId,
                        title: taskTitle,
                        dueDate: snoozeDate
                    )
                }
            default:
                break
            }
        }
        completionHandler()
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let taskCompletedFromNotification = Notification.Name("taskCompletedFromNotification")
}
