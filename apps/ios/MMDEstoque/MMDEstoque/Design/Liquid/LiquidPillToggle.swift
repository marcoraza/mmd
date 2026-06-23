import SwiftUI

// MARK: - LiquidPillToggle
//
// Segmentado de vidro de duas ou mais opcoes, pilula. Usado no canto da nav bar
// (Lista/Mapa no packing, Scan/Conferencia no check-out). Generico sobre o tipo
// da selecao.

struct LiquidPillToggle<Option: Hashable>: View {

    @Binding var selection: Option
    let options: [(value: Option, label: String)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { opt in
                Button {
                    withAnimation(Liquid.Motion.fast) { selection = opt.value }
                } label: {
                    Text(opt.label)
                        .font(.liquidMono(11, weight: .medium))
                        .foregroundStyle(selection == opt.value ? Liquid.bg0 : Liquid.fg2)
                        .padding(.horizontal, Liquid.Space.md)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(selection == opt.value ? Liquid.accentCyan : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            Capsule().fill(Liquid.glassBg)
                .overlay(Capsule().strokeBorder(Liquid.glassBorder, lineWidth: 1))
        )
    }
}
