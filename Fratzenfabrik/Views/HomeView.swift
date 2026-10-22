import SwiftUI

struct HomeView: View {
    @State private var filter: Difficulty?
    @State private var kidFilter: Kid?
    @State private var mirror: MirrorLaunch?

    private var designs: [FaceDesign] {
        DesignCatalog.all.filter {
            (filter == nil || $0.difficulty == filter) && (kidFilter == nil || $0.kids.contains(kidFilter!))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                SpookyBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        FratzenLogo(size: 58)
                            .padding(.top, 70)

                        Text("Gruselig einfache Kinderschminke –\nzum Nachmalen & live Anprobieren!")
                            .font(Spook.scribble(15))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Spook.ghost.opacity(0.85))
                            .rotationEffect(.degrees(-1.5))

                        VStack(spacing: 10) {
                            Button {
                                mirror = MirrorLaunch(design: designs.randomElement()?.id ?? .ghostCute)
                            } label: {
                                Label("Spuk-Spiegel starten", systemImage: "camera.fill")
                            }
                            .buttonStyle(SlimeButtonStyle())

                            Text("Kamera aufs Kind halten und alle Fratzen live anprobieren 👀")
                                .font(Spook.body(13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 6)

                        filterBar

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                            ForEach(Array(designs.enumerated()), id: \.element.id) { index, design in
                                NavigationLink(value: design) {
                                    DesignCard(design: design, kid: kidFilter ?? design.preferredKid,
                                               tilt: index.isMultiple(of: 2) ? -1.8 : 1.6)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: filter)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: kidFilter)

                        SafetyCard()

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)

                DrippingSlime(height: 22)
                    .frame(height: 90)
                    .ignoresSafeArea(edges: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: FaceDesign.self) { design in
                DesignDetailView(design: design, initialKid: kidFilter ?? design.preferredKid)
            }
        }
        .fullScreenCover(item: $mirror) { launch in
            MirrorView(design: launch.design, stepMode: launch.stepMode)
        }
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                KidChip(title: "🍬 Alle", color: Spook.slime, selected: kidFilter == nil) { kidFilter = nil }
                KidChip(title: "👧 Mädchen", color: Spook.candy, selected: kidFilter == .girl) {
                    kidFilter = kidFilter == .girl ? nil : .girl
                }
                KidChip(title: "👦 Jungs", color: Spook.lightBlueAccent, selected: kidFilter == .boy) {
                    kidFilter = kidFilter == .boy ? nil : .boy
                }
            }
            difficultyBar
        }
    }

    private var difficultyBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                FilterChip(title: "Alle Stufen", selected: filter == nil) { filter = nil }
                ForEach(Difficulty.allCases) { level in
                    FilterChip(title: "\(level.pumpkins) \(level.label)", selected: filter == level) {
                        filter = filter == level ? nil : level
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}

/// Großer Mädchen/Jungs-Umschalter.
struct KidChip: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Spook.title(16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(selected ? Spook.night : .white)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selected ? color : Color.white.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(selected ? 0 : 0.6), lineWidth: 2))
                .glow(selected ? color : .clear, radius: 8)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Spook.body(14, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(selected ? Spook.night : .white)
                .background(Capsule().fill(selected ? Spook.pumpkin : Color.white.opacity(0.1)))
                .overlay(Capsule().stroke(Spook.pumpkin.opacity(selected ? 0 : 0.5), lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct DesignCard: View {
    let design: FaceDesign
    let kid: Kid
    var tilt: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                KidThumbnail(design: design, kid: kid)
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(design.emoji)
                    .font(.system(size: 30))
                    .rotationEffect(.degrees(14))
                    .offset(x: 6, y: -6)
            }
            Text(design.name)
                .font(Spook.title(17))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack {
                Text(design.difficulty.pumpkins).font(.system(size: 12))
                Spacer()
                Label("\(design.minutes) Min", systemImage: "timer")
                    .font(Spook.body(12, weight: .bold))
                    .foregroundStyle(Spook.moon)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Spook.grape, Spook.plum.opacity(0.95)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(design.accent.opacity(0.75), lineWidth: 2)
        )
        .shadow(color: design.accent.opacity(0.35), radius: 12)
        .rotationEffect(.degrees(tilt))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(design.name), \(design.difficulty.label), \(design.minutes) Minuten")
    }
}

struct SafetyCard: View {
    private let rules = [
        ("🧴", "Nur echte Kinderschminke auf Wasserbasis – niemals Bastel- oder Acrylfarbe."),
        ("✋", "Vorher einen Klecks am Handgelenk testen, ob die Haut ihn mag."),
        ("👁️", "Nicht direkt ins Auge oder auf wunde Haut malen."),
        ("✨", "Nur kosmetischen Glitzer verwenden, nie Bastelglitzer."),
        ("🛑", "Das Kind darf jederzeit „Stopp!“ rufen – dann ist Gruselpause."),
        ("🧼", "Abschminken mit lauwarmem Wasser, milder Seife oder etwas Babyöl."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("☠️ Spuk-Sicherheitsregeln")
                .font(Spook.title(22))
                .foregroundStyle(Spook.pumpkin)
            ForEach(rules.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    Text(rules[index].0).font(.system(size: 20))
                    Text(rules[index].1).font(Spook.body(14, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                }
            }
            Divider().overlay(Spook.pumpkin.opacity(0.4))
            Text("🛒 Grundausstattung")
                .font(Spook.title(18))
                .foregroundStyle(Spook.slime)
            Text("Schminkpalette (Weiß, Schwarz, Orange, Grün, Lila, Rot), 2 Schwämmchen, ein dicker und ein feiner Pinsel, Wasserbecher, Wattestäbchen, Feuchttücher.")
                .font(Spook.body(14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.35)))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Spook.pumpkin.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
        )
        .padding(.top, 10)
    }
}
