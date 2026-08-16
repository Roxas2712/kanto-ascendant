# Kanto Ascendant 6.5.0 RC10

- `CRYSTAL CHARS` is now a complete FireRed-style character modelpack: native
  16×16 field animation for Red, Blue and Casey, higher-detail 64×64 player
  fronts, and native 64×64 FRLG fronts for every used Kanto opponent class.
- 2D battles use one coherent set of five-frame 64×64 upper-body Poké Ball
  throws for Red, Blue and Casey. Voxel battles instead use dedicated
  128×128 standing art on a 320×288 trainer billboard, retaining readable
  faces, complete shoes and mirrored player-side facing.

## Behoben

- Die interne ID lautet jetzt `kanto_ascendant`; der eigenständige
  `trainer_rematch`-Mod wird als Konflikt erkannt.
- Bestehende Kanto-Ascendant-Spielstände und Optionen aus RC9 werden vor den
  normalen Migrationen übernommen. Jeder spätere Speichervorgang hält eine
  getrennte RC9-Rollback-Kopie aktuell.
- **Einfache Interaktionen** bleibt im finalen Optionsschema erhalten und ist
  ohne vorhandenen Profilwert standardmäßig aktiv. Dadurch funktionieren
  A-Tasten-Interaktionen mit VM-Zielen wieder, darunter Zerschneider-Bäume.
- Der deutsche Eintrag heißt kompakt **GOROCHU-APP**. Alle vier Statusseiten
  wurden auf Gen-I-sichere Zeilenlängen umgebrochen.
- Gen-II-Geschlecht erscheint nun auch in beiden Kampf-HUDs. Der feste
  Nidoran♀-/Nidoran♂-Sonderfall und geschlechtslose Arten sind separat
  abgesichert.
- Eier besitzen nun eine vollständige Schlüpfsequenz mit Wackeln, Rissen,
  Schalenfragmenten, Pokémon-Enthüllung und Schrei. Die bestehende
  Breeding-/Save-Logik bleibt der alleinige Finalisierer.

## Installation

Wegen der ID-Korrektur muss die alte RC9-Installation vor dem Import aus dem
`mods`-Ordner verschoben werden. Die vollständige Anleitung einschließlich
Rollback steht in `INSTALL_6.5.0_RC10_DE.md`.
