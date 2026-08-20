import Foundation

struct DjVuSearchMatch: Sendable, Equatable, Identifiable {
    let id: Int
    let pageIndex: Int
    let byteRange: Range<Int>
    let rects: [DjVuTextRect]

    var pageNumber: Int { pageIndex + 1 }
}

enum DjVuSearchEngine {
    static func search(document: DjVuDocument, query: String) throws -> [DjVuSearchMatch] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        var matches: [DjVuSearchMatch] = []
        matches.reserveCapacity(64)

        for pageIndex in 0..<document.pageCount {
            guard matches.count < DecodeLimits.maxSearchResults else { break }
            guard let layer = try document.textLayer(at: pageIndex) else { continue }

            let remaining = DecodeLimits.maxSearchResults - matches.count
            matches.append(contentsOf: search(
                layer: layer,
                pageIndex: pageIndex,
                query: normalizedQuery,
                startingID: matches.count,
                limit: remaining
            ))
        }

        return matches
    }

    static func search(
        layer: DjVuTextLayer,
        pageIndex: Int,
        query: String,
        startingID: Int = 0,
        limit: Int = DecodeLimits.maxSearchResults
    ) -> [DjVuSearchMatch] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty, limit > 0 else { return [] }

        // `plainText` only replaces one-byte DjVu structural control characters
        // with one-byte whitespace. UTF-8 byte offsets therefore stay aligned with
        // the original text used by the zone tree.
        let searchableText = layer.plainText
        guard !searchableText.isEmpty else { return [] }

        var results: [DjVuSearchMatch] = []
        results.reserveCapacity(min(limit, 32))

        var lowerBound = searchableText.startIndex
        let end = searchableText.endIndex
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

        while lowerBound < end, results.count < limit,
              let range = searchableText.range(
                of: normalizedQuery,
                options: options,
                range: lowerBound..<end,
                locale: .current
              ) {
            let lowerByte = searchableText.utf8.distance(
                from: searchableText.utf8.startIndex,
                to: range.lowerBound
            )
            let upperByte = searchableText.utf8.distance(
                from: searchableText.utf8.startIndex,
                to: range.upperBound
            )
            let byteRange = lowerByte..<upperByte
            let rects = layer.leafZones(overlapping: byteRange).map(\.rect)

            results.append(DjVuSearchMatch(
                id: startingID + results.count,
                pageIndex: pageIndex,
                byteRange: byteRange,
                rects: rects
            ))

            // Query is guaranteed non-empty, so this always advances.
            lowerBound = range.upperBound
        }

        return results
    }
}
