import SwiftUI

// MARK: - Tour Anchoring

/// Collects the on-screen bounds of every element tagged with `.tourAnchor(_:)`.
/// The root overlay reads this to place the spotlight cutout and the card.
struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [TourTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TourTarget: Anchor<CGRect>],
        nextValue: () -> [TourTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    /// Registers this view as the tour anchor for `target`.
    func tourAnchor(_ target: TourTarget) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [target: $0] }
    }

    /// Registers the anchor only when `target` is non-nil. Handy inside generic
    /// loops where just some items are tour targets.
    @ViewBuilder
    func tourAnchor(if target: TourTarget?) -> some View {
        if let target {
            tourAnchor(target)
        } else {
            self
        }
    }
}
