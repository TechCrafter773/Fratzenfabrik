import SwiftUI

struct DesignDetailView: View {
    let design: FaceDesign
    /// `nil` zeigt das fertige Design, sonst bis einschließlich diesem Schritt.
    @State private var selectedStep: Int?
    @State private var mirror: MirrorLaunch?
    @State private var kid: Kid
    @State private var turn: TurnRequest?

    init(design: FaceDesign, initialKid: Kid) {
        self.design = design
        _kid = State(initialValue: initialKid)
    }

    private var hair: HairSuggestion { design.hair(for: kid) }

    var body: some View {
        ZStack {
            SpookyBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    preview
                    hairCard
                    infoChips
                    materials
                    stepsList
                    tipCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) { liveButtons }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(item: $mirror) { launch in
            MirrorView(design: launch.design, stepMode: launch.stepMode, step: selectedStep ?? 0, kid: kid)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(design.emoji).font(.system(size: 40)).wobble(8, speed: 2.5)
                Text(design.name)
                    .font(Spook.title(32))
                    .foregroundStyle(design.accent)
                    .glow(design.accent, radius: 8)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
            }
            Text(design.tagline)
                .font(Spook.scribble(15))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var preview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ForEach(Kid.allCases) { option in
                    KidChip(title: "\(option.emoji) \(option.label)",
                            color: option == .girl ? Spook.candy : Spook.lightBlueAccent,
                            selected: kid == option) { kid = option }
                }
            }

            ZStack(alignment: .bottom) {
                Circle()
                    .fill(RadialGradient(colors: [design.accent.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 200))
                Head3DView(design: design.id, kid: kid, hair: hair,
                           visibleSteps: selectedStep.map { $0 + 1 }, turn: turn)
                HStack(spacing: 10) {
                    turnButton("↶ Seite", yaw: 1.25)
                    turnButton("Vorne", yaw: 0)
                    turnButton("Seite ↷", yaw: -1.25)
                }
                .padding(.bottom, 6)
            }
            .frame(height: 420)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topTrailing) {
                Text("👆 wischen zum Drehen")
                    .font(Spook.body(11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.black.opacity(0.35)))
            }

            Text(selectedStep.map { "Schritt \($0 + 1): \(design.steps[$0].title)" } ?? "So sieht’s fertig aus ✨")
                .font(Spook.title(17))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            HStack(spacing: 8) {
                ForEach(design.steps) { step in
                    stepDot(label: "\(step.id + 1)", selected: selectedStep == step.id) { selectedStep = step.id }
                }
                stepDot(label: "✓", selected: selectedStep == nil) { selectedStep = nil }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedStep)
    }

    private func turnButton(_ title: String, yaw: Float) -> some View {
        Button {
            turn = TurnRequest(yaw: yaw)
        } label: {
            Text(title)
                .font(Spook.body(13, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.black.opacity(0.5)))
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var hairCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💇").font(.system(size: 30)).wobble(8, speed: 2.5)
            VStack(alignment: .leading, spacing: 4) {
                Text("Frisur-Idee für \(kid == .girl ? "Mädchen" : "Jungs"): \(hair.title)")
                    .font(Spook.title(17))
                    .foregroundStyle(kid == .girl ? Spook.candy : Spook.lightBlueAccent)
                Text(hair.tip)
                    .font(Spook.body(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Das andere Modell oben zeigt die Frisur für \(kid == .girl ? "Jungs" : "Mädchen").")
                    .font(Spook.body(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke((kid == .girl ? Spook.candy : Spook.lightBlueAccent).opacity(0.5), lineWidth: 1.5))
        .animation(.easeInOut, value: kid)
    }

    private func stepDot(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Spook.title(16))
                .frame(width: 38, height: 38)
                .foregroundStyle(selected ? Spook.night : .white)
                .background(Circle().fill(selected ? Spook.slime : Color.white.opacity(0.12)))
                .overlay(Circle().stroke(Spook.slime.opacity(0.6), lineWidth: selected ? 0 : 1.5))
                .scaleEffect(selected ? 1.15 : 1)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var infoChips: some View {
        HStack(spacing: 10) {
            InfoChip(icon: "⏱️", text: "ca. \(design.minutes) Min")
            InfoChip(icon: design.difficulty.pumpkins, text: design.difficulty.label)
            InfoChip(icon: "🖌️", text: "\(design.steps.count) Schritte")
        }
    }

    private var materials: some View {
        SpookySection(title: "🎨 Das brauchst du") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(design.colors) { paint in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(paint.color)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                        Text(paint.name).font(Spook.body(14))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(design.tools, id: \.self) { tool in
                    Label(tool, systemImage: "paintbrush.pointed.fill")
                        .font(Spook.body(14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.top, 4)
        }
    }

    private var stepsList: some View {
        SpookySection(title: "🪄 Schritt für Schritt") {
            ForEach(design.steps) { step in
                Button {
                    selectedStep = step.id
                } label: {
                    StepRow(step: step, selected: selectedStep == step.id, accent: design.accent)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💡").font(.system(size: 30)).wobble(10, speed: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Profi-Trick").font(Spook.title(17)).foregroundStyle(Spook.moon)
                Text(design.tip).font(Spook.body(14, weight: .medium)).foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Spook.moon.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Spook.moon.opacity(0.5), lineWidth: 1.5))
    }

    private var liveButtons: some View {
        HStack(spacing: 12) {
            Button {
                mirror = MirrorLaunch(design: design.id, stepMode: false)
            } label: {
                Label("Live ansehen", systemImage: "camera.fill")
                    .font(Spook.title(16))
            }
            .buttonStyle(SlimeButtonStyle())

            Button {
                mirror = MirrorLaunch(design: design.id, stepMode: true)
            } label: {
                Label("Live-Anleitung", systemImage: "wand.and.stars")
                    .font(Spook.title(16))
            }
            .buttonStyle(SlimeButtonStyle(color: Spook.pumpkin))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            LinearGradient(colors: [.clear, Spook.night.opacity(0.95)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 2) {
            Text(icon).font(.system(size: 16))
            Text(text).font(Spook.body(12, weight: .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08)))
    }
}

struct SpookySection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Spook.title(22)).foregroundStyle(Spook.slime)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.35)))
    }
}

struct StepRow: View {
    let step: PaintStep
    let selected: Bool
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.id + 1)")
                .font(Spook.title(20))
                .foregroundStyle(Spook.night)
                .frame(width: 40, height: 40)
                .background(SlimeBlob(drips: [0.3, 0.7], dripLength: 6).fill(selected ? Spook.slime : Spook.pumpkin))
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(Spook.title(17)).foregroundStyle(.white)
                Text(step.text).font(Spook.body(14, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Label(step.tool, systemImage: "paintbrush")
                    .font(Spook.body(12, weight: .bold))
                    .foregroundStyle(accent)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? Spook.slime.opacity(0.14) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? Spook.slime : .clear, lineWidth: 1.5)
        )
    }
}
