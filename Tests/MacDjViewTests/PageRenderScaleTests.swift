import Foundation
import Testing
@testable import MacDjView

@Suite("Render scale policy")
struct PageRenderScaleTests {
    @Test("Zoom always selects a valid render scale")
    func renderScale() {
        #if os(macOS)
        #expect(PageRenderScale.forZoom(0.25) == 0.5)
        #expect(PageRenderScale.forZoom(0.5) == 0.5)
        #expect(PageRenderScale.forZoom(0.75) == 1.0)
        #expect(PageRenderScale.forZoom(1.0) == 1.0)
        #expect(PageRenderScale.forZoom(4.0) == 1.0)
        #else
        #expect(PageRenderScale.forZoom(0.25) == 0.25)
        #expect(PageRenderScale.forZoom(1.0) == 1.0)
        #expect(PageRenderScale.forZoom(4.0) == 4.0)
        #endif
    }
}
