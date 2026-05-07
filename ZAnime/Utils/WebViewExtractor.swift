import WebKit
import Foundation

class WebViewExtractor: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((URL?) -> Void)?
    private var timer: Timer?
    private var attemptCount = 0
    private let maxAttempts = 3
    
    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        // نسمح بتشغيل JavaScript والوصول للوسائط
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
    }
    
    /// يحمّل صفحة السيرفر ويستخرج منها رابط m3u8 أو mp4
    /// - Parameters:
    ///   - url: رابط الصفحة المستهدفة (مثلاً رابط الحلقة)
    ///   - completion: closure يعيد رابط البث إن وُجد، أو nil
    func extractStreamURL(from url: URL, completion: @escaping (URL?) -> Void) {
        self.completion = completion
        self.attemptCount = 0
        
        // إلغاء العملية تلقائياً بعد 20 ثانية إذا لم يتم العثور على رابط
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] _ in
            if self?.completion != nil {
                self?.completion?(nil)
                self?.completion = nil
            }
        }
        
        let request = URLRequest(url: url)
        webView?.load(request)
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // ننتظر قليلاً ليتم تنفيذ JavaScript داخل الصفحة (تأخير متزايد)
        let delay = Double(1 + attemptCount) * 2.0 // 2، 3، 4 ثوانٍ
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.findMediaURL()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(with: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        complete(with: nil)
    }
    
    private func findMediaURL() {
        // JavaScript محسّن للبحث عن الفيديو في أماكن متعددة
        let js = """
        (function() {
            var html = document.documentElement.outerHTML;
            
            // البحث عن m3u8
            var m3u8Match = html.match(/https?:\\/\\/[^' "\\n]+\\.m3u8[^' "]*/i);
            if (m3u8Match && m3u8Match[0]) {
                return m3u8Match[0];
            }
            
            // البحث عن mp4
            var mp4Match = html.match(/https?:\\/\\/[^' "\\n]+\\.mp4[^' "]*/i);
            if (mp4Match && mp4Match[0]) {
                return mp4Match[0];
            }
            
            // البحث عن src في iframe
            var iframes = document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
                var src = iframes[i].src;
                if (src && (src.includes('m3u8') || src.includes('mp4') || src.includes('video'))) {
                    return src;
                }
            }
            
            // البحث عن video tags
            var videos = document.querySelectorAll('video source');
            for (var i = 0; i < videos.length; i++) {
                var src = videos[i].src;
                if (src) {
                    return src;
                }
            }
            
            // البحث عن src في video tags
            var videoElements = document.querySelectorAll('video');
            for (var i = 0; i < videoElements.length; i++) {
                if (videoElements[i].src) {
                    return videoElements[i].src;
                }
            }
            
            return null;
        })();
        """
        
        webView?.evaluateJavaScript(js) { [weak self] result, error in
            if let link = result as? String, !link.isEmpty {
                let streamURL = URL(string: link)
                self?.complete(with: streamURL)
            } else {
                // محاولة أخرى إذا لم نجد الفيديو
                self?.attemptCount += 1
                if self?.attemptCount ?? 0 < self?.maxAttempts ?? 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.findMediaURL()
                    }
                } else {
                    self?.complete(with: nil)
                }
            }
        }
    }
    
    private func complete(with url: URL?) {
        timer?.invalidate()
        timer = nil
        completion?(url)
        completion = nil
        // إيقاف تحميل الصفحة بعد الاستخراج لتوفير الموارد
        webView?.stopLoading()
    }
}
