import SwiftUI

/// A minimal player view designed for the sidebar.
/// Features metadata above the artwork and hover-triggered playback controls.
@available(macOS 26.0, *)
struct SidebarMiniPlayerView: View {
    @Environment(PlayerService.self) private var playerService
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top section: Metadata and Controls
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.playerService.currentTrack?.title ?? "Not Playing")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(self.playerService.currentTrack?.artistsDisplay ?? "Unknown Artist")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    // Like button
                    Button {
                        HapticService.toggle()
                        self.playerService.likeCurrentTrack()
                    } label: {
                        Image(systemName: self.playerService.currentTrackLikeStatus == .like ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(self.playerService.currentTrackLikeStatus == .like ? .red : .primary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help(self.playerService.currentTrackLikeStatus == .like ? "Unlike" : "Like")
                    .padding(6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())

                    // Return to Player Bar button
                    Button {
                        HapticService.navigation()
                        withAnimation(AppAnimation.standard) {
                            self.playerService.isSidebarMiniPlayerMode = false
                        }
                    } label: {
                        Image(systemName: "pip.exit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Return to Player Bar")
                    .padding(6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Center section: Artwork with Hover Controls
            GeometryReader { geometry in
                let size = geometry.size.width
                
                ZStack {
                    // Background Artwork
                    Group {
                        if let track = self.playerService.currentTrack, let thumbnailURL = track.thumbnailURL?.highQualityThumbnailURL {
                            CachedAsyncImage(url: thumbnailURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.black.opacity(0.1)
                            }
                        } else {
                            Color.white.opacity(0.05)
                                .overlay {
                                    CassetteIcon(size: size * 0.3)
                                        .foregroundStyle(.white.opacity(0.1))
                                }
                        }
                    }
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .blur(radius: self.isHovering ? 5 : 0)
                    .opacity(self.isHovering ? 0.7 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )

                    // Hover Controls (Playback)
                    if self.isHovering {
                        HStack(spacing: size * 0.12) {
                            Button {
                                HapticService.playback()
                                Task { await self.playerService.previous() }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: size * 0.09))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                HapticService.playback()
                                Task { await self.playerService.playPause() }
                            } label: {
                                Image(systemName: self.playerService.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: size * 0.16))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                HapticService.playback()
                                Task { await self.playerService.next() }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: size * 0.09))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isHovering = hovering
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 16)
        .background(GlassEffectContainer { Color.clear })
    }
}
