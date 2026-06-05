import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: SSHConfigStore
    @EnvironmentObject var appearance: AppearanceSettings
    @State private var selectedHostIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var showImportFilePicker = false
    @State private var showAnsibleImportSheet = false
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: toolbar + list
            VStack(spacing: 0) {
                // Thin bar: search + buttons
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .frame(height: 16)

                    Menu {
                        Button("Import from ~/.ssh/config") {
                            importSystemConfig()
                        }
                        Button("Import from file...") {
                            showImportFilePicker = true
                        }
                        Button("Import from Ansible hosts...") {
                            showAnsibleImportSheet = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    if selectedHostIDs.count > 1 {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "trash")
                                Text("\(selectedHostIDs.count)")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: addHost) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(appearance.backgroundColor.opacity(0.8))
                .overlay(alignment: .bottom) { Divider() }

                // Host list
                HostListView(selectedHostIDs: $selectedHostIDs, searchText: $searchText)
            }
            .frame(width: 280)

            Divider()

            // Right panel: detail, full height
            Group {
                if selectedHostIDs.count == 1, let id = selectedHostIDs.first {
                    HostDetailView(hostID: id)
                } else if selectedHostIDs.count > 1 {
                    MultiSelectionView(count: selectedHostIDs.count) {
                        store.deleteHosts(ids: selectedHostIDs)
                        selectedHostIDs.removeAll()
                    }
                } else {
                    EmptyDetailView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 750, minHeight: 500)
        .background(appearance.backgroundColor)
        .confirmationDialog(
            "Delete \(selectedHostIDs.count) servers?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedHostIDs.count) servers", role: .destructive) {
                store.deleteHosts(ids: selectedHostIDs)
                selectedHostIDs.removeAll()
            }
        }
        .fileImporter(isPresented: $showImportFilePicker, allowedContentTypes: [.plainText, .data]) { result in
            if case .success(let url) = result {
                importFrom(url: url)
            }
        }
        .sheet(isPresented: $showAnsibleImportSheet) {
            AnsibleImportView { message in
                importAlertMessage = message
                showImportAlert = true
            }
            .environmentObject(store)
        }
        .alert("Import", isPresented: $showImportAlert) {
            Button("OK") {}
        } message: {
            Text(importAlertMessage)
        }
    }

    private func addHost() {
        let host = SSHHost(alias: "new-server", hostName: "", user: "root")
        store.addHost(host)
        selectedHostIDs = [host.id]
    }

    private func importSystemConfig() {
        let sshConfig = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")
        importFrom(url: sshConfig)
    }

    private func importFrom(url: URL) {
        let countBefore = store.hosts.count
        store.importFromFile(at: url)
        let imported = store.hosts.count - countBefore
        importAlertMessage = imported > 0
            ? "Imported \(imported) server(s)."
            : "No servers found in file."
        showImportAlert = true
    }

}

struct MultiSelectionView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    let count: Int
    let onDelete: () -> Void
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(appearance.accentColor)
            Text("\(count) servers selected")
                .font(appearance.detailFont)
                .foregroundStyle(appearance.textColor)
            Button("Delete Selected", role: .destructive) {
                showConfirm = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .confirmationDialog("Delete \(count) servers?", isPresented: $showConfirm, titleVisibility: .visible) {
                Button("Delete \(count) servers", role: .destructive) {
                    onDelete()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
