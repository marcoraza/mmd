import MapKit
import SwiftUI

// MARK: - Mapa da aba Eventos
//
// VISUAL: mockup Home 2.0 (canvas, 7 rotas, pin, balão de km, carrossel).
// DADOS: eventos reais do backend (pin Supabase, km galpão→destino, toque
// abre sheet funcional). MapKit fica só na superfície de edição expandida.

private struct RotaVariante {
    let a: CGFloat
    let b: CGFloat
    let c: CGFloat
    let d: CGFloat
}

/// Mesmas 7 curvas do protótipo home-2.0 / handoff.
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

private func variante(seed: Int) -> RotaVariante {
    rotaVariantes[wrapIndex(seed, rotaVariantes.count)]
}

/// Seed visual estável: coords do pin quando existem; senão id do evento.
private func visualSeed(for evento: Project) -> Int {
    if let pin = evento.destinoPin {
        return MapRouteComposition.variantIndex(for: pin.coordinate)
    }
    var hasher = Hasher()
    hasher.combine(evento.id)
    return abs(hasher.finalize())
}

private func kmPara(_ evento: Project) -> Int? {
    guard let pin = evento.destinoPin else { return nil }
    return MapRouteComposition.displayKilometers(
        from: GalpaoOrigem.coordinate,
        to: pin.coordinate
    )
}

// MARK: - MapaHome (carrossel mockup + dados reais)

struct MapaHome: View {
    let eventos: [Project]
    let selecionado: Int
    let aoArrastar: (Int) -> Void
    let aoTocar: () -> Void

    static let altura: CGFloat = 212

    @State private var shownIndex = 0
    @State private var dragX: CGFloat = 0
    @State private var busy = false
    @State private var passoInterno = false
    @State private var rotaOpacity: Double = 1
    @State private var destinoFrac: CGPoint = .zero
    @State private var viagem = 0

    private var count: Int { eventos.count }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                slot(for: wrapIndex(shownIndex - 1, count))
                    .frame(width: w)
                centerSlot
                    .frame(width: w)
                slot(for: wrapIndex(shownIndex + 1, count))
                    .frame(width: w)
            }
            .offset(x: -w + dragX)
            .contentShape(Rectangle())
            .gesture(arrasto(w))
            .onTapGesture { aoTocar() }
        }
        .frame(height: Self.altura)
        .clipped()
        .onAppear {
            shownIndex = selecionado
            destinoFrac = destinoFrac(for: selecionado)
        }
        .onChange(of: selecionado) { _, novo in
            guard novo != shownIndex else {
                // Mesmo índice, pin pode ter sido gravado agora.
                destinoFrac = destinoFrac(for: novo)
                return
            }
            if passoInterno {
                passoInterno = false
                shownIndex = novo
                destinoFrac = destinoFrac(for: novo)
                return
            }
            if busy {
                viagem += 1
                shownIndex = novo
                destinoFrac = destinoFrac(for: novo)
                rotaOpacity = 1
                busy = false
                return
            }
            viajarPin(para: novo)
        }
        .onChange(of: eventos.map(\.destinoPin)) { _, _ in
            destinoFrac = destinoFrac(for: shownIndex)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(count > 1 ? "Arraste para trocar de evento" : "Toque para o local")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        guard count > 0, eventos.indices.contains(shownIndex) else {
            return "Mapa do evento"
        }
        let ev = eventos[shownIndex]
        if let km = kmPara(ev) {
            return "Mapa, \(ev.localDisplayName), \(km) quilômetros do galpão"
        }
        return "Mapa, \(ev.localDisplayName), local ainda não definido"
    }

    @ViewBuilder
    private var centerSlot: some View {
        let seed = seed(for: shownIndex)
        let ev = evento(at: shownIndex)
        let hasPin = ev?.hasDestino == true
        ZStack {
            MapaBase(seed: seed)
            if hasPin {
                MapaRota(variante: variante(seed: seed))
                    .opacity(rotaOpacity)
                MapaDestino(frac: destinoFrac, km: ev.flatMap(kmPara))
            } else {
                MapaSemPin(texto: ev?.enderecoDisplayLine.isEmpty == false
                    ? ev!.enderecoDisplayLine
                    : (ev?.localDisplayName ?? "Local ainda não definido"))
            }
        }
    }

    @ViewBuilder
    private func slot(for index: Int) -> some View {
        let seed = seed(for: index)
        let ev = evento(at: index)
        let hasPin = ev?.hasDestino == true
        ZStack {
            MapaBase(seed: seed)
            if hasPin {
                let v = variante(seed: seed)
                MapaRota(variante: v)
                MapaDestino(
                    frac: CGPoint(x: v.c, y: v.d),
                    km: ev.flatMap(kmPara)
                )
            } else if count > 0 {
                MapaSemPin(texto: "Local ainda não definido")
            }
        }
    }

    private func evento(at index: Int) -> Project? {
        guard count > 0, eventos.indices.contains(index) else { return nil }
        return eventos[index]
    }

    private func seed(for index: Int) -> Int {
        guard let ev = evento(at: index) else { return index }
        return visualSeed(for: ev)
    }

    private func destinoFrac(for index: Int) -> CGPoint {
        let v = variante(seed: seed(for: index))
        return CGPoint(x: v.c, y: v.d)
    }

    private func viajarPin(para novo: Int) {
        busy = true
        viagem += 1
        let atual = viagem
        withAnimation(EP.rotaFade) { rotaOpacity = 0 }
        withAnimation(EP.pinViaja) { destinoFrac = destinoFrac(for: novo) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            guard viagem == atual else { return }
            shownIndex = novo
            withAnimation(EP.rotaFade) { rotaOpacity = 1 }
            busy = false
        }
    }

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
                let rapido = abs(value.velocity.width) > 550
                let passo = (abs(dx) > 90 || rapido) ? (dx < 0 ? 1 : -1) : 0
                if passo == 0 {
                    withAnimation(EP.snapCarrossel) { dragX = 0 }
                    return
                }
                busy = true
                withAnimation(EP.snapCarrossel) { dragX = passo > 0 ? -w : w }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                    shownIndex = wrapIndex(shownIndex + passo, count)
                    destinoFrac = destinoFrac(for: shownIndex)
                    rotaOpacity = 1
                    dragX = 0
                    passoInterno = true
                    aoArrastar(passo)
                    busy = false
                }
            }
    }
}

