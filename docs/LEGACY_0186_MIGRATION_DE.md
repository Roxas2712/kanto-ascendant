# Legacy-Archiv unter Engine 0.1.86 sicher übernehmen

`True Legacy Journey` funktioniert unter der unveränderten Engine 0.1.86
weiterhin sequenziell. Das Archiv wird beim echten New Game über eine geprüfte
Kapsel in den neuen, spielstandgebundenen `mod.storage`-Bereich übertragen.
Nur Archive aus älteren Mod-Versionen, die noch unter
`kanto_ascendant/legacy/<edition>.lua` liegen, brauchen einmalig diese
Offline-Migration.

## Sicherheitsvertrag

- Pokémon/gen1recomp/LÖVE muss vollständig beendet sein. Das Startskript
  bricht bei einem erkannten Prozess ab und beendet ihn niemals selbst.
- Ohne `--apply` läuft ausschließlich ein Dry-Run. Er schreibt keine Datei und
  erzeugt auch keine Playthrough-ID.
- `--apply` sichert Quellarchiv (einschließlich `.tmp`/`.bak`), `options.lua`,
  Zielsave sowie bereits vorhandenen Ziel-Storage unter
  `legacy_migration_backups/`.
- Das alte Archiv wird weder gelöscht noch verändert.
- Ein vorhandener Save-Stempel und die Engine-Zuordnung müssen übereinstimmen.
  Abweichungen sowie ein fremdes Zielarchiv führen zum Abbruch.
- Wenn ein alter Save noch keine ID besitzt, ist die Vergabe nur mit
  `--allocate-id` und einem ausdrücklich genannten Slot erlaubt. Dieser Slot
  muss laut `options.lua` der aktive Slot sein.
- Reihenfolge bei der Erstvergabe: neue opaque ID lokal erzeugen → die ID in
  einem transaktionalen Migrationszeugen sichern und zurücklesen → Ziel-
  Storage unter genau dieser ID schreiben und semantisch prüfen → Zielsave
  samt `legacy_storage_binding`-Beleg (Scope, ID, Archiv-Digest) stempeln →
  `options.lua` zuordnen. Ein Neustart nach dem ID-Zeugen verwendet
  dieselbe ID und erzeugt keinen verwaisten zweiten Storage-Bereich. Nach jedem
  unterbrochenen Schritt bleibt das alte Archiv unverändert und der Lauf ist
  wiederholbar.
- Der Digest im `legacy_storage_binding`-Beleg dokumentiert den einmalig
  geprüften Importstand. Er ist kein dauerhaft festgehaltener Inhalts-Hash:
  Bank, Titel und Kampagnenfortschritt verändern das Archiv danach regulär.
  Beim Laden bindet zusätzlich die aktuelle Run-ID des Saves an die Run-ID des
  Archivs; ein fremder aktiver Lauf im selben Scope wird abgewiesen.
- Vorhandene `main`-, `.tmp`- und `.bak`-Generationen werden vollständig
  klassifiziert: Eine einzige gültige fremde Generation bricht ab; eine
  identische gültige Generation darf beschädigte Geschwister heilen. Ohne
  gültige Generation wird nur ein vom eigenen, verifizierten ID-Zeugen
  stammendes abgebrochenes Erstschreiben wiederholt, niemals ein unbekanntes
  Ziel überschrieben.

## BLITZ / Rot / Slot 7

Zuerst ausschließlich prüfen:

```sh
tools/MIGRATE_LEGACY_ARCHIVE_0186.command \
  --edition red --slot slot7 --allocate-id
```

Die Ausgabe muss `DRY-RUN`, `red/slot7`, die Quelle, das Zielmuster und einen
Archiv-Digest zeigen. Erst nach Prüfung anwenden:

```sh
tools/MIGRATE_LEGACY_ARCHIVE_0186.command \
  --edition red --slot slot7 --allocate-id --apply
```

Der Apply-Lauf gilt nur dann als erfolgreich, wenn `APPLIED`, die endgültige
Playthrough-ID, der Backup-Ordner und die verifizierte Zieldatei ausgegeben
werden. Danach die App neu starten und zuerst den Legacy-Bankbestand prüfen.

Slot 1 darf hier trotz gleichem Trainer-ID-Fingerprint nicht gewählt werden:
Die eindeutige Autorität ist der ausdrücklich gewählte und in `options.lua`
aktive Slot 7.

## Bereits gestempelte Saves

Ist `meta.playthroughId` bereits im Save enthalten oder liegt die eindeutige
Engine-Zuordnung in `options.playthroughIds` vor, entfallen `--allocate-id` und
gegebenenfalls `--slot` bei einem flachen Alt-Save. Der Migrator übernimmt nie
eine abweichende zweite ID.

## Edition-Storage neuerer Engines

Eine Engine mit öffentlichem `mod.storage:edition(game)` importiert das alte
KA-Archiv engine-seitig als rohe v6-Datentabelle unter `legacy/archive`.
Kanto Ascendant erkennt diese API automatisch; Save-Slot und Playthrough-ID
sind dafür nicht Teil des Schlüssels. `--target-scope edition` existiert nur
für kontrollierte Wartungs-/Recovery-Fälle. Im normalen Spielbetrieb soll der
engine-eigene Import verwendet werden.

## Abbruch oder Stromausfall

Nicht manuell Dateien zwischen `main`, `.tmp` und `.bak` kopieren. App weiterhin
geschlossen lassen, den gemeldeten Backup-Ordner aufbewahren und denselben
Befehl erneut ausführen. Der Migrator akzeptiert nur denselben semantischen
Archivinhalt und dieselbe Identität. Bei einer Abweichung bleibt er fail-closed;
eine Rücksicherung erfolgt dann ausschließlich nach Prüfung der drei gesicherten
Generationen.
