import CoreGraphics

/// Read-only page source shared by DjVu documents and comic archives.
protocol PageDocument: AnyObject, Sendable {
    var pageCount: Int { get }
    /// May be nil until an archive page has been decoded.
    func pageSize(at index: Int) -> CGSize?
    func pageDPI(at index: Int) -> Int?
    func renderPage(at index: Int, scale: Double) throws -> CGImage
}

extension PageDocument {
    func pageDPI(at index: Int) -> Int? { nil }
}

extension DjVuDocument: PageDocument {
    func pageSize(at index: Int) -> CGSize? {
        guard pages.indices.contains(index) else { return nil }
        return CGSize(width: pages[index].width, height: pages[index].height)
    }

    func pageDPI(at index: Int) -> Int? {
        guard pages.indices.contains(index) else { return nil }
        return pages[index].dpi
    }
}
