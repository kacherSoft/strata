import SwiftUI

// MARK: - View + Liquid Glass Extension

public extension View {
    /// Applies liquid glass styling with the specified style
    /// - Parameter style: The liquid glass style configuration
    /// - Returns: A view with liquid glass styling applied
    func liquidGlass(_ style: LiquidGlassStyle) -> some View {
        modifier(LiquidGlassModifier(style: style))
    }

    /// Applies liquid glass styling with optional highlight state
    /// - Parameter style: The liquid glass style configuration
    /// - Parameter isHighlighted: Whether to use elevated variant (for hover/target states)
    /// - Returns: A view with liquid glass styling applied
    func liquidGlass(_ style: LiquidGlassStyle, isHighlighted: Bool) -> some View {
        let effectiveStyle = LiquidGlassStyle(
            thickness: style.thickness,
            variant: isHighlighted ? .elevated : style.variant,
            cornerRadius: style.cornerRadius,
            tint: style.tint,
            interactive: style.interactive
        )
        return modifier(LiquidGlassModifier(style: effectiveStyle))
    }

    /// Applies liquid glass styling with default style
    /// - Parameter thickness: The material thickness
    /// - Parameter variant: The glass variant
    /// - Parameter cornerRadius: The corner radius
    /// - Returns: A view with liquid glass styling applied
    func liquidGlass(
        thickness: LiquidGlassStyle.Thickness,
        variant: LiquidGlassStyle.Variant = .default,
        cornerRadius: CGFloat = 12
    ) -> some View {
        let style = LiquidGlassStyle(
            thickness: thickness,
            variant: variant,
            cornerRadius: cornerRadius
        )
        return modifier(LiquidGlassModifier(style: style))
    }
}
