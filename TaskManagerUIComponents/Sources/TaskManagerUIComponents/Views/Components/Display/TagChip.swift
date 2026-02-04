import SwiftUI

// MARK: - Tag Chip Component
public struct TagChip: View {
    let text: String
    let showRemove: Bool
    let onRemove: (() -> Void)?

    public init(text: String) {
        self.text = text
        self.showRemove = false
        self.onRemove = nil
    }
    
    public init(text: String, showRemove: Bool, onRemove: @escaping () -> Void) {
        self.text = text
        self.showRemove = showRemove
        self.onRemove = onRemove
    }

    private var tagColor: Color {
        let hash = text.hashValue
        let colors: [Color] = [
            Color(red: 0.5, green: 0.7, blue: 0.9),
            Color(red: 0.7, green: 0.5, blue: 0.9),
            Color(red: 0.5, green: 0.9, blue: 0.7),
            Color(red: 0.9, green: 0.7, blue: 0.5),
            Color(red: 0.9, green: 0.5, blue: 0.7),
            Color(red: 0.5, green: 0.9, blue: 0.9),
        ]
        return colors[abs(hash) % colors.count]
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.primary)
            
            if showRemove {
                Button(action: { onRemove?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tagColor.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
