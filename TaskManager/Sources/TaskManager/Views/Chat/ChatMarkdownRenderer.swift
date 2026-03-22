import SwiftUI

/// Lightweight markdown renderer using AttributedString.
/// Handles code blocks with monospaced font; delegates inline markdown to AttributedString(markdown:).
struct ChatMarkdownRenderer: View {
    let text: String

    var body: some View {
        if let attributed = parseMarkdown(text) {
            Text(attributed)
                .font(.system(size: 14))
                .textSelection(.enabled)
        } else {
            Text(text)
                .font(.system(size: 14))
                .textSelection(.enabled)
        }
    }

    private func parseMarkdown(_ input: String) -> AttributedString? {
        let parts = splitCodeBlocks(input)
        var result = AttributedString()

        for part in parts {
            if part.isCodeBlock {
                var code = AttributedString(part.content)
                code.font = .system(size: 13, design: .monospaced)
                // Dark code block background (#111827)
                code.backgroundColor = Color(red: 0.067, green: 0.094, blue: 0.153)
                result += AttributedString("\n")
                result += code
                result += AttributedString("\n")
            } else {
                if let md = try? AttributedString(
                    markdown: part.content,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) {
                    result += md
                } else {
                    result += AttributedString(part.content)
                }
            }
        }
        return result
    }

    private struct TextPart {
        let content: String
        let isCodeBlock: Bool
    }

    /// Splits text on ``` delimiters; odd-index segments are code blocks.
    private func splitCodeBlocks(_ text: String) -> [TextPart] {
        var parts: [TextPart] = []
        let components = text.components(separatedBy: "```")
        for (index, component) in components.enumerated() {
            let isCode = index % 2 == 1
            let content: String
            if isCode {
                // Strip optional language tag line (e.g., "swift\n...")
                let trimmed = component.drop(while: { !$0.isNewline })
                content = String(trimmed.dropFirst())
            } else {
                content = component
            }
            guard !content.isEmpty else { continue }
            parts.append(TextPart(content: content, isCodeBlock: isCode))
        }
        return parts
    }
}
