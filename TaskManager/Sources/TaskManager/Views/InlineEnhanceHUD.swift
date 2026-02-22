import SwiftUI

struct InlineEnhanceHUD: View {
    let modeName: String
    let state: HUDState
    
    enum HUDState: Equatable {
        case enhancing
        case success
        case error(String)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            stateIcon
            stateText
        }
        .font(.system(.body, weight: .medium))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .fixedSize()
    }
    
    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .enhancing:
            ProgressView()
                .controlSize(.small)
                .scaleEffect(1.1)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16, weight: .semibold))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16, weight: .semibold))
        }
    }
    
    @ViewBuilder
    private var stateText: some View {
        switch state {
        case .enhancing:
            Text("Enhancing with \"\(modeName)\"…")
                .foregroundStyle(.primary)
        case .success:
            Text("Enhanced ✓")
                .foregroundStyle(.primary)
        case .error(let message):
            Text(message)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
}
