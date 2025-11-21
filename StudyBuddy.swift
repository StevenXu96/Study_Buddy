import SwiftUI

@main
struct StudyBuddyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
        }
    }
}
