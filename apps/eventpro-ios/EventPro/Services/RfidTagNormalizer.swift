import Foundation

/// Normalização de tag RFID **espelhada do servidor** (`normalizeRfidTag`,
/// `apps/web/src/lib/rfid-scan-core.ts`).
///
/// Corrige a divergência D2 de `docs/contratos-api.md`: o app legado mandava a
/// tag crua do leitor e depois tentava casar a resposta (já normalizada pelo
/// servidor) contra a lista local crua. Enquanto o EPC vier em hexadecimal
/// maiúsculo sem separador os dois conjuntos coincidem; qualquer formatação
/// diferente — e o SDK Zebra real pode entregar com separador — quebra o
/// casamento em silêncio, sem erro HTTP.
///
/// Regra do servidor, byte a byte:
/// 1. `trim()`
/// 2. `toUpperCase()`
/// 3. remoção de espaço, `:` e `-`
/// 4. válida se casa `^[A-Z0-9]+$` e tem 8 a 96 caracteres
///
/// O lote inteiro é recusado se **uma** tag for inválida (`tags_invalidas`):
/// não existe aceite parcial. Por isso o cliente filtra antes de enviar e
/// avisa, em vez de deixar o servidor derrubar o lote todo.
enum RfidTagNormalizer {

    static let minLength = 8
    static let maxLength = 96

    private static let separators: Set<Character> = [" ", ":", "-"]

    /// Normaliza uma tag. Não valida.
    static func normalize(_ raw: String) -> String {
        var out = String()
        out.reserveCapacity(raw.count)
        for character in raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        where !separators.contains(character) {
            out.append(character)
        }
        return out
    }

    /// `true` se a tag **já normalizada** passa na validação do servidor.
    static func isValid(_ normalized: String) -> Bool {
        guard normalized.count >= minLength, normalized.count <= maxLength else { return false }
        return normalized.allSatisfy { character in
            character.isASCII && (character.isNumber || ("A"..."Z").contains(character))
        }
    }

    /// Normaliza e valida numa tacada.
    static func normalizeIfValid(_ raw: String) -> String? {
        let normalized = normalize(raw)
        return isValid(normalized) ? normalized : nil
    }

    /// Normaliza, descarta inválidas e deduplica **preservando a ordem de
    /// chegada**, igual ao servidor.
    static func normalizeBatch(_ raws: [String]) -> (valid: [String], invalid: [String]) {
        var valid: [String] = []
        var invalid: [String] = []
        var seen = Set<String>()

        for raw in raws {
            let normalized = normalize(raw)
            guard isValid(normalized) else {
                // Entrada que normaliza para vazio é ausência de tag, não tag
                // inválida: não faz sentido derrubar o lote por causa dela.
                if !normalized.isEmpty {
                    invalid.append(raw)
                }
                continue
            }
            if seen.insert(normalized).inserted {
                valid.append(normalized)
            }
        }

        return (valid, invalid)
    }

    /// Só as válidas, na ordem de leitura.
    static func normalized(_ raws: [String]) -> [String] {
        normalizeBatch(raws).valid
    }
}
