import Foundation
import SwiftUI

/// Represents a resolved RFID/QR scan result, combining the serial number
/// with its parent equipment info. Used by ScanResultView to display
/// enriched item data after a tag is read.
struct ResolvedItem: Identifiable {
    let serialNumber: SerialNumber
    let equipment: Equipment

    var id: UUID { serialNumber.id }

    // MARK: - Display Properties

    /// e.g. "Marca Modelo" or equipment name.
    var displayName: String {
        equipment.displayName
    }

    /// The internal code, e.g. "MMD-ILU-0001".
    var codigoInterno: String {
        serialNumber.codigoInterno
    }

    /// Category of the parent equipment.
    var categoria: Categoria {
        equipment.categoria
    }

    /// Human-readable status label.
    var statusLabel: String {
        serialNumber.status.displayName
    }

    /// Human-readable condition (estado + desgaste).
    var condicaoLabel: String {
        "\(serialNumber.estado.displayName) — \(serialNumber.desgasteLabel)"
    }

    /// Color associated with the equipment category (from Nothing Design System).
    var categoryColor: Color {
        equipment.categoria.color
    }

    /// Color representing the current status (from Nothing Design System).
    var statusColor: Color {
        serialNumber.status.color
    }

    /// Formatted current value, if available.
    var valorFormatado: String? {
        serialNumber.valorAtualFormatado
    }
}
