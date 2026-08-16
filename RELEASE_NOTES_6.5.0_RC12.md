# Kanto Ascendant 6.5.0 RC12

RC12 baut auf dem kombinierten RC11-/Crystal-v1.5-/Phase-8-Stand auf. Das
unveränderte RC11-Testpaket bleibt als direkter Rückweg erhalten.

## Korrekturen

- Gespeichertes **GAME SPEED** wirkt erst ab dem eigentlichen Gameplay. Titel,
  Eich-Intro, Figurenwahl und Namenseingabe laufen immer mit 1×.
- Neue 6.5-Profile starten mit der vollständigen Crystal-Pokémon-Darstellung.
  Crystal-Animationen sind damit bereits auf dem Titelbild und bei Eichs
  Demo-Pokémon aktiv. Bestehende, bewusst geänderte Optionen bleiben erhalten.
- Die doppelte, widersprüchliche Definition der Team-Icon-Option ist entfernt.
  **ANIMIERTE ARTEN** registriert wieder für jedes Pokémon #001–251 ein
  eigenes bewegtes Icon, ohne dass FollowerEX installiert sein muss. Die
  vorübergehend gespeicherten Werte `species/classic` werden verlustfrei auf
  `animated/original` übernommen.
- Im Voxel-Modus werden die farbigen Crystal-Frames verwendet, auch wenn für
  die flache Darstellung die GBC-Palette gespeichert ist. Pikachu und andere
  Pokémon erscheinen dadurch im farbigen Voxel-Kampf nicht mehr grau.
- Die Figurenwahl lädt für Grün/Casey, Blau und Rot exakt das jeweilige
  Frontbild, das auch die aktive Battle-Darstellung verwendet.
- Der Pokémon-Geschlechtsmarker besitzt im Kampf ein eigenes HUD-Feld. Er kann
  weder einen dreistelligen Levelwert noch `PAR`, `PSN`, `SLP`, `BRN`, `FRZ`
  oder einen anderen Status überschreiben. Das gilt für 2D und Voxel.
- Die frühe Ho-Oh-Vision kann nur noch im südlichen hohen Gras von Route 2
  zwischen Vertania City und dem Vertania-Wald erscheinen. Nördliches
  Route-2-Gras, Wald und Torhaus sind ausgeschlossen.
- Ho-Oh erscheint ausschließlich in dieser Vision golden. Das spätere
  fangbare Ho-Oh und alle anderen Ho-Oh-Darstellungen bleiben unverändert.
- Eine Niederlage gegen die Ho-Oh-Vision stellt das Team wieder her und nutzt
  den normalen Blackout-Weg zum zuletzt besuchten Pokémon-Center. Die
  begrenzte Nuzlocke-Ausnahme bleibt nur während der Visions-Faint-Callbacks
  aktiv und kann den Run deshalb nicht beenden.

## Ho-Oh-Wahrscheinlichkeit

Die Chance beträgt **1 % pro geeignetem Schritt** im südlichen Route-2-Gras
bei den Kartenkoordinaten X 4–9 / Y 48–51. Die Vision kann pro Spielstand nur
einmal stattfinden und Ho-Oh ist dort nicht fangbar.

## Rückweg

Vor einem Rückweg Spiel und Mod schließen und den Spielstand sichern. Danach
RC12 deaktivieren/entfernen und das unveränderte RC11-Testpaket erneut
importieren.
