import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct AnsibleImportView: View {
    @EnvironmentObject var store: SSHConfigStore
    let onComplete: (String) -> Void

    @State private var text = ""
    @State private var showFilePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Ansible Hosts")
                    .font(.headline)
                Spacer()
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                Button {
                    showFilePicker = true
                } label: {
                    Label("Browse file...", systemImage: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Text editor
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 260)
                .padding(8)

            Divider()

            // Footer
            HStack {
                if text.isEmpty {
                    Text("Paste or load an Ansible inventory file")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    let preview = AnsibleHostsParser.parse(text)
                    Text("\(preview.count) host(s) found")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Import") {
                    let added = store.importFromAnsibleText(text)
                    dismiss()
                    onComplete(added > 0
                        ? "Imported \(added) server(s) from Ansible hosts."
                        : "No new servers found (duplicates skipped).")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 540)
        .onAppear { pasteFromClipboard() }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.plainText, .data]) { result in
            if case .success(let url) = result,
               let content = try? String(contentsOf: url, encoding: .utf8) {
                text = content
            }
        }
    }

    private func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string), !s.isEmpty {
            text = s
        }
    }
}
