import AppKit
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var pinItem: NSMenuItem!
    private var titleObservation: NSKeyValueObservation?
    private let pinKey = "alwaysOnTop"
    private let transparencyKey = "windowTransparency"
    private let transparencyLevels = [0, 10, 20, 30, 40, 50, 60, 70]
    private var transparencyItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.3, *) { webView.isInspectable = true }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "OKX Mini Chart"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0x0f / 255, green: 0x11 / 255, blue: 0x15 / 255, alpha: 1)
        window.minSize = NSSize(width: 300, height: 360)
        window.contentView = webView
        window.setContentSize(NSSize(width: 520, height: 820))
        window.center()
        window.setFrameAutosaveName("MainWindow")

        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            if let title = view.title, !title.isEmpty { self?.window.title = title }
        }

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        applyPin(UserDefaults.standard.bool(forKey: pinKey))
        setTransparency(UserDefaults.standard.integer(forKey: transparencyKey))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    @objc private func reload() { webView.reload() }

    @objc private func togglePin() {
        let on = !UserDefaults.standard.bool(forKey: pinKey)
        UserDefaults.standard.set(on, forKey: pinKey)
        applyPin(on)
    }

    private func applyPin(_ on: Bool) {
        window.level = on ? .floating : .normal
        window.collectionBehavior = on ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
        pinItem.state = on ? .on : .off
    }

    @objc private func pickTransparency(_ sender: NSMenuItem) { setTransparency(sender.tag) }
    @objc private func moreTransparent() { stepTransparency(1) }
    @objc private func lessTransparent() { stepTransparency(-1) }

    private func stepTransparency(_ delta: Int) {
        let current = transparencyLevels.firstIndex(of: UserDefaults.standard.integer(forKey: transparencyKey)) ?? 0
        let next = min(max(current + delta, 0), transparencyLevels.count - 1)
        setTransparency(transparencyLevels[next])
    }

    private func setTransparency(_ percent: Int) {
        let value = transparencyLevels.contains(percent) ? percent : 0
        UserDefaults.standard.set(value, forKey: transparencyKey)
        window.alphaValue = CGFloat(100 - value) / 100
        for item in transparencyItems { item.state = item.tag == value ? .on : .off }
    }

    private func buildMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "OKX Mini Chart 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "OKX Mini Chart 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, to: main)

        let edit = NSMenu(title: "편집")
        edit.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "다시 실행", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        addSubmenu(edit, to: main)

        let view = NSMenu(title: "보기")
        let reloadItem = NSMenuItem(title: "새로고침", action: #selector(reload), keyEquivalent: "r")
        reloadItem.target = self
        view.addItem(reloadItem)
        pinItem = NSMenuItem(title: "항상 위에 표시", action: #selector(togglePin), keyEquivalent: "t")
        pinItem.target = self
        view.addItem(pinItem)
        view.addItem(.separator())
        let transparency = NSMenu(title: "창 투명도")
        for level in transparencyLevels {
            let item = NSMenuItem(title: level == 0 ? "0% (불투명)" : "\(level)%", action: #selector(pickTransparency(_:)), keyEquivalent: "")
            item.tag = level
            item.target = self
            transparency.addItem(item)
            transparencyItems.append(item)
        }
        transparency.addItem(.separator())
        let more = NSMenuItem(title: "더 투명하게", action: #selector(moreTransparent), keyEquivalent: "-")
        more.keyEquivalentModifierMask = [.command, .option]
        more.target = self
        transparency.addItem(more)
        let less = NSMenuItem(title: "덜 투명하게", action: #selector(lessTransparent), keyEquivalent: "=")
        less.keyEquivalentModifierMask = [.command, .option]
        less.target = self
        transparency.addItem(less)
        let transparencyItem = NSMenuItem(title: "창 투명도", action: nil, keyEquivalent: "")
        transparencyItem.submenu = transparency
        view.addItem(transparencyItem)
        addSubmenu(view, to: main)

        let win = NSMenu(title: "윈도우")
        win.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        addSubmenu(win, to: main)

        NSApp.mainMenu = main
    }

    private func addSubmenu(_ menu: NSMenu, to main: NSMenu) {
        let item = NSMenuItem()
        item.submenu = menu
        main.addItem(item)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
