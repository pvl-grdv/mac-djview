import CoreGraphics
import Testing
@testable import MacDjView

@Suite("Continuous comic page sizing")
struct ComicPageLayoutTests {
    @Test("Comic frames remain fixed without decoding all archived pages")
    func uniformSlot() {
        #expect(ComicArchiveDocument.readingSlotSize.width == 900)
        #expect(ComicArchiveDocument.readingSlotSize.height == 1300)
    }
}
