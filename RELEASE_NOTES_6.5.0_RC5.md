# Kanto Ascendant 6.5.0 — interner Release Candidate 5

Dieser RC ersetzt RC4 intern. STARFALL TIDES bleibt für 7.0 reserviert; die
6.x-Hotfix-Schiene bleibt offen.

## Save-/Mod-Manager-Korrektur

- Der Ablauf **ASC aktiv → speichern → ASC deaktivieren → laden/speichern →
  ASC wieder aktivieren** ist jetzt explizit abgesichert.
- Kanto Ascendant lädt wieder fehlerfrei neben der eigenständigen
  **Useful Bag**. Solange ein ASC-Beutelmodus aktiv ist, übernimmt ASC
  `BagMenu` über den vorgesehenen Override-Pfad; **AUS / EXTERN** überlässt
  den Bildschirm weiterhin Useful Bag.
- Beim Laden ohne ASC verschiebt die Engine unbekannte ASC-Pokémon und
  -Items verlustfrei in ihre Save-Quarantäne. Nach dem erneuten Aktivieren
  werden Pokémon in eine freie Box und Items in Beutel beziehungsweise PC
  zurückgeführt. Der bisherige doppelte `BagMenu`-Fehler hatte genau diesen
  Wiederherstellungslauf vorzeitig verhindert.

Alle visuellen und konfigurierbaren RC4-Funktionen bleiben unverändert
enthalten.

## Verifikation

- 18/18 neuer Disable-/Save-/Re-enable-Regressionstest
- echte Useful Bag 2.4.1 und Kanto Ascendant laden gemeinsam: 2 Mods,
  0 Registry-Fehler
- 67/67 gezielte 6.5-Plumbing-/Funktionstests
- 6581/6581 vollständige Modprüfungen
- 6603/6603 Upgrade- und Save-Matrix-Prüfungen
- exakte Test-ZIP wird nach dem Build über den Launcher importiert und in
  einer isolierten LÖVE-Identität erneut mit Useful Bag sowie
  Disable-/Re-enable-Zuständen geprüft
