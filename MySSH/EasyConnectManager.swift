import AppKit
import Combine
import ApplicationServices

class EasyConnectManager: ObservableObject {
    @Published var isAccessibilityGranted: Bool = false

    private var settings: EasyConnectSettings?
    private var store: SSHConfigStore?
    private var monitor: Any?
    private var axTimer: Timer?
    private var settingsCancellable: AnyCancellable?
    private var lastHotkeyFireDate = Date.distantPast
    private let hotkeyCooldown: TimeInterval = 0.8

    func configure(settings: EasyConnectSettings, store: SSHConfigStore) {
        self.settings = settings
        self.store = store
        checkAccessibility()
        startAXPolling()

        settingsCancellable = settings.$isEnabled
            .combineLatest(settings.$hotkeyKeyCode, settings.$hotkeyModifiers)
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled, keyCode, mods in
                print("[EasyConnect] settings changed → enabled=\(enabled) keyCode=\(keyCode) mods=\(mods)")
                self?.reregisterMonitor()
            }

        reregisterMonitor()
    }

    func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        print("[EasyConnect] AXIsProcessTrusted=\(trusted)")
        DispatchQueue.main.async { self.isAccessibilityGranted = trusted }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func reregisterMonitor() {
        stopMonitor()
        guard let settings = settings else {
            print("[EasyConnect] reregister: no settings"); return
        }
        guard settings.isEnabled else {
            print("[EasyConnect] reregister: disabled"); return
        }
        guard settings.hasHotkey else {
            print("[EasyConnect] reregister: no hotkey set"); return
        }
        guard AXIsProcessTrusted() else {
            print("[EasyConnect] reregister: Accessibility NOT granted"); return
        }

        let targetCode = CGKeyCode(settings.hotkeyKeyCode)
        let targetMods = settings.modifierFlags
        print("[EasyConnect] monitor registered — keyCode=\(settings.hotkeyKeyCode) mods=\(settings.hotkeyModifiers) display=\(settings.hotkeyDisplay)")

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            var eventMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            eventMods.remove(.capsLock)
            if !event.isARepeat && event.keyCode == targetCode && eventMods == targetMods {
                let now = Date()
                guard now.timeIntervalSince(self?.lastHotkeyFireDate ?? .distantPast) >= (self?.hotkeyCooldown ?? 0) else {
                    print("[EasyConnect] hotkey ignored — debounce")
                    return
                }
                self?.lastHotkeyFireDate = now
                print("[EasyConnect] hotkey matched — code=\(event.keyCode) mods=\(eventMods.rawValue)")
                self?.handleHotkey()
            }
        }
    }

    func stopMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    private func startAXPolling() {
        axTimer?.invalidate()
        axTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                if self.isAccessibilityGranted != trusted {
                    self.isAccessibilityGranted = trusted
                    if trusted { self.reregisterMonitor() }
                }
            }
        }
    }

    // MARK: - Hotkey action

    private func handleHotkey() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            let text = self.selectedText()
            print("[EasyConnect] hotkey fired — selectedText='\(text)'")
            guard let target = self.extractTarget(from: text) else {
                print("[EasyConnect] no target extracted from: '\(text)'")
                return
            }
            print("[EasyConnect] connecting → host=\(target.host) port=\(target.port as Any)")
            // launch must be called on main thread (reads store, calls SSHLauncher)
            DispatchQueue.main.async { self.launch(host: target.host, port: target.port) }
        }
    }

    private func launch(host: String, port: Int?) {
        guard let settings = settings, let store = store else {
            print("[EasyConnect] launch: settings or store is nil"); return
        }

        let existing = store.hosts.first { $0.hostName == host || $0.alias == host }
        let sshHost: SSHHost = existing ?? SSHHost(
            alias: host, hostName: host,
            user: settings.defaultUser,
            port: port ?? settings.defaultPort,
            identityFile: settings.defaultIdentityFile
        )

        let ecTerm = settings.terminalApp
        let termName = ecTerm.isEmpty
            ? (UserDefaults.standard.string(forKey: "terminalApp") ?? "Terminal")
            : ecTerm
        let terminal = TerminalApp(rawValue: termName) ?? .terminal

        let cmd = SSHLauncher.sshCommand(for: sshHost)
        print("[EasyConnect] launch: terminal=\(terminal.rawValue) running=\(terminal.isRunning) cmd=\(cmd)")
        SSHLauncher.connect(to: sshHost, using: terminal)
    }

    /// Reads selected text from the frontmost app. AX is instant when the app exposes
    /// selected text; the copy fallback covers browsers and custom text controls.
    private func selectedText() -> String {
        if let text = selectedTextFromAccessibility() {
            print("[EasyConnect] selectedText via AX: '\(text)'")
            return text
        }

        if let text = selectedTextByCopyingSelection() {
            print("[EasyConnect] selectedText via copy fallback: '\(text)'")
            return text
        }

        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        print("[EasyConnect] selectedText via existing clipboard: '\(clipboard)'")
        return clipboard
    }

    private func selectedTextFromAccessibility() -> String? {
        let system = AXUIElementCreateSystemWide()
        var elementRef: AnyObject?
        let elementError = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &elementRef)
        guard elementError == .success, let uiElement = elementRef else { return nil }

        var textRef: AnyObject?
        let textError = AXUIElementCopyAttributeValue(uiElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &textRef)
        guard textError == .success,
              let text = textRef as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return text
    }

    private func selectedTextByCopyingSelection() -> String? {
        let pasteboard = NSPasteboard.general

        let (snapshot, previousChangeCount) = DispatchQueue.main.sync {
            (PasteboardSnapshot.capture(from: pasteboard), pasteboard.changeCount)
        }
        DispatchQueue.main.sync {
            pasteboard.clearContents()
            sendCopyShortcut()
        }

        let deadline = Date().addingTimeInterval(0.35)
        var copied: String?
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
            let (changed, text) = DispatchQueue.main.sync { () -> (Bool, String?) in
                let changed = pasteboard.changeCount != previousChangeCount
                return (changed, changed ? pasteboard.string(forType: .string) : nil)
            }
            guard changed else { continue }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copied = text
                break
            }
        }

        DispatchQueue.main.sync { snapshot.restore(to: pasteboard) }
        return copied
    }

    private func sendCopyShortcut() {
        let source = CGEventSource(stateID: .privateState)
        let cKeyCode: CGKeyCode = 8
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Target extraction

    private func extractTarget(from raw: String) -> (host: String, port: Int?)? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let portOverride = extractSSHPort(from: text)
        for token in targetTokens(from: text) {
            guard !isIgnoredTargetToken(token) else { continue }
            if var target = parseTargetToken(token) {
                if target.port == nil { target.port = portOverride }
                return target
            }
        }

        return nil
    }

    private func targetTokens(from text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\"'`,;(){}<>"))
        return text
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
    }

    private func isIgnoredTargetToken(_ token: String) -> Bool {
        let lowercased = token.lowercased()
        return lowercased == "ssh"
            || lowercased == "scp"
            || lowercased == "sftp"
            || lowercased.hasPrefix("-")
    }

    private func parseTargetToken(_ rawToken: String) -> (host: String, port: Int?)? {
        var token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: "[]\"'`,;(){}<>"))
        guard !token.isEmpty else { return nil }

        if token.lowercased().hasPrefix("ssh://"),
           let components = URLComponents(string: token),
           let host = components.host,
           isValidHost(host),
           isValidPort(components.port) {
            return (host, components.port)
        }

        token = token.components(separatedBy: "@").last ?? token

        let pieces = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let hostPart = pieces.first else { return nil }

        let host = String(hostPart)
        let port: Int?
        if pieces.count == 2 {
            guard let parsedPort = Int(pieces[1]) else { return nil }
            port = parsedPort
        } else {
            port = nil
        }
        guard isValidHost(host), isValidPort(port) else { return nil }

        return (host, port)
    }

    private func extractSSHPort(from text: String) -> Int? {
        let pattern = #"(?:^|\s)-p\s+(\d{1,5})(?:\s|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text),
              let port = Int(text[range]),
              isValidPort(port) else {
            return nil
        }
        return port
    }

    private func isValidHost(_ host: String) -> Bool {
        if isValidIPv4(host) { return true }
        return isValidHostname(host)
    }

    private func isValidIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), value >= 0, value <= 255 else { return false }
            return String(part) == "\(value)"
        }
    }

    private func isValidHostname(_ host: String) -> Bool {
        guard host.count <= 253,
              host.rangeOfCharacter(from: .alphanumerics) != nil,
              Int(host) == nil else {
            return false
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard host.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { label in
            guard !label.isEmpty else { return false }
            return !label.hasPrefix("-") && !label.hasSuffix("-")
        }
    }

    private func isValidPort(_ port: Int?) -> Bool {
        guard let port = port else { return true }
        return (1...65535).contains(port)
    }

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]

        static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
            let items = pasteboard.pasteboardItems?.map { item in
                item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { result, type in
                    if let data = item.data(forType: type) {
                        result[type] = data
                    }
                }
            } ?? []
            return PasteboardSnapshot(items: items)
        }

        func restore(to pasteboard: NSPasteboard) {
            pasteboard.clearContents()
            guard !items.isEmpty else { return }

            let restoredItems = items.map { contents in
                let item = NSPasteboardItem()
                for (type, data) in contents {
                    item.setData(data, forType: type)
                }
                return item
            }
            pasteboard.writeObjects(restoredItems)
        }
    }

    deinit {
        stopMonitor()
        axTimer?.invalidate()
    }
}
