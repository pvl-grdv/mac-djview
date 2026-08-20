import Foundation

final class ByteStream {
    let data: Data
    private let bytes: [UInt8]
    private(set) var offset: Int

    init(data: Data) {
        self.data = data
        self.bytes = [UInt8](data)
        self.offset = 0
    }

    init(data: Data, offset: Int) {
        self.data = data
        self.bytes = [UInt8](data)
        self.offset = min(max(offset, 0), self.bytes.count)
    }

    var remaining: Int { max(0, bytes.count - offset) }
    var isAtEnd: Bool { offset >= bytes.count }

    func seek(to position: Int) throws {
        guard position >= 0, position <= bytes.count else {
            throw DjVuError.truncatedData
        }
        offset = position
    }

    func skip(_ count: Int) throws {
        let (newOffset, overflow) = offset.addingReportingOverflow(count)
        guard !overflow, newOffset >= 0, newOffset <= bytes.count else {
            throw DjVuError.truncatedData
        }
        offset = newOffset
    }

    func readUInt8() throws -> UInt8 {
        guard remaining >= 1 else { throw DjVuError.truncatedData }
        let value = bytes[offset]
        offset += 1
        return value
    }

    func readUInt16() throws -> UInt16 {
        guard remaining >= 2 else { throw DjVuError.truncatedData }
        let b0 = UInt16(bytes[offset])
        let b1 = UInt16(bytes[offset + 1])
        offset += 2
        return (b0 << 8) | b1
    }

    func readUInt24() throws -> UInt32 {
        guard remaining >= 3 else { throw DjVuError.truncatedData }
        let b0 = UInt32(bytes[offset])
        let b1 = UInt32(bytes[offset + 1])
        let b2 = UInt32(bytes[offset + 2])
        offset += 3
        return (b0 << 16) | (b1 << 8) | b2
    }

    func readUInt32() throws -> UInt32 {
        guard remaining >= 4 else { throw DjVuError.truncatedData }
        let b0 = UInt32(bytes[offset])
        let b1 = UInt32(bytes[offset + 1])
        let b2 = UInt32(bytes[offset + 2])
        let b3 = UInt32(bytes[offset + 3])
        offset += 4
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    func readString(_ count: Int) throws -> String {
        guard count >= 0, count <= remaining else { throw DjVuError.truncatedData }
        let end = offset + count
        let slice = bytes[offset..<end]
        offset = end
        return String(bytes: slice, encoding: .ascii) ?? ""
    }

    func readData(_ count: Int) throws -> Data {
        guard count >= 0, count <= remaining else { throw DjVuError.truncatedData }
        let end = offset + count
        let result = Data(bytes[offset..<end])
        offset = end
        return result
    }

    func substream(length: Int) throws -> ByteStream {
        guard length >= 0, length <= remaining else { throw DjVuError.truncatedData }
        let end = offset + length
        let sub = ByteStream(data: Data(bytes[offset..<end]))
        offset = end
        return sub
    }

    // Read a byte without advancing.
    func peek() throws -> UInt8 {
        guard remaining >= 1 else { throw DjVuError.truncatedData }
        return bytes[offset]
    }

    // For ZP-Coder: out-of-range bytes use DjVu's conventional 0xFF padding.
    subscript(index: Int) -> UInt8 {
        guard index >= 0, index < bytes.count else { return 0xFF }
        return bytes[index]
    }

    /// Create a new stream from the remaining data (DjVu.js fork()).
    func fork() throws -> ByteStream {
        guard offset >= 0, offset <= bytes.count else { throw DjVuError.truncatedData }
        if offset == bytes.count {
            return ByteStream(data: Data())
        }
        return ByteStream(data: Data(bytes[offset..<bytes.count]))
    }

    /// Read a null-terminated string. Missing terminator consumes the remainder.
    func readStrNT() -> String {
        var result: [UInt8] = []
        while offset < bytes.count {
            let b = bytes[offset]
            offset += 1
            if b == 0 { break }
            result.append(b)
        }
        return String(bytes: result, encoding: .utf8) ?? ""
    }

    var isEmpty: Bool { offset >= bytes.count }
}
