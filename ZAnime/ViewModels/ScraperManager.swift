import Foundation
import WebKit
import SwiftUI

class ScraperManager: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var animeList: [AnimeItem] = []
    @Published var currentDetail: AnimeDetail?
    @Published var streamURL: URL?
    @Published var isLoadingDetail = false
    @Published var isLoadingStream = false
    @Published var errorMessage: String? = nil
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
    
    // 1. جلب الأنميات المستمرة
    func fetchPopularAnime() {
        errorMessage = nil
        guard let url = URL(string: "https://animeslayerweb.com/anime/?status=ongoing") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.errorMessage = "فشل تحميل البيانات" }
                return
            }
            let items = self.extractAnimeItems(from: html)
            DispatchQueue.main.async {
                self.animeList = items
                if items.isEmpty { self.errorMessage = "لا توجد أنميات" }
            }
        }.resume()
    }
    
    // دالة عامة لاستخراج الأنميات من أي صفحة HTML
    private func extractAnimeItems(from html: String) -> [AnimeItem] {
        var items: [AnimeItem] = []
        let pattern = "<article class=\"bs dd1\"[^>]*?>(.*?)</article>"
        let articles = matches(for: pattern, in: html, options: [.dotMatchesLineSeparators])
        for block in articles {
            guard let content = block.first else { continue }
            let hrefPattern = "href=\"([^\"]+)\""
            let titlePattern = "title=\"([^\"]+)\""
            let imgPattern = "src=\"(https://[^\"]+\\.(?:jpg|jpeg|png|webp)[^\"]*)\""
            if let href = firstMatch(for: hrefPattern, in: content),
               let title = firstMatch(for: titlePattern, in: content),
               let img = firstMatch(for: imgPattern, in: content) {
                let cleanImage = img.replacingOccurrences(of: "?resize=247,350", with: "")
                items.append(AnimeItem(title: title, url: href, imageURL: cleanImage))
            }
        }
        return items
    }
    
    // 2. جلب تفاصيل الأنمي
    func fetchAnimeDetail(from url: String) {
        isLoadingDetail = true
        currentDetail = nil
        guard let requestURL = URL(string: url) else { return }
        URLSession.shared.dataTask(with: requestURL) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.isLoadingDetail = false }
                return
            }
            
            // العنوان
            let titlePattern = "<h1 class=\"entry-title\"[^>]*?>([^<]+)</h1>"
            let title = self.firstMatch(for: titlePattern, in: html) ?? "بدون عنوان"
            
            // الصورة
            let imgPattern = "<div class=\"thumb\"[^>]*?>.*?<img src=\"([^\"]+)\""
            let rawImage = self.firstMatch(for: imgPattern, in: html) ?? ""
            let cleanImage = rawImage.replacingOccurrences(of: "?resize=247,350", with: "")
            
            // الوصف
            let descPattern = "<div class=\"entry-content\"[^>]*?><p>([^<]+)</p>"
            let description = self.firstMatch(for: descPattern, in: html) ?? "لا يوجد وصف"
            
            // التقييم
            let ratingPattern = "<meta itemprop=\"ratingValue\" content=\"([^\"]+)\""
            let rating = self.firstMatch(for: ratingPattern, in: html) ?? "0.0"
            
            // الحالة
            let statusPattern = "<span><b>الحالة:</b>([^<]+)</span>"
            var status = self.firstMatch(for: statusPattern, in: html) ?? "?"
            status = status.trimmingCharacters(in: .whitespaces)
            
            // النوع
            let typePattern = "<span><b>النوع:</b>([^<]+)</span>"
            var type = self.firstMatch(for: typePattern, in: html) ?? "?"
            type = type.trimmingCharacters(in: .whitespaces)
            
            // الاستوديو
            let studioPattern = "<span><b>الاستوديو:</b><a[^>]*?>([^<]+)</a>"
            var studio = self.firstMatch(for: studioPattern, in: html) ?? "غير معروف"
            studio = studio.trimmingCharacters(in: .whitespaces)
            
            // الحلقات
            let epPattern = "class=\"CSB\" id=\"IDSB[^\"]*?\"[^>]*?><span>([^<]+)</span>"
            let epsMatches = self.matches(for: epPattern, in: html, options: [])
            var episodes: [Episode] = []
            for ep in epsMatches {
                let num = ep[1].trimmingCharacters(in: .whitespaces)
                if !num.isEmpty {
                    var episode = Episode(number: num)
                    let serverPattern = "source=\"ani\" quality-data=\"(FHD|HD|SD)\" data=\"([^\"]+)\" class=\"([^\"]+)\" type=\"([^\"]+)\""
                    let serverMatches = self.matches(for: serverPattern, in: html, options: [])
                    for serv in serverMatches {
                        if serv.count == 5 {
                            let server = Server(name: serv[4], quality: serv[1], dataCode: serv[2], type: serv[4])
                            episode.servers.append(server)
                        }
                    }
                    episodes.append(episode)
                }
            }
            
            let detail = AnimeDetail(
                imageURL: cleanImage,
                title: title,
                description: description,
                rating: rating,
                status: status,
                type: type,
                releaseYear: "",
                studio: studio,
                episodes: episodes
            )
            DispatchQueue.main.async {
                self.currentDetail = detail
                self.isLoadingDetail = false
            }
        }.resume()
    }
    
    // 3. البحث
    func searchAnime(query: String) {
        errorMessage = nil
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://animeslayerweb.com/?s=\(encoded)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.errorMessage = "فشل البحث" }
                return
            }
            let items = self.extractAnimeItems(from: html)
            DispatchQueue.main.async {
                self.animeList = items
                if items.isEmpty { self.errorMessage = "لا نتائج" }
            }
        }.resume()
    }
    
    // 4. تشغيل الحلقة
    func playEpisode(server: Server) {
        isLoadingStream = true
        currentServerType = server.type
        guard let url = URL(string: "https://animeslayerweb.com/anime/") else { return }
        webView?.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let js = "document.body.innerHTML.match(/(https?:\\/\\/[^'\"\\s]+\\.(m3u8|mp4))/g)"
        webView.evaluateJavaScript(js) { result, error in
            if let urls = result as? [String], let first = urls.first {
                DispatchQueue.main.async {
                    self.streamURL = URL(string: first)
                    self.isLoadingStream = false
                }
            } else {
                DispatchQueue.main.async { self.isLoadingStream = false }
            }
        }
    }
    
    // MARK: - Regex Helpers
    private func matches(for regex: String, in text: String, options: NSRegularExpression.Options) -> [[String]] {
        do {
            let regex = try NSRegularExpression(pattern: regex, options: options)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return results.map { match in
                (0..<match.numberOfRanges).compactMap {
                    if let range = Range(match.range(at: $0), in: text) { return String(text[range]) }
                    return nil
                }
            }
        } catch { return [] }
    }
    
    // دالة محسنة ترجع أول التقاط (group 1) مباشرةً
    private func firstMatch(for regex: String, in text: String) -> String? {
        let results = matches(for: regex, in: text, options: [.dotMatchesLineSeparators])
        return results.first?.dropFirst().first  // أول نتيجة بعد المجموعة الكاملة
    }
}