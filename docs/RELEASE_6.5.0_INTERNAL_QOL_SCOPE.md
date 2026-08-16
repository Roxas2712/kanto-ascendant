# Kanto Ascendant 6.5.0 — interner QoL-Scope

Status: interne Arbeitsschiene, noch keine öffentliche Release-Zusage.

STARFALL TIDES ist für 7.0 reserviert. 6.5.0 enthält ausschließlich
ausgewählte Komfort-, Kompatibilitäts- und Optionsverbesserungen. Hotfixes
bleiben auf der bestehenden Release-Schiene jederzeit separat auslieferbar.

## Verbindliche Leitplanken

- Basis ist Kanto Ascendant v6.0.5.
- Jede neue Funktion ist einzeln abschaltbar und save-kompatibel.
- Alte Spielstände behalten ihre Datenstruktur; neue 6.5-Optionen verwenden
  dokumentierte Defaults und können einzeln abgeschaltet werden.
- Die externe QoL-Mod bleibt Eigentümer ihrer QoL-Hooks. Bei Useful Bag hat
  Ascendant aktiviert Vorrang; nach Abschalten übernimmt die externe Mod.
- Deutsch und Englisch werden vollständig gepflegt; sichtbare Texte bleiben
  spoiler- und layout-sicher.
- 2D, Crystal, Red/Blue/Yellow-Fallback und Dramatic Shape/Voxel werden für
  jede sichtbare Änderung geprüft.

## Inhalt von 6.5.0

### 1. Johto-Begegnungslevel

Gewöhnliche Johto-Ersatzbegegnungen verwenden den gerundeten,
Gen-I-gewichteten Routenmittelwert plus einen Zufallsaufschlag von **+2 bis
+8 Leveln**. Die Grenze ist weiterhin Level 100. Primal-/Story-
Begegnungen behalten ihre ausdrücklich gesetzten Level. Die Regel gilt
einheitlich für klassische Begegnungen, Wilds und permanente Forschungs-
habitate.

### 2. Kanto-Ascendant-Optionsgruppe

Unter `OPTIONS` wird die eigene Gruppe `JOHTO ASCENDANT FT.` geführt. Sie
enthält mindestens:

- Johto-Levelbonus: `+2–5`, `+2–8` (Default für 6.5: `+2–8`);
- Useful Bag: `AUS / KANTO ASCENDANT`;
- Quick Select: `AUS / EIN`;
- Sprite-Menü: `AUTO / ORIGINAL / CRYSTAL` plus getrennte Bereiche für Kampf,
  Team/Status, Pokédex, Boxen und weitere Szenen;
- integrierte QoL-Hauptschalter und deren Unterfunktionen;
- Fangziel-Abfrage: `AUS / IMMER FRAGEN / TEAM ZUERST / BOX ZUERST`.

Die externe QoL-Mod und Useful Bag werden erkannt. Externe QoL-Hooks gehen
vollständig vor. Die Ascendant-Tasche bleibt stärker, solange ihr Schalter
aktiv ist; wird sie abgeschaltet, übernimmt die externe Useful Bag.

### 3. Useful Bag

Die vorhandene Useful-Bag-Implementierung wird als optionale Kanto-
Ascendant-Funktion übernommen: moderne Taschenaufteilung bei unveränderter
Vanilla-Kapazität,
Sortierung, kampftauglicher Startbereich, vollständige TM-Namen und
Select-/Reorder-Kompatibilität. Die Farbpalette wird über die vorhandene
Palette-/Voxel-Schicht auf Gen-I-kompatible Farben begrenzt.

Die Funktion bleibt abschaltbar. Solange sie aktiv ist, besitzt Ascendant die
BagMenu-Darstellung. Nach dem Abschalten wird keine zweite Ascendant-
BagMenu-Implementierung registriert und die externe `useful_bag` übernimmt.

Die integrierte Darstellung erhält eine vollständige FireRed-/GBA-Anmutung:
farbige Fachleiste mit Symbolen, fünf kompakte Itemzeilen, klare Auswahl- und
Bedienbereiche sowie eine true-color-fähige Voxel-/SGB-Ausgabe. Die
Datenprojektion bleibt dieselbe flache Engine-Tasche.

Die Box-Oberfläche erhält denselben Stil: farbiger Storage-Kopf, aktuelle
Boxnummer, 5×4-Raster, echte Pokémon-Vorschaubilder, Detailvorschau und
D-Pad-Navigation. Transfer, Release und Boxwechsel bleiben engine-eigen.

### 4. Quick Select und Sprite-Auswahl

Quick Select wird aus dem lokalen Select-Mod in Kanto Ascendant integriert,
mit bestehender Feld-Item-Logik statt einer zweiten Item-Effect-Implementierung.
Die Belegung bleibt optional.

Die Sprite-Auswahl sitzt vollständig im neuen Menübaum. `AUTO` bewahrt die
bisherigen 6.5-Regeln und externe Renderer, `ORIGINAL` nutzt die Grafik der
aktiven Spielversion und `CRYSTAL` schaltet den vollständigen Crystal-Satz für
#001–251 ein. Kampf, Team/Status, Pokédex, FireRed-Boxen und weitere Szenen
(Entwicklung, Tausch, Ruhmeshalle, Titel/Oak/Credits) sind getrennt schaltbar.

Für alle 251 Pokémon liegen normale und shiny Crystal-Frontsprites vor.
Zusätzlich sind die 151 Kanto- und 100 Johto-Backsprites jeweils normal und
shiny vollständig. Die Auswahl greift live; Crystal-Kampfanimationen bleiben
separat abschaltbar. Die Teamanzeige erhält aus dem gewählten Crystal-Frame
ein passendes 16×16-Retro-Icon. Explizite externe Sprite-Renderer behalten
Vorrang.

### 5. Integrierte QoL-Funktionen

Die Funktionen aus `pokemon-gen1-recomp-mod-qol` werden einzeln unter
`JOHTO ASCENDANT → QUALITY OF LIFE` angeboten:

- EXP-Fortschrittsbalken im Kampf;
- gefangene-Anzeige bei wilden Begegnungen;
- erleichterte Feldinteraktionen;
- Ortsbanner;
- Controller-Doppelinput-Schutz;
- Voxel-kompatible Kampfüberlagerungen.

Wenn die externe QoL-Mod installiert ist, hat sie Vorrang; die integrierten
Hooks bleiben für diese Features aus, damit keine Doppelanzeigen entstehen.

### 6. Fangziel-Abfrage / automatische Box

Nach einem erfolgreichen Fang kann der Spieler entscheiden, ob das Pokémon
ins Team oder direkt in die Box geht. Die Abfrage darf den Fang nicht
wiederholen und muss bei `AUS` vollständig dem Vanilla-Verhalten folgen.
Entwicklungs-, Story- und Safari-/Sonderfänge erhalten einen eigenen
Regressionstest. Bei vollem Team wird ein Teammitglied gewählt und sicher mit
dem bereits eingelagerten Fang getauscht; nichts wird überschrieben,
dupliziert oder verloren.

### 7. Eingebaute Komfortverbesserungen

Die für 6.5 priorisierten eigenen QoL-Ergänzungen sind jetzt umgesetzt:

- Schutz vor dem Wegwerfen seltener Fortschrittsitems;
- nicht-destruktive Pokédex- und Box-Filter;
- optionale Textgeschwindigkeits-Presets mit Vanilla-Engine-Fallback;
- konfigurierbare Reitsteuerung (SELECT-Fahrrad oder klassischer Beutel);
- moderne Tasche-/Box-Darstellung und Fangziel-Abfrage.

## Zusätzliche empfohlene QoL-Ideen

- konfigurierbare „letztes Teammitglied heilen“-Anzeige vor dem Verlassen
  eines Pokémon-Centers;
- einmalige Bestätigung vor dem Wegwerfen seltener/key Items;
- optionales Halten der Laufrichtung beim Rad-/Lapras-Reiten;
- `A`-Haltefunktion für wiederholte Textseiten, ohne Storydialoge zu
  überspringen;
- separate Toggle-Option für Kampf-Animationsgeschwindigkeit, standardmäßig
  unverändert;
- Such-/Filterfunktion im Pokédex und in der Box, nur als UI-Projektion ohne
  Änderungen an der gespeicherten Reihenfolge.

## Nicht Bestandteil von 6.5.0

- Orange-Archipel, Starfall Tides, Jirachi-/Mythical-Kampagne;
- neue Regionen, neue Storyhubs oder große neue Pokémonfamilien;
- verpflichtende Änderungen an vorhandenen Saves;
- öffentliche Discord-/Release-Kommunikation vor Maintainerfreigabe.

## Abnahmekriterien

- bestehende 6.0.5-Upgrades und alte Saves laden unverändert;
- der vollständige Ablauf ASC aktiv → speichern → ASC deaktivieren →
  laden/speichern → ASC zusammen mit externer Useful Bag wieder aktivieren
  lädt ohne Registry-Fehler und stellt quarantänisierte Pokémon/Items wieder
  her;
- alle Toggles wirken ohne Neustart, sofern die betroffene Engine-Fläche das
  erlaubt, sonst mit klarer Hinweisbox;
- externe QoL-Mods gewinnen ihre Hook-Konflikte; externe Useful Bag übernimmt
  zuverlässig, sobald die Ascendant-Tasche ausgeschaltet wird;
- Deutsch/Englisch, 2D/Crystal/Voxel und Red/Blue/Yellow sind abgedeckt;
- vollständige Main-, Modkit-, Packaging- und Upgrade-Matrix bleibt grün;
- 6.5.0 wird erst nach interner UAT als Releasekandidat markiert.
