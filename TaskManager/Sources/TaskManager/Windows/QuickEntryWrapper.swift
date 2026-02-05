import SwiftUI
import TaskManagerUIComponents

struct QuickEntryWrapper: View {
    @State private var isPresented = true
    
    var onDismiss: () -> Void
    var onCreate: (String, String, Date?, Bool, TaskItem.Priority, [String]) -> Void
    
    var body: some View {
        Color.clear
            .frame(width: 500, height: 450)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                NewTaskSheet(isPresented: $isPresented, onCreate: onCreate)
            }
            .onChange(of: isPresented) { _, newValue in
                if !newValue {
                    onDismiss()
                }
            }
    }
}
