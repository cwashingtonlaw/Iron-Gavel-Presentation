import SwiftUI

struct ImagePreview: View {
    let fileURL: URL

    var body: some View {
        if let image = UIImage(contentsOfFile: fileURL.path) {
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
