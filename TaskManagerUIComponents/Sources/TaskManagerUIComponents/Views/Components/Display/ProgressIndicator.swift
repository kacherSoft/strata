import SwiftUI

// MARK: - Progress Indicator Component
public struct ProgressIndicator: View {
    let current: Int
    let total: Int
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Progress")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(current)/\(total)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.blue)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .liquidGlass(.settingsCard)
    }
}
