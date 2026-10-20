import Foundation

/// Keep image decoding independent from presentation zoom.
/// On macOS, two bounded quality tiers avoid re-decoding on each wheel/toolbar
/// increment. SwiftUI handles the final display scaling and interpolation.
/// iPadOS retains its existing adaptive render policy for memory-constrained devices.
enum PageRenderScale {
    static func forZoom(_ zoom: Double) -> Double {
        #if os(macOS)
        return zoom <= 0.5 ? 0.5 : 1.0
        #else
        return zoom
        #endif
    }
}
