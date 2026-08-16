# Kanto Ascendant 6.5.0 — interner Release Candidate 7

Dieser RC ersetzt RC6 intern. STARFALL TIDES bleibt für 7.0 reserviert; die
6.x-Hotfix-Schiene bleibt offen.

## Crystal-2D- und Fangkorrekturen

- Die globale Auswahl **CRYSTAL 2D** steuert jetzt auch das Teammenü, wenn
  ein älterer Spielstand dort noch den Unterwert **CLASSIC** gespeichert hat.
  Die eigenständig gebündelten, animierten Menüicons bleiben für Nationaldex
  #001–251 verfügbar; Follower EX ist weiterhin keine Abhängigkeit.
- Crystal-Rückensprites werden im Kampf in nativer Größe geladen. Die
  Skalierung gilt nun auch für die transparent vorbereiteten Cache-Dateien,
  sodass Crystal ohne Dramatic Shape sauber funktioniert.
- **FANGZIEL: FRAGEN** fragt jetzt nach jedem normalen Wildfang – auch wenn
  das Pokémon zunächst noch ins Team passt. Die Entscheidung erscheint vor
  der Spitznamenfrage.
- Der Spitznamenbildschirm zeigt das gefangene Pokémon statt einer leeren
  weißen Fläche.
- Ist die aktive Box voll, wird bei der Boxwahl automatisch die nächste Box
  mit Platz verwendet. Die Meldung nennt die tatsächlich verwendete Box.

## Verifikation

- 585/585 gezielte 6.5-QoL-, Fang- und Icon-Prüfungen
- 62/62 echte LÖVE-UI-/Spriteprüfungen
- 14/14 echter Fang-/Spitznamen-/Boxüberlauf-Ablauf
- 15/15 Ballwurf-, Ausbruch- und Fangerfolgsprüfungen
- 9/9 Bill-/Spieler-/Eich-PC- und Abmeldepfade
- 6581/6581 vollständige Modprüfungen
- 6603/6603 Upgrade- und Save-Matrix-Prüfungen
