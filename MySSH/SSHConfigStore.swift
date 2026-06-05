import Foundation
import Combine
import SwiftUI

/// Manages reading/writing the ssh_config file directly in iCloud Drive.
/// Path: ~/Library/Mobile Documents/com~apple~CloudDocs/MySSH/ssh_config
class SSHConfigStore: ObservableObject {
    @Published var hosts: [SSHHost] = []

    private let fileURL: URL
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    init() {
        // Store config directly in iCloud Drive folder
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/MySSH")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("ssh_config")

        loadConfig()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Load / Save

    func loadConfig() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else { return }

        let parsed = SSHConfigParser.parse(text)
        DispatchQueue.main.async {
            self.hosts = parsed
        }
    }

    func saveConfig() {
        let text = SSHConfigParser.serialize(hosts)
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    // MARK: - CRUD

    func addHost(_ host: SSHHost) {
        hosts.append(host)
        saveConfig()
    }

    func updateHost(_ host: SSHHost) {
        if let idx = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[idx] = host
            saveConfig()
        }
    }

    func deleteHost(_ host: SSHHost) {
        hosts.removeAll { $0.id == host.id }
        saveConfig()
    }

    func deleteHosts(at offsets: IndexSet) {
        hosts.remove(atOffsets: offsets)
        saveConfig()
    }

    func deleteHosts(ids: Set<UUID>) {
        hosts.removeAll { ids.contains($0.id) }
        saveConfig()
    }

    var groups: [String] {
        let allGroups = Set(hosts.map { $0.group })
        return [""] + allGroups.filter { !$0.isEmpty }.sorted()
    }

    func importFromFile(at url: URL) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }
        let imported = SSHConfigParser.parse(text)
        hosts.append(contentsOf: imported)
        saveConfig()
    }

    /// Returns number of actually imported hosts (skips duplicates by IP+alias).
    @discardableResult
    func importFromAnsibleFile(at url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return 0 }
        return importFromAnsibleText(text)
    }

    @discardableResult
    func importFromAnsibleText(_ text: String) -> Int {
        let imported = AnsibleHostsParser.parse(text)
        var added = 0
        for host in imported {
            let duplicate = hosts.contains {
                $0.hostName == host.hostName && $0.alias == host.alias
            }
            if !duplicate {
                hosts.append(host)
                added += 1
            }
        }
        if added > 0 { saveConfig() }
        return added
    }

    // MARK: - File Monitoring (detect external/iCloud changes)

    private func startMonitoring() {
        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.loadConfig()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }
        source.resume()
        fileMonitor = source
    }

    private func stopMonitoring() {
        fileMonitor?.cancel()
        fileMonitor = nil
    }
}
