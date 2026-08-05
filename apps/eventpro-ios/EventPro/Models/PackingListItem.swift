import Foundation

// MARK: - PackingListItem

/// Espelha a tabela `packing_list` do Supabase.
///
/// `serialNumbersDesignados` é a coluna legada `uuid[]`; a alocação real vive
/// em `packing_allocations` (UNIQUE por serial). Enquanto a coluna existir, ela
/// continua sendo a fonte de "quais seriais esta linha espera".
struct PackingListItem: Identifiable, Codable, Hashable {
    let id: UUID
    var projetoId: UUID
    var itemId: UUID
    var quantidade: Int
    var serialNumbersDesignados: [UUID]? = nil
    var notas: String? = nil

    /// Item pai do join PostgREST: `select=*,item:items(*)`.
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

    // MARK: - Hashable (ignora o item aninhado)

    static func == (lhs: PackingListItem, rhs: PackingListItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - PackingListItem + Display Helpers

extension PackingListItem {

    var displayName: String {
        item?.displayName ?? "Item \(itemId.uuidString.prefix(8))"
    }

    /// Seriais designados, ou lista vazia.
    var designados: [UUID] {
        serialNumbersDesignados ?? []
    }
}
