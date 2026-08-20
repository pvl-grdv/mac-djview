import Foundation

enum DjVuError: LocalizedError {
    case invalidMagic
    case invalidFormat(String)
    case unsupportedChunk(String)
    case truncatedData
    case invalidPageIndex(Int)
    case decodingFailed(String)
    case resourceLimitExceeded(String)
    case noImageData

    var errorDescription: String? {
        switch self {
        case .invalidMagic: return "Not a valid DjVu file"
        case .invalidFormat(let msg): return "Invalid format: \(msg)"
        case .unsupportedChunk(let id): return "Unsupported chunk: \(id)"
        case .truncatedData: return "Unexpected end of data"
        case .invalidPageIndex(let i): return "Invalid page index: \(i)"
        case .decodingFailed(let msg): return "Decoding failed: \(msg)"
        case .resourceLimitExceeded(let msg): return "Safety limit exceeded: \(msg)"
        case .noImageData: return "No image data found"
        }
    }
}
