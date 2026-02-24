import SwiftUI

// MARK: - HUD View Model

@MainActor
@Observable
final class HUDViewModel {
    var modeName: String = ""
    var state: InlineEnhanceHUD.HUDState = .enhancing
    
    // Animated dots: cycles through "" → "." → ".." → "..."
    var dotCount: Int = 0
    private var dotTask: Task<Void, Never>?
    
    func startDots() {
        dotTask?.cancel()
        dotCount = 0
        dotTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { break }
                self.dotCount = (self.dotCount + 1) % 4
            }
        }
    }
    
    func stopDots() {
        dotTask?.cancel()
        dotTask = nil
    }
}

// MARK: - Color Theme
private struct Theme {
    // Glassmorphism base
    static let glassTint = Color(red: 0.05, green: 0.1, blue: 0.02).opacity(0.4)
    static let glassEdge = Color(white: 1.0).opacity(0.2)
    
    // Lime to Neon Green gradient matching the reference image, made brighter
    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.85, green: 1.0, blue: 0.0),  // Brighter Lime Yellow
            Color(red: 0.2, green: 1.0, blue: 0.2)    // Brighter Neon Green
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // The strong neon glow emitted by the bright text
    static let glowColor = Color(red: 0.5, green: 1.0, blue: 0.0).opacity(1.0)
    
    static let dimPrimary = Color.white.opacity(0.15) // Darker mid-grey for resting text contrast
}

// MARK: - Main HUD View

struct InlineEnhanceHUD: View {
    @Bindable var viewModel: HUDViewModel
    
    enum HUDState: Equatable {
        case enhancing
        case success
        case error(String)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            stateIcon
            stateText
        }
        .font(.system(size: 13, weight: .medium, design: .monospaced).italic())
        .modifier(ShimmerMask(active: viewModel.state == .enhancing))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.glassTint)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.glassEdge, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        .environment(\.colorScheme, .dark)
        .fixedSize()
        .onChange(of: viewModel.state) { _, newValue in
            if newValue == .enhancing {
                viewModel.startDots()
            } else {
                viewModel.stopDots()
            }
        }
        .onAppear {
            if viewModel.state == .enhancing {
                viewModel.startDots()
            }
        }
    }
    
    // MARK: - Icon
    
    @ViewBuilder
    private var stateIcon: some View {
        switch viewModel.state {
        case .enhancing:
            StrataIcon()
                .frame(width: 16, height: 16)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
        }
    }
    
    // MARK: - Text
    
    @ViewBuilder
    private var stateText: some View {
        switch viewModel.state {
        case .enhancing:
            let dots = String(repeating: ".", count: viewModel.dotCount)
            Text("Enhancing with \"\(viewModel.modeName)\"\(dots)")
        case .success:
            Text("Enhanced ✓")
        case .error(let message):
            Text(message)
                .lineLimit(2)
        }
    }
}

// MARK: - Strata Icon (Cybertech Style)

/// Exact geometric S logo matching the Strata brand reference
private struct StrataIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        // Proportions based on reference image
        let T: CGFloat = h * 0.28        // Thickness of top/bottom bars
        let C: CGFloat = h * 0.22        // Size of outer chamfers (top-left, bottom-right)
        let Sw: CGFloat = w * 0.38       // Horizontal width of the diagonal spine
        let shift: CGFloat = w * 0.28    // Horizontal shift of the spine from top to bottom
        
        // Spine X coordinates
        let midTopX_Left = (w - shift - Sw) / 2
        let midTopX_Right = midTopX_Left + Sw
        let midBotX_Left = midTopX_Left + shift
        let midBotX_Right = midBotX_Left + Sw
        
        var path = Path()
        // Start below top-left chamfer
        path.move(to: CGPoint(x: 0, y: C))
        // Top-left chamfer
        path.addLine(to: CGPoint(x: C, y: 0))
        // Top edge
        path.addLine(to: CGPoint(x: w, y: 0))
        // Right edge (top bar endcap)
        path.addLine(to: CGPoint(x: w, y: T))
        // Inner top-right notch (top edge)
        path.addLine(to: CGPoint(x: midTopX_Right, y: T))
        // Inner spine (right edge)
        path.addLine(to: CGPoint(x: midBotX_Right, y: h - T))
        // Inner bottom-right notch (bottom edge)
        path.addLine(to: CGPoint(x: w, y: h - T))
        // Right edge, above bottom-right chamfer
        path.addLine(to: CGPoint(x: w, y: h - C))
        // Bottom-right chamfer
        path.addLine(to: CGPoint(x: w - C, y: h))
        // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: h))
        // Left edge (bottom bar endcap)
        path.addLine(to: CGPoint(x: 0, y: h - T))
        // Inner bottom-left notch (bottom edge)
        path.addLine(to: CGPoint(x: midBotX_Left, y: h - T))
        // Inner spine (left edge)
        path.addLine(to: CGPoint(x: midTopX_Left, y: T))
        // Inner top-left notch (top edge)
        path.addLine(to: CGPoint(x: 0, y: T))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Shimmer Mask Modifier

/// Replicates the CSS `-webkit-mask-image` shimmer effect:
/// Content is dimmed to ~15% opacity, with a bright band sweeping left → right.
/// Uses TimelineView for reliable continuous animation.
private struct ShimmerMask: ViewModifier {
    let active: Bool
    
    @State private var startTime: Date = Date()
    
    /// How wide the bright band is, as a fraction of total width (0.0–1.0)
    private let bandWidth: Double = 0.20
    /// Duration of one full sweep cycle in seconds
    private let cycleDuration: Double = 2.0
    /// Base opacity when not highlighted
    private let dimOpacity: Double = 0.35
    
    func body(content: Content) -> some View {
        Group {
            if active {
                TimelineView(.animation) { timeline in
                    // Start exactly at 0.0 duration relative to the activation time
                    let time = timeline.date.timeIntervalSince(startTime)
                    let totalRange = 1.0 + bandWidth * 2
                    let cycle = (time / cycleDuration).truncatingRemainder(dividingBy: 1.0)
                    let bandCenter = -bandWidth + cycle * totalRange
                    
                    // Compute stop locations — all clamped to [0, 1], cascade ensures non-decreasing
                    let half = bandWidth / 2
                    let p1 = clamp(bandCenter - half)
                    let p2 = max(p1, clamp(bandCenter))
                    let p3 = max(p2, clamp(bandCenter + half))
                    
                    // 1. Draw the base view uniformly dimmed
                    content
                        .foregroundStyle(Theme.dimPrimary)
                        // 2. Overlay an exact copy at full brightness, but mask it to only show the sweeping band
                        .overlay(
                            content
                                .foregroundStyle(Theme.primaryGradient)
                                .shadow(color: Theme.glowColor, radius: 4, x: 0, y: 0) // Neon glow effect
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .clear, location: 0.0),
                                            .init(color: .clear, location: p1),
                                            .init(color: .white, location: p2),
                                            .init(color: .clear, location: p3),
                                            .init(color: .clear, location: 1.0),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            } else {
                content
                    .foregroundStyle(Theme.primaryGradient)
                    .shadow(color: Theme.glowColor, radius: 4, x: 0, y: 0)
            }
        }
        .onChange(of: active) { _, isActive in
            if isActive {
                startTime = Date()
            }
        }
        .onAppear {
            if active {
                startTime = Date()
            }
        }
    }
    
    private func clamp(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}

