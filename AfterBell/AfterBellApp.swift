import SwiftUI

@main
struct AfterBellApp: App {
    @State private var store = HomeworkStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Homework") {
                    store.form = .add
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}
