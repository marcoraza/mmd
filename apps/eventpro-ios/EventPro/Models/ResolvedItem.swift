import Foundation

/// Resultado de um scan (RFID ou QR) já resolvido: o serial mais o item pai.
///
/// **Camada de dados pura.** Não importa SwiftUI e não expõe cor nenhuma: cor
/// de categoria e cor de status são decisão de apresentação e vivem na camada
/// de view (fase 7 do plano de migração). O legado misturava os dois e amarrava
/// o modelo ao design system morto.
struct ResolvedItem: Identifiable, Equatable {
    let serialNumber: SerialNumber
    let equipment: Equipment

    /// RSSI de pico da leitura que produziu este resultado, em dBm, quando o
    /// leitor reporta. `nil` para QR, mock sem RSSI e retorno de API.
    let rssi: Int?

    init(serialNumber: SerialNumber, equipment: Equipment, rssi: Int? = nil) {
        self.serialNumber = serialNumber
        self.equipment = equipment
        self.rssi = rssi
    }

    var id: UUID { serialNumber.id }

    // MARK: - Display Properties

    /// "Marca Modelo" ou o nome do item.
    var displayName: String {
        equipment.displayName
    }

    /// Código interno, ex.: "MMD-ILU-0001".
    var codigoInterno: String {
        serialNumber.codigoInterno
    }

    var categoria: Categoria {
        equipment.categoria
    }

    var statusLabel: String {
        serialNumber.status.displayName
    }

    /// Estado do ciclo de vida mais desgaste, ex.: "Usado — Regular".
    var condicaoLabel: String {
        "\(serialNumber.estado.displayName) — \(serialNumber.desgasteLabel)"
    }

    var valorFormatado: String? {
        serialNumber.valorAtualFormatado
    }

    static func == (lhs: ResolvedItem, rhs: ResolvedItem) -> Bool {
        lhs.serialNumber.id == rhs.serialNumber.id && lhs.rssi == rhs.rssi
    }
}
