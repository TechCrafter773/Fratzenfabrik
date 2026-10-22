import SwiftUI

/// Alle Schmink-Ideen. Die Anzahl der Schritte muss zu den Ebenen in `FacePainter` passen.
enum DesignCatalog {
    static let all: [FaceDesign] = [ghost, cat, pumpkin, witch, spiderweb, bat, vampire, skeleton, frankenstein]

    static func design(_ id: DesignID) -> FaceDesign { all.first { $0.id == id }! }

    static let ghost = FaceDesign(
        id: .ghost,
        name: "Kleines Gespenst",
        emoji: "👻",
        tagline: "Buuuh! Der Klassiker – schneller geht Gruseln nicht.",
        difficulty: .superEasy,
        minutes: 10,
        accent: Spook.ghost,
        colors: [Paint.white, Paint.black, Paint.grey],
        tools: ["Schminkschwamm", "Dicker Pinsel", "Wattestäbchen"],
        tip: "Die weiße Farbe lieber in zwei dünnen Schichten auftragen statt einer dicken – dann bröckelt nichts.",
        steps: .steps([
            ("Weiß grundieren",
             "Schwamm leicht anfeuchten, in die weiße Farbe tupfen und das ganze Gesicht betupfen. Augen und Haaransatz aussparen.",
             "Schwamm"),
            ("Riesige Augenhöhlen",
             "Mit dem dicken Pinsel große, nach unten hängende schwarze Ovale um die Augen malen – wie traurige Gespensteraugen. Die Lider nur ganz vorsichtig.",
             "Dicker Pinsel"),
            ("Buuuh-Mund",
             "Ein schwarzes, langgezogenes O über den Mund malen. Das Kind darf dabei ‚Buuuh‘ sagen!",
             "Dicker Pinsel"),
            ("Geisterschatten",
             "Etwas Grau unter die Wangenknochen tupfen und verwischen. Schon schwebt das Gespenst!",
             "Wattestäbchen"),
        ])
    )

    static let cat = FaceDesign(
        id: .cat,
        name: "Schwarze Katze",
        emoji: "🐱",
        tagline: "Miau in 5 Minuten. Perfekt für Zappelkinder.",
        difficulty: .superEasy,
        minutes: 5,
        accent: Spook.candy,
        colors: [Paint.white, Paint.black, Paint.pink],
        tools: ["Feiner Pinsel", "Schwamm (optional)"],
        tip: "Schnurrhaare mit Schwung von innen nach außen malen und am Ende den Pinsel anheben – so werden sie spitz.",
        steps: .steps([
            ("Weiße Schnäuzchen-Bäckchen",
             "Zwei weiße Kreise links und rechts über die Oberlippe tupfen. Das ist die Katzenschnauze.",
             "Schwamm"),
            ("Katzennäschen",
             "Die Nasenspitze rosa oder schwarz anmalen – ein kleines Dreieck mit runden Ecken. Dann einen Strich runter zur Oberlippe.",
             "Feiner Pinsel"),
            ("Schnurrhaare & Punkte",
             "Auf jede Seite drei geschwungene Schnurrhaare malen und ein paar schwarze Pünktchen auf die weißen Bäckchen.",
             "Feiner Pinsel"),
            ("Katzenaugen",
             "Vom äußeren Augenwinkel einen kleinen Strich schräg nach oben ziehen – fertig ist der Katzenblick.",
             "Feiner Pinsel"),
        ])
    )

    static let pumpkin = FaceDesign(
        id: .pumpkin,
        name: "Grinsekürbis",
        emoji: "🎃",
        tagline: "Leuchtet orange und grinst bis zu den Ohren.",
        difficulty: .easy,
        minutes: 15,
        accent: Spook.pumpkin,
        colors: [Paint.orange, Paint.darkOrange, Paint.black, Paint.green, Paint.yellow],
        tools: ["Schminkschwamm", "Dicker Pinsel", "Feiner Pinsel"],
        tip: "Erst das Orange gut trocknen lassen (Föhn auf kalt hilft!), sonst verschmiert das Schwarz.",
        steps: .steps([
            ("Orange grundieren",
             "Mit dem Schwamm das ganze Gesicht orange betupfen. Augen frei lassen.",
             "Schwamm"),
            ("Kürbisrillen",
             "Mit Dunkelorange vier gebogene Linien von der Stirn bis zum Kinn malen – wie die Rillen eines Kürbisses.",
             "Dicker Pinsel"),
            ("Dreiecksaugen & Nase",
             "Schwarze Dreiecke um die Augen malen (Spitze zeigt nach oben) und ein kleines Dreieck auf die Nase.",
             "Dicker Pinsel"),
            ("Zackengrinsen",
             "Ein breites, schwarzes Grinsen mit Zacken oben über den Mund malen – von Wange zu Wange.",
             "Dicker Pinsel"),
            ("Stiel & Glanzpunkte",
             "Oben auf die Stirn einen grünen Stiel mit Ringelranke malen. Ein paar gelbe Glanzpunkte auf die Wangen.",
             "Feiner Pinsel"),
        ])
    )

    static let witch = FaceDesign(
        id: .witch,
        name: "Kleine Hexe",
        emoji: "🧙",
        tagline: "Hex-hex! Mit Warze, Sternen und Zauberspirale.",
        difficulty: .superEasy,
        minutes: 10,
        accent: Spook.slime,
        colors: [Paint.paleGreen, Paint.purple, Paint.black, Paint.brown, Paint.glitter],
        tools: ["Schminkschwamm", "Feiner Pinsel", "Glitzergel"],
        tip: "Hellgrün nur ganz dünn auftupfen – dann sieht es nach Zaubertrank aus und nicht nach Frosch.",
        steps: .steps([
            ("Hexengrün",
             "Das Gesicht dünn mit hellgrüner Farbe betupfen. Lippen und Augen auslassen.",
             "Schwamm"),
            ("Lila Zauberlider",
             "Lila Farbe auf die Lider und bis zu den Augenbrauen tupfen und weich verwischen.",
             "Schwamm"),
            ("Spirale & Sterne",
             "Eine lila Zauberspirale auf eine Wange malen, auf die andere zwei kleine Sterne.",
             "Feiner Pinsel"),
            ("Warze & Lippen",
             "Eine braune Warze neben die Nase tupfen und die Lippen dunkellila anmalen. Glitzer drauf – hex-hex!",
             "Feiner Pinsel"),
        ])
    )

    static let spiderweb = FaceDesign(
        id: .spiderweb,
        name: "Spinnennetz",
        emoji: "🕸️",
        tagline: "Nur schwarze Farbe – und eine fiese kleine Spinne.",
        difficulty: .easy,
        minutes: 10,
        accent: Spook.violet,
        colors: [Paint.black, Paint.glitter],
        tools: ["Feiner Pinsel", "Glitzergel (optional)"],
        tip: "Die Fäden zwischen den Speichen immer leicht nach innen durchhängen lassen – so sieht es echt aus.",
        steps: .steps([
            ("Speichen",
             "Vom äußeren Augenwinkel aus sieben gerade Linien wie Sonnenstrahlen über Schläfe, Stirn und Wange ziehen.",
             "Feiner Pinsel"),
            ("Fäden",
             "Die Speichen mit durchhängenden Bögen verbinden. Vier Runden – von innen nach außen.",
             "Feiner Pinsel"),
            ("Kleine Spinne",
             "Auf die andere Wange einen dicken Punkt als Körper, einen kleinen als Kopf und acht geknickte Beine malen.",
             "Feiner Pinsel"),
            ("Tautropfen-Glitzer",
             "Ein paar Glitzerpunkte auf das Netz setzen, als hätte der Nebel Tautropfen hinterlassen.",
             "Glitzergel"),
        ])
    )

    static let bat = FaceDesign(
        id: .bat,
        name: "Fledermaus-Maske",
        emoji: "🦇",
        tagline: "Flatter-Maske über den Augen. Superheld, aber gruselig.",
        difficulty: .easy,
        minutes: 10,
        accent: Spook.violet,
        colors: [Paint.purple, Paint.black, Paint.white],
        tools: ["Schwamm", "Dicker Pinsel", "Feiner Pinsel"],
        tip: "Die Flügel zuerst mit Lila vorzeichnen – Lila verzeiht Fehler, Schwarz nicht.",
        steps: .steps([
            ("Lila Schimmer",
             "Rund um die Augen eine lila Maskenform auftupfen und die Ränder weich auslaufen lassen.",
             "Schwamm"),
            ("Fledermausflügel",
             "Auf der Nasenwurzel den Körper mit zwei Ohren malen, dann die Flügel über die Augenbrauen bis zu den Schläfen. Die Unterkante in Bögen malen.",
             "Dicker Pinsel"),
            ("Weiße Details",
             "Zwei weiße Pünktchen als Fledermaus-Augen und feine weiße Linien in die Flügel.",
             "Feiner Pinsel"),
        ])
    )

