import SwiftUI

// MARK: - ProgressSegmentBar

/// Variable-count segmented progress bar.
///
/// Displays `filled` out of `total` segments as rectangular blocks.
/// Falls back to a continuous bar when total exceeds `maxVisibleSegments`.
///
/// Same visual treatment as WearBar: 5px height, 2px gap, no border-radius.
struct ProgressSegmentBar: View {

    let total: Int
    let filled: Int
    var filledColor: Color = .ndSuccess
    var emptyColor: Color = .ndBorder
    var maxVisibleSegments: Int = 20

    var body: some View {
        if total <= 0 {
            emptyState
        } else if total <= maxVisibleSegments {
            segmentedBar
        } else {
            continuousBar
        }
    }

    // MARK: - Segmented

    private var segmentedBar: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? filledColor : emptyColor)
                    .frame(height: 5)
            }
        }
    }

    // MARK: - Continuous Fallback

    private var continuousBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(emptyColor)

                Rectangle()
                    .fill(filledColor)
                    .frame(
                        width: total > 0
                            ? geometry.size.width * CGFloat(filled) / CGFloat(total)
                            : 0
                    )
            }
        }
        .frame(height: 5)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Rectangle()
            .fill(emptyColor)
            .frame(height: 5)
    }
}

// MARK: - Preview

#if DEBUG
struct ProgressSegmentBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: NDSpacing.section) {
            ProgressSegmentBar(total: 12, filled: 8)
            ProgressSegmentBar(total: 12, filled: 12, filledColor: .ndSuccess)
            ProgressSegmentBar(total: 5, filled: 2, filledColor: .ndWarning)
            ProgressSegmentBar(total: 30, filled: 20)
            ProgressSegmentBar(total: 0, filled: 0)
        }
        .padding()
        .background(Color.ndBlack)
        .preferredColorScheme(.dark)
    }
}
#endif
