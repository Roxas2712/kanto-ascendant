# Rollback von 6.5.0 RC7 auf RC6

Das separate Paket
`kanto-ascendant-6.5.0-rc7-rollback-to-rc6.zip` enthält exakt den zuvor
getesteten RC6-Stand.

1. Spiel und Launcher vollständig beenden.
2. Den aktuellen Spielstand zusätzlich sichern.
3. Das RC7-Rollback-Paket im Mod-Manager importieren und den vorhandenen
   Kanto-Ascendant-Stand ersetzen.
4. Spiel und Mod-Manager neu starten.
5. Den Spielstand laden und die bisherige RC6-Konfiguration weiterverwenden.

Das Rollback ändert keine Save-Datei. Neue 6.5-Optionswerte bleiben
nicht-destruktiv gespeichert und werden von einem Stand ignoriert, der sie
nicht auswertet. Wird Kanto Ascendant vollständig deaktiviert, schützt die
vorhandene Save-Quarantäne unbekannte ASC-Pokémon und -Items weiterhin bis
zum erneuten Aktivieren eines kompatiblen Stands.
