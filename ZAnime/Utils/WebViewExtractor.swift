import WebKit
import Foundation

class WebViewExtractor: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((URL?) -> Void)?
    private var timer: Timer?
    
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
        // إلغاء العملية تلقائياً بعد 15 ثانية إذا لم يتم العثور على رابط
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
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
        // ننتظر قليلاً ليتم تنفيذ JavaScript داخل الصفحة (تأخير 3 ثوانٍ إضافية)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
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
        // JavaScript لاستخراج أي رابط m3u8 أو mp4 من innerHTML
        let js = """
        (function() {
            var html = document.documentElement.outerHTML;
            var m3u8 = html.match(/https?:\\/\\/[^' "\\n]+\\.m3u8[^' "]*/i);
            if (m3u8 && m3u8[0]) return m3u8[0];
            var mp4 = html.match(/https?:\\/\\/[^' "\\n]+\\.mp4[^' "]*/i);
            return mp4 ? mp4[0] : null;
        })();
        """
        webView?.evaluateJavaScript(js) { [weak self] result, error in
            if let link = result as? String, !link.isEmpty {
                let streamURL = URL(string: link)
                self?.complete(with: streamURL)
            } else {
                self?.complete(with: nil)
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