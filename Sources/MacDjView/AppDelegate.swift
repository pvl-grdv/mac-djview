import SwiftUI

@MainActor
@Observable
final class OpenURLHandler {
    static let shared = OpenURLHandler()

    // AppDelegate can receive Finder open events before any SwiftUI window exists.
    // A queue also ensures multiple selected files are not silently discarded.
    private(set) var pendingURLs: [URL] = []

    func enqueue(_ urls: [URL]) {
        pendingURLs.append(contentsOf: urls)
    }

    func takePendingURLs() -> [URL] {
        let urls = pendingURLs
        pendingURLs.removeAll()
        return urls
    }
}

#if os(macOS)
import Cocoa

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Only needed when running via `swift run` without an app bundle
        if Bundle.main.bundleIdentifier == nil || Bundle.main.bundlePath.hasSuffix(".build") {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        OpenURLHandler.shared.enqueue(urls)
    }
}
#endif

// MARK: - Settings

struct SettingsView: View {
    @AppStorage("defaultPageLayout") private var defaultPageLayout = PageLayout.single.rawValue
    @AppStorage("defaultScrollMode") private var defaultScrollMode = ScrollMode.paged.rawValue
    @AppStorage("defaultZoom") private var defaultZoom: Double = 1.0

    var body: some View {
        Form {
            Picker("Default Layout", selection: $defaultPageLayout) {
                Text("Single Page").tag(PageLayout.single.rawValue)
                Text("Two Pages").tag(PageLayout.twoPage.rawValue)
            }

            Picker("Default Scroll Mode", selection: $defaultScrollMode) {
                Text("Paged").tag(ScrollMode.paged.rawValue)
                Text("Continuous").tag(ScrollMode.continuous.rawValue)
            }

            HStack {
                Text("Default Zoom")
                Slider(value: $defaultZoom, in: 0.25...4.0, step: 0.25) {
                    Text("Zoom")
                }
                Text("\(Int(defaultZoom * 100))%")
                    .monospacedDigit()
                    .frame(width: 50)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 400)
        #endif
        .navigationTitle("Settings")
    }
}
