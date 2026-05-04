import Foundation
import WebKit
import SwiftUI

class ScraperManager: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var animeList: [AnimeItem] = []
    @Published var currentDetail: AnimeDetail?
    @Published var streamURL: URL?
    @Published var isLoadingDetail = false
    @Published var isLoadingStream = false
    var currentServerType = ""
    
    private var webView: WKWebView?
    
    override init() {
        super.init()
        configWebView()
        fetchPopularAnime()
    }
    
    private func configWebView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
    }
    
    // 1. جلب الانميات الشائعة
    func fetchPopularAnime() {
        guard let url = URL(string: "https://animeslayerweb.com/anime/?status=ongoing") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else { return }
            let pattern = "<div class=\"bsx\"><a href=\"([^\"]+)\"[^>]*?oldtitle=\"([^\"]+)\"[^>]*?>.*?<img src=\"([^\"]+)\"[^>]*?>"
            let results = self.matches(for: pattern, in: html)  // <-- إصلاح: إزالة if let
            var items: [AnimeItem] = []
            for res in results {
                if res.count == 3 {
                    items.append(AnimeItem(title: res[1], url: res[0], imageURL: res[2]))
                }
            }
            DispatchQueue.main.async { self.animeList = items }
        }.resume()
    }
    
    // 2. جلب تفاصيل انمي
    func fetchAnimeDetail(from url: String) {
        isLoadingDetail = true
        guard let requestURL = URL(string: url) else { return }
        URLSession.shared.dataTask(with: requestURL) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.isLoadingDetail = false }
                return
            }
            
            let titlePattern = "<h1 class=\"entry-title\"[^>]*?>([^<]+)</h1>"
            let title = self.firstMatch(for: titlePattern, in: html) ?? "بدون عنوان"
            
            let imgPattern = "<div class=\"thumb\"[^>]*?>.*?<img src=\"([^\"]+)\"[^>]*?>"
            let imageURL = self.firstMatch(for: imgPattern, in: html) ?? ""
            
            let descPattern = "<div class=\"entry-content\"[^>]*?><p>([^<]+)</p>"
            let description = self.firstMatch(for: descPattern, in: html) ?? "لا يوجد وصف"
            
            let epsPattern = "class=\"CSB\" id=\"IDSB[^\"]*?\"><span>الحلقة ([^<]+)</span>"
            let epsNumbers = self.matches(for: epsPattern, in: html)
            
            let serverPattern = "source=\"ani\" quality-data=\"(FHD|HD|SD)\" data=\"([^\"]+)\" class=\"([^\"]+)\" type=\"([^\"]+)\""
            let serverMatches = self.matches(for: serverPattern, in: html)
            
            var episodes: [Episode] = []
            for epNum in epsNumbers.prefix(5) {
                var episode = Episode(number: epNum.first ?? "1")
                for serv in serverMatches {
                    if serv.count == 3 {
                        episode.servers.append(Server(name: serv[2], quality: serv[0], dataCode: serv[1], type: serv[2]))
                    }
                }
                episodes.append(episode)
            }
            
            DispatchQueue.main.async {
                self.currentDetail = AnimeDetail(
                    imageURL: imageURL,
                    title: title,
                    description: description,
                    rating: "8.9",
                    status: "مستمر",
                    type: "مسلسل",
                    releaseYear: "2024",
                    episodes: episodes
                )
                self.isLoadingDetail = false
            }
        }.resume()
    }
    
    // 3. تشغيل حلقة
    func playEpisode(server: Server) {
        isLoadingStream = true
        currentServerType = server.type
        guard let webView = webView else { return }
        // استخدام WebViewExtractor للاستخراج الفعلي
        let urlString = "https://animeslayerweb.com/anime/" // يمكن تعديل الرابط ليتوافق مع السيرفر
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let js = "document.body.innerHTML.match(/(https?:\\/\\/[^'\"\\s]+\\.(m3u8|mp4))/g)"
        webView.evaluateJavaScript(js) { result, error in
            if let urls = result as? [String], let firstURL = urls.first {
                DispatchQueue.main.async {
                    self.streamURL = URL(string: firstURL)
                    self.isLoadingStream = false
                }
            } else {
                DispatchQueue.main.async { self.isLoadingStream = false }
            }
        }
    }
    
    // Regex helpers – تُرجع مصفوفة عادية وليس Optional
    private func matches(for regex: String, in text: String) -> [[String]] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return results.map { match in
                (0..<match.numberOfRanges).compactMap {
                    if let range = Range(match.range(at: $0), in: text) { return String(text[range]) }
                    return nil
                }
            }
        } catch { return [] }
    }
    
    private func firstMatch(for regex: String, in text: String) -> String? {
        return matches(for: regex, in: text).first?.first
    }
}