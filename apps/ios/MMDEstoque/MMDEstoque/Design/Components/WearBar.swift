import SwiftUI

// MARK: - WearBar

/// Segmented progress bar showing equipment wear level (1-5).
///
/// Nothing Design System rules:
/// - 5 rectangular blocks, no border-radius
/// - 5pt height, 2pt gap between blocks
/// - Filled blocks use the wear color (left-to-right up to the level)
/// - Empty blocks use `ndBorder`
///
/// Color mapping:
/// - 5 (Excelente): success green
/// - 4 (Bom): success green
/// - 3 (Regular): white (neutral)
/// - 2 (Desgastado): warning yellow
/// - 1 (Critico): accent red
///
/// Usage:
///
///     WearBar(level: 4)
///     WearBar(level: serialNumber.desgaste)
///
struct WearBar: View {
    let level: Int

    /// Total number of segments in the bar.
    private let totalSegments = 5

    /// Height of each segment block.
    private let segmentHeight: CGFloat = 5

    /// Gap between segments.
    private let segmentGap: CGFloat = 2

    private var clampedLevel: Int {
        min(max(level, 0), totalSegments)
    }

    private var fillColor: Color {
        clampedLevel.wearColor
    }

    var body: some View {
        HStack(spacing: segmentGap) {
            ForEach(1...totalSegments, id: \.self) { index in
                Rectangle()
                    .fill(index <= clampedLevel ? fillColor : Color.ndBorder)
                    .frame(height: segmentHeight)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desgaste \(clampedLevel) de \(totalSegments)")
        .accessibilityValue(wearLabel)
    }

    private var wearLabel: String {
        switch clampedLevel {
        case 5:  return "Excelente"
        case 4:  return "Bom"
        case 3:  return "Regular"
        case 2:  return "Desgastado"
        case 1:  return "Critico"
        default: return "Desconhecido"
        }
    }
}

// MARK: - WearBar + Label Variant

/// WearBar with an inline label showing the numeric level and description.
struct WearBarLabeled: View {
    let level: Int

    var body: some View {
        HStack(spacing: NDSpacing.base) {
            WearBar(level: level)
            Text("\(level)/5")
                .font(.spaceMono(11))
                .foregroundStyle(level.wearColor)
        }
    }
}

// MARK: - Previews

#Preview("Wear Bars") {
    VStack(spacing: NDSpacing.medium) {
        ForEach(0...5, id: \.self) { level in
            HStack {
                Text("Nivel \(level)")
                    .font(.ndCaption)
                    .foregroundStyle(Color.ndTextSecondary)
                    .frame(width: 60, alignment: .leading)
                WearBarLabeled(level: level)
            }
        }
    }
    .padding(NDSpacing.wide)
    .background(Color.ndBlack)
}
