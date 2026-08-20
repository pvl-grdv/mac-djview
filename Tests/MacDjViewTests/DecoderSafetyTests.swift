import Foundation
import Testing
@testable import MacDjView

@Suite("Decoder safety limits")
struct DecoderSafetyTests {
    private func be32(_ value: Int) -> [UInt8] {
        let v = UInt32(value)
        return [
            UInt8((v >> 24) & 0xFF),
            UInt8((v >> 16) & 0xFF),
            UInt8((v >> 8) & 0xFF),
            UInt8(v & 0xFF),
        ]
    }

    private func form(type: String = "DJVU", children: [UInt8] = []) -> [UInt8] {
        let payloadLength = 4 + children.count
        var bytes = Array("FORM".utf8) + be32(payloadLength) + Array(type.utf8) + children
        if payloadLength % 2 != 0 {
            bytes.append(0)
        }
        return bytes
    }

    private func leaf(id: String, payload: [UInt8], includePadding: Bool = true) -> [UInt8] {
        var bytes = Array(id.utf8) + be32(payload.count) + payload
        if includePadding && payload.count % 2 != 0 {
            bytes.append(0)
        }
        return bytes
    }

    @Test("checked arithmetic rejects integer overflow")
    func checkedArithmetic() {
        #expect(throws: DjVuError.self) {
            try DecodeLimits.checkedAdd(Int.max, 1, context: "test")
        }
        #expect(throws: DjVuError.self) {
            try DecodeLimits.checkedMultiply(Int.max, 2, context: "test")
        }
    }

    @Test("bounded file loader never reads beyond its limit")
    func boundedFileLoader() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacDjView-safety-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data([1, 2, 3, 4]).write(to: url)

        #expect(throws: DjVuError.self) {
            try SafeFileLoader.read(url: url, maxBytes: 3)
        }
        #expect(try SafeFileLoader.read(url: url, maxBytes: 4) == Data([1, 2, 3, 4]))
    }

    @Test("oversized page dimensions are rejected before allocation")
    func oversizedPage() {
        #expect(throws: DjVuError.self) {
            try DecodeLimits.validatePage(width: 65_535, height: 65_535)
        }
    }

    @Test("oversized JB2 bitmap is rejected before allocation")
    func oversizedJB2Bitmap() {
        #expect(throws: DjVuError.self) {
            try JB2Bitmap.validated(width: 65_535, height: 65_535)
        }
    }

    @Test("valid empty FORM parses")
    func validEmptyFORM() throws {
        let data = Data(Array("AT&T".utf8) + form())
        let root = try IFFParser.parse(data: data)
        #expect(root.id == "FORM")
        #expect(root.formType == "DJVU")
    }

    @Test("FORM length smaller than form type is rejected")
    func shortFORM() {
        let data = Data(Array("AT&TFORM".utf8) + be32(3))
        #expect(throws: DjVuError.self) {
            try IFFParser.parse(data: data)
        }
    }

    @Test("child chunk cannot overrun parent FORM")
    func childOverrun() {
        let childHeader = Array("TEST".utf8) + be32(100)
        let data = Data(Array("AT&T".utf8) + form(children: childHeader))
        #expect(throws: DjVuError.self) {
            try IFFParser.parse(data: data)
        }
    }

    @Test("odd IFF leaf requires and accepts padding")
    func oddLeafPadding() throws {
        let padded = Data(Array("AT&T".utf8) + form(children: leaf(id: "TEST", payload: [1])))
        let root = try IFFParser.parse(data: padded)
        #expect(root.children.count == 1)
        #expect(root.children[0].data == Data([1]))

        let unpaddedChild = leaf(id: "TEST", payload: [1], includePadding: false)
        let malformed = Data(Array("AT&T".utf8) + form(children: unpaddedChild))
        #expect(throws: DjVuError.self) {
            try IFFParser.parse(data: malformed)
        }
    }

    @Test("excessive IFF nesting is rejected")
    func excessiveNesting() {
        var nested = form()
        for _ in 0...DecodeLimits.maxIFFDepth {
            nested = form(children: nested)
        }
        let data = Data(Array("AT&T".utf8) + nested)
        #expect(throws: DjVuError.self) {
            try IFFParser.parse(data: data)
        }
    }

    @Test("rendered pixel budget is checked before CGContext allocation")
    func renderedPixelBudget() {
        #expect(throws: DjVuError.self) {
            try PageCompositor.compose(
                width: 6_000,
                height: 6_000,
                background: nil,
                foreground: nil,
                mask: nil,
                fgPalette: nil,
                scale: 2.0
            )
        }
    }

    @Test("invalid render scale is rejected")
    func invalidRenderScale() {
        #expect(throws: DjVuError.self) {
            try PageCompositor.compose(
                width: 10,
                height: 10,
                background: nil,
                foreground: nil,
                mask: nil,
                fgPalette: nil,
                scale: .infinity
            )
        }
    }
}
