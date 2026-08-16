# Rollback von 6.5.0 RC5 auf 6.0.5

Das separate RC5-Rollback-Paket enthält den unveränderten Stand von
Kanto Ascendant 6.0.5.

1. Spiel vollständig beenden.
2. Den aktuellen Spielstand zusätzlich sichern.
3. Die eigenständige **Useful Bag** vor dem 6.0.5-Neustart deaktivieren.
   RC5 kann den gemeinsamen `BagMenu`-Besitz sauber auflösen; der ältere
   6.0.5-Stand besitzt diese Koexistenzkorrektur noch nicht.
4. `kanto-ascendant-6.5.0-rc5-rollback-to-6.0.5.zip` im Mod-Manager
   importieren und den vorhandenen Kanto-Ascendant-Stand ersetzen.
5. Spiel neu starten und im Mod-Manager prüfen, dass **6.0.5** angezeigt wird.
6. Den Spielstand laden. 6.5-spezifische Optionsschlüssel bleiben
   nicht-destruktiv im Optionsspeicher und werden von 6.0.5 ignoriert.

Nicht mit deaktiviertem Kanto Ascendant weiterspielen, wenn ASC-Pokémon oder
-Items unmittelbar im Team beziehungsweise Beutel sichtbar bleiben sollen:
Die Engine bewahrt unbekannte Inhalte zwar in der Save-Quarantäne auf, stellt
sie aber erst nach erneutem Aktivieren eines kompatiblen ASC-Stands zurück.
