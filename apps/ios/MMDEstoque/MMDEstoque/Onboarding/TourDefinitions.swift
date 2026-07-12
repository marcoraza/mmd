import Foundation

// MARK: - Tour Content

/// The concrete tours. Content only, no mechanics: copy is benefit-first, the
/// engine handles anchoring, spotlight, and advancing.
enum TourDefinitions {

    static func tour(for id: TourID) -> Tour {
        switch id {
        case .orientacao: return orientacao
        case .checkout:   return checkout
        case .retorno:    return retorno
        }
    }

    /// First-run orientation across the Início cockpit and the tabs. Auto-advances
    /// with animation; the card always offers "Próximo" to move ahead sooner.
    static let orientacao = Tour(id: .orientacao, steps: [
        TourStep(
            target: nil,
            tab: .inicio,
            title: "Seu estoque cabe no bolso",
            body: "Um tour rápido pra você dominar o essencial. Menos de um minuto.",
            kind: .info,
            advance: .autoAfter(5),
            actionHint: nil
        ),
        TourStep(
            target: .heroCard,
            tab: .inicio,
            title: "Seu próximo evento, pronto pra sair",
            body: "O evento mais perto abre aqui, com a prontidão da packing list de um olhar.",
            kind: .info,
            advance: .autoAfter(5),
            actionHint: nil
        ),
        TourStep(
            target: .kpiCard,
            tab: .inicio,
            title: "Estoque em números, ao vivo",
            body: "Quanto está disponível, em campo e em manutenção. Sempre do Supabase, nunca chute.",
            kind: .info,
            advance: .autoAfter(5),
            actionHint: nil
        ),
        TourStep(
            target: .plusButton,
            tab: .inicio,
            title: "Toda operação começa aqui",
            body: "Identificar, despachar, receber e etiquetar, a um toque de qualquer tela.",
            kind: .info,
            advance: .autoAfter(5),
            actionHint: nil
        ),
        TourStep(
            target: .eventosTab,
            tab: .eventos,
            title: "Seus eventos, por status",
            body: "A sair, em campo ou todos. Cada evento leva direto à packing list.",
            kind: .info,
            advance: .autoAfter(5),
            actionHint: nil
        ),
        TourStep(
            target: .readerStatus,
            tab: .inicio,
            title: "Conecte o leitor e comece",
            body: "O RFD40 pareia aqui pra ler as tags. Pronto pra rodar o primeiro evento.",
            kind: .info,
            advance: .tapNext,
            actionHint: nil
        ),
    ])

    /// Check-out walkthrough. Starts when an event's packing list is opened and
    /// stays inside the flow. The middle step waits for the real tap; the app
    /// navigates into the validation screen and the tour follows.
    static let checkout = Tour(id: .checkout, steps: [
        TourStep(
            target: .packingHero,
            tab: nil,
            title: "Sua packing list, item a item",
            body: "Tudo que sai pra este evento. Confira antes de dar saída.",
            kind: .info,
            advance: .tapNext,
            actionHint: nil
        ),
        TourStep(
            target: .openCheckout,
            tab: nil,
            title: "Dê saída no evento",
            body: "O check-out valida cada peça contra a lista, sem margem pra erro.",
            kind: .action,
            advance: .onAction(.openCheckout),
            actionHint: "Abra o check-out"
        ),
        TourStep(
            target: .checkoutScan,
            tab: nil,
            title: "Cada leitura bate contra a lista",
            body: "Aponte o leitor: o progresso sobe em tempo real e libera a saída quando tudo bate.",
            kind: .info,
            advance: .tapNext,
            actionHint: nil
        ),
    ])

    /// Retorno / check-in. Fecha o ciclo do evento: o material volta do campo,
    /// cada peça conferida e a volta registrada. Dispara ao abrir a validação
    /// de um evento em campo.
    static let retorno = Tour(id: .retorno, steps: [
        TourStep(
            target: .retornoHeader,
            tab: nil,
            title: "O material voltou do campo",
            body: "Aqui você recebe de volta o que saiu pra este evento e confere peça por peça.",
            kind: .info,
            advance: .tapNext,
            actionHint: nil
        ),
        TourStep(
            target: .retornoHeader,
            tab: nil,
            title: "Cada peça volta conferida",
            body: "OK volta pro estoque na hora. Defeito vai pra manutenção com desgaste e nota. Aí é só confirmar a volta.",
            kind: .info,
            advance: .tapNext,
            actionHint: nil
        ),
    ])
}
