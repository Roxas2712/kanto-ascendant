# Kanto Ascendant 6.5.0 RC21

## Deutsches Editionsband unter Engine 0.1.76

- Behoben: Engine 0.1.76 animiert kontinuierliche lokalisierte Editionsbänder
  beim Start selbst von rechts herein. Der ältere Deutsch-Kompatibilitätscode
  zeichnete gleichzeitig ein zweites festes „ROTE EDITION“-Band.
- Kanto Ascendant erkennt jetzt den neuen `versionFull`-Renderpfad und lässt
  dort ausschließlich die native Engine-Animation zeichnen.
- Auf älteren Engine-Versionen bleibt der bisherige deutsche Vollband-Fallback
  unverändert aktiv.
- Auch Crystal- und Fallback-Titelgrafiken werden abschließend auf ihre Form
  geprüft; ein 8-Pixel-Editionsband kann nicht als bewegtes Pokémon erscheinen.

## Abnahme

- Getestet im tatsächlich installierten macOS-App-Build mit Engine 0.1.76,
  Deutsch 2.1.6 und Kanto Ascendant 6.5.0.
- Der komplette Bootablauf wurde rechts, während des Einflugs und nach der
  Landung aufgenommen. In allen Phasen ist genau ein Editionsband sichtbar.
- Der ältere lokale Enginepfad wurde zusätzlich mit natürlichem Pokémonwechsel
  sowie absichtlich fehlerhaften Crystal- und Fallback-Grafiken geprüft.
