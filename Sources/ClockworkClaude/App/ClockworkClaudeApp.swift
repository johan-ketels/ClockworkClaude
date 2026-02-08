import SwiftUI
import AppKit
import CoreText

@main
struct ClockworkClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var jobStore = JobStore()
    @State private var launchdService = LaunchdService()
    @State private var commandScanner = CommandScanner()

    init() {
        if let fontURL = Bundle.module.url(forResource: "Timepiece", withExtension: "TTF")
            ?? Bundle.main.url(forResource: "Timepiece", withExtension: "TTF") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(jobStore)
                .environment(launchdService)
                .environment(commandScanner)
                .frame(minWidth: 960, minHeight: 600)
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
