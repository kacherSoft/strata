import SwiftUI
import TaskManagerUIComponents

struct QuickEntryWrapper: View {
    var onDismiss: () -> Void
    var onCreate: (String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void
    
    var body: some View {
        QuickEntryContent(
            onCancel: onDismiss,
            onCreate: { title, notes, dueDate, hasReminder, priority, tags in
                onCreate(title, notes, dueDate, hasReminder, priority, tags)
                onDismiss()
            }
        )
    }
}
