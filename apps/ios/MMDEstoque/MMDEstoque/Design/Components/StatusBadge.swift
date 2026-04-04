import SwiftUI

// MARK: - StatusBadge

/// Pill-shaped badge that displays a status label with its corresponding color.
///
/// Nothing Design System rules:
/// - Space Mono ALL CAPS, 9px, letter-spacing 0.08em
/// - Capsule shape (pill, border-radius 999px)
/// - 1px border in the status color
/// - Text in the status color
/// - Transparent background
///
/// Usage:
///
///     StatusBadge(status: .disponivel)
///     StatusBadge(text: "CUSTOM", color: .ndWarning)
///
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.ndLabelSm)
            .textCase(.uppercase)
            .tracking(9 * 0.08)
            .foregroundStyle(color)
            .padding(.horizontal, NDSpacing.base)
            .padding(.vertical, NDSpacing.tight)
            .background(
                Capsule()
                    .strokeBorder(color, lineWidth: 1)
            )
    }
}

// MARK: - Convenience Initializers

extension StatusBadge {

    /// Create a badge from a `StatusSerial` enum value.
    /// Text and color are derived automatically.
    init(status: StatusSerial) {
        self.text = status.displayName
        self.color = status.color
    }
}

// MARK: - CategoriaBadge

/// Pill-shaped badge for equipment categories, using category accent colors.
///
/// Same visual rules as `StatusBadge` but derives color from `Categoria`.
///
/// Usage:
///
///     CategoriaBadge(categoria: .iluminacao)
///     CategoriaBadge(text: "AUDIO", color: .blue)
///
struct CategoriaBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.ndLabelSm)
            .textCase(.uppercase)
            .tracking(9 * 0.08)
            .foregroundStyle(color)
            .padding(.horizontal, NDSpacing.base)
            .padding(.vertical, NDSpacing.tight)
            .background(
                Capsule()
                    .strokeBorder(color, lineWidth: 1)
            )
    }
}

extension CategoriaBadge {

    /// Create a badge from a `Categoria` enum value.
    init(categoria: Categoria) {
        self.text = categoria.displayName
        self.color = categoria.color
    }
}

// MARK: - Previews

#Preview("Status Badges") {
    VStack(spacing: NDSpacing.medium) {
        ForEach(StatusSerial.allCases) { status in
            StatusBadge(status: status)
        }
    }
    .padding(NDSpacing.wide)
    .background(Color.ndBlack)
}

#Preview("Category Badges") {
    VStack(spacing: NDSpacing.medium) {
        ForEach(Categoria.allCases) { cat in
            CategoriaBadge(categoria: cat)
        }
    }
    .padding(NDSpacing.wide)
    .background(Color.ndBlack)
}