// MARK: - Base (água, parque, quarteirões, vias) — mockup

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
            agua.addCurve(
                to: CGPoint(x: w + 20, y: h * 0.26),
                control1: CGPoint(x: w * 0.72, y: h * 0.2),
                control2: CGPoint(x: w * 0.88, y: h * 0.3)
            )
            agua.addLine(to: CGPoint(x: w + 20, y: -20))
            agua.closeSubpath()
            ctx.fill(agua, with: .color(EP.mapAgua))

            var parque = Path()
            parque.move(to: CGPoint(x: -20, y: h * 0.72))
            parque.addCurve(
                to: CGPoint(x: w * 0.42, y: h * 0.94),
                control1: CGPoint(x: w * 0.16, y: h * 0.66),
                control2: CGPoint(x: w * 0.2, y: h * 0.9)
            )
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
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: 3),
                    with: .color(EP.mapQuarteirao)
                )
            }

            var principal1 = Path()
            principal1.move(to: CGPoint(x: -20, y: h * 0.6))
            principal1.addCurve(
                to: CGPoint(x: w + 20, y: h * 0.3),
                control1: CGPoint(x: w * 0.3, y: h * 0.55),
                control2: CGPoint(x: w * 0.5, y: h * 0.44)
            )
            var principal2 = Path()
            principal2.move(to: CGPoint(x: w * 0.47 + off / 3, y: -20))
            principal2.addLine(to: CGPoint(x: w * 0.44, y: h + 20))
            let viaPrincipal = StrokeStyle(lineWidth: 9, lineCap: .round)
            ctx.stroke(principal1, with: .color(EP.mapViaPrincipal), style: viaPrincipal)
            ctx.stroke(principal2, with: .color(EP.mapViaPrincipal), style: viaPrincipal)

            var secundarias = Path()
            secundarias.move(to: CGPoint(x: -20, y: h * 0.28))
            secundarias.addCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.18),
                control1: CGPoint(x: w * 0.25, y: h * 0.24),
                control2: CGPoint(x: w * 0.4, y: h * 0.3)
            )
            secundarias.move(to: CGPoint(x: -20, y: h * 0.86))
            secundarias.addLine(to: CGPoint(x: w * 0.5, y: h * 0.86))
            secundarias.move(to: CGPoint(x: w * 0.2, y: -20))
            secundarias.addLine(to: CGPoint(x: w * 0.2, y: h * 0.72))
            secundarias.move(to: CGPoint(x: w * 0.74, y: h * 0.1))
            secundarias.addLine(to: CGPoint(x: w * 0.74, y: h + 20))
            ctx.stroke(
                secundarias,
                with: .color(EP.mapViaSecundaria),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
            )
        }
    }
}

