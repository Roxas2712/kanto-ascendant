# Männliche Mondberg-Crew – lokales Charakterpaket

Vorlage: vorhandenes `youngster_voxel_front_hd_v2.png`; Glatze, türkisfarbenes
Oberteil, dunkle Shorts, passende Schuhe. Die Vorlage bleibt unangetastet.
Neue Richtungen und Posen mit dem eingebauten Imagegen erzeugt, keine Änderung
von Pokémon-Grafiken oder normalen Teenager-Trainern.

- `source/`: unveränderte ausgewählte Imagegen-Master (Walk, Blink, Aktionen).
- `PROMPTS.json`: vollständige Prompts und ursprüngliche Speicherorte, einschließlich
  der Transparenz-Nachbearbeitung. Kein CLI-/API-Fallback verwendet.
- `walk.png`, `blink.png`: 16×96, native Stand-/Schrittansichten vorn/hinten/links.
- `cards_4x3.png`, `cards_blink_4x3.png`: 495×900, alle vier Richtungen,
  Stand und zwei Schritte. Der Körper bleibt beim Blinzeln unverändert.
- `battle_56_*`, `battle_128_*`: sechs Porträts; Stand, Blinzeln, fünfteiliger
  Wurf mit sechs nativen Ticks pro Pose und Leerhand nach Freigabe.
- `battle_heroes_3x10.png`: VASC-Richtungen, Aktionen und Blinzelreihen.

Reproduzierbarer Engine-Packer: `qa/bald-crew-male-20260916/bake/main.lua`,
Umgebung `BALD_ART_ROOT` auf diesen Ordner setzen und mit LÖVE ausführen.
Die festen Zuschnitte wurden an den tatsächlichen zusammenhängenden Figuren
ermittelt; die visuelle Rasteraufteilung des Masters ist nicht pixelgenau.
Native Ausgaben verwenden Nearest-Sampling und binäres OBJ-Alpha.

`bald_crew_67_male_character.lua` bindet denselben geprüften Animationsadapter
wie Fabelle an sieben eigene Trainerklassen. Namen und persönliche Teams
bleiben getrennt; der Charakter-Adapter erzeugt keine Teams. Fabelle behält
ihren eigenen Körper, ihre eigenen Assets und die zwei Augenfarben.

Lokaler Implementierungsstand, keine Veröffentlichung oder Gesamtabnahme.
