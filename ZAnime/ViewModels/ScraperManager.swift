import Foundation
import WebKit
import SwiftUI

class ScraperManager: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var animeList: [AnimeItem] = []
    @Published var currentDetail: AnimeDetail?
    @Published var streamURL: URL?
    @Published var isLoadingList = false
    @Published var isLoadingDetail = false
    @Published var isLoadingStream = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasMorePages = true

    private var currentDetailURL: String = ""
    private var webViewExtractor: WebViewExtractor?

    override init() {
        super.init()
        fetchAnimeList(page: 1, reset: true)
    }

    // MARK: - 1. قائمة الأنميات مع pagination
    func fetchAnimeList(page: Int = 1, status: String = "ongoing", reset: Bool = false) {
        guard !isLoadingList else { return }
        isLoadingList = true
        errorMessage = nil
        if reset {
            animeList = []
            currentPage = 1
            hasMorePages = true
        }

        let urlString = "https://animeslayerweb.com/anime/page/\(page)/?status=\(status)&order=update"
        guard let url = URL(string: urlString) else { isLoadingList = false; return }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.isLoadingList = false } }
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.errorMessage = "فشل تحميل البيانات" }
                return
            }
            let items = self.extractAnimeItems(from: html)
            let hasNext = html.contains("class=\"next page-numbers\"") || html.contains("rel=\"next\"")
            DispatchQueue.main.async {
                if reset {
                    self.animeList = items
                } else {
                    self.animeList.append(contentsOf: items)
                }
                self.currentPage = page
                self.hasMorePages = hasNext
                if items.isEmpty && page == 1 { self.errorMessage = "لا توجد أنميات" }
            }
        }.resume()
    }

    func loadNextPage(status: String = "ongoing") {
        guard hasMorePages && !isLoadingList else { return }
        fetchAnimeList(page: currentPage + 1, status: status)
    }

    // MARK: - استخراج الأنميات من HTML
    private func extractAnimeItems(from html: String) -> [AnimeItem] {
        var items: [AnimeItem] = []

        // pattern للـ article cards
        let pattern = #"<article[^>]*class="[^"]*bs[^"]*"[^>]*>(.*?)</article>"#
        let articles = regexMatches(pattern: pattern, in: html, options: [.dotMatchesLineSeparators])

        for block in articles {
            guard block.count > 1 else { continue }
            let content = block[1]

            guard
                let href = firstCapture(pattern: #"href="(https://animeslayerweb\.com/anime/[^"]+)""#, in: content),
                let title = firstCapture(pattern: #"title="([^"]+)""#, in: content)
            else { continue }

            // الصورة - نجلب بجودة عالية بحذف resize parameter
            let rawImg = firstCapture(pattern: #"src="(https?://[^"]+\.(?:jpg|jpeg|png|webp)[^"]*)""#, in: content) ?? ""
            let imageURL = cleanImageURL(rawImg)

            // عدد الحلقات
            let epCount = firstCapture(pattern: #"<div class="[^"]*epx[^"]*">([^<]+)</div>"#, in: content) ?? ""

            // الحالة
            let status = content.contains("Ongoing") || content.contains("مستمر") ? "مستمر" : "مكتمل"

            items.append(AnimeItem(
                title: title,
                url: href,
                imageURL: imageURL,
                status: status,
                episodeCount: epCount.trimmingCharacters(in: .whitespaces)
            ))
        }
        return items
    }

    // MARK: - 2. تفاصيل الأنمي (إصلاح مشكلة البيانات القديمة + الحلقات)
    func fetchAnimeDetail(from url: String) {
        // إعادة تعيين البيانات فوراً عند طلب أنمي جديد
        currentDetail = nil
        currentDetailURL = url
        isLoadingDetail = true
        errorMessage = nil

        guard let requestURL = URL(string: url) else {
            isLoadingDetail = false
            return
        }

        var request = URLRequest(url: requestURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard
                let data = data,
                let html = String(data: data, encoding: .utf8),
                // تأكد إن الـ URL لم يتغير (المستخدم لم يفتح أنمي آخر بعد)
                self.currentDetailURL == url
            else {
                DispatchQueue.main.async { self?.isLoadingDetail = false }
                return
            }

            let detail = self.parseAnimeDetail(from: html)
            let postID = self.firstCapture(pattern: #"data-id="(\d+)""#, in: html) ?? ""

            DispatchQueue.main.async {
                self.currentDetail = detail
                self.isLoadingDetail = false
            }

            // جلب الحلقات عبر AJAX منفصل
            if !postID.isEmpty {
                self.fetchEpisodes(postID: postID, animeURL: url)
            }
        }.resume()
    }

    private func parseAnimeDetail(from html: String) -> AnimeDetail {
        var detail = AnimeDetail()

        // العنوان
        detail.title = firstCapture(
            pattern: #"<h1 class="entry-title"[^>]*>([^<]+)</h1>"#, in: html
        )?.trimmingCharacters(in: .whitespaces) ?? "بدون عنوان"

        // الصورة - من bigcontent أو thumb
        let rawImg = firstCapture(
            pattern: #"class="thumb"[^>]*>[\s\S]*?<img[^>]*src="([^"]+)""#, in: html
        ) ?? firstCapture(
            pattern: #"itemprop="image"[^>]*src="([^"]+)""#, in: html
        ) ?? ""
        detail.imageURL = cleanImageURL(rawImg)

        // الوصف
        detail.description = firstCapture(
            pattern: #"itemprop="description"[^>]*>\s*<p>([\s\S]*?)</p>"#, in: html
        )?.htmlDecoded ?? ""

        // التقييم
        detail.rating = firstCapture(
            pattern: #"itemprop="ratingValue" content="([^"]+)""#, in: html
        ) ?? "0.0"

        // الحالة
        detail.status = firstCapture(
            pattern: #"<b>الحالة:</b>\s*([^<]+)"#, in: html
        )?.trimmingCharacters(in: .whitespaces) ?? ""

        // النوع
        detail.type = firstCapture(
            pattern: #"<b>النوع:</b>\s*([^<]+)"#, in: html
        )?.trimmingCharacters(in: .whitespaces) ?? ""

        // الاستوديو
        detail.studio = firstCapture(
            pattern: #"<b>الاستوديو:</b>\s*<a[^>]*>([^<]+)</a>"#, in: html
        )?.trimmingCharacters(in: .whitespaces) ?? ""

        // سنة الإصدار
        detail.releaseYear = firstCapture(
            pattern: #"<b>تم الإصدار:</b>\s*(\d{4})"#, in: html
        ) ?? ""

        // الموسم
        detail.season = firstCapture(
            pattern: #"<b>الموسم:</b>\s*<a[^>]*>([^<]+)</a>"#, in: html
        )?.trimmingCharacters(in: .whitespaces) ?? ""

        // المدة
        detail.duration = firstCapture(
            pattern: #"<b>المدة:</b>\s*([^<]+)"#, in: html
        )?.trimmingCharacters(in: .whitespaces) ?? ""

        // الأنواع
        let genreMatches = regexMatches(
            pattern: #"class="genxed"[^>]*>(.*?)</div>"#,
            in: html, options: [.dotMatchesLineSeparators]
        )
        if let genreBlock = genreMatches.first?[safe: 1] {
            detail.genres = regexMatches(
                pattern: #"rel="tag">([^<]+)</a>"#, in: genreBlock, options: []
            ).compactMap { $0[safe: 1] }
        }

        return detail
    }

    // MARK: - جلب الحلقات عبر AJAX (الحل الصحيح للـ cache المفرغ)
    private func fetchEpisodes(postID: String, animeURL: String) {
        // WP AJAX endpoint للحلقات - يتجاوز الـ server-side cache
        guard let ajaxURL = URL(string: "https://animeslayerweb.com/wp-admin/admin-ajax.php") else { return }

        var request = URLRequest(url: ajaxURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(animeURL, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.httpBody = "action=ts_episode_list&post_id=\(postID)".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self, self.currentDetailURL == animeURL else { return }
            
            // إذا فشل AJAX، نحاول WP REST API
            if let data = data, let html = String(data: data, encoding: .utf8), !html.isEmpty && html != "0" && html != "-1" {
                let episodes = self.parseEpisodeList(from: html)
                if !episodes.isEmpty {
                    DispatchQueue.main.async {
                        self.currentDetail?.episodes = episodes
                    }
                    return
                }
            }
            // fallback: WP REST API
            self.fetchEpisodesViaRESTAPI(postID: postID, animeURL: animeURL)
        }.resume()
    }

    private func fetchEpisodesViaRESTAPI(postID: String, animeURL: String) {
        // جلب الحلقات عبر WP REST API custom endpoint
        let endpoints = [
            "https://animeslayerweb.com/wp-json/wp/v2/episode?series=\(postID)&per_page=100&_fields=id,title,link,date,meta",
            "https://animeslayerweb.com/wp-json/wp/v2/episode?post_parent=\(postID)&per_page=100",
        ]

        fetchEpisodeFromEndpoints(endpoints, animeURL: animeURL, index: 0)
    }

    private func fetchEpisodeFromEndpoints(_ endpoints: [String], animeURL: String, index: Int) {
        guard index < endpoints.count else { return }
        guard let url = URL(string: endpoints[index]) else {
            fetchEpisodeFromEndpoints(endpoints, animeURL: animeURL, index: index + 1)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self, self.currentDetailURL == animeURL else { return }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               !json.isEmpty {
                let episodes = self.parseEpisodesFromJSON(json)
                DispatchQueue.main.async {
                    self.currentDetail?.episodes = episodes
                }
            } else {
                self.fetchEpisodeFromEndpoints(endpoints, animeURL: animeURL, index: index + 1)
            }
        }.resume()
    }

    private func parseEpisodeList(from html: String) -> [Episode] {
        var episodes: [Episode] = []
        let liPattern = #"<li[^>]*>(.*?)</li>"#
        let items = regexMatches(pattern: liPattern, in: html, options: [.dotMatchesLineSeparators])

        for item in items {
            guard let content = item[safe: 1] else { continue }
            let num = firstCapture(pattern: #"class="[^"]*ep-num[^"]*">([^<]+)"#, in: content)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let title = firstCapture(pattern: #"class="[^"]*ep-title[^"]*">([^<]+)"#, in: content)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let date = firstCapture(pattern: #"class="[^"]*ep-date[^"]*">([^<]+)"#, in: content)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let url = firstCapture(pattern: #"href="([^"]+)""#, in: content) ?? ""

            if !num.isEmpty || !url.isEmpty {
                episodes.append(Episode(number: num, title: title, date: date, url: url))
            }
        }
        return episodes
    }

    private func parseEpisodesFromJSON(_ json: [[String: Any]]) -> [Episode] {
        return json.enumerated().compactMap { (index, item) in
            let link = item["link"] as? String ?? ""
            let titleObj = item["title"] as? [String: Any]
            let title = (titleObj?["rendered"] as? String ?? "").htmlDecoded
            let date = (item["date"] as? String ?? "").prefix(10).description
            let num = String(json.count - index)
            return Episode(number: num, title: title, date: date, url: link)
        }
    }

    // MARK: - 3. البحث
    func searchAnime(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoadingList = true
        animeList = []
        errorMessage = nil
        hasMorePages = false

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://animeslayerweb.com/?s=\(encoded)") else {
            isLoadingList = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.isLoadingList = false } }
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.errorMessage = "فشل البحث" }
                return
            }
            let items = self.extractAnimeItems(from: html)
            DispatchQueue.main.async {
                self.animeList = items
                if items.isEmpty { self.errorMessage = "لا توجد نتائج لـ \"\(query)\"" }
            }
        }.resume()
    }

    // MARK: - 4. تشغيل الحلقة
    func playEpisode(url: String, completion: @escaping (URL?) -> Void) {
        isLoadingStream = true
        streamURL = nil

        // جلب صفحة الحلقة واستخراج رابط السيرفر
        guard let episodeURL = URL(string: url) else {
            isLoadingStream = false
            completion(nil)
            return
        }

        let extractor = WebViewExtractor()
        self.webViewExtractor = extractor
        extractor.extractStreamURL(from: episodeURL) { [weak self] streamURL in
            DispatchQueue.main.async {
                self?.streamURL = streamURL
                self?.isLoadingStream = false
                completion(streamURL)
            }
        }
    }

    // MARK: - Image URL Helper
    private func cleanImageURL(_ url: String) -> String {
        var clean = url
        // حذف resize parameter للحصول على جودة أعلى
        clean = clean.replacingOccurrences(of: #"\?resize=\d+,\d+"#, with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"&resize=\d+,\d+"#, with: "", options: .regularExpression)
        // تحويل wp.com CDN links للأصل
        if clean.contains("i0.wp.com/") || clean.contains("i1.wp.com/") ||
           clean.contains("i2.wp.com/") || clean.contains("i3.wp.com/") {
            clean = clean.replacingOccurrences(of: #"https://i\d\.wp\.com/"#, with: "https://", options: .regularExpression)
        }
        return clean
    }

    // MARK: - Regex Helpers
    func regexMatches(pattern: String, in text: String, options: NSRegularExpression.Options) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return results.map { match in
            (0..<match.numberOfRanges).compactMap {
                guard let range = Range(match.range(at: $0), in: text) else { return nil }
                return String(text[range])
            }
        }
    }

    func firstCapture(pattern: String, in text: String) -> String? {
        return regexMatches(pattern: pattern, in: text, options: [.dotMatchesLineSeparators])
            .first?[safe: 1]
    }
}

// MARK: - Helpers
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension String {
    var htmlDecoded: String {
        var result = self
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#039;", "'"), ("&nbsp;", " "),
            ("&#8217;", "'"), ("&#8220;", "\""), ("&#8221;", "\""),
        ]
        for (encoded, decoded) in entities {
            result = result.replacingOccurrences(of: encoded, with: decoded)
        }
        return result
    }
}
