# Hidden Evolution: Gen-I-Tileset- und Voxel-Provenienz

Status: **Authority-Vertrag für 6.5 RC**.

Die drei Prüfungen verwenden ausschließlich die bereits von der Engine aus
Pokémon Rot/Blau/Gelb importierten Kanto-Tilesets. Es werden keine Johto-
Tileset-PNGs mehr geladen, kopiert oder als Voxel-Ersatz registriert.

| Produktbereich | Runtime-Tileset | Gen-I-Rollen | Voxel-Vertrag |
| --- | --- | --- | --- |
| Gemeinsamer Drei-Schacht-Tunnel | `CAVERN` | Höhlenboden, Felswand, native Warppads | `FULL` |
| ROT – fünf Basalt-/Abgrundebenen | `CAVERN` | Boden `25`, Fels `125`, Wasser `118`, Warp `124`, native Lochquadranten `119/120/104/105` | `FULL` |
| BLAU – fünf Frost-/Gezeitenebenen | `CAVERN` | Boden `25`, optischer Eisproxy `21`, Bremse `1`, Fels `125`, Wasser `118`, Warp `124`, native Lochquadranten `119/120/104/105` | `FULL` |
| GRÜN – vier Hain-/Nebelebenen | `FOREST` | Baumwall `2`, Pfad `27`, Lichtung `46`, Gras `47`, Wasser `45`, Baumtor `25`, Wurzel `99` | `FULL` |
| Gemeinsame Siegelkammer | `CAVERN` | native Höhlen- und Warppads | `FULL` |

Die Blocknummern sind nullbasierte Runtime-Metatiles aus
`gen1recomp/data/generated/tilesets.lua`. Jede Kampagne validiert beim
Registrieren zusätzlich die tatsächlich wirksamen Kollisionszellen; eine
optisch passende, aber begehbare Wand kann dadurch nicht still in den RC
gelangen.

`FULL` bedeutet: DRAMALESS verwendet das kanonische Volumenprofil des
jeweiligen Gen-I-Tilesets. `MAP_STUDIO`, `voxelCells` und private
„Wallpaper“-Voxel sind für diese Karten ausdrücklich verboten. So stammen
2D-Kollision, Warps und Voxelvolumen aus derselben Quelle.

## BLAU: Eis ohne Johto-Abhängigkeit

Die Gen-I-Engine besitzt keine allgemeine Eis-Terrainmechanik. BLAU nutzt
daher den vollständig begehbaren CAVERN-Akzentblock `21` als sichtbares Eis
und eine kampagneneigene, zellweise Bewegungssteuerung. Vor jedem Schritt
werden Grenze, Kollision und belegte Zelle geprüft. Nach jedem Schritt läuft
`onStepComplete`; Loch, Warp, Bremse oder Kartenwechsel beenden die Bewegung.
Die sechs sichtbaren Abgründe sind echte CAVERN-Lochzellen mit explizitem,
sicherem Rückwarp zum jeweiligen Abschnittseingang.

## GRÜN: echter Nebel

GRÜN verwendet `field.mapAtmospheres` mit `effect="fog"`. Sichtweite und
Deckkraft reagieren auf dieselben fünf Freigabeflags wie Rätsel, Ledger und
Spielstand. Ein bloßes `map.fog`-Feld oder eine private Rendererattrappe zählt
nicht als Integration.

## Abgeleitete Feldobjekte

`shiny_transforms.lua` schreibt ausschließlich kleine, neu komponierte
Hilfsgrafiken in den persönlichen Cache unter
`save/mod-derived/kanto_ascendant/hidden_evolution/`:

- eine transparente, kompakte Runentafel ohne deckenden 16×16-Hintergrund;
- einen transparenten haarfeinen Wandriss und seine hochgesetzte Variante;
- die versiegelte Tür aus Material des persönlichen CAVERN-Imports.

Strength-Felsen verwenden unmittelbar `SPRITE_BOULDER`; dafür wird kein
zweites Asset erzeugt. Die frühere Datei `hidden_evolution_tilesets.lua` und
die Johto-Bitmaps bleiben höchstens als historische Prototypreferenz im
Arbeitsbaum. `hidden_evolution_campaign.lua` lädt sie nicht und führt sie
nicht im `COPY_SET` des RC.

## Abnahme

Verbindlich sind die fokussierten Kanto-Tests für ROT, BLAU und GRÜN, der
gemeinsame Tunneltest, der Authority-Ladetest sowie echte 2D- und DRAMALESS-
Aufnahmen. Dateiexistenz oder ein Renderer-`ok:true` allein ist kein visueller
PASS; transparente Objekte, Wand-/Wasser-/Lochlesbarkeit, korrekte Ebenen und
fehlende Fallbackflächen müssen in den Bildern geprüft werden.
