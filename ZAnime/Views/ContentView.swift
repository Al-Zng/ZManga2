import SwiftUI

private let accentPurple = Color(red: 0.38, green: 0.18, blue: 0.96)
private let bgDark = Color(red: 0.07, green: 0.07, blue: 0.10)

@available(iOS 16.0, *)
struct ContentView: View {
    @StateObject var scraper = ScraperManager()
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedFilter: AnimeFilter = .ongoing
    @FocusState private var searchFocused: Bool
    @State private var scrollPosition: String? = nil

    enum AnimeFilter: String, CaseIterable {
        case ongoing = "يعرض الآن"
        case completed = "مكتمل"

        var statusParam: String {
            switch self {
            case .ongoing: return "ongoing"
            case .completed: return "completed"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bgDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Search bar
                    if isSearching {
                        searchBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Filter tabs
                    if !isSearching {
                        filterTabs
                    }

                    // Content
                    if let error = scraper.errorMessage {
                        errorView(message: error)
                    } else {
                        animeGrid
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearching)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("ZAnime")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentPurple, Color(red: 0.6, green: 0.3, blue: 1.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Spacer()

            HStack(spacing: 16) {
                Button {
                    withAnimation { isSearching.toggle() }
                    if !isSearching { scraper.fetchAnimeList(page: 1, status: selectedFilter.statusParam, reset: true) }
                } label: {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                Button {
                    scraper.fetchAnimeList(page: 1, status: selectedFilter.statusParam, reset: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .disabled(scraper.isLoadingList)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Search
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))

            TextField("ابحث عن أنمي...", text: $searchText)
                .focused($searchFocused)
                .foregroundColor(.white)
                .font(.system(size: 15))
                .onSubmit { if !searchText.isEmpty { scraper.searchAnime(query: searchText) } }

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.14))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .onAppear { searchFocused = true }
    }

    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(AnimeFilter.allCases, id: \.self) { filter in
                Button {
                    guard selectedFilter != filter else { return }
                    selectedFilter = filter
                    searchText = ""
                    scraper.fetchAnimeList(page: 1, status: filter.statusParam, reset: true)
                } label: {
                    VStack(spacing: 6) {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: selectedFilter == filter ? .bold : .medium))
                            .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.4))

                        Rectangle()
                            .fill(selectedFilter == filter ? accentPurple : .clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Grid (محسّن لحل مشكلة التمرير)
    private var animeGrid: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                if scraper.isLoadingList && scraper.animeList.isEmpty {
                    loadingGrid
                } else {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                        spacing: 14
                    ) {
                        ForEach(scraper.animeList) { anime in
                            NavigationLink(
                                destination: AnimeDetailView(animeURL: anime.url)
                                    .environmentObject(scraper)
                            ) {
                                AnimeCardView(anime: anime)
                            }
                            .buttonStyle(.plain)
                            .id(anime.id.uuidString) // إضافة ID فريد لكل عنصر
                            .onAppear {
                                // تحميل الصفحة التالية فقط عند ظهور العنصر الأخير
                                if !isSearching,
                                   anime.id == scraper.animeList.last?.id,
                                   !scraper.isLoadingList,
                                   scraper.hasMorePages {
                                    scraper.loadNextPage(status: selectedFilter.statusParam)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)

                    if scraper.isLoadingList {
                        ProgressView()
                            .tint(accentPurple)
                            .padding(.bottom, 20)
                    }
                }
            }
            .onChange(of: scraper.animeList.count) { _ in
                // الحفاظ على موضع التمرير عند إضافة عناصر جديدة
                if let lastID = scraper.animeList.last?.id.uuidString {
                    withAnimation {
                        scrollProxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Skeleton loader
    private var loadingGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
            spacing: 14
        ) {
            ForEach(0..<12, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.13))
                        .frame(width: 112, height: 158)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.13))
                        .frame(width: 90, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.11))
                        .frame(width: 70, height: 10)
                }
                .frame(width: 112)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 15))
            Button {
                scraper.fetchAnimeList(page: 1, status: selectedFilter.statusParam, reset: true)
            } label: {
                Text("إعادة المحاولة")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(accentPurple)
                    .cornerRadius(10)
            }
            Spacer()
        }
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.06), location: 0.4),
                            .init(color: .white.opacity(0.12), location: 0.5),
                            .init(color: .white.opacity(0.06), location: 0.6),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .init(x: phase - 1, y: 0.5),
                        endPoint: .init(x: phase, y: 0.5)
                    )
                }
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 2
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}