# Kanto Ascendant 6.5.0 RC15

## Figuren-Regression behoben

- Eiches Charakterauswahl lädt für Grün/Casey, Blau und Rot wieder die drei
  dedizierten 128×128-HD-Ganzkörpermodelle. Sie werden erst nach der
  160×144-Spieloberfläche als pixelgenaue Bildschirm-Ebene gezeichnet. Nur
  transparenter Rand wird ausgespart; bei der Standardauflösung ist jeder
  Quellpixel exakt 3×3 Bildschirmpixel groß. Es gibt weder Halbskalierung noch
  Linearfilter oder Palettenreduktion.
- Ein alter gespeicherter Wert für **Ascendant-Feldfiguren** darf weder die
  HD-Auswahl noch Kampf-, Intro-, Karten- oder Ruhmeshallenbilder auf kompakte
  Gen-I-Grafiken zurückschalten.
- Alle 42 in Kanto verwendeten Nicht-Rivalen-Trainerklassen verwenden
  unabhängig vom Feldfigurenstil ihre nativen 64×64-Feuerrot/Blattgrün-Fronten.
- Crystal-v1.5 bleibt für Pokémon-Animationen zuständig, überschreibt aber
  keine ausgewählte Traineridentität und setzt Grün oder Blau nicht mehr spät
  auf Rot zurück.

## Nachweis

- Figurenlogik: 146/146
- Gelb-Kompatibilität: 19/19
- Crystal-v1.5: 4039/4039
- Figurenassets: 306/306
- Echter Eich-Selektor mit absichtlich altem Optionswert: 13/13
- 42 FRLG-Trainerklassen plus sechs echte Kampf-Intros: 101/101
- Strenger Modkit-Validator und `git diff --check`: bestanden
