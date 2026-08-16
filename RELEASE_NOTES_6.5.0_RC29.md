# Kanto Ascendant 6.5.0 RC29 – Handoff-Kandidat

Stand: 14. August 2026. Diese Notizen beschreiben den vorbereiteten RC29-
Testkandidaten nach der manuellen RC28-Abnahme. MANUAL-004 ist mit dem finalen
64px-Gorochu-Satz `READY`; TEST-RC Fehler 1–9 sind repariert und fokussiert
verifiziert. Der Gesamtstand ist **TESTKANDIDAT / FIXED_001_009 /
JOHTO_VISUAL_RETEST_REQUIRED**: Johto 3–6/9 ist statisch und funktional grün,
benötigt nach einem Setup-/Harness-Abbruch aber noch einen bereinigten echten
Visualretest. Das geprüfte Mod-only-Paket ist ein Test-RC, ausdrücklich kein
finaler Release.

## Feste Produktgrenze

- Gegenstand ist ausschließlich die Mod **Kanto Ascendant**.
- Engine, `game.love`, Gen1-Recompiler und Desktop-/Mobile-App gehören nicht zu
  diesem RC und wurden nicht verändert.
- ASH und BLITZ wurden nur gelesen. Schreibende Prüfungen liefen mit Kopien
  oder frischen Wegwerf-Identitäten.
- Die freigegebene **Charakterauswahl ist unverändert**: keine Änderung an
  Bildern, Assets, Layout, Farben, Reihenfolge, Texten oder Eingaben.
- Es wurde kein vollständiger 192-Zellen-Lauf als Abschlussbedingung gestartet.
  Reparaturen wurden mit den jeweils engsten relevanten Tests und kurzen echten
  Laufzeitbelegen geprüft.

## Manuelle Meldungen 001–021

Die Klassifikation verwendet `BUG`, `FEATURE_REQUEST`, `SUPPORT`,
`COMPATIBILITY` und `NO_ACTION`. „Grün“ bedeutet den unten angegebenen
fokussierten Nachweis, nicht einen behaupteten Komplettdurchlauf des Spiels.

