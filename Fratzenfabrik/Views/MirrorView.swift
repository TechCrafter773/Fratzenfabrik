import SwiftUI

/// Der Spuk-Spiegel: Mit der Selfie-Kamera klebt die Schminke in 3D am Gesicht (ARKit),
/// mit der Rückkamera liegt sie als 2D-Overlay auf jedem erkannten Gesicht.
struct MirrorView: View {
    enum LiveMode { case ar, camera }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @StateObject private var ar = ARFaceController()

    @State private var design: DesignID
    @State private var stepMode: Bool
    @State private var step: Int
    @State private var opacity: Double = 0.9
    @State private var photo: CapturedPhoto?
    @State private var flash = false
    @State private var shutterCount = 0
    @State private var mode: LiveMode
    @State private var demoKid: Kid
    @State private var demoMouthOpen = false

    init(design: DesignID, stepMode: Bool = false, step: Int = 0, kid: Kid? = nil) {
        _design = State(initialValue: design)
        _stepMode = State(initialValue: stepMode)
        _step = State(initialValue: step)
        _mode = State(initialValue: ARFaceController.isSupported ? .ar : .camera)
        _demoKid = State(initialValue: kid ?? DesignCatalog.design(design).preferredKid)
    }

    private var current: FaceDesign { DesignCatalog.design(design) }
    private var visibleSteps: Int? { stepMode ? step + 1 : nil }
    private var isDemo: Bool { mode == .camera && camera.access == .noCamera }

    private var mouthOpen: Bool {
        switch mode {
        case .ar: ar.mouthOpen
        case .camera: isDemo ? demoMouthOpen : visionMouthOpen
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if mode == .ar {
                arLayer
            } else {
                switch camera.access {
                case .granted: cameraLayer
                case .noCamera: demoLayer
                case .denied: deniedLayer
                case .unknown: ProgressView().tint(Spook.slime)
                }
            }

            controls

            Color.white
                .opacity(flash ? 0.85 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .statusBarHidden()
        .task { await startLive() }
        .onDisappear {
            ar.pause()
            camera.stop()
        }
        .onChange(of: design) { _, _ in
            SpookAudio.shared.play(.whoosh, volume: 0.55)
            updateARPaint()
        }
        .onChange(of: step) { _, _ in
            if stepMode { SpookAudio.shared.play(.sparkle, volume: 0.5) }
            updateARPaint()
        }
        .onChange(of: stepMode) { _, _ in updateARPaint() }
        .onChange(of: opacity) { _, _ in updateARPaint() }
        .sheet(item: $photo) { photo in
            PhotoResultView(photo: photo)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: design)
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .sensoryFeedback(.success, trigger: shutterCount)
        .sensoryFeedback(.impact(weight: .heavy), trigger: mouthOpen)
    }

    // MARK: Live-Modi

    private func startLive() async {
        if mode == .ar {
            updateARPaint()
            ar.run()
        } else {
            await camera.start()
        }
    }

    private func switchCamera() {
        guard ARFaceController.isSupported else {
            camera.flipCamera()
            return
        }
        if mode == .ar {
            ar.pause()
            mode = .camera
            Task { await camera.start() }
        } else {
            camera.stop()
            mode = .ar
            updateARPaint()
            ar.run()
        }
    }

    private func updateARPaint() {
        guard mode == .ar else { return }
        ar.setPaint(DesignTexture.image(design: design, visibleSteps: visibleSteps, kid: nil), opacity: opacity)
    }

    // MARK: Ebenen

    private var arLayer: some View {
        ZStack {
            ARFaceView(controller: ar)
                .ignoresSafeArea()
            MouthEffectLayer(mouth: ar.mouthPoint, open: ar.mouthOpen, emojis: current.mouthEmojis)
                .ignoresSafeArea()
            if ar.failed {
                deniedLayer
            } else if !ar.faceVisible {
                SearchingHint(front: true)
            }
        }
    }

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

            GeometryReader { geo in
                MouthEffectLayer(mouth: visionMouth(in: geo.size), open: visionMouthOpen, emojis: current.mouthEmojis)
            }
            .ignoresSafeArea()

            if camera.faces.isEmpty {
                SearchingHint(front: camera.position == .front)
            }
        }
    }

