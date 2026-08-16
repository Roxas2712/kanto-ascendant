# Kanto Ascendant 6.5.0 RC14 – Testbericht

## Gezielte Verträge

- Ho-Oh-Vision ohne Lugia-Definition: **33/33**.
- Phase-9-Core einschließlich Zustandsmigration: **31/31**.
- Mythischer Nuzlocke-Schutz: **23/23**.
- Mythic Signals: **148/148**.
- Phase-10-Audit: **28/28**.
- Ascendant-UI: **17/17**.
- QoL einschließlich Ball-/Icon-Regression: **607 Assertions**.

Die Tests sichern ab, dass nur eine Ho-Oh-Vision existiert, alte
Lugia-Vision-Daten entfernt werden und Lugias regulärer Fangweg unberührt
bleibt. Der Nuzlocke-Wrapper wird erst beim konkreten Ascendant-Kampf und nur
während der beiden relevanten Faint-Callbacks ausgenommen.

## Echter Nuzlocke-Renderer-Lauf

Ein isolierter Red-Lauf mit Kanto Ascendant 6.5.0, der echten eingebauten
Nuzlocke-Mod 1.0.0, Deutsch 2.1.5 und Dramaless Shape 1.6.2.ST bestand
**24/24** Laufzeitprüfungen.

Geprüfte Niederlagenpfade:

- reguläres Ascendant-Ho-Oh;
- reguläres Ascendant-Celebi;
- Celebi-Signal;
- Route-24-Mew;
- Mew-Echo.

Jeder Pfad behielt das Team, erzeugte eine normale Niederlage und landete mit
vollständig geheiltem Pokémon im Vertania-Pokémon-Center. Ein reguläres Lugia
diente als Kontrollfall und behielt korrekt die normalen Nuzlocke-Regeln.
Der Beleg liegt unter `qa/rc14_mythic_nuzlocke/` und wird durch
`tests/rc14_mythic_nuzlocke_driver.lua` reproduziert; beides ist vom
Spielerpaket ausgeschlossen.

## Vollständige Regression

- Hauptregression: **6582/6582**.
- Upgrade-Matrix Red/Blau/Gelb: **6633/6633**.
- Deaktivieren/Speichern/Reaktivieren: **18/18**.
- Strenger Modkit-Validator: bestanden.
- `git diff --check`: bestanden.

## Paketprüfung

Das launcherfähige RC14-ZIP enthält 15.578 Laufzeitdateien plus
`.modkit/pack.json` (15.579 Archiveinträge). ZIP-Integrität, Root-Manifest,
`vision_encounters.lua`, `mythic_safety.lua`, erneute strenge Validierung des
entpackten Archivs und Ausschluss von Tests, QA-Bildern, Quellen sowie
privaten RC14-Unterlagen sind bestanden.

ZIP und MODPKG sind bytegleich und tragen SHA-256
`3396280697fbd6b5b16370f01ab0e2eda3c5e6b732dada933561ef963b7ad921`.
Die Rollback-Datei ist bytegleich mit RC13 und behält dessen SHA-256
`e552507bca8953e3165aca7627ef308c28f39f8ebce5a38766a57e56a984c866`.
