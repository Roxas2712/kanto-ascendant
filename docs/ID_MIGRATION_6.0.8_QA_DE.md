# Kanto Ascendant 6.0.8 – ID-Migration und QA

## Was geändert wurde

Kanto Ascendant wird ab 6.0.8 intern als `kanto_ascendant` geführt. Bis 6.0.7
wurde `trainer_rematch` verwendet. Genau diese alte ID wird aber auch von der
eigenständigen Trainer-Rematch-Mod genutzt; deshalb konnte der Launcher eine
Kanto-Ascendant-ZIP mit „already installed“ ablehnen.

6.0.8 behandelt die alte ID ausschließlich noch als:

- Quelle für die einmalige Daten- und Optionsmigration,
- unveränderten Rollback-Snapshot,
- manifestierten Konflikt, damit alter und neuer Code nie gleichzeitig laufen.

## Migration beim ersten Start

Vor der Save-Validierung erkennt 6.0.8 einen Ascendant-6.x-Spielstand, kopiert
fehlende Werte aus `save.modData.trainer_rematch` nach
`save.modData.kanto_ascendant` und ändert nur den zugehörigen Eintrag in
`save.meta.mods`. Bereits vorhandene neue Werte gewinnen. Andere Mods,
Pokémon, Boxen, Items, Pokédex, Kartenposition und Basisfortschritt bleiben
unverändert.

Die Optionsmigration läuft ebenfalls nach „neue Werte gewinnen“. Ein
abgebrochener erster Versuch kann beim nächsten Start fortgesetzt werden. Der
alte Save- und Optionsbereich wird nicht gelöscht.

## Durchgeführte Prüfungen

- ID-Migration: 27/27 – Save, Optionen, Teilmigration, Idempotenz,
  aktuelle-Werte-gewinnen, Rollback-Erhalt und Schutz vor falscher Übernahme
  der eigenständigen Trainer-Rematch-1.x-Mod.
- Vollständige Kanto-Ascendant-Integration: 6.569/6.569.
- Historische Upgrade-Matrix: 6.633/6.633 – mehrere Altversionen,
  Red/Blue/Yellow, Deutsch/Englisch, Serialisierung, Neustart und Mod aus/an.
- Konfliktmatrix: alte ID, Followers EX, PokéPC-Varianten und Quality of Life;
  Manager und Boot-Fehlerlog geprüft.
- Rematch Phase 8: 130.093 Prüfungen; weitere Rematch-, Follower-, Gorochu-,
  UI-, Atlas-, Economy-, Signals-, Wilds- und Mythic-Suiten grün.
- Strikte Modkit-Validierung: `ok kanto_ascendant valid`.
- Paketstruktur und ZIP-CRC: fehlerfrei; Release-Grenzen-Audit grün.
- Echter LÖVE-Launcher-Test: 6.0.7 (`trainer_rematch`) installiert, danach
  6.0.8 (`kanto_ascendant`) ohne Ersetzen importiert; beide IDs erkannt und
  beidseitiger Konfliktschutz aktiv.

## Testpaket und Rückfallstand

- Test: `kanto-ascendant-6.0.8-id-migration-rc1-test.zip`
- SHA-256: `df219a87a602279ec0cf557b2e14e3c8829b718e6f7b04e96a041c4ad17d1310`
- 6.0.7-Fallback: `kanto-ascendant-6.0.7-comprehensive-e2e-8520950-test.zip`
- Abgenommener RC10 bleibt zusätzlich unverändert erhalten.

Für den Rückweg 6.0.8 deaktivieren und erst danach den alten Eintrag aktivieren.
Fortschritt, der ausschließlich mit 6.0.8 entstanden ist, wird nicht rückwärts
in den alten Snapshot geschrieben.
