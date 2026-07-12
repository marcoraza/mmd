import SwiftUI

// MARK: - TourOverlay

/// Root overlay for the active tour. Resolves the highlighted element's frame
/// from collected anchors, then draws the spotlight and the coach card.
///
/// Mounted in LiquidRoot via `.overlayPreferenceValue(TourAnchorKey.self)` so
/// it can see anchors published anywhere in the tree.
struct TourOverlayContent: View {

    let anchors: [TourTarget: Anchor<CGRect>]
    let proxy: GeometryProxy

    @EnvironmentObject private var tour: TourController

    var body: some View {
        if tour.isActive, let step = tour.currentStep {
            let targetRect = resolvedRect(for: step)

            ZStack {
                SpotlightView(cutout: targetRect)

                // Info steps swallow taps to the app underneath so nothing fires
                // by accident. Action steps let taps pass through the cutout.
                if step.kind == .info {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {}
                }

                TourCard(
                    step: step,
                    number: tour.stepNumber,
                    total: tour.stepCount,
                    onNext: { tour.next() },
                    onSkip: { tour.skip() }
                )
                .position(cardCenter(for: targetRect))
                .id(step.id)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .animation(Liquid.Motion.default, value: step.id)
        }
    }

    // MARK: - Geometry

    private func resolvedRect(for step: TourStep) -> CGRect? {
        guard let target = step.target, let anchor = anchors[target] else { return nil }
        return proxy[anchor]
    }

    /// Places the card below a top-half target, above a bottom-half target, or
    /// centered when there is no target. Always clamped inside the screen.
    private func cardCenter(for rect: CGRect?) -> CGPoint {
        let size = proxy.size
        let estimatedHalfHeight: CGFloat = 92
        let margin: CGFloat = 28
        let x = size.width / 2

        guard let rect else {
            return CGPoint(x: x, y: size.height / 2)
        }

        let below = rect.maxY + margin + estimatedHalfHeight
        let above = rect.minY - margin - estimatedHalfHeight
        let minY = estimatedHalfHeight + margin
        let maxY = size.height - estimatedHalfHeight - margin

        let y: CGFloat = rect.midY < size.height / 2 ? below : above
        return CGPoint(x: x, y: min(max(y, minY), maxY))
    }
}