| ID | Klassifikation | Ergebnis im RC29-Handoff | Status |
|---|---|---|---|
| MANUAL-001 | BUG | Titel bewahrt die vollständige native editionsabhängige Pokémonrotation. Nur ein echter Spezieswechsel rotiert Green/Blue/Red einmal; Trainer und die aktuelle beliebige Spezies werden atomar publiziert und diese nutzt ihren gebündelten animierten Crystal-Satz. | GRÜN – echter Wegwerf-LÖVE-Lauf 9/9, Rot-Zyklus vor/nach 16/16 identisch |
| MANUAL-002 | BUG | HEVO-Forscher erscheinen nach der Liga auch in Altständen korrekt; Legacy-Red, belegte Primärzellen, Reload und Duplikatschutz sind abgedeckt. | GRÜN – 377 Assertions |
| MANUAL-003 | BUG | Altstände lösen den freigegebenen Red-Spieler und Erika V2 ohne stillen Ersatz auf; Renderer-Version und Provenienz werden fail-closed geprüft. | GRÜN – echter FULL-Lauf mit installierter DRAMALESS_SHAPE 1.6.2.ST, 12/12, 0 Fallbacks |
| MANUAL-004 | BUG | Frühere Eigenentwürfe bleiben REJECTED; 56px/d804 bleibt `SUPERSEDED INTERMEDIATE`. Der finale P-Infinity-basierte 64px-Satz hält den Schweif in allen Frames verbunden, ist mit 40 Assets/22.622 Checks grün und bestand einen echten 2D-Einzelkampf mit 44 Dateien, Normal/Shiny/Classic je Frame 1→3 und 6/6 Bildern. | **READY** – finaler 64px-Echtlauf PASS |
| MANUAL-005 | BUG + FEATURE_REQUEST | Silver-Standee wurde über die konfigurierte Bossposition tiefer als die native Raumvorgabe verankert; die drei physischen Rätselwege sind unterscheidbar und erklärt. Echte 2D-Räume und Battle-Intros belegen die unterschiedlichen Farb-/Raumthemen. | GRÜN – fokussierte Verträge plus echter 2D-Lauf |
| MANUAL-006 | BUG | Silver, Kris und Gold führen jeweils ihren Johto-Starter; Silver/Kris besitzen ihr Mega-Ziel, Gold exklusiv Tornuptos Ascendant-Form. | GRÜN – Passagen-/Cadence-/Mega-Verträge |
| MANUAL-007 | BUG | Jeder Finalraum registriert exakt einen Meister-Actor; es gibt kein verstecktes Siegelobjekt mehr, das als zweiter Trainer erscheint. | GRÜN – Strukturtest und echter 2D-Raum-/Intro-Lauf |
| MANUAL-008 | BUG | Der echte Lauf bestätigte den Softlock: normaler `tile 160` auf `(9,21)`, daher feuerte der native Warp nicht. Ein produktseitiger `onStep`-Exit führt nun sicher nach `INDIGO_PLATEAU_LOBBY (7,10)`. | GRÜN – physischer Lauf `(9,19)→(9,20)→(9,21)→Lobby` |
| MANUAL-009 | BUG | ASC-LAUF mit Randomizer-/Nuzlocke-Regeln ist an jedem Player-PC erreichbar und bleibt nach Beginn schreibgeschützt. | GRÜN – 56/56 + 26/26 |
| MANUAL-010 | BUG | SELECT-Hilfe und Item-Umordnung koexistieren: SELECT zeigt Hilfe; START/R3 öffnet Item-Aktionen mit Verschieben, Schnellwahl und Sortierung. | GRÜN – 126/126 + 13/13 + 37/37 |
| MANUAL-011 | BUG | Eichs Intro verwendet ausschließlich den freigegebenen Oak/Eich-V1-Satz mit versionierter Provenienz. | GRÜN – echter Intro-Renderer |
| MANUAL-012 | BUG | Nidorino ist an den 21-Frame-Crystal-Satz gebunden, auch wenn ein Kompatibilitätspfad die Demo-Spezies spät ersetzt. | GRÜN – echter Frame 1→2, verschiedene Pixelhashes |
| MANUAL-013 | NO_ACTION | Für den subjektiv schwereren Startkampf wurde kein deterministischer Mod-Balancefehler gefunden. Standardlevel und -teams bleiben unverändert; der QA-Treiber verlangt jetzt ausdrücklich einen Sieg. | VERIFIZIERT – kein unbelegter Balanceeingriff |
| MANUAL-014 | BUG | Frühes Johto bleibt bis zur tatsächlich reparierten Driftglas-Empfangsstation gesperrt; `save.created` leert fortgeschrittene Slot-Caches. | GRÜN – 2501 + 217 + 273 Assertions |
| MANUAL-015 | COMPATIBILITY | Der Replacement-Vertrag für integrierte Altmods ist grün. Eine bereits laufende alte App-Sitzung muss vollständig neu gestartet werden; unsicheres Hook-Entladen wird nicht in die Mod eingebaut. | GRÜN nach Neustart; kein Engine-/App-Fix |
| MANUAL-016 | BUG | Der Bootsmann übernimmt keinen gebrieften Zustand mehr aus einem zuvor geladenen fortgeschrittenen Slot. | GRÜN – Cross-Save-Reset-Vertrag |
| MANUAL-017 | BUG + FEATURE_REQUEST | Alle `KA_JOHTO_*`-Karten sperren sichtbare, ambiente und klassische Wildbegegnungen. Die Hallentore stehen bei `(5,15)/(9,15)/(13,15)`; historische Kartenmaße bleiben zur Altstandssicherheit erhalten. | GRÜN – echter 2D-Hallenlauf mit Null-Wilds-Ambient-Assertion |
| MANUAL-018 | SUPPORT | BLITZ und ASH sind aufgrund fehlender kanonischer Voraussetzungen legitim noch nicht für „REISE STARTEN“ berechtigt. Ein nichtdestruktiver Wegwerf-ID-Lauf erreichte PC, Eich, vier Pakte und vier Bankregeln. | GRÜN – 16/16; Legacy-Kern unverändert |
| MANUAL-019 | BUG | Silver, Kris und Gold besitzen verschiedene physische Sequenzen und erklärende Hinweise statt dreimal desselben 1→2→3-Schemas. | GRÜN – Passagen-/Cadence-Verträge |
| MANUAL-020 | BUG | Golds Belohnung nutzt echte Gen-II-Shiny-DVs, bleibt nach nativem Save/Reload shiny und zeichnet die sichtbare Kennzeichnung; Doppelcallback und Reload erzeugen kein zweites Geschenk. | GRÜN – unabhängiger Reward-/Reload-Audit |
| MANUAL-021 | NO_ACTION + FEATURE_REQUEST | Die bestehende Farmregel ist bestätigt: ein neuer Silver→Kris→Gold-Zyklus verlangt Top Vier + Champion und genau einen zusätzlichen Ruhmeshallen-Eintrag. Nach tatsächlich zugestellter Gold-Belohnung erklärt eine eigene DE/EN-Seite diese Voraussetzung nun unübersehbar; Pending bleibt unverändert. | GRÜN – unabhängiger BLITZ-Klon-Audit plus enge UX-Härtung |

## Gezielte reale Laufzeitbelege

- Titel: vollständige native editionsabhängige Pokémonrotation bleibt
  engine-owned. Echter Rot-Titelrenderer mit Green+Charmander,
  Blue+Nidoran♂, Red+Sichlor und Green+Ditto; drei Nicht-Starter,
  Trainer-Wrap und atomare Identitätsspur, Laufreceipt 9/9.
- Eich/Nidorino: freigegebener Oak V1 und zwei verschiedene echte
  Nidorino-Crystal-Frames; 7/7.
- Trainerdarstellung: Legacy-Red und Erika V2 gemeinsam im echten FULL-
  Trainerintro gegen die installierte unveränderte DRAMALESS_SHAPE 1.6.2.ST;
  12/12, `fallback_receipts=0`.
- Vermächtnisreise: frische Wegwerf-Identität bis zum nichtdestruktiven
  Bankregelmenü; 16/16, keine Archivtransaktion und kein Nutzer-Save-Write.
- Johto Masters: echter 2D-Hallenlauf mit logisch angeordneten Toren,
  Null-Wilds-Ambient-Assertion und physischem Exit in die Indigo-Lobby; echte
  Silver-/Kris-/Gold-Räume und Battle-Intros mit exakt einem Meister pro
  Finale.
- Johto Reward/Cadence: bytegleicher BLITZ-Klon, kanonisches DV-Shiny,
  doppelcallback- und reloadfeste Exact-once-Zustellung sowie genau eine neue
  Ruhmeshallen-Zeile pro weiterem Silver→Kris→Gold-Zyklus. Silver/Kris nutzen
  ihre Megas, Gold exklusiv `TYPHLOSION_ASCENDANT`.
- HEVO-Freischaltung: Vor dem Gate und bei falscher Figur weder Forscher noch
  sichtbarer/interaktiver Riss; nach dem passenden Forscherdialog der richtige
  Riss einschließlich Shared-Tunnel-Übergang. Autoritative Zuordnung:
  Aster/Celadon→Route 22, Linden/Pewter→Route 3, Nera/Cinnabar→Route 24.
  `hidden_evolution_professor_discovery_gate_test.lua` 458, echter
  Fissure-LÖVE-Lauf, `hidden_evolution_shared_tunnel_test.lua`,
  `hidden_evolution_campaign_authority_load_test.lua` 220 und
  `hidden_evolution_campaign_fixture_gate_test.lua` 3/3 sind grün.
- Johto 3–6/9: Passages, Cadence, Battlefields, Package-Contract,
  Host-Handoff, Music Unit/Legacy/Authority 19/19, Syntax und Diff-Check sind
  PASS. 36/36 Poolplätze und Versuch 1 mit 18/18 Pokémon sind
  trainerübergreifend eindeutig; Silver führt Impergator+Entei, Kris Meganie,
  Gold exklusiv Tornupto-Ascendant. Räume, 18 disjunkte DE/EN-Fragen,
  Quizhosts, Finalgegner und echte Step-Exits erfüllen den Funktionsvertrag.
- Gorochu 2D, **nur Zwischenstand**: P-Infinity-basierte native 56×56-Pixelart
  mit 40 Assets; Normal/Shiny und neutrales Vierfarb-Schwarz-Weiß, Front/Back,
  sechs Zustände. Ein echter einzelner 2D-Kampf wechselte alle drei
  Darstellungsstufen am lebenden Battleobjekt und endete mit 6/6 Screenshots
  technisch als PASS; nur Wegwerf-Identität, keine Nutzer-Save-Schreiboperation.
  Dieser Satz ist wegen der neuen 64px-/Schweifvorgabe ausdrücklich
  `SUPERSEDED INTERMEDIATE` und keine MANUAL-004-Abnahme.
- Gorochu 2D, **final**: P-Infinity-basierter 64px-Satz mit 40 Assets und
  durchgehend verbundener Schweifgeometrie. Ein echter Rot/2D-Einzelkampf band
  44 Dateien, belegte Normal/Shiny/Classic und Front/Back jeweils Frame 1→3 und
  schrieb 6/6 Bilder. Keine Clippingkante, stimmige Bodenlinie, klare
  Normal-/Shiny-Trennung ohne Cyan und neutrale Vierfarb-Schwarz-Weiß-Figur;
  nur Wegwerf-Identität, keine Nutzer-Save-Schreiboperation.
- Autoritative gebündelte Mod-Suite 7235/7235 und aktualisierter
  UI-Integrationsvertrag 35/35.

Die Bild- und Laufbelege stehen im RC29-Handoff-Verzeichnis unter
`qa/rc28_manual_fixes_20260814/`. Die früheren Gorochu-Zwischenstände bleiben
ausdrücklich **verworfen**. Auch der spätere 56px-Kontaktbogen und seine sechs
d804-Bilder sind nur `SUPERSEDED INTERMEDIATE`. Ausschließlich der getrennte
64px-Kontaktbogen und die sechs e861-Bilder unter `images/gorochu_final/`
belegen MANUAL-004.

## Relevante geprüfte SHA-256-Werte

