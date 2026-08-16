# Kanto Ascendant 6.5.0 RC16

## HD-Figuren mit DRAMALESS_SHAPE repariert

- Eiches echte New-Game-Charakterauswahl zeigt Grün/Casey, Blau und Rot wieder
  mit den nativen 128×128-HD-Modellen.
- `DRAMALESS_SHAPE 1.6.2.ST` verwirft in seinem `Renderer:endFrame`-Wrapper
  den vom Spiel gelieferten Viewport. Kanto Ascendant rekonstruiert den
  fehlenden klassischen 160×144-Viewport nun aus Fenstergröße, DPI und dem
  ganzzahligen Game-Boy-Fit, ohne den externen Mod zu verändern.
- Die Modelle werden weiterhin ausschließlich ganzzahlig mit Nearest-Filter
  vergrößert. Transparente Außenränder werden für die Platzierung ausgespart;
  Bildpixel, Farben und Konturen bleiben unverändert.

## Echter Desktop-Nachweis

- Offizielle `gen1recomp-2.app` mit realem deutschem Nutzerprofil,
  `DRAMALESS_SHAPE 1.6.2.ST`, Übersetzungen und Shiny Indicators: 14/14.
- Voller Weg Titel → NEUES SPIEL → Eich → Charakterauswahl: 8/8.
- Isolierter Selektor und native 128×128-Quellen: bestanden.
- Alle 42 FRLG-Trainerklassen plus sechs Kampf-Intros: 101/101.
