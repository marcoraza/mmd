import SwiftUI

// MARK: - Event Pro: Design Tokens
//
// Lei visual "Ponte de cinza" (handoff event-pro-2, secao 2), medida no
// prototipo da Home 2.0: papel quente, mapa frio, cinzas neutros de ponte.
// Regra dura: paleta clara, ZERO cor de acento. Estado e codificado por
// posicao, peso, rotulo, forma ou densidade, nunca por cor.
//
// Sobrevive da fundacao anterior: escala de espaco base 4, raios, alvo de
// toque 44pt, fontes Inter Tight e JetBrains Mono, EPPressStyle.

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
    /// Padding lateral do conteudo da Home (medido no prototipo).
    static let padTela: CGFloat = 22
    /// Folga inferior de scroll para a barra flutuante.
    static let padBarra: CGFloat = 116
}

// MARK: - Raio (granular na faixa baixa, onde erro e visivel)

extension EP {
    static let r2: CGFloat = 2
    static let r4: CGFloat = 4
    static let r6: CGFloat = 6
    static let r8: CGFloat = 8
    static let r10: CGFloat = 10
    static let r12: CGFloat = 12
    static let r14: CGFloat = 14
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    /// Pilula: metade da altura do componente, calculada no uso.
}

// MARK: - Papel e tinta (familia unica; estados futuros usam degraus da
// escada, nunca cor nova: F6F4F1 ECEBE9 E2E1DE DCDBD8 CBCAC6 B6B5B2
// 7B7B7E 4A4A4C 171718)

extension EP {
    /// Fundo do app, papel quente.
    static let paper = Color(hexRGB: 0xF6F4F1)
    /// Superficie selecionada (evento aberto na agenda), 1,09:1 sobre papel.
    static let paper2 = Color(hexRGB: 0xECEBE9)
    /// Hairline 1px entre linhas de lista.
    static let linha = Color(hexRGB: 0xE2E1DE)
    /// Tinta: titulos, valores fortes. 16,32:1.
    static let ink = Color(hexRGB: 0x171718)
    /// Corpo. 8,05:1.
    static let ink2 = Color(hexRGB: 0x4A4A4C)
    /// Terciario: estrutura, kicker, texto grande apagado. 3,84:1.
    /// Nunca em texto pequeno (piso 4,5:1): para isso existe `sub`.
    static let ink3 = Color(hexRGB: 0x7B7B7E)
    /// Texto secundario pequeno, calculado para o piso 4,5:1 (4,56:1).
    static let sub = Color(hexRGB: 0x6F6F72)
    /// Icone de aba apagada na barra sem capsula (3,34:1, piso 3:1).
    static let tabApagado = Color(hexRGB: 0x85858A)
    /// Balao de distancia no mapa (blur 14 saturate 1.4 no uso).
    static let balao = Color(hexRGB: 0x12151A).opacity(0.5)
}

// MARK: - Mapa (paleta fria; a unica area densa da tela)

extension EP {
    static let mapBase = Color(hexRGB: 0x14161A)
    static let mapAgua = Color(hexRGB: 0x171A20)
    static let mapParque = Color(hexRGB: 0x161920)
    static let mapQuarteirao = Color(hexRGB: 0x1B1F25)
    static let mapViaPrincipal = Color(hexRGB: 0x232830)
    static let mapViaSecundaria = Color(hexRGB: 0x1E222A)
}

// MARK: - Tipografia (Inter Tight; numeros sempre tabulares no uso)

extension EP {
    /// Nome do evento no topo: 34 semibold, tracking -0.045em (aplicar
    /// `.tracking(EP.displayTracking)` junto).
    static func display() -> Font { .custom("InterTight", size: 34).weight(.semibold) }
    static let displayTracking: CGFloat = 34 * -0.045

    /// Linha de contexto acima do display.
    static func kicker() -> Font { .custom("InterTight", size: 12).weight(.medium) }
    /// Frase unica de dados; valores fortes em `dadosForte()`.
    static func dados() -> Font { .custom("InterTight", size: 14) }
    static func dadosForte() -> Font { .custom("InterTight", size: 14).weight(.semibold) }
    /// Section header ("Agenda") e contagem a direita.
    static func secao() -> Font { .custom("InterTight", size: 12).weight(.medium) }
    /// Agenda: coluna de data.
    static func agendaData() -> Font { .custom("InterTight", size: 13).weight(.medium) }
    /// Agenda: nome do evento (aberto vira semibold, nao confirmado regular).
    static func agendaNome() -> Font { .custom("InterTight", size: 15).weight(.medium) }
    static func agendaNomeAberto() -> Font { .custom("InterTight", size: 15).weight(.semibold) }
    static func agendaNomeSoft() -> Font { .custom("InterTight", size: 15) }
    /// Agenda: local, encostado a direita.
    static func agendaLocal() -> Font { .custom("InterTight", size: 13) }
    /// Balao de distancia no mapa.
    static func balaoTexto() -> Font { .custom("InterTight", size: 11).weight(.semibold) }
    /// Rotulo da aba ativa.
    static func abaRotulo() -> Font { .custom("InterTight", size: 14).weight(.semibold) }
    /// Titulo de tela secundaria (Eventos, Ajustes, Login).
    static func screenTitle() -> Font { .custom("InterTight", size: 28).weight(.semibold) }
    /// Corpo e apoio fora da Home.
    static func body() -> Font { .custom("InterTight", size: 15) }
    static func itemTitle() -> Font { .custom("InterTight", size: 16).weight(.semibold) }
    static func secondary() -> Font { .custom("InterTight", size: 13) }
    /// Mono para serial, timestamp e dado tecnico.
    static func mono(_ size: CGFloat = 13) -> Font { .custom("JetBrains Mono", size: size) }
}

// MARK: - Motion (duracoes medidas no prototipo)

extension EP {
    /// Snap do carrossel do mapa. Gatilho: deslocamento > 90pt ou
    /// velocidade > 0,55pt/ms.
    static let snapCarrossel = Animation.timingCurve(0.25, 0.9, 0.25, 1, duration: 0.34)
    /// Pin viaja dentro do mapa (toque na agenda).
    static let pinViaja = Animation.timingCurve(0.4, 0.05, 0.2, 1, duration: 0.5)
    /// Cross-fade da rota.
    static let rotaFade = Animation.easeInOut(duration: 0.34)
    /// Capsula da aba: largura.
    static let abaCapsula = Animation.timingCurve(0.3, 0.9, 0.25, 1, duration: 0.34)
    /// Capsula da aba: fundo e cor.
    static let abaCor = Animation.easeInOut(duration: 0.28)
    /// Rotulo da aba: opacity.
    static let abaRotuloFade = Animation.easeInOut(duration: 0.22)
    /// Fundo da linha da agenda.
    static let linhaAgenda = Animation.easeInOut(duration: 0.22)
    /// Troca de conteudo pos-animacao.
    static let trocaConteudo = Animation.easeInOut(duration: 0.32)
    /// Curva neutra para feedback e fades curtos.
    static let ease = Animation.easeInOut(duration: 0.18)
}

// MARK: - Cor por hex sRGB (a lei nova e medida em hex, nao em oklch)

extension Color {
    init(hexRGB: UInt32) {
        self.init(
            .sRGB,
            red: Double((hexRGB >> 16) & 0xFF) / 255.0,
            green: Double((hexRGB >> 8) & 0xFF) / 255.0,
            blue: Double(hexRGB & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Press feedback (todo alvo tocavel responde; escala + haptic)

struct EPPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(EP.ease, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { old, new in
                new && !old
            }
    }
}
