import AppKit
import WebKit

private enum AppConfig {
    static let appName = "Pomodewro"
    static let popoverScale: CGFloat = 0.70
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

final class WebViewController: NSViewController, WKUIDelegate {
    private var didLoad = false
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

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
