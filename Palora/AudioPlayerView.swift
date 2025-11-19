import SwiftUI
import AVFoundation

@Observable
@MainActor
final class AudioPlayer: NSObject {
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    func load(url: URL) throws {
        stop()
        
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        player?.volume = volume
        
        duration = player?.duration ?? 0
        currentTime = 0
    }
    
    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.stop()
        }
    }
}

struct AudioPlayerView: View {
    @State private var player = AudioPlayer()
    let audioURL: URL
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
                
                HStack {
                    Text(player.formattedCurrentTime)
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                    Text(player.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            
            // Controls
            HStack(spacing: 16) {
                Button(action: {
                    if player.isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                }) {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                }
                .buttonStyle(.plain)
                .disabled(player.duration == 0)
                
                // Volume control
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                    Slider(value: $player.volume, in: 0...1)
                        .frame(width: 100)
                    Image(systemName: "speaker.wave.3")
                        .font(.caption)
                }
            }
        }
        .padding()
        .onAppear {
            do {
                try player.load(url: audioURL)
            } catch {
                print("Failed to load audio: \(error)")
            }
        }
        .onDisappear {
            player.stop()
        }
    }
}

