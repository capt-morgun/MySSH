import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            EasyConnectSettingsView()
                .tabItem { Label("EasyConnect", systemImage: "bolt.fill") }
        }
        .frame(width: 500, height: 620)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @AppStorage("terminalApp") private var terminalApp = "Terminal"
    @AppStorage("globalIdentityFile") private var globalIdentityFile = ""
    @EnvironmentObject var store: SSHConfigStore
    @State private var showImportPicker = false
    @State private var showApplyConfirm = false

    var body: some View {
        Form {
            Section("Terminal Application") {
                Picker("Open SSH in:", selection: $terminalApp) {
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.rawValue).tag(app.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Global SSH Key") {
                HStack {
                    TextField("SSH Key path", text: $globalIdentityFile)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") { browseGlobalKey() }
                }
                Text("Used automatically when a server has no key of its own.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Apply to all servers without a key") {
                    showApplyConfirm = true
                }
                .confirmationDialog(
                    "Set this key on all servers that currently have no SSH key?",
                    isPresented: $showApplyConfirm, titleVisibility: .visible
                ) {
                    Button("Apply to all") {
                        applyGlobalKeyToAll()
                    }
                }

                Button("Change key on ALL servers") {
                    changeKeyOnAll()
                }
                .foregroundStyle(.orange)
            }

            Section("Import") {
                Button("Import from ~/.ssh/config") { importSystemConfig() }
                Button("Import from file...") { showImportPicker = true }
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.plainText, .data]) { result in
            if case .success(let url) = result {
                store.importFromFile(at: url)
            }
        }
    }

    private func browseGlobalKey() {
        let panel = NSOpenPanel()
        panel.title = "Select Global SSH Key"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")
        if panel.runModal() == .OK, let url = panel.url {
            globalIdentityFile = url.path
        }
    }

    private func applyGlobalKeyToAll() {
        guard !globalIdentityFile.isEmpty else { return }
        for i in store.hosts.indices {
            if store.hosts[i].identityFile.isEmpty {
                store.hosts[i].identityFile = globalIdentityFile
            }
        }
        store.saveConfig()
    }

    private func changeKeyOnAll() {
        guard !globalIdentityFile.isEmpty else { return }
        for i in store.hosts.indices {
            store.hosts[i].identityFile = globalIdentityFile
        }
        store.saveConfig()
    }

    private func importSystemConfig() {
        let sshConfig = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")
        store.importFromFile(at: sshConfig)
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @State private var textColor: Color = .primary
    @State private var bgColor: Color = Color(.windowBackgroundColor)
    @State private var accentColor: Color = .accentColor
    @State private var groupColor: Color = .orange

    var body: some View {
        Form {
            Section("Colors") {
                ColorPicker("Text color", selection: $textColor, supportsOpacity: false)
                    .onChange(of: textColor) { appearance.textColor = textColor }

                ColorPicker("Background color", selection: $bgColor, supportsOpacity: false)
                    .onChange(of: bgColor) { appearance.backgroundColor = bgColor }

                ColorPicker("Accent color", selection: $accentColor, supportsOpacity: false)
                    .onChange(of: accentColor) { appearance.accentColor = accentColor }

                ColorPicker("Group header color", selection: $groupColor, supportsOpacity: false)
                    .onChange(of: groupColor) { appearance.groupHeaderColor = groupColor }
            }

            Section("Font") {
                Picker("Font family", selection: $appearance.fontName) {
                    ForEach(AppearanceSettings.availableFonts, id: \.self) { name in
                        Text(name).font(name == "System" ? .system(size: 13) : .custom(name, size: 13))
                            .tag(name)
                    }
                }

                HStack {
                    Text("Content size")
                    Slider(value: $appearance.fontSize, in: 10...24, step: 1)
                    Text("\(Int(appearance.fontSize))pt")
                        .monospacedDigit()
                        .frame(width: 35)
                }
                Toggle("Bold content text", isOn: $appearance.fontBold)
            }

            Section("Group Headers") {
                HStack {
                    Text("Header size")
                    Slider(value: $appearance.groupFontSize, in: 10...28, step: 1)
                    Text("\(Int(appearance.groupFontSize))pt")
                        .monospacedDigit()
                        .frame(width: 35)
                }
                Toggle("Bold group headers", isOn: $appearance.groupFontBold)
            }

            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEV")
                        .font(appearance.groupFont)
                        .foregroundStyle(appearance.groupHeaderColor)
                    Text("my-server — root@192.168.1.1")
                        .font(appearance.contentFont)
                        .foregroundStyle(appearance.textColor)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(appearance.backgroundColor)
                .cornerRadius(6)
            }

            Section {
                Button("Reset to Defaults") {
                    appearance.resetToDefaults()
                    loadColors()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { loadColors() }
    }

    private func loadColors() {
        textColor = appearance.textColor
        bgColor = appearance.backgroundColor
        accentColor = appearance.accentColor
        groupColor = appearance.groupHeaderColor
    }
}
