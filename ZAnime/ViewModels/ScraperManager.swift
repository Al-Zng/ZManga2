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
    
    // 1. جلب الأنميات الشائعة (المستمرة) من الصفحة الرئيسية
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
            let extracted = self.extractAnimeItems(from: html)
            DispatchQueue.main.async {
                if extracted.isEmpty {
                    self.errorMessage = "لم يتم العثور على أي أنمي."
                } else {
                    self.animeList = extracted
                    self.errorMessage = nil
                }
            }
        }.resume()
    }
    
    // دالة استخراج عامة تُستخدم لكل الصفحات
    private func extractAnimeItems(from html: String) -> [AnimeItem] {
        var items: [AnimeItem] = []
        
        // 1. استخراج جميع <article class="bs dd1"> ... </article>
        let articlePattern = "<article class=\"bs dd1\"[^>]*?>(.*?)</article>"
        let articles = matches(for: articlePattern, in: html, options: [.dotMatchesLineSeparators])
        
        for articleHTML in articles {
            guard let block = articleHTML.first else { continue }
            
            // 2. استخراج href و title من <a>
            let linkPattern = "<a href=\"([^\"]+)\"[^>]*?title=\"([^\"]*?)\""
            let linkMatch = firstMatch(for: linkPattern, in: block)
            guard let href = linkMatch?[1], let title = linkMatch?[2], !title.isEmpty else { continue }
            
            // 3. استخراج src الصورة (داخل <img>)
            let imgPattern = "src=\"(https://[^\"]+?\\.(?:jpg|png|jpeg|webp)[^\"]*)\""
            let imgURL = firstMatch(for: imgPattern, in: block)?[1] ?? ""
            
            let item = AnimeItem(title: title, url: href, imageURL: imgURL)
            items.append(item)
        }
        
        // إذا لم ينجح النمط أعلاه، نجرب نمطًا بديلًا بسيطًا (للحالات النادرة)
        if items.isEmpty {
            let simplePattern = "<div class=\"bsx\"><a href=\"([^\"]+)\"[^>]*?title=\"([^\"]+)\"[^>]*?>.*?<img src=\"([^\"]+)\""
            let simpleMatches = matches(for: simplePattern, in: html, options: [.dotMatchesLineSeparators])
            for match in simpleMatches {
                if match.count == 4 {
                    items.append(AnimeItem(title: match[2], url: match[1], imageURL: match[3]))
                }
            }
        }
        return items
    }
    
    // 2. جلب تفاصيل أنمي (محسنة)
    func fetchAnimeDetail(from url: String) {
        isLoadingDetail = true
        guard let requestURL = URL(string: url) else { return }
        URLSession.shared.dataTask(with: requestURL) { data, _, _ in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.isLoadingDetail = false }
                return
            }
            
            // استخراج العنوان
            let titlePattern = "<h1 class=\"entry-title\"[^>]*?>([^<]+)</h1>"
            let title = self.firstMatch(for: titlePattern, in: html)?[1] ?? "بدون عنوان"
            
            // استخراج الصورة الرئيسية
            let imgPattern = "<div class=\"thumb\"[^>]*?>.*?<img src=\"([^\"]+)\""
            let imageURL = self.firstMatch(for: imgPattern, in: html)?[1] ?? ""
            
            // استخراج الوصف
            let descPattern = "<div class=\"entry-content\"[^>]*?><p>([^<]+)</p>"
            let description = self.firstMatch(for: descPattern, in: html)?[1] ?? "لا يوجد وصف"
            
            // استخراج أرقام الحلقات
            let epsPattern = "class=\"CSB\"[^>]*?><span>الحلقة ([^<]+)</span>"
            let epsNumbers = self.matches(for: epsPattern, in: html, options: [])
            
            // استخراج السيرفرات
            let serverPattern = "source=\"ani\" quality-data=\"(FHD|HD|SD)\" data=\"([^\"]+)\" class=\"([^\"]+)\" type=\"([^\"]+)\""
            let serverMatches = self.matches(for: serverPattern, in: html, options: [])
            
            var episodes: [Episode] = []
            for epNum in epsNumbers {
                let num = epNum.count > 1 ? epNum[1] : (epNum.first ?? "1")
                var ep = Episode(number: num)
                for serv in serverMatches {
                    if serv.count >= 5 { // full match + 3 groups (quality, data, type)
                        ep.servers.append(Server(name: serv[4], quality: serv[1], dataCode: serv[2], type: serv[4]))
                    }
                }
                episodes.append(ep)
            }
            
            DispatchQueue.main.async {
                self.currentDetail = AnimeDetail(
                    imageURL: imageURL,
                    title: title,
                    description: description,
                    rating: "?",
                    status: "?",
                    type: "?",
                    releaseYear: "",
                    episodes: episodes
                )
                self.isLoadingDetail = false
            }
        }.resume()
    }
    
    // 3. تشغيل حلقة (مؤقت)
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
    
    // أدوات Regex محسّنة
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
    
    private func firstMatch(for regex: String, in text: String) -> [String]? {
        return matches(for: regex, in: text, options: [.dotMatchesLineSeparators]).first
    }
}