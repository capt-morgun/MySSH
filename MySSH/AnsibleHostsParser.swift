import Foundation

struct AnsibleHostsParser {
    static func parse(_ text: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentGroup = ""

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                // Strip :children / :vars suffixes
                var groupName = String(line.dropFirst().dropLast())
                if let colon = groupName.lastIndex(of: ":") {
                    groupName = String(groupName[groupName.startIndex..<colon])
                }
                currentGroup = groupName
                continue
            }

            if let host = parseEntry(line, group: currentGroup) {
                hosts.append(host)
            }
        }

        return hosts
    }

    private static func parseEntry(_ line: String, group: String) -> SSHHost? {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { return nil }

        let alias = parts[0]
        var hostName = ""
        var user = "root"
        var port = 22

        for part in parts.dropFirst() {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            switch kv[0] {
            case "ansible_host": hostName = kv[1]
            case "ansible_user": user = kv[1]
            case "ansible_port": port = Int(kv[1]) ?? 22
            default: break
            }
        }

        guard !hostName.isEmpty else { return nil }

        return SSHHost(alias: alias, hostName: hostName, user: user, port: port, group: group)
    }
}
