import CoreGraphics

/// Read-only page source shared by DjVu documents and comic archives.
protocol PageDocument: AnyObject, Sendable {
    var pageCount: Int { get }
    /// May be nil until an archive page has been decoded.
    func pageSize(at index: Int) -> CGSize?
    func pageDPI(at index: Int) -> Int?
    /// Continuous comic pages can use uniformly sized, letterboxed slots.
    var prefersUniformPageSlots: Bool { get }
    func continuousPageSize(at index: Int) -> CGSize?
    func renderPage(at index: Int, scale: Double) throws -> CGImage
}

extension PageDocument {
    func pageDPI(at index: Int) -> Int? { nil }
    var prefersUniformPageSlots: Bool { false }
    func continuousPageSize(at index: Int) -> CGSize? { pageSize(at: index) }
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
