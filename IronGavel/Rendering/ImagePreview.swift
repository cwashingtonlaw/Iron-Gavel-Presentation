import SwiftUI

struct ImagePreview: View {
    let fileURL: URL

    var body: some View {
        if let image = ImageLoader.shared.image(at: fileURL) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Text("Cannot render this image\n\(fileURL.path)")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}
