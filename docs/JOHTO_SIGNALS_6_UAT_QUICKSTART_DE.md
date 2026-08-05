# Kanto Ascendant 6.0 – Johto Signals UAT

Dieser Test läuft vollständig getrennt von deinen normalen Spielständen.
Die eigene LOVE-Identität heißt `kanto-ascendant-signals-uat`; verwendet
werden ausschließlich die reservierten Slots `6001` bis `6024`.

## Start

Im Terminal:

```sh
cd /Users/maarten/Documents/Recompile/gen1recomp
LOVE_BIN=.tools/love-11.5-macos/love.app/Contents/MacOS/love

POKEPORT_IDENTITY=kanto-ascendant-signals-uat \
POKEPORT_VERSION=yellow \
"$LOVE_BIN" .
```

Für die anderen Editionen `yellow` durch `red` oder `blue` ersetzen.
Im Spiel bei der Spielstandauswahl die gewünschte Nummer `6001` bis `6024`
öffnen.

## Die wichtigsten End-to-End-Tests

| Slot | Was du tust | Erfolgreich, wenn |
|---|---|---|
| 6001 | Einen Schritt gehen, Angebot ablehnen, Gebiet verlassen und zurückkehren | Die Feldkapsel erscheint verständlich; NEIN sperrt nichts dauerhaft |
| 6002 | Feldkapsel annehmen und mit dem Bootsmann sprechen | Driftglass und die garantierte Rückfahrt werden vor Abfahrt erklärt |
| 6003 | Auf Driftglass speichern/neustarten, zurücksegeln, Sender reparieren, beide Boote testen | Kein Warp auf eine Testinsel, kein Feststecken, Queststand bleibt erhalten |
| 6004 | 30 normale Kämpfe mit `KANTO FIRST` | Es erscheint kein frühes Johto-Pokémon |
| 6005–6007 | Die drei Johto-Modi und mehrere Habitate testen | Anzeige und Begegnungen entsprechen 2 %, 4 % beziehungsweise 10 % |
| 6008–6011 | `SCAN CURRENT AREA` in Wald, Küste, Vulkan und Höhle benutzen | Nur die passende Spur wird geöffnet; der Name bleibt bis zur echten Sichtung `???` |
| 6012–6015 | Jeweils die nächste geeignete Begegnung auslösen | Endivie, Karnimani, Feurigel beziehungsweise Larvitar erscheint garantiert |
| 6016 | Echo schwächen, Status setzen, Meisterball werfen und FLUCHT wählen | Es bleibt bei 1 KP, weist Fang und Flucht ab, gibt den Meisterball zurück und kämpft bis zur Niederlage |
| 6017–6018 | Resonanz-Siegel beim Forscher anfordern | Mit drei Orden klare Ablehnung; mit vier Orden Vergabe auch bei vollem Beutel |
| 6019 | Nächste geeignete Grasbegegnung auslösen | Ein aktiviertes, noch nicht gefangenes Mew oder Celebi erscheint fangbar |
| 6020–6021 | Gebundenes Mew beziehungsweise Celebi erneut auslösen | Dasselbe Pokémon kehrt mit gespeichertem KP- und Statuszustand zurück |
| 6022 | Speichern, Mod aus, laden/speichern, Mod wieder an | Johto-Pokémon, Dex und beide Zähler bleiben erhalten |
| 6023 | Endivie-Prüfung in Prismania abschließen | Früher Fang wird erkannt; Belohnung ist Ersatz statt eines Duplikats |
| 6024 | Auf Driftglass speichern, Mod aus/an und neu laden | Sicherer Rückfall nach Alabastia; kein unbekannter Karten-Crash oder Datenverlust |
| 6025 | Zweite Glasfuge betreten; Prismengrotte absichtlich richtig und falsch spielen | Alle Säulen erreichbar; falscher Ton setzt nur die Folge zurück; Items nie doppelt; EVOLI-Ritual wiederholbar |
| 6026 | Beim Direktstart **JA** wählen, Anwendung vollständig beenden und denselben Slot neu laden | Die Auswahl wurde sofort gespeichert; die Frage erscheint nicht erneut |
| 6027 | Beim Direktstart **NEIN** wählen, Anwendung vollständig beenden und denselben Slot neu laden | Die Feldquest bleibt aktiv; die Frage erscheint nicht erneut |
| 6028 | Nationaldex #152–251 durchblättern und besonders #152, #158, #177, #201, #245 und #251 öffnen | Richtige Crystal-Sprites, vollständige Daten und klar unterschiedliche echte Johto-Rufe |

## Was unbedingt gemeldet werden soll

- unleserliche oder abgeschnittene Texte;
- ein Warp außerhalb von Kanto oder Driftglass;
- falsche Sprites, Platzhalter oder Kanto-Arten anstelle von Johto-Arten;
- falsche Sprache, vorzeitig sichtbare Dex-Namen oder nicht erklärte Menüpunkte;
- verlorene Items, Pokémon, Zähler oder Queststände nach Neustart;
- jede Situation, in der Driftglass nicht wieder verlassen werden kann.

Bitte immer Edition, Sprache, Slot, genaue Aktion und wenn möglich einen
Screenshot nennen.

Die vollständige Prüftabelle und alle technischen Sicherheitsbedingungen
stehen in `JOHTO_SIGNALS_6_UAT_RUNBOOK.md`.