| Artefakt | SHA-256 |
|---|---|
| `title_intro.lua` | `f328f6d7bd81d528ee0729721ddc81221b7384b9f8a3c52b1a0ba3f7debe5c4e` |
| `crystal_animation.lua` | `7a74b35b3406dc9677015daee1a684995fc3522e54f486477510a7ca3c87be7d` |
| `crystal_v15_features.lua` | `1d4e4d8765e6805d0c5c606efac7bf5c0c91f47aa3a4c755ed0cd58edd9d8163` |
| `egg_hatch_animation.lua` | `4a128c2308ce875a3f167cc11e07a10d65918ebd3ee7fc3b46dcffa6ac0ea008` |
| `hidden_evolution_architecture.lua` | `ab8eb6a917ac1d880aab68574ed3c49de1531097246409aa691c17ce2e3f25fe` |
| `hidden_evolution_story_hints.lua` | `2d84dc9343bee08cb290d887164e2733e0f15a0d2f558e32c6f3c8ab46e42a1a` |
| `extended_characters.lua` | `9d01c6b6b6885759f93b908879241fe8feeb3c886c97271db2c85c37e0f644d8` |
| `voxel_renderer_compat.lua` | `b7466980616a63a02a49fbce5050d8b5e7865a56cffeba8c5487739a91fc1742` |
| `manifest.json` | `95474d853cff233aa06b60574a44979aac241f60318c3698fd51813b5a645470` |
| `johto_masters_passages.lua` | `2115c7593d552069a4b19bb702697f0bff8daee35b8ace12cd0ca67644bca769` |
| `johto_masters_data.lua` | `d92c521314ffed0cd2e081a226db138bd4999507063f45656f769631e08213b8` |
| Silver `arenaAuthority` alt/neu bytegleich | `5531b36e41e8b66b7a029e46b9aee5bb82fdbca84f55fbcdb791ef71b8d35579` |
| `johto_masters.lua` | `80f361476016948d9d4369b9a0429618583cb46df439e95d18d4e08ca0aff1bf` |
| `README.md` | `3077d4e5eb1fd49e5ac989893053c5d79a1418b80da56b974645dadb6a40a690` |
| `FAQ.md` | `51a6539ccf359e21b463b856aa06d1dd53d7d062046755c3363035119cca0c8d` |
| TEST-RC 1 nativer Titelzyklus-Laufreceipt | `28cca03cd89a67908f79b593059e67496342142025c1dcd4531a12c87f15fd3a` |
| TEST-RC 2 Ei-Schlüpf-Laufreceipt | `15243d62bb02d3d7b3f0a87c2f12e46f13935396e48f3bf8a068fc2f0e8a6a35` |
| TEST-RC 7/8 Fissure-LÖVE-Laufreceipt | `8dd3b17c0111a1e9d4e1ac80021a0ec3af2c94bb71cab6ccc7822dd69556d27d` |
| TEST-RC 7/8 vor Gate / passender Forscher | `f096f48d56e3aa9e1bbada40918d834a387a3224cd1e702a695e5d2071595399` / `9378972d1d273667879bae09aab10fb56f123df7cc3e25e1dc997e2f52431ecb` |
| TEST-RC 7/8 gelöster Riss / falsche Figur | `c3e69fcb65ba9525fb67e642d26a1215ceeb42bce59d378047e71677ec3d75fd` / `cc138ead0e73d865df41a09b0b78cb34884e8caf350ab896afe81738eb95da80` |
| Johto-Visualretry-Log, Setup-/Harness-Fail | `61b58650eb732707ebc3fe1d1dd20066376f269a23d038d6503e0e7029a19956` |
| RC29 TEST FIXES 001–009 `.modpkg` / `.zip` | `2a64d9b28a3a68a24fdc477d32b4bb33eebaa8e10d521205dedc713602c6548a` / byteidentisch; je 39.233.927 Byte |
| FULL Red/Erika-Laufreceipt | `55031f8dd291881215ca369d4900df097eda87a6aa5b9ae82789e8e3d79b7050` |
| Johto-Torhalle 2D | `92ef0e0e88fb7ae63a473de57791d1e6aea5d1e6741a4b4cfe5145bd8dcd761d` |
| Silver-Finalraum 2D | `5e0852389330c1da137b24774d34cc410f4db748ff75f07e97a5fcf25468add8` |
| Kris-Finalraum 2D | `87452ce42d48d9ae5fcb65877719d15d6a9c624a0dc9280f734c46853b324d42` |
| Gold-Finalraum 2D | `5508c0a370bab08990b9c5b7700e56af441d5e84726b5dcdb867f4e52ef76d98` |
| Autoritative gebündelte Mod-Suite | `5617d5282652bf251c2d54a2109e1e7c7e25302421cdd0e303ff99205323be23` |
| `tests/johto_signals_ui_integration_test.lua` | `0c477f97838926d85fd74f3353c527d25c78939b083e22a61e1464cb93b10ae4` |
| Gorochu 56px-Zwischenstand, 40-Asset-Kontaktbogen | `1d8e40fd1e9855524fc03177d2a8f30022042558fc624f7eebf8e7796e526b1c` |
| Gorochu 56px-Zwischenstand, echter 2D-Laufreceipt | `5143373549a3f2badfc2868e32e1f888635704f0097266bd0cfdf7362afddd24` |
| Gorochu 64px-40-Asset-Kontaktbogen | `4efe9856e93cfe87b9c28e6f7db0faea11d69a9ae0b7f781bf925353b1829e30` |
| Gorochu 64px-Identitäts-/Matrix-Digest | `bdf3c899da9437bda72b24cf3107f36d6487dc8fecbad504ceed9f136bd5acc3` |
| Gorochu finaler 64px-2D-Laufreceipt | `2dfbf68e8e1ac0f735bd08922d973e88abf829b950aafcb1a8487a53cc38ec4d` |
| Gorochu final Normal-Rücken/Shiny-Front A | `7f2bc53acaefbda3af72dbc754f9246ddc4b21d9e413ea89e7bd974b967c56a9` |
| Gorochu final Normal-Rücken/Shiny-Front B | `3a72e1d25918ec29d64ca65e6dc32288893edcd26a84624e68f126f0dcbbfbc9` |
| Gorochu final Shiny-Rücken/Normal-Front A | `0338d800b908748a73b120a342fd5df3dd1b78131fa01004bf82584781ace6e6` |
| Gorochu final Shiny-Rücken/Normal-Front B | `482fd04ed545dac824c887eccd6641846a42426bec2a227d8f67c30285c5bdc2` |
| Gorochu final Classic-Grayscale A | `ba60e35fd3d96dd87f23baeab6b5f7388a89193405cddedae419e848c6dd7747` |
| Gorochu final Classic-Grayscale B | `59d86ffece48f41f500146530e5629b1c381ee8feb80bdbeead4d04c922d4357` |

Diese Werte bezeichnen den fokussierten Stand. Die ausdrücklich als 56px
benannten Werte bleiben Zwischenstandsbelege; Kontaktbogen, Matrixdigest,
e861-Receipt und die sechs als „final“ benannten PNGs gehören zum abgenommenen
64px-Satz. Nur die ausdrücklich als RC29 TEST FIXES benannte Zeile ist die
Paketprüfsumme.

## Separate TEST-RC-Sammelrunde

- **TEST-RC Fehler 1 – FIXED / VERIFIED:** Vor dem eigentlichen
  Titelpaarwechsel flashte der Trainer A→B→C; das bewegte Pokémon verwendete
  laut Nutzerbeobachtung die falsche Crystal-Animation. Nutzerbild-SHA-256:
  `32107191fe4ef7ec8080d06a6fb993d04ff1a17cb862dba3ab59bc93fe1cae25`.
  Die Diagnose bestätigte: Der Trainerindex wurde bei
  jedem Timer-Reset weitergeschaltet, während der native Übergang den Timer
  mehrfach zurücksetzt; die Crystal-Titelwahl ist zudem Options-/Fallback-
  abhängig. Der Fix schreibt `cycleSpecies` nirgends und bewahrt die
  vollständige native editionsabhängige Rotation. Nur ein echter
  Index-/Spezieswechsel rotiert Green→Blue→Red einmal und publiziert Trainer
  plus beliebige aktuelle Spezies atomar; deren gebündelte Crystal-Animation
  ist der fail-closed Titelpfad. Statischer Vertrag PASS, Crystal 4055/4055,
  echter Wegwerf-LÖVE-Lauf 9/9 mit Rot-Liste vor/nach 16/16 identisch, drei
  Nicht-Startern und Trainer-Wrap. Receipt `28cca03c…`; vier PNGs:
  `a3af7e51…`, `4a1aed0b…`, `38d559da…`, `0b8a5484…`.
- **TEST-RC Fehler 2 – FIXED / VERIFIED:** Die Ei-Schlüpf-Grafik erschien
  nahezu schwarzweiß/ausgewaschen, mit abgelösten violetten Fragmenten.
  Nutzerbild-SHA-256:
  `cba6302878a55d38be0e328e0449c01299a8642b422fec17591020fb51800f2b`.
  Der Flood-Cutout bewahrt nun True Color; neutrale Schalenfragmente existieren
  nur im Reveal-Fenster und sind ab Cleanup sowie während der Nachricht weg.
  Statischer Vertrag PASS, In-Memory-Lauf 9 Checks, Breeding 36/36 und echter
  Wegwerf-LÖVE-Lauf 4/4 mit drei PNGs `30675327…`, `33362634…`, `7ccc7eba…`.
  Receipt `15243d62…`.
- **TEST-RC Fehler 3 – FIXED / STATIC + FUNCTIONAL VERIFIED:** Kompakte
  sichtbare Torreihe, beschriftete Ausgangsplatten und echte Step-Exits. Der
  ursprüngliche Nutzerbeleg bleibt Ausgangsbild; neuer Visualretest nötig.
- **TEST-RC Fehler 4 – FIXED / STATIC + FUNCTIONAL VERIFIED:** Erklärte
  Drei-Fragen-Prüfungen mit 18 disjunkten DE/EN-Fragen und ohne Wiederholung
  im verbundenen Lauf; neuer Visualretest nötig.
- **TEST-RC Fehler 5 – FIXED / STATIC + FUNCTIONAL VERIFIED:** Alle 36 Pools
  sind trainerübergreifend eindeutig, Versuch 1 ist 18/18 eindeutig. Silver
  führt Impergator+Entei, Kris Meganie, Gold exklusiv Tornupto-Ascendant.
- **TEST-RC Fehler 6 – FIXED / STATIC + FUNCTIONAL VERIFIED:** Passage-,
  Cadence-, Package-, Host-Handoff- und Musikverträge sind PASS; neuer
  Visualretest nötig.
- **TEST-RC Fehler 7 – FIXED / VERIFIED:** Der Nutzerbeleg zeigte vor dem Gate
  einen dunklen Hoenn-/Hidden-Evolution-Höhlenriss (SHA-256
  `6f046bdbe026c3c7fdd48d6aadd7f96dbba547ce41b9af9833b61e8e81ddc7a2`).
  Der finale Vertrag hält Wand und Interaktionsziel vor Freischaltung sowie bei
  falscher Figur vollständig verborgen. Erst der gelöste passende
  Forscherdialog schaltet den zugehörigen Riss sichtbar, interaktiv und
  passierbar. Echter Vierbild-Lauf plus Professor 458, Shared Tunnel,
  Authority 220 und Fixture 3/3 sind grün.
- **TEST-RC Fehler 8 – FIXED / VERIFIED:** Die Forscherkette ist autoritativ
  zugeordnet: Professor Aster in Celadon öffnet Route 22, Professor Linden in
  Pewter Route 3 und Professor Nera auf Cinnabar Route 24. Nur die passende
  Figur nach dem vorgesehenen Gate sieht den jeweiligen Forscher; falsche
  Figuren erhalten weder Forscher noch Riss. Architektur `ab8eb6a9…`,
  Story-Hints `2d84dc93…`, Fissure-LÖVE-Receipt `8dd3b17c…`.
- **TEST-RC Fehler 9 – FIXED / STATIC + FUNCTIONAL VERIFIED:** Drei kompakte
  farblich getrennte Räume, genau ein Quizhost und Finalgegner je Weg, Gold
  ohne Treppentextur-Spam und 18 getrennte DE/EN-Fragen. Silver-FULL bleibt
  bytegleich **HARD LOCK / DO NOT CHANGE**; neuer Visualretest nötig.

Fehler 1–9 sind repariert und fokussiert verifiziert; 3–6/9 besitzen derzeit
einen statischen und funktionalen PASS, aber noch keinen neuen echten
Visualbeleg. Keiner der Punkte ändert MANUAL-004 `READY`. Die geschützte
Charakterauswahl blieb vollständig unangetastet.

Die konkrete Red-/Silver-FULL/Voxel-Kampfinszenierung ist dagegen vom Nutzer
**APPROVED / DO NOT CHANGE**: Darstellung, Positionen, Größen, Farben und
Raumoptik sind geschützt. Lock-Screenshot-SHA-256:
`9baeadfd5b16786efa7695ee8882800d8f55b6727f6461d300aa34d1bda299f7`.
Dieser Lock schließt Fehler 3/4 nicht; spätere UX-/Rätselkorrekturen müssen ihn
unverändert lassen.

## Noch offen vor finaler Freigabe

1. Bereinigter echter Johto-Visualretest ohne die doppelte alte Mod-ID. Der
   einzige Retry endete vor der ersten Bildaufnahme als Setup-/Harness-Fail;
   Log-SHA-256 `61b58650eb732707ebc3fe1d1dd20066376f269a23d038d6503e0e7029a19956`.
2. Der Mod-only-Test-RC (`.modpkg` und byteidentische `.zip`, je 39.233.927
   Byte, SHA-256 `2a64d9b28a3a68a24fdc477d32b4bb33eebaa8e10d521205dedc713602c6548a`)
   ist für gezielte Tests gebaut: `unzip`, 28.740 Manifesthashes und
   Ausschlussprüfung PASS. Er ist ausdrücklich noch kein finaler Release.

## Bewusste Testgrenze

Nicht ausgeführt wurden ein vollständiger 192-Zellen-Zertifizierungslauf, ein
natürlicher Durchlauf von „Neues Spiel“ bis Legacy-Ende und jede Kombination
aus Edition, Sprache, 2D/FULL, Pakt und Bankregel. Diese Grenze ist kein
verdeckter grüner Komplettlauf; der Handoff stützt sich auf die fokussierten
Regressionen der tatsächlich berührten Modpfade.
