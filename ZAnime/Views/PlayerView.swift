import SwiftUI
import AVKit

struct PlayerView: View {
    let streamURL: URL?
    let isLoading: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let streamURL = streamURL {
                VideoPlayer(player: AVPlayer(url: streamURL))
            } else if isLoading {
                ProgressView("جار تحميل الفيديو...")
            } else {
                VStack { Image(systemName: "wifi.slash").font(.largeTitle); Text("تعذر تحميل الفيديو") }
            }
            VStack { HStack { Button(action: { presentationMode.wrappedValue.dismiss() }) { Image(systemName: "xmark.circle.fill").font(.largeTitle) }.padding(); Spacer() }; Spacer() }
        }
    }
}