# Kanto Ascendant 6.5.0 RC10 installieren

RC10 korrigiert die interne Mod-ID von `trainer_rematch` zu
`kanto_ascendant`. Spielstände und Optionen werden beim ersten Laden
automatisch übernommen.

## Vor dem Import

1. Sichere `save.lua`, die Save-Slots und `options.lua`.
2. Beende Gen1Recomp vollständig.
3. Verschiebe die alte Kanto-Ascendant-Installation mit der ID
   `trainer_rematch` vollständig aus dem `mods`-Ordner. Nur den Ordner
   umzubenennen reicht nicht, weil die ID in `manifest.json` steht.
4. Falls die eigenständige Mod **Trainer Rematch** installiert ist, deaktiviere
   oder entferne sie ebenfalls. Kanto Ascendant enthält diese Funktion bereits
   und RC10 markiert beide IDs deshalb als Konflikt.

## RC10 aktivieren

1. Importiere `kanto-ascendant-6.5.0-rc10-test.zip`.
2. Aktiviere **Kanto Ascendant** im Mod-Manager.
3. Starte das Spiel neu und lade deinen bisherigen Spielstand.
4. Speichere einmal normal. Damit werden die neue
   `kanto_ascendant`-Struktur und eine getrennte RC9-Rollback-Kopie geschrieben.

## Auf RC9 zurückgehen

1. Beende das Spiel und sichere den aktuellen Spielstand erneut.
2. Verschiebe/deaktiviere RC10 (`kanto_ascendant`).
3. Importiere `kanto-ascendant-6.5.0-rc10-rollback-to-rc9.zip`.
4. Aktiviere die darin enthaltene RC9-Version und starte neu.

RC10 spiegelt seine Save- und Optionsdaten bei jedem Schreiben in die alte
`trainer_rematch`-Struktur. Fortschritt, der unter RC10 gespeichert wurde,
bleibt dadurch für den beigefügten RC9-Rollback lesbar.
