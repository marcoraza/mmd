import SwiftUI

// MARK: - LiquidPackingMapView
//
// Variante MAPA do packing: mapa do galpao com prateleiras coloridas por
// progresso, rota otimizada, "voce esta aqui", proximo pick, barra de
// prateleiras, ETA e CTA. Porte fiel do mockup screen support-screens (PackingMap).
//
// MOCK: o layout do galpao (prateleiras, rota, ETA) e dado de exemplo ate o
// Marco passar o mapa real. O `localizacao` no banco hoje so tem "Galpao MMD",
// sem grid de prateleira, entao a rota e simulada de proposito.

struct LiquidPackingMapView: View {

    let project: Project

    // Espaco logico do mapa (mesmas coords do mockup), mapeado proporcionalmente.
    private let logicalW: CGFloat = 340
    private let logicalH: CGFloat = 270

    private let shelves: [WarehouseShelf] = WarehouseShelf.mock
    private let routePoints: [CGPoint] = [
        .init(x: 50, y: 50), .init(x: 200, y: 50), .init(x: 275, y: 50),
        .init(x: 275, y: 140), .init(x: 125, y: 140), .init(x: 50, y: 140),
        .init(x: 50, y: 230), .init(x: 125, y: 230),
    ]
    private let youAreHere = CGPoint(x: 190, y: 50)

    var body: some View {
        ZStack {
            CausticBackground(intensity: .work)

            ScrollView {
                VStack(spacing: Liquid.Space.lg) {
                    mapCard
                    nextPickCard
                    progressStrip
                    statsRow
                    cta
                }
                .padding(Liquid.Space.lg)
                .padding(.bottom, Liquid.Space.vast)
            }
        }
    }

    // MARK: Mapa

    private var mapCard: some View {
        GlassCard(strong: true) {
            VStack(alignment: .leading, spacing: Liquid.Space.md) {
                Text("Galpão A, rota otimizada").liquidLabel()

                GeometryReader { geo in
                    let sx = geo.size.width / logicalW
                    let sy = geo.size.height / logicalH

                    ZStack(alignment: .topLeading) {
                        routePath(sx: sx, sy: sy)

                        ForEach(shelves) { shelf in
                            shelfBox(shelf)
                                .frame(width: shelf.width * sx, height: 60 * sy)
                                .position(x: (shelf.x + shelf.width / 2) * sx,
                                          y: (shelf.y + 30) * sy)
                        }

                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .liquidGlow(.white, radius: 10, opacity: 0.9)
                            .position(x: youAreHere.x * sx, y: youAreHere.y * sy)
                    }
                }
                .frame(height: 250)
            }
        }
    }

