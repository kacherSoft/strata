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

    /// Base shadow opacity (amplified in light mode for card separation)
    var shadowOpacity: Double {
        switch variant {
        case .subtle: return 0.04
        case .default: return 0.06
        case .elevated: return 0.10
        }
    }

    /// Shadow radius
    var shadowRadius: CGFloat {
        switch thickness {
        case .ultraThin: return 4
        case .thin: return 6
        case .regular: return 10
        }
    }

    /// Shadow Y offset
    var shadowY: CGFloat {
        switch thickness {
        case .ultraThin: return 2
        case .thin: return 3
        case .regular: return 5
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
/// Automatically adapts to light/dark color scheme:
/// - Light mode: Clean, solid backgrounds with subtle gray borders (native macOS style)
/// - Dark mode: Glassmorphism with materials and edge lighting
public struct LiquidGlassModifier: ViewModifier {
    let style: LiquidGlassStyle

    @Environment(\.colorScheme) private var colorScheme

    public init(style: LiquidGlassStyle) {
        self.style = style
    }

    public func body(content: Content) -> some View {
        if colorScheme == .light {
            // Light mode: Layered depth effect with reflection
            content
                .background(lightModeBackground)
                .clipShape(style.shape)
                .overlay(lightModeInnerHighlight)
                .overlay(lightModeBorder)
                .shadow(color: .black.opacity(shadowOpacity), radius: style.shadowRadius, y: style.shadowY)
        } else {
            // Dark mode: Glassmorphism
            content
                .background(darkModeBackground)
                .clipShape(style.shape)
                .overlay(darkModeBorder)
                .shadow(color: .black.opacity(shadowOpacity), radius: style.shadowRadius, y: style.shadowY)
        }
    }

    // MARK: - Adaptive Values

    /// Adaptive shadow opacity (more prominent in light mode for depth)
    private var shadowOpacity: Double {
        switch colorScheme {
        case .light:
            // Cards need visible shadows to pop in light mode
            style.shadowOpacity * 2.0
        default:
            style.shadowOpacity * 0.75
        }
    }

    /// Adaptive overlay opacity (only used in dark mode)
    private var overlayOpacity: Double {
        style.whiteOverlayOpacity * 0.3
    }

    // MARK: - Light Mode Components

    /// Light mode: Bright card backgrounds that pop above the window
    /// Cards are whiter than window background to create visual separation
    @ViewBuilder
    private var lightModeBackground: some View {
        // Bright white-ish card background (lighter than window)
        let topColor = Color.white.opacity(lightModeCardOpacity + 0.05)
        let bottomColor = Color(nsColor: .windowBackgroundColor).opacity(lightModeCardOpacity)

        LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Card background opacity based on thickness (thicker = more opaque/elevated)
    private var lightModeCardOpacity: Double {
        switch style.thickness {
        case .ultraThin:
            return 0.85 // Subtle but still visible
        case .thin:
            return 0.92 // Cards - clearly visible
        case .regular:
            return 0.98 // FAB/buttons - almost solid white
        }
    }

    /// Light mode: Inner highlight (top-left reflection simulating light source)
    @ViewBuilder
    private var lightModeInnerHighlight: some View {
        let highlightOpacity: Double = {
            switch style.variant {
            case .subtle: return 0.3
            case .default: return 0.5
            case .elevated: return 0.7
            }
        }()

        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(highlightOpacity),
                        Color.white.opacity(highlightOpacity * 0.3),
                        Color.clear,
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    /// Light mode: Outer subtle gray border
    @ViewBuilder
    private var lightModeBorder: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .strokeBorder(
                Color(nsColor: .separatorColor).opacity(borderOpacityLight),
                lineWidth: 0.5
            )
    }

    /// Border opacity for light mode based on variant
    private var borderOpacityLight: Double {
        switch style.variant {
        case .subtle: return 0.5
        case .default: return 0.7
        case .elevated: return 0.9
        }
    }

    // MARK: - Dark Mode Components

    /// Dark mode: Full glassmorphism with materials and edge lighting
    @ViewBuilder
    private var darkModeBackground: some View {
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
        // Subtle white overlay for lift
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

    /// Dark mode: Gradient edge lighting
    @ViewBuilder
    private var darkModeBorder: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(style.borderTopOpacity * 0.6),
                        Color.white.opacity(style.borderBottomOpacity * 0.7)
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
