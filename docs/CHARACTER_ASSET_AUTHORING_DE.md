# Charakter-Assets: verbindlicher Stand und Authoring-Regeln

Stand: 10. August 2026. Dieses Dokument hält den gemeinsam visuell
abgenommenen Stand von Red, Blue und Green/Casey fest. Für Walking-Sprites
sind die Dateien unter
`assets/sources/characters/crystal_chars/approved_walk/` die verbindlichen
Master. Der Builder darf sie nur pixelgenau kopieren und nicht erneut aus
großen Bildern reduzieren oder automatisch umfärben.

## Warum diese Trennung zwingend ist

Ein Charakter besteht im Recompiler aus mehreren unabhängigen Bildflächen.
Sie dürfen nicht gegeneinander ausgetauscht werden:

| Oberfläche | Format | Zweck |
|---|---:|---|
| Walking | 16×96, sechs Frames à 16×16 | Oberwelt und Ereignisfigur |
| Bike | 16×96 | Fahrrad; eigene Körper- und Fahrzeugpose |
| Fishing | 16×96 | Angelkörper; die Angel selbst zeichnet die Engine |
| 2D Front | 64×64 | Gegneransicht und frontale 2D-Präsentation |
| 2D Back / Throw | 64×64, fünf Einzelbilder | Oberkörper im klassischen Kampf und Wurfanimation |
| Voxel Front | 64×64 und 128×128 HD | stehende Ganzkörperfigur im Voxel-Kampf |

Eine Battle-Figur darf niemals in ein Walking-Sheet kopiert werden. Ebenso
darf die 2D-Backsprite nicht als Voxel-Ganzkörperfigur dienen. Änderungen an
einer Oberfläche autorisieren keine Änderungen an einer anderen.

## Native Walking-Geometrie

Alle drei Master sind RGBA-PNGs mit exakt 16×96 Pixeln. Die Reihenfolge lautet:

1. vorne / stehen (`down_idle`)
2. hinten / stehen (`up_idle`)
3. links / stehen (`left_idle`)
4. vorne / laufen (`down_walk`)
5. hinten / laufen (`up_walk`)
6. links / laufen (`left_walk`)

Rechts erzeugt die Engine durch Spiegelung der linken Frames. Es gibt deshalb
keinen siebten oder achten Frame. Frames werden nicht vergrößert, verlängert,
weichgezeichnet, vertikal verschoben oder mit zusätzlichem transparentem Rand
versehen. Vorschauen verwenden ausschließlich Nearest-Neighbour-Skalierung.

## Verbindliche Designs

### Red

- Feuerrot-Silhouette mit roter Kappe.
- Vorne sitzt nur mittig ein kleines weißes Pokéball-Emblem mit rotem Kern;
  kein weißes Stirnband über die gesamte Kappenbreite.
- Seitlich ist nur der vordere Kappenteil weiß. Der übrige seitliche und der
  gesamte hintere Kappenbereich bleiben rot.
- Schwarzes Shirt zwischen roten Westenteilen; vorne eine weiße Mittelleiste.
- Blaue Hose und gelber Rucksack in den Rückansichten.
- Keine hautfarbenen Pixel innerhalb von Kappe oder Haaren.

### Green / Casey

- Lange braune Haare mit zusammenhängender Silhouette, ohne Stirnschatten,
  Toupet-Eindruck oder Buckel in der Rückansicht.
- Gesichtspixel in weicherem Braun statt beißendem Schwarz.
- Grün-weiße Ohrringe vorne und seitlich; seitlich vier Pixel als zwei obere
  und zwei untere Pixel.
- Weißer Shirtstreifen in den lesbaren Ansichten, hautfarbene Hände und eine
  kleine dunkelgrüne Handtasche an der Seite.
- Gesicht bleibt hautfarben; in der Haarmasse stehen keine hautfarbenen
  Fehlpixel.

### Blue

- Die bestehende abgenommene Walking-Silhouette bleibt unverändert.
- Orangebraune Haare, schwarzes Oberteil und violette Hose.
- Änderungen für Red oder Casey werden nicht auf Blue übertragen.

## Reproduzierbarer Arbeitsablauf

1. Immer nur die tatsächlich betroffene Oberfläche öffnen.
2. Walking direkt auf dem nativen 16×16-Raster bearbeiten; kein generatives
   Herunterskalieren und kein Antialiasing.
3. Nur Farben aus der Figurpalette oder bewusst neu freigegebene Farben nutzen.
4. Alle sechs Frames bei 1× und vergrößert prüfen: Silhouette, Gesicht,
   Kopfbedeckung/Haare, Hände, Füße, Accessoires und Grundlinie.
5. Vorher-/Nachher-Board erzeugen. Transparenz muss als Schachbrett sichtbar
   bleiben; Weiß oder Pink ist kein Ersatz für Alpha.
6. Prüfen, dass nur die beabsichtigte Figur und Oberfläche verändert wurden.
7. Den freigegebenen Sheet nach `approved_walk/` kopieren, Prüfsumme im
   `manifest.json` aktualisieren und erst dann in die Runtime übernehmen.
8. Einen Ingame-Test in normaler Oberwelt und Voxel-Oberwelt ausführen. Battle-
   Ansichten werden separat getestet und gelten nicht als Walking-Beleg.

Der aktuelle Checkpoint ist zusätzlich über SHA-256 im Manifest fixiert. Der
Asset-Test vergleicht Master und Runtime bytegenau, damit ein späterer Build
die handgezeichneten Korrekturen nicht still überschreiben kann.

Die bereits vorhandene sichere Tool-Grundlage kann so ausgeführt werden:

```sh
python3 tools/character_asset_tool.py validate
python3 tools/character_asset_tool.py board
```

`validate` schreibt keine Assets. `board` erneuert ausschließlich das
Nearest-Neighbour-Review-Board neben den freigegebenen Mastern.

## Konzept: Character Tool für den Recompiler

Das vollständige Werkzeug ist kein allgemeiner Bildgenerator, sondern ein
zustandsbewusster Pixel- und Asset-Editor. Ein sicherer MVP sollte enthalten:

- Charakterwahl Red / Blue / Green und getrennte Tabs für Walk, Bike, Fishing,
  2D Front, 2D Back/Throw und Voxel Front.
- 16×16-Pixelraster mit Stift, Pipette, Radierer, Palette, Undo/Redo und
  optionaler Onion-Skin-Ansicht des Idle-/Laufpaars.
- Sechs feste Walking-Slots mit korrekten Richtungsnamen sowie automatisch
  gespiegelter rechter Vorschau; keine freie Änderung der Canvasgröße.
- Live-Vorschau bei 1×, 8× und auf einem neutralen Oberwelt-/Voxel-Hintergrund.
- Sperrbare Alpha-Maske, Grundlinie und Palette. Antialiasing und nicht-native
  Skalierung sind bei Walking grundsätzlich deaktiviert.
- Eine explizite Oberflächen-Sperre: Wer `walk` bearbeitet, kann nicht aus
  Versehen `back`, `front`, `voxel_front`, `bike` oder `fish` überschreiben.
- Versionierte Snapshots mit Figur, Oberfläche, Autor, Datum, Prüfsumme und
  kurzer Änderungsnotiz. Export erfolgt zunächst als Kandidat, erst nach einer
  visuellen Freigabe als `approved-master`.
- Automatische Prüfungen für Maße, Framezahl, harte Alpha-Kanten, transparente
  Ecken, Grundlinie, erlaubte Farben, unveränderte Nachbar-Assets und
  Master-/Runtime-Gleichheit.
- Automatisch erzeugte QA-Boards und optional ein Startsave pro Figur für den
  echten Ingame-Test.

### Empfohlene Umsetzung

Der Editor sollte als kleines lokales Tool neben dem Recompiler laufen. Die
erste Stufe kann Python/Pillow für Laden, Speichern, Validierung und QA-Boards
nutzen; die Oberfläche kann später als kleines Web-/Canvas-Frontend oder als
Recompiler-Debug-Menü hinzukommen. Das Dateiformat bleibt normales PNG plus
Manifest – kein proprietäres Projektformat. So bleiben alle Assets auch ohne
das Tool nachvollziehbar und per Git überprüfbar.

### Nicht verhandelbare Sicherheitsregel

Ein Export darf niemals mehrere Oberflächen oder Figuren implizit verändern.
Jede Änderung zeigt vor dem Schreiben eine Liste der Ziel-Dateien und erzeugt
einen wiederherstellbaren Snapshot. Das verhindert genau die bisherigen Fälle,
in denen Walking-, Battle- und Voxel-Figuren versehentlich vermischt wurden.
