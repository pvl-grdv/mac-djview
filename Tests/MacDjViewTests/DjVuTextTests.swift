import Foundation
import Testing
@testable import MacDjView

@Suite("DjVu embedded text")
struct DjVuTextTests {
    private func u24(_ value: Int) -> [UInt8] {
        let v = UInt32(value)
        return [
            UInt8((v >> 16) & 0xFF),
            UInt8((v >> 8) & 0xFF),
            UInt8(v & 0xFF),
        ]
    }

    private func biased16(_ value: Int) -> [UInt8] {
        let encoded = UInt16(value + 0x8000)
        return [UInt8(encoded >> 8), UInt8(encoded & 0xFF)]
    }

    private func zone(
        kind: DjVuTextZoneKind,
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        textStart: Int,
        textLength: Int,
        children: [[UInt8]] = []
    ) -> [UInt8] {
        [kind.rawValue]
            + biased16(x)
            + biased16(y)
            + biased16(width)
            + biased16(height)
            + biased16(textStart)
            + u24(textLength)
            + u24(children.count)
            + children.flatMap { $0 }
    }

    private func payload(text: String, rootZone: [UInt8]? = nil) -> Data {
        let utf8 = Array(text.utf8)
        var bytes = u24(utf8.count) + utf8
        if let rootZone {
            bytes.append(1) // DjVuTXT::Zone::version
            bytes += rootZone
        }
        return Data(bytes)
    }

    @Test("text-only TXTa is valid")
    func textOnly() throws {
        let layer = try DjVuTextDecoder.parse(
            payload: payload(text: "Привет, мир"),
            pageHeight: 1000
        )
        #expect(layer.text == "Привет, мир")
        #expect(layer.rootZone == nil)
    }

    @Test("Russian UTF-8 byte ranges and delta-encoded word zones decode")
    func russianWordZones() throws {
        let text = "Привет мир"
        let firstWordLength = "Привет".utf8.count
        let secondWordStart = "Привет ".utf8.count
        let secondWordLength = "мир".utf8.count

        // Desired native DjVu rectangles (bottom-left origin):
        // first word:  x=100, y=100, w=80, h=20
        // second word: x=200, y=100, w=45, h=20
        // Child fields are encoded relative to parent / previous sibling.
        let firstWord = zone(
            kind: .word,
            x: 100,
            y: 880, // parent top 1000 - (100 + 20)
            width: 80,
            height: 20,
            textStart: 0,
            textLength: firstWordLength
        )
        let secondWord = zone(
            kind: .word,
            x: 20, // 200 - previous right edge 180
            y: 0,
            width: 45,
            height: 20,
            textStart: secondWordStart - firstWordLength,
            textLength: secondWordLength
        )
        let root = zone(
            kind: .page,
            x: 0,
            y: 0,
            width: 800,
            height: 1000,
            textStart: 0,
            textLength: text.utf8.count,
            children: [firstWord, secondWord]
        )

        let layer = try DjVuTextDecoder.parse(
            payload: payload(text: text, rootZone: root),
            pageHeight: 1000
        )
        let page = try #require(layer.rootZone)
        #expect(page.kind == .page)
        #expect(page.rect == DjVuTextRect(x: 0, y: 0, width: 800, height: 1000))
        #expect(page.children.count == 2)

        let first = page.children[0]
        let second = page.children[1]
        #expect(first.rect == DjVuTextRect(x: 100, y: 880, width: 80, height: 20))
        #expect(second.rect == DjVuTextRect(x: 200, y: 880, width: 45, height: 20))
        #expect(layer.string(in: first.textByteRange) == "Привет")
        #expect(layer.string(in: second.textByteRange) == "мир")
        #expect(layer.leafZones(overlapping: second.textByteRange) == [second])
    }

    @Test("DjVu structural separators normalize for search and indexing")
    func separatorNormalization() throws {
        let raw = "one\u{000B}two\u{001D}three\u{001F}four\u{0000}five"
        let layer = try DjVuTextDecoder.parse(payload: payload(text: raw), pageHeight: 100)
        #expect(layer.plainText == "one\ntwo\nthree\nfour five")
    }

    @Test("unsupported text zone version is rejected")
    func badVersion() {
        let bytes = u24(1) + [0x41, 2]
        #expect(throws: DjVuError.self) {
            try DjVuTextDecoder.parse(payload: Data(bytes), pageHeight: 100)
        }
    }

    @Test("invalid UTF-8 is rejected")
    func invalidUTF8() {
        let bytes = u24(2) + [0xC3, 0x28]
        #expect(throws: DjVuError.self) {
            try DjVuTextDecoder.parse(payload: Data(bytes), pageHeight: 100)
        }
    }

    @Test("zone text range cannot extend beyond page text")
    func zoneRangeOverflow() {
        let root = zone(
            kind: .page,
            x: 0,
            y: 0,
            width: 100,
            height: 100,
            textStart: 0,
            textLength: 2
        )
        #expect(throws: DjVuError.self) {
            try DjVuTextDecoder.parse(
                payload: payload(text: "A", rootZone: root),
                pageHeight: 100
            )
        }
    }

    @Test("zone nesting is bounded")
    func zoneDepthLimit() {
        var nested = zone(
            kind: .character,
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            textStart: 0,
            textLength: 1
        )

        for _ in 0...DecodeLimits.maxTextZoneDepth {
            nested = zone(
                kind: .character,
                x: 0,
                y: 0,
                width: 1,
                height: 1,
                textStart: 0,
                textLength: 1,
                children: [nested]
            )
        }

        let root = zone(
            kind: .page,
            x: 0,
            y: 0,
            width: 100,
            height: 100,
            textStart: 0,
            textLength: 1,
            children: [nested]
        )

        #expect(throws: DjVuError.self) {
            try DjVuTextDecoder.parse(
                payload: payload(text: "A", rootZone: root),
                pageHeight: 100
            )
        }
    }

    @Test("trailing zone bytes are rejected")
    func trailingZoneBytes() {
        var data = payload(
            text: "A",
            rootZone: zone(
                kind: .page,
                x: 0,
                y: 0,
                width: 100,
                height: 100,
                textStart: 0,
                textLength: 1
            )
        )
        data.append(0xFF)

        #expect(throws: DjVuError.self) {
            try DjVuTextDecoder.parse(payload: data, pageHeight: 100)
        }
    }
}
