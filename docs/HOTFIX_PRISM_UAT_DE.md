# Kanto Ascendant – Hotfix- und Prismengrotten-UAT

Diese kurze Abnahme verwendet ausschließlich die isolierte LOVE-Identität
`kanto-ascendant-signals-uat`. Normale Spielstände werden nicht geöffnet oder
verändert.

## Start

Öffne je nach Edition `START_YELLOW_UAT.command`, `START_RED_UAT.command`
oder `START_BLUE_UAT.command`. Falls macOS nachfragt, bestätige das Öffnen.

In der Spielstandauswahl stehen die vorbereiteten Tests als
`S25 PRISM GROTTO` bis `S28 JOHTO DEX AUDIO`. Nach einem veränderten Test
kann der ursprüngliche Zustand jederzeit mit dem UAT-Builder neu erzeugt
werden.

## Test 1: Steinrätsel

1. Lade `S25 PRISM GROTTO`.
2. Gehe rechts durch die zweite Glasfuge.
3. Lies zuerst die große Kristalltafel.
4. Lass dir vom Forscher ein Rätsel geben.
5. Spiele absichtlich zuerst einen falschen Pfeiler.
6. Löse anschließend die angezeigte Folge korrekt.
7. Sprich denselben Pfeiler und den Forscher erneut an.

**PASS:** Alle Symbole sind unterscheidbar. Ein Fehler setzt nur die aktuelle
Folge zurück. Die Belohnung wird genau einmal vergeben. Der Forscher kann
Rätsel und bereits gelöste Inschriften erneut erklären.

## Test 1b: Johto-Attacken am zentralen Kristall

1. Lade `S25 PRISM GROTTO`.
2. Sprich zuerst mit dem Forscher. Er muss auf die Kristalltafel hinter sich
   als Quelle für Johto-Attacken hinweisen.
3. Sprich die große Kristalltafel hinter dem Forscher an und bestätige die
   Einstimmung.
4. Wähle Gengar und lasse es Spukball lernen.
5. Sprich die Tafel erneut an, wähle das Growlithe auf Level 33 und danach
   Flammenrad.
6. Nutze eines der vorbereiteten Sonderbonbons, erhöhe Growlithe auf Level 34
   und wiederhole den Versuch.
7. Wähle Parasect, das für diesen Test bereits vier Attacken einschließlich
   Zerschneider besitzt. Die Tafel muss auf den bestehenden Attacken-Verlerner
   auf Route 5 verweisen und darf kein eigenes Verlern-Menü öffnen.
8. Lösche beim Route-5-Verlerner eine beliebige Attacke (optional auch eine
   VM), kehre zur Tafel zurück und lerne die Kristall-Attacke. Prüfe danach
   den bestehenden Attacken-Erinnerer.

**PASS:** Gengar kann Spukball sofort lernen. Growlithe wird auf Level 33 als
zu schwach abgewiesen und ausdrücklich auf Level 34 verwiesen; ab Level 34
lernt es Flammenrad. Die Tafel verändert bei vier Attacken nichts und verweist
auf Route 5. Der dortige Verlerner darf auch VMs entfernen, lässt aber immer
mindestens eine Attacke übrig. Die kristallgelernte Attacke erscheint später
beim bestehenden Attacken-Erinnerer.

## Test 2: „JA“ dauerhaft merken

1. Lade `S26 REMEMBER YES`.
2. Wähle beim Johto-Direktstart **YES/JA**.
3. Warte, bis „Receiver ready/Empfänger bereit“ vollständig geschlossen ist.
4. Beende die Anwendung vollständig, ohne zusätzlich manuell zu speichern.
5. Starte erneut und lade wieder `S26 REMEMBER YES`.

**PASS:** Die Frage erscheint nicht erneut. Wanderwaves/Wanderwellen ist
weiterhin aktiv.

## Test 3: „NEIN“ dauerhaft merken

1. Lade `S27 REMEMBER NO`.
2. Wähle **NO/NEIN**.
3. Beende die Anwendung vollständig, ohne zusätzlich manuell zu speichern.
4. Starte erneut und lade wieder `S27 REMEMBER NO`.

**PASS:** Die Frage erscheint nicht erneut. Die normale Feldkapsel-Quest ist
weiterhin aktiv und wurde nicht übersprungen.

## Test 4: Johto-Dex, Crystal-Sprites und Rufe

1. Lade `S28 JOHTO DEX AUDIO`.
2. Öffne den Nationaldex.
3. Prüfe mindestens #152 Chikorita, #158 Karnimani, #177 Natu,
   #201 Icognito, #245 Suicune und #251 Celebi.
4. Achte jeweils auf Frontbild, Daten, Namen und Ruf.
5. Öffne zusätzlich die vier Johto-Pokémon im Team.

**PASS:** Kein Eintrag zeigt ein Kanto-Ersatzpokémon. Die Daten sind
vollständig. Die ausgewählten Arten besitzen klar unterschiedliche,
passende Johto-Rufe.

## Meldung

Bitte notiere Edition, Sprache, Slot, PASS/FAIL und füge bei einem Fehler
einen Screenshot oder kurzen Clip bei.
