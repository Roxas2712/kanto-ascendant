# Kanto Ascendant 6.5.0 RC13 – Testbericht

## Ho-Oh-Logik

- Gezielter Modultest: **35/35**.
- Core-Phase-9-Vertrag: **30/30**.
- Geprüft wurden die unveränderte 1-%-Grenze und Kartenfläche, direkte
  Darstellung ohne BattleTransition, `??? / L???`, die nicht gesetzte
  Pokédex-Sichtmarke, Gold-Tint, zweisprachige Texte, fremde Musik,
  verfremdeter Ruf, fehlendes Kampfmenü, Fang-/EXP-Sperre, unveränderte
  Teamdaten, Einmal-Markierung und der getrennt erhaltene Lugia-Pfad.

## Echter Renderer-Lauf

Ein vollständig isolierter Red-Lauf mit Kanto Ascendant 6.5.0, Deutsch 2.1.5
und Dramaless Shape 1.6.2.ST bestand **21/21** Laufzeitprüfungen.

Nachgewiesen wurden:

- goldene, animierte Erscheinung mit unbekanntem Namen und Level;
- keine Spielerfigur und kein Kampfmenü;
- fremde Melodie und verfremdeter Ruf;
- sichtbares Verschwinden vor dem Abschlusstext;
- Rückkehr nach Route 2 auf X 4 / Y 48;
- unveränderte Team-HP sowie persistente Einmal-Markierung.

Die vier reproduzierbaren Belegbilder liegen unter
`qa/rc13_hooh_mystery/`. Der Treiber liegt unter
`tests/rc13_hooh_mystery_driver.lua`; beide Bereiche sind aus dem
Spielerpaket ausgeschlossen.

## Vollständige Regression

- Hauptregression: **6582/6582**.
- Upgrade-Matrix Red/Blau/Gelb: **6633/6633**.
- Deaktivieren/Speichern/Reaktivieren: **18/18**.
- `git diff --check`: bestanden.

## Paketprüfung

Das launcherfähige RC13-ZIP enthält 15.577 Laufzeitdateien plus
`.modkit/pack.json` (15.578 Archiveinträge). ZIP-Integrität, Root-Manifest,
Manifest-ID `kanto_ascendant`, Version `6.5.0`, repräsentative Pflichtdateien,
erneute strenge Validierung des entpackten Archivs und Ausschluss von Tests,
QA-Bildern, Quellen sowie privaten RC13-Unterlagen sind bestanden.

ZIP und MODPKG sind bytegleich und tragen SHA-256
`e552507bca8953e3165aca7627ef308c28f39f8ebce5a38766a57e56a984c866`.
Die Rollback-Datei ist bytegleich mit RC12 und behält dessen SHA-256
`3d2696e9a96f95a1062e132c07a51e697a8519f9d0fa3565ca16c5c9a509b636`.
