import SwiftUI

struct AnimeDetailView: View {
    let animeURL: String
    @EnvironmentObject var scraper: ScraperManager
    @State private var selectedServer: Server?
    
    var body: some View {
        ScrollView {
            if let detail = scraper.currentDetail {
                VStack(alignment: .leading, spacing: 15) {
                    AsyncImage(url: URL(string: detail.imageURL)) { phase in
                        if let image = phase.image { image.resizable().aspectRatio(contentMode: .fit) }
                        else { Rectangle().fill(Color.gray) }
                    }.frame(height: 300).cornerRadius(12)
                    
                    Text(detail.title).font(.largeTitle).bold().foregroundColor(.white)
                    Text("🍿 \(detail.type) • ⭐️ \(detail.rating) • \(detail.status)").foregroundColor(.gray)
                    Text(detail.description).foregroundColor(.white)
                    
                    if detail.episodes.isEmpty {
                        ProgressView()
                    } else {
                        ForEach(detail.episodes) { episode in
                            VStack(alignment: .leading) {
                                Text("الحلقة \(episode.number)").font(.headline).foregroundColor(.white).padding(.top)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(episode.servers) { server in
                                            Button(server.name) { selectedServer = server; scraper.playEpisode(server: server) }.padding(8).background(Color.blue).cornerRadius(8).foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }.padding()
            } else { ProgressView().onAppear { scraper.fetchAnimeDetail(from: animeURL) } }
        }
        .background(Color.black.ignoresSafeArea())
        .fullScreenCover(item: $selectedServer) { server in PlayerView(streamURL: scraper.streamURL, isLoading: scraper.isLoadingStream).ignoresSafeArea() }
    }
}