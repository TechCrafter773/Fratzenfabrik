import SwiftUI

/// Der Spuk-Spiegel: Live-Kamera mit Schminke als Overlay auf jedem erkannten Gesicht.
struct MirrorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()

    @State private var design: DesignID
    @State private var stepMode: Bool
    @State private var step: Int
    @State private var opacity: Double = 0.9
    @State private var photo: CapturedPhoto?
    @State private var flash = false
    @State private var shutterCount = 0

    init(design: DesignID, stepMode: Bool = false, step: Int = 0) {
        _design = State(initialValue: design)
        _stepMode = State(initialValue: stepMode)
        _step = State(initialValue: step)
    }

    private var current: FaceDesign { DesignCatalog.design(design) }
    private var visibleSteps: Int? { stepMode ? step + 1 : nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.access {
            case .granted: cameraLayer
            case .noCamera: demoLayer
            case .denied: deniedLayer
            case .unknown: ProgressView().tint(Spook.slime)
            }

            controls

            Color.white
                .opacity(flash ? 0.85 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .statusBarHidden()
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .sheet(item: $photo) { photo in
            PhotoResultView(photo: photo)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: design)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sensoryFeedback(.success, trigger: shutterCount)
    }

    // MARK: Ebenen

    private var cameraLayer: some View {
        ZStack {
            CameraPreview(session: camera.tracker.session, configurationID: camera.configurationID, bridge: camera.previewBridge)
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    let map = camera.previewBridge.mapper(for: camera.orientation)
                        ?? aspectFillMapper(imageSize: camera.imageSize, viewSize: size)
                    for landmarks in camera.faces {
                        guard let face = FaceGeometry.from(landmarks, map: map) else { continue }
                        FacePainter.draw(design, face: face, in: ctx, opacity: opacity,
                                         visibleSteps: visibleSteps, pulseLast: stepMode, time: t)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            if camera.faces.isEmpty {
                SearchingHint(front: camera.position == .front)
            }
        }
    }

    private var demoLayer: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Keine Kamera gefunden – hier hilft unser Probe-Kind aus! 🧒")
                .font(Spook.scribble(14))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            DesignPreview(design: design, visibleSteps: visibleSteps, pulseLast: stepMode)
                .opacity(opacity)
                .frame(maxHeight: 420)
                .padding(.horizontal, 20)
            Spacer(minLength: 300)
        }
        .background(SpookyBackground())
    }

    private var deniedLayer: some View {
        VStack(spacing: 16) {
            Text("🙈").font(.system(size: 70)).wobble(10)
            Text("Ohne Kamera kein Spuk!")
                .font(Spook.title(24))
                .foregroundStyle(Spook.pumpkin)
            Text("Erlaube der Fratzenfabrik in den Einstellungen den Kamerazugriff. Die Bilder bleiben auf deinem Gerät.")
                .font(Spook.body(15, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button("Einstellungen öffnen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(SlimeButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding(30)
    }

    // MARK: Bedienung

    private var controls: some View {
        VStack(spacing: 12) {
            topBar
            Spacer()
            if stepMode {
                StepCard(design: current, step: $step)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            opacityRow
            designCarousel
            bottomBar
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: stepMode)
    }

    private var topBar: some View {
        HStack {
            RoundIconButton(systemName: "xmark") { dismiss() }
            Spacer()
            Text("\(current.emoji) \(current.name)")
                .font(Spook.title(17))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.5)))
                .overlay(Capsule().stroke(current.accent.opacity(0.8), lineWidth: 1.5))
                .contentTransition(.opacity)
            Spacer()
            if camera.access == .granted {
                RoundIconButton(systemName: "arrow.triangle.2.circlepath.camera") { camera.flipCamera() }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.top, 8)
    }

    private var opacityRow: some View {
        HStack(spacing: 10) {
            Text("👻").font(.system(size: 16))
            Slider(value: $opacity, in: 0.25...1)
                .tint(Spook.slime)
            Text("🎨").font(.system(size: 16))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.45)))
        .accessibilityLabel("Deckkraft der Schminke")
    }

    private var designCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(DesignCatalog.all) { item in
                        let selected = item.id == design
                        Button {
                            design = item.id
                            step = 0
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.emoji).font(.system(size: selected ? 34 : 26))
                                Text(item.name.components(separatedBy: " ").last ?? item.name)
                                    .font(Spook.body(10, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(selected ? item.accent.opacity(0.35) : .black.opacity(0.45)))
                            .overlay(Circle().stroke(selected ? item.accent : .white.opacity(0.25), lineWidth: selected ? 3 : 1))
                            .glow(selected ? item.accent : .clear, radius: 8)
                            .scaleEffect(selected ? 1.08 : 1)
                        }
                        .buttonStyle(PressableStyle())
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(design, anchor: .center) }
            .onChange(of: design) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: design)
    }

    private var bottomBar: some View {
        HStack {
            RoundIconButton(systemName: "dice.fill", size: 54) {
                let others = DesignCatalog.all.filter { $0.id != design }
                if let pick = others.randomElement() {
                    design = pick.id
                    step = 0
                }
            }
            .accessibilityLabel("Zufällige Fratze")

            Spacer()

            Button(action: takePhoto) {
                ZStack {
                    Circle().fill(Spook.slime).frame(width: 74, height: 74).glow(Spook.slime, radius: 12)
                    Circle().stroke(Spook.night, lineWidth: 4).frame(width: 60, height: 60)
                    Text("📸").font(.system(size: 26))
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Foto machen")

            Spacer()

            Button {
                stepMode.toggle()
                step = 0
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: stepMode ? "sparkles" : "list.number")
                        .font(.system(size: 20, weight: .bold))
                    Text(stepMode ? "Fertig" : "Schritte")
                        .font(Spook.body(10, weight: .heavy))
                }
                .foregroundStyle(stepMode ? Spook.night : .white)
                .frame(width: 54, height: 54)
                .background(Circle().fill(stepMode ? Spook.pumpkin : .black.opacity(0.5)))
                .overlay(Circle().stroke(Spook.pumpkin, lineWidth: 2))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(stepMode ? "Fertigen Look zeigen" : "Schritt-für-Schritt-Anleitung")
        }
        .padding(.horizontal, 12)
    }

    // MARK: Foto

    private func takePhoto() {
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        withAnimation(.easeIn(duration: 0.35).delay(0.1)) { flash = false }

        let design = design, steps = visibleSteps, opacity = opacity
        if camera.access == .granted {
            camera.capture { image, faces in
                if let result = PhotoComposer.compose(image: image, faces: faces, design: design,
                                                      visibleSteps: steps, opacity: opacity) {
                    shutterCount += 1
                    photo = CapturedPhoto(image: result)
                }
            }
        } else if let result = PhotoComposer.composeCartoon(design: design, visibleSteps: steps, opacity: opacity) {
            shutterCount += 1
            photo = CapturedPhoto(image: result)
        }
    }
}

