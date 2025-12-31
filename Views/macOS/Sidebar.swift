import SwiftUI

/// Sidebar navigation for the main window, styled like Apple Music.
@available(macOS 26.0, *)
struct Sidebar: View {
    @Environment(PlayerService.self) private var playerService
    @Binding var selection: NavigationItem?

    /// Namespace for glass effect morphing.
    @Namespace private var sidebarNamespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            List(selection: self.$selection) {
                // Main navigation
                Section {
                    NavigationLink(value: NavigationItem.search) {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.searchItem)

                    NavigationLink(value: NavigationItem.home) {
                        Label("Home", systemImage: "house")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.homeItem)
                }

                // Discover section
                Section("Discover") {
                    NavigationLink(value: NavigationItem.explore) {
                        Label("Explore", systemImage: "globe")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.exploreItem)

                    NavigationLink(value: NavigationItem.charts) {
                        Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.chartsItem)

                    NavigationLink(value: NavigationItem.moodsAndGenres) {
                        Label("Moods & Genres", systemImage: "theatermask.and.paintbrush")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.moodsAndGenresItem)

                    NavigationLink(value: NavigationItem.newReleases) {
                        Label("New Releases", systemImage: "sparkles")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.newReleasesItem)
                }

                // Library section
                Section("Library") {
                    NavigationLink(value: NavigationItem.likedMusic) {
                        Label("Liked Music", systemImage: "heart.fill")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.likedMusicItem)

                    NavigationLink(value: NavigationItem.library) {
                        Label("Playlists", systemImage: "music.note.list")
                    }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.libraryItem)
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                if self.playerService.isSidebarMiniPlayerMode {
                    Color.clear.frame(height: 220) // Match mini player height + padding
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
            .accessibilityIdentifier(AccessibilityID.Sidebar.container)
            .overlay(alignment: .bottom) {
                if self.playerService.isSidebarMiniPlayerMode {
                    SidebarMiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: self.selection) { _, newValue in
                if newValue != nil {
                    HapticService.navigation()
                }
            }
        }
    }
}

@available(macOS 26.0, *)
#Preview {
    Sidebar(selection: .constant(.home))
        .frame(width: 220)
}

// MARK: - SidebarMiniPlayerView

@available(macOS 26.0, *)
struct SidebarMiniPlayerView: View {
    @Environment(PlayerService.self) private var playerService
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                // Background Artwork
                if let track = self.playerService.currentTrack, let thumbnailURL = track.thumbnailURL?.highQualityThumbnailURL {
                    CachedAsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.black.opacity(0.1)
                    }
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .blur(radius: self.isHovering ? 5 : 0)
                    .opacity(self.isHovering ? 0.6 : 1.0)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.05))
                        .frame(width: 180, height: 180)
                        .overlay {
                            CassetteIcon(size: 60)
                                .foregroundStyle(.white.opacity(0.1))
                        }
                }

                // Hover Controls
                if self.isHovering {
                    VStack(spacing: 16) {
                        Text(self.playerService.currentTrack?.title ?? "Not Playing")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 12)

                        HStack(spacing: 24) {
                            Button {
                                HapticService.playback()
                                Task { await self.playerService.previous() }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                HapticService.playback()
                                Task { await self.playerService.playPause() }
                            } label: {
                                Image(systemName: self.playerService.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)

                            Button {
                                HapticService.playback()
                                Task { await self.playerService.next() }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .frame(width: 200, height: 200)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isHovering = hovering
                }
            }
        }
        .background(GlassEffectContainer { Color.clear })
    }
}
