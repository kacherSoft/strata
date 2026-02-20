import SwiftUI

// MARK: - Conditional Liquid Glass Modifier
private struct ConditionalLiquidGlassModifier: ViewModifier {
    let apply: Bool
    let style: LiquidGlassStyle

    func body(content: Content) -> some View {
        if apply {
            content.modifier(LiquidGlassModifier(style: style))
        } else {
            content
        }
    }
}

// MARK: - Priority Picker Component
public struct PriorityPicker: View {
    @Binding var selectedPriority: TaskItem.Priority
    @Namespace private var animation

    public init(selectedPriority: Binding<TaskItem.Priority>) {
        self._selectedPriority = selectedPriority
    }

    public var body: some View {
        HStack(spacing: 12) {
            PriorityOption(
                label: "High",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                isSelected: selectedPriority == .high
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPriority = .high
                }
            }

            PriorityOption(
                label: "Medium",
                icon: "minus.circle.fill",
                color: .orange,
                isSelected: selectedPriority == .medium
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPriority = .medium
                }
            }

            PriorityOption(
                label: "Low",
                icon: "arrow.down.circle.fill",
                color: .blue,
                isSelected: selectedPriority == .low
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPriority = .low
                }
            }

            PriorityOption(
                label: "None",
                icon: "circle",
                color: .secondary,
                isSelected: selectedPriority == .none
            ) {
                withAnimation(.spring(response: 0.3)) {
                    selectedPriority = .none
                }
            }

            Spacer()
        }
    }
}

// MARK: - Priority Option Component
struct PriorityOption: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? color : .secondary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 56)
            .background {
                if isSelected {
                    color.opacity(0.15)
                } else {
                    Color.clear
                }
            }
            .modifier(ConditionalLiquidGlassModifier(apply: !isSelected, style: .searchBar))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(color, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
