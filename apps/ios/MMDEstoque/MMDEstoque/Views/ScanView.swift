import SwiftUI

// MARK: - ScanView

/// Main scanning screen. Hero tag count in Doto 72px, scrollable tag list,
/// pill-shaped scan/resolve/clear buttons. Nothing Design System, pure dark.
struct ScanView: View {

    @EnvironmentObject private var rfidManager: RFIDManager
    @EnvironmentObject private var apiClient: APIClient

    @State private var navigateToResults = false
    @State private var resolvedItems: [ResolvedItem] = []
    @State private var unresolvedTags: [String] = []
    @State private var isResolving = false
    @State private var resolveError: String?

    /// Tags that just appeared, shown with a "NEW" badge that fades after 2s.
    @State private var recentTags: Set<String> = []

    /// Drives the subtle pulse on the scan button border while scanning.
    @State private var scanPulse = false

    var body: some View {
        VStack(spacing: 0) {
            heroArea
            tagList
            bottomBar
        }
        .background(Color.ndBlack)
        .navigationTitle("Leitura RFID")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToResults) {
            ScanResultView(
                resolvedItems: resolvedItems,
                unresolvedTags: unresolvedTags
            )
        }
        .onChange(of: rfidManager.scannedTags) { newTags in
            markNewTags(newTags)
        }
        .onDisappear {
            if rfidManager.isScanning {
                rfidManager.stopInventory()
            }
        }
    }

    // MARK: - Hero Area

    private var heroArea: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: NDSpacing.vast)

            // Hero number
            Text("\(rfidManager.tagCount)")
                .font(.displayXL)
                .foregroundStyle(Color.ndTextDisplay)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: rfidManager.tagCount)

            // Label below
            Text("TAGS")
                .font(.spaceMono(11))
                .tracking(11 * 0.08)
                .foregroundStyle(Color.ndTextSecondary)
                .padding(.top, NDSpacing.tight)

            Spacer()
                .frame(height: NDSpacing.vast)

            // Empty state hint
            if !rfidManager.isScanning && rfidManager.tagCount == 0 {
                Text("APONTE O LEITOR E PRESSIONE ESCANEAR")
                    .font(.spaceMono(11))
                    .tracking(11 * 0.08)
                    .foregroundStyle(Color.ndTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NDSpacing.wide)
                    .padding(.bottom, NDSpacing.section)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tag List

    private var tagList: some View {
        Group {
            if rfidManager.scannedTags.isEmpty {
                Spacer()
            } else {
                VStack(spacing: 0) {
                    // 1px top border
                    Rectangle()
                        .fill(Color.ndBorder)
                        .frame(height: 1)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(rfidManager.scannedTags.reversed(), id: \.self) { tag in
                                tagRow(tag)

                                // 1px separator
                                Rectangle()
                                    .fill(Color.ndBorder)
                                    .frame(height: 1)
                                    .padding(.leading, NDSpacing.medium)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func tagRow(_ tag: String) -> some View {
        HStack(spacing: NDSpacing.compact) {
            Text(tag)
                .font(.spaceMono(14))
                .foregroundStyle(Color.ndTextPrimary)
                .lineLimit(1)

            Spacer()

            if recentTags.contains(tag) {
                newBadge
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, NDSpacing.medium)
        .padding(.vertical, 14)
    }

    /// "NEW" badge in StatusBadge style with ndSuccess color.
    private var newBadge: some View {
        Text("NEW")
            .font(.ndLabelSm)
            .textCase(.uppercase)
            .tracking(9 * 0.08)
            .foregroundStyle(Color.ndSuccess)
            .padding(.horizontal, NDSpacing.base)
            .padding(.vertical, NDSpacing.tight)
            .background(
                Capsule()
                    .strokeBorder(Color.ndSuccess, lineWidth: 1)
            )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Error display
            if let error = resolveError {
                Text(error)
                    .font(.spaceMono(11))
                    .foregroundStyle(Color.ndAccent)
                    .padding(.horizontal, NDSpacing.medium)
                    .padding(.vertical, NDSpacing.base)
            }

            // 1px top border
            Rectangle()
                .fill(Color.ndBorder)
                .frame(height: 1)

            HStack(spacing: NDSpacing.compact) {
                // LIMPAR - text only
                Button {
                    rfidManager.clearTags()
                    recentTags.removeAll()
                    resolveError = nil
                } label: {
                    Text("LIMPAR")
                        .font(.spaceMono(11))
                        .tracking(11 * 0.08)
                        .foregroundStyle(
                            rfidManager.tagCount > 0
                                ? Color.ndTextSecondary
                                : Color.ndTextDisabled
                        )
                }
                .disabled(rfidManager.tagCount == 0)

                Spacer()

                // RESOLVER - pill outline
                Button {
                    Task { await resolveTags() }
                } label: {
                    HStack(spacing: NDSpacing.base) {
                        if isResolving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Color.ndTextPrimary)
                        }

                        Text("RESOLVER")
                            .font(.spaceMono(13))
                            .tracking(13 * 0.08)
                    }
                    .foregroundStyle(
                        rfidManager.tagCount > 0 && !isResolving
                            ? Color.ndTextPrimary
                            : Color.ndTextDisabled
                    )
                    .padding(.horizontal, NDSpacing.section)
                    .padding(.vertical, NDSpacing.compact)
                    .background(
                        Capsule()
                            .strokeBorder(
                                rfidManager.tagCount > 0 && !isResolving
                                    ? Color.ndBorderVisible
                                    : Color.ndBorder,
                                lineWidth: 1
                            )
                    )
                }
                .disabled(rfidManager.tagCount == 0 || isResolving)

                // ESCANEAR / PARAR - pill filled or outline
                Button {
                    toggleScanning()
                } label: {
                    Text(rfidManager.isScanning ? "PARAR" : "ESCANEAR")
                        .font(.spaceMono(13))
                        .tracking(13 * 0.08)
                        .foregroundStyle(
                            rfidManager.isScanning
                                ? Color.ndTextDisplay
                                : Color.ndBlack
                        )
                        .padding(.horizontal, NDSpacing.section)
                        .padding(.vertical, NDSpacing.compact)
                        .background(
                            Group {
                                if rfidManager.isScanning {
                                    Capsule()
                                        .strokeBorder(Color.ndTextDisplay, lineWidth: 1)
                                        .opacity(scanPulse ? 0.6 : 1.0)
                                } else {
                                    Capsule()
                                        .fill(Color.white)
                                }
                            }
                        )
                        .scaleEffect(rfidManager.isScanning && scanPulse ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .onChange(of: rfidManager.isScanning) { scanning in
                    if scanning {
                        withAnimation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                        ) {
                            scanPulse = true
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.3)) {
                            scanPulse = false
                        }
                    }
                }
                .accessibilityLabel(rfidManager.isScanning ? "Parar leitura" : "Iniciar leitura")
            }
            .padding(.horizontal, NDSpacing.medium)
            .padding(.vertical, NDSpacing.compact)
        }
        .background(Color.ndBlack)
    }

    // MARK: - Actions

    private func toggleScanning() {
        if rfidManager.isScanning {
            rfidManager.stopInventory()
        } else {
            rfidManager.startInventory()
        }
    }

    private func resolveTags() async {
        let tags = rfidManager.scannedTags
        guard !tags.isEmpty else { return }

        isResolving = true
        resolveError = nil

        do {
            let result = try await apiClient.resolveRfidTags(tags)
            resolvedItems = result.resolved
            unresolvedTags = result.unresolved
            navigateToResults = true
        } catch {
            resolveError = error.localizedDescription
        }

        isResolving = false
    }

    // MARK: - New Tag Tracking

    /// When new tags appear, add them to the "recent" set and schedule
    /// their removal after 2 seconds so the NEW badge fades out.
    private func markNewTags(_ allTags: [String]) {
        let allSet = Set(allTags)
        let newOnes = allSet.subtracting(recentTags.union(Set(rfidManager.scannedTags)))

        guard !newOnes.isEmpty else { return }

        withAnimation(.easeIn(duration: 0.2)) {
            recentTags.formUnion(newOnes)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                recentTags.subtract(newOnes)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScanView()
                .environmentObject(RFIDManager())
                .environmentObject(APIClient())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
