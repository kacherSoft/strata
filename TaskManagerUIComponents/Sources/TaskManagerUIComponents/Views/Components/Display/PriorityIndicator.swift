import SwiftUI

// MARK: - Priority Indicator Component
public struct PriorityIndicator: View {
    let priority: TaskItem.Priority

    public init(priority: TaskItem.Priority) {
        self.priority = priority
    }

    public var body: some View {
        if priority != .none {
            Image(systemName: "flag.fill")
                .font(.system(size: 11))
                .foregroundStyle(priorityColor(priority))
        }
    }

    private func priorityColor(_ priority: TaskItem.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .clear
        }
    }
}
