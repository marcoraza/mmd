import SwiftUI

// MARK: - Event Pro: Design Tokens
//
// Fundacao nova, derivada de dois estudos medidos:
// - Gramatica ClickUp (raza-design-universes/clickup-sistema-espaco-estado-motion.md):
//   escala de espaco base 4, elevacao com teto de alpha, estados como degraus
//   de rampa (nunca opacity), duas curvas de motion, hairline como definicao.
// - Identidade Liquid Glass do MMD: acentos oklch proprios, dark-first.
//
// Adaptacoes de contexto (galpao, luva, pressa):
// - alvo de toque minimo 44pt (ClickUp usa 42)
// - piso de contraste de texto 4.5:1 (ClickUp desce a 4.2)
// - elevacao no dark e CLAREAMENTO de superficie + hairline, nao sombra preta.

enum EP {}

// MARK: - Espaco (base 4, doze degraus, linear; fora da lista nao existe)

extension EP {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 28
    static let s8: CGFloat = 32
    static let s9: CGFloat = 36
    static let s10: CGFloat = 40
    static let s11: CGFloat = 44
    static let s12: CGFloat = 48

    /// Alvo de toque minimo. Galpao e luva: nada abaixo disso.
    static let touchMin: CGFloat = 44
    /// Altura de linha de dado de um andar.
    static let rowHeight: CGFloat = 48
    /// Altura de linha de dois andares (titulo + subtitulo).
    static let rowHeightTall: CGFloat = 60
}

// MARK: - Raio (granular na faixa baixa, onde erro e visivel)

extension EP {
    static let r2: CGFloat = 2
    static let r4: CGFloat = 4
    static let r6: CGFloat = 6
    static let r8: CGFloat = 8
    static let r10: CGFloat = 10
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    /// Pilula: metade da altura do componente, calculada no uso.
}

// MARK: - Cor: superficies (elevacao por clareamento, quatro niveis)

extension EP {
    // Rampa de fundo dark, do chao ao flutuante. Cada nivel e um degrau
    // perceptual em oklch; a separacao entre camadas vem do tom, e a
    // definicao vem da hairline, nunca de sombra preta pesada.
    static let bg0 = Color(oklch: 0.12, 0.015, 250)   // chao do app
    static let bg1 = Color(oklch: 0.155, 0.017, 250)  // card em repouso
    static let bg2 = Color(oklch: 0.19, 0.019, 250)   // card elevado / input
    static let bg3 = Color(oklch: 0.23, 0.021, 250)   // flutuante (barra, sheet)

    // Estados de superficie interativa: degrau acima, nunca opacity.
    static let bg1Hover = Color(oklch: 0.175, 0.018, 250)
    static let bg1Pressed = Color(oklch: 0.20, 0.019, 250)
    static let bg3Pressed = Color(oklch: 0.27, 0.022, 250)

    // Hairlines: a definicao de borda que a sombra nao da no dark.
    static let hairline = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.14)
}

// MARK: - Cor: texto (piso 4.5:1 sobre bg0; terciario nunca vira informacao)

extension EP {
    static let fg0 = Color(oklch: 0.97, 0.005, 250)   // primario
    static let fg1 = Color(oklch: 0.82, 0.008, 250)   // corpo
    static let fg2 = Color(oklch: 0.64, 0.010, 250)   // secundario / labels
    static let fg3 = Color(oklch: 0.46, 0.012, 250)   // estrutura, nunca dado
}

// MARK: - Cor: significado (a lei: cor so em estado, identidade ou selecao)

extension EP {
    // Estado operacional (badge de fundo cheio, texto escuro do chao).
    static let stateReady = Color(oklch: 0.80, 0.17, 150)    // pronto / ok
    static let stateField = Color(oklch: 0.80, 0.15, 75)     // em campo / atencao
    static let stateCritical = Color(oklch: 0.70, 0.18, 25)  // falta / dano
    static let stateInfo = Color(oklch: 0.75, 0.14, 210)     // acao primaria / foco

    // Identidade de categoria (pilula, cor fixa por categoria, sempre a mesma).
    static let catIluminacao = Color(oklch: 0.80, 0.15, 75)
    static let catAudio = Color(oklch: 0.70, 0.17, 295)
    static let catVideo = Color(oklch: 0.75, 0.14, 210)
    static let catCabo = Color(oklch: 0.72, 0.12, 180)
    static let catEnergia = Color(oklch: 0.70, 0.18, 25)
    static let catEstrutura = Color(oklch: 0.68, 0.10, 250)
    static let catEfeito = Color(oklch: 0.78, 0.16, 330)
    static let catAcessorio = Color(oklch: 0.75, 0.08, 130)

    /// Selecao (halo tonal de baixa saturacao, nunca bloco de cor cheio).
    static func selectionHalo(_ accent: Color) -> Color {
        accent.opacity(0.16)
    }
}

// MARK: - Motion (duas curvas; alta frequencia nao ganha transicao)

extension EP {
    /// Curva de UI: sai devagar, corre, trava seco. Derivada da familia
    /// snappy, valores proprios.
    static let snappy = Animation.timingCurve(0.55, 0, 0.1, 0.95, duration: 0.22)
    /// Curva neutra para fades e mudancas de estado nao espaciais.
    static let ease = Animation.timingCurve(0.42, 0, 0.58, 1, duration: 0.18)
    /// Spring de chegada para elementos que entram na tela.
    static let arrive = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

// MARK: - Tipografia (dois regimes: escala so no titulo de tela; dentro de
// lista, hierarquia por peso e cor, nunca por tamanho)

extension EP {
    static func screenTitle() -> Font { .custom("InterTight", size: 28).weight(.bold) }
    static func itemTitle() -> Font { .custom("InterTight", size: 16).weight(.semibold) }
    static func body() -> Font { .custom("InterTight", size: 15) }
    static func secondary() -> Font { .custom("InterTight", size: 13) }
    static func sectionLabel() -> Font { .custom("JetBrains Mono", size: 12).weight(.medium) }
    static func mono(_ size: CGFloat = 13) -> Font { .custom("JetBrains Mono", size: size) }
    static func heroNumber() -> Font { .custom("InterTight", size: 44).weight(.semibold) }
}

// MARK: - Superficie padrao (card com hairline; elevacao = bg + hairline)

struct EPSurface: ViewModifier {
    var level: Int = 1
    var radius: CGFloat = EP.r12

    private var fill: Color {
        switch level {
        case 0: return EP.bg0
        case 1: return EP.bg1
        case 2: return EP.bg2
        default: return EP.bg3
        }
    }

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(EP.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func epSurface(_ level: Int = 1, radius: CGFloat = EP.r12) -> some View {
        modifier(EPSurface(level: level, radius: radius))
    }
}

// MARK: - Press feedback (todo alvo tocavel responde; degrau de rampa + escala)

struct EPPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: EP.r12, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.06 : 0))
            )
            .animation(EP.ease, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { old, new in
                new && !old
            }
    }
}
