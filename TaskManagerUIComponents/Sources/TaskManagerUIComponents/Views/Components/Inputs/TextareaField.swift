import SwiftUI

// MARK: - Textarea Field Component
public struct TextareaField: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat

    public init(text: Binding<String>, placeholder: String = "Enter text...", height: CGFloat = 80) {
        self._text = text
        self.placeholder = placeholder
        self.height = height
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .background(.clear)
                .frame(height: height)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .liquidGlass(.searchBar)
    }
}
