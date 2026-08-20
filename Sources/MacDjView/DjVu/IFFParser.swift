import Foundation

struct IFFChunk {
    let id: String
    let data: Data
    let children: [IFFChunk]
    let formType: String?  // non-nil for FORM chunks

    var isForm: Bool { formType != nil }
}

final class IFFParser {
    static func parse(data: Data) throws -> IFFChunk {
        guard data.count <= DecodeLimits.maxFileBytes else {
            throw DjVuError.resourceLimitExceeded("DjVu file is larger than the supported limit")
        }

        let stream = ByteStream(data: data)
        let magic = try stream.readString(4)
        guard magic == "AT&T" else {
            throw DjVuError.invalidMagic
        }

        var chunkCount = 0
        let root = try parseChunk(
            stream: stream,
            depth: 0,
            chunkCount: &chunkCount,
            limit: data.count
        )
        guard stream.isAtEnd else {
            throw DjVuError.invalidFormat("Trailing data after root FORM")
        }
        return root
    }

    private static func parseChunk(
        stream: ByteStream,
        depth: Int,
        chunkCount: inout Int,
        limit: Int
    ) throws -> IFFChunk {
        guard depth <= DecodeLimits.maxIFFDepth else {
            throw DjVuError.resourceLimitExceeded("IFF nesting is too deep")
        }
        chunkCount += 1
        guard chunkCount <= DecodeLimits.maxIFFChunks else {
            throw DjVuError.resourceLimitExceeded("IFF contains too many chunks")
        }
        guard stream.offset >= 0, stream.offset <= limit else {
            throw DjVuError.invalidFormat("IFF chunk starts outside its parent")
        }
        guard limit - stream.offset >= 8 else {
            throw DjVuError.truncatedData
        }

        let id = try stream.readString(4)
        let rawLength = try stream.readUInt32()
        let length = Int(rawLength)
        guard length <= limit - stream.offset else {
            throw DjVuError.truncatedData
        }

        let chunk: IFFChunk
        if id == "FORM" {
            guard length >= 4 else {
                throw DjVuError.invalidFormat("FORM chunk length is smaller than its form type")
            }

            let formType = try stream.readString(4)
            let contentLength = length - 4
            let endOffset = try DecodeLimits.checkedAdd(
                stream.offset, contentLength, context: "FORM end offset"
            )

            var children: [IFFChunk] = []
            while stream.offset < endOffset {
                let child = try parseChunk(
                    stream: stream,
                    depth: depth + 1,
                    chunkCount: &chunkCount,
                    limit: endOffset
                )
                children.append(child)
            }
            guard stream.offset == endOffset else {
                throw DjVuError.invalidFormat("FORM child overruns parent boundary")
            }

            chunk = IFFChunk(id: id, data: Data(), children: children, formType: formType)
        } else {
            let chunkData = try stream.readData(length)
            chunk = IFFChunk(id: id, data: chunkData, children: [], formType: nil)
        }

        // Every IFF chunk, including FORM, is padded to an even byte boundary.
        // The pad byte is not part of the declared length but is part of the parent payload.
        if rawLength % 2 != 0 {
            guard stream.offset < limit else {
                throw DjVuError.truncatedData
            }
            try stream.skip(1)
        }

        return chunk
    }

    static func findChunks(in chunk: IFFChunk, withId targetId: String) -> [IFFChunk] {
        var results: [IFFChunk] = []
        if chunk.id == targetId {
            results.append(chunk)
        }
        for child in chunk.children {
            results.append(contentsOf: findChunks(in: child, withId: targetId))
        }
        return results
    }
}
