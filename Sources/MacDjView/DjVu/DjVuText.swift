import Foundation

/// DjVu hidden-text zone kinds, ordered from page-level structure to characters.
enum DjVuTextZoneKind: UInt8, Sendable, CaseIterable {
    case page = 1
    case column = 2
    case region = 3
    case paragraph = 4
    case line = 5
    case word = 6
    case character = 7
}

/// A text-zone rectangle in page pixels using a top-left origin, matching the
/// rendered CGImage / SwiftUI coordinate system.
struct DjVuTextRect: Sendable, Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

/// One node in the DjVu hidden-text hierarchy.
struct DjVuTextZone: Sendable, Equatable {
    let kind: DjVuTextZoneKind
    let rect: DjVuTextRect
    /// UTF-8 byte range in `DjVuTextLayer.text`.
    let textByteRange: Range<Int>
    let children: [DjVuTextZone]

    var isLeaf: Bool { children.isEmpty }

    func leafZones(overlapping byteRange: Range<Int>) -> [DjVuTextZone] {
        guard textByteRange.overlaps(byteRange) else { return [] }
        if children.isEmpty { return [self] }
        return children.flatMap { $0.leafZones(overlapping: byteRange) }
    }
}

/// Searchable text and optional coordinate hierarchy from a page's TXTa/TXTz chunk.
struct DjVuTextLayer: Sendable, Equatable {
    let text: String
    let rootZone: DjVuTextZone?

    var utf8Count: Int { text.utf8.count }

    /// A search/index friendly representation. DjVu uses control separators for
    /// columns/regions/paragraphs in addition to normal whitespace; normalize
    /// those separators without changing the original `text` used for zone ranges.
    var plainText: String {
        var result = ""
        result.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x00:
                result.append(" ")
            case 0x0B, 0x0C, 0x1D, 0x1E, 0x1F:
                result.append("\n")
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// Convert a DjVu UTF-8 byte range into a Swift String slice. Malformed zone
    /// boundaries are rejected rather than rounded to adjacent Unicode scalars.
    func string(in byteRange: Range<Int>) -> String? {
        let utf8 = text.utf8
        guard byteRange.lowerBound >= 0,
              byteRange.upperBound >= byteRange.lowerBound,
              byteRange.upperBound <= utf8.count else {
            return nil
        }

        let lowerUTF8 = utf8.index(utf8.startIndex, offsetBy: byteRange.lowerBound)
        let upperUTF8 = utf8.index(utf8.startIndex, offsetBy: byteRange.upperBound)
        guard let lower = String.Index(lowerUTF8, within: text),
              let upper = String.Index(upperUTF8, within: text) else {
            return nil
        }
        return String(text[lower..<upper])
    }

    func leafZones(overlapping byteRange: Range<Int>) -> [DjVuTextZone] {
        rootZone?.leafZones(overlapping: byteRange) ?? []
    }
}

enum DjVuTextDecoder {
    private struct RawZone {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
        let textStart: Int
        let textLength: Int
    }

    static func decode(
        chunkID: String,
        data: Data,
        pageHeight: Int
    ) throws -> DjVuTextLayer {
        let payload: Data
        switch chunkID {
        case "TXTa":
            payload = data
        case "TXTz":
            payload = try BZZDecoder.decode(
                stream: ByteStream(data: data),
                maxOutputBytes: DecodeLimits.maxDecodedTextChunkBytes
            ).data
        default:
            throw DjVuError.invalidFormat("Unsupported text chunk: \(chunkID)")
        }
        return try parse(payload: payload, pageHeight: pageHeight)
    }

    static func parse(payload: Data, pageHeight: Int) throws -> DjVuTextLayer {
        guard pageHeight > 0, pageHeight <= DecodeLimits.maxPageDimension else {
            throw DjVuError.resourceLimitExceeded("text layer page height is outside supported limits")
        }

        let stream = ByteStream(data: payload)
        let textLength = Int(try stream.readUInt24())
        guard textLength <= DecodeLimits.maxTextBytesPerPage else {
            throw DjVuError.resourceLimitExceeded("DjVu text layer is too large")
        }
        guard textLength <= stream.remaining else {
            throw DjVuError.truncatedData
        }

        let textData = try stream.readData(textLength)
        guard let text = String(data: textData, encoding: .utf8) else {
            throw DjVuError.invalidFormat("DjVu text layer is not valid UTF-8")
        }

        // DjVuLibre permits text-only chunks with no zone data. If a zone tree is
        // present, it starts with version 1 and exactly one page zone.
        guard !stream.isAtEnd else {
            return DjVuTextLayer(text: text, rootZone: nil)
        }

        let version = try stream.readUInt8()
        guard version == 1 else {
            throw DjVuError.invalidFormat("Unsupported DjVu text zone version: \(version)")
        }
        guard !stream.isAtEnd else {
            throw DjVuError.truncatedData
        }

        var zoneCount = 0
        let (root, _) = try parseZone(
            stream: stream,
            pageHeight: pageHeight,
            textByteCount: textLength,
            parent: nil,
            previous: nil,
            depth: 1,
            zoneCount: &zoneCount
        )
        guard root.kind == .page else {
            throw DjVuError.invalidFormat("DjVu text zone tree does not start with a page zone")
        }
        guard stream.isAtEnd else {
            throw DjVuError.invalidFormat("DjVu text layer contains trailing zone data")
        }

        return DjVuTextLayer(text: text, rootZone: root)
    }

