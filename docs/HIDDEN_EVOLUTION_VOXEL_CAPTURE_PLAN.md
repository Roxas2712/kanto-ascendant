# Hidden Evolution 6.5 – Runtime-/Voxel-Abnahme

Stand: 11. August 2026

## Ergebnis und Abgrenzung

Die drei neuen Kartenkampagnen RED, BLUE und GREEN sowie gemeinsamer Tunnel,
versiegelte Vorkammer und alle drei Wandrisse sind im aktuellen Authority-
Stand in 2D und DRAMALESS/Voxel abgenommen. Der echte Runtimepfad registriert
**16 eindeutige Hidden-Evolution-Karten**; der Editor-Handoff umfasst zusätzlich
Route 22, Route 24 und Route 3 und damit exakt 19 Karten.

Das kampagnenweite **Release-Gesamtgate bleibt PARTIAL**. Die einzelnen
Dungeon-Vollruns ersetzen nicht den noch fehlenden zusammenhängenden
Ruhmeshalle→RED→BLUE→GREEN→Steinkoffer-Lauf über drei Vermächtnisreisen.
Johto-Passagen, Eich-Finale und andere getrennte RC-Gates werden durch dieses
Dokument ebenfalls nicht freigegeben.

Der bereits bestehende Aprikoko-Ball-Funktionsstand wird nicht zurückgebaut,
ist nach ausdrücklicher Nutzerentscheidung heute jedoch geparkt und kein
Bestandteil dieses Abschlussgates.

Autoritative Strukturwerte:

- Authority-Load: **168/168 PASS**.
- Headless-Struktur: **16 Runtimekarten PASS**.
- gemeinsamer Layout-Hash: `hevo-a-0b71`.
- finaler Editor-Handoff:
  `/Users/maarten/Documents/Recompile/Hidden-Evolution-Map-Editor/workspaces/Kanto-6.5-RC-Karten/authority-current/editor_project.json`
  mit 19 Karten, `generatedAt 2026-08-11T16:14:23Z`, SHA-256
  `8273bca54d501377db720e3e07064a584e45f1aacd9a5b9aa35102cc49d072d1`.
- `sourceProjectHash 35e2176fdbcba08602cd3f327cc8052dea2d39c0e0cdecf819d1ee8a8d09576a`
  bezeichnet ausschließlich die Provenienz des
  ursprünglichen Nutzerimports und ist **nicht** der Hash des finalen Exports.

## Verbindlicher Renderer-Vertrag

Jede map-, tileset-, asset- oder rendererrelevante Änderung muss die
betroffenen Karten erneut durch den echten DRAMALESS-World-Pass laden. Ein
`result.json` mit `ok: true` allein ist kein visuelles PASS. Erforderlich sind:

- `voxelMode=FULL` und ein aktiver Pipeline-/World-Pass;
- keine fehlenden Assets, Schwarzbilder, falschen Ebenen, Base-Form-Fallbacks,
  2D-Notfallrenderer oder Abstürze;
- dieselbe begehbare Topologie, Warps, Objekte und Interaktionspositionen wie
  im 2D-Pfad;
- Originalauflösungsprüfung auf weiße Säume, Raster-/Ditherringe, Portal-
  Billboards, leere Viewportränder und Objektglows;
- echte D-Pad-/Menütraces für Navigation, Rätsel, Save/Reload, Rückweg und
  Wiedereintritt.

`BLITZ` ist in RED/BLUE-Dunkelheit und im GREEN-Nebel absichtlich
**wirkungslos**. Der Versuch zeigt nur den lokalisierten Flavortext; er darf
weder Sichtstufe noch Nebel-/Dunkelmaske verändern.

## Finaler RED-Beleg

