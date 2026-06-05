import Foundation
import AppKit
import Combine

class EasyConnectSettings: ObservableObject {
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    @Published var isEnabled: Bool
    @Published var defaultUser: String
    @Published var defaultPort: Int
    @Published var defaultIdentityFile: String
    @Published var terminalApp: String          // "" = use global General setting
    @Published var hotkeyKeyCode: Int
    @Published var hotkeyModifiers: Int         // stored as Int — NSNumber bridges cleanly
    @Published var hotkeyDisplay: String

    init() {
        isEnabled           = defaults.bool(forKey: "ec.isEnabled")
        defaultUser         = defaults.string(forKey: "ec.defaultUser")    ?? "root"
        let savedPort       = defaults.integer(forKey: "ec.defaultPort")
        defaultPort         = savedPort > 0 ? savedPort : 22
        defaultIdentityFile = defaults.string(forKey: "ec.identityFile")   ?? ""
        terminalApp         = defaults.string(forKey: "ec.terminalApp")    ?? ""
        hotkeyKeyCode       = defaults.integer(forKey: "ec.keyCode")       == 0
                                ? 14 : defaults.integer(forKey: "ec.keyCode")  // default 'e'
        hotkeyModifiers     = defaults.integer(forKey: "ec.modifiers")     == 0
                                ? Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
                                : defaults.integer(forKey: "ec.modifiers")
        hotkeyDisplay       = defaults.string(forKey: "ec.display")        ?? "⌘⇧E"

        $isEnabled.sink           { [weak self] v in self?.defaults.set(v, forKey: "ec.isEnabled") }.store(in: &cancellables)
        $defaultUser.sink         { [weak self] v in self?.defaults.set(v, forKey: "ec.defaultUser") }.store(in: &cancellables)
        $defaultPort.sink         { [weak self] v in self?.defaults.set(v, forKey: "ec.defaultPort") }.store(in: &cancellables)
        $defaultIdentityFile.sink { [weak self] v in self?.defaults.set(v, forKey: "ec.identityFile") }.store(in: &cancellables)
        $terminalApp.sink         { [weak self] v in self?.defaults.set(v, forKey: "ec.terminalApp") }.store(in: &cancellables)
        $hotkeyKeyCode.sink       { [weak self] v in self?.defaults.set(v, forKey: "ec.keyCode") }.store(in: &cancellables)
        $hotkeyModifiers.sink     { [weak self] v in self?.defaults.set(v, forKey: "ec.modifiers") }.store(in: &cancellables)
        $hotkeyDisplay.sink       { [weak self] v in self?.defaults.set(v, forKey: "ec.display") }.store(in: &cancellables)
    }

    var hasHotkey: Bool { hotkeyKeyCode != 0 }

    /// Effective modifier flags for comparison with NSEvent
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(hotkeyModifiers))
    }
}
