# Kanto Ascendant 6.5 — Charakter-Testkandidat vom 10.08.2026

## Installation

1. Ältere Kanto-Ascendant-Demos im Launcher deaktivieren oder entfernen. Sie
   verwenden dieselbe Mod-ID `kanto_ascendant` und dürfen nicht parallel laufen.
2. `Kanto-Ascendant-6.5.0-phase8-character-checkpoint-test-candidate.zip`
   über den Gen1-Recomp-Launcher importieren.
3. Kanto Ascendant aktivieren und das Spiel neu starten.
4. **CRYSTAL CHARS** ist standardmäßig aktiv. Unter
   **OPTIONEN → FIGUREN-SPRITES** bleibt **ASCENDANT CHARS** als alternative
   Gen-I-Darstellung anwählbar.

## Schwerpunkt dieses Kandidaten

- Red: rote Feuerrot-Kappe mit kleinem mittigem Pokéball-Emblem, nur einem
  weißen vorderen Teil in der Seitenansicht, komplett roter Rückseite,
  schwarzem Shirt, weißer Westenmitte und gelbem Rucksack.
- Green/Casey: bereinigte Stirn- und Seitenhaare, weichere Gesichtspixel,
  grün-weiße Ohrringe, weißer Shirtstreifen, hautfarbene Hände und kleine
  dunkelgrüne Seitentasche.
- Blue: unveränderter, freigegebener aktueller Walking-Stand.

Bitte bei allen drei Figuren vorne, hinten, links und rechts jeweils stehen und
laufen. Rechts wird von der Engine aus den linken Frames gespiegelt. Die
Walking-Sprites müssen auf derselben Grundlinie bleiben und dürfen weder
springen noch schweben.

Battle-Fronten, 2D-Backsprites/Wurfanimationen und Voxel-Ganzkörperfiguren sind
absichtlich getrennte Assets. Dieser Walking-Pass hat sie nicht verändert.

Zusätzlich verwendet Green/Casey als Rivale wieder die saubere farbige
64×64-Kampffront. Die kompakte 56×56-Gen-I-Grafik bleibt auf Karten und in
Spezialszenen beschränkt; Walking-, Back- und Wurfsprites wurden dafür nicht
umgebaut.

## Technischer Checkpoint

Die drei ausgelieferten Walking-Sheets entsprechen bytegenau den freigegebenen
Mastern unter `assets/sources/characters/crystal_chars/approved_walk/` im
Entwicklungsprojekt. Maße, sechs Frames, harte Alpha-Kanten und transparente
Ecken werden automatisiert geprüft.
