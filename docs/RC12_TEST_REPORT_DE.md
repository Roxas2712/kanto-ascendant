# Kanto Ascendant 6.5.0 RC12 – Testbericht

## Gezielte Prüfungen

- Vor-Spielstart-Tempo: 3/3. Titel und komplette Eich-Sequenz bleiben bei
  gespeichertem 20×-Tempo auf 1×; im Overworld wird 20× wieder wirksam.
- Ho-Oh-Vision: 14/14. Geprüft wurden 1-%-Grenze, ausschließlich das südliche
  Route-2-Gras vor dem Wald, Ausschluss von nördlichem Gras/Straße/Wald/Tor,
  Gold-Tint, Fangblock, Nuzlocke-Scoping, Team-Rollback und Übergabe der
  Niederlage an den echten Blackout-Callback.
- Crystal-v1.5-Laufzeit: 23/23, einschließlich tatsächlichem Framewechsel bei
  Eichs Demo-Pokémon.
- Figuren: 143/143. Der Selektorpfad ist für alle drei Figuren identisch mit
  dem jeweiligen aktiven Battle-Frontpfad.
- Pokémon-Gender: 37/37. Der Spieler-Marker bleibt bei Status und Level 100 in
  einem unabhängigen HUD-Feld.
- Core Phase 9: 30/30 einschließlich Ho-Oh-Kartengrenze.
- Team-Icons: 252/252 Art-Sheets registriert; Originalmodus, Shiny-Auswahl,
  Neustartvertrag und Migration der alten `species/classic`-Werte geprüft.

## Vollständige Regression

- Hauptregression: 6582/6582.
- Upgrade-Matrix Red/Blau/Gelb: 6633/6633.
- Deaktivieren/Speichern/Reaktivieren: 18/18.
- Rematch Phase 8: 130108 Assertions.
- Crystal-v1.5-Assets: 251 Graustufen-Vorderseiten, 453 Rückseiten und 94
  Trainerporträts.
- Crystal-Figurenassets: 306/306; Figuren-Assetwerkzeug: 54/54.
- Strenger Modkit-Validator: bestanden.
- `git diff --check`: bestanden.

## Echter Renderer-Lauf

Isolierter Red-Lauf mit Kanto Ascendant, deutscher Übersetzung und Dramaless
Shape 1.6.2.ST: **14/14** Laufzeitprüfungen bestanden.

Nachgewiesen wurden:

- Figurenwahl mit echten Battle-Frontbildern;
- zwei unterschiedliche Crystal-Frames bei Eich;
- goldene Ho-Oh-Vision im Voxel-Kampf;
- farbiges Pikachu im Voxel+GBC-Kombinationspfad;
- sauber getrennte Anzeigen `Geschlecht + Level 100` und
  `Geschlecht + PAR`;
- echter Blackout nach Niederlage mit Ankunft im Vertania-Pokémon-Center.

Belegbilder liegen unter `qa/rc12_startup_hooh_hud/` und werden durch
`tests/rc12_startup_hooh_hud_driver.lua` reproduziert. Testtreiber, Quellen
und QA-Bilder sind vom Spielerpaket ausgeschlossen.

Zusätzlich liefen zwei voneinander getrennte echte PartyMenu-Prozesse für die
Ruhe- und Bewegungsphase. Beide bestätigten sechs verschiedene, ladbare
16×96-Art-Sheets; die Screenshots besitzen unterschiedliche Bilddaten. Die
Belege liegen unter `qa/rc12_party_icons/`.

## Paketprüfung

Das launcherfähige ZIP enthält 15.577 Laufzeitdateien plus
`.modkit/pack.json` (15.578 Archiveinträge). ZIP-Integrität, Root-Manifest,
Manifest-ID `kanto_ascendant`, Version `6.5.0`, repräsentative Pflichtdateien,
erneute strenge Validierung des entpackten Archivs und Ausschluss von Tests,
QA-Bildern, Quellen sowie privaten Release-Unterlagen sind bestanden. ZIP und
MODPKG sind bytegleich und tragen SHA-256
`3d2696e9a96f95a1062e132c07a51e697a8519f9d0fa3565ca16c5c9a509b636`.
Die Rollback-Datei ist bytegleich mit dem abgenommenen RC11 und behält dessen
SHA-256 `5010b28485fa8b8ac93001f4e89b939002587e21e813ff6817e8758fe405d159`.
