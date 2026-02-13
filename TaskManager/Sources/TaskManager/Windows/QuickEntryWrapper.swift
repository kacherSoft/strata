import SwiftUI
import TaskManagerUIComponents

struct QuickEntryWrapper: View {
    var onDismiss: () -> Void
    var onCreate: (String, String, Date?, Bool, TimeInterval, TaskItem.Priority, [String], [URL]) -> Void
    var onPickPhotos: ((@escaping ([URL]) -> Void) -> Void)?
    var onDeletePhoto: ((URL) -> Void)?
    
    var body: some View {
        QuickEntryContent(
            onCancel: onDismiss,
            onCreate: { title, notes, dueDate, hasReminder, duration, priority, tags, photos in
                onCreate(title, notes, dueDate, hasReminder, duration, priority, tags, photos)
                onDismiss()
            },
            onPickPhotos: onPickPhotos,
            onDeletePhoto: onDeletePhoto
        )
    }
}
