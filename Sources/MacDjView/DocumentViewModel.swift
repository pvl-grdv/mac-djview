import Foundation
import SwiftUI
import CryptoKit

enum PageLayout: String, CaseIterable {
    case single = "Single Page"
    case twoPage = "Two Pages"
}

enum ScrollMode: String, CaseIterable {
    case paged = "Paged"
    case continuous = "Continuous"
}

enum ColorTheme: String, CaseIterable, Codable {
    case normal = "Normal"
    case inverted = "Inverted"
    case sepia = "Sepia"
}

private struct DocumentState: Codable {
    var currentPage: Int
    var zoom: Double
    var pageLayout: String
    var scrollMode: String
    var colorTheme: String?
}

@MainActor
@Observable
final class DocumentViewModel {
    var document: (any PageDocument)?
    var currentPage = 0
    var pageImage: PlatformImage?
    var rightPageImage: PlatformImage?
    var zoom: Double = 1.0
    var isLoading = false
    var errorMessage: String?
    var fileName: String?
    var pageLayout: PageLayout = .single
    var scrollMode: ScrollMode = .paged
    var colorTheme: ColorTheme = .normal
    var scrollTarget: Int?
    var documentURL: URL?
    var showFileImporter = false

    var searchQuery = ""
    var searchMatches: [DjVuSearchMatch] = []
    var selectedSearchMatchIndex: Int?
    var isSearching = false
    var searchErrorMessage: String?

    let pageCache = PageCache()

    private var renderTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var documentGeneration = 0
    private var renderRevision = 0

    var hasDocument: Bool { document != nil }
    var pageCount: Int { document?.pageCount ?? 0 }
    var canGoBack: Bool { currentPage > 0 }

    var canGoForward: Bool {
        guard let document else { return false }
        return currentPage < document.pageCount - 1
    }

    var selectedSearchMatch: DjVuSearchMatch? {
        guard let index = selectedSearchMatchIndex,
              searchMatches.indices.contains(index) else { return nil }
        return searchMatches[index]
    }

    var canNavigateSearchResults: Bool { !searchMatches.isEmpty }

