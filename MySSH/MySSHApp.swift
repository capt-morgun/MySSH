import SwiftUI

@main
struct MySSHApp: App {
    @StateObject private var store = SSHConfigStore()
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var ecSettings = EasyConnectSettings()
    @StateObject private var ecManager = EasyConnectManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appearance)
                .environmentObject(ecSettings)
                .environmentObject(ecManager)
                .tint(appearance.accentColor)
                .onAppear {
                    ecManager.configure(settings: ecSettings, store: store)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 550)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(appearance)
                .environmentObject(ecSettings)
                .environmentObject(ecManager)
        }
    }
}
