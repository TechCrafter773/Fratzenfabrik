# 🎃 Fratzenfabrik

Halloween-Kinderschminke zum Nachmalen – und live auf dem Gesicht anprobieren.

## Was die App kann

- **17 Designs**: drei Gespenster (süß, lustig, super gruselig), Katze, Zyklop, Kürbis, Hexe, Feuerteufel, Mumie, Spinnennetz, Fledermaus, Fledermaus-Schwarm, Vampir, Werwolf, Skelett, Zuckerschädel und Frankenstein.
- **Mädchen und Jungs**: Auf der Startseite lässt sich nach Mädchen oder Jungs filtern. Jedes Design hat einen Frisur-Vorschlag für Mädchen und einen für Jungs.
- **3D-Kinder**: Die Vorschau zeigt modellierte 3D-Köpfe (SceneKit) mit Frisur und Accessoires (Hexenhut, Katzenohren, Hörner, Schleife, Blumenkranz). Sie lassen sich per Wischen oder Knopf drehen und von der Seite ansehen. Die Schminke wird als Textur aufgemalt und baut sich Schritt für Schritt auf.
- **Spuk-Spiegel live**:
  - **Selfie-Kamera mit Face ID**: echtes 3D über ARKit. Das Gesichtsnetz wird bemalt, und die Schminke bewegt sich beim Drehen des Kopfes mit.
  - **Rückkamera**: 2D-Overlay über die Vision-Gesichtserkennung, auch bei mehreren Kindern gleichzeitig.
- **Spuk-Sounds und Mund-auf-Effekt**: Reißt das Kind den Mund auf, fliegen Geister, Fledermäuse, Flammen oder anderes heraus, und die Fratze ruft etwas („Buuuh!“, „Miau!“, „Auuuuh!“). Beim Fratzen-Wechsel gibt es ein Rauschen, beim Foto ein Türknarzen. Über den Lautsprecher-Knopf lässt sich der Ton ausschalten.
- Mit dem Auslöser entsteht ein Foto inklusive Schminke, das man speichern oder teilen kann.

## Bauen

- Xcode 16 oder neuer, iOS 17+
- `Fratzenfabrik.xcodeproj` öffnen → unter *Signing & Capabilities* dein Team wählen → auf dem iPhone starten.
- Bundle ID: `com.techcrafter773.fratzenfabrik` (bei Bedarf in den Build Settings ändern)

Alles läuft lokal auf dem Gerät. Es gibt keinen Server, kein Tracking und keine Uploads.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `App/` | App-Einstieg |
| `Theme/` | Farben, Schleim-Tropfen, Spuk-Hintergrund, Logo |
| `Models/` | Designs & Anleitungen (`DesignCatalog.swift`) |
| `Painting/` | Gesichtsgeometrie, Pinsel-Helfer, Designs als Ebenen (`FacePainter.swift`), Textur-Rendering |
| `ThreeD/` | 3D-Kopf, Frisuren & Accessoires, drehbare Ansicht, Vorschaubilder |
| `Effects/` | Spuk-Sounds, Mund-auf-Partikel |
| `Sounds/` | Effekt-Sounds (WAV) |
| `Camera/` | ARKit-3D (Selfie), AVFoundation + Vision (Rückkamera) |
| `Views/` | Startseite, Detailseite, Spuk-Spiegel, Foto-Ergebnis |

**Neues Design hinzufügen:** Füge in `DesignID` einen Fall hinzu, lege in `DesignCatalog` den Eintrag mit den Schritten an und in `FacePainter` die passende Anzahl Ebenen. Gezeichnet wird im „Gesichtsraum“: Die Augen liegen bei (±0,5 | 0), der Mund bei etwa (0 | 1,05), das Kinn bei etwa (0 | 1,8).

## TestFlight über GitHub Actions

Die App wird komplett in der Cloud gebaut, auf macOS-Runnern von GitHub:

- **Build** (`.github/workflows/build.yml`): kompiliert bei jedem Push für den Simulator.
- **TestFlight** (`.github/workflows/testflight.yml`): archiviert die App, signiert sie per Apple-Cloud-Signatur (kein Zertifikat nötig) und lädt sie zu TestFlight hoch. Starten über *Actions → TestFlight → Run workflow*. Bei Push auf `main` läuft er automatisch. Die Build-Nummer ist die Laufnummer des Workflows.

Benötigte Repository-Secrets (*Settings → Secrets and variables → Actions*):

| Secret | Inhalt |
|---|---|
| `APPLE_TEAM_ID` | 10-stellige Team-ID (developer.apple.com → Membership) |
| `APP_STORE_CONNECT_KEY_ID` | Key-ID des API-Schlüssels |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer-ID (steht über der Schlüsselliste) |
| `APP_STORE_CONNECT_KEY_P8` | Inhalt der `.p8`-Datei (roh oder base64) |

Der API-Schlüssel braucht die Rolle **Admin**, damit Apple das Verteilungszertifikat in der Cloud verwalten darf.