Der 2D-Vollrun liegt unter
[`qa/hidden_evolution_red_release_full_final_v2_20260811/`](../qa/hidden_evolution_red_release_full_final_v2_20260811/):
45 PNGs, 2.215 Eingabezeilen, Prozessstatus 0. Der entsprechende vollständig
aktuelle DRAMALESS-Lauf liegt unter
[`qa/hidden_evolution_red_release_full_voxel_final_v1_20260811/`](../qa/hidden_evolution_red_release_full_voxel_final_v1_20260811/):
45 PNGs, 2.274 Eingabezeilen, 45 Rendererreceipts, Prozessstatus 0.

Abgedeckt sind Route-22-Haarriss, isolierter RED-Schacht, alle fünf RED-Karten,
fünf voneinander getrennte Statuennischen, drei Strength-Fassungen, sieben
echte Stürze mit sicheren Zuflucht-/Leiterrückwegen, schwarzer Surfstrom,
LOHGOCKNIT plus Reload, Groudon-Schrein/Reward, Vorkammer, vollständiger
Rückweg und Reentry. Nach Statue 5 bleiben 173 geänderte Wegzellen bis zum
Ende; sie ist kein Ausgangsmarker.

Für neue Belege gilt zusätzlich der getrennte Objektvertrag: Alle fünf
Rätselobjekte pro Held zeigen die graue, unbewegliche
`SPRITE_KA_HEVO_QUIZ_STATUE`. Gelbe `SPRITE_KA_EVOLUTION_RELIC`-Objekte sind
ausschließlich optionale Etagen-Lichtsteine. 2D, VASC und DRAMALESS müssen die
beiden Rollen ohne weißen Hintergrund, Clipping oder Sprite-Austausch zeigen.

Repräsentative Originale:

- [Sight 0 und Statue 1](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/03a_statue1_hidden_niche_sight0.png)
- [dritte Strength-Fassung](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/05d_strength_socket_C.png)
- [Abgrundsturz und Recovery](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/08_f_abyss_fall_4_recovery.png)
- [LOHGOCKNIT](../qa/hidden_evolution_red_release_full_voxel_final_v1_20260811/voxel/07a_recovery_blazikenite_claim.png)
- [langer Rückweg nach Statue 5](../qa/hidden_evolution_red_release_full_voxel_final_v1_20260811/voxel/10d_lower_long_return_after_statue5.png)
- [Route-22-Rückkehr nach Reentry](../qa/hidden_evolution_red_release_full_voxel_final_v1_20260811/voxel/18_route22_return_after_reentry.png)

Der frühere negative RED-Befund zu angeblich ungültigen negativen
Voxel-Höhen ist überholt. Der aktuelle Authority-Load und der vollständige
DRAMALESS-Vollrun starten und beenden RED ohne diesen Blocker.

## Finaler BLUE-Beleg

Der unveränderte kanonische Belegsatz liegt unter
[`qa/hidden_evolution_blue_release_final_20260811/`](../qa/hidden_evolution_blue_release_final_20260811/)
und ist durch [REPORT](../qa/hidden_evolution_blue_release_final_20260811/REPORT.md),
`MANIFEST.tsv` und `SHA256SUMS.txt` gebunden.

| Belegrolle | Ordner | Umfang |
|---|---|---|
| vollständige 2D-Mechanik | `full_2d_current_v1/` | 89 PNG, 1.274 Trace-Zeilen, exit 0 |
| historischer Shared-Randdelta 2D | `shared_border_2d_v3/` | 5 PNG, 6 Trace-Zeilen, exit 0; für Abstand/Sicht durch den finalen Spacing-Report ersetzt |
| Voxel-Vollrun für BLUE-Mechanik/Innenräume | `full_voxel_current_v1/` | 89 PNG, 1.285 Trace-Zeilen, exit 0; Shared-Bilder nur für Abstand/Sicht superseded |

Die vollständigen 2D-/Voxel-Läufe bleiben für Mechanik und Inhalt maßgeblich.
Ihre Shared-Aufnahmen `01`, `42` und `44` sowie der frühere Randdelta v3 sind
inzwischen ausschließlich hinsichtlich Schachtabstand und Sichtbarkeit
ersetzt. Dafür gilt der neue gezielte 2D-/FULL-Voxel-Beleg unter
[`qa/hidden_evolution_shared_tunnel_spacing_final_20260811/`](../qa/hidden_evolution_shared_tunnel_spacing_final_20260811/).

Abgedeckt sind fünf isolierte Statuen an den finalen Positionen Halle
`(25,22)`, Eis `(11,5)`/`(37,31)` und Tiefe `(3,19)`/`(47,9)`, drei
Strength-Schalter, eine zusammenhängende 217-von-225-Block-Eisfläche, alle
sechs Fallrouten `(41,6)`, `(42,7)`, `(4,16)`, `(3,17)`, `(29,28)`,
`(30,29)`, mehrdirektionaler Surf, SUMPEXNIT+Reload, Reward, Rückweg und
persistenter Sight-5-Reentry. Die BLUE-eigene idempotente SEEL-Darstellung
verhindert die unsichtbare Surfsilhouette und wird beim Verlassen/Reload
restauriert; sie ändert keine gemeinsame Engine- oder Assetdatei.

Repräsentative Originale:

- [wirkungsloser BLITZ](../qa/hidden_evolution_blue_release_final_20260811/full_voxel_current_v1/voxel/03_threshold_after_ineffective_flash.png)
- [großes Eisfeld](../qa/hidden_evolution_blue_release_final_20260811/full_voxel_current_v1/voxel/12e_glacier_contiguous_ice_field_sight3.png)
- [Loch-Nahansicht](../qa/hidden_evolution_blue_release_final_20260811/full_voxel_current_v1/voxel/13b_hole_01_41_6_closeup.png)
- [Surf nach rechts](../qa/hidden_evolution_blue_release_final_20260811/full_voxel_current_v1/voxel/27b_depths_surf_mid_right.png)
- [SUMPEXNIT](../qa/hidden_evolution_blue_release_final_20260811/full_voxel_current_v1/voxel/29_depths_swampertite_claim.png)
- [final getrennter Shared-Reentry ohne weißen Rand](../qa/hidden_evolution_shared_tunnel_spacing_final_20260811/voxel/44_shared_tunnel_reentry.png)

## Finaler GREEN-Beleg

Der zusammengesetzte, ausdrücklich delta-getrennte Beleg steht im
[`GREEN-REPORT`](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/REPORT.md):

- Mechanik/Navigation 2D `e2e_final_v20_2d/`: exit 0, 1.960 Trace-Zeilen,
  29 PNGs.
- Mechanik/Navigation Voxel `e2e_final_v21_voxel/`: exit 0, 1.989
  Trace-Zeilen, 29 PNGs und 29 `worldPresent`-Receipts; alle 25 GREEN-Frames
  `FULL`, vier allgemeine Route-3/Shared-Frames.
- finale Nebeloptik 2D `opaque_outer_v23_targeted_2d/`: Sight 0/3/5.
- finale Nebeloptik Voxel `opaque_outer_v24_targeted_voxel/`: Sight 0/3/5,
  jeweils `voxelMode=FULL`, `postComposite=true` und
  `DRAMALESS_UPRIGHT_MIDPOINT`.

Seit v20/v21 wurde ausschließlich die GREEN-Post-Composite-Nebelmaske
geändert. Deshalb bleiben diese Vollruns für Navigation/Mechanik gültig; für
die Optik gelten nur v23/v24. Außenpixel sind bei Sight 0/3/5 aus den echten
PNGs dekodiert und ausnahmslos `RGBA 30,30,30,255`. Der höchstens zwei
Screen-Pixel breite Übergang liegt vollständig innerhalb des Sichtkreises;
außen gibt es keine Welttextur, Transparenz, Rasterung oder Schwaden.

Abgedeckt sind alle vier GREEN-Karten, fünf abgelegene Statuen, falsche und
frische richtige Antwort, sechs dokumentierte Decoy-Spuren, echtes CUT mit
Quellorden, gesperrtes/offenes Root- und Canopy-Gate, GEWALDRONIT+Reload,
Reset/Checkpoint, Reward, Rayquaza-Tür, Rückweg, Reentry und Shrine-Shortcut.
Der fokussierte statische Lauf besteht 3.141/3.141 Checks.

