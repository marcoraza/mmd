import SwiftUI

// MARK: - Tour Domain Models

/// Identifies each guided tour. Used for persistence keys and lookup.
enum TourID: String, CaseIterable {
    case orientacao
    case checkout
    case retorno
}

/// UI elements a step can anchor to (spotlight + card position).
enum TourTarget: String, Hashable {
    case heroCard
    case kpiCard
    case plusButton
    case eventosTab
    case readerStatus
    case packingHero
    case openCheckout
    case checkoutScan
    case retornoHeader
}

/// Whether the step is passive (info) or waits for a real user action.
enum StepKind {
    case info
    case action
}

/// How a step advances to the next one.
enum AdvanceRule: Equatable {
    /// Waits for the user to tap the card's primary button.
    case tapNext
    /// Advances on its own after `seconds`; the card still shows a button to skip ahead.
    case autoAfter(TimeInterval)
    /// Waits until the user performs the real action on `target`.
    case onAction(TourTarget)
}

/// A single step: what to highlight, what to say, and how to move on.
struct TourStep: Identifiable {
    let id = UUID()
    /// Element to spotlight. `nil` renders a centered card with no cutout.
    let target: TourTarget?
    /// Tab the step lives on. `nil` leaves the current tab untouched (deep flow steps).
    let tab: LiquidTab?
    /// Benefit-first headline.
    let title: String
    let body: String
    let kind: StepKind
    let advance: AdvanceRule
    /// Short prompt shown on `.action` steps, e.g. "Abra o check-out".
    let actionHint: String?
}

/// An ordered list of steps under one `TourID`.
struct Tour {
    let id: TourID
    let steps: [TourStep]
}
