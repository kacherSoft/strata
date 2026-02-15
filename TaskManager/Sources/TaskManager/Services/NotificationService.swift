import AppKit
import UserNotifications

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private let center: UNUserNotificationCenter?
    private var alarmSound: NSSound?
    private(set) var alarmingTaskId: UUID?
    
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
        // UNUserNotificationCenter requires a bundle identifier; guard against its absence
        if Bundle.main.bundleIdentifier != nil {
            self.center = UNUserNotificationCenter.current()
        } else {
            self.center = nil
        }
        super.init()
        if let center {
            setupCategories()
            center.delegate = self
        }
    }
    
    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    private func setupCategories() {
        guard let center else { return }
        let completeAction = UNNotificationAction(
            identifier: Self.completeAction,
            title: "Complete",
            options: .foreground
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: "Dismiss",
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
        guard let center else { return }
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
        guard let center else { return }
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
    
    static func previewSound(for soundId: String) {
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
        guard let center else { return }
        center.removePendingNotificationRequests(withIdentifiers: [
            taskId.uuidString,
            "reminder-\(taskId.uuidString)"
        ])
    }
    
    func startAlarm(soundId: String) {
        stopAlarm()
        let soundName: String? = switch soundId {
        case "tri-tone": "Tink"
        case "chime": "Blow"
        case "glass": "Glass"
        case "ping": "Ping"
        default: nil
        }
        if let soundName, let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.loops = true
            sound.play()
            alarmSound = sound
        } else {
            // Use system beep as fallback — play on a timer for looping
            if let sound = NSSound(named: NSSound.Name("Ping")) {
                sound.loops = true
                sound.play()
                alarmSound = sound
            }
        }
    }

    func startAlarm(for taskId: UUID, soundId: String) {
        alarmingTaskId = taskId
        startAlarm(soundId: soundId)
    }

    func stopAlarm() {
        alarmSound?.stop()
        alarmSound = nil
        alarmingTaskId = nil
    }

    var isAlarmPlaying: Bool {
        alarmSound?.isPlaying ?? false
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
        Task { @MainActor in
            switch actionId {
            case NotificationService.completeAction:
                NotificationCenter.default.post(
                    name: .taskCompletedFromNotification,
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
            case NotificationService.snoozeAction:
                NotificationCenter.default.post(
                    name: .reminderDismissedFromNotification,
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
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
        let userInfo = notification.request.content.userInfo
        if let taskIdString = userInfo["taskId"] as? String {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .reminderAlarmFired,
                    object: nil,
                    userInfo: ["taskId": taskIdString]
                )
            }
        }
        // Don't play the notification sound — we'll play our own looping alarm
        completionHandler([.banner])
    }
}

extension Notification.Name {
    static let taskCompletedFromNotification = Notification.Name("taskCompletedFromNotification")
    static let reminderAlarmFired = Notification.Name("reminderAlarmFired")
    static let reminderDismissedFromNotification = Notification.Name("reminderDismissedFromNotification")
}
