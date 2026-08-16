# Laufzeitgrenze der Arten #252–279

Stand: 11. August 2026

## Verbindliche Identität

Der Spezies-Schlüssel (`TREECKO`, `AMBIPOM`, `AZURILL`, `WYNAUT` usw.) bleibt
die maßgebliche gespeicherte Identität. Ein vorhandener Spielstand wird nicht
auf eine andere Nummer umgeschrieben.

- `internalRuntimeDex` ist der private, speicherstabile Katalogplatz in Kanto
  Ascendant. Für diese Erweiterung ist das #252–279.
- `sourceDex` ist ausschließlich die nationale Quellidentität für Wilds-,
  Follower- und Voxel-Assets.
- #252–260 haben in beiden Feldern dieselbe Nummer.
- #261–279 dürfen niemals als nationale Nummer interpretiert werden.
- Besonders wichtig: `AZURILL` bleibt intern #278, verwendet visuell aber
  National #298. `WYNAUT` bleibt intern #279, verwendet visuell National #360.

Diese Trennung ist eine reine Auflösungs- und Migrationsgrenze. Sie ändert
weder Evolutionsketten noch Learnsets, Kampfdaten oder Pokédextexte.

## Oberflächenvertrag

`extended_species_runtime.lua` stellt für alle 28 Arten folgende tatsächliche
Laufzeitauflösungen bereit und exportiert eine maschinenlesbare Matrix:

- Kampf: Gegner-Vorderseite und Spieler-Rückseite
- normale und Shiny-Variante
- Pokédex, Status/Summary und moderne Boxvorschau
- animiertes Party-Icon und nativer Follower/Walker
- Wilds-Provider und Voxel-Billboard über `sourceDex`
- Speziesruf aus der zusammengeführten Audio-Registry

Alle 28 Crystal-Vorderseiten #252–279 besitzen jetzt mehrere gezeichnete
Posen und ein verfasstes `anim.asm`-Timing. 21 Arten stammen aus Nuuks
bereitgestelltem Crystal-Pack; Ambipom, Mismagius, Lickilicky, Rhyperior,
Tangrowth, Yanmega und Wynaut stammen identitätsgenau aus dem fest gepinnten
Polished-Crystal-Quellstand. Die Matrix meldet deshalb für alle Vorderseiten
`mode = "animated"` und `authoredTiming = true`. Die gelieferten Rückseiten
besitzen weiterhin jeweils nur eine echte Pose und bleiben ehrlich statisch;
ein einzelner Rahmen wird nie als Animation ausgegeben.

## Prüfpfade

- `tests/extended_species_runtime_test.lua` lädt die vollständige Mod über den
  echten Gen1Recomp-SDK-Loader und prüft die live ausgeführten Resolver.
- `tools/extended_species_runtime_qa_driver.lua` läuft im echten LÖVE-Client,
  dekodiert alle Oberflächen, konstruiert echte Spieler-/Gegner-Battler,
  erzeugt Wilds-Voxelkarten, öffnet Summary/Dex für Azurill und Wynaut und
  erzeugt jeden Ruf als echte Audioquelle.
- Der Treiber schreibt
  `extended_species_runtime_matrix.json` und exportiert jede tatsächlich
  durch LÖVE gerenderte Oberfläche. Die dauerhaft eingecheckte Abnahme liegt
  unter `qa/rc65_crystal_252_279/`: zwei Profile `crystal_on`/`crystal_off`,
  vier lesbare Kontaktbögen und `surface_acceptance_report.json` mit
  SHA-256 je Renderer-Export.
- `tools/build_extended_species_runtime_qa_gallery.py` validiert dabei 28
  Arten × normal/shiny × neun Oberflächen × zwei Profile (= 1.008 Exporte),
  die unterschiedlichen Shiny-/Front-Back-Karten und die Azurill-/Wynaut-
  SourceDex-Grenze. Der ausgeschaltete Crystal-Zweig behält für diese Gäste
  absichtlich die statische gelieferte Karte: Ein ROM-era-Fallback für
  #252–279 wird weder vorgetäuscht noch mitgeliefert.
