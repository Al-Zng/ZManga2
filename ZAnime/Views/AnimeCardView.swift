import SwiftUI

struct AnimeCardView: View {
    let anime: AnimeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // الصورة
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: anime.imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        ZStack {
                            Color(white: 0.12)
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    default:
                        ZStack {
                            Color(white: 0.10)
                            ProgressView()
                                .tint(.white.opacity(0.4))
                        }
                    }
                }
                .frame(width: 112, height: 158)
                .clipped()

                // gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Badge حلقات
                if !anime.episodeCount.isEmpty {
                    Text(anime.episodeCount)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.38, green: 0.18, blue: 0.96))
                        .cornerRadius(4)
                        .padding(6)
                }
            }
            .cornerRadius(10)
            .frame(width: 112, height: 158)

            // العنوان
            Text(anime.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 112, alignment: .leading)
        }
        .frame(width: 112)
    }
}