Repräsentative Originale:

- [finaler opaker Sight-0-Nebel 2D](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/opaque_outer_v23_targeted_2d/after_opaque_v23/2d/00_grove_sight_0_opaque_exterior.png)
- [finaler opaker Sight-3-Nebel Voxel](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/opaque_outer_v24_targeted_voxel/after_opaque_v24/voxel/01_mist_sight_3_opaque_exterior.png)
- [CUT-Gate offen](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v21_voxel/voxel/12_mist_root_gate_open.png)
- [GEWALDRONIT](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v21_voxel/voxel/14_mist_sceptilite_claimed.png)
- [Statue 5](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v21_voxel/voxel/19_mist_after_statue_5_full_reveal.png)
- [vollständige Route-3-Rückkehr](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v21_voxel/voxel/24_route3_return.png)

Die v20/v21-Bilder und alle älteren GREEN-Galerien sind **nur hinsichtlich
der Nebeloptik** superseded. v18 besitzt außerdem die verworfene, zu leicht
sichtbare Statue-5-Position; v22 hatte zu wenige Außenpixel-Samples. Sie
dürfen nicht als finale Nebelabnahme zitiert werden.

## Shared, Wandrisse und Wilds-Renderer

Der gemeinsame Tunnel 1920 ist 27×12 Blöcke groß und enthält drei isolierte
Schächte mit Blockzentren `3/13/23` und Eintrittszellen `x=6/26/46`. Die Schachtprofile
bleiben identisch, liegen aber so weit auseinander, dass zwischen zwei
Profilen mindestens zwölf vollständig unpassierbare Zellen und damit eine
volle native Kamerabreite solider CAVERN-Fels liegen;
ein benachbarter Pfad darf weder am Eintritt noch am Rückkehrpad ins Sichtfeld
geraten. Die finale Randdarstellung verwendet `borderBlock=3`; die inert
bleibenden unteren Füllzellen sind normalisiert, ohne Pads, Wände oder Warps
zu verändern. Die versiegelte Vorkammer 1948 besitzt drei getrennte
Rückkehrpads und den charakterspezifischen Groudon-/Kyogre-/Rayquaza-Teaser:

- [Shared-Antechamber-Abnahme](../qa/hidden_evolution_shared_antechamber_final_20260811/)
- [finaler Shared-Spacing-Report](../qa/hidden_evolution_shared_tunnel_spacing_final_20260811/REPORT.md)
- [finale Wandrisse](../qa/fissure_wall_decal_final_v2_20260811/)

Der Spacing-Report belegt sechs Warps, null Objekte, 324 Blöcke sowie echten
BLUE-Eintritt, Rückkehr und Reentry in 2D und FULL-Voxel. Zusätzliche klar als
`presentation-only` markierte 2D-Aufnahmen zeigen RED/BLUE/GREEN jeweils ohne
sichtbaren Nachbarschacht. Alle älteren Fullrun-Tunnelbilder sind nur für
diesen visuellen Abstand superseded; ihre Navigations-/Mechaniktraces bleiben
maßgeblich.

RED `(35,1)`, BLUE `(10,3)` und GREEN `(41,3)` sind transparente,
transparente Haarrisse auf geraden Felswänden. Im Voxelpfad liegen sie als
flache Wand-Decals an der vertikalen Fläche, niemals als Portal/Billboard.

Die im früheren Route-22-Voxelbild auftretenden Wilds-Warnungen sind ebenfalls
geschlossen. `tests/wilds_voxel_spawn_fx_deferred_test.lua` besteht 19 Checks;
der fokussierte Lauf unter
[`qa/wilds_voxel_spawnfx_route22_final_20260811/`](../qa/wilds_voxel_spawnfx_route22_final_20260811/)
meldet keine Pose-, Billboard- oder Emergency-Warnung und zeigt das native
Rattfratz.

## Lv.-70-Dungeonhabitate

`main.lua -> hidden_evolution_campaign.lua -> hevo_dungeon_encounters.lua`
publiziert nach dem echten, charaktergeprüften Wandriss-Eintritt alle
Registry-Eltern der passenden Farbe als Lv.-70-Habitat ab der ersten
zugehörigen Prüfungsetage. Die aktive Reiseidentität und der boolesche
`KA_HEVO_CHARACTER_TUNNEL_ENTERED_<FARBE>`-Flag müssen übereinstimmen; nur ein
bereits physisch innerhalb derselben Farbprüfung gespeicherter Altstand gilt
als sichere In-Progress-Kompatibilität. Paket-Unlocks, Statue oder Checkpoint
sind kein Ersatz für den Eintritt.
Shared-Karten, Gesehen-/Gefangen-Autogrants, Endentwicklungs-Bypass und wilde
Hoenn-Starter sind ausgeschlossen. Die sichtbaren Wilds lösen echte
Sechsframe-Sheets ohne Fallback auf; Randomizer sowie Johto-Klassik-/Visible-
Wilds-Pfade bleiben geschützt.

Statische/runtimegebundene Abnahme: `hevo_dungeon_encounters_test.lua`
1.437 PASS, `hevo_dungeon_encounters_authority_test.lua` 279 PASS,
`run_rules_test.lua` 40/40 mit Randomizer-E2E bis `battle.wild` und weiterhin
exaktem Lv. 70, Johto Signals 2.490, Wilds 251, Authority 168 und Headless 16.
Der Authority-Test lädt außerdem die drei reproduzierbaren Demo-Entrypoints,
prüft jeden Start und jede Fundwegzelle gegen echte Map-Kollision sowie GREENs
natives Gras. Der QA-Builder erzwingt in Slot und laufender Runtime `GBCFX=0`;
das globale Produkt-Feature bleibt unverändert. Das Teilpaket behauptet keine
neue Screenshotgalerie. Die visuelle Dungeon-/Spawnabnahme bleibt beim
übergeordneten Map-Gate. Diese Habitatprüfung ändert keine der oben
eingefrorenen Dungeon-Mechaniktraces.

## Historische Defektbelege

`qa/hidden_evolution_runtime_20260811/`, `defect_v2`, frühe
`hidden_evolution_blue_final_20260811/navigated_narrow`-Serien sowie
Fissure-Ordner ohne `final_v2` bleiben ausschließlich Before-/Diagnosebelege.
Die damals gezählten „18 Maps“ bestanden aus drei Kamerafokussen auf denselben
Tunnel plus 15 weitere Karten; sie sind keine aktuelle Runtimekartenzahl.

## Noch offene Releasebelege

Für den Gesamt-RC fehlen weiterhin, unabhängig vom abgeschlossenen
Kartenpaket:

1. ein echter Ruhmeshalle→Dungeon→NG+→Dungeon→NG+→Dungeon-Lauf für
   RED→BLUE→GREEN mit Save/Reload an den Übergängen;
2. sichtbare Stone-Case-/Pending-Reconciliation und exakt-einmalige
   Megasteinübergabe in der Folgereise;
3. der vierte unabhängige Gesamtregressionslauf über Hauptgeschichte,
   Ruhmeshalle, Partnerkatalog, Rivalenball, Rematches, Titel, Follower,
   Schwierigkeit und Wild-Verfolger;
4. die getrennte Johto-Neuabnahme: Die Torhalle und je eine eigene Passage+
   Finalarena für Silver/Kris/Gold sowie der unmittelbare Live-Bucket→Archiv-
   Sync sind implementiert und fokussiert geprüft; Silver-Back, fünf Wurfphasen, 64/128-
   Voxeltrainer, rechtssicherer Runtime-Track, persistente 2D-/Voxel-Goldens
   und volle R/B/Y×DE/EN-E2E fehlen;
5. die aktuelle Eich-Endgame-Neuabnahme sowie ein sauberer Release-Testbuild.
