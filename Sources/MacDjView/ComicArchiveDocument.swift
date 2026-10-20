import CoreGraphics
import Foundation
import ImageIO
import Unrar

enum ComicArchiveError: LocalizedError {
    case unsupportedFormat
    case emptyArchive
    case tooManyEntries
    case encryptedArchive
    case multivolumeArchive
    case invalidPage
    case imageTooLarge
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Unsupported document format"
        case .emptyArchive: "The CBR archive does not contain supported images"
        case .tooManyEntries: "The archive contains too many files"
        case .encryptedArchive: "Password-protected CBR archives are not supported"
        case .multivolumeArchive: "Multi-volume RAR archives are not supported"
        case .invalidPage: "Invalid comic page"
        case .imageTooLarge: "Comic page exceeds the safe image size limit"
        case .invalidImage: "The archived image could not be decoded"
        }
    }
}

/// Keeps a security-scoped document accessible while background pages render.
private final class FileAccessToken: @unchecked Sendable {
    private let url: URL
    private let didStart: Bool

    init(_ url: URL) {
        self.url = url
        self.didStart = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if didStart { url.stopAccessingSecurityScopedResource() }
    }
}

/// A RAR-backed comic. Each decode uses a fresh Unrar handle, because its
/// Archive implementation is explicitly not thread-safe.
final class ComicArchiveDocument: PageDocument, @unchecked Sendable {
    private static let maxEntries = 10_000
    private static let maxPageBytes = 96 * 1024 * 1024
    private static let allowedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "gif", "bmp", "tif", "tiff", "heic"
    ]

    private let url: URL
    private let access: FileAccessToken
    private let entries: [Unrar.Entry]
    private let sizeLock = NSLock()
    private var knownPageSizes: [Int: CGSize] = [:]

    var pageCount: Int { entries.count }

    init(url: URL) throws {
        let access = FileAccessToken(url)
        let archive = try Unrar.Archive(fileURL: url)
        guard !archive.isVolume else { throw ComicArchiveError.multivolumeArchive }
        guard !archive.isHeaderEncrypted else { throw ComicArchiveError.encryptedArchive }

        let allEntries = try archive.entries()
        guard allEntries.count <= Self.maxEntries else {
            throw ComicArchiveError.tooManyEntries
        }
        let pages = allEntries
            .filter { !$0.directory && Self.isImagePath($0.fileName) }
            .sorted { Self.comesBefore($0.fileName, $1.fileName) }
        guard !pages.isEmpty else { throw ComicArchiveError.emptyArchive }
        guard !pages.contains(where: { $0.encrypted }) else {
            throw ComicArchiveError.encryptedArchive
        }

        self.url = url
        self.access = access
        self.entries = pages
    }

    func pageSize(at index: Int) -> CGSize? {
        sizeLock.withLock { knownPageSizes[index] }
    }

    func renderPage(at index: Int, scale: Double = 1) throws -> CGImage {
        guard entries.indices.contains(index) else { throw ComicArchiveError.invalidPage }
        guard scale.isFinite, scale > 0, scale <= 4 else {
            throw ComicArchiveError.invalidPage
        }

        let entry = entries[index]
        guard entry.uncompressedSize > 0,
              entry.uncompressedSize <= UInt64(Self.maxPageBytes) else {
            throw ComicArchiveError.imageTooLarge
        }

        // Stream with a strict cap; never use Unrar's unbounded extract-to-Data API.
        let archive = try Unrar.Archive(fileURL: url)
        var bytes = Data()
        bytes.reserveCapacity(min(Int(entry.uncompressedSize), 8 * 1024 * 1024))
        var exceededLimit = false
        do {
            try archive.extract(entry) { chunk, progress in
                if chunk.count > Self.maxPageBytes - bytes.count {
                    exceededLimit = true
                    progress.cancel()
                } else {
                    bytes.append(chunk)
                }
            }
        } catch {
            if exceededLimit { throw ComicArchiveError.imageTooLarge }
            throw error
        }
        guard !exceededLimit, bytes.count == Int(entry.uncompressedSize) else {
            throw ComicArchiveError.invalidImage
        }

        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(
            bytes as CFData, sourceOptions as CFDictionary
        ), let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let rawWidth = (properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue,
              let rawHeight = (properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue else {
            throw ComicArchiveError.invalidImage
        }

        let orientation = (properties[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue ?? 1
        let rotated = (5...8).contains(orientation)
        let width = rotated ? rawHeight : rawWidth
        let height = rotated ? rawWidth : rawHeight
        try DecodeLimits.validatePage(width: width, height: height, context: "comic image")

        // ImageIO decodes only to the desired size when zoomed out. Beyond 100%
        // SwiftUI scales the native image rather than allocating a huge bitmap.
        let decodeScale = min(scale, 1)
        let maxPixelSize = max(1, Int(Double(max(width, height)) * decodeScale))
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbOptions as CFDictionary
        ) else { throw ComicArchiveError.invalidImage }

        sizeLock.withLock {
            knownPageSizes[index] = CGSize(width: width, height: height)
        }
        return image
    }

    /// Never use archive entry paths as filesystem destinations.
    static func isImagePath(_ path: String) -> Bool {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.hasPrefix("/") else { return false }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              !components.contains(where: { $0.isEmpty || $0 == ".." || $0.hasPrefix(".") }),
              !components.contains(where: { String($0).caseInsensitiveCompare("__MACOSX") == .orderedSame })
        else { return false }
        let name = String(components[components.count - 1])
        guard let ext = name.split(separator: ".").last?.lowercased() else { return false }
        return allowedExtensions.contains(ext)
    }

    static func comesBefore(_ lhs: String, _ rhs: String) -> Bool {
        let order = lhs.compare(
            rhs, options: [.numeric, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return order == .orderedAscending || (order == .orderedSame && lhs < rhs)
    }
}
