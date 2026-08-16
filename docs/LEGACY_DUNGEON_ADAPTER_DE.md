# Dungeon-Legacy-Adapter

> [!WARNING]
> **⚠️ FULL SPOILERS:** Diese technische Referenz nennt Belohnungen,
> Partner-Pokémon und Fortschrittsbedingungen der Vermächtnisreise.

<details>
<summary><strong>Vollständige technische Spoiler öffnen</strong></summary>

`legacy_dungeon_adapter.lua` ist die absichtlich kleine Integrationsnaht zwischen den charaktergebundenen Dungeons und `legacy_archive`. Werden sie bei der späteren Installation übergeben, verwendet sie die öffentlichen Oberflächen von `legacy_journey` (aktive Figur, Pfadabschluss, Tür) und `legacy_starters` (passender Hoenn-Partner); andernfalls fällt sie nur auf die gleichwertigen Archive-APIs zurück.

| Reise | dauerhafte Belohnung | NG+-Starter | Archiv-Siegel |
| --- | --- | --- | --- |
| Rot | BLAZIKENITE | TORCHIC | red |
| Blau | SWAMPERTITE | MUDKIP | blue |
| Grün | SCEPTILITE | TREECKO | green |

| Übergang | Vorbedingung | atomare Änderung | Ergebnis |
| --- | --- | --- | --- |
| Rot | aktive Legacy-Reise RED, Ruhmeshalle | `meta.RED`, BLAZIKENITE, TORCHIC-Entitlement/Dex, rote Fragen/Unlocks, lokales rotes Siegel | Archive-Pfad `red` abgeschlossen |
| Blau | aktive BLUE-Reise, Ruhmeshalle | bereits aus dem Archiv kopierte rote Felder bleiben; ergänzt nur blaue Felder | Archive-Pfad `blue` abgeschlossen, keine Duplikate |
| Grün | aktive GREEN-Reise, Ruhmeshalle | alle bisherigen Felder bleiben; ergänzt grüne Felder | Archive-Pfad `green`; gemeinsame Tür kann über Archive geprüft werden |

`reenter(save, character)` akzeptiert nur die aktuell aktive eigene Figur mit ihrem Meta-Siegel. Ein alter Save ohne `legacy_journey` wird bewusst nicht zu RED hochgestuft, sondern fail-closed abgewiesen. Fehlen in einem gültigen alten HEVO-Save einzelne neue Untertabellen (`dex`, `questionIds` usw.), werden sie erst innerhalb der erfolgreichen Abschluss-Transaktion angelegt.

Der Dungeon ruft nach seinem eigenen Siegel `finalize(game, { character="RED", evolutionUnlocks={}, questionIds={}, rivalWitness=true })` auf. Der Adapter verlangt aktive passende Figur und Ruhmeshalle, schreibt nur `hevo_persistent` (Meta, Unlocks, Stones, Dex, Fragen) dauerhaft und `hevo_run.dungeonLegacy` lauflokal. Ein abweichender `character`-Wert, eine fremde Figur oder ein schon eingelöstes Lauf-Siegel werden abgewiesen. Erst danach wird `legacy_archive.advancePath` aufgerufen. Schlägt Save- oder Archivschreiben fehl, stellt der Adapter den Save-Snapshot wieder her und versucht den wiederhergestellten Save erneut zu schreiben.

Beim nächsten `beginJourney` übernimmt die vorhandene Archive-API die erlaubten persistenten HEVO-Felder in die neue Reise; lokale Siegel und das einmalige Türarchiv beginnen neu. Die versiegelte Tür ist bereit, wenn alle drei Steine/Meta-Siegel vorhanden **und** `legacy_archive.hevoDoorQuestReady` grün ist; `consumeDoorArchive` delegiert an `legacy_archive.consumeHevoDoorQuest`, also einmalig pro Lauf.

Die echten Mega-Profile für die drei Hoenn-Steine existieren derzeit nicht in `mega_evolution.lua` (die vorhandene `mega.grantStone`-API würde sie deshalb ablehnen). Der Adapter hält daher nur die dauerhaften, deduplizierten Entitlements in `permanentItems`. Die spätere Mega-Integration muss nach Eintragen der Profile diese Entitlements über `mega.grantStone` materialisieren. Karten-, Tür- und Dungeon-Eventbindung bleibt bewusst ein offener Integrationseam.

Recovery: Vor jeder Mutation wird ein Tiefensnapshot von `hevo_run`, `hevo_persistent` und Flags gebildet. Scheitert der eigentliche Game-Save, wird der Snapshot wiederhergestellt; erst danach darf `advancePath` ins Archive schreiben. Scheitert dieses Schreiben, wird derselbe Snapshot wiederhergestellt und erneut gespeichert. Scheitert auch dieser Wiederherstellungs-Save, liefert der Adapter ausdrücklich `rollback-save`; der Aufrufer darf keinen Erfolgstext zeigen und muss beim nächsten Save/Load die Archive-Recovery prüfen. Die getesteten offenen Integrationseams sind die spätere Dungeon-Eventregistrierung und das Materialisieren der drei Entitlements in reale Mega-Profile.

</details>
