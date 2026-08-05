import XCTest
@testable import EventPro

/// Divergência D2 de `docs/contratos-api.md`: a normalização de tag precisa ser
/// idêntica à do servidor, senão o casamento entre o que o app leu e o que a
/// API devolveu quebra em silêncio, sem erro HTTP.
final class RfidTagNormalizerTests: XCTestCase {

    // MARK: - normalize

    func testNormalizeUpperCases() {
        XCTAssertEqual(
            RfidTagNormalizer.normalize("e28011702000020a5c41b6e0"),
            "E28011702000020A5C41B6E0"
        )
    }

    func testNormalizeRemovesSeparators() {
        XCTAssertEqual(
            RfidTagNormalizer.normalize("E2:80:11:70:20:00:02:0A:5C:41:B6:E0"),
            "E28011702000020A5C41B6E0"
        )
        XCTAssertEqual(
            RfidTagNormalizer.normalize("E280-1170-2000-020A-5C41-B6E0"),
            "E28011702000020A5C41B6E0"
        )
        XCTAssertEqual(
            RfidTagNormalizer.normalize("E280 1170 2000 020A 5C41 B6E0"),
            "E28011702000020A5C41B6E0"
        )
    }

    func testNormalizeTrims() {
        XCTAssertEqual(
            RfidTagNormalizer.normalize("  e28011702000020a5c41b6e0\n"),
            "E28011702000020A5C41B6E0"
        )
    }

    func testNormalizeIsIdempotent() {
        let once = RfidTagNormalizer.normalize("e2:80-11 70")
        XCTAssertEqual(RfidTagNormalizer.normalize(once), once)
    }

    // MARK: - isValid

    func testValidTagPassesServerRule() {
        XCTAssertTrue(RfidTagNormalizer.isValid("E28011702000020A5C41B6E0"))
        XCTAssertTrue(RfidTagNormalizer.isValid("ABCD1234"))  // limite inferior: 8
    }

    func testTooShortIsInvalid() {
        XCTAssertFalse(RfidTagNormalizer.isValid("ABC1234"))  // 7
    }

    func testTooLongIsInvalid() {
        XCTAssertFalse(RfidTagNormalizer.isValid(String(repeating: "A", count: 97)))
        XCTAssertTrue(RfidTagNormalizer.isValid(String(repeating: "A", count: 96)))
    }

    func testNonAlphanumericIsInvalid() {
        XCTAssertFalse(RfidTagNormalizer.isValid("E2801170_ABCD"))
        XCTAssertFalse(RfidTagNormalizer.isValid("E2801170.ABCD"))
        XCTAssertFalse(RfidTagNormalizer.isValid("E2801170abcd"))  // já deveria vir maiúscula
    }

    func testEmptyIsInvalid() {
        XCTAssertFalse(RfidTagNormalizer.isValid(""))
    }

    // MARK: - normalizeIfValid

    func testNormalizeIfValidAcceptsSeparatedHex() {
        XCTAssertEqual(
            RfidTagNormalizer.normalizeIfValid("e2:80:11:70:20:00:02:0a"),
            "E28011702000020A"
        )
    }

    func testNormalizeIfValidRejectsGarbage() {
        XCTAssertNil(RfidTagNormalizer.normalizeIfValid("nao é uma tag"))
        XCTAssertNil(RfidTagNormalizer.normalizeIfValid("---"))
    }

    // MARK: - normalizeBatch

    func testBatchDeduplicatesPreservingArrivalOrder() {
        let raws = [
            "E28011702000020A5C41B6E0",
            "e2:80:11:70:20:00:02:0a:5c:41:b7:f1",
            "e28011702000020a5c41b6e0",  // repetida, chegou depois
            "E28011702000020A5C41B802",
        ]

        let (valid, invalid) = RfidTagNormalizer.normalizeBatch(raws)

        XCTAssertTrue(invalid.isEmpty)
        XCTAssertEqual(
            valid,
            [
                "E28011702000020A5C41B6E0",
                "E28011702000020A5C41B7F1",
                "E28011702000020A5C41B802",
            ],
            "Ordem de chegada precisa ser preservada, e a duplicata sai sem reordenar o resto"
        )
    }

    func testBatchSeparatesInvalidTags() {
        let (valid, invalid) = RfidTagNormalizer.normalizeBatch([
            "E28011702000020A5C41B6E0",
            "curta",
            "com espaço e acentuação",
        ])

        XCTAssertEqual(valid, ["E28011702000020A5C41B6E0"])
        XCTAssertEqual(invalid.count, 2)
    }

    func testBatchOfEmptyStringsProducesNothing() {
        let (valid, invalid) = RfidTagNormalizer.normalizeBatch(["", "   "])
        XCTAssertTrue(valid.isEmpty)
        XCTAssertTrue(invalid.isEmpty, "String vazia não é 'tag inválida', é ausência de tag")
    }
}
