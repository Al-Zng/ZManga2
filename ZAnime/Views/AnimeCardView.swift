import SwiftUI

struct AnimeCardView: View {
    let anime: AnimeItem
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: anime.imageURL)) { phase in
                if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) }
                else { Rectangle().fill(Color.gray) }
            }.frame(width: 110, height: 150).cornerRadius(8).clipped()
            Text(anime.title).font(.caption).bold().foregroundColor(.white).lineLimit(2).multilineTextAlignment(.center)
        }.frame(width: 110)
    }
}