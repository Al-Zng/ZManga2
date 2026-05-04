import SwiftUI

private let accentPurple = Color(red: 0.38, green: 0.18, blue: 0.96)
private let bgDark = Color(red: 0.07, green: 0.07, blue: 0.10)

@available(iOS 16.0, *)
struct AnimeDetailView: View {
    let animeURL: String
    @EnvironmentObject var scraper: ScraperManager
    @State private var showPlayer = false
    @State private var selectedEpisodeURL: String = ""
    @State private var streamURL: URL?
    @State private var isExtractingStream = false
    @State private var streamError = false
    @State private var descExpanded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            bgDark.ignoresSafeArea()

            if scraper.isLoadingDetail {
                loadingView
            } else if let detail = scraper.currentDetail {
                detailContent(detail)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // مهم: clear currentDetail عند الرجوع
                    scraper.currentDetail = nil
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("رجوع")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            // إعادة جلب كل مرة - يحل مشكلة البيانات القديمة
            scraper.fetchAnimeDetail(from: animeURL)
        }
        .onDisappear {
            scraper.currentDetail = nil
        }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(streamURL: streamURL, isLoading: isExtractingStream, hasError: streamError)
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(accentPurple)
            Text("جار التحميل...")
                .foregroundColor(.white.opacity(0.4))
                .font(.system(size: 14))
            Spacer()
        }
    }

    // MARK: - Detail Content
    @ViewBuilder
    private func detailContent(_ detail: AnimeDetail) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Hero section
                heroSection(detail)

                // Info + actions
                VStack(alignment: .leading, spacing: 20) {
                    // Genres
                    if !detail.genres.isEmpty {
                        genrePills(detail.genres)
                    }

                    // Stats row
                    statsRow(detail)

                    // Synopsis
                    synopsisSection(detail)

                    // Divider
                    Divider().background(Color(white: 0.18))

                    // Episodes
                    episodesSection(detail)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Hero
    private func heroSection(_ detail: AnimeDetail) -> some View {
        ZStack(alignment: .bottom) {
            // الصورة الخلفية - blurred
            AsyncImage(url: URL(string: detail.imageURL)) { phase in
                if let img = phase.image {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(white: 0.12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()
            .blur(radius: 20)
            .overlay(Color.black.opacity(0.5))

            // Gradient overlay
            LinearGradient(
                colors: [.clear, bgDark],
                startPoint: .init(x: 0.5, y: 0.3),
                endPoint: .bottom
            )

            // Content
            HStack(alignment: .bottom, spacing: 16) {
                // Poster
                AsyncImage(url: URL(string: detail.imageURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Color(white: 0.15)
                    default:
                        Color(white: 0.12)
                            .overlay(ProgressView().tint(.white.opacity(0.3)))
                    }
                }
                .frame(width: 110, height: 155)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)

                // Title + meta
                VStack(alignment: .leading, spacing: 8) {
                    Text(detail.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)

                    HStack(spacing: 8) {
                        if !detail.rating.isEmpty && detail.rating != "0.0" {
                            Label(detail.rating, systemImage: "star.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                        if !detail.releaseYear.isEmpty {
                            Text(detail.releaseYear)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    if !detail.status.isEmpty {
                        statusBadge(detail.status)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 280)
    }

    private func statusBadge(_ status: String) -> some View {
        let isOngoing = status.contains("يعرض") || status.contains("Ongoing")
        return Text(status)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(isOngoing ? .green : .white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isOngoing ? Color.green.opacity(0.15) : Color(white: 0.2))
            .cornerRadius(6)
    }

    // MARK: - Genres
    private func genrePills(_ genres: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(accentPurple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accentPurple.opacity(0.12))
                        .cornerRadius(20)
                }
            }
        }
    }

    // MARK: - Stats
    private func statsRow(_ detail: AnimeDetail) -> some View {
        HStack(spacing: 0) {
            statItem(label: "النوع", value: detail.type.isEmpty ? "—" : detail.type)
            Divider().frame(height: 28).background(Color(white: 0.2))
            statItem(label: "الاستوديو", value: detail.studio.isEmpty ? "—" : detail.studio)
            if !detail.season.isEmpty {
                Divider().frame(height: 28).background(Color(white: 0.2))
                statItem(label: "الموسم", value: detail.season)
            }
            if !detail.duration.isEmpty {
                Divider().frame(height: 28).background(Color(white: 0.2))
                statItem(label: "المدة", value: detail.duration)
            }
        }
        .padding(.vertical, 12)
        .background(Color(white: 0.10))
        .cornerRadius(12)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Synopsis
    private func synopsisSection(_ detail: AnimeDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("القصة")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            if detail.description.isEmpty {
                Text("لا يوجد وصف")
                    .foregroundColor(.white.opacity(0.35))
                    .font(.system(size: 14))
            } else {
                Text(detail.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(descExpanded ? nil : 3)
                    .lineSpacing(4)

                if detail.description.count > 120 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { descExpanded.toggle() }
                    } label: {
                        Text(descExpanded ? "أقل" : "المزيد")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentPurple)
                    }
                }
            }
        }
    }

    // MARK: - Episodes
    @ViewBuilder
    private func episodesSection(_ detail: AnimeDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("الحلقات")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                if !detail.episodes.isEmpty {
                    Text("(\(detail.episodes.count))")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            }

            if detail.episodes.isEmpty {
                // Loading or empty
                if scraper.isLoadingDetail {
                    HStack {
                        ProgressView().tint(accentPurple)
                        Text("جار تحميل الحلقات...")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                } else {
                    Text("لا توجد حلقات متاحة")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.vertical, 8)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(detail.episodes) { episode in
                        episodeRow(episode)
                    }
                }
            }
        }
    }

    private func episodeRow(_ episode: Episode) -> some View {
        Button {
            guard !episode.url.isEmpty else { return }
            selectedEpisodeURL = episode.url
            isExtractingStream = true
            streamError = false
            streamURL = nil
            showPlayer = true

            scraper.playEpisode(url: episode.url) { url in
                isExtractingStream = false
                if let url = url {
                    streamURL = url
                } else {
                    streamError = true
                }
            }
        } label: {
            HStack(spacing: 12) {
                // رقم الحلقة
                ZStack {
                    Circle()
                        .fill(accentPurple.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Text(episode.number)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(accentPurple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(episode.title.isEmpty ? "الحلقة \(episode.number)" : episode.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if !episode.date.isEmpty {
                        Text(episode.date)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(white: 0.11))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
