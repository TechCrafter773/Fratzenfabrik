# 🎃 Fratzenfabrik

Halloween-Kinderschminke zum Nachmalen – und live auf dem Gesicht anprobieren.

## Was die App kann

- **9 einfache Designs**: Gespenst, Katze, Kürbis, Hexe, Spinnennetz, Fledermaus, Vampir, Skelett, Frankenstein
- **Schritt-für-Schritt-Anleitungen** mit Farben, Werkzeug und Profi-Tipps. Die Vorschau auf dem Probe-Kind baut sich Schritt für Schritt auf.
- **Spuk-Spiegel (Live-Kamera)**: Die Kamera (hinten oder vorne) erkennt Gesichter mit Apples Vision-Framework und legt die Schminke live darüber, bei bis zu 4 Kindern gleichzeitig.
  - Mit dem Karussell wechselst du die Designs, mit dem Würfel kommt ein zufälliges.
  - Im **Schritt-Modus** erscheint auf dem echten Gesicht nur das, was bis zum aktuellen Schritt gemalt ist. Der aktuelle Schritt pulsiert.
  - Mit dem Regler stellst du die Deckkraft ein. Mit dem Auslöser machst du ein Foto inkl. Schminke und kannst es speichern oder teilen.
- Ohne Kamera (z. B. im Simulator) springt das gezeichnete Probe-Kind ein.

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
| `Painting/` | Gesichtsgeometrie, Pinsel-Helfer, die Designs als Ebenen (`FacePainter.swift`), Probe-Kind |
| `Camera/` | AVFoundation-Session + Vision-Gesichtserkennung |
| `Views/` | Startseite, Detailseite, Spuk-Spiegel, Foto-Ergebnis |

**Neues Design hinzufügen:** Füge in `DesignID` einen Fall hinzu, lege in `DesignCatalog` den Eintrag mit den Schritten an und in `FacePainter` die passende Anzahl Ebenen. Gezeichnet wird im „Gesichtsraum“: Die Augen liegen bei (±0,5 | 0), der Mund bei etwa (0 | 1,05), das Kinn bei etwa (0 | 1,8).
