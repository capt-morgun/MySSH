import SwiftUI

struct HostListView: View {
    @EnvironmentObject var store: SSHConfigStore
    @EnvironmentObject var appearance: AppearanceSettings
    @Binding var selectedHostIDs: Set<UUID>
    @Binding var searchText: String

    var filteredHosts: [SSHHost] {
        if searchText.isEmpty { return store.hosts }
        return store.hosts.filter {
            $0.alias.localizedCaseInsensitiveContains(searchText) ||
            $0.hostName.localizedCaseInsensitiveContains(searchText) ||
            $0.user.localizedCaseInsensitiveContains(searchText) ||
            $0.group.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedHosts: [(group: String, hosts: [SSHHost])] {
        var result: [(group: String, hosts: [SSHHost])] = []
        var seen: Set<String> = []
        for host in filteredHosts {
            if !seen.contains(host.group) {
                seen.insert(host.group)
                result.append((group: host.group, hosts: []))
            }
            if let idx = result.firstIndex(where: { $0.group == host.group }) {
                result[idx].hosts.append(host)
            }
        }
        return result
    }

    var body: some View {
        List(selection: $selectedHostIDs) {
            ForEach(groupedHosts, id: \.group) { section in
                Section {
                    ForEach(section.hosts) { host in
                        HostRowView(host: host, appearance: appearance)
                            .tag(host.id)
                            .contextMenu {
                                Button("Connect") {
                                    let app = TerminalApp(rawValue: UserDefaults.standard.string(forKey: "terminalApp") ?? "Terminal") ?? .terminal
                                    SSHLauncher.connect(to: host, using: app)
                                }
                                Button("Duplicate") {
                                    duplicateHost(host)
                                }
                                Divider()
                                if selectedHostIDs.count > 1 {
                                    Button("Delete \(selectedHostIDs.count) Selected", role: .destructive) {
                                        store.deleteHosts(ids: selectedHostIDs)
                                        selectedHostIDs.removeAll()
                                    }
                                } else {
                                    Button("Delete", role: .destructive) {
                                        store.deleteHost(host)
                                        selectedHostIDs.remove(host.id)
                                    }
                                }
                            }
                    }
                } header: {
                    Text(section.group.isEmpty ? "Ungrouped" : section.group.uppercased())
                        .font(appearance.groupFont)
                        .foregroundStyle(appearance.groupHeaderColor)
                        .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(appearance.backgroundColor)
        .background(DoubleClickListenerView {
            connectSelected()
        })
    }

    private func connectSelected() {
        guard selectedHostIDs.count == 1,
              let id = selectedHostIDs.first,
              let host = store.hosts.first(where: { $0.id == id }) else { return }
        let app = TerminalApp(rawValue: UserDefaults.standard.string(forKey: "terminalApp") ?? "Terminal") ?? .terminal
        SSHLauncher.connect(to: host, using: app)
    }

    private func duplicateHost(_ host: SSHHost) {
        let copy = SSHHost(
            alias: host.alias + "-copy",
            hostName: host.hostName,
            user: host.user,
            port: host.port,
            identityFile: host.identityFile,
            forwardAgent: host.forwardAgent,
            group: host.group,
            extraOptions: host.extraOptions
        )
        store.addHost(copy)
        selectedHostIDs = [copy.id]
    }
}

struct DoubleClickListenerView: NSViewRepresentable {
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> DoubleClickNSView {
        let view = DoubleClickNSView()
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: DoubleClickNSView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
    }

    class DoubleClickNSView: NSView {
        var onDoubleClick: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self = self,
                      let window = self.window,
                      event.window == window,
                      event.clickCount == 2 else { return event }

                // Check if click is inside this view's bounds
                let locationInWindow = event.locationInWindow
                let locationInView = self.convert(locationInWindow, from: nil)
                if self.bounds.contains(locationInView) {
                    self.onDoubleClick?()
                }
                return event
            }
        }

        override func removeFromSuperview() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
            super.removeFromSuperview()
        }
    }
}

struct HostRowView: View {
    let host: SSHHost
    @ObservedObject var appearance: AppearanceSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(host.alias)
                .font(appearance.contentFont)
                .foregroundStyle(appearance.textColor)
            HStack(spacing: 4) {
                Text(host.user.isEmpty ? "" : "\(host.user)@")
                Text(host.hostName.isEmpty ? "—" : host.hostName)
                if host.port != 22 {
                    Text(":\(host.port)")
                }
            }
            .font(appearance.contentFont.monospaced())
            .foregroundStyle(appearance.textColor.opacity(0.6))
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
