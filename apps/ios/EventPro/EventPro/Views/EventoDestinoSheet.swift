import MapKit
import SwiftUI

// MARK: - Superfície de destino (busca + mapa + edição Uber)

struct EventoDestinoSheet: View {
    @ObservedObject var location: EventLocationViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            if location.canEdit {
                searchField
                suggestionsList
            }
            mapBlock
            footerStatus
        }
        .background(EP.paper)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var handle: some View {
        Capsule()
            .fill(EP.linha)
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Local do evento")
                    .font(EP.secao())
                    .foregroundStyle(EP.ink3)
                Text(location.displayName)
                    .font(EP.itemTitle())
                    .foregroundStyle(EP.ink)
                    .lineLimit(2)
                if !location.addressLine.isEmpty {
                    Text(location.addressLine)
                        .font(EP.secondary())
                        .foregroundStyle(EP.sub)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            Button("Fechar", action: onClose)
                .font(EP.dadosForte())
                .foregroundStyle(EP.ink2)
                .buttonStyle(EPPressStyle())
        }
        .padding(.horizontal, EP.padTela)
        .padding(.bottom, EP.s3)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(EP.ink3)
            TextField("Buscar nome ou endereço", text: $location.query)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    Task { await location.searchNow() }
                }
                .onChange(of: location.query) { _, _ in
                    location.scheduleSearch()
                }
            if location.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(EP.paper2, in: RoundedRectangle(cornerRadius: EP.r12, style: .continuous))
        .padding(.horizontal, EP.padTela)
        .padding(.bottom, EP.s3)
        .accessibilityLabel("Buscar local do evento")
    }

    @ViewBuilder
    private var suggestionsList: some View {
        if let searchError = location.searchError {
            Text(searchError)
                .font(EP.secondary())
                .foregroundStyle(EP.sub)
                .padding(.horizontal, EP.padTela)
                .padding(.bottom, EP.s2)
        } else if location.emptyResults {
            Text("Nenhum resultado. Tente outro nome ou endereço.")
                .font(EP.secondary())
                .foregroundStyle(EP.sub)
                .padding(.horizontal, EP.padTela)
                .padding(.bottom, EP.s2)
        } else if !location.suggestions.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(location.suggestions) { item in
                        Button {
                            Task { await location.selectSuggestion(item) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(EP.dadosForte())
                                    .foregroundStyle(EP.ink)
                                    .lineLimit(1)
                                Text(item.address)
                                    .font(EP.secondary())
                                    .foregroundStyle(EP.sub)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, EP.padTela)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name), \(item.address)")
                        Divider().overlay(EP.linha)
                    }
                }
            }
            .frame(maxHeight: 160)
        }
    }

    private var mapBlock: some View {
        ZStack(alignment: .topTrailing) {
            ExpandedDestinoMap(
                pin: location.pin,
                isEditing: location.isEditingMap,
                onCameraIdle: { coordinate in
                    Task {
                        await location.commitCameraCenter(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        )
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: EP.r14, style: .continuous))
            .padding(.horizontal, EP.padTela)

            if location.canEdit, location.pin != nil {
                editControls
                    .padding(.trailing, EP.padTela + 10)
                    .padding(.top, 10)
            }
        }
        .frame(minHeight: 280)
        .padding(.bottom, EP.s3)
    }

    @ViewBuilder
    private var editControls: some View {
        if location.isEditingMap {
            Button("Concluir") {
                location.cancelMapEdit()
            }
            .font(EP.dadosForte())
            .foregroundStyle(EP.paper)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(EP.ink, in: Capsule())
            .buttonStyle(EPPressStyle())
            .accessibilityLabel("Concluir edição do pin")
        } else {
            Button("Editar local") {
                location.beginMapEdit()
            }
            .font(EP.dadosForte())
            .foregroundStyle(EP.paper)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(EP.ink, in: Capsule())
            .buttonStyle(EPPressStyle())
            .accessibilityLabel("Editar pin do local")
        }
    }

    private var footerStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            if location.isEditingMap {
                Text("Arraste o mapa sob o pin. A posição salva ao soltar.")
                    .font(EP.secondary())
                    .foregroundStyle(EP.sub)
            }

            if location.isSaving {
                Text("Salvando local…")
                    .font(EP.secondary())
                    .foregroundStyle(EP.ink3)
            }

            if let toast = location.toast {
                HStack {
                    Text(toast)
                        .font(EP.dadosForte())
                        .foregroundStyle(EP.ink)
                    Spacer()
                    if location.canUndo {
                        Button("Desfazer") {
                            Task { await location.undo() }
                        }
                        .font(EP.dadosForte())
                        .foregroundStyle(EP.ink2)
                    }
                    Button {
                        location.dismissToast()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(EP.ink3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(EP.paper2, in: RoundedRectangle(cornerRadius: EP.r12, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(toast + (location.canUndo ? ", desfazer disponível" : ""))
            }

            if let saveError = location.saveError {
                Text(saveError)
                    .font(EP.secondary())
                    .foregroundStyle(EP.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EP.paper2, in: RoundedRectangle(cornerRadius: EP.r12, style: .continuous))
            }

            if !location.canEdit {
                Text("Somente leitura. Peça a um editor para ajustar o pin.")
                    .font(EP.secondary())
                    .foregroundStyle(EP.sub)
            }
        }
        .padding(.horizontal, EP.padTela)
        .padding(.bottom, EP.s6)
    }
}
