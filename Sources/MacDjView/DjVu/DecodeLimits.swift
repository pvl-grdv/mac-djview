import Foundation

enum DecodeLimits {
    // Bounds are deliberately generous for real scanned documents while keeping
    // malformed input from turning tiny files into unbounded allocations/work.
    static let maxFileBytes = 256 * 1024 * 1024
    static let maxIFFDepth = 32
    static let maxIFFChunks = 50_000
    static let maxDocumentComponents = 10_000

    static let maxPageDimension = 65_535
    static let maxPagePixels = 40_000_000
    static let maxRenderedPixels = 64_000_000

    static let maxIW44Blocks = 40_000
    static let maxIW44Slices = 256
    static let maxIW44BlockSlices = 5_000_000

    static let maxJB2BitmapPixels = 40_000_000
    static let maxJB2DecodedBitmapPixels = 80_000_000
    static let maxJB2Symbols = 100_000
    static let maxJB2Blits = 250_000
    static let maxJB2BlitPixels = 100_000_000
    static let maxJB2Records = 100_000
    static let maxJB2CommentBytes = 16 * 1024 * 1024

    static let maxBZZOutputBytes = 64 * 1024 * 1024

    static func checkedAdd(_ lhs: Int, _ rhs: Int, context: String) throws -> Int {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else {
            throw DjVuError.resourceLimitExceeded("integer overflow while calculating \(context)")
        }
        return value
    }

    static func checkedMultiply(_ lhs: Int, _ rhs: Int, context: String) throws -> Int {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow else {
            throw DjVuError.resourceLimitExceeded("integer overflow while calculating \(context)")
        }
        return value
    }

    static func validatePage(width: Int, height: Int, context: String = "page") throws {
        guard width > 0, height > 0,
              width <= maxPageDimension, height <= maxPageDimension else {
            throw DjVuError.resourceLimitExceeded(
                "\(context) dimensions \(width)×\(height) are outside supported limits"
            )
        }
        let pixels = try checkedMultiply(width, height, context: "\(context) pixel count")
        guard pixels <= maxPagePixels else {
            throw DjVuError.resourceLimitExceeded("\(context) has too many pixels (\(pixels))")
        }
    }

    @discardableResult
    static func validateJB2Bitmap(width: Int, height: Int) throws -> Int {
        guard width >= 0, height >= 0,
              width <= maxPageDimension, height <= maxPageDimension else {
            throw DjVuError.resourceLimitExceeded(
                "JB2 bitmap dimensions \(width)×\(height) are outside supported limits"
            )
        }
        let pixels = try checkedMultiply(width, height, context: "JB2 bitmap pixel count")
        guard pixels <= maxJB2BitmapPixels else {
            throw DjVuError.resourceLimitExceeded("JB2 bitmap has too many pixels (\(pixels))")
        }
        return pixels
    }
}
