import Foundation
import Testing
@testable import MacDjView

@Suite("Comic archive page discovery")
struct ComicArchiveTests {
    @Test("Page names sort naturally, not alphabetically")
    func naturalPageOrder() {
        let names = ["10.jpg", "2.jpg", "1.jpg", "11.jpg", "3.jpg"]
        #expect(names.sorted(by: ComicArchiveDocument.comesBefore) ==
                ["1.jpg", "2.jpg", "3.jpg", "10.jpg", "11.jpg"])
    }

    @Test("Archives ignore metadata, traversal and non-image files")
    func imageFiltering() {
        #expect(ComicArchiveDocument.isImagePath("pages/001.JPG"))
        #expect(ComicArchiveDocument.isImagePath("chapter/002.png"))
        #expect(!ComicArchiveDocument.isImagePath("__MACOSX/pages/001.jpg"))
        #expect(!ComicArchiveDocument.isImagePath(".hidden.jpg"))
        #expect(!ComicArchiveDocument.isImagePath("pages/.DS_Store"))
        #expect(!ComicArchiveDocument.isImagePath("pages/../001.jpg"))
        #expect(!ComicArchiveDocument.isImagePath("notes.txt"))
        #expect(!ComicArchiveDocument.isImagePath("/absolute/001.jpg"))
    }
}
