import SwiftUI

// MARK: - Tag Cloud Component
public struct TagCloud: View {
    let tags: [String]

    public init(tags: [String]) {
        self.tags = tags
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(text: tag)
                }
            }
        }
    }
}
