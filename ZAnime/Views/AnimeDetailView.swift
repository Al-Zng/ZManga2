import SwiftUI

@available(iOS 16.0, *)
struct AnimeDetailView: View {
    let animeURL: String
    @EnvironmentObject var scraper: ScraperManager
    @State private var selectedServer: Server?
    
    var body: some View {
        ScrollView {
            if let detail = scraper.currentDetail {
                VStack(alignment: .leading, spacing: 16) {
                    // صورة الغلاف
                    AsyncImage(url: URL(string: detail.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Rectangle().fill(Color.gray)
                        }
                    }
                    .frame(height: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // العنوان
                    Text(detail.title)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    // أزرار الإجراءات
                    HStack(spacing: 20) {
                        Button(action: { /* مشاهدة */ }) {
                            Label("مشاهدة", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        Button(action: { /* إضافة للمفضلة */ }) {
                            Image(systemName: "bookmark")
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                        
                        Button(action: { /* مشاركة */ }) {
                            Image(systemName: "square.and.arrow.up")
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    
                    // المعلومات
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "النوع", value: detail.type)
                        InfoRow(label: "التقييم", value: "⭐️ \(detail.rating)")
                        InfoRow(label: "الحالة", value: detail.status)
                        InfoRow(label: "الاستوديو", value: detail.studio)
                    }
                    .padding(.horizontal)
                    
                    // الوصف
                    Text("القصة")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    Text(detail.description)
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // الحلقات
                    if !detail.episodes.isEmpty {
                        Text("الحلقات")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(detail.episodes) { episode in
                            VStack(alignment: .leading) {
                                Text("الحلقة \(episode.number)")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 4)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(episode.servers) { server in
                                            Button(action: {
                                                selectedServer = server
                                                scraper.playEpisode(server: server)
                                            }) {
                                                Text("\(server.name) \(server.quality)")
                                                    .font(.caption)
                                                    .padding(8)
                                                    .background(Color.blue.opacity(0.7))
                                                    .cornerRadius(8)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            Divider().background(Color.gray)
                        }
                    } else {
                        Text("لا توجد حلقات")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                }
            } else {
                ProgressView("جار التحميل...")
                    .foregroundColor(.white)
                    .onAppear {
                        scraper.fetchAnimeDetail(from: animeURL)
                    }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .fullScreenCover(item: $selectedServer) { server in
            PlayerView(streamURL: scraper.streamURL, isLoading: scraper.isLoadingStream)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
        }
    }
}