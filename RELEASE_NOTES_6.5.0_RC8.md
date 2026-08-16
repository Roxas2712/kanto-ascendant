# Kanto Ascendant 6.5.0 — interner Release Candidate 8

Dieser RC ersetzt RC7 intern. STARFALL TIDES bleibt für 7.0 reserviert; die
6.x-Hotfix-Schiene bleibt offen.

## Teamicons und PC

- Die Teamansicht verwendet die eigenständig mitgelieferten, animierten
  Crystal-Menüicons für Nationaldex #001–251 jetzt auch dann zuverlässig,
  wenn gespeicherte und laufende Optionswerte nach einem Modwechsel kurz
  voneinander abweichen.
- Follower EX ist dafür weder installiert noch zur Laufzeit erforderlich.
  Eine separat installierte Icon-Mod behält weiterhin Vorrang.
- Im deutschen PC-Menü bleibt der exakte Spielername erhalten:
  beispielsweise `ASHs PC`. Der Eintrag von Prof. Oak bleibt davon unberührt.
- Die Box-Hauptansicht zeigt unten links die Legende `L/R  BOX`; Links/Rechts
  wechselt weiterhin direkt zur vorherigen oder nächsten Box.

## Verifikation

- 11/11 fokussierte echte LÖVE-Prüfungen ohne Follower EX
- 6 repräsentative Icons: #001, #025, #151, #152, #201 und #251
- getrennte Ruhe-/Laufframes mit 2.150 abweichenden Bildpunkten im
  ausgewählten Teamicon
- 585/585 gezielte 6.5-QoL-, Fang- und Icon-Prüfungen
- 62/62 echte LÖVE-UI-/Spriteprüfungen
- 9/9 Bill-/Spieler-/Eich-PC- und Abmeldepfade
