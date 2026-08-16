# Kanto Ascendant 6.5.0 RC14

RC14 baut vollständig auf RC13 auf. RC13 bleibt als unveränderter Rückweg
erhalten.

## Lugia

- Die frühere zufällige Lugia-Vorahnung wurde vollständig entfernt.
- Alte gespeicherte Lugia-Vision-Flags werden bei der nächsten
  Zustandsnormalisierung gelöscht und können keine Begegnung mehr auslösen.
- Lugia bleibt über den vorhandenen regulären Kanto-Ascendant-Fangweg
  erreichbar. Fangort, Freischaltung und Fangmechanik wurden nicht ersetzt.
- Der Optionspunkt heißt deshalb jetzt eindeutig **HO-OH-VISION**.

## Nuzlocke-Schutz für mythische Ascendant-Begegnungen

Bei einer Niederlage in den vorgesehenen Ho-Oh-, Celebi- und Mew-Ereignissen
gilt nun ein eng begrenzter Schutz gegen die Löschlogik der eingebauten
Nuzlocke-Mod:

- besiegte Team-Pokémon werden nicht aus dem Spielstand gelöscht;
- der Nuzlocke-Spielstand wird bei einem vollständigen Team-KO nicht beendet
  oder gelöscht;
- der Kampf endet als normale Niederlage;
- das vollständige Team wird geheilt;
- der Spieler kehrt zum zuletzt besuchten Pokémon-Center zurück.

Abgedeckt sind reguläres Ascendant-Ho-Oh, reguläres Celebi, Celebi-Signale,
Route-24-Mew, echte Mew-Signale und die nicht fangbaren Mew-/Celebi-Echos.
Die kampflose frühe Ho-Oh-Vision aus RC13 kann weiterhin weder Schaden noch
eine Niederlage auslösen.

Der Schutz ist bewusst nicht allgemein: Lugia und gewöhnliche Kämpfe folgen
weiterhin den ausgewählten Nuzlocke-Regeln.

## Rückweg

Vor einem Rückweg Spiel und Mod schließen und den Spielstand sichern. Danach
RC14 deaktivieren/entfernen und das unveränderte RC13-Testpaket erneut
importieren.
