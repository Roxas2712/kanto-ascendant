# Kanto Ascendant 6.5.0 RC11 – Testbericht

## Grundlage

- Ausgangspunkt: der abgenommene RC10-Commit `c35a41a`.
- RC10-Paket und RC10-Rollback wurden nicht verändert.
- Die 6.0.6–6.0.11-Hotfixhistorie wurde auf RC10 zusammengeführt; bei
  Konflikten blieben die neueren 6.5-Implementierungen maßgeblich.
- Manifest: `kanto_ascendant`, Version `6.5.0`.

## Automatisierte Prüfungen

- Modkit strict: bestanden.
- Hauptregression: 6573/6573.
- Upgrade-/Deaktivieren-/Reaktivieren-Matrix: 6633/6633.
- Rematch Phase 8: 130108 Assertions.
- QoL: 608 Assertions einschließlich aller fünf Balltypen und Trainer-Block.
- Konfliktschutz: alle sechs bekannten IDs in beiden Manager-Richtungen.
- Follower Phase 1–5, Rematch Phase 6–8, Core Phase 9–10, Johto Signals,
  Gorochu, Atlas, Feldökonomie, Erreichbarkeit, Voxel-Kamera und UI-Audits:
  bestanden.
- UI-Audit: 19/19 mod-eigene Menüs verwenden das Kanto-Layout.

## Echter Renderer-Lauf: Ballanimationen

Der isolierte Red-Lauf verwendete nur Kanto Ascendant und eine getrennte
Testidentität. Geprüft wurden Wurf, rollender Wurf, geschlossener Ball,
erfolgreicher Fang, Ausbruch, nicht fangbarer Gegner und Trainer-Block.

Ergebnis: 43/43 Laufzeitprüfungen bestanden. Der integrierte Fangindikator
wurde zusätzlich aus dem importierten 8×8-Balltile in
`mod-derived/kanto_ascendant` erzeugt; es gab keinen fehlenden Asset-Pfad.

Belegbilder liegen in `qa/rc11/ball_animations/`:

- `poke_breakout_toss_roll.png`
- `great_caught_toss_roll.png`
- `ultra_breakout_toss_roll.png`
- `master_caught_toss_roll.png`
- `safari_caught_toss_roll.png`
- `master_trainer_block.png`

Der Ordner enthält insgesamt 23 Screenshots sämtlicher getesteter Phasen.

## Paketprüfung

- Das reproduzierbare Archiv enthält 11227 Laufzeitdateien plus
  `.modkit/pack.json`.
- Der Produktionsimporter hat das exakte Test-ZIP akzeptiert: 5/5 Prüfungen.
- Gegenüber RC10 fehlt keine Laufzeitdatei.
- Tests, Werkzeuge, QA-Screenshots und Release-Arbeitsdokumente sind nicht in
  das Spielerpaket gelangt.
- ZIP-Integrität und Johto-Signals-Releasegrenze: bestanden.
- Der finale RC11-Hash steht in `SHA256SUMS-6.5.0-RC11.txt` neben dem Paket.
- Das getrennte Rückweg-Paket enthält bytegenau das abgenommene RC10-ZIP mit
  SHA-256 `03c026a63dcb3292073450c98ac078cc253b58252a4cbdd09c6cb9b7d55a4dfe`.

## Vermächtniswege-Addendum

Der auf RC11 aufbauende Arbeitsstand wurde zusätzlich mit folgenden isolierten
Prüfungen abgesichert:

- Archiv und Vier-Zyklen-Persistenz: 79 Assertions.
- Echte Vermächtnis-Reise: 16 Assertions.
- Drei Charakterwege und dauerhafte Siegel: 23 Assertions.
- Wandernde Trainer: 294 Assertions.
- Atlas/Vermächtnis-Galerie einschließlich drei Siegeln und Pass: 48/48.

Danach blieben Hauptregression 6573/6573, Upgrade-Matrix 6633/6633,
Deaktivieren/Speichern/Reaktivieren 18/18 und der Konfliktschutz vollständig
grün. Der strenge Modkit-Validator und ein reproduzierbarer
Paket-Probelauf bestanden. Dieser Probelauf ersetzt noch nicht das oben
dokumentierte finale RC11-Paket oder dessen Hash.

## Crystal-v1.5-Addendum

Die Inhalte des offiziellen Releases `v1.5` wurden additiv auf den bestehenden
6.5-Arbeitsstand übernommen. Grundlage ist der unveränderte Upstream-Commit
`9d48cc921da4db88043cb2a14e9f8803aefffad7`. Die bereits in Kanto Ascendant
vorhandenen normalen und schillernden Vorderseiten für #001–251 blieben
erhalten. Ergänzt wurden 251 Graustufen-Vorderseiten, 453 Kanto-Rückseiten,
94 Trainerporträts sowie der Turmgeist. Herkunft und Importregeln sind in
`assets/crystal_v15/provenance.json` festgehalten.

Automatisierte Ergebnisse:

- Crystal-v1.5-Laufzeitlogik: 18/18.
- Asset-Vollständigkeit: 251 Graustufen-Vorderseiten, 453 Rückseiten und
  94 Trainerporträts.
- Hauptregression: 6573/6573.
- Upgrade-Matrix: 6633/6633.
- Deaktivieren/Speichern/Reaktivieren: 18/18.
- Strenger Modkit-Validator und Phase-10-Audit: bestanden.

Zusätzlich wurde das gepackte Mod in einer isolierten echten LÖVE-Instanz
sowohl im Farbmodus `redpp` als auch im Graustufenmodus `gbc` gestartet. Dabei
wurden Vorder- und Rückseitenauflösung, der True-Color-Vertrag, tatsächlicher
Framewechsel sowie die Trainerporträts geprüft. Die sichtbare Bewegung von
Bisasam wurde anschließend im laufenden Spiel bestätigt.

Die sechs finalen Belegbilder liegen in `qa/crystal_v15_acceptance_final/`:

- `redpp_summary_frame_a.png`
- `redpp_summary_frame_b.png`
- `redpp_trainer_intro.png`
- `gbc_summary_frame_a.png`
- `gbc_summary_frame_b.png`
- `gbc_trainer_intro.png`

Das abschließend neu erzeugte Testpaket enthält 15485 Laufzeitdateien plus
`.modkit/pack.json` (15486 Archiveinträge). ZIP-Integrität, Root-Manifest,
Manifest-ID `kanto_ascendant`, Version `6.5.0`, neun repräsentative
Pflichtdateien und die erneute strenge Validierung des entpackten Archivs sind
bestanden. MODPKG und ZIP sind bytegleich und haben SHA-256
`93b78384d6e7d3be44c3805fc7f413b3af2e843fb6e7ce02fabc9efa4b867fd6`.

Die Aufnahmen und QA-Werkzeuge sind ausdrücklich vom Spielerpaket
ausgeschlossen. Dieses Addendum ersetzt weder das abgenommene RC10-Fallback
noch das zuvor dokumentierte finale RC11-Paket.

## Figuren-, Rivalen-, Gender- und Breeding-Integration

Der vollständig abgenommene Phase-8-Arbeitsstand wurde anschließend in den
RC11-/Crystal-v1.5-Zweig integriert. Dabei blieben die vorhandenen RC11-QoL-,
Vermächtnis- und Crystal-v1.5-Implementierungen maßgeblich. Zwei echte
Integrationsfehler wurden vor dem Paketbau behoben: Eier werden nicht mehr als
Follower angeboten, und der Voxel-Kamera-Controller wird nur einmal
registriert. Auch der Rivalen-Test berücksichtigt nun korrekt, dass die
Schwierigkeitslogik Teams kopiert, ohne die authored Ausgangsroster zu ändern.

Aktueller kombinierter Teststand:

- Hauptregression: 6582/6582.
- Upgrade-Matrix Red/Blau/Gelb mit echter Übersetzungsmod-Erkennung:
  6633/6633.
- Deaktivieren/Speichern/Reaktivieren: 18/18.
- Charaktere 139/139, Gelb-Kompatibilität 19/19, Sprachtrennung 18/18,
  Rivalenteams 16/16, Pokémon-Gender 36/36 und Breeding 31/31.
- Crystal-Figurenassets 306/306; Crystal-v1.5-Laufzeit 18/18;
  Charakter-Assetwerkzeug 54/54.
- QoL einschließlich Ball-/Icon-Regression: 607 Assertions.
- Rematch Phase 8: 130108 Assertions; Vermächtnis-Archiv 79,
  Vermächtnis-Reise 16, Wege 23 und Wanderer 294 Assertions.
- Strenger Modkit-Validator, Phase-10-Audit, gemeinsamer FireRed-UI-Audit,
  Johto-Signals-Grenzen und Pixel-Guards: bestanden.

Die 192 Rivalenkampf-Aufnahmen und die vollständigen Dialog-/Gender-Läufe aus
der Phase-8-Abnahme bleiben unter `docs/PHASE8_FULL_ACCEPTANCE_20260810_DE.md`
dokumentiert. Drei repräsentative Endbilder wurden nach
`qa/phase8_full_acceptance_final/` übernommen. Die sechs getrennten
Crystal-v1.5-Belege liegen weiterhin unter
`qa/crystal_v15_acceptance_final/`. Exakte Resolver- und Assettests sichern im
kombinierten Stand ab, dass die neuen v1.5-Pokémonbilder nicht die fest
zugeordneten Rot-/Blau-/Casey-Figurenpfade überschreiben.

Das kombinierte Testarchiv enthält 15576 Laufzeitdateien plus
`.modkit/pack.json` (15577 Archiveinträge). ZIP-Integrität, Root-Manifest,
Pflichtdateien, Ausschluss aller Tests/Werkzeuge/QA- und Quellenbilder sowie
die strenge Neuvalidierung des entpackten Archivs sind bestanden. `.modpkg`
und `.zip` sind bytegleich. SHA-256:
`5010b28485fa8b8ac93001f4e89b939002587e21e813ff6817e8758fe405d159`.
