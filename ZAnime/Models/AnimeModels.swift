import Foundation

// MARK: - نموذج الأنمي في القائمة
struct AnimeItem: Identifiable, Codable, Hashable {
    var id = UUID()
    let title: String
    let url: String
    let imageURL: String
    var status: String = "مستمر"
    var type: String = "مسلسل"
    var episodeCount: String = ""
    var rating: String = ""
}

// MARK: - تفاصيل الأنمي
struct AnimeDetail {
    var imageURL: String = ""
    var title: String = ""
    var description: String = ""
    var rating: String = "0.0"
    var status: String = ""
    var type: String = ""
    var releaseYear: String = ""
    var studio: String = ""
    var season: String = ""
    var duration: String = ""
    var genres: [String] = []
    var episodes: [Episode] = []
}

// MARK: - الحلقة
struct Episode: Identifiable, Hashable {
    var id = UUID()
    var number: String
    var title: String = ""
    var date: String = ""
    var url: String = ""
    var servers: [Server] = []
}

// MARK: - السيرفر
struct Server: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var quality: String
    var dataCode: String
    var type: String
}
