import Foundation

/// Parses and serializes standard OpenSSH ssh_config format.
/// Groups are stored as comments: # Group: <name>
struct SSHConfigParser {

    // MARK: - Parse

    static func parse(_ text: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var current: SSHHost?
        var currentGroup = ""
        var globalDefaults = SSHHost()  // collects Host * settings
        var inGlobal = false

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Parse group comments:
            // "# Group: Dev"
            // "# ==================== GROUP: Dev ===================="
            if line.hasPrefix("#") {
                let stripped = line
                    .drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "="))
                    .trimmingCharacters(in: .whitespaces)

                if stripped.lowercased().hasPrefix("group:") {
                    currentGroup = String(stripped.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if line.isEmpty { continue }

            let parts = splitDirective(line)
            guard let key = parts.key else { continue }
            let value = parts.value

            if key.lowercased() == "host" {
                // Save previous host
                if let h = current, !h.alias.isEmpty {
                    hosts.append(h)
                }
                if value == "*" {
                    // Enter global defaults block
                    inGlobal = true
                    current = nil
                    continue
                }
                inGlobal = false
                current = SSHHost(alias: value, group: currentGroup)
            } else if inGlobal {
                // Apply to global defaults
                applyDirective(key: key, value: value, to: &globalDefaults)
            } else if var host = current {
                applyDirective(key: key, value: value, to: &host)
                current = host
            }
        }

        // Don't forget last host
        if let h = current, !h.alias.isEmpty {
            hosts.append(h)
        }

        // Apply global defaults to hosts missing those values
        for i in hosts.indices {
            if hosts[i].user.isEmpty && !globalDefaults.user.isEmpty {
                hosts[i].user = globalDefaults.user
            }
            if hosts[i].port == 22 && globalDefaults.port != 22 {
                hosts[i].port = globalDefaults.port
            }
            if hosts[i].identityFile.isEmpty && !globalDefaults.identityFile.isEmpty {
                hosts[i].identityFile = globalDefaults.identityFile
            }
            if !hosts[i].forwardAgent && globalDefaults.forwardAgent {
                hosts[i].forwardAgent = globalDefaults.forwardAgent
            }
        }

        return hosts
    }

    // MARK: - Serialize

    static func serialize(_ hosts: [SSHHost]) -> String {
        var lines: [String] = []
        var lastGroup = ""

        // Group hosts by their group, preserving order within groups
        let grouped = Dictionary(grouping: hosts, by: { $0.group })
        // Output ungrouped first, then each group
        let sortedGroups = grouped.keys.sorted { a, b in
            if a.isEmpty { return true }
            if b.isEmpty { return false }
            return a < b
        }

        for group in sortedGroups {
            guard let groupHosts = grouped[group] else { continue }

            if !group.isEmpty && group != lastGroup {
                if !lines.isEmpty { lines.append("") }
                lines.append("# ==================== GROUP: \(group) ====================")
                lines.append("")
            }
            lastGroup = group

            for host in groupHosts {
                lines.append("Host \(host.alias)")

                if !host.hostName.isEmpty {
                    lines.append("    HostName \(host.hostName)")
                }
                if !host.user.isEmpty {
                    lines.append("    User \(host.user)")
                }
                if host.port != 22 {
                    lines.append("    Port \(host.port)")
                }
                if !host.identityFile.isEmpty {
                    lines.append("    IdentityFile \(host.identityFile)")
                }
                if host.forwardAgent {
                    lines.append("    ForwardAgent yes")
                }

                for key in host.extraOptions.keys.sorted() {
                    if let val = host.extraOptions[key] {
                        lines.append("    \(key) \(val)")
                    }
                }

                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func splitDirective(_ line: String) -> (key: String?, value: String) {
        let separators = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "="))
        guard let firstSpace = line.unicodeScalars.firstIndex(where: { separators.contains($0) }) else {
            return (line, "")
        }
        let key = String(line[line.startIndex..<firstSpace])
        let rest = line[firstSpace...].drop(while: { separators.contains($0.unicodeScalars.first!) })
        return (key, String(rest))
    }

    private static func applyDirective(key: String, value: String, to host: inout SSHHost) {
        switch key.lowercased() {
        case "hostname":
            host.hostName = value
        case "user":
            host.user = value
        case "port":
            host.port = Int(value) ?? 22
        case "identityfile":
            host.identityFile = value
        case "forwardagent":
            host.forwardAgent = value.lowercased() == "yes"
        default:
            host.extraOptions[key] = value
        }
    }
}
