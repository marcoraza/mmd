import SwiftUI

// MARK: - TourController

/// Drives an active tour: which step is showing, when to advance, and which tab
/// the app should be on. Owns no view state beyond that, so it stays testable.
@MainActor
final class TourController: ObservableObject {

    @Published private(set) var activeTour: Tour?
    @Published private(set) var currentIndex: Int = 0

    /// The tab the current step wants the app to show. LiquidRoot observes this.
    @Published var requestedTab: LiquidTab?

    private var autoAdvanceTask: Task<Void, Never>?

    var isActive: Bool { activeTour != nil }

    var currentStep: TourStep? {
        guard let tour = activeTour, currentIndex >= 0, currentIndex < tour.steps.count else {
            return nil
        }
        return tour.steps[currentIndex]
    }

    var stepNumber: Int { currentIndex + 1 }
    var stepCount: Int { activeTour?.steps.count ?? 0 }

    // MARK: - Lifecycle

    func start(_ tour: Tour) {
        cancelAutoAdvance()
        guard !tour.steps.isEmpty else { return }
        activeTour = tour
        currentIndex = 0
        applyStepSideEffects()
    }

    /// Advances to the next step, or finishes if this was the last one.
    func next() {
        guard let tour = activeTour else { return }
        cancelAutoAdvance()
        let target = currentIndex + 1
        if target >= tour.steps.count {
            finish(markDone: true)
        } else {
            currentIndex = target
            applyStepSideEffects()
        }
    }

    /// User dismissed the tour. Counts as seen so it does not reappear.
    func skip() {
        finish(markDone: true)
    }

    func complete() {
        finish(markDone: true)
    }

    /// Called when the user performs a real action. Advances only if the current
    /// step is an `.action` waiting on exactly this target.
    func notifyAction(_ target: TourTarget) {
        guard let step = currentStep, step.kind == .action else { return }
        if case .onAction(let expected) = step.advance, expected == target {
            next()
        }
    }

    // MARK: - Private

    private func finish(markDone: Bool) {
        cancelAutoAdvance()
        if markDone, let tour = activeTour {
            AppConfig.shared.markTourDone(tour.id)
        }
        activeTour = nil
        currentIndex = 0
        requestedTab = nil
    }

    private func applyStepSideEffects() {
        guard let step = currentStep else { return }
        if let tab = step.tab {
            requestedTab = tab
        }
        scheduleAutoAdvanceIfNeeded(for: step)
    }

    private func scheduleAutoAdvanceIfNeeded(for step: TourStep) {
        guard case .autoAfter(let delay) = step.advance else { return }
        autoAdvanceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.next()
        }
    }

    private func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
    }
}
