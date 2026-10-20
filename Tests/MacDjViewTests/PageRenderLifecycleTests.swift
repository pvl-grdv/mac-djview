import CoreGraphics
import Foundation
import Testing
@testable import MacDjView

/// The renderer is intentionally slower for page 0, so a later selection can
/// supersede it even when decoding has already started on the serial queue.
private final class SlowMockDocument: PageDocument, @unchecked Sendable {
    var pageCount: Int { 2 }

    func pageSize(at index: Int) -> CGSize? {
        (0..<pageCount).contains(index) ? CGSize(width: 20, height: 20) : nil
    }

    func renderPage(at index: Int, scale: Double) throws -> CGImage {
        if index == 0 {
            Thread.sleep(forTimeInterval: 0.12)
        }
        let width = index == 0 ? 5 : 10
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: width, height: 4,
                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }
}

@Suite("Page render lifecycle")
@MainActor
struct PageRenderLifecycleTests {
    @Test("An older render cannot overwrite the newest page")
    func staleRenderIsIgnored() async throws {
        let model = DocumentViewModel()
        model.document = SlowMockDocument()
        model.currentPage = 0
        model.renderCurrentPage()

        // Allow the first decode to enter the queue, then select page 2.
        try await Task.sleep(for: .milliseconds(25))
        model.currentPage = 1
        model.renderCurrentPage()
        try await Task.sleep(for: .milliseconds(300))

        #expect(model.currentPage == 1)
        #expect(model.pageImage?.size.width == 10)
        #expect(!model.isLoading)
    }

    @Test("Switching to a cached page also invalidates in-flight rendering")
    func cachedPageCancelsOldRender() async throws {
        let model = DocumentViewModel()
        model.document = SlowMockDocument()
        model.currentPage = 1
        model.renderCurrentPage()
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.pageImage?.size.width == 10)

        model.currentPage = 0
        model.renderCurrentPage()
        try await Task.sleep(for: .milliseconds(25))
        model.currentPage = 1
        model.renderCurrentPage()
        try await Task.sleep(for: .milliseconds(250))

        #expect(model.pageImage?.size.width == 10)
        #expect(!model.isLoading)
    }
}
