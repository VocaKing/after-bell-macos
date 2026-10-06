import AVKit
import SwiftUI

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
