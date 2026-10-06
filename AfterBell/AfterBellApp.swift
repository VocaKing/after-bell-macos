import AVKit
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

struct IntroOverlay: View {
    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black
            IntroPlayer(onFinished: onFinished)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onFinished() }
    }
}

struct IntroPlayer: NSViewRepresentable {
    var onFinished: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinished: onFinished) }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        view.showsFullScreenToggleButton = false
        guard let url = Bundle.main.url(forResource: "Intro", withExtension: "mp4") else {
            DispatchQueue.main.async { onFinished() }
            return view
        }
        let player = AVPlayer(url: url)
        view.player = player
        context.coordinator.watch(player)
        player.play()
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

    final class Coordinator: NSObject {
        let onFinished: () -> Void
        var token: NSObjectProtocol?

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func watch(_ player: AVPlayer) {
            token = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.onFinished()
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}
