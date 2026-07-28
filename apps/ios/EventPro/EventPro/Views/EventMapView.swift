import SwiftUI

// MARK: - Mapa ilustrativo da Home 2.0
//
// Superficie ilustrativa (pendencia 9.2): mapa escuro com rota propria por
// evento, sem dado geografico real e sem balao de km (o balao so entra com
// dado real). Geometria portada do prototipo (tasks/evidence/home-2.0):
// mesma agua, parque, quarteiroes, vias e as 7 variantes de rota, com
// variacao por seed. Navegacao por dois caminhos: arrastar (carrossel de
// 3 slots) e toque na agenda (o pin viaja dentro do mapa).

private struct RotaVariante {
    let a: CGFloat
    let b: CGFloat
    let c: CGFloat
    let d: CGFloat
}

private let rotaVariantes: [RotaVariante] = [
    RotaVariante(a: 0.12, b: 0.88, c: 0.82, d: 0.22),
    RotaVariante(a: 0.18, b: 0.80, c: 0.74, d: 0.30),
    RotaVariante(a: 0.08, b: 0.74, c: 0.90, d: 0.36),
    RotaVariante(a: 0.22, b: 0.90, c: 0.70, d: 0.16),
    RotaVariante(a: 0.10, b: 0.82, c: 0.86, d: 0.26),
    RotaVariante(a: 0.16, b: 0.70, c: 0.78, d: 0.40),
    RotaVariante(a: 0.06, b: 0.84, c: 0.92, d: 0.20),
]

private func wrapIndex(_ i: Int, _ n: Int) -> Int {
    guard n > 0 else { return 0 }
    return ((i % n) + n) % n
}

private func variante(_ seed: Int) -> RotaVariante {
    rotaVariantes[wrapIndex(seed, rotaVariantes.count)]
}

// MARK: - MapaHome (carrossel)

struct MapaHome: View {
    /// Quantos eventos existem na agenda (0 desliga a navegacao).
    let count: Int
    /// Indice do evento em destaque, controlado pelo pai.
    let selecionado: Int
    /// Arrasto commitou um passo (+1/-1); o pai atualiza a selecao.
    let aoArrastar: (Int) -> Void

    static let altura: CGFloat = 212

    @State private var shownSeed = 0
    @State private var dragX: CGFloat = 0
    @State private var busy = false
    @State private var passoInterno = false
    @State private var rotaOpacity: Double = 1
    @State private var destinoFrac: CGPoint = .zero

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                MapaSlot(seed: wrapIndex(shownSeed - 1, count), comRota: count > 0)
                    .frame(width: w)
                ZStack {
                    MapaBase(seed: shownSeed)
                    if count > 0 {
                        MapaRota(variante: variante(shownSeed))
                            .opacity(rotaOpacity)
                        MapaDestino(frac: destinoFrac)
                    }
                }
                .frame(width: w)
                MapaSlot(seed: wrapIndex(shownSeed + 1, count), comRota: count > 0)
                    .frame(width: w)
            }
            .offset(x: -w + dragX)
            .contentShape(Rectangle())
            .gesture(arrasto(w))
        }
        .frame(height: Self.altura)
        .clipped()
        .onAppear {
            shownSeed = selecionado
            destinoFrac = destino(selecionado)
        }
        .onChange(of: selecionado) { _, novo in
            guard novo != shownSeed else { return }
            if passoInterno {
                passoInterno = false
                return
            }
            viajarPin(para: novo)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mapa do evento, arraste para trocar")
    }

    private func destino(_ seed: Int) -> CGPoint {
        let v = variante(seed)
        return CGPoint(x: v.c, y: v.d)
    }

    // MARK: Toque na agenda: o mapa NAO desliza, o pin viaja dentro dele

    private func viajarPin(para novo: Int) {
        busy = true
        withAnimation(EP.rotaFade) { rotaOpacity = 0 }
        withAnimation(EP.pinViaja) { destinoFrac = destino(novo) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            shownSeed = novo
            withAnimation(EP.rotaFade) { rotaOpacity = 1 }
            busy = false
        }
    }

    // MARK: Arrasto: carrossel que segue o dedo e encaixa no vizinho

    private func arrasto(_ w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !busy, count > 1 else { return }
                dragX = value.translation.width
            }
            .onEnded { value in
                guard !busy, count > 1 else {
                    dragX = 0
                    return
                }
                let dx = value.translation.width
                // Gatilho medido: deslocamento > 90pt ou velocidade > 0,55pt/ms.
                let rapido = abs(value.velocity.width) > 550
                let passo = (abs(dx) > 90 || rapido) ? (dx < 0 ? 1 : -1) : 0
                if passo == 0 {
                    withAnimation(EP.snapCarrossel) { dragX = 0 }
                    return
                }
                busy = true
                withAnimation(EP.snapCarrossel) { dragX = passo > 0 ? -w : w }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                    shownSeed = wrapIndex(shownSeed + passo, count)
                    destinoFrac = destino(shownSeed)
                    rotaOpacity = 1
                    dragX = 0
                    passoInterno = true
                    aoArrastar(passo)
                    busy = false
                }
            }
    }
}

// MARK: - Slot estatico (vizinhos do carrossel)

