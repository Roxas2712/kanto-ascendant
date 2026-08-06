# Kanto Ascendant 6.5.0 — interner QoL-Scope

Status: interne Arbeitsschiene, noch keine öffentliche Release-Zusage.

STARFALL TIDES ist für 7.0 reserviert. 6.5.0 enthält ausschließlich
ausgewählte Komfort-, Kompatibilitäts- und Optionsverbesserungen. Hotfixes
bleiben auf der bestehenden Release-Schiene jederzeit separat auslieferbar.

## Verbindliche Leitplanken

- Basis ist Kanto Ascendant v6.0.5.
- Jede neue Funktion ist einzeln abschaltbar und save-kompatibel.
- Alte Spielstände dürfen keine Funktion ungefragt aktivieren.
- Eine externe Mod bleibt Eigentümer ihrer UI/Hook-Fläche, wenn sie installiert
  ist. Kanto Ascendant bietet dann nur eine kompatible Abschalt-/Fallbackspur.
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

Unter `ASCENDANT` wird eine eigene Gruppe `JOHTO ASCENDANT` geführt. Sie
enthält mindestens:

- Johto-Levelbonus: `AUS`, `+2–5`, `+2–8` (Default für 6.5: `+2–8`);
- Useful Bag: `AUS / KANTO ASCENDANT / EXTERNE MOD`;
- Quick Select: `AUS / EIN`;
- Sprite-Quelle für Dex/Party/Stats: `ORIGINAL / CRYSTAL`;
- integrierte QoL-Hauptschalter und deren Unterfunktionen;
- Fangziel-Abfrage: `AUS / IMMER FRAGEN / TEAM ZUERST / BOX ZUERST`.

Die externe QoL-Mod und Useful Bag werden erkannt. Ist die jeweilige
externe Funktion aktiv, deaktiviert Kanto Ascendant die eigene konkurrierende
UI automatisch und lässt die externe Mod vollständig vorangehen.

### 3. Useful Bag

Die vorhandene Useful-Bag-Implementierung wird als optionale Kanto-
Ascendant-Funktion übernommen: moderne Taschenaufteilung, 999 Slots,
Sortierung, kampftauglicher Startbereich, vollständige TM-Namen und
Select-/Reorder-Kompatibilität. Die Farbpalette wird über die vorhandene
Palette-/Voxel-Schicht auf Gen-I-kompatible Farben begrenzt.

Die Funktion bleibt abschaltbar. Bei installierter externer `useful_bag`-
Mod gewinnt diese ausdrücklich; Kanto Ascendant setzt keine zweite
BagMenu-Implementierung darüber.

Die integrierte Darstellung erhält zusätzlich eine dezente FireRed-/GBA-
Anmutung mit farbigem Kopfbereich und Kapazitätsanzeige. Die Datenprojektion
bleibt dieselbe flache Engine-Tasche; damit ändern sich keine Save-Felder.

Die Box-Oberfläche erhält denselben Stil: farbiger Storage-Kopf, aktuelle
Boxnummer und sichtbare Belegung. Transfer, Release und Boxwechsel bleiben
vollständig engine-eigen.

### 4. Quick Select und Sprite-Auswahl

Quick Select wird aus dem lokalen Select-Mod in Kanto Ascendant integriert,
mit bestehender Feld-Item-Logik statt einer zweiten Item-Effect-Implementierung.
Die Belegung bleibt optional.

Dex-, Party- und Stats-Sprite-Auswahl werden getrennt gespeichert. Der
Kanto-Fall `ORIGINAL/CRYSTAL` erhält einen eigenen Optionspfad, damit Crystal-
Sprites im Dex nicht stillschweigend auf Kanto-Originale zurückfallen.

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
Regressionstest. Bei vollem Team wird niemals stillschweigend überschrieben.

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
- alle Toggles wirken ohne Neustart, sofern die betroffene Engine-Fläche das
  erlaubt, sonst mit klarer Hinweisbox;
- externe Useful-Bag- und QoL-Mods bleiben funktional und gewinnen den
  jeweiligen Hook-Konflikt;
- Deutsch/Englisch, 2D/Crystal/Voxel und Red/Blue/Yellow sind abgedeckt;
- vollständige Main-, Modkit-, Packaging- und Upgrade-Matrix bleibt grün;
- 6.5.0 wird erst nach interner UAT als Releasekandidat markiert.
