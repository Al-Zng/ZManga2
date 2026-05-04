import Foundation
import WebKit
import SwiftUI

class ScraperManager: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var animeList: [AnimeItem] = []
    @Published var currentDetail: AnimeDetail?
    @Published var streamURL: URL?
    @Published var isLoadingDetail = false
    @Published var isLoadingStream = false
    @Published var errorMessage: String? = nil // لإظهار أخطاء الشبكة
    
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
    
    // 1. جلب الأنميات الشائعة (محسّنة)
    func fetchPopularAnime() {
        errorMessage = nil
        guard let url = URL(string: "https://animeslayerweb.com/anime/?status=ongoing") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "فشل الاتصال: \(error.localizedDescription)" }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.errorMessage = "لم يتم استقبال بيانات" }
                return
            }
            
            // تجربة استخراج البيانات
            let extractedItems = self.extractAnimeItems(from: html)
            DispatchQueue.main.async {
                if extractedItems.isEmpty {
                    self.errorMessage = "لم يتم العثور على أي أنمي. تأكد من اتصال الإنترنت أو تغير هيكل الموقع."
                } else {
                    self.animeList = extractedItems
                    self.errorMessage = nil
                }
            }
        }.resume()
    }
    
    // دالة استخراج الأنميات من HTML (طريقتين)
    private func extractAnimeItems(from html: String) -> [AnimeItem] {
        var items: [AnimeItem] = []
        
        // 1. نبحث عن جميع أقسام المقالات
        let articlePattern = "<article class=\"bs dd1\"[^>]*?>(.*?)</article>"
        let articles = self.matches(for: articlePattern, in: html, options: [.dotMatchesLineSeparators])
        
        for articleHTML in articles {
            guard let articleContent = articleHTML.first else { continue }
            
            // استخراج href
            let hrefPattern = "href=\"([^\"]+)\""
            let href = firstMatch(for: hrefPattern, in: articleContent)
            
            // استخراج العنوان من oldtitle
            let oldtitlePattern = "oldtitle=\"([^\"]+)\""
            var title = firstMatch(for: oldtitlePattern, in: articleContent) ?? ""
            
            // إذا لم نجد oldtitle، نبحث عن h2
            if title.isEmpty {
                let h2Pattern = "<h2[^>]*?>([^<]+)</h2>"
                title = firstMatch(for: h2Pattern, in: articleContent) ?? ""
            }
            
            // استخراج الصورة
            let imgPattern = "src=\"(https://[^\"]+?\\.(?:jpg|png|jpeg|webp)[^\"]*)\""
            let imageURL = firstMatch(for: imgPattern, in: articleContent) ?? ""
            
            if let href = href, !title.isEmpty {
                items.append(AnimeItem(title: title, url: href, imageURL: imageURL))
            }
        }
        
        // إذا لم نعثر على شيء، نجرب النمط القديم كخطة بديلة
        if items.isEmpty {
            let oldPattern = "<div class=\"bsx\"><a href=\"([^\"]+)\"[^>]*?oldtitle=\"([^\"]+)\"[^>]*?>.*?<img src=\"([^\"]+)\"[^>]*?>"
            let res = matches(for: oldPattern, in: html, options: [.dotMatchesLineSeparators])
            for r in res {
                if r.count == 3 {
                    items.append(AnimeItem(title: r[1], url: r[0], imageURL: r[2]))
                }
            }
        }
        
        return items
    }
    
    // 2. جلب تفاصيل أنمي (لم تتغير)
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
            let epsNumbers = self.matches(for: epsPattern, in: html, options: [])
            
            let serverPattern = "source=\"ani\" quality-data=\"(FHD|HD|SD)\" data=\"([^\"]+)\" class=\"([^\"]+)\" type=\"([^\"]+)\""
            let serverMatches = self.matches(for: serverPattern, in: html, options: [])
            
            var episodes: [Episode] = []
            for epNum in epsNumbers.prefix(5) {
                var episode = Episode(number: epNum.first ?? "1")
                for serv in serverMatches {
                    if serv.count >= 4 {
                        episode.servers.append(Server(name: serv[2], quality: serv[0], dataCode: serv[1], type: serv[3]))
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
    
    // 3. تشغيل حلقة (لم تتغير)
    func playEpisode(server: Server) {
        isLoadingStream = true
        currentServerType = server.type
        guard let webView = webView else { return }
        let urlString = "https://animeslayerweb.com/anime/"
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
    
    // أدوات مساعدة لـ Regex (مُحسَّنة)
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
    
    private func firstMatch(for regex: String, in text: String) -> String? {
        let res = matches(for: regex, in: text, options: [.dotMatchesLineSeparators])
        return res.first?.first
    }
}