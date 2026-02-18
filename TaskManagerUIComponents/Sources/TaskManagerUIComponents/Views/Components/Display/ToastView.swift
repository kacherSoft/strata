import SwiftUI

public enum ToastStyle {
    case info
    case success
    case warning
    case error

    var iconName: String {
        switch self {
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .info: .blue
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .info: .blue.opacity(0.16)
        case .success: .green.opacity(0.16)
        case .warning: .orange.opacity(0.16)
        case .error: .red.opacity(0.2)
        }
    }

    var borderColor: Color {
        switch self {
        case .info: .blue.opacity(0.35)
        case .success: .green.opacity(0.35)
        case .warning: .orange.opacity(0.35)
        case .error: .red.opacity(0.45)
        }
    }
}

public struct ToastView: View {
    let message: String
    let style: ToastStyle

    public init(message: String, style: ToastStyle = .info) {
        self.message = message
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.iconName)
                .font(.caption)
                .foregroundStyle(style.foregroundColor)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(style.backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(style.borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }
}
