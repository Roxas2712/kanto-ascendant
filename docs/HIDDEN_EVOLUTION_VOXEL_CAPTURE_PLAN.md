# Hidden Evolution 6.5 – Runtime- und Renderer-Vertrag

Dieses Dokument beschreibt den öffentlichen technischen Vertrag der drei
Hidden-Evolution-Pfade. Es enthält bewusst keine vollständige Lösung. Exakte
Routen, Karten und Voraussetzungen stehen im klar als Vollspoiler markierten
[Offline-Guide](guides/hidden-evolution/README.md).

## Karten- und Rollenvertrag

- RED, BLUE und GREEN besitzen je einen eigenständigen Pfad sowie den
  gemeinsamen Tunnel und die versiegelte Vorkammer.
- Alle fünf Rätselobjekte pro Held verwenden die unbewegliche graue
  `SPRITE_KA_HEVO_QUIZ_STATUE` mit `semanticRole="quiz_statue"`.
- Gelbe `SPRITE_KA_EVOLUTION_RELIC`-Objekte sind ausschließlich optionale
  Etagenlichter mit `semanticRole="floor_light"`.
- Rätselstatuen, Etagenlichter, Übergänge, Warps und Kollisionen müssen in
  nativer 2D-Darstellung, Voxel Ascendant und der geprüften DRAMALESS-Version
  dieselbe Spielbedeutung behalten.

## Renderer-Abnahme

Jede Änderung an Karten, Tilesets, Assets oder Renderer-Bridges muss die
betroffenen Karten erneut durch den echten World-Pass laden. Ein bloßer
Headless-Erfolg ersetzt keine visuelle Prüfung. Erforderlich sind:

- keine fehlenden Assets, Schwarzbilder, falschen Ebenen oder Base-Form-
  Fallbacks;
- identische begehbare Topologie, Warps und Interaktionspositionen;
- keine weißen Säume, Rasterringe, abgeschnittenen Billboards oder leeren
  Viewportränder;
- echte Eingabetraces für Navigation, Rätsel, Speichern/Laden, Rückweg und
  Wiedereintritt.

`BLITZ` ist in der RED-/BLUE-Dunkelheit und im GREEN-Nebel absichtlich
wirkungslos. Der lokalisierte Hinweis darf weder Sichtstufe noch Maske ändern.

## Pfadspezifische Mindestabdeckung

### RED

Der Lauf deckt den Route-22-Riss, alle fünf Rätselstatuen, drei STÄRKE-
Fassungen, sichere Sturz-/Recovery-Wege, den schwarzen Strom, Schrein,
Vorkammer, vollständigen Rückweg und Wiedereintritt ab.

### BLUE

Der Lauf deckt Route 24, Frostschwelle, Frosthalle, zusammenhängendes Eisfeld,
alle Löcher und Rücksetzungen, drei STÄRKE-Schalter, optionalen Surfzweig,
Schrein, Vorkammer und Wiedereintritt ab.

### GREEN

Der Lauf deckt Route 3, Wurzel- und Nebelhain, ZERSCHNEIDER-Gate,
Kronendach-Tor, fünf Sichtstufen, Schrein, Vorkammer, Rückweg und Wiedereintritt
ab. Nebel darf Außenräume vollständig verbergen, ohne den sicheren
Spielerbereich unlesbar zu machen.

## Gemeinsame Abschlussbedingungen

- Der Endstein nennt fehlende Pflichtbedingungen verständlich und setzt den
  Spieler erst nach Bestätigung an den Pfadanfang zurück.
- Optionale Etagenlichter und geheime Caches sind keine Siegelvoraussetzung.
- Bereits dauerhaft autorisierte Siegel bleiben idempotent und werden durch
  spätere Berichtsprüfungen nicht entwertet.
- Speicher-, Archiv- oder Authority-Fehler werden nicht als Rätselversagen
  ausgegeben und lösen keinen Rückteleport aus.

## Öffentliche Belege

Die mit dem Release veröffentlichte HTML-Lösung enthält die geprüften
Kartenübersichten und Einzelkarten. Die vollständigen Entwicklungs-Captures,
Runnerprotokolle und maschinenspezifischen Arbeitsverzeichnisse bleiben im
privaten Abnahmearchiv und sind nicht Bestandteil des öffentlichen Quellbaums
oder Modpakets.