    private static func parseZone(
        stream: ByteStream,
        pageHeight: Int,
        textByteCount: Int,
        parent: RawZone?,
        previous: RawZone?,
        depth: Int,
        zoneCount: inout Int
    ) throws -> (DjVuTextZone, RawZone) {
        guard depth <= DecodeLimits.maxTextZoneDepth else {
            throw DjVuError.resourceLimitExceeded("DjVu text zone nesting is too deep")
        }

        zoneCount = try DecodeLimits.checkedAdd(zoneCount, 1, context: "DjVu text zone count")
        guard zoneCount <= DecodeLimits.maxTextZonesPerPage else {
            throw DjVuError.resourceLimitExceeded("DjVu page contains too many text zones")
        }

        let rawKind = try stream.readUInt8()
        guard let kind = DjVuTextZoneKind(rawValue: rawKind) else {
            throw DjVuError.invalidFormat("Unknown DjVu text zone type: \(rawKind)")
        }

        var x = Int(try stream.readUInt16()) - 0x8000
        var y = Int(try stream.readUInt16()) - 0x8000
        let width = Int(try stream.readUInt16()) - 0x8000
        let height = Int(try stream.readUInt16()) - 0x8000
        var textStart = Int(try stream.readUInt16()) - 0x8000
        let textLength = Int(try stream.readUInt24())

        guard width > 0, height > 0 else {
            throw DjVuError.invalidFormat("DjVu text zone has an empty rectangle")
        }

        if let previous {
            if kind == .page || kind == .paragraph || kind == .line {
                x = try DecodeLimits.checkedAdd(x, previous.x, context: "text zone x offset")
                let encodedBottom = try DecodeLimits.checkedAdd(y, height, context: "text zone y offset")
                y = try DecodeLimits.checkedSubtract(
                    previous.y, encodedBottom, context: "text zone y position"
                )
            } else {
                let previousRight = try DecodeLimits.checkedAdd(
                    previous.x, previous.width, context: "previous text zone right edge"
                )
                x = try DecodeLimits.checkedAdd(x, previousRight, context: "text zone x position")
                y = try DecodeLimits.checkedAdd(y, previous.y, context: "text zone y position")
            }

            let previousTextEnd = try DecodeLimits.checkedAdd(
                previous.textStart, previous.textLength, context: "previous text zone range"
            )
            textStart = try DecodeLimits.checkedAdd(
                textStart, previousTextEnd, context: "text zone start"
            )
        } else if let parent {
            x = try DecodeLimits.checkedAdd(x, parent.x, context: "text zone parent x offset")
            let parentTop = try DecodeLimits.checkedAdd(
                parent.y, parent.height, context: "text zone parent top"
            )
            let encodedBottom = try DecodeLimits.checkedAdd(y, height, context: "text zone y offset")
            y = try DecodeLimits.checkedSubtract(
                parentTop, encodedBottom, context: "text zone y position"
            )
            textStart = try DecodeLimits.checkedAdd(
                textStart, parent.textStart, context: "text zone start"
            )
        }

        guard textStart >= 0 else {
            throw DjVuError.invalidFormat("DjVu text zone starts before page text")
        }
        let textEnd = try DecodeLimits.checkedAdd(textStart, textLength, context: "text zone range")
        guard textEnd <= textByteCount else {
            throw DjVuError.invalidFormat("DjVu text zone extends past page text")
        }

        let childCount = Int(try stream.readUInt24())
        let remainingZoneBudget = DecodeLimits.maxTextZonesPerPage - zoneCount
        guard childCount <= remainingZoneBudget else {
            throw DjVuError.resourceLimitExceeded("DjVu page contains too many text zones")
        }

        let raw = RawZone(
            x: x,
            y: y,
            width: width,
            height: height,
            textStart: textStart,
            textLength: textLength
        )

        var children: [DjVuTextZone] = []
        children.reserveCapacity(min(childCount, 1024))
        var previousChild: RawZone?
        for _ in 0..<childCount {
            let (child, childRaw) = try parseZone(
                stream: stream,
                pageHeight: pageHeight,
                textByteCount: textByteCount,
                parent: raw,
                previous: previousChild,
                depth: depth + 1,
                zoneCount: &zoneCount
            )
            children.append(child)
            previousChild = childRaw
        }

        let bottomPlusHeight = try DecodeLimits.checkedAdd(y, height, context: "text zone top edge")
        let topY = try DecodeLimits.checkedSubtract(
            pageHeight, bottomPlusHeight, context: "text zone top-left y"
        )

        let zone = DjVuTextZone(
            kind: kind,
            rect: DjVuTextRect(x: x, y: topY, width: width, height: height),
            textByteRange: textStart..<textEnd,
            children: children
        )
        return (zone, raw)
    }
}
