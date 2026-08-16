# Journeys-/Essentials-Fangball-Art

## Herkunft und Inventur

Die Masters stammen ausschließlich aus dem vom Nutzer bereitgestellten,
lokalen Pokemon-Essentials-Projekt:

`Pokemon Journeys V18/Graphics/Battle animations/`

Die vollständige Zuordnung, Originalpfade, Runtime-Pfade, SHA-256-Werte und
Dimensionen stehen maschinenlesbar in
[JOURNEYS_BALL_ASSET_INVENTORY.json](JOURNEYS_BALL_ASSET_INVENTORY.json).
`tools/import_journeys_ball_assets.py` kopiert die geprüften Dateien nach
`assets/journeys_balls/`; die Runtime referenziert ausschließlich diese
eingecheckten Kopien und niemals Downloads.

| Engine-Item | Journeys-Sheet |
| --- | --- |
| POKE / GREAT / ULTRA / MASTER / SAFARI | ball_00 bis ball_04 |
| FAST / LEVEL / LURE / HEAVY / LOVE / FRIEND / MOON | ball_17 bis ball_23 |

Für jeden Eintrag existieren ein geschlossenes 256×64-Sheet und ein 32×64
`_open`-Master. Die acht 32×64-Segmente jedes geschlossenen Sheets sind
tatsächlich unterschiedliche Animationsphasen. Der frühere Runtime-Stand
wählte irrtümlich immer Segment 0; deshalb sind die alten Renderer-Captures
kein Freigabebeleg.

## Runtime

`journeys_ball_skins.lua` ersetzt nach dem bestehenden visuellen Ball-Bridge-
Setup ausschließlich den Rasterzeichner. Catch-Rate, Beutelverbrauch,
Toss-/Roll-/Shake-Timing, Breakout, Erfolg, Trainerblock, No-Catch und
Full-Box-Verhalten bleiben vollständig Engine-eigen. Die geschlossenen
Journeys-Masters erscheinen daher auf den existierenden OAM-Zuständen. Mit
deaktivierter Option `modern_ball_skins` bleibt die native R/B/Y-Palettenroute
unverändert aktiv.

Die offenen Masters werden mitgeliefert und inventarisiert, aber bewusst nicht
in einen falschen Zustand gemappt: Die aktuelle Gen-I-Animation-API bietet
keinen Open-Ball-Draw-Schritt zwischen Poof/Hide/Show. Dafür ist eine separate
Engine-Visual-API-Erweiterung erforderlich.

## QA und visuelle Abnahme

```sh
python3 tests/journeys_ball_assets_test.py

cd /path/to/gen1recomp
TRAINER_REMATCH_MOD_DIR=mods/ka_rc11_integration \
  ./.tools/luajit-src/src/luajit \
  mods/ka_rc11_integration/tests/journeys_ball_skins_test.lua
```

Beide Prüfungen laufen grün. Zusätzlich wurden sechs echte LÖVE-Läufe für
Rot/Blau/Gelb × Modern/Original erzeugt. `tools/build_journeys_ball_qa.py`
archiviert die 504 vollständigen LÖVE-Fenster-Captures unverändert unter
dem privaten Abnahmearchiv und extrahiert deren zentrierten GB-Viewport per
Nearest-Neighbour (je 160×144). Daraus entstehen
Kontaktbögen mit Außenabstand sowie zwei unbeschnittenen Beschriftungszeilen.
Die archivierten Raw-Captures und die nachvollziehbar abgeleiteten Viewports,
nicht die flüchtigen Capture-Verzeichnisse, sind der dauerhafte Abnahmebeleg.
Jeder Lauf bestimmt seinen zentrierten, ganzzahlig skalierten 160×144-Viewport
unabhängig. Das ist wichtig, weil LÖVE-Läufe je nach Fensterzustand mit
1024×768 oder 1710×1069 aufgenommen werden können; das frühere Wiederverwenden
der Modern-Geometrie war die Ursache der abgeschnittenen Original-Bögen. Die
konkrete Extraktion steht pro Lauf als `viewportExtraction` im Report.

Der reale Capture-Driver liegt in
`tests/journeys_ball_skins_visual_driver.lua`. Er durchläuft für jeden der
zwölf Bälle echte `BattleState`-Toss-, Shake-/Breakout-, Success-, No-Catch-,
vollbelegte-PC- und Trainerblockpfade und schreibt pro Zustand ein PNG. Er ist
für jede Palette getrennt auszuführen, zum Beispiel:

```sh
cd /path/to/gen1recomp
TRAINER_REMATCH_MOD_DIR=mods/ka_rc11_integration \
POKEPORT_DRIVER=/path/to/kanto-ascendant/tests/journeys_ball_skins_visual_driver.lua \
POKEPORT_VERSION=red SHOT_DIR=/tmp/journeys-balls-red love .
```

Der gleiche Lauf mit `POKEPORT_VERSION=blue` und `yellow` belegt die
R/B/Y-Palettenroute. Alle akzeptierten Läufe verwenden zusätzlich
`POKEPORT_ONLY_MOD=kanto_ascendant`, damit kein fremder Mod die Authority-
Runtime überlagert. Für die Originalroute setzt der Treiber
`modern_ball_skins=false`; dann bleibt die bestehende native Vierfarben-
Zeichnung aktiv.

## Renderer-Matrix – PASS / P1

Der Frame-0-Defekt ist behoben: `journeys_ball_skins.lua` wählt die acht
gelieferten, unterschiedlichen 32×64-Phasen aus dem echten `AnimPlayer`-
Zeitstand. `tests/journeys_ball_skins_test.lua` prüft die Runtimezuordnung und
den Framefortschritt; `tests/journeys_ball_assets_test.py` prüft Herkunft,
Hashes und 96 unterschiedliche Quellphasen.

Die sechs neu erzeugten Authority-LÖVE-Läufe enthalten jeweils 84 erwartete
Zustände: zwölf Bälle × Toss, Roll/Shake, Breakout, Success-Shake,
Success-voller-PC, No-Catch und Trainerblock. Damit liegen dauerhaft vor:

- 504 unveränderte LÖVE-Fensteraufnahmen;
- 504 exakt daraus extrahierte native 160×144-Viewports;
- 72 exakte, einballige Zustandsstreifen plus 72 lesbare JPEG-
  Reviewderivate;
- sechs exakte 12-Ball-Identitätsbögen plus sechs Reviewderivate.

`tests/journeys_ball_qa_report_test.py` validiert die sechs realen Läufe,
vollständige Raw-/Native-Matrix, unveränderte Kontaktzellen und sichtbar
verschiedene Zustände. Die manuelle Sichtprüfung vom 11.08.2026 deckt alle
zwölf Ballidentitäten sowie repräsentativ beide Randbälle und jeden Zustand
in Rot, Blau und Gelb auf Modern-/Originalroute ab. Der signierte Report
Der private Matrixreport steht auf `fileMatrixPass=true`,
`contactGridPass=true`, `visualStatus=pass` und `pass=true`; 156
Reviewartefakte sind dort per SHA-256 gebunden.

Ehrliche Grenze: Die zwölf gelieferten `_open`-Master bleiben inventarisiert,
aber absichtlich unverdrahtet. Die Gen-I-Kette besitzt zwischen Poof/Hide/Show
keinen separaten Open-Ball-Zeichenschritt. Breakout wird deshalb korrekt über
den echten Engine-`SHOWPIC_ANIM`-Pfad belegt und nicht mit einem erfundenen
Zwischenzustand kaschiert.
