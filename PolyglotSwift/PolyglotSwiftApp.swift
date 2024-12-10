//
//  PolyglotSwiftApp.swift
//  PolyglotSwift
//
//  Created by Ethan on 2024-12-08.
//

import SwiftUI

@main
struct PolyglotSwiftApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView() 
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("DeepL Settings...") {
                    openSettings()
                }
            }
        }
    }
    
    private func openSettings() {
        if let window = NSApplication.shared.windows.first {
            let settingsView = SettingsView()
            let controller = NSHostingController(rootView: settingsView)
            let sheet = NSWindow(contentViewController: controller)
            sheet.title = "DeepL Settings"
            window.beginSheet(sheet)
        }
    }
}
