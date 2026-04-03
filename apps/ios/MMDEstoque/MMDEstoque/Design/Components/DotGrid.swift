import SwiftUI

// MARK: - DotGrid

/// Repeating dot-grid background pattern for the Nothing Design System.
///
/// Draws small dots in a uniform grid using `Canvas` for efficient rendering.
/// Intended as a subtle texture on top of `ndBlack` backgrounds.
///
/// Default configuration:
/// - Dot color: `ndBorder` (#222222)
/// - Dot size: 1pt radius
/// - Grid spacing: 12pt
/// - Opacity: 0.3
///
/// Usage:
///
///     ZStack {
///         Color.ndBlack
///         DotGrid()
///         // Your content here
///     }
///
///     // Or as a background modifier:
///     VStack { ... }
///         .background(Color.ndBlack)
///         .overlay(DotGrid())
///
struct DotGrid: View {
    var spacing: CGFloat = 12
    var dotSize: CGFloat = 1
    var dotColor: Color = .ndBorder
    var dotOpacity: Double = 0.3

    var body: some View {
        Canvas { context, size in
            let resolved = context.resolve(Shading.color(dotColor.opacity(dotOpacity)))

            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Circle().path(in: rect), with: resolved)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - View Extension

extension View {

    /// Adds the Nothing dot-grid pattern as a background overlay.
    ///
    /// Convenience for the common pattern of `ndBlack` background + dot grid.
    ///
    ///     VStack { ... }
    ///         .ndDotGridBackground()
    ///
    func ndDotGridBackground() -> some View {
        self
            .background(Color.ndBlack)
            .overlay(DotGrid())
    }
}

// MARK: - Preview

#Preview("Dot Grid") {
    ZStack {
        Color.ndBlack
        DotGrid()

        VStack(spacing: NDSpacing.wide) {
            Text("MMD ESTOQUE")
                .font(.ndHeading)
                .foregroundStyle(Color.ndTextDisplay)
            Text("Nothing Design System")
                .ndLabel()
        }
    }
    .ignoresSafeArea()
}