    var searchResultText: String {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return "" }
        if isSearching { return "Searching…" }
        if searchErrorMessage != nil { return "Search failed" }
        guard !searchMatches.isEmpty else { return "No results" }
        let selected = (selectedSearchMatchIndex ?? 0) + 1
        return "\(selected) of \(searchMatches.count)"
    }

    var pageIndicatorText: String {
        guard let document else { return "" }
        if pageLayout == .twoPage, currentPage > 0,
           currentPage + 1 < document.pageCount {
            return "Pages \(currentPage + 1)\u{2013}\(currentPage + 2) of \(document.pageCount)"
        }
        return "Page \(currentPage + 1) of \(document.pageCount)"
    }

    var navigationSubtitleText: String {
        guard document != nil else { return "" }
        return pageIndicatorText
    }

    func navigatePage(_ delta: Int) {
        guard let document else { return }

        let step = pageLayout == .twoPage ? delta * 2 : delta
        let newPage = currentPage + step
        guard newPage >= 0, newPage < document.pageCount else { return }

        currentPage = pageLayout == .twoPage ? spreadStartPage(for: newPage) : newPage

        if scrollMode == .continuous {
            scrollTarget = currentPage
        } else {
            renderCurrentPage()
        }
    }

    func goToFirstPage() {
        guard document != nil, currentPage != 0 else { return }
        currentPage = 0
        if scrollMode == .continuous {
            scrollTarget = currentPage
        } else {
            renderCurrentPage()
        }
    }

    func goToLastPage() {
        guard let document, currentPage != document.pageCount - 1 else { return }
        if pageLayout == .twoPage {
            currentPage = spreadStartPage(for: document.pageCount - 1)
        } else {
            currentPage = document.pageCount - 1
        }
        if scrollMode == .continuous {
            scrollTarget = currentPage
        } else {
            renderCurrentPage()
        }
    }

    func spreadStartPage(for page: Int) -> Int {
        if page <= 0 { return 0 }
        return page % 2 == 0 ? page - 1 : page
    }

    func cycleColorTheme() {
        let all = ColorTheme.allCases
        let idx = all.firstIndex(of: colorTheme)!
        colorTheme = all[(idx + 1) % all.count]
        saveDocumentState()
    }

    func adjustZoom(_ delta: Double) {
        zoom = max(0.25, min(4.0, zoom + delta))
        handleZoomChanged()
    }

    func zoomToActualSize() {
        zoom = 1.0
        handleZoomChanged()
    }

    func fitToHeight(viewportHeight: CGFloat) {
        guard let document,
              let page = document.pageSize(at: currentPage) else { return }
        let otherPage: CGSize? = {
            guard pageLayout == .twoPage, currentPage > 0,
                  currentPage + 1 < document.pageCount else { return nil }
            return document.pageSize(at: currentPage + 1)
        }()
        let pageHeight = max(page.height, otherPage?.height ?? 0)
        let availableHeight = viewportHeight - 40
        guard availableHeight > 0, pageHeight > 0 else { return }
        zoom = max(0.25, min(4.0, availableHeight / pageHeight))
        handleZoomChanged()
    }

    func fitToWidth(viewportWidth: CGFloat) {
        guard let document,
              let page = document.pageSize(at: currentPage) else { return }
        let rightSize: CGSize? = {
            guard pageLayout == .twoPage, currentPage > 0,
                  currentPage + 1 < document.pageCount else { return nil }
            return document.pageSize(at: currentPage + 1)
        }()
        let totalPageWidth = page.width + (rightSize.map { $0.width + 12 } ?? 0)
        let availableWidth = viewportWidth - 40
        guard availableWidth > 0, totalPageWidth > 0 else { return }
        zoom = max(0.25, min(4.0, availableWidth / totalPageWidth))
        handleZoomChanged()
    }

    private func handleZoomChanged() {
        if scrollMode == .paged {
            renderCurrentPage()
        }
    }

    func handlePageLayoutChanged() {
        guard document != nil else { return }
        saveDocumentState()
        if pageLayout == .twoPage {
            currentPage = spreadStartPage(for: currentPage)
        }
        if scrollMode == .paged {
            renderCurrentPage()
        } else {
            scrollTarget = currentPage
        }
    }

    func handleScrollModeChanged() {
        guard document != nil else { return }
        saveDocumentState()
        if scrollMode == .paged {
            renderCurrentPage()
        } else {
            renderRevision += 1
            renderTask?.cancel()
            isLoading = false
            scrollTarget = currentPage
        }
    }

    func setSearchQuery(_ query: String) {
        searchQuery = query
        searchTask?.cancel()
        searchMatches = []
        selectedSearchMatchIndex = nil
        searchErrorMessage = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document, !trimmed.isEmpty else {
            isSearching = false
            return
        }
        guard let djvu = document as? DjVuDocument else {
            isSearching = false
            searchErrorMessage = "Text search in CBR is not available yet"
            return
        }

        let generation = documentGeneration
        isSearching = true
        searchTask = Task { [weak self, djvu] in
            do {
                try await Task.sleep(for: .milliseconds(180))
                try Task.checkCancellation()

                let matches = try await Task.detached(priority: .userInitiated) {
                    try DjVuSearchEngine.search(document: djvu, query: trimmed)
                }.value
                try Task.checkCancellation()

                await MainActor.run {
                    guard let self, self.documentGeneration == generation,
                          self.searchQuery == query else { return }
                    self.searchMatches = matches
                    self.selectedSearchMatchIndex = matches.isEmpty ? nil : 0
                    self.isSearching = false
                    if !matches.isEmpty {
                        self.navigateToSelectedSearchMatch()
                    }
                }
            } catch is CancellationError {
                // Superseded by a newer query.
            } catch {
                await MainActor.run {
                    guard let self, self.documentGeneration == generation,
                          self.searchQuery == query else { return }
                    self.searchMatches = []
                    self.selectedSearchMatchIndex = nil
                    self.searchErrorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }

    func nextSearchMatch() {
        guard !searchMatches.isEmpty else { return }
        let current = selectedSearchMatchIndex ?? -1
        selectedSearchMatchIndex = (current + 1) % searchMatches.count
        navigateToSelectedSearchMatch()
    }

    func previousSearchMatch() {
        guard !searchMatches.isEmpty else { return }
        let current = selectedSearchMatchIndex ?? 0
        selectedSearchMatchIndex = (current - 1 + searchMatches.count) % searchMatches.count
        navigateToSelectedSearchMatch()
    }

    func highlightRects(for pageIndex: Int) -> [DjVuTextRect] {
        guard let match = selectedSearchMatch, match.pageIndex == pageIndex else { return [] }
        return match.rects
    }

    private func navigateToSelectedSearchMatch() {
        guard let match = selectedSearchMatch, let document else { return }
        let target = min(max(match.pageIndex, 0), document.pageCount - 1)
        currentPage = pageLayout == .twoPage ? spreadStartPage(for: target) : target

        if scrollMode == .continuous {
            scrollTarget = target
        } else {
            renderCurrentPage()
        }
    }

    func loadDocument(url: URL) {
        documentGeneration += 1
        renderRevision += 1
        let generation = documentGeneration
        loadTask?.cancel()
        renderTask?.cancel()
        searchTask?.cancel()

        document = nil
        isLoading = true
        errorMessage = nil
        pageImage = nil
        rightPageImage = nil
        fileName = url.lastPathComponent
        documentURL = url
        pageCache.removeAll()
        searchQuery = ""
        searchMatches = []
        selectedSearchMatchIndex = nil
        isSearching = false
        searchErrorMessage = nil

        loadTask = Task { [weak self] in
            do {
                let doc = try await Task.detached(priority: .userInitiated) {
                    () throws -> any PageDocument in
                    switch url.pathExtension.lowercased() {
                    case "cbr":
                        return try ComicArchiveDocument(url: url)
                    case "djvu", "djv":
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer {
                            if scoped { url.stopAccessingSecurityScopedResource() }
                        }
                        let data = try SafeFileLoader.read(url: url)
                        return try DjVuDocument(data: data)
                    default:
                        throw ComicArchiveError.unsupportedFormat
                    }
                }.value
                try Task.checkCancellation()
                guard let self, self.documentGeneration == generation else { return }

                self.document = doc
                if let saved = self.restoreDocumentState() {
                    self.currentPage = min(max(saved.currentPage, 0), doc.pageCount - 1)
                    self.zoom = saved.zoom.isFinite ? max(0.25, min(4.0, saved.zoom)) : 1.0
                    if let layout = PageLayout(rawValue: saved.pageLayout) {
                        self.pageLayout = layout
                    }
                    if let mode = ScrollMode(rawValue: saved.scrollMode) {
                        self.scrollMode = mode
                    }
                    if let theme = saved.colorTheme.flatMap({ ColorTheme(rawValue: $0) }) {
                        self.colorTheme = theme
                    }
                } else {
                    self.currentPage = 0
                    self.zoom = 1.0
                }
                if self.scrollMode == .paged {
                    self.renderCurrentPage()
                } else {
                    self.scrollTarget = self.currentPage
                    self.isLoading = false
                }
            } catch is CancellationError {
                // A newer document was selected.
            } catch {
                guard let self, self.documentGeneration == generation else { return }
                self.errorMessage = "Failed to open: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func renderCurrentPage() {
        guard let document else { return }

        // Invalidate every previous render (including tasks that are about to
        // hit the cache fast path), not only when a new async render starts.
        renderRevision += 1
        let revision = renderRevision
        renderTask?.cancel()

        let generation = documentGeneration
        let pageIndex = currentPage
        let renderScale = PageRenderScale.forZoom(zoom)
        let zoomPercent = Int(renderScale * 100)

        let rightIndex: Int? = {
            guard pageLayout == .twoPage, pageIndex > 0,
                  pageIndex + 1 < document.pageCount else { return nil }
            return pageIndex + 1
        }()

        if let cached = pageCache.image(forPage: pageIndex, zoom: zoomPercent) {
            self.pageImage = cached

            if let ri = rightIndex,
               let cachedRight = pageCache.image(forPage: ri, zoom: zoomPercent) {
                self.rightPageImage = cachedRight
                self.isLoading = false
                return
            } else if rightIndex == nil {
                self.rightPageImage = nil
                self.isLoading = false
                return
            }
        }

        isLoading = true
        errorMessage = nil

        renderTask = Task {
            do {
                try Task.checkCancellation()
                let leftImage: PlatformImage
                if let cached = pageCache.image(forPage: pageIndex, zoom: zoomPercent) {
                    leftImage = cached
                } else {
                    leftImage = try await pageCache.render(
                        document: document, pageIndex: pageIndex, scale: renderScale
                    )
                    try Task.checkCancellation()
                    guard generation == documentGeneration,
                          revision == renderRevision else { return }
                    pageCache.store(leftImage, forPage: pageIndex, zoom: zoomPercent)
                }

                try Task.checkCancellation()
                guard generation == documentGeneration,
                      revision == renderRevision else { return }

                let renderedRight: PlatformImage?
                if let ri = rightIndex {
                    if let cached = pageCache.image(forPage: ri, zoom: zoomPercent) {
                        renderedRight = cached
                    } else {
                        let img = try await pageCache.render(
                            document: document, pageIndex: ri, scale: renderScale
                        )
                        try Task.checkCancellation()
                        guard generation == documentGeneration,
                              revision == renderRevision else { return }
                        pageCache.store(img, forPage: ri, zoom: zoomPercent)
                        renderedRight = img
                    }
                } else {
                    renderedRight = nil
                }

                try Task.checkCancellation()
                await MainActor.run {
                    guard self.documentGeneration == generation,
                          self.renderRevision == revision else { return }
                    self.pageImage = leftImage
                    self.rightPageImage = renderedRight
                    self.isLoading = false
                }
            } catch is CancellationError {
                // Cancelled by new render — ignore
            } catch {
                await MainActor.run {
                    guard self.documentGeneration == generation,
                          self.renderRevision == revision else { return }
                    self.errorMessage = "Decode error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func documentStateKey(for url: URL) -> String {
        let pathData = Data(url.standardizedFileURL.path.utf8)
        let digest = SHA256.hash(data: pathData)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "docState:\(hex)"
    }

    func saveDocumentState() {
        guard document != nil, let documentURL else { return }
        let state = DocumentState(
            currentPage: currentPage,
            zoom: zoom,
            pageLayout: pageLayout.rawValue,
            scrollMode: scrollMode.rawValue,
            colorTheme: colorTheme.rawValue
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: documentStateKey(for: documentURL))
    }

    private func restoreDocumentState() -> DocumentState? {
        guard let documentURL,
              let data = UserDefaults.standard.data(forKey: documentStateKey(for: documentURL))
        else { return nil }
        return try? JSONDecoder().decode(DocumentState.self, from: data)
    }
}

#if os(macOS)
struct DocumentActions {
    var navigatePage: (Int) -> Void
    var goToFirstPage: () -> Void
    var goToLastPage: () -> Void
    var adjustZoom: (Double) -> Void
    var zoomToActualSize: () -> Void
    var fitToHeight: () -> Void
    var fitToWidth: () -> Void
    var presentSearch: () -> Void
    var nextSearchMatch: () -> Void
    var previousSearchMatch: () -> Void
    var canGoBack: Bool
    var canGoForward: Bool
    var hasDocument: Bool
    var canNavigateSearchResults: Bool
    var colorTheme: Binding<ColorTheme>
    var pageLayout: Binding<PageLayout>
    var scrollMode: Binding<ScrollMode>
    var showFileImporter: Binding<Bool>
}

struct DocumentActionsKey: FocusedValueKey {
    typealias Value = DocumentActions
}

extension FocusedValues {
    var documentActions: DocumentActions? {
        get { self[DocumentActionsKey.self] }
        set { self[DocumentActionsKey.self] = newValue }
    }
}
#endif
