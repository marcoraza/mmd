import SwiftUI

// MARK: - SpotlightView

/// Dims the whole screen and punches a rounded hole around the highlighted
/// element. Purely visual: never captures touches, so `.action` steps can tap
/// the real element through the hole.
struct SpotlightView: View {

    /// Target frame in the overlay's coordinate space. `nil` dims everything.
    let cutout: CGRect?
    var cornerRadius: CGFloat = Liquid.Radius.md
    var padding: CGFloat = 8
    var dim: Double = 0.6

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(dim))
            .reverseMask {
                if let cutout {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .frame(
                            width: cutout.width + padding * 2,
                            height: cutout.height + padding * 2
                        )
                        .position(x: cutout.midX, y: cutout.midY)
                }
            }
            .allowsHitTesting(false)
            .animation(Liquid.Motion.default, value: cutout)
    }
}

// MARK: - Reverse Mask

extension View {
    /// Masks `self` everywhere except where `content` draws, cutting a hole.
    /// Works on iOS 16 via `.destinationOut` inside a compositing group.
    func reverseMask<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        mask {
            Rectangle()
                .overlay {
                    content().blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}
