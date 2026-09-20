import SwiftUI

/// Lecteur plein écran.
///
/// Présenté en `fullScreenCover` : couvre réellement tout l'écran, encoche et
/// indicateur d'accueil compris. Toutes les dimensions sont dérivées de la
/// hauteur disponible, pour tenir de l'iPhone SE au Pro Max sans débordement.
struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var halo = false
    @State private var dragOffset: CGFloat = 0

    private var track: Track? { player.current }

    var body: some View {
        ZStack {
            // Fond opaque sous le décor : garantit qu'aucun pixel de la vue
            // précédente ne subsiste, quelle que soit la transition.
            Theme.night.ignoresSafeArea()
            LiquidBackdrop(intensity: 1.25)

            if let track {
                GeometryReader { geo in
                    content(track, in: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .offset(y: dragOffset)
            } else {
                VStack {
                    closeBar
                    Spacer()
                    EmptyStateView(icon: "music.note", title: "Rien en lecture",
                                   message: "Choisis un récitateur puis une sourate.")
                    Spacer()
                }
            }
        }
        .statusBarHidden(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                halo = true
            }
        }
    }

    // MARK: - Mise en page

    /// Répartit l'espace selon la hauteur utile. `tight` déclenche la variante
    /// compacte (petits écrans) : ornement réduit, marges resserrées.
    @ViewBuilder
    private func content(_ track: Track, in size: CGSize) -> some View {
        let h = size.height
        let tight = h < 700
        let art = min(size.width * 0.70, max(h * 0.30, 132))
        let gap: CGFloat = tight ? 8 : 16

        VStack(spacing: 0) {
            closeBar
                .gesture(dismissDrag)

            Spacer(minLength: tight ? 2 : 6)

            ornament(for: track, side: art)
                .gesture(dismissDrag)

            Spacer(minLength: gap)

            titles(for: track, tight: tight)
                .padding(.horizontal, 26)

            Spacer(minLength: gap)

            scrubber(tight: tight)
                .padding(.horizontal, tight ? 20 : 26)

            Spacer(minLength: tight ? 10 : 18)

            transport(tight: tight)

            Spacer(minLength: tight ? 10 : 18)

            secondaryBar(for: track)
                .padding(.horizontal, 14)

            if let message = player.errorMessage {
                errorBanner(message)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
            }

            Spacer(minLength: tight ? 4 : 10)
        }
    }

    /// Barre supérieure : fermeture explicite à gauche, poignée au centre.
    private var closeBar: some View {
        ZStack {
            Capsule()
                .fill(Theme.ivory.opacity(0.26))
                .frame(width: 38, height: 4.5)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ivory.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .glass(radius: 12, elevation: 0.5)
                }
                .buttonStyle(PressScale())

                Spacer()

                Text("En lecture")
                    .font(Theme.ui(11, .semibold))
                    .foregroundStyle(Theme.faint)
                    .opacity(0)   // réserve la symétrie sans surcharger le titre
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    /// Glisser vers le bas pour fermer. Rattaché au haut de l'écran seulement,
    /// afin de ne pas voler ses gestes à la tête de lecture.
    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 { dragOffset = value.translation.height }
            }
            .onEnded { value in
                if value.translation.height > 110 {
                    dismiss()
                    dragOffset = 0
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Éléments

    /// Rosette centrale : elle respire au rythme de la lecture et se fige à la pause.
    private func ornament(for track: Track, side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Theme.emerald.opacity(0.34), .clear],
                                   center: .center, startRadius: side * 0.04, endRadius: side * 0.66)
                )
                .frame(width: side * 1.32, height: side * 1.32)
                .scaleEffect(halo && player.isPlaying ? 1.07 : 0.94)
                .blur(radius: side * 0.055)

            IslamicPattern(tile: side * 0.25, lineWidth: 0.9,
                           color: Theme.gold, opacity: 0.20)
                .frame(width: side, height: side)
                .clipShape(Circle())
                .rotationEffect(.degrees(halo && player.isPlaying ? 12 : -12))

            Circle()
                .stroke(Theme.goldSheen.opacity(0.55), lineWidth: 1)
                .frame(width: side, height: side)

            Octagon()
                .stroke(Theme.gold.opacity(0.45), lineWidth: 1)
                .frame(width: side * 0.78, height: side * 0.78)
                .rotationEffect(.degrees(halo && player.isPlaying ? -8 : 8))

            VStack(spacing: side * 0.035) {
                Text(track.surah.nameAr)
                    .font(Theme.arabic(side * 0.17, .semibold))
                    .foregroundStyle(Theme.ivory)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, side * 0.1)

                Text("\(track.surah.verses) versets · \(track.surah.revelation)")
                    .font(Theme.ui(max(9, side * 0.042), .medium))
                    .foregroundStyle(Theme.gold.opacity(0.8))
                    .lineLimit(1)
            }

            if player.isBuffering {
                ProgressView()
                    .tint(Theme.emerald)
                    .scaleEffect(1.1)
                    .offset(y: side * 0.34)
            }
        }
        .frame(width: side * 1.32, height: side * 1.32)
    }

    private func titles(for track: Track, tight: Bool) -> some View {
        VStack(spacing: tight ? 3 : 6) {
            Text("\(track.surah.number). \(track.surah.nameFr)")
                .font(Theme.display(tight ? 19 : 23, .bold))
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text(track.reciterName)
                .font(Theme.ui(tight ? 12.5 : 14, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)

            HStack(spacing: 6) {
                Chip(text: track.recitation.shortLabel, icon: "book.closed")
                Chip(text: player.isPlayingLocal ? "Hors ligne" : "En ligne",
                     icon: player.isPlayingLocal ? "arrow.down.circle.fill" : "wifi",
                     tint: player.isPlayingLocal ? Theme.emerald : Theme.teal)
            }
            .padding(.top, 2)
        }
    }

    private func scrubber(tight: Bool) -> some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { min(player.position, max(player.duration, 0.01)) },
                    set: { player.position = $0 }
                ),
                in: 0...max(player.duration, 0.01),
                onEditingChanged: { editing in
                    player.isScrubbing = editing
                    if !editing { player.seek(to: player.position) }
                }
            )
            .tint(Theme.emerald)
            .disabled(player.duration <= 0)

            HStack {
                Text(Fmt.time(player.position))
                Spacer()
                Text(player.duration > 0 ? "-" + Fmt.time(player.duration - player.position) : "--:--")
            }
            .font(Theme.mono(tight ? 10 : 11, .medium))
            .foregroundStyle(Theme.faint)
        }
    }

    private func transport(tight: Bool) -> some View {
        let small: CGFloat = tight ? 40 : 46
        let big: CGFloat = tight ? 64 : 74
        return HStack(spacing: tight ? 11 : 16) {
            CircleGlassButton(icon: "backward.fill", side: small) { player.previous() }
            CircleGlassButton(icon: "gobackward.15", side: small, iconScale: 0.36) { player.skip(by: -15) }

            CircleGlassButton(
                icon: player.isPlaying ? "pause.fill" : "play.fill",
                side: big, iconScale: 0.36, prominent: true
            ) {
                player.togglePlayPause()
            }

            CircleGlassButton(icon: "goforward.15", side: small, iconScale: 0.36) { player.skip(by: 15) }
            CircleGlassButton(icon: "forward.fill", side: small) { player.next() }
        }
    }

    private func secondaryBar(for track: Track) -> some View {
        HStack(spacing: 0) {
            ExternalDisplayButton()

            Button {
                player.cycleRepeat()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: player.repeatMode.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(player.repeatMode == .off ? "Répéter" :
                            (player.repeatMode == .one ? "Sourate" : "Série"))
                        .font(Theme.ui(9.5, .medium))
                }
                .foregroundStyle(player.repeatMode == .off ? Theme.faint : Theme.gold)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            let state = downloads.state(for: track)
            Button {
                switch state {
                case .idle, .failed: downloads.enqueue(track)
                case .waiting, .downloading: downloads.cancel(track)
                case .done: downloads.remove(recitationId: track.recitation.id,
                                             surah: track.surah.number)
                }
            } label: {
                VStack(spacing: 3) {
                    DownloadButton(state: state, side: 22) {}
                        .allowsHitTesting(false)
                    Text(state == .done ? "Téléchargé" :
                            (state.isActive ? "\(Int(state.fraction * 100)) %" : "Télécharger"))
                        .font(Theme.ui(9.5, .medium))
                        .foregroundStyle(state == .done ? Theme.emerald : Theme.faint)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                player.stop()
                dismiss()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Arrêter").font(Theme.ui(9.5, .medium))
                }
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .glass(radius: 20, elevation: 0.7)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.danger)
            Text(message)
                .font(Theme.ui(11.5, .medium))
                .foregroundStyle(Theme.ivory.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.danger.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Theme.danger.opacity(0.32), lineWidth: 0.8)
        )
    }
}
