# Kanto Ascendant 6.5.0 RC18

## Behoben

- Pokémon Rot zeigt nicht länger gleichzeitig das in einer fremden
  Gelb-Grafik eingebrannte „GELBE EDITION“ und das korrekte rote
  „ROTE EDITION“-Band.
- Ursache war der automatische Asset-Override des zwar installierten, in Rot
  aber inaktiven Mods `deutsch-gelb`. Kanto Ascendant verwirft ausschließlich
  diesen nachgewiesen editionsfremden Logo-Override in Rot/Blau.
- Gelb behält unverändert sein vorgesehenes lokalisiertes Komplettlogo.

## Eingefrorene Charaktergrafiken

- Die 39 abgenommenen Red/Green/Blue-Dateien für Auswahl, Eich-Intro, Kampf,
  Voxel, Laufen, Fahrrad, Angeln und Wurfanimationen sind bytegenau
  eingefroren.
- Ein SHA-256-Regressionswächter verhindert unbemerkte Änderungen.

## Abnahme

- Echter aktualisierter Desktop-Build 0.1.76, Pokémon Rot, deutsches Profil:
  Editionsprüfung 4/4 bestanden.
- Charakter-Assetprüfung: 307/307 bestanden.
