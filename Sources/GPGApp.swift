import SwiftUI
import AppKit

struct GPGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .navigationTitle("GPG App")
                .onDisappear {
                    NSApplication.shared.terminate(nil)
                }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure Logger
        #if DEBUG
        Logger.minimumLevel = .debug
        #else
        Logger.minimumLevel = .info
        #endif
        
        logInfo("Application started")
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logInfo("Application terminating")
    }
} 
