import SwiftUI
import AVKit

/// Interface dédiée au téléviseur ou au projecteur.
///
/// Aucun contrôle minuscule n'est nécessaire ici : le téléphone reste la
/// télécommande et l'écran externe se concentre sur la lecture et la lisibilité.
struct ExternalDisplayView: View {
    @EnvironmentObject private var player: PlayerService
    @State private var halo = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.night.ignoresSafeArea()
                LiquidBackdrop(intensity: 0.62)

                if let track = player.current {
                    playing(track, in: geo.size)
                } else {
                    idle(in: geo.size)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                halo = true
            }
        }
    }

    private func playing(_ track: Track, in size: CGSize) -> some View {
        let artSide = min(size.height * 0.52, size.width * 0.30)
        let progress = player.duration > 0
            ? max(0, min(player.position / player.duration, 1))
            : 0

        return HStack(spacing: size.width * 0.075) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.emerald.opacity(0.42), .clear],
                                center: .center,
                                startRadius: artSide * 0.08,
                                endRadius: artSide * 0.82
                            )
                        )
                        .frame(width: artSide * 1.42, height: artSide * 1.42)
                        .scaleEffect(halo && player.isPlaying ? 1.05 : 0.94)
                        .blur(radius: artSide * 0.08)

                    IslamicPattern(tile: artSide * 0.23,
                                   lineWidth: 1.1,
                                   color: Theme.gold,
                                   opacity: 0.22)
                        .frame(width: artSide, height: artSide)
                        .clipShape(Circle())

                    Circle()
                        .stroke(Theme.goldSheen.opacity(0.72), lineWidth: 1.6)
                        .frame(width: artSide, height: artSide)

                    SurahMedallion(number: track.surah.number,
                                   active: player.isPlaying,
                                   side: artSide * 0.62)
                }

                Text("تلاوة")
                    .font(Theme.arabic(max(24, artSide * 0.15), .semibold))
                    .foregroundStyle(Theme.goldSheen)
            }
            .frame(width: size.width * 0.30)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(player.isPlaying ? Theme.emerald : Theme.gold)
                        .frame(width: 9, height: 9)
                    Text(player.isPlaying ? "EN LECTURE" : "EN PAUSE")
                        .font(Theme.ui(max(13, size.height * 0.026), .bold))
                        .tracking(2.2)
                        .foregroundStyle(Theme.gold)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.gold.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.2)
                    .padding(.top, 16)

                Text(track.surah.nameAr)
                    .font(Theme.arabic(max(34, size.height * 0.082), .semibold))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .padding(.top, 22)

                Text("\(track.surah.number). \(track.surah.nameFr)")
                    .font(Theme.display(max(28, size.height * 0.055), .bold))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.top, 8)

                Text(track.reciterName)
                    .font(Theme.ui(max(18, size.height * 0.032), .medium))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .padding(.top, 9)

                VStack(spacing: 8) {
                    GeometryReader { bar in
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Theme.accent)
                                    .frame(width: bar.size.width * progress)
                            }
                    }
                    .frame(height: 7)

                    HStack {
                        Text(Fmt.time(player.position))
                        Spacer()
                        Text(player.duration > 0 ? Fmt.time(player.duration) : "--:--")
                    }
                    .font(Theme.mono(max(13, size.height * 0.023), .medium))
                    .foregroundStyle(Theme.faint)
                }
                .padding(.top, 30)

                HStack(spacing: 9) {
                    Image(systemName: player.isPlayingLocal
                          ? "arrow.down.circle.fill"
                          : "wifi")
                    Text(player.isPlayingLocal ? "Lecture hors ligne" : "Lecture en ligne")
                    Text("·")
                    Text("Contrôles sur l’iPhone")
                }
                .font(Theme.ui(max(13, size.height * 0.024), .medium))
                .foregroundStyle(player.isPlayingLocal ? Theme.emerald : Theme.teal)
                .padding(.top, 25)
            }
            .frame(maxWidth: size.width * 0.48, alignment: .leading)
        }
        .padding(.horizontal, size.width * 0.09)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func idle(in size: CGSize) -> some View {
        VStack(spacing: 18) {
            IslamicPattern(tile: 100,
                           lineWidth: 1,
                           color: Theme.gold,
                           opacity: 0.20)
                .frame(width: min(size.width * 0.24, 230),
                       height: min(size.width * 0.24, 230))
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Theme.gold.opacity(0.5), lineWidth: 1.4)
                }

            Text("تلاوة")
                .font(Theme.arabic(42, .semibold))
                .foregroundStyle(Theme.goldSheen)
            Text("Choisis une sourate sur ton iPhone")
                .font(Theme.display(26, .semibold))
                .foregroundStyle(Theme.ivory)
            Text("L’écran externe est prêt.")
                .font(Theme.ui(16, .regular))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Bouton Apple TV / AirPlay placé dans le lecteur du téléphone.
struct ExternalDisplayButton: View {
    @ObservedObject private var display = ExternalDisplayManager.shared

    var body: some View {
        VStack(spacing: 3) {
            AirPlayRoutePicker()
                .frame(width: 40, height: 26)

            Text(display.isConnected ? "TV active" : "Diffuser")
                .font(Theme.ui(9.5, .medium))
                .foregroundStyle(display.isConnected ? Theme.emerald : Theme.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.isConnected
                            ? "Écran externe connecté"
                            : "Choisir un écran AirPlay")
    }
}

private struct AirPlayRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor(Theme.muted)
        view.activeTintColor = UIColor(Theme.gold)
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {
        view.tintColor = UIColor(Theme.muted)
        view.activeTintColor = UIColor(Theme.gold)
    }
}