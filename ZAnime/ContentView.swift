import SwiftUI
import AVKit
import WebKit

struct AnimeItem: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let imageURL: String
}

class ScraperManager: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var animeList: [AnimeItem] = []
    @Published var currentStreamURL: URL?
    private var webView: WKWebView!

    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        fetchAnimeList()
    }

    func fetchAnimeList() {
        guard let url = URL(string: "https://animeslayerweb.com/anime/") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else { return }
            let pattern = "<div class=\"bsx\"><a href=\"([^\"]+)\".*?title=\"([^\"]+)\".*?<img src=\"([^\"]+)\""
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
                let results = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                
                var parsed: [AnimeItem] = []
                for result in results {
                    if let urlRange = Range(result.range(at: 1), in: html),
                       let titleRange = Range(result.range(at: 2), in: html),
                       let imgRange = Range(result.range(at: 3), in: html) {
                        parsed.append(AnimeItem(title: String(html[titleRange]), url: String(html[urlRange]), imageURL: String(html[imgRange])))
                    }
                }
                DispatchQueue.main.async { self.animeList = parsed }
            } catch { print("Regex error") }
        }.resume()
    }

    func extractVideoM3U8(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            webView.evaluateJavaScript("document.body.innerHTML") { result, error in
                if let html = result as? String {
                    if let m3u8Range = html.range(of: "(?<=['\"])(https?://[^'\"]+\\.m3u8)(?=['\"])", options: .regularExpression) {
                        self.currentStreamURL = URL(string: String(html[m3u8Range]))
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject var scraper = ScraperManager()
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(scraper.animeList) {
                            anime in AnimeCard(anime: anime).onTapGesture {
                                scraper.extractVideoM3U8(from: anime.url)
                            }
                        }
                    }.padding()
                }
            }
            .navigationTitle("ZAnime")
            .preferredColorScheme(.dark)
            .sheet(item: Binding<URL?>(get: { scraper.currentStreamURL }, set: { scraper.currentStreamURL = $0 })) { url in
                VideoPlayer(player: AVPlayer(url: url)).edgesIgnoringSafeArea(.all)
            }
        }
    }
}

struct AnimeCard: View {
    let anime: AnimeItem
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: anime.imageURL)) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                else { Rectangle().fill(Color.gray) }
            }.frame(height: 180).cornerRadius(8)
            Text(anime.title).font(.caption).bold().foregroundColor(.white).lineLimit(2)
        }
    }
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}