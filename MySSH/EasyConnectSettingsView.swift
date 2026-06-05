import SwiftUI
import AppKit

// MARK: - Settings view

struct EasyConnectSettingsView: View {
    @EnvironmentObject var ecSettings: EasyConnectSettings
    @EnvironmentObject var ecManager: EasyConnectManager

    @State private var portText = ""

    var body: some View {
        Form {
            Section {
                Toggle("Enable EasyConnect", isOn: $ecSettings.isEnabled)
                    .disabled(!ecManager.isAccessibilityGranted)
                Text("Select an IP or hostname in any app, press the hotkey, and MySSH instantly opens an SSH connection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hotkey") {
                HStack {
                    Text("Shortcut")
                        .frame(width: 110, alignment: .leading)
                    HotkeyRecorderView(
                        keyCode: $ecSettings.hotkeyKeyCode,
                        modifiers: $ecSettings.hotkeyModifiers,
                        display: $ecSettings.hotkeyDisplay
                    ) {
                        if ecSettings.isEnabled { ecManager.reregisterMonitor() }
                    }
                    .frame(width: 160, height: 26)

                    if ecSettings.hasHotkey {
                        Button {
                            ecSettings.hotkeyKeyCode = 0
                            ecSettings.hotkeyModifiers = 0
                            ecSettings.hotkeyDisplay = ""
                            ecManager.stopMonitor()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Accessibility") {
                HStack(spacing: 10) {
                    Image(systemName: ecManager.isAccessibilityGranted
                          ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(ecManager.isAccessibilityGranted ? .green : .orange)
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ecManager.isAccessibilityGranted
                             ? "Accessibility access granted"
                             : "Accessibility access required")
                        if !ecManager.isAccessibilityGranted {
                            Text("Needed to read selected text in other apps.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !ecManager.isAccessibilityGranted {
                        Button("Grant Access") { ecManager.requestAccessibility() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .onAppear { ecManager.checkAccessibility() }
            }

            Section("Terminal") {
                Picker("Open SSH in:", selection: $ecSettings.terminalApp) {
                    Text("Same as General Settings").tag("")
                    Divider()
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.rawValue).tag(app.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Default Connection") {
                HStack {
                    Text("User")
                        .frame(width: 110, alignment: .leading)
                    TextField("root", text: $ecSettings.defaultUser)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Port")
                        .frame(width: 110, alignment: .leading)
                    TextField("22", text: $portText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: portText) { _, val in
                            if let p = Int(val), p > 0 { ecSettings.defaultPort = p }
                        }
                }
                HStack {
                    Text("SSH Key")
                        .frame(width: 110, alignment: .leading)
                    TextField("Optional", text: $ecSettings.defaultIdentityFile)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") { browseKey() }
                }
                Text("Applied when the host is not in your server list.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { portText = "\(ecSettings.defaultPort)" }
    }

    private func browseKey() {
        let panel = NSOpenPanel()
        panel.title = "Select SSH Key"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            ecSettings.defaultIdentityFile = url.path
        }
    }
}

// MARK: - Hotkey recorder

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @Binding var display: String
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> HotkeyButton {
        let btn = HotkeyButton()
        btn.coordinator = context.coordinator
        return btn
    }

    func updateNSView(_ nsView: HotkeyButton, context: Context) {
        context.coordinator.parent = self
        nsView.currentDisplay = display
        nsView.needsDisplay = true
    }

    class Coordinator: NSObject {
        var parent: HotkeyRecorderView
        init(_ parent: HotkeyRecorderView) { self.parent = parent }

        func recorded(keyCode: Int, modifiers: Int, display: String) {
            parent.keyCode = keyCode
            parent.modifiers = modifiers
            parent.display = display
            parent.onCommit()
        }
    }
}

// MARK: - HotkeyButton (NSView)

class HotkeyButton: NSView {
    weak var coordinator: HotkeyRecorderView.Coordinator?
    var currentDisplay: String = ""
    private(set) var isRecording = false
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return nil
        }
        needsDisplay = true
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        needsDisplay = true
    }

    private func handleKey(_ event: NSEvent) {
        if event.keyCode == 53 { stopRecording(); return }  // Esc = cancel

        // Ignore standalone modifier key presses
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        guard !modifierKeyCodes.contains(event.keyCode) else { return }

        var mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        mods.remove(.capsLock)
        guard !mods.isEmpty else { return }

        let display = mods.displayString + event.keyDisplayString
        coordinator?.recorded(keyCode: Int(event.keyCode), modifiers: Int(mods.rawValue), display: display)
        stopRecording()
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { stopRecording() }
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let label: String
        let textColor: NSColor
        if isRecording {
            label = "Press key combo…"
            textColor = .labelColor
            NSColor.selectedControlColor.withAlphaComponent(0.3).setFill()
        } else {
            label = currentDisplay.isEmpty ? "Click to record" : currentDisplay
            textColor = currentDisplay.isEmpty ? .placeholderTextColor : .labelColor
            NSColor.controlBackgroundColor.setFill()
        }

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: textColor
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let size = str.size()
        str.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                             y: (bounds.height - size.height) / 2))
    }
}

// MARK: - Helpers

private extension NSEvent.ModifierFlags {
    var displayString: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option)  { s += "⌥" }
        if contains(.shift)   { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

private extension NSEvent {
    var keyDisplayString: String {
        switch Int(keyCode) {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return charactersIgnoringModifiers?.uppercased() ?? "[\(keyCode)]"
        }
    }
}
