import SwiftUI

// MARK: - Tag Cloud Component
public struct TagCloud: View {
    let tags: [String]
    let onRemove: ((String) -> Void)?

    public init(tags: [String]) {
        self.tags = tags
        self.onRemove = nil
    }
    
    public init(tags: [String], onRemove: @escaping (String) -> Void) {
        self.tags = tags
        self.onRemove = onRemove
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    if let onRemove {
                        TagChip(text: tag, showRemove: true) {
                            onRemove(tag)
                        }
                    } else {
                        TagChip(text: tag)
                    }
                }
            }
        }
    }
}