private struct MapaSlot: View {
    let seed: Int
    let comRota: Bool

    var body: some View {
        ZStack {
            MapaBase(seed: seed)
            if comRota {
                MapaRota(variante: variante(seed))
                MapaDestino(frac: CGPoint(x: variante(seed).c, y: variante(seed).d))
            }
        }
    }
}

// MARK: - Base (agua, parque, quarteiroes, vias)

private struct MapaBase: View {
    let seed: Int

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let off = CGFloat((wrapIndex(seed, rotaVariantes.count) * 13) % 40)

            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(EP.mapBase))

            var agua = Path()
            agua.move(to: CGPoint(x: w * 0.62 - off, y: -20))
            agua.addCurve(to: CGPoint(x: w + 20, y: h * 0.26),
                          control1: CGPoint(x: w * 0.72, y: h * 0.2),
                          control2: CGPoint(x: w * 0.88, y: h * 0.3))
            agua.addLine(to: CGPoint(x: w + 20, y: -20))
            agua.closeSubpath()
            ctx.fill(agua, with: .color(EP.mapAgua))

            var parque = Path()
            parque.move(to: CGPoint(x: -20, y: h * 0.72))
            parque.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.94),
                            control1: CGPoint(x: w * 0.16, y: h * 0.66),
                            control2: CGPoint(x: w * 0.2, y: h * 0.9))
            parque.addLine(to: CGPoint(x: w * 0.42, y: h + 20))
            parque.addLine(to: CGPoint(x: -20, y: h + 20))
            parque.closeSubpath()
            ctx.fill(parque, with: .color(EP.mapParque))

            let quarteiroes: [CGRect] = [
                CGRect(x: w * 0.05 + off, y: h * 0.08, width: 58, height: h * 0.14),
                CGRect(x: w * 0.26, y: h * 0.06, width: 46, height: h * 0.10),
                CGRect(x: w * 0.06, y: h * 0.36, width: 72, height: h * 0.16),
                CGRect(x: w * 0.33 - off / 2, y: h * 0.34, width: 52, height: h * 0.20),
                CGRect(x: w * 0.56, y: h * 0.42, width: 64, height: h * 0.15),
                CGRect(x: w * 0.78, y: h * 0.56, width: 56, height: h * 0.18),
                CGRect(x: w * 0.52, y: h * 0.74, width: 48, height: h * 0.14),
            ]
            for rect in quarteiroes {
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(EP.mapQuarteirao))
            }

            var principal1 = Path()
            principal1.move(to: CGPoint(x: -20, y: h * 0.6))
            principal1.addCurve(to: CGPoint(x: w + 20, y: h * 0.3),
                                control1: CGPoint(x: w * 0.3, y: h * 0.55),
                                control2: CGPoint(x: w * 0.5, y: h * 0.44))
            var principal2 = Path()
            principal2.move(to: CGPoint(x: w * 0.47 + off / 3, y: -20))
            principal2.addLine(to: CGPoint(x: w * 0.44, y: h + 20))
            let viaPrincipal = StrokeStyle(lineWidth: 9, lineCap: .round)
            ctx.stroke(principal1, with: .color(EP.mapViaPrincipal), style: viaPrincipal)
            ctx.stroke(principal2, with: .color(EP.mapViaPrincipal), style: viaPrincipal)

            var secundarias = Path()
            secundarias.move(to: CGPoint(x: -20, y: h * 0.28))
            secundarias.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.18),
                                 control1: CGPoint(x: w * 0.25, y: h * 0.24),
                                 control2: CGPoint(x: w * 0.4, y: h * 0.3))
            secundarias.move(to: CGPoint(x: -20, y: h * 0.86))
            secundarias.addLine(to: CGPoint(x: w * 0.5, y: h * 0.86))
            secundarias.move(to: CGPoint(x: w * 0.2, y: -20))
            secundarias.addLine(to: CGPoint(x: w * 0.2, y: h * 0.72))
            secundarias.move(to: CGPoint(x: w * 0.74, y: h * 0.1))
            secundarias.addLine(to: CGPoint(x: w * 0.74, y: h + 20))
            ctx.stroke(secundarias, with: .color(EP.mapViaSecundaria),
                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }
}

// MARK: - Rota (gradiente branco da origem ao destino) + origem

private struct MapaRota: View {
    fileprivate let variante: RotaVariante

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let origem = CGPoint(x: w * variante.a, y: h * variante.b)
            let destino = CGPoint(x: w * variante.c, y: h * variante.d)

            Path { p in
                p.move(to: origem)
                p.addCurve(to: destino,
                           control1: CGPoint(x: w * (variante.a + 0.14), y: h * (variante.b - 0.1)),
                           control2: CGPoint(x: w * (variante.c - 0.3), y: h * (variante.d + 0.24)))
            }
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.18), location: 0),
                        .init(color: .white.opacity(0.8), location: 0.5),
                        .init(color: .white, location: 1),
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )

            Circle()
                .fill(EP.mapBase)
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                .position(origem)
        }
    }
}

// MARK: - Destino (circulo branco com halo; anima posicao no pin-viaja)

private struct MapaDestino: View {
    let frac: CGPoint

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
            }
            .position(x: geo.size.width * frac.x, y: geo.size.height * frac.y)
        }
    }
}
