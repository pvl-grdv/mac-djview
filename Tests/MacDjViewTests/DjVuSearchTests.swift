import Foundation
import Testing
@testable import MacDjView

@Suite("DjVu document search")
struct DjVuSearchTests {
    private func layer(text: String, wordRects: [(String, DjVuTextRect)]) -> DjVuTextLayer {
        var children: [DjVuTextZone] = []
        var searchStart = text.startIndex

        for (word, rect) in wordRects {
            guard let range = text.range(of: word, range: searchStart..<text.endIndex) else {
                continue
            }
            let lower = text.utf8.distance(from: text.utf8.startIndex, to: range.lowerBound)
            let upper = text.utf8.distance(from: text.utf8.startIndex, to: range.upperBound)
            children.append(DjVuTextZone(
                kind: .word,
                rect: rect,
                textByteRange: lower..<upper,
                children: []
            ))
            searchStart = range.upperBound
        }

        let root = DjVuTextZone(
            kind: .page,
            rect: DjVuTextRect(x: 0, y: 0, width: 1000, height: 1400),
            textByteRange: 0..<text.utf8.count,
            children: children
        )
        return DjVuTextLayer(text: text, rootZone: root)
    }

    @Test("Russian search is case insensitive and preserves highlight rectangles")
    func russianCaseInsensitive() {
        let first = DjVuTextRect(x: 10, y: 20, width: 80, height: 18)
        let second = DjVuTextRect(x: 100, y: 20, width: 55, height: 18)
        let textLayer = layer(
            text: "Привет мир",
            wordRects: [("Привет", first), ("мир", second)]
        )

        let matches = DjVuSearchEngine.search(
            layer: textLayer,
            pageIndex: 4,
            query: "ПРИВЕТ"
        )

        #expect(matches.count == 1)
        #expect(matches[0].pageIndex == 4)
        #expect(matches[0].pageNumber == 5)
        #expect(matches[0].rects == [first])
        #expect(textLayer.string(in: matches[0].byteRange) == "Привет")
    }

    @Test("phrase search highlights all overlapping leaf zones")
    func phraseHighlightsWords() {
        let first = DjVuTextRect(x: 10, y: 20, width: 80, height: 18)
        let second = DjVuTextRect(x: 100, y: 20, width: 55, height: 18)
        let textLayer = layer(
            text: "Привет мир",
            wordRects: [("Привет", first), ("мир", second)]
        )

        let matches = DjVuSearchEngine.search(
            layer: textLayer,
            pageIndex: 0,
            query: "привет мир"
        )

        #expect(matches.count == 1)
        #expect(matches[0].rects == [first, second])
    }

    @Test("DjVu structural separators remain searchable")
    func structuralSeparators() {
        let textLayer = DjVuTextLayer(text: "alpha\u{000B}beta", rootZone: nil)
        #expect(DjVuSearchEngine.search(
            layer: textLayer,
            pageIndex: 0,
            query: "beta"
        ).count == 1)
    }

    @Test("empty and whitespace-only queries return no results")
    func emptyQuery() {
        let textLayer = DjVuTextLayer(text: "text", rootZone: nil)
        #expect(DjVuSearchEngine.search(layer: textLayer, pageIndex: 0, query: "").isEmpty)
        #expect(DjVuSearchEngine.search(layer: textLayer, pageIndex: 0, query: "   ").isEmpty)
    }

    @Test("result limit bounds repeated matches")
    func resultLimit() {
        let textLayer = DjVuTextLayer(text: "a a a a a", rootZone: nil)
        let matches = DjVuSearchEngine.search(
            layer: textLayer,
            pageIndex: 0,
            query: "a",
            limit: 3
        )
        #expect(matches.count == 3)
        #expect(matches.map(\.id) == [0, 1, 2])
    }
}
