import SwiftUI
import AVKit

struct PlayerView: View {
    let streamURL: URL?
    let isLoading: Bool
    let hasError: Bool
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = streamURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("جار تحميل الفيديو...")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 14))
                }
            } else if hasError {
                VStack(spacing: 16) {
                    Image(systemName: "play.slash.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.3))
                    Text("تعذر تحميل الفيديو")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 15))
                    Text("قد يكون السيرفر غير متاح")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 13))
                }
            }

            // زر الإغلاق
            VStack {
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(20)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}
