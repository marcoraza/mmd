import Foundation

// MARK: - PackingListItem

/// Maps to the Supabase "packing_list" table.
struct PackingListItem: Identifiable, Codable, Hashable {
    let id: UUID
    var projetoId: UUID
    var itemId: UUID
    var quantidade: Int
    var serialNumbersDesignados: [UUID]? = nil
    var notas: String? = nil

    /// Nested equipment from PostgREST join: select=*,item:items(*)
    var item: Equipment? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case projetoId = "projeto_id"
        case itemId = "item_id"
        case quantidade
        case serialNumbersDesignados = "serial_numbers_designados"
        case notas
        case item
    }

    // MARK: - Hashable (exclude optional nested item)

    static func == (lhs: PackingListItem, rhs: PackingListItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - PackingListItem + Display Helpers

extension PackingListItem {

    /// Display name from the joined equipment, or a fallback with the item ID prefix.
    var displayName: String {
        item?.displayName ?? "Item \(itemId.uuidString.prefix(8))"
    }
}
