import SwiftUI

struct RecitersView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager

    @State private var query = ""
    @State private var filter: ReciterFilter = .all
    @State private var selectedRiwaya: String?
    @State private var visibleCount = 30

    private let pageSize = 30

    private var results: [Reciter] {
        let base = catalog.allReciters
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        let filtered = base.filter { r in
            let matchesMainFilter: Bool
            switch filter {
            case .all:        matchesMainFilter = true
            case .favorites:  matchesMainFilter = catalog.isFavorite(r.id)
            case .complete:   matchesMainFilter = !r.completeVersions.isEmpty
            case .downloaded: matchesMainFilter = r.versions.contains {
                downloads.downloadedCount(recitationId: $0.id) > 0
            }
            }

            guard matchesMainFilter else { return false }
            guard let selectedRiwaya else { return true }
            return r.versions.contains { $0.riwayaName == selectedRiwaya }
        }

        guard !trimmed.isEmpty else { return filtered }
        let needle = Self.fold(trimmed)
        return filtered.filter {
            Self.fold($0.name).contains(needle) || $0.nameAr.contains(trimmed)
        }
    }

    private struct RiwayaFilter: Identifiable, Hashable {
        let id: String
        let reciterCount: Int
    }

    /// Familles réellement présentes dans le catalogue, sans liste codée en dur.
    /// Ainsi une nouvelle riwaya ajoutée aux données apparaît automatiquement.
    private var riwayaFilters: [RiwayaFilter] {
        var recitersByRiwaya: [String: Set<String>] = [:]

        for reciter in catalog.allReciters {
            for version in reciter.versions {
                recitersByRiwaya[version.riwayaName, default: []].insert(reciter.id)
            }
        }

        return recitersByRiwaya
            .map { RiwayaFilter(id: $0.key, reciterCount: $0.value.count) }
            .sorted { Self.fold($0.id) < Self.fold($1.id) }
    }

    private var selectedRiwayaTitle: String {
        selectedRiwaya ?? "Toutes les riwayat"
    }

    private var displayedResults: [Reciter] {
        Array(results.prefix(visibleCount))
    }

    /// Regroupement alphabétique, actif seulement en navigation libre :
    /// sur une recherche, la pertinence prime sur l'ordre.
    /// Type nommé plutôt qu'un tuple — Swift n'autorise pas de key path
    /// vers un élément de tuple, donc `ForEach(…, id: \.0)` ne compilerait pas.
    private struct LetterGroup: Identifiable {
        let id: String
        let reciters: [Reciter]
    }

    private var grouped: [LetterGroup] {
        Dictionary(grouping: displayedResults) { r -> String in
            r.custom ? "Mes sources" : String(r.name.prefix(1)).uppercased()
        }
        .sorted { a, b in
            if a.key == "Mes sources" { return true }
            if b.key == "Mes sources" { return false }
            return a.key < b.key
        }
        .map { LetterGroup(id: $0.key, reciters: $0.value) }
    }

    private var showGroups: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty && results.count > 12
    }

    private func loadNextPage() {
        guard visibleCount < results.count else { return }
        visibleCount = min(visibleCount + pageSize, results.count)
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if displayedResults.count < results.count {
            ProgressView()
                .tint(Theme.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .onAppear { loadNextPage() }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                    header

                    if results.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "Aucun résultat",
                            message: filter == .downloaded
                                ? "Tu n'as encore rien téléchargé. Ouvre un récitateur et appuie sur la flèche."
                                : "Essaie un autre nom, ou change de filtre."
                        )
                    } else if showGroups {
                        ForEach(grouped) { group in
                            Section {
                                ForEach(group.reciters) { ReciterRow(reciter: $0) }
                            } header: {
                                letterHeader(group.id, count: group.reciters.count)
                            }
                        }
                    } else {
                        ForEach(displayedResults) { ReciterRow(reciter: $0) }
                    }

                    paginationFooter
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationBarHidden(true)
        }
        .onChange(of: query) { _, _ in visibleCount = pageSize }
        .onChange(of: filter) { _, _ in visibleCount = pageSize }
        .onChange(of: selectedRiwaya) { _, _ in visibleCount = pageSize }
    }

    // MARK: Sous-vues

    private var header: some View {
        VStack(spacing: 13) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tilawa")
                        .font(Theme.display(28, .bold))
                        .foregroundStyle(Theme.goldSheen)
                    Text("\(catalog.allReciters.count) récitateurs · \(catalog.totalVersions) versions")
                        .font(Theme.ui(11.5, .regular))
                        .foregroundStyle(Theme.faint)
                }
                Spacer()
                Text("تلاوة")
                    .font(Theme.arabic(30, .semibold))
                    .foregroundStyle(Theme.ivory.opacity(0.9))
            }
            .padding(.top, 8)

            OrnamentDivider()

            SearchField(text: $query)

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(ReciterFilter.allCases) { f in
                        FilterChip(title: f.title, icon: f.icon, selected: filter == f) {
                            withAnimation(.easeInOut(duration: 0.2)) { filter = f }
                        }
                    }
                    riwayaMenu
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.bottom, 4)
    }

    /// Menu unique plutôt qu'une rangée de boutons : les nombreuses riwayat
    /// restent accessibles sans agrandir l'en-tête.
    private var riwayaMenu: some View {
        Menu {
            Button {
                selectedRiwaya = nil
            } label: {
                Label("Toutes les riwayat",
                      systemImage: selectedRiwaya == nil ? "checkmark.circle.fill" : "circle")
            }

            if !riwayaFilters.isEmpty {
                Divider()
            }

            ForEach(riwayaFilters) { option in
                Button {
                    selectedRiwaya = option.id
                } label: {
                    Label("\(option.id) · \(option.reciterCount)",
                          systemImage: selectedRiwaya == option.id
                              ? "checkmark.circle.fill"
                              : "circle")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(selectedRiwayaTitle)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .font(Theme.ui(11.5, .medium))
            .foregroundStyle(selectedRiwaya == nil ? Theme.ivory : Theme.night)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background {
                if selectedRiwaya == nil {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.goldSheen)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func letterHeader(_ letter: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(Theme.display(12.5, .bold))
                .foregroundStyle(Theme.gold)
            Rectangle()
                .fill(LinearGradient(colors: [Theme.gold.opacity(0.28), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.8)
            Text("\(count)")
                .font(Theme.mono(10, .medium))
                .foregroundStyle(Theme.faint)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Comparaison insensible à la casse et aux diacritiques (« Sudais » trouve « Sudaïs »).
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}

enum ReciterFilter: Int, CaseIterable, Identifiable {
    case all, favorites, complete, downloaded

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all:        return "Tous"
        case .favorites:  return "Favoris"
        case .complete:   return "Mushaf complet"
        case .downloaded: return "Hors ligne"
        }
    }
    var icon: String {
        switch self {
        case .all:        return "square.grid.2x2"
        case .favorites:  return "star.fill"
        case .complete:   return "checkmark.seal"
        case .downloaded: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Ligne de récitateur

struct ReciterRow: View {
    let reciter: Reciter
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager

    private var offlineCount: Int {
        reciter.versions.reduce(0) { $0 + downloads.downloadedCount(recitationId: $1.id) }
    }

    var body: some View {
        NavigationLink {
            ReciterDetailView(reciter: reciter)
        } label: {
            HStack(spacing: 12) {
                Monogram(reciter: reciter, side: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(reciter.name)
                        .font(Theme.ui(15, .semibold))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)

                    if reciter.hasArabicName {
                        Text(reciter.nameAr)
                            .font(Theme.arabic(13.5))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }

                    HStack(spacing: 5) {
                        if reciter.custom {
                            Chip(text: "Ma source", icon: "link", tint: Theme.gold)
                        }
                        if reciter.versions.count > 1 {
                            Chip(text: "\(reciter.versions.count) versions", icon: "square.stack.3d.up")
                        }
                        if !reciter.completeVersions.isEmpty {
                            Chip(text: "114", icon: "checkmark.seal.fill", tint: Theme.emerald)
                        }
                        if offlineCount > 0 {
                            Chip(text: "\(offlineCount) hors ligne",
                                 icon: "arrow.down.circle.fill", tint: Theme.teal)
                        }
                    }
                }

                Spacer(minLength: 2)

                Button {
                    catalog.toggleFavorite(reciter.id)
                } label: {
                    Image(systemName: catalog.isFavorite(reciter.id) ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(catalog.isFavorite(reciter.id) ? Theme.gold : Theme.faint)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.faint.opacity(0.7))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .glass(radius: Theme.radiusCard, elevation: 0.7)
        }
        .buttonStyle(PressScale(scale: 0.985))
    }
}
