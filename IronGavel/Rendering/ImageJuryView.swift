import SwiftUI

struct ImageJuryView: View {
    let fileURL: URL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = ImageLoader.shared.image(at: fileURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
