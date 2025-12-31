import SwiftUI

// MARK: - PlayerFullView

/// A full-screen minimal player view displayed when "Player View" mode is active.
/// Features large artwork and controls for an immersive listening experience.
@available(macOS 26.0, *)
struct PlayerFullView: View {
    @Environment(PlayerService.self) private var playerService

    /// Namespace for potential morphing transitions.
    @Namespace private var fullPlayerNamespace

    /// State for full artwork immersion
    @State private var isFullArtworkMode = false

    /// Local interaction states for smooth slider dragging (similar to PlayerBar)
    @State private var seekValue: Double = 0
    @State private var isSeeking = false
    @State private var volumeValue: Double = 1.0
    @State private var isAdjustingVolume = false

    var body: some View {
        ZStack {
            // Background: Heavily blurred album art (always present for depth)
            self.backgroundView

            if self.isFullArtworkMode {
                // Full Artwork Mode Layout
                self.fullArtworkLayout
            } else {
                // Standard Player Layout
                self.standardLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            self.volumeValue = self.playerService.volume
            if self.playerService.duration > 0 {
                self.seekValue = self.playerService.progress / self.playerService.duration
            }
        }
        .onChange(of: self.playerService.progress) { _, newValue in
            if !self.isSeeking, self.playerService.duration > 0 {
                self.seekValue = newValue / self.playerService.duration
            }
        }
        .onChange(of: self.playerService.volume) { _, newValue in
            if !self.isAdjustingVolume {
                self.volumeValue = newValue
            }
        }
    }

    // MARK: - Layouts

    private var standardLayout: some View {
        VStack(spacing: 0) {
            // Top: Close Button
            self.headerView
                .transition(.move(edge: .top).combined(with: .opacity))

            Spacer()

            // Center: Immersive Content
            VStack(spacing: 48) {
                self.artworkView
                    .onTapGesture {
                        withAnimation(AppAnimation.standard) {
                            self.isFullArtworkMode = true
                        }
                    }

                VStack(spacing: 32) {
                    self.trackInfoView
                    self.controlsView
                    self.slidersView
                }
                .frame(maxWidth: 600)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
        }
        .padding(.bottom, 60)
    }

    private var fullArtworkLayout: some View {
        ZStack {
            // Fill background with artwork
            self.artworkView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            // Bottom-Leading Track Info with wide gradient for readability
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    self.trackInfoView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
                .padding(.top, 100) // Gradient height
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.7), .black.opacity(0.35), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppAnimation.standard) {
                self.isFullArtworkMode = false
            }
        }
        .transition(.opacity)
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        GeometryReader { geometry in
            Group {
                if let track = self.playerService.currentTrack, let thumbnailURL = track.thumbnailURL?.highQualityThumbnailURL {
                    CachedAsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: 80)
                            .opacity(0.4)
                            .scaleEffect(1.2) // Slight over-scale to hide blur edges
                    } placeholder: {
                        Color.black
                    }
                } else {
                    Color.black
                }
            }
        }
        .ignoresSafeArea()
    }

    private var headerView: some View {
        HStack {
            Spacer()
            Button {
                HapticService.navigation()
                withAnimation(AppAnimation.standard) {
                    self.playerService.isPlayerViewMode = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(12)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())
                    .accessibilityLabel("Exit Player View")
                    .accessibilityIdentifier("ExitPlayerViewButton")
            }
            .buttonStyle(.plain)
            .help("Exit Player View")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(32)
    }

    private var artworkView: some View {
        CachedAsyncImage(url: self.playerService.currentTrack?.thumbnailURL?.highQualityThumbnailURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: self.isFullArtworkMode ? 0 : 24)
                .fill(.white.opacity(0.05))
                .overlay {
                    CassetteIcon(size: 100)
                        .foregroundStyle(.white.opacity(0.2))
                }
        }
        .frame(width: self.isFullArtworkMode ? nil : 380, height: self.isFullArtworkMode ? nil : 380)
        .clipShape(RoundedRectangle(cornerRadius: self.isFullArtworkMode ? 0 : 24))
        .shadow(color: .black.opacity(0.6), radius: self.isFullArtworkMode ? 0 : 40, x: 0, y: 20)
    }

    private var trackInfoView: some View {
        VStack(alignment: self.isFullArtworkMode ? .leading : .center, spacing: 8) {
            Text(self.playerService.currentTrack?.title ?? "Not Playing")
                .font(.system(size: self.isFullArtworkMode ? 40 : 32, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(self.playerService.currentTrack?.artistsDisplay ?? "Unknown Artist")
                .font(.system(size: self.isFullArtworkMode ? 24 : 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }

    private var controlsView: some View {
        HStack(spacing: 50) {
            // Previous
            Button {
                HapticService.playback()
                Task { await self.playerService.previous() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.pressable)

            // Play/Pause
            Button {
                HapticService.playback()
                Task { await self.playerService.playPause() }
            } label: {
                Image(systemName: self.playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)

            // Next
            Button {
                HapticService.playback()
                Task { await self.playerService.next() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.pressable)
        }
    }

    private var slidersView: some View {
        VStack(spacing: 24) {
            // Seek Bar
            VStack(spacing: 8) {
                Slider(value: self.$seekValue, in: 0 ... 1) { editing in
                    if editing {
                        self.isSeeking = true
                    } else {
                        self.performSeek()
                    }
                }
                .accentColor(.white)

                HStack {
                    Text(self.formatTime(self.isSeeking ? self.seekValue * self.playerService.duration : self.playerService.progress))
                        .font(.system(size: 12, design: .monospaced))
                    Spacer()
                    Text("-\(self.formatTime(self.playerService.duration - (self.isSeeking ? self.seekValue * self.playerService.duration : self.playerService.progress)))")
                        .font(.system(size: 12, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.4))
            }

            // Volume
            HStack(spacing: 16) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))

                Slider(value: self.$volumeValue, in: 0 ... 1) { editing in
                    if editing {
                        self.isAdjustingVolume = true
                    } else {
                        self.isAdjustingVolume = false
                        Task { await self.playerService.setVolume(self.volumeValue) }
                    }
                }
                .accentColor(.white.opacity(0.6))
                .onChange(of: self.volumeValue) { oldValue, newValue in
                    if self.isAdjustingVolume {
                        Task { await self.playerService.setVolume(newValue) }
                    }
                }

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: 300)
        }
    }

    // MARK: - Helper Methods

    private func performSeek() {
        guard self.isSeeking else { return }
        let seekTime = self.seekValue * self.playerService.duration
        Task {
            await self.playerService.seek(to: seekTime)
            self.isSeeking = false
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
