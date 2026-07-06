import AppKit
import UniformTypeIdentifiers
import WebKit

private enum AppConfig {
    static let appName = "Pomodewro"
    static let popoverScale: CGFloat = 1.0
    static let basePopoverSize = NSSize(width: 800, height: 490)

    static var popoverSize: NSSize {
        NSSize(
            width: basePopoverSize.width * popoverScale,
            height: basePopoverSize.height * popoverScale
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let webViewController = WebViewController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = TomatoStatusIcon.image()
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.toolTip = AppConfig.appName
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = AppConfig.popoverSize
        popover.contentViewController = webViewController
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            webViewController.loadIfNeeded()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            webViewController.refreshTimer()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Pomodewro", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class WebViewController: NSViewController, WKUIDelegate, WKScriptMessageHandler {
    private var didLoad = false
    private let soundStore = SoundStore()
    private lazy var soundSchemeHandler = SoundSchemeHandler(store: soundStore)
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.setURLSchemeHandler(soundSchemeHandler, forURLScheme: "pomodewro-sound")
        configuration.userContentController.add(self, name: "pomodewroNative")

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.uiDelegate = self
        return view
    }()

    override func loadView() {
        view = webView
        view.frame = NSRect(origin: .zero, size: AppConfig.popoverSize)
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        guard let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            webView.loadHTMLString("<body style='font:14px -apple-system;color:white;background:#111'>Missing index.html</body>", baseURL: nil)
            return
        }

        var url = htmlURL
        if var components = URLComponents(url: htmlURL, resolvingAgainstBaseURL: false) {
            components.queryItems = [URLQueryItem(name: "nativeScale", value: String(Double(AppConfig.popoverScale)))]
            url = components.url ?? htmlURL
        }

        webView.loadFileURL(url, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    func refreshTimer() {
        webView.evaluateJavaScript("window.pomodewroRefreshTimer && window.pomodewroRefreshTimer();")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.webView.evaluateJavaScript("window.pomodewroRefreshTimer && window.pomodewroRefreshTimer();")
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.begin { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == "pomodewroNative",
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }

        switch type {
        case "importSound":
            importSound()
        case "clearSounds":
            clearStoredSounds()
        default:
            break
        }
    }

    private func importSound() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Pomodewro sound"
        panel.prompt = "Add Sound"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .audio,
            UTType(filenameExtension: "mp3"),
            UTType(filenameExtension: "m4a"),
            UTType(filenameExtension: "aac"),
            UTType(filenameExtension: "wav"),
            UTType(filenameExtension: "aiff"),
            UTType(filenameExtension: "aif"),
            UTType(filenameExtension: "mp4")
        ].compactMap { $0 }

        panel.begin { [weak self] response in
            guard let self else { return }
            guard response == .OK, let sourceURL = panel.url else { return }

            do {
                let sound = try self.soundStore.importSound(from: sourceURL)
                self.callJavaScriptCallback(
                    "pomodewroNativeSoundImported",
                    payload: ["id": sound.id, "name": sound.name, "url": sound.url]
                )
            } catch {
                self.callJavaScriptCallback(
                    "pomodewroNativeSoundImportFailed",
                    payload: ["message": "Could not save sound"]
                )
            }
        }
    }

    private func clearStoredSounds() {
        do {
            try soundStore.clear()
            callJavaScriptCallback("pomodewroNativeSoundsCleared")
        } catch {
            callJavaScriptCallback(
                "pomodewroNativeSoundImportFailed",
                payload: ["message": "Could not clear audio"]
            )
        }
    }

    private func callJavaScriptCallback(_ name: String, payload: [String: String] = [:]) {
        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else { return }

        webView.evaluateJavaScript("window['\(name)'] && window['\(name)'](\(json));")
    }
}

private struct NativeSound {
    let id: String
    let name: String
    let url: String
}

private final class SoundStore {
    private let fileManager = FileManager.default

    private var directory: URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("Pomodewro/Sounds", isDirectory: true)
    }

    func importSound(from sourceURL: URL) throws -> NativeSound {
        let hasSecurityAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let id = "native-sound-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6).lowercased())"
        let fileExtension = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension.lowercased()
        let destinationURL = directory.appendingPathComponent("\(id).\(fileExtension)")
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let rawName = sourceURL.deletingPathExtension().lastPathComponent
        let name = String((rawName.isEmpty ? "Custom" : rawName).prefix(24))
        return NativeSound(id: id, name: name, url: "pomodewro-sound://\(id)")
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    func fileURL(for id: String) -> URL? {
        guard id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else { return nil }
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }
        return files.first { $0.deletingPathExtension().lastPathComponent == id }
    }
}

private final class SoundSchemeHandler: NSObject, WKURLSchemeHandler {
    private let store: SoundStore

    init(store: SoundStore) {
        self.store = store
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            fail(urlSchemeTask, message: "Missing sound URL")
            return
        }

        let soundId = url.host ?? url.lastPathComponent
        guard let fileURL = store.fileURL(for: soundId) else {
            fail(urlSchemeTask, message: "Sound not found")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let response = URLResponse(
                url: url,
                mimeType: Self.mimeType(for: fileURL.pathExtension),
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            fail(urlSchemeTask, message: "Could not read sound")
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func fail(_ urlSchemeTask: WKURLSchemeTask, message: String) {
        let error = NSError(
            domain: AppConfig.appName,
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        urlSchemeTask.didFailWithError(error)
    }

    private static func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp3":
            return "audio/mpeg"
        case "m4a", "mp4", "aac":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "aif", "aiff":
            return "audio/aiff"
        default:
            return "application/octet-stream"
        }
    }
}

private enum TomatoStatusIcon {
    static func image() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.black.setFill()

        let body = NSBezierPath(ovalIn: NSRect(x: 4, y: 3, width: 11, height: 11))
        body.fill()

        let rightLeaf = NSBezierPath()
        rightLeaf.move(to: NSPoint(x: 10, y: 12))
        rightLeaf.curve(to: NSPoint(x: 15, y: 16), controlPoint1: NSPoint(x: 10, y: 15), controlPoint2: NSPoint(x: 13, y: 16))
        rightLeaf.curve(to: NSPoint(x: 10, y: 12), controlPoint1: NSPoint(x: 14, y: 13), controlPoint2: NSPoint(x: 12, y: 12))
        rightLeaf.fill()

        let leftLeaf = NSBezierPath()
        leftLeaf.move(to: NSPoint(x: 9, y: 12))
        leftLeaf.curve(to: NSPoint(x: 5, y: 15), controlPoint1: NSPoint(x: 8, y: 15), controlPoint2: NSPoint(x: 6, y: 16))
        leftLeaf.curve(to: NSPoint(x: 9, y: 12), controlPoint1: NSPoint(x: 6, y: 12), controlPoint2: NSPoint(x: 8, y: 12))
        leftLeaf.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
