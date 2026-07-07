import SwiftUI

// MARK: - LiquidPillToggle
//
// Segmentado de vidro de duas ou mais opcoes, pilula. Usado no canto da nav bar
// (Lista/Mapa no packing, Scan/Conferencia no check-out). Generico sobre o tipo
// da selecao.

struct LiquidPillToggle<Option: Hashable>: View {

    @Binding var selection: Option
    let options: [(value: Option, label: String)]

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { opt in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selection = opt.value
                    }
                } label: {
                    Text(opt.label)
                        .font(.liquidSans(12, weight: .semibold))
                        .foregroundStyle(selection == opt.value ? Liquid.fg0 : Liquid.fg2)
                        .padding(.horizontal, Liquid.Space.md)
                        .padding(.vertical, 6)
                        .background {
                            if selection == opt.value {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .matchedGeometryEffect(id: "pill-indicator", in: indicator)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule().fill(Liquid.bg1)
                .overlay(Capsule().strokeBorder(Liquid.hairline, lineWidth: 1))
        )
    }
}
