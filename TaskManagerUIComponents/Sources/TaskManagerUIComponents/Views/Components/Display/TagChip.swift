import SwiftUI

// MARK: - Tag Chip Component
public struct TagChip: View {
    let text: String

    public init(text: String) {
        self.text = text
    }

    // Generate consistent pastel color based on tag text
    private var tagColor: Color {
        let hash = text.hashValue
        let colors: [Color] = [
            Color(red: 0.5, green: 0.7, blue: 0.9),  // Pastel blue
            Color(red: 0.7, green: 0.5, blue: 0.9),  // Pastel purple
            Color(red: 0.5, green: 0.9, blue: 0.7),  // Pastel green
            Color(red: 0.9, green: 0.7, blue: 0.5),  // Pastel orange
            Color(red: 0.9, green: 0.5, blue: 0.7),  // Pastel pink
            Color(red: 0.5, green: 0.9, blue: 0.9),  // Pastel cyan
        ]
        return colors[abs(hash) % colors.count]
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tagColor.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
