import SwiftUI

struct HostDetailView: View {
    @EnvironmentObject var store: SSHConfigStore
    @EnvironmentObject var appearance: AppearanceSettings
    let hostID: UUID

    @State private var alias = ""
    @State private var hostName = ""
    @State private var user = ""
    @State private var port = ""
    @State private var identityFile = ""
    @State private var forwardAgent = false
    @State private var group = ""
    @State private var extraOptionsText = ""

    private var host: SSHHost? {
        store.hosts.first { $0.id == hostID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection
                GroupBox {
                    VStack(spacing: 10) {
                        labeledField("Alias (Host)", text: $alias)
                        labeledField("Hostname / IP", text: $hostName)
                        labeledField("User", text: $user)
                        labeledField("Port", text: $port)
                        HStack {
                            Text("Group")
                                .frame(width: 120, alignment: .leading)
                                .foregroundStyle(appearance.textColor)
                            TextField("e.g. Production", text: $group)
                                .textFieldStyle(.roundedBorder)
                            if !store.groups.filter({ !$0.isEmpty }).isEmpty {
                                Menu {
                                    ForEach(store.groups.filter { !$0.isEmpty }, id: \.self) { g in
                                        Button(g) { group = g }
                                    }
                                } label: {
                                    Image(systemName: "list.bullet")
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                            }
                        }
                    }
                } label: {
                    Text("Connection")
                        .font(appearance.contentFont)
                        .foregroundStyle(appearance.textColor)
                }

                // Authentication
                GroupBox {
                    VStack(spacing: 10) {
                        HStack {
                            Text("SSH Key")
                                .frame(width: 120, alignment: .leading)
                                .foregroundStyle(appearance.textColor)
                            TextField("SSH Key path", text: $identityFile)
                                .textFieldStyle(.roundedBorder)
                            Button("Browse...") { browseKey() }
                        }
                        HStack {
                            Text("Forward Agent")
                                .frame(width: 120, alignment: .leading)
                                .foregroundStyle(appearance.textColor)
                            Toggle("", isOn: $forwardAgent)
                                .labelsHidden()
                            Spacer()
                        }
                    }
                } label: {
                    Text("Authentication")
                        .font(appearance.contentFont)
                        .foregroundStyle(appearance.textColor)
                }

                // Extra Options
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("One per line: Key Value")
                            .font(.caption)
                            .foregroundStyle(appearance.textColor.opacity(0.5))
                        TextEditor(text: $extraOptionsText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                    }
                } label: {
                    Text("Extra Options")
                        .font(appearance.contentFont)
                        .foregroundStyle(appearance.textColor)
                }

                // Actions
                HStack {
                    Button("Connect") {
                        save()
                        let app = TerminalApp(rawValue: UserDefaults.standard.string(forKey: "terminalApp") ?? "Terminal") ?? .terminal
                        if let h = host { SSHLauncher.connect(to: h, using: app) }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)

                    Spacer()

                    Button("Save") { save() }
                        .keyboardShortcut("s", modifiers: .command)
                }
            }
            .padding(20)
        }
        .font(appearance.detailFont)
        .foregroundStyle(appearance.textColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadFields() }
        .onChange(of: hostID) { loadFields() }
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .frame(width: 120, alignment: .leading)
                .foregroundStyle(appearance.textColor)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func loadFields() {
        guard let h = host else { return }
        alias = h.alias
        hostName = h.hostName
        user = h.user
        port = "\(h.port)"
        identityFile = h.identityFile
        forwardAgent = h.forwardAgent
        group = h.group
        extraOptionsText = h.extraOptions.map { "\($0.key) \($0.value)" }.joined(separator: "\n")
    }

    private func save() {
        guard var h = host else { return }
        h.alias = alias
        h.hostName = hostName
        h.user = user
        h.port = Int(port) ?? 22
        h.identityFile = identityFile
        h.forwardAgent = forwardAgent
        h.group = group

        var extras: [String: String] = [:]
        for line in extraOptionsText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            if parts.count == 2 {
                extras[String(parts[0])] = String(parts[1])
            }
        }
        h.extraOptions = extras

        store.updateHost(h)
    }

    private func browseKey() {
        let panel = NSOpenPanel()
        panel.title = "Select SSH Key"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")

        if panel.runModal() == .OK, let url = panel.url {
            identityFile = url.path
        }
    }
}

struct EmptyDetailView: View {
    @EnvironmentObject var appearance: AppearanceSettings

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(appearance.textColor.opacity(0.4))
            Text("Select a server or add a new one")
                .font(appearance.detailFont)
                .foregroundStyle(appearance.textColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
