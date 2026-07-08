import SwiftUI

// MARK: - LiquidCheckoutGridView
//
// Conferencia visual do check-out: ring de prontidao, mapa de calor das
// unidades (toque pra localizar o serial), chips de filtro sincronizados com a
// lista por item. Porte fiel do mockup CheckoutCombined.
//
// MOCK: o estado de validacao (quais unidades ja foram lidas, o que falta) e
// dado de exemplo ate o scan alimentar isso de verdade. No fluxo real, cada tag
// lida pinta uma celula de verde.

struct LiquidCheckoutGridView: View {

    let project: Project

    @State private var filter: CheckoutFilter = .all
    @State private var focused: Int? = nil

    // MOCK: 27 indices faltando, das 108 celulas visiveis (214 reais).
    private let missing: Set<Int> = [3, 7, 18, 22, 31, 45, 56, 72, 89, 101, 4, 41,
                                     68, 92, 55, 77, 99, 48, 65, 82, 85, 38, 27, 14, 104, 73, 16]
    private let totalUnits = 214
    private let readyUnits = 187
    private let missingUnits = 27

    private let columns = Array(repeating: GridItem(.fixed(14), spacing: 3), count: 18)

    private var rows: [CheckoutRow] { CheckoutRow.mock }
    private var visibleRows: [CheckoutRow] {
        switch filter {
        case .all:     return rows
        case .missing: return rows.filter { $0.status != .ok }
        case .ok:      return rows.filter { $0.status == .ok }
        }
    }

    var body: some View {
        ZStack {
            TechnicalGridCanvas()

            ScrollView {
                VStack(alignment: .leading, spacing: Liquid.Space.lg) {
                    readinessHeader
                    gridCard
                    filterChips
                    listCard
                }
                .padding(Liquid.Space.lg)
                .padding(.bottom, Liquid.Space.vast)
            }
        }
    }

    // MARK: Readiness

    private var readinessHeader: some View {
        HStack(spacing: Liquid.Space.lg) {
            ReadinessGauge(progress: 0.87, diameter: 72, stroke: 6)

            VStack(alignment: .leading, spacing: Liquid.Space.xs) {
                (Text("\(readyUnits)").foregroundColor(Liquid.fg0)
                    + Text("/\(totalUnits)").foregroundColor(Liquid.fg3))
                    .font(.liquidSans(28, weight: .medium))
                Text("\(missingUnits) faltando")
                    .font(.liquidSmall).foregroundStyle(Liquid.accentAmber)
                LiquidProgressBar(total: totalUnits, filled: readyUnits, color: Liquid.accentGreen, height: 3)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Grid

    private var gridCard: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                HStack {
                    Text("214 unidades, toque pra localizar").liquidLabel()
                    Spacer()
                    HStack(spacing: Liquid.Space.md) {
                        legend(Liquid.accentGreen, readyUnits)
                        legend(Liquid.accentRed, missingUnits)
                    }
                }

                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(0..<108, id: \.self) { i in
                        cell(i)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func legend(_ color: Color, _ n: Int) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
            Text("\(n)").liquidMonoData(9, color: Liquid.fg2)
        }
    }

    private func cell(_ i: Int) -> some View {
        let isMissing = missing.contains(i)
        let isFocus = focused == i
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(isMissing ? Liquid.accentRed.opacity(0.85) : Liquid.accentGreen.opacity(0.75))
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(.white, lineWidth: isFocus ? 2 : 0)
            )
            .liquidGlow(isMissing && !isFocus ? Liquid.accentRed : .clear, radius: 4, opacity: isMissing && !isFocus ? 0.7 : 0)
            .scaleEffect(isFocus ? 1.6 : 1)
            .zIndex(isFocus ? 2 : 1)
            .onTapGesture {
                withAnimation(Liquid.Motion.fast) { focused = (focused == i) ? nil : i }
            }
    }

    // MARK: Chips

    private var filterChips: some View {
        HStack(spacing: Liquid.Space.sm) {
            chip(.missing, "Faltando", Liquid.accentAmber, missingUnits)
            chip(.ok, "Prontos", Liquid.accentGreen, readyUnits)
            chip(.all, "Tudo", Liquid.fg2, totalUnits)
        }
    }

    private func chip(_ value: CheckoutFilter, _ label: String, _ color: Color, _ n: Int) -> some View {
        let on = filter == value
        return Button { withAnimation(Liquid.Motion.fast) { filter = value } } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label).font(.liquidSans(11, weight: .medium))
                Text("\(n)").font(.liquidMono(11)).opacity(0.7)
            }
            .foregroundStyle(on ? color : Liquid.fg2)
            .padding(.horizontal, Liquid.Space.md)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(on ? color.opacity(0.22) : Liquid.glassBg)
                    .overlay(Capsule().strokeBorder(on ? color : Liquid.glassBorder, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: List

    private var listCard: some View {
        GlassCard(strong: true, padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Por item agregado").font(.liquidSans(12, weight: .medium)).foregroundStyle(Liquid.fg0)
                    Spacer()
                    Text("\(visibleRows.count) linhas").liquidMonoData(10, color: Liquid.fg2)
                }
                .padding(.horizontal, Liquid.Space.lg)
                .padding(.vertical, Liquid.Space.md)

                Rectangle().fill(Liquid.glassBorder).frame(height: 1)

                ForEach(visibleRows) { row in
                    rowView(row)
                    Rectangle().fill(Liquid.glassBorder.opacity(0.6)).frame(height: 0.5)
                        .padding(.leading, Liquid.Space.lg)
                }
            }
        }
    }

