import SwiftUI
import TaskManagerUIComponents

struct QuickEntryWrapper: View {
    var onDismiss: () -> Void
    var onCreate: (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL], Bool, TaskManagerUIComponents.RecurrenceRule, Int, Decimal?, String?, Double?) -> Void
    var onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    var onDeletePhoto: ((URL) -> Void)?
    
    var body: some View {
        QuickEntryContent(
            onCancel: onDismiss,
            onCreate: { title, notes, dueDate, hasReminder, duration, priority, tags, photos, isRecurring, recurrenceRule, recurrenceInterval, budget, client, effort in
                onCreate(title, notes, dueDate, hasReminder, duration, priority, tags, photos, isRecurring, recurrenceRule, recurrenceInterval, budget, client, effort)
                onDismiss()
            },
            onPickPhotos: onPickPhotos,
            onDeletePhoto: onDeletePhoto
        )
    }
}
