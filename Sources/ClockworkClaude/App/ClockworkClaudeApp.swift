import SwiftUI
import AppKit

@main
struct ClockworkClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var jobStore = JobStore()
    @State private var launchdService = LaunchdService()
    @State private var commandScanner = CommandScanner()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(jobStore)
                .environment(launchdService)
                .environment(commandScanner)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    launchdService.refreshStatus(for: jobStore.jobs)
                    jobStore.syncWithSystem(launchdService: launchdService)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
