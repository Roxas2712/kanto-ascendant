# Vermächtnis-Titel in Kanto Ascendant 6.5

> [!WARNING]
> **⚠️ FULL SPOILERS:** Diese technische Referenz nennt geheime Titel,
> Belohnungen und ihre Fortschrittsbedingungen.

<details>
<summary><strong>Vollständige technische Spoiler öffnen</strong></summary>

Beim vollständigen **Vermächtnis-Neustart** werden freigeschaltete normale
Trainerkarten-Titel und der aktiv ausgewählte Titel jetzt im externen
Vermächtnis-Archiv gespeichert. Der neue Spielstand erhält dieselben
freigeschalteten Titel in `ascendant.achievements` sowie dieselbe Auswahl in
`ascendant.selectedTitle` und `legacy_hall.selectedTitle`.

Das Archiv akzeptiert ausschließlich die in Kanto Ascendant definierten
Achievement-IDs und diese vier fortschrittsgebundenen Vermächtnis-IDs:

| Dauerhafter Fortschritt | Titel-ID | Englisch | Deutsch |
| --- | --- | --- | --- |
| Roter Weg abgeschlossen | `legacy_path_red` | KANTO CHALLENGER | KANTO-HERAUSFORDERER |
| Blauer Weg abgeschlossen | `legacy_path_blue` | OAK'S HEIR | EICHS ERBE |
| Grüner Weg abgeschlossen | `legacy_path_green` | WILDERNESS KEEPER | HÜTERIN DER WILDNIS |
| Alle drei Siegel und Finale | `legacy_pass` | LEGACY KEEPER | VERMÄCHTNIS-HÜTER |

Die drei Charaktertitel sind keine zweiten, konkurrierenden Höhlentitel. Sie
verwenden die bereits für Rot, Blau und Grün vorgesehenen Titel und werden nur
über `completedPaths.red`, `completedPaths.blue` beziehungsweise
`completedPaths.green` freigeschaltet. Der Vermächtnis-Pass benötigt weiterhin
das dauerhafte `legacyPass`-Flag.

Unbekannte Achievement- oder Titel-IDs werden beim Archivieren, Migrieren und
Wiederherstellen verworfen. Ein alter oder manipulierter Spielstand kann dadurch
keinen namenlosen oder automatisch aus einer internen ID erzeugten
„Phantomtitel“ in die Galerie oder auf die Trainerkarte bringen.

</details>
