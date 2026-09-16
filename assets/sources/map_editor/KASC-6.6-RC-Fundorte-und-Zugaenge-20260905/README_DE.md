# KASC 6.6 RC – Fundorte und Zugänge

Dieser getrennte Arbeitsbereich ist für parallele Kartenarbeit im
**Hidden Evolution Map Studio** bestimmt. Er verändert weder die laufende
KASC-Arbeitskopie noch eine installierte Mod.

## Öffnen

1. `Hidden Evolution Map Studio.app` starten.
2. Oben **JSON laden** wählen.
3. Die Datei `editor_project.json` aus diesem Ordner öffnen.

## Enthalten

- 16 echte Kanto-Quellkarten der aktuellen Starter-Zugänge;
- zwölf aktuelle kompakte Starterhabitate aus `maps-v2.1.json`;
- Zinnoberinsel, Pokémon-Villa B1F und Siegesstraße 2F für Lavados;
- Zinnober-Labor und die drei aktiven Regi-Sanktuarien;
- der versiegelte HEVO-Vorraum und die aktiven Räume für Groudon, Kyogre und
  Rayquaza;
- Orania City und die aktive Wunschkammer für Jirachi.

Insgesamt enthält der zuletzt gespeicherte Stand 45 Karten. Zusätzlich zu den
ursprünglichen Arbeitskarten enthält er Seeschauminseln B4F sowie die getrennten
Vulkanebenen `KA_MOLTRES_VOLCANO_BASE` und
`KA_MOLTRES_VOLCANO_ASCENT`. Die gelb markierten dynamischen
Zugänge und Rückwege heißen im Objekt-/Warp-Inspektor `EDITOR ONLY`. Sie lassen
sich verschieben, werden wegen `editorOnly`, `runtimeDynamic` und
`nonExporting` aber nicht als ungesicherte Direktwarps exportiert.

Der Snapshot ist inzwischen vollständig in KASC gesichert; der Karteneditor
muss für Build oder Test nicht geöffnet bleiben. Ownergebunden importiert sind
die zwölf Starterhabitate, drei Vulkanebenen und drei Regi-Sanktuarien. Die
bestehenden Kanto-Quellkarten bleiben unverändert und liefern nur geprüfte
Annäherungs-/Rückkehrpunkte. Andere als visuelle Prototypen markierte Räume
werden weiterhin nicht pauschal als Produktionsimport behandelt.

## Übergabe der Änderungen

Nach der Bearbeitung bitte **JSON herunterladen** beziehungsweise das Projekt
speichern und die resultierende JSON-Datei zurückgeben. Übernommen werden:

- Kartenblöcke, Kollisionen, Objekte und Raumaufbau;
- Positionen der `KASC_GUIDE_*`-Markierungen;
- gewünschte Eingangs-, Ziel- und Rückkehrkoordinaten;
- Rätsel- und Laufwegnotizen.

Die eigentliche Freischalt-, Save-, Rückkehr- und Card-Logik bleibt
ownergebunden in KASC und wird erst nach dem visuellen Kartenentscheid aus dem
Arbeitsbereich aktualisiert. Den Map-Studio-Modexport dieses Planungsprojekts
nicht direkt als Release installieren.

## Dokumentationsvertrag

Jeder übernommene Zugang erhält später in der öffentlichen Komplettlösung:

1. Fundortbild und Wegbeschreibung auf der Quellkarte;
2. genaue Freischaltbedingung und sichtbares Zugangsmerkmal;
3. Raumplan mit Laufweg und Rätselreihenfolge;
4. Kampf-/Fangpunkt und Belohnung;
5. geprüften Rückweg sowie Hinweise auf noch offene visuelle Probleme.

Der eingebettete JSON-Schlüssel `kascMapEditingContract` listet alle Kategorien
und Runtime-IDs. `accessDecisionContract` enthält die 16 aktuellen
Starter-Zugangsbelege vollständig.
