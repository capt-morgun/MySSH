import Foundation

struct SSHHost: Identifiable, Equatable, Hashable {
    let id: UUID
    var alias: String          // Host alias (the "Host xxx" line)
    var hostName: String       // HostName (IP or domain)
    var user: String
    var port: Int
    var identityFile: String   // Path to SSH key
    var forwardAgent: Bool
    var group: String          // Group name (from "# Group: xxx" comment)
    var extraOptions: [String: String]  // Any other ssh_config options

    init(
        id: UUID = UUID(),
        alias: String = "",
        hostName: String = "",
        user: String = "root",
        port: Int = 22,
        identityFile: String = "",
        forwardAgent: Bool = false,
        group: String = "",
        extraOptions: [String: String] = [:]
    ) {
        self.id = id
        self.alias = alias
        self.hostName = hostName
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.forwardAgent = forwardAgent
        self.group = group
        self.extraOptions = extraOptions
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
