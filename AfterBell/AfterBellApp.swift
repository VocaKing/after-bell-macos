import SwiftUI

@main
struct AfterBellApp: App {
    @State private var store = HomeworkStore()
    @State private var showIntro = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(store)
                if showIntro {
                    IntroOverlay {
                        withAnimation(.easeOut(duration: 0.35)) {
                            showIntro = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
                .frame(minWidth: 1080, minHeight: 720)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
                }
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