// MARK: - Rota + origem (mockup)

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
                p.addCurve(
                    to: destino,
                    control1: CGPoint(x: w * (variante.a + 0.14), y: h * (variante.b - 0.1)),
                    control2: CGPoint(x: w * (variante.c - 0.3), y: h * (variante.d + 0.24))
                )
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

            // Origem: r 4.5 mapBase + aro branco 2.5
            Circle()
                .fill(EP.mapBase)
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                .position(origem)
        }
    }
}

// MARK: - Destino + balão de km (mockup)

private struct MapaDestino: View {
    let frac: CGPoint
    let km: Int?

    var body: some View {
        GeometryReader { geo in
            let point = CGPoint(x: geo.size.width * frac.x, y: geo.size.height * frac.y)
            ZStack {
                if let km {
                    DistanciaBalao(km: km)
                        .position(x: point.x, y: point.y - 28)
                }
                // Pin: halo r11 @ 14% + disco r5
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 22, height: 22)
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                }
                .position(point)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Sem pin

private struct MapaSemPin: View {
    let texto: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
            Text("Local ainda não definido")
                .font(EP.dadosForte())
                .foregroundStyle(.white.opacity(0.92))
            Text(texto)
                .font(EP.secondary())
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Mapa expandido (MapKit só na edição funcional)
//
// A sheet de destino usa isto para editar pin de verdade e ver cartografia.
// O card da Home permanece 100% mockup.

struct ExpandedDestinoMap: View {
    let pin: DestinoPin?
    let isEditing: Bool
    let onCameraIdle: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition
    @State private var isDragging = false

    init(
        pin: DestinoPin?,
        isEditing: Bool,
        onCameraIdle: @escaping (CLLocationCoordinate2D) -> Void
    ) {
        self.pin = pin
        self.isEditing = isEditing
        self.onCameraIdle = onCameraIdle
        if let pin {
            _position = State(
                initialValue: .region(
                    MapRouteComposition.region(
                        origin: GalpaoOrigem.coordinate,
                        destination: pin.coordinate,
                        aspectWidthOverHeight: 1.15
                    )
                )
            )
        } else {
            _position = State(
                initialValue: .region(
                    MKCoordinateRegion(
                        center: GalpaoOrigem.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                    )
                )
            )
        }
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                Annotation(GalpaoOrigem.nome, coordinate: GalpaoOrigem.coordinate, anchor: .center) {
                    GalpaoOrigemDot()
                }

                if let pin, !isEditing {
                    MapPolyline(
                        coordinates: MapRouteComposition.routeCoordinates(
                            from: GalpaoOrigem.coordinate,
                            to: pin.coordinate
                        )
                    )
                    .stroke(
                        Color.white.opacity(0.92),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    Annotation("", coordinate: pin.coordinate, anchor: .center) {
                        DestinoPinComBalao(
                            km: MapRouteComposition.displayKilometers(
                                from: GalpaoOrigem.coordinate,
                                to: pin.coordinate
                            )
                        )
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .preferredColorScheme(.dark)
            .colorScheme(.dark)
            .background(EP.mapBase)
            .onMapCameraChange(frequency: .continuous) { _ in
                if isEditing { isDragging = true }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                guard isEditing else { return }
                isDragging = false
                onCameraIdle(context.camera.centerCoordinate)
            }
            .allowsHitTesting(isEditing)
            .onChange(of: pin) { _, newPin in
                guard !isEditing, let newPin else { return }
                withAnimation(EP.pinViaja) {
                    position = .region(
                        MapRouteComposition.region(
                            origin: GalpaoOrigem.coordinate,
                            destination: newPin.coordinate,
                            aspectWidthOverHeight: 1.15
                        )
                    )
                }
            }

            if isEditing {
                DestinoPinDot()
                    .allowsHitTesting(false)
                    .offset(y: isDragging ? -4 : 0)
                    .animation(.easeOut(duration: 0.12), value: isDragging)
            }
        }
    }
}