    private func rowView(_ row: CheckoutRow) -> some View {
        HStack(spacing: Liquid.Space.md) {
            Image(systemName: row.status.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(row.status.color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(row.status.color.opacity(0.20))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(row.status.color, lineWidth: 1))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).font(.liquidSans(13, weight: .medium)).foregroundStyle(Liquid.fg0).lineLimit(1)
                Text(row.code).liquidMonoData(9, color: Liquid.fg3)
            }
            Spacer()
            Text(row.label).font(.liquidMono(12, weight: .medium)).foregroundStyle(row.status.color)
        }
        .padding(.horizontal, Liquid.Space.lg)
        .padding(.vertical, Liquid.Space.md)
    }
}

// MARK: - Models (mock)

enum CheckoutFilter { case all, missing, ok }

enum CheckoutStatus {
    case missing, partial, ok
    var color: Color {
        switch self {
        case .missing: return Liquid.accentRed
        case .partial: return Liquid.accentAmber
        case .ok:      return Liquid.accentGreen
        }
    }
    var icon: String {
        switch self {
        case .missing: return "xmark"
        case .partial: return "exclamationmark.triangle.fill"
        case .ok:      return "checkmark"
        }
    }
}

struct CheckoutRow: Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let status: CheckoutStatus
    let qty: Int
    let alloc: Int

    var label: String {
        switch status {
        case .missing: return "0/\(qty)"
        case .partial: return "\(alloc)/\(qty)"
        case .ok:      return "\(qty)/\(qty)"
        }
    }

    static let mock: [CheckoutRow] = [
        .init(name: "Box Truss Q30 3m", code: "MMD-EST-0009", status: .missing, qty: 12, alloc: 0),
        .init(name: "Moving Head Beam 230W", code: "MMD-ILU-0088", status: .partial, qty: 8, alloc: 6),
        .init(name: "Cabo XLR 10m (lote)", code: "MMD-CAB-L012", status: .partial, qty: 40, alloc: 32),
        .init(name: "Par LED 18x10W", code: "MMD-ILU-0042", status: .ok, qty: 16, alloc: 16),
        .init(name: "Mesa Yamaha QL5", code: "MMD-AUD-0003", status: .ok, qty: 1, alloc: 1),
        .init(name: "Subwoofer JBL SRX818", code: "MMD-AUD-0024", status: .ok, qty: 4, alloc: 4),
        .init(name: "Cabo Powercon 5m", code: "MMD-CAB-L004", status: .ok, qty: 30, alloc: 30),
        .init(name: "Caixa JBL VRX932", code: "MMD-AUD-0011", status: .ok, qty: 8, alloc: 8),
    ]
}
