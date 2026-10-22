import Photos
import SwiftUI

struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Setzt Kamerabild und Schminke zu einem fertigen Foto zusammen.
@MainActor
enum PhotoComposer {
    static func compose(image: CGImage, faces: [FaceLandmarks], design: DesignID, visibleSteps: Int?, opacity: Double) -> UIImage? {
        let size = CGSize(width: image.width, height: image.height)
        let content = ZStack(alignment: .bottomTrailing) {
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: size.width, height: size.height)
            Canvas { ctx, canvasSize in
                let map: (CGPoint) -> CGPoint = { CGPoint(x: $0.x * canvasSize.width, y: $0.y * canvasSize.height) }
                for landmarks in faces {
                    guard let face = FaceGeometry.from(landmarks, map: map) else { continue }
                    FacePainter.draw(design, face: face, in: ctx, opacity: opacity, visibleSteps: visibleSteps)
                }
            }
            Watermark(width: size.width)
        }
        .frame(width: size.width, height: size.height)
        return render(content)
    }

    static func composeCartoon(design: DesignID, visibleSteps: Int?, opacity: Double) -> UIImage? {
        let size = CGSize(width: 1080, height: 1350)
        let content = ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: [Spook.plum, Spook.night], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, canvasSize in
                let face = FaceGeometry.cartoon(in: CGRect(origin: .zero, size: canvasSize).insetBy(dx: 60, dy: 60))
                CartoonKid.draw(face, in: ctx, time: 1, blink: false)
                FacePainter.draw(design, face: face, in: ctx, opacity: opacity, visibleSteps: visibleSteps)
            }
            Watermark(width: size.width)
        }
        .frame(width: size.width, height: size.height)
        return render(content)
    }

    private static func render(_ view: some View) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }
}

private struct Watermark: View {
    let width: CGFloat

    var body: some View {
        Text("🎃 Fratzenfabrik")
            .font(Spook.title(width * 0.05))
            .foregroundStyle(Spook.slime)
            .shadow(color: .black.opacity(0.8), radius: width * 0.006)
            .padding(width * 0.04)
            .rotationEffect(.degrees(-4))
    }
}

struct PhotoResultView: View {
    let photo: CapturedPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var saveState: SaveState = .idle

    enum SaveState { case idle, saving, saved, denied, failed }

    var body: some View {
        ZStack {
            SpookyBackground()
            VStack(spacing: 18) {
                Text("Buuuh! Schaurig schön! 👻")
                    .font(Spook.title(26))
                    .foregroundStyle(Spook.slime)
                    .glow(Spook.slime, radius: 8)
                    .padding(.top, 24)

                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Spook.pumpkin, lineWidth: 3))
                    .rotationEffect(.degrees(-1.5))
                    .shadow(color: Spook.pumpkin.opacity(0.5), radius: 16)
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button(action: save) {
                        Label(saveLabel, systemImage: saveState == .saved ? "checkmark" : "square.and.arrow.down")
                            .font(Spook.title(16))
                    }
                    .buttonStyle(SlimeButtonStyle())
                    .disabled(saveState == .saving || saveState == .saved)

                    ShareLink(item: Image(uiImage: photo.image),
                              preview: SharePreview("Fratzenfabrik", image: Image(uiImage: photo.image))) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                            .font(Spook.title(16))
                    }
                    .buttonStyle(SlimeButtonStyle(color: Spook.pumpkin))
                }
                .padding(.horizontal, 20)

                Button("Weiterspuken") { dismiss() }
                    .font(Spook.title(16))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 16)
            }
        }
        .sensoryFeedback(.success, trigger: saveState == .saved)
    }

    private var saveLabel: String {
        switch saveState {
        case .idle: "Speichern"
        case .saving: "Speichere…"
        case .saved: "Gespeichert!"
        case .denied: "Kein Zugriff"
        case .failed: "Nochmal"
        }
    }

    private func save() {
        saveState = .saving
        let image = photo.image
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in saveState = .denied }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                Task { @MainActor in saveState = success ? .saved : .failed }
            }
        }
    }
}
