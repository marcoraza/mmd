import SwiftUI

// MARK: - Liquid Glass 2030: Typography
//
// Inter Tight (sans) para UI, headings e body. JetBrains Mono para dados:
// seriais, timestamps, contadores, labels. Ambas variaveis (eixo wght),
// registradas em UIAppFonts. O peso e selecionado pela instancia nomeada
// via `.weight()` (iOS 16+).
//
// Escala do handoff (size / weight / tracking). O tracking vive em modifiers
// porque `Font` nao carrega letter-spacing nem line-height.

extension Liquid {
    enum Typeface {
        static let sans = "Inter Tight"
        static let mono = "JetBrains Mono"
    }
}

// MARK: - Font Builders

extension Font {

    /// Inter Tight no tamanho e peso dados. Acompanha Dynamic Type.
    static func liquidSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Liquid.Typeface.sans, size: size).weight(weight)
    }

    /// JetBrains Mono no tamanho e peso dados. Acompanha Dynamic Type.
    static func liquidMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Liquid.Typeface.mono, size: size).weight(weight)
    }

    // MARK: Semantic Scale

    /// 42pt. Titulos hero de tela.
    static let liquidDisplay = Font.liquidSans(42, weight: .medium)
    /// 28pt. Titulos de secao grandes.
    static let liquidTitle = Font.liquidSans(28, weight: .medium)
    /// 22pt. Subtitulos.
    static let liquidH2 = Font.liquidSans(22, weight: .medium)
    /// 17pt. Headings menores, nomes de item.
    static let liquidH3 = Font.liquidSans(17, weight: .medium)
    /// 14pt. Corpo de texto.
    static let liquidBody = Font.liquidSans(14, weight: .regular)
    /// 12pt. Texto secundario.
    static let liquidSmall = Font.liquidSans(12, weight: .regular)
    /// 10pt mono. Labels ALL CAPS.
    static let liquidMonoLabel = Font.liquidMono(10, weight: .medium)

    /// Numero hero (contador de scan, KPIs). Mono, peso medio, tamanho grande.
    /// Dado numerico em mono mantem o ar de instrumento do Liquid.
    static func liquidHero(_ size: CGFloat = 96) -> Font {
        .liquidMono(size, weight: .medium)
    }
}

// MARK: - Text Style Modifiers
//
// Empacotam fonte, tracking e cor padrao. A cor e sobrescrevivel: basta
// encadear `.foregroundStyle(...)` depois, que o ultimo modifier vence.

extension View {

    func liquidDisplay() -> some View {
        self.font(.liquidDisplay).tracking(-1.0).foregroundStyle(Liquid.fg0)
    }

    func liquidTitle() -> some View {
        self.font(.liquidSans(28, weight: .semibold)).tracking(-0.4).foregroundStyle(Liquid.fg0)
    }

    /// Titulo grande de tela raiz, escala do large title do iOS.
    func liquidLargeTitle() -> some View {
        self.font(.liquidSans(31, weight: .bold)).tracking(-0.7).foregroundStyle(Liquid.fg0)
    }

    /// Titulo de card destacado (hero, item principal de lista).
    func liquidCardTitle() -> some View {
        self.font(.liquidSans(20, weight: .semibold)).tracking(-0.3).foregroundStyle(Liquid.fg0)
    }

    func liquidH2() -> some View {
        self.font(.liquidH2).tracking(-0.3).foregroundStyle(Liquid.fg0)
    }

    func liquidH3() -> some View {
        self.font(.liquidH3).tracking(-0.1).foregroundStyle(Liquid.fg1)
    }

    func liquidBody() -> some View {
        self.font(.liquidBody).foregroundStyle(Liquid.fg1)
    }

    func liquidSmall() -> some View {
        self.font(.liquidSmall).foregroundStyle(Liquid.fg2)
    }

    /// Label mono: ALL CAPS, tracking comedido, cor secundaria por padrao.
    /// Usado em headers de secao, metadados, badges.
    func liquidLabel(_ color: Color = Liquid.fg2) -> some View {
        self
            .font(.liquidMonoLabel)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(color)
    }

    /// Header de secao em sans, sentence case. Substitui o label mono caps
    /// onde a tela pede hierarquia mais calma (estilo lista do iOS).
    func liquidSection(_ color: Color = Liquid.fg2) -> some View {
        self
            .font(.liquidSans(13, weight: .semibold))
            .foregroundStyle(color)
    }

    /// Texto mono de dado (serial, timestamp), sem uppercase.
    func liquidMonoData(_ size: CGFloat = 13, color: Color = Liquid.fg1) -> some View {
        self
            .font(.liquidMono(size, weight: .regular))
            .foregroundStyle(color)
    }
}