    static let vampire = FaceDesign(
        id: .vampire,
        name: "Mini-Vampir",
        emoji: "🧛",
        tagline: "Blass, edel und mit Zähnchen. Bluuut? Nur Ketchup!",
        difficulty: .easy,
        minutes: 15,
        accent: Spook.blood,
        colors: [Paint.white, Paint.purple, Paint.black, Paint.red],
        tools: ["Schwamm", "Feiner Pinsel", "Wattestäbchen"],
        tip: "Die Vampirzähne direkt unter die Mundwinkel malen – dann sehen sie auch bei geschlossenem Mund echt aus.",
        steps: .steps([
            ("Blasse Haut",
             "Ganz dünn Weiß auf das Gesicht tupfen. Es soll noch etwas Haut durchschimmern.",
             "Schwamm"),
            ("Müde Vampiraugen",
             "Mit dem Wattestäbchen etwas Lila unter die Augen und auf die Lider reiben.",
             "Wattestäbchen"),
            ("Spitzer Haaransatz",
             "Mitten auf der Stirn ein schwarzes, nach unten zeigendes V an den Haaransatz malen.",
             "Feiner Pinsel"),
            ("Rote Lippen",
             "Die Lippen kräftig rot ausmalen.",
             "Feiner Pinsel"),
            ("Zähnchen & Tropfen",
             "Unter jeden Mundwinkel einen weißen Zahn mit schwarzer Kontur. Ein kleiner roter Tropfen darunter – fertig.",
             "Feiner Pinsel"),
        ])
    )

    static let skeleton = FaceDesign(
        id: .skeleton,
        name: "Klapperskelett",
        emoji: "💀",
        tagline: "Knochenhart und megacool. Klapper, klapper!",
        difficulty: .medium,
        minutes: 20,
        accent: Spook.ghost,
        colors: [Paint.white, Paint.black, Paint.grey],
        tools: ["Schwamm", "Dicker Pinsel", "Feiner Pinsel"],
        tip: "Für die Zähne zuerst den langen Strich, dann die kurzen Querstriche – immer von der Mitte nach außen.",
        steps: .steps([
            ("Weiß grundieren",
             "Das ganze Gesicht weiß betupfen, die Augen frei lassen.",
             "Schwamm"),
            ("Augenhöhlen",
             "Große, runde schwarze Kreise um die Augen malen – die Augenbrauen gehören mit dazu.",
             "Dicker Pinsel"),
            ("Herz-Nase",
             "Auf die Nasenspitze ein schwarzes, auf dem Kopf stehendes Herz malen.",
             "Feiner Pinsel"),
            ("Klapperzähne",
             "Einen langen schwarzen Strich über die Lippen bis in die Wangen ziehen und mit kurzen Querstrichen Zähne malen.",
             "Feiner Pinsel"),
            ("Knochenschatten",
             "Grau unter die Wangenknochen tupfen, damit das Gesicht schön hohl wirkt.",
             "Schwamm"),
        ])
    )

    static let frankenstein = FaceDesign(
        id: .frankenstein,
        name: "Frankis Monster",
        emoji: "🧟",
        tagline: "Grün, genäht und total verschraubt.",
        difficulty: .medium,
        minutes: 20,
        accent: Spook.slime,
        colors: [Paint.green, Paint.darkGreen, Paint.black, Paint.red, Paint.grey],
        tools: ["Schwamm", "Dicker Pinsel", "Feiner Pinsel"],
        tip: "Die Stiche der Narbe als kleine Kreuze malen – das sieht genäht aus und geht ganz schnell.",
        steps: .steps([
            ("Monstergrün",
             "Das ganze Gesicht kräftig grün betupfen.",
             "Schwamm"),
            ("Eckiger Pony",
             "Am Haaransatz einen schwarzen, gezackten Pony quer über die Stirn malen.",
             "Dicker Pinsel"),
            ("Narbe mit Stichen",
             "Eine rote Linie schräg über die Stirn malen und mit schwarzen Kreuzchen ‚zunähen‘.",
             "Feiner Pinsel"),
            ("Schatten & Lippen",
             "Dunkelgrün unter die Augen und in die Wangen tupfen, die Lippen dunkelgrau anmalen.",
             "Schwamm"),
            ("Schrauben",
             "Links und rechts unten am Kiefer je eine graue Schraube mit schwarzer Kontur malen.",
             "Feiner Pinsel"),
        ])
    )
}
