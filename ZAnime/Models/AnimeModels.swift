import Foundation

// MARK: - نموذج انمي في القائمة الرئيسية
struct AnimeItem: Identifiable, Codable {
    var id = UUID()
    let title: String
    let url: String
    let imageURL: String
    var status: String = "مستمر"
    var type: String = "مسلسل"
}

// MARK: - نموذج تفاصيل الانمي (مع حلقات)
struct AnimeDetail {
    var imageURL: String
    var title: String
    var description: String = "يتم التحميل..."
    var rating: String = "0.0"
    var status: String = "مكتمل"
    var type: String = "مسلسل"
    var releaseYear: String = ""
    var episodes: [Episode] = []
}

// MARK: - نموذج الحلقة
struct Episode: Identifiable {
    var id = UUID()
    var number: String
    var servers: [Server] = []
}

// MARK: - نموذج السيرفر
struct Server: Identifiable {
    var id = UUID()
    var name: String
    var quality: String
    var dataCode: String
    var type: String
}