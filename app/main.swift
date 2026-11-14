import AppKit
import UserNotifications
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, UNUserNotificationCenterDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var pinItem: NSMenuItem!
    private var disguiseItem: NSMenuItem!
    private var disguised = false
    private var titleObservation: NSKeyValueObservation?
    private let pinKey = "alwaysOnTop"
    private let opacityKey = "windowOpacity"
    private let minOpacity = 0.3
    private var opacitySlider: NSSlider!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        UNUserNotificationCenter.current().delegate = self

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController.add(self, name: "win")
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
            if let title = view.title, !title.isEmpty, self?.disguised == false { self?.window.title = title }
        }

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        addOpacitySlider()
        applyPin(UserDefaults.standard.bool(forKey: pinKey))
        setOpacity(UserDefaults.standard.object(forKey: opacityKey) as? Double ?? 1)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "win", let body = message.body as? [String: Any] else { return }
        if let s = body["shot"] as? [String: Any] {
            let r = CGRect(x: s["x"] as? Double ?? 0, y: s["y"] as? Double ?? 0, width: s["w"] as? Double ?? 0, height: s["h"] as? Double ?? 0)
            snap(r.width > 1 && r.height > 1 ? r : nil, s["name"] as? String ?? "")
            return
        }
        if let n = body["notify"] as? [String: Any] { notify(n); return }
        if body["notifyAuth"] as? Bool == true { requestNotifyAuth { _ in }; return }
        if let s = body["sound"] as? String { NSSound(named: NSSound.Name(s))?.play(); return }
        if let d = body["disguise"] as? Bool { applyDisguise(d); return }
        let dx = body["dx"] as? Double ?? 0, dy = body["dy"] as? Double ?? 0
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return }
        resizeWindow(dx: CGFloat(dx), dy: CGFloat(dy))
    }

    // 칸 하나(또는 창 전체)를 PNG 로 바탕화면(~/Desktop)에 저장하고 클립보드에도 넣는다(옵시디언 등에 바로 붙여넣기).
    @objc private func capture() { webView.evaluateJavaScript("startShot()") }

    @objc private func captureWindow() {
        webView.evaluateJavaScript("prepShot()") { [weak self] result, _ in
            self?.snap(nil, (result as? String) ?? "")
        }
    }

    private func snap(_ rect: CGRect?, _ insts: String) {
        // 토스트·선택 표시가 사라진 화면이 그려질 시간을 준다
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let cfg = WKSnapshotConfiguration()
            if let rect { cfg.rect = rect }
            self.webView.takeSnapshot(with: cfg) { image, error in
                guard let image, let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                    self.shotDone(nil, error?.localizedDescription ?? "이미지를 만들지 못했어요")
                    return
                }
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setData(png, forType: .png)

                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd HHmmss"
                let name = "OKX \(fmt.string(from: Date()))\(insts.isEmpty ? "" : " " + insts).png"
                let dir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
                do {
                    try png.write(to: dir.appendingPathComponent(name))
                    self.shotDone(name, nil)
                } catch {
                    self.shotDone(nil, "클립보드엔 복사됐지만 저장 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func js(_ s: String?) -> String {
        s.map { "\"\($0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\"" } ?? "null"
    }

    private func shotDone(_ name: String?, _ err: String?) {
        webView.evaluateJavaScript("shotDone(\(js(name)), \(js(err)))")
    }

    private func requestNotifyAuth(_ done: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                if !granted { self?.webView.evaluateJavaScript("notifyDenied()") }
                done(granted)
            }
        }
    }

    private func notify(_ n: [String: Any]) {
        if let s = n["sound"] as? String, !s.isEmpty { NSSound(named: NSSound.Name(s))?.play() }
        guard n["banner"] as? Bool ?? true else { return }
        let content = UNMutableNotificationContent()
        content.title = disguised ? "알림" : n["title"] as? String ?? ""
        content.body = disguised ? "" : n["body"] as? String ?? ""
        content.userInfo = ["inst": n["inst"] as? String ?? "", "tf": n["tf"] as? String ?? ""]
        requestNotifyAuth { granted in
            guard granted else { return }
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let inst = info["inst"] as? String ?? "", tf = info["tf"] as? String ?? ""
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.window.makeKeyAndOrderFront(nil)
            if !inst.isEmpty { self.webView.evaluateJavaScript("openAlert(\(self.js(inst)), \(self.js(tf)))") }
        }
        completionHandler()
    }

    private func resizeWindow(dx: CGFloat, dy: CGFloat) {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        var frame = window.frame
        let height = min(max(frame.height + dy, window.minSize.height), visible.height)
        let width = min(max(frame.width + dx, window.minSize.width), visible.width)
        let top = frame.maxY
        frame.size = NSSize(width: width, height: height)
        frame.origin.y = max(top - height, visible.minY)
        if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - height }
        if frame.maxX > visible.maxX { frame.origin.x = max(visible.minX, visible.maxX - width) }
        window.setFrame(frame, display: true, animate: true)
    }

    @objc private func reload() { webView.reload() }

    @objc private func toggleTradeFold() { webView.evaluateJavaScript("toggleTradeFold()") }

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

    @objc private func toggleDisguise() { webView.evaluateJavaScript("toggleDisguise()") }

    private func applyDisguise(_ on: Bool) {
        disguised = on
        disguiseItem.state = on ? .on : .off
        window.title = on ? "" : (webView.title.flatMap { $0.isEmpty ? nil : $0 } ?? "OKX Mini Chart")
    }

    @objc private func sliderMoved(_ sender: NSSlider) { setOpacity(sender.doubleValue) }
    @objc private func moreTransparent() { setOpacity(window.alphaValue - 0.1) }
    @objc private func lessTransparent() { setOpacity(window.alphaValue + 0.1) }

    private func setOpacity(_ value: Double) {
        let v = min(max(value, minOpacity), 1)
        window.alphaValue = v
        opacitySlider.doubleValue = v
        UserDefaults.standard.set(v, forKey: opacityKey)
    }

    private func addOpacitySlider() {
        opacitySlider = NSSlider(value: 1, minValue: minOpacity, maxValue: 1, target: self, action: #selector(sliderMoved(_:)))
        opacitySlider.controlSize = .small
        opacitySlider.isContinuous = true
        opacitySlider.toolTip = "창 투명도 (왼쪽으로 끌수록 투명)"
        opacitySlider.frame = NSRect(x: 4, y: 3, width: 84, height: 22)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 28))
        container.addSubview(opacitySlider)
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = container
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)
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
        disguiseItem = NSMenuItem(title: "위장 모드", action: #selector(toggleDisguise), keyEquivalent: "d")
        disguiseItem.target = self
        view.addItem(disguiseItem)
        let shotItem = NSMenuItem(title: "차트 캡처", action: #selector(capture), keyEquivalent: "s")
        shotItem.target = self
        view.addItem(shotItem)
        let winShotItem = NSMenuItem(title: "창 전체 캡처", action: #selector(captureWindow), keyEquivalent: "S")
        winShotItem.target = self
        view.addItem(winShotItem)
        let foldItem = NSMenuItem(title: "주문 패널 접기·펼치기", action: #selector(toggleTradeFold), keyEquivalent: "]")
        foldItem.target = self
        view.addItem(foldItem)
        view.addItem(.separator())
        let more = NSMenuItem(title: "더 투명하게", action: #selector(moreTransparent), keyEquivalent: "-")
        more.keyEquivalentModifierMask = [.command, .option]
        more.target = self
        view.addItem(more)
        let less = NSMenuItem(title: "덜 투명하게", action: #selector(lessTransparent), keyEquivalent: "=")
        less.keyEquivalentModifierMask = [.command, .option]
        less.target = self
        view.addItem(less)
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
