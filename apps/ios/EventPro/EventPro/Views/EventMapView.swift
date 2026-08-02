import MapKit
import SwiftUI

// MARK: - Mapa real da aba Eventos
//
// Card 212pt full bleed, MapKit passivo (carrossel horizontal).
// Galpão → pin com curva que varia por destino, pin + balão de km do mockup.

private func wrapIndex(_ i: Int, _ n: Int) -> Int {
    guard n > 0 else { return 0 }
    return ((i % n) + n) % n
}

// MARK: - MapaHome (carrossel)

struct MapaHome: View {
    let eventos: [Project]
    let selecionado: Int
    let aoArrastar: (Int) -> Void
    let aoTocar: () -> Void

    static let altura: CGFloat = 212

    @State private var shownSeed = 0
    @State private var dragX: CGFloat = 0
    @State private var busy = false
    @State private var passoInterno = false

    private var count: Int { eventos.count }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                slot(for: wrapIndex(shownSeed - 1, count), width: w)
                    .frame(width: w)
                slot(for: shownSeed, width: w)
                    .frame(width: w)
                slot(for: wrapIndex(shownSeed + 1, count), width: w)
                    .frame(width: w)
            }
            .offset(x: -w + dragX)
            .contentShape(Rectangle())
            .gesture(arrasto(w))
            .onTapGesture { aoTocar() }
        }
        .frame(height: Self.altura)
        .clipped()
        .onAppear { shownSeed = selecionado }
        .onChange(of: selecionado) { _, novo in
            guard novo != shownSeed else { return }
            if passoInterno {
                passoInterno = false
                shownSeed = novo
                return
            }
            if busy {
                shownSeed = novo
                busy = false
                return
            }
            withAnimation(EP.pinViaja) {
                shownSeed = novo
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(count > 1 ? "Arraste para trocar de evento" : "")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        guard count > 0, eventos.indices.contains(shownSeed) else {
            return "Mapa do evento"
        }
        let evento = eventos[shownSeed]
        if let pin = evento.destinoPin {
            let km = MapRouteComposition.displayKilometers(
                from: GalpaoOrigem.coordinate,
                to: pin.coordinate
            )
            return "Mapa real, \(evento.localDisplayName), \(km) quilômetros do galpão"
        }
        return "Mapa, \(evento.localDisplayName), local ainda não definido"
    }

    @ViewBuilder
    private func slot(for index: Int, width: CGFloat) -> some View {
        if count == 0 {
            DestinoMapSlot(evento: nil, cardWidth: width)
        } else if eventos.indices.contains(index) {
            DestinoMapSlot(evento: eventos[index], cardWidth: width)
        } else {
            DestinoMapSlot(evento: nil, cardWidth: width)
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
                    shownSeed = wrapIndex(shownSeed + passo, count)
                    dragX = 0
                    passoInterno = true
                    aoArrastar(passo)
                    busy = false
                }
            }
    }
}

// MARK: - Slot

struct DestinoMapSlot: View {
    let evento: Project?
    var cardWidth: CGFloat = 390

    var body: some View {
        ZStack {
            if let evento, let pin = evento.destinoPin {
                CompactDestinoMap(pin: pin, cardWidth: cardWidth)
            } else {
                EmptyDestinoMap(
                    title: evento?.localDisplayName ?? "Agenda",
                    subtitle: emptySubtitle
                )
            }
        }
    }

    private var emptySubtitle: String {
        guard let evento else { return "Nenhum evento na fila" }
        if !evento.enderecoDisplayLine.isEmpty {
            return evento.enderecoDisplayLine
        }
        return "Local ainda não definido"
    }
}

// MARK: - Mapa compacto MapKit

private struct CompactDestinoMap: View {
    let pin: DestinoPin
    var cardWidth: CGFloat = 390

    private var origin: CLLocationCoordinate2D { GalpaoOrigem.coordinate }

    private var route: [CLLocationCoordinate2D] {
        MapRouteComposition.routeCoordinates(from: origin, to: pin.coordinate)
    }

    private var km: Int {
        MapRouteComposition.displayKilometers(from: origin, to: pin.coordinate)
    }

    private var region: MKCoordinateRegion {
        let aspect = max(cardWidth / MapaHome.altura, 0.5)
        return MapRouteComposition.region(
            origin: origin,
            destination: pin.coordinate,
            aspectWidthOverHeight: aspect
        )
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            MapPolyline(coordinates: route)
                .stroke(
                    Color.white.opacity(0.92),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

            Annotation(GalpaoOrigem.nome, coordinate: origin, anchor: .center) {
                GalpaoOrigemDot()
            }

            Annotation("", coordinate: pin.coordinate, anchor: .center) {
                DestinoPinComBalao(km: km)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls { }
        .preferredColorScheme(.dark)
        .colorScheme(.dark)
        .background(EP.mapBase)
        .allowsHitTesting(false)
        // id força recarregar câmera/rota ao trocar de evento no carrossel
        .id("\(pin.latitude)-\(pin.longitude)")
    }
}

// MARK: - Estado sem pin

private struct EmptyDestinoMap: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            EP.mapBase
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
                Text("Local ainda não definido")
                    .font(EP.dadosForte())
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(EP.secondary())
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

// MARK: - Mapa expandido (edição Uber + linha + km)

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
            _position = State(initialValue: .region(
                MKCoordinateRegion(
                    center: GalpaoOrigem.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                )
            ))
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
