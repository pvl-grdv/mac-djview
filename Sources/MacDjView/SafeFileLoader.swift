import Foundation

enum SafeFileLoader {
    private static let chunkSize = 1024 * 1024

    static func read(url: URL, maxBytes: Int = DecodeLimits.maxFileBytes) throws -> Data {
        guard maxBytes > 0, maxBytes < Int.max else {
            throw DjVuError.resourceLimitExceeded("invalid file size limit")
        }

        if let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSize > maxBytes {
            throw DjVuError.resourceLimitExceeded("DjVu file is larger than the supported limit")
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var result = Data()
        result.reserveCapacity(min(maxBytes, 8 * 1024 * 1024))

        while result.count <= maxBytes {
            let remaining = (maxBytes + 1) - result.count
            let requestSize = min(chunkSize, remaining)
            guard requestSize > 0,
                  let chunk = try handle.read(upToCount: requestSize),
                  !chunk.isEmpty else {
                break
            }
            result.append(chunk)
        }

        guard result.count <= maxBytes else {
            throw DjVuError.resourceLimitExceeded("DjVu file is larger than the supported limit")
        }
        return result
    }
}