    private func routePath(sx: CGFloat, sy: CGFloat) -> some View {
        Path { p in
            guard let first = routePoints.first else { return }
            p.move(to: CGPoint(x: first.x * sx, y: first.y * sy))
            for pt in routePoints.dropFirst() {
                p.addLine(to: CGPoint(x: pt.x * sx, y: pt.y * sy))
            }
        }
        .stroke(Liquid.accentViolet.opacity(0.5),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
    }

    private func shelfBox(_ shelf: WarehouseShelf) -> some View {
        let color = shelf.color
        return VStack(spacing: 2) {
            Text(shelf.id)
                .font(.liquidMono(12, weight: .medium))
                .foregroundStyle(color)
            Text(shelf.done ? "OK" : "\(shelf.total - shelf.pending)/\(shelf.total)")
                .font(.liquidMono(9))
                .foregroundStyle(Liquid.fg1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(color, lineWidth: 1.5))
        )
        .liquidGlow(shelf.active ? color : .clear, radius: shelf.active ? 16 : 0, opacity: shelf.active ? 0.6 : 0)
    }

    // MARK: Proximo pick

    private var nextPickCard: some View {
        VStack(alignment: .leading, spacing: Liquid.Space.sm) {
            HStack(spacing: Liquid.Space.sm) {
                Text("A3")
                    .font(.liquidMono(11, weight: .medium))
                    .foregroundStyle(Liquid.bg0)
                    .padding(.horizontal, Liquid.Space.sm)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Liquid.accentViolet))
                Text("Próximo, 3m à frente").liquidLabel(Liquid.accentViolet)
            }
            Text("Par LED 18x10W").liquidH3()
            (Text("Pegar ").foregroundColor(Liquid.fg2)
                + Text("4 unidades").foregroundColor(Liquid.fg0)
                + Text(", sobram 12 na prateleira").foregroundColor(Liquid.fg2))
                .font(.liquidBody)
        }
        .padding(Liquid.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                .fill(Liquid.accentViolet.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    .strokeBorder(Liquid.accentViolet.opacity(0.4), lineWidth: 1))
        )
    }

    // MARK: Barra de prateleiras

    private var progressStrip: some View {
        HStack(spacing: Liquid.Space.sm) {
            HStack(spacing: 6) {
                ForEach(0..<10, id: \.self) { i in
                    Capsule()
                        .fill(i < 7 ? Liquid.accentGreen : (i == 7 ? Liquid.accentViolet : Liquid.glassBorderStrong))
                        .frame(height: 4)
                }
            }
            Text("7/10 prateleiras").liquidMonoData(10, color: Liquid.fg2)
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: Liquid.Space.sm) {
            statCard("Tempo", "12:34", "decorridos")
            statCard("Restam", "~7 min", "estimado")
            statCard("Progresso", "87/214", "41%")
        }
    }

    private func statCard(_ label: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).liquidLabel(Liquid.fg2)
            Text(value).font(.liquidMono(16, weight: .medium)).foregroundStyle(Liquid.fg0)
            Text(sub).liquidSmall().foregroundStyle(Liquid.fg3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Liquid.Space.md)
        .glassSurface(cornerRadius: Liquid.Radius.md)
    }

    // MARK: CTA

    private var cta: some View {
        Text("Iniciar coleta em A3")
            .font(.liquidMono(14, weight: .medium))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Liquid.bg0)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Liquid.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Liquid.Radius.md, style: .continuous)
                    .fill(Liquid.accentViolet)
                    .liquidGlow(Liquid.accentViolet, radius: 18, opacity: 0.4)
            )
            .padding(.top, Liquid.Space.xs)
    }
}

// MARK: - WarehouseShelf (mock)

struct WarehouseShelf: Identifiable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let total: Int
    let pending: Int
    var done: Bool = false
    var active: Bool = false
    var amber: Bool = false
    var red: Bool = false
    var wide: Bool = false

    var width: CGFloat { wide ? 140 : 65 }

    var color: Color {
        if active { return Liquid.accentViolet }
        if amber { return Liquid.accentAmber }
        if red { return Liquid.accentRed }
        return Liquid.accentGreen
    }

    // MOCK: layout de exemplo, trocar pelo galpao real.
    static let mock: [WarehouseShelf] = [
        .init(id: "A1", x: 20, y: 30, total: 12, pending: 0, done: true),
        .init(id: "A2", x: 95, y: 30, total: 8, pending: 0, done: true),
        .init(id: "A3", x: 170, y: 30, total: 16, pending: 4, active: true),
        .init(id: "A4", x: 245, y: 30, total: 4, pending: 0, done: true),
        .init(id: "B1", x: 20, y: 120, total: 8, pending: 3, amber: true),
        .init(id: "B2", x: 95, y: 120, total: 2, pending: 0, done: true),
        .init(id: "B3", x: 170, y: 120, total: 30, pending: 0, done: true),
        .init(id: "B4", x: 245, y: 120, total: 4, pending: 4, amber: true),
        .init(id: "C1", x: 20, y: 210, total: 1, pending: 0, done: true),
        .init(id: "EXT", x: 95, y: 210, total: 12, pending: 12, red: true, wide: true),
    ]
}
