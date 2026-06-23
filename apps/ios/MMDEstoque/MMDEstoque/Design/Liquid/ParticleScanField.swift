import SwiftUI

// MARK: - ParticleScanField
//
// O campo de scan herói: aneis concentricos + nuvem de particulas, uma por tag
// lida. Cada tag vira um ponto luminoso que entra com a leitura. A assinatura
// visual do produto (referencia: mockup screen-rfid-scan).
//
// As posicoes sao deterministicas por indice (hash), entao as particulas nao
// pulam a cada re-render: a tag N fica sempre no mesmo lugar.

struct ParticleScanField: View {

    let tagCount: Int
    var isScanning: Bool
    var diameter: CGFloat = 300

    /// Teto de particulas desenhadas (alem disso vira denso demais e pesa).
    private let maxParticles = 90

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            rings
            particles
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? nil : Liquid.Motion.default, value: tagCount)
        .onAppear { startPulse() }
        .onChange(of: isScanning) { _ in startPulse() }
    }

    // MARK: Aneis

    private var rings: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let scale = ringScales[i]
                Circle()
                    .strokeBorder(Liquid.accentCyan.opacity(0.08 + Double(i) * 0.03), lineWidth: 1)
                    .frame(width: diameter * scale, height: diameter * scale)
            }

            Circle()
                .strokeBorder(Liquid.accentCyan.opacity(isScanning ? 0.30 : 0.16), lineWidth: 1.5)
                .frame(width: diameter, height: diameter)
                .liquidGlow(
                    Liquid.accentCyan,
                    radius: isScanning ? 26 : 10,
                    opacity: isScanning ? 0.5 : 0.2
                )
                .scaleEffect(isScanning && pulse ? 1.025 : 1.0)
        }
    }

    private let ringScales: [CGFloat] = [0.40, 0.60, 0.80, 1.0]

    // MARK: Particulas

    private var particles: some View {
        let n = min(max(tagCount, 0), maxParticles)
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let p = position(for: i)
                Circle()
                    .fill(Liquid.accentCyan)
                    .frame(width: p.size, height: p.size)
                    .liquidGlow(Liquid.accentCyan, radius: p.size * 2.4, opacity: 0.85)
                    .position(x: p.x, y: p.y)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    /// Posicao e tamanho deterministicos por indice. Hash em UInt pra evitar
    /// negativos. Raio fica na faixa media-externa pra nao cobrir o contador.
    private func position(for i: Int) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        let seedA = UInt(bitPattern: i) &* 2_654_435_761
        let seedB = UInt(bitPattern: i) &* 40_503 &+ 12_345
        let a = Double(seedA % 1000) / 1000.0
        let b = Double(seedB % 1000) / 1000.0

        let angle = a * 2 * .pi
        let radius = (0.24 + b * 0.74) * Double(diameter) / 2
        let center = Double(diameter) / 2
        let x = center + cos(angle) * radius
        let y = center + sin(angle) * radius
        let size: CGFloat = (i % 4 == 0) ? 3.5 : 2.5
        return (CGFloat(x), CGFloat(y), size)
    }

    private func startPulse() {
        guard isScanning, !reduceMotion else {
            pulse = false
            return
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ParticleScanField_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            CausticBackground(intensity: .hero)
            ParticleScanField(tagCount: 73, isScanning: true)
                .overlay {
                    VStack(spacing: 2) {
                        Text("73").font(.liquidHero(76)).foregroundStyle(Liquid.fg0)
                        Text("TAGS").liquidLabel(Liquid.fg2)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