// MARK: - Bausteine

struct RoundIconButton: View {
    let systemName: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(.black.opacity(0.5)))
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

struct SearchingHint: View {
    let front: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("👻").font(.system(size: 64)).wobble(12, speed: 3)
            Text("Huhu? Wo ist das Gesicht?")
                .font(Spook.title(20))
                .foregroundStyle(.white)
            Text(front ? "Schau direkt in die Kamera." : "Halte die Kamera auf das Gesicht eines Kindes – von vorne und gut beleuchtet.")
                .font(Spook.body(14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black.opacity(0.55)))
        .padding(.horizontal, 40)
        .offset(y: -80)
        .allowsHitTesting(false)
    }
}

struct StepCard: View {
    let design: FaceDesign
    @Binding var step: Int

    var body: some View {
        let current = design.steps[min(step, design.steps.count - 1)]
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Schritt \(current.id + 1) von \(design.steps.count)")
                    .font(Spook.body(12, weight: .heavy))
                    .foregroundStyle(Spook.night)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Spook.pumpkin))
                Spacer()
                Label(current.tool, systemImage: "paintbrush.fill")
                    .font(Spook.body(12, weight: .bold))
                    .foregroundStyle(Spook.moon)
            }
            Text(current.title)
                .font(Spook.title(20))
                .foregroundStyle(.white)
            Text(current.text)
                .font(Spook.body(14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button {
                    step = max(0, step - 1)
                } label: {
                    Label("Zurück", systemImage: "chevron.left")
                }
                .disabled(step == 0)
                Spacer()
                Button {
                    step = min(design.steps.count - 1, step + 1)
                } label: {
                    Label(step == design.steps.count - 1 ? "Fertig! 🎉" : "Weiter", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .disabled(step == design.steps.count - 1)
            }
            .font(Spook.title(16))
            .tint(Spook.slime)
            .padding(.top, 2)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.black.opacity(0.65)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Spook.pumpkin.opacity(0.7), lineWidth: 1.5))
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -40 { step = min(design.steps.count - 1, step + 1) }
                if value.translation.width > 40 { step = max(0, step - 1) }
            }
        )
        .animation(.spring(response: 0.3), value: step)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
