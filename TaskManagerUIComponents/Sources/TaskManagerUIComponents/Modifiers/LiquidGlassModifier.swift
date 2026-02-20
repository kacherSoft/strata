import SwiftUI

// MARK: - Liquid Glass Style Configuration

/// Configuration for liquid glass appearance
public struct LiquidGlassStyle: Sendable {
    /// Material thickness
    public enum Thickness: Sendable {
        case ultraThin   // Subtle, for badges/chips
        case thin        // Cards, rows
        case regular     // Prominent elements (FAB)
    }

    /// Glass intensity variant
    public enum Variant: Sendable {
        case `default`   // Standard glass
        case elevated    // More prominent (selected state)
        case subtle      // Less prominent (secondary elements)
    }

    public let thickness: Thickness
    public let variant: Variant
    public let cornerRadius: CGFloat
    public let shape: AnyShape

    /// OS 26+ specific tint color
    public let tint: Color?

    /// OS 26+ interactive mode
    public let interactive: Bool

    // MARK: - Init

    public init(
        thickness: Thickness,
        variant: Variant = .default,
        cornerRadius: CGFloat = 12,
        tint: Color? = nil,
        interactive: Bool = false
    ) {
        self.thickness = thickness
        self.variant = variant
        self.cornerRadius = cornerRadius
        self.shape = AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        self.tint = tint
        self.interactive = interactive
    }

    /// Convenience init for capsule shape
    public static func capsule(
        thickness: Thickness = .ultraThin,
        variant: Variant = .default
    ) -> LiquidGlassStyle {
        LiquidGlassStyle(
            thickness: thickness,
            variant: variant,
            cornerRadius: .infinity,
            tint: nil,
            interactive: false
        )
    }

    /// Convenience init for circle shape
    public static func circle(
        thickness: Thickness = .ultraThin,
        variant: Variant = .default
    ) -> LiquidGlassStyle {
        LiquidGlassStyle(
            thickness: thickness,
            variant: variant,
            cornerRadius: .infinity,
            tint: nil,
            interactive: false
        )
    }

    // MARK: - Computed Properties (Base Values - Adapted by Modifier)

    /// Base overlay opacity (adapted: light=full, dark=30%)
    var whiteOverlayOpacity: Double {
        switch variant {
        case .subtle: return 0.06
        case .default: return 0.10
        case .elevated: return 0.14
        }
    }

    /// Saturation boost (makes glass feel "alive")
    var saturationBoost: Double {
        switch variant {
        case .subtle: return 1.10
        case .default: return 1.15
        case .elevated: return 1.20
        }
    }

    /// Base shadow opacity (adapted: light=full, dark=60%)
    var shadowOpacity: Double {
        switch variant {
        case .subtle: return 0.03
        case .default: return 0.05
        case .elevated: return 0.08
        }
    }

    /// Shadow radius
    var shadowRadius: CGFloat {
        switch thickness {
        case .ultraThin: return 3
        case .thin: return 5
        case .regular: return 8
        }
    }

    /// Shadow Y offset
    var shadowY: CGFloat {
        switch thickness {
        case .ultraThin: return 1
        case .thin: return 2
        case .regular: return 4
        }
    }

    /// Base border top opacity (adapted: light=full, dark=40%)
    var borderTopOpacity: Double {
        switch variant {
        case .subtle: return 0.25
        case .default: return 0.40
        case .elevated: return 0.50
        }
    }

    /// Base border bottom opacity (adapted: light=full, dark=50%)
    var borderBottomOpacity: Double {
        0.08
    }
}

// MARK: - Liquid Glass Modifier

/// View modifier that applies liquid glass styling with OS 26 native support
/// Automatically adapts to light/dark color scheme
public struct LiquidGlassModifier: ViewModifier {
    let style: LiquidGlassStyle

    @Environment(\.colorScheme) private var colorScheme

    public init(style: LiquidGlassStyle) {
        self.style = style
    }

    public func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(style.shape)
            .overlay(glassBorder)
            .shadow(color: .black.opacity(shadowOpacity), radius: style.shadowRadius, y: style.shadowY)
    }

    // MARK: - Adaptive Values

    /// Adaptive shadow opacity (darker in light mode, subtler in dark)
    private var shadowOpacity: Double {
        colorScheme == .light ? style.shadowOpacity : style.shadowOpacity * 0.75
    }

    /// Adaptive overlay opacity (NO overlay in light - materials already adapt; subtle lift in dark)
    private var overlayOpacity: Double {
        colorScheme == .light ? 0 : style.whiteOverlayOpacity * 0.3
    }

    /// Adaptive border top opacity (edge lighting - preserve definition in dark)
    private var borderTopOpacity: Double {
        colorScheme == .light ? style.borderTopOpacity : style.borderTopOpacity * 0.6
    }

    /// Adaptive border bottom opacity
    private var borderBottomOpacity: Double {
        colorScheme == .light ? style.borderBottomOpacity : style.borderBottomOpacity * 0.7
    }

    // MARK: - Glass Background

    @ViewBuilder
    private var glassBackground: some View {
        if #available(macOS 26.0, *) {
            nativeGlassBackground
        } else {
            fallbackGlassBackground
        }
    }

    @available(macOS 26.0, *)
    @ViewBuilder
    private var nativeGlassBackground: some View {
        // Use fallback until macOS 26 GlassEffectStyle API is finalized
        fallbackGlassBackground
    }

    @ViewBuilder
    private var fallbackGlassBackground: some View {
        // Material base
        materialBase
        // Adaptive tint overlay (white for light, subtle for dark)
            .overlay(Color.white.opacity(overlayOpacity))
        // Saturation boost (makes glass feel "alive")
            .saturation(style.saturationBoost)
    }

    @ViewBuilder
    private var materialBase: some View {
        switch style.thickness {
        case .ultraThin:
            Color.clear.background(.ultraThinMaterial)
        case .thin:
            Color.clear.background(.thinMaterial)
        case .regular:
            Color.clear.background(.regularMaterial)
        }
    }

    // MARK: - Glass Border (Edge Lighting)

    @ViewBuilder
    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(borderTopOpacity),
                        Color.white.opacity(borderBottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Convenience Styles

public extension LiquidGlassStyle {
    /// Task row default style
    static let taskRow = LiquidGlassStyle(thickness: .ultraThin, variant: .default, cornerRadius: 12)

    /// Task row selected style
    static let taskRowSelected = LiquidGlassStyle(thickness: .thin, variant: .elevated, cornerRadius: 12)

    /// Kanban column style
    static let kanbanColumn = LiquidGlassStyle(thickness: .thin, variant: .default, cornerRadius: 12)

    /// Kanban card style
    static let kanbanCard = LiquidGlassStyle(thickness: .ultraThin, variant: .default, cornerRadius: 10)

    /// FAB button style
    static let fabButton = LiquidGlassStyle(thickness: .regular, variant: .elevated, cornerRadius: .infinity)

    /// Badge/chip style
    static let badge = LiquidGlassStyle.capsule(thickness: .ultraThin, variant: .subtle)

    /// Search bar style
    static let searchBar = LiquidGlassStyle(thickness: .ultraThin, variant: .default, cornerRadius: 8)

    /// Settings card style
    static let settingsCard = LiquidGlassStyle(thickness: .thin, variant: .default, cornerRadius: 12)

    /// Circle button style
    static let circleButton = LiquidGlassStyle.circle(thickness: .ultraThin, variant: .default)
}
