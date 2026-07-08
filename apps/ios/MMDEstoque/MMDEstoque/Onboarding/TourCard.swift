import SwiftUI

// MARK: - TourCard

/// Floating coach card in the Liquid Glass system. Benefit headline, body,
/// progress, and either a "Próximo/Concluir" button (info steps) or an action
/// hint (action steps).
struct TourCard: View {

    let step: TourStep
    let number: Int
    let total: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.md) {
            progressHeader

            Text(step.title)
                .font(.liquidSans(19, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(Liquid.fg0)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.body)
                .font(.liquidSans(14, weight: .regular))
                .foregroundStyle(Liquid.fg2)
                .fixedSize(horizontal: false, vertical: true)

            footer
                .padding(.top, Liquid.Space.xs)
        }
        .padding(Liquid.Space.lg)
        .frame(width: 300, alignment: .leading)
        .panelSurface(cornerRadius: Liquid.Radius.lg, tone: .elevated)
        .liquidElevatedShadow()
    }

    // MARK: - Progress

    private var progressHeader: some View {
        HStack(spacing: Liquid.Space.md) {
            progressBar

            Text("PASSO \(number) DE \(total)")
                .font(.liquidMono(9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Liquid.fg3)
                .fixedSize()
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Liquid.hairlineStrong)

                Capsule()
                    .fill(Liquid.accentCyan)
                    .frame(width: geo.size.width * CGFloat(number) / CGFloat(max(total, 1)))
                    .animation(Liquid.Motion.default, value: number)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Liquid.Space.sm) {
            Button(action: onSkip) {
                Text("PULAR TOUR")
                    .font(.liquidMono(10, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(Liquid.fg3)
            }
            .buttonStyle(.plain)

            Spacer()

            if step.kind == .action {
                actionHint
            } else {
                nextButton
            }
        }
    }

    private var actionHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 11, weight: .semibold))

            Text(step.actionHint ?? "Sua vez")
                .font(.liquidMono(11, weight: .medium))
                .tracking(0.6)
                .textCase(.uppercase)
        }
        .foregroundStyle(Liquid.accentCyan)
    }

    private var nextButton: some View {
        Button(action: onNext) {
            Text(number >= total ? "CONCLUIR" : "PRÓXIMO")
                .font(.liquidSans(13, weight: .semibold))
                .foregroundStyle(Liquid.bg0)
                .padding(.horizontal, Liquid.Space.lg)
                .padding(.vertical, Liquid.Space.sm)
                .background(Capsule().fill(Liquid.fg0))
        }
        .buttonStyle(.plain)
    }
}
