import AppKit
import Foundation

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm = "iTerm"
    case warp = "Warp"
    case alacritty = "Alacritty"

    var id: String { rawValue }

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            switch self {
            case .terminal:  return app.bundleIdentifier == "com.apple.Terminal"
            case .iterm:     return app.bundleIdentifier == "com.googlecode.iterm2"
            case .warp:      return app.bundleIdentifier?.hasPrefix("dev.warp") == true
            case .alacritty: return app.bundleIdentifier == "org.alacritty"
            }
        }
    }
}

struct SSHLauncher {

    static func sshCommand(for host: SSHHost) -> String {
        var parts = ["ssh"]

        if host.port != 22 {
            parts.append("-p")
            parts.append("\(host.port)")
        }

        let key = host.identityFile.isEmpty
            ? UserDefaults.standard.string(forKey: "globalIdentityFile") ?? ""
            : host.identityFile
        if !key.isEmpty {
            parts.append("-i")
            parts.append(shellQuote(key))
        }

        if host.forwardAgent {
            parts.append("-A")
        }

        for (k, value) in host.extraOptions.sorted(by: { $0.key < $1.key }) {
            parts.append("-o")
            parts.append(shellQuote("\(k)=\(value)"))
        }

        let hostname = host.hostName.isEmpty ? host.alias : host.hostName
        let target = host.user.isEmpty ? hostname : "\(host.user)@\(hostname)"
        parts.append(shellQuote(target))

        return parts.joined(separator: " ")
    }

    static func connect(to host: SSHHost, using app: TerminalApp) {
        let command = sshCommand(for: host)
        let running = app.isRunning
        switch app {
        case .terminal:  launchInTerminal(command, appRunning: running)
        case .iterm:     launchInITerm(command, appRunning: running)
        case .warp:      launchInWarp(command, appRunning: running)
        case .alacritty: launchInAlacritty(command)
        }
    }

    // MARK: - Terminal.app

    private static func launchInTerminal(_ command: String, appRunning: Bool) {
        let commandLiteral = appleScriptString(command)
        let script: String
        if appRunning {
            // Cmd+T opens a new tab reliably; `do script in front window` behaviour
            // changed in recent macOS and may open a new window instead of a tab.
            script = """
            tell application "Terminal" to activate
            delay 0.1
            tell application "System Events" to keystroke "t" using {command down}
            delay 0.25
            tell application "Terminal" to do script \(commandLiteral) in front window
            """
        } else {
            script = """
            tell application "Terminal"
                activate
                do script \(commandLiteral)
            end tell
            """
        }
        runScript(script)
    }

    // MARK: - iTerm2

    private static func launchInITerm(_ command: String, appRunning: Bool) {
        let commandLiteral = appleScriptString(command)
        let script: String
        if appRunning {
            script = """
            tell application "iTerm"
                activate
                if (count of windows) > 0 then
                    tell current window
                        create tab with default profile command \(commandLiteral)
                    end tell
                else
                    create window with default profile command \(commandLiteral)
                end if
            end tell
            """
        } else {
            script = """
            tell application "iTerm"
                activate
                delay 1
                create window with default profile command \(commandLiteral)
            end tell
            """
        }
        runScript(script)
    }

    // MARK: - Warp
    // Warp has no AppleScript dictionary; use Cmd+T for new tab then type command.

    private static func launchInWarp(_ command: String, appRunning: Bool) {
        let commandLiteral = appleScriptString(command)
        let openDelay = appRunning ? "0.3" : "0.8"
        let newTabBlock = appRunning ? """
            keystroke "t" using {command down}
            delay 0.3
        """ : ""
        let script = """
        tell application "Warp" to activate
        delay \(openDelay)
        tell application "System Events"
            \(newTabBlock)keystroke \(commandLiteral)
            keystroke return
        end tell
        """
        runScript(script)
    }

    // MARK: - Alacritty (no tab support — always a new window)

    private static func launchInAlacritty(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Alacritty", "--args", "-e", "/bin/zsh", "-c", command]
        try? process.run()
    }

    // MARK: - Helpers

    private static func runScript(_ script: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { p in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if p.terminationStatus != 0 {
                print("[SSHLauncher] osascript failed status=\(p.terminationStatus): \(output)")
            }
        }
        do {
            try process.run()
        } catch {
            print("[SSHLauncher] osascript launch failed: \(error.localizedDescription)")
        }
    }

    private static func shellQuote(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }

        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-[]")
        if value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return value
        }

        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