    /// Mund-Mitte des ersten Gesichts auf dem Bildschirm.
    private func visionMouth(in size: CGSize) -> CGPoint? {
        guard let landmarks = camera.faces.first, !landmarks.outerLips.isEmpty else { return nil }
        let map = camera.previewBridge.mapper(for: camera.orientation)
            ?? aspectFillMapper(imageSize: camera.imageSize, viewSize: size)
        return map(centroid(landmarks.outerLips))
    }

    /// Mund offen = Innenlippen deutlich höher als ein Fünftel der Mundbreite.
    private var visionMouthOpen: Bool {
        guard let landmarks = camera.faces.first, landmarks.innerLips.count >= 3, landmarks.outerLips.count >= 3 else { return false }
        let s = camera.imageSize
        let inner = bounds(landmarks.innerLips.map { CGPoint(x: $0.x * s.width, y: $0.y * s.height) })
        let outer = bounds(landmarks.outerLips.map { CGPoint(x: $0.x * s.width, y: $0.y * s.height) })
        return outer.width > 0 && inner.height / outer.width > 0.2
    }

    private var demoLayer: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 90)
            Text("Keine Kamera gefunden – unser 3D-Probekind springt ein!\nTipp drauf: Mund auf! 😮")
                .font(Spook.scribble(14))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Head3DView(design: design, kid: demoKid, hair: current.hair(for: demoKid), visibleSteps: visibleSteps)
                .opacity(opacity)
                .frame(height: 420)
                .overlay {
                    GeometryReader { geo in
                        MouthEffectLayer(mouth: CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.6),
                                         open: demoMouthOpen, emojis: current.mouthEmojis)
                    }
                }
                .onTapGesture {
                    demoMouthOpen = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { demoMouthOpen = false }
                }
            Picker("Modell", selection: $demoKid) {
                ForEach(Kid.allCases) { Text("\($0.emoji) \($0.label)").tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 60)
            Spacer(minLength: 270)
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

    private var modeLabel: String {
        switch mode {
        case .ar: "✨ 3D-Live · Mund aufreißen! 😮"
        case .camera: isDemo ? "🧒 Probekind" : (camera.position == .front ? "Selfie-Kamera · Mund auf! 😮" : "Rückkamera · Mund auf! 😮")
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(spacing: 8) {
                RoundIconButton(systemName: "xmark") { dismiss() }
                SoundToggle()
            }
            Spacer()
            VStack(spacing: 4) {
                Text("\(current.emoji) \(current.name)")
                    .font(Spook.title(17))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .overlay(Capsule().stroke(current.accent.opacity(0.8), lineWidth: 1.5))
                    .contentTransition(.opacity)
                Text(modeLabel)
                    .font(Spook.body(11, weight: .heavy))
                    .foregroundStyle(Spook.slime)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.45)))
            }
            Spacer()
            if mode == .ar || camera.access == .granted {
                RoundIconButton(systemName: "arrow.triangle.2.circlepath.camera") { switchCamera() }
                    .accessibilityLabel(mode == .ar ? "Zur Rückkamera wechseln" : "Kamera wechseln")
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
                                    .minimumScaleFactor(0.6)
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
        SpookAudio.shared.play(.creak, volume: 0.7)

        let design = design, steps = visibleSteps, opacity = opacity
        switch mode {
        case .ar:
            if let result = PhotoComposer.watermarked(ar.snapshot()) {
                shutterCount += 1
                photo = CapturedPhoto(image: result)
            }
        case .camera where camera.access == .granted:
            camera.capture { image, faces in
                if let result = PhotoComposer.compose(image: image, faces: faces, design: design,
                                                      visibleSteps: steps, opacity: opacity) {
                    shutterCount += 1
                    photo = CapturedPhoto(image: result)
                }
            }
        case .camera:
            if let result = PhotoComposer.composeDemo(design: design, kid: demoKid, visibleSteps: steps) {
                shutterCount += 1
                photo = CapturedPhoto(image: result)
            }
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
