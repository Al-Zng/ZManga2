import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @StateObject var scraper = ScraperManager()
    @State private var searchText = ""
    @State private var selectedTab = 0
    
    var filteredAnime: [AnimeItem] {
        if searchText.isEmpty { return scraper.animeList }
        return scraper.animeList.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(filteredAnime) { anime in
                            NavigationLink(destination: AnimeDetailView(animeURL: anime.url).environmentObject(scraper)) {
                                AnimeCardView(anime: anime)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("ZAnime")
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث عن أنمي")
                .onSubmit(of: .search) {
                    scraper.searchAnime(query: searchText)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { scraper.fetchPopularAnime() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .tabItem { Label("المستمر", systemImage: "play.tv") }
            .tag(0)
            
            // في التبويب الثاني يمكن إضافة المكتمل لاحقًا
            Text("قريباً")
                .tabItem { Label("المكتمل", systemImage: "checkmark.tv") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
    }
}