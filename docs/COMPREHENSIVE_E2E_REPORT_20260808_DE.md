# Kanto Ascendant 6.0.8 – verständliche Änderungs- und E2E-Dokumentation

Stand: 8. August 2026
Interne Prüfreferenz: `KA-INTERNAL: RELEASE-BASELINE-001`

## Ergebnis in einem Satz

Der aktuelle Stand ist in Rot, Blau und Gelb vollständig gestartet worden. Die
Follower-, Rematch-, Schwierigkeits-, Menü-, Gorochu- und Konfliktfunktionen
haben ihre Einzelprüfungen bestanden. Zusätzlich wurde ein erzeugter
Rot-Spielstand manuell über den Launcher geladen, im Feld bedient und das
Ascendant-Menü mit echter Tastatureingabe geöffnet und wieder geschlossen.

## Was sich für Spieler geändert hat

### 1. Eigene Follower statt Abhängigkeit von Followers EX

- Kanto Ascendant besitzt jetzt selbst einen Follower-Controller.
- Ein bis vier Pokémon können gleichzeitig folgen.
- Die Kette läuft wirklich hintereinander: Pokémon 2 folgt Pokémon 1,
  Pokémon 3 folgt Pokémon 2 und so weiter.
- Kurven, Kartenränder, Häuser, Höhlen, Fahrrad, Entwicklungen, Teamwechsel
  und Boxtransfer werden berücksichtigt.
- Rot und Blau verwenden standardmäßig das erste gesunde Team-Pokémon.
- Gelbs besonderes Partner-Pikachu bleibt geschützt und wird nicht doppelt
  gezeichnet.

![Vier Follower in Rot](../qa/comprehensive_e2e_20260808/followers/red-final-chain.png)

### 2. Vollständige Follower-Sprite-Abdeckung

- Für alle 151 Kanto-Pokémon und 100 Johto-Pokémon sind normale und schillernde
  Follower-Pfade vorhanden.
- Gorochu ist als eigene Art registriert.
- Die Registry kann weitere eigene Arten aufnehmen, ohne ein falsches
  Standard-Pokémon anzuzeigen.
- Das System funktioniert ohne installierte Followers-EX-Mod.

### 3. Frei konfigurierbare Begleiter

- In den Optionen lässt sich die Anzahl auf 1 bis 4 stellen.
- `PARTY` folgt automatisch der Teamreihenfolge.
- `CUSTOM` erlaubt eine eigene Auswahl und Reihenfolge.
- Die Auswahl speichert stabile Pokémon-Identitäten. Sie bleibt deshalb nach
  Entwicklung, Umordnung, Boxtransfer und komplettem Neustart erhalten.
- Gelb bietet für Raichu sowohl die Ascendant-Darstellung als auch die
  klassische zentrierte Partnerbox.

![Geladene individuelle Viererkette in Gelb](../qa/comprehensive_e2e_20260808/followers/yellow-reloaded-custom.png)

![Raichu im Ascendant-Stil](../qa/comprehensive_e2e_20260808/followers/yellow-raichu-ascendant-box.png)

![Raichu klassisch zentriert](../qa/comprehensive_e2e_20260808/followers/yellow-raichu-centered-box.png)

### 4. Rematch 2.0

- Jeder Trainer besitzt einen eigenen, dauerhaft gespeicherten Fortschritt.
- Nur ein Sieg erhöht den Fortschritt.
- Die ursprünglichen Pokémon bleiben die Grundlage; später kommen passende
  Verstärkungen aus Klassen-Pools hinzu.
- Entwicklungen, neue Teammitglieder und die letzten Auswahlen werden
  nachvollziehbar und begrenzt gespeichert.
- Die Anti-Wiederholungslogik verhindert monotone Teams, ohne bei kleinen
  legalen Pools festzuhängen.
- Johto-Pokémon und stärkere Taktiken werden erst über die vorgesehenen
  Fortschrittsstufen freigeschaltet.

### 5. Fortschritt nach Level 100

- Das sichtbare und gespeicherte Level bleibt strikt bei 100 gedeckelt.
- Weitere Siege verbessern stattdessen begrenzt DV, Stat-EP und
  Attackenqualität.
- Rollen, STAB, Coverage, Status, Setup, Heilung und taktische Sets fließen in
  die Attackenauswahl ein.
- Top Vier und Champ benutzen denselben gedeckelten Mastery-Unterbau mit
  passenden Zusatzregeln.

### 6. Rematch-Belohnungen, EP-Teiler und EP-Multiplikator

- Rematches besitzen gestaffelte Item- und Geldbelohnungen.
- Der Meisterball ist aus normalen Belohnungen ausgeschlossen.
- Reservierte Belohnungen werden bei voller Tasche zusammengeführt und auf
  sichere Mengen begrenzt.
- Der EP-Teiler unterstützt `AUS`, `KLASSISCH` und `TEAM`.
- Der EP-Multiplikator schaltet ×2, ×3 und ×5 nacheinander frei, ohne die
  aktive Einstellung heimlich zu ändern.
- Freischaltungen, aktive Einstellung und PC-Lagerung überleben einen
  Neustart.

### 7. Schwierigkeit und Core-QoL

- Die fünf Schwierigkeitsstufen verwenden feste Trainer-/Wildnisaufschläge:
  Standard 0/0, Hoch +3/+2, Hart +5/+3, Sehr Hart +8/+5 und Extrem +10/+7.
- Gegnerlevel bleiben bei 100 gedeckelt.
- Extrem sperrt Heil-/Kampfitems in Trainerkämpfen, aber nicht Pokébälle in
  Wildkämpfen.
- Seltene Items wie der Meisterball sind vor versehentlichem Wegwerfen und
  Verkaufen geschützt; die Bestätigung steht standardmäßig auf `NEIN`.
- Das Fahrrad reagiert auf die logische Select-Taste und damit auch auf
  Tastatur-/Controller-Neubelegungen.
- Kanto 151, Prismenhöhlen-Rückweg sowie die einmaligen Ho-Oh-/Lugia-Visionen
  sind in denselben Core-Test eingebunden.
- Interne Warteschlangen und Historien sind begrenzt, damit lange Spielstände
  nicht unkontrolliert wachsen.

### 8. Durchgängiges Kanto-Ascendant-/Feuerrot-Menüdesign

- Hauptmenü, Optionsbaum, Gameplay-, Begleiter-, Grafik-, Inhalte- und
  Systemseiten verwenden dieselbe Feuerrot-nahe Farb- und Rahmenlogik.
- Lange Listen besitzen einen festen sichtbaren Bereich und sauberes Scrollen.
- Die neuen Menüs hängen zentral unter `ASCENDANT -> OPTIONEN`; es existieren
  keine losgelösten Doppeloptionen.
- Die Darstellung wurde in Rot, Blau und Gelb separat aufgenommen.

![Ascendant-Hauptmenü](../qa/comprehensive_e2e_20260808/ui/red-main.png)

![Zentraler Optionsbaum](../qa/comprehensive_e2e_20260808/ui/red-options-root.png)

![Gameplay-Einstellungen oben](../qa/comprehensive_e2e_20260808/ui/red-gameplay-top.png)

![Gameplay-Einstellungen gescrollt](../qa/comprehensive_e2e_20260808/ui/red-gameplay-scroll.png)

### 9. Überarbeiteter Gorochu-Walking-Sprite

- Der Walker basiert auf einer klar lesbaren Raichu-Silhouette und wurde für
  Gorochu gezielt verändert.
- Normal und Shiny besitzen Stand- und Laufbilder für alle Richtungen.
- Rechts wird korrekt aus der linken Bewegung gespiegelt.
- Ein alter Renderer-Cache kann den neuen Pfad nicht mehr unbemerkt durch ein
  altes Bild ersetzen.

![Gorochu läuft links](../qa/comprehensive_e2e_20260808/gorochu/normal-walk-left.png)

![Gorochu läuft rechts](../qa/comprehensive_e2e_20260808/gorochu/normal-walk-right.png)

![Schillerndes Gorochu läuft nach oben](../qa/comprehensive_e2e_20260808/gorochu/shiny-walk-up.png)

### 10. Offene, erweiterbare Konfliktsperre

Kanto Ascendant überschneidet sich funktional mit Followers EX, PokéPC
Followers und dem externen Quality-of-Life-Paket. Deshalb stehen deren stabile
Manifest-IDs in einer einzigen Konfliktliste.

- Sind beide Mods beim Start aktiv, wird nur Kanto Ascendant in den
  Konfliktzustand gesetzt. Der andere Mod bleibt geladen.
- Der Fehlerlog nennt die kollidierende Manifest-ID.
- Wird Kanto Ascendant im Mod-Manager eingeschaltet, während einer der drei
  Mods aktiv ist, erscheint `CONFLICTS WITH / DISABLE IT FIRST`; die Auswahl
  wird nicht übernommen.
- Weitere Mods können später durch eine zusätzliche Manifest-ID sowie einen
  Testfall ergänzt werden.

![Followers EX wird im Manager blockiert](../qa/comprehensive_e2e_20260808/conflicts/followers-ex-selection-block.png)

![PokéPC wird im Manager blockiert](../qa/comprehensive_e2e_20260808/conflicts/pokepc-selection-block.png)

![Quality of Life wird im Manager blockiert](../qa/comprehensive_e2e_20260808/conflicts/qol-selection-block.png)

### 11. Echte animierte Team-Icons ohne FollowerEX

- Für alle Pokémon #001–251 sowie Gorochu wird im Team-Menü ein eigenes
  Artensheet registriert; Kanto Ascendant ist dafür nicht von FollowerEX
  abhängig.
- Normale Pokémon werden auf ihr exaktes Artensheet aufgelöst. Wo ein eigenes
  Shiny-Sheet enthalten ist (Johto und Gorochu), wird es pro Pokémon gewählt;
  die Kanto-Quelle besitzt derzeit je Art ein gemeinsames Walker-Sheet.
- Die Option `TEAM-ICONS` schaltet zwischen `ANIMIERTE ARTEN` und den
  ursprünglichen Gen-I-Klassen um. Wegen des beim Start aufgebauten
  Icon-Katalogs wird ein erforderlicher Neustart in der Hilfe genannt.
- Die farbigen Sheets besitzen im alten SGB-Teamfenster eine gezielte
  Echtfarbzone. Dadurch werden sie nicht mehr zu falschen schwarzen oder
  grauen Gen-I-Silhouetten verfärbt.

![Animierte Team-Icons – Phase A](../qa/ascendant-options-bag-icons-20260808/red-team-icons-frame-a.png)

![Animierte Team-Icons – Phase B](../qa/ascendant-options-bag-icons-20260808/red-team-icons-frame-b.png)

### 12. SELECT-Hilfe und Feuerrot-Tasche

- SELECT öffnet auf der Optionshauptseite und auf jeder Unterseite eine
  deutsch/englische Erklärung zur markierten Einstellung.
- Die Hilfe nennt den aktuellen Wert, notwendige Neustarts und besitzt bei
  längeren Texten mehrere Seiten.
- Alle 52 Schema-Optionen haben einen Hilfetext; dynamische EP-Zeilen und
  Optionskategorien sind ebenfalls erklärt.
- Die Tasche zeigt Gegenstände, Anzahl und Geld im Feuerrot-nahen
  Ascendant-Stil. Im festen unteren Feld bleibt die Wirkung des markierten
  Items sichtbar.
- Benutzen, Wegwerfen, Kampfitems, Schutzabfragen und SELECT-Sortierung
  bleiben im Engine-Code und wurden nicht durch eine zweite Taschenlogik
  ersetzt.

![SELECT-Hilfe für Schwierigkeit](../qa/ascendant-options-bag-icons-20260808/red-gameplay-help.png)

![Feuerrot-Tasche mit dauerhafter Itembeschreibung](../qa/ascendant-options-bag-icons-20260808/red-bag-item-description.png)

## Was genau E2E getestet wurde

| Bereich | Echte Spielprozesse | Durchführung | Ergebnis |
| --- | ---: | --- | --- |
| Native Einzel-Follower | 3 | Rot/Blau/Gelb: Laufen, Ecke, Kartenrand, Tür, Entwicklung, Team/Box, Speichern/Laden | Grün |
| Sprite-Registry | 1 | 17 repräsentative Kanto-, Johto- und eigene Arten tatsächlich auf der Karte erzeugt | Grün |
| 1–4-Follower-Kette | 3 | Alle Anzahlen, gemischte Arten, Kurven, Route, Tür, Höhle, Fahrrad, Entwicklung, Entfernen, Gelb-Skripte | Grün |
| Begleiterauswahl | 6 | Pro Edition schreiben und in einem neuen Prozess laden; Custom-Reihenfolge und stabile IDs prüfen | Grün |
| Rematch Phase 6 | 6 | Siege, Originalteam, Entwicklung, Rekrutierung, Leveldeckel, Anti-Repeat; danach Neustart | Grün |
| Rematch Phase 7 | 6 | Feld, Level 100, Post-100, Attacken, Freischaltungen, Taktik, Top Vier, Champ; danach Neustart | Grün |
| Rematch Phase 8 | 6 | Items, Geld, EP-Teiler, Multiplikator, Menüabkürzung, PC und Persistenz | Grün |
| Schwierigkeit/Core | 3 | Alle Modi, Deckel, Tastatur, Controller, Neubelegung, Itemaktionen, Kanto 151, Prism, Visionen, Gorochu | Grün |
| Feuerrot-Menüs | 3 | Hauptmenü, Optionsbaum, Gameplay oben/unten, Begleitereditor in jeder Edition | Grün |
| Gorochu-Animation | 1 | Normal/Shiny, Stand/Lauf, alle Richtungen und gespiegeltes Rechts | Grün |
| Mod-Konflikte | 4 | Drei offizielle IDs; QoL-Aufnahme einmal in neuer Identität wiederholt | Grün |
| Manuelle Spielsitzung | 1 | Launcher, Rot-Spielstand, Feld, Followerkette, Startmenü, Ascendant-Menü, Zurück | Grün |
| Animierte Team-Icons | 6 | Rot/Blau/Gelb, je Artphase A/B; sechs unterschiedliche 16×96-Sheets pro Lauf | Grün |
| Optionshilfe und Tasche | 3 | Menübaum, mehrseitige SELECT-Hilfe, Tasche, Beschreibung und Sortiersteuerung pro Edition | Grün |

Das sind 51 erfolgreiche automatisierte Real-LÖVE-Prozesse plus eine manuelle
Spielsitzung.

## Manuelle Spielsitzung

Der erzeugte Rot-Spielstand `PHASE5` wurde im echten Launcher ausgewählt. Nach
dem Titelbildschirm wurde Pallet Town geladen; die Viererkette war sofort
sichtbar. Anschließend wurden Feldfokus und Richtungsinput geprüft, das
Startmenü mit Escape geöffnet, `ASCENDANT` ausgewählt und das Feuerrot-Menü mit
`X/B` wieder bis ins Feld geschlossen.

![Manuell geladener Rot-Spielstand](../qa/comprehensive_e2e_20260808/manual/red-walk.png)

![Manuell geöffnetes Ascendant-Menü](../qa/comprehensive_e2e_20260808/manual/red-ascendant-menu.png)

## Ergänzende automatische Einzelprüfungen

- Hauptintegration: 6.569 von 6.569 Checks
- Upgrade-/Altsave-Matrix: 6.633 von 6.633 Checks
- Rematch Phase 6: 51 Checks
- Rematch Phase 7: 88 Checks
- Rematch Phase 8: 130.093 Checks
- Core Phase 9: 28 Checks
- Phase-10-Grenzaudit: 28 Checks
- Gorochu: 40 visuelle, 55 Audio- und 61 Walking-Qualitätschecks
- Erreichbarkeit: 251 von 251 Arten; alle Arten-/Attackenreferenzen gültig
- Feldökonomie: 54 Checks
- Forschungsatlas: 44 Checks
- Ascendant-Menü: 17 Verhaltens- und 19 Strukturchecks über 17 gestaltete Module
- Team-Icons: 252 registrierte Artenprofile; Normal/Shiny und Originalmodus geprüft
- SELECT-Hilfe/Tasche: zweisprachige Hilfe, Itemfamilien und erhaltene Aktionen geprüft
- Johto Signals/Prismen/Wilds/Archive: vollständige CI-Matrix grün
- Strikte Modkit-Validierung: grün
- `git diff --check`: grün

## Try & Error – was beim Testen auffiel

1. Eine ganz neue Testidentität hatte zunächst keinen ROM-Cache und blieb
   korrekt im Launcher bei `No ROM imported`. Für alle folgenden Läufe wurden
   deshalb die bereits importierten Rot-/Blau-/Gelb-Caches schreibgeschützt
   eingebunden. Spielstände und Mod-Daten blieben trotzdem je Test frisch.
2. Der erste Headless-Aufruf verwendete einen absoluten Modpfad, den das
   speicherinterne Test-Dateisystem nicht als Modquelle behandelt. Der Test
   wurde mit dem exakten relativen Launcherpfad wiederholt und bestand.
3. Die erste QoL-Screenshotserie wurde zwar logisch grün, eine Aufnahme war
   aber nur teilweise gefüllt. Der komplette Test wurde in einer neuen
   Identität wiederholt. Nur die vollständige zweite Serie wird hier benutzt.

Diese drei Punkte waren Fehler im Testaufbau beziehungsweise in der Aufnahme,
nicht im Spielcode. In den wiederholten Produktprüfungen trat kein neuer
kritischer Fehler auf.

## Bekannte Grenzen der Aussage

- Dies ist eine breite, gezielte E2E-Matrix und ein kurzer manueller Spieltest,
  aber kein erneutes Durchspielen der kompletten Geschichte von Anfang bis
  Ende.
- Controllerpfade wurden über echte LÖVE-/SDL-Ereignisse getestet; es wurde
  nicht jedes physische Controller-Modell angeschlossen.
- Nicht sichtbare Systeme wie Persistenz, Belohnungsverteilung und
  Anti-Repeat werden durch Zustandsprüfungen und neue Prozesse bewiesen. Die
  Screenshots dokumentieren die tatsächlich sichtbaren Oberflächen und
  Spielfiguren.

## Freigabestatus

Auf Basis dieser Matrix ist der aktuelle Stand ein testbarer Release Candidate.
`KA-INTERNAL: RELEASE-BASELINE-001`
