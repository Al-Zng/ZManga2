import SwiftUI

struct ContentView: View {
    @StateObject var scraper = ScraperManager()
    @State private var searchText = ""
    
    var filteredAnime: [AnimeItem] {
        if searchText.isEmpty { return scraper.animeList }
        return scraper.animeList.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // العرض العلوي المميز
                    if let featured = scraper.animeList.first {
                        FeaturedAnimeCard(anime: featured)
                            .onTapGesture { scraper.fetchAnimeDetail(from: featured.url) }
                    }
                    
                    // شبكة الانميات
                    Text("جميع الانميات")
                        .font(.title2).bold().foregroundColor(.white).padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(filteredAnime) { anime in
                            NavigationLink(destination: AnimeDetailView(animeURL: anime.url).environmentObject(scraper)) {
                                AnimeCardView(anime: anime)
                            }
                        }
                    }.padding(.horizontal)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("ZAnime")
            .preferredColorScheme(.dark)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "ابحث عن انمي")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { scraper.fetchPopularAnime() }) { Image(systemName: "arrow.clockwise") } } }
        }
    }
}

// بطاقة عرض علوية
struct FeaturedAnimeCard: View {
    let anime: AnimeItem
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: anime.imageURL)) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill).frame(height: 250).clipped() }
                else { Rectangle().fill(Color.gray).frame(height: 250) }
            }
            LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading) {
                Text(anime.title).font(.title).bold().foregroundColor(.white)
                HStack { Image(systemName: "star.fill").foregroundColor(.yellow); Text("8.9").foregroundColor(.white) }
            }.padding()
        }.cornerRadius(12).padding(.horizontal)
    }
}