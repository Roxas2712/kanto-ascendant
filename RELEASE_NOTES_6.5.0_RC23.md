# Kanto Ascendant 6.5.0 RC23

## New Game+ abgeschlossen

- Die Vermächtnis-Reise startet nach dem Champ weiterhin direkt vom
  Zimmer-PC in Eichs neue Reise, ohne Rückkehr zum Titelschirm.
- Bank, Lager, Geld, vollständige Pokémon-Daten und wandernde Trainer bleiben
  über den sicheren Archiv- und Rückrollpfad verfügbar.
- Nur während einer aktiven Vermächtnis-Reise erhält Eichs Labor in Rot/Blau
  die neue Drei-Ball-Sequenz. Links wartet der charaktergebundene
  Hoenn-Starter: Rot → Flemmli, Blau → Hydropi, Grün → Geckarbor. Er wird erst
  nach dem passenden, in einer früheren Reise verdienten Höhlensiegel
  auswählbar; vorher bleibt der Ball sichtbar und Eich verweist auf ein
  mögliches nächstes Leben. Es gibt dort keinen Sinnoh-Starter; ein normaler
  Kampagnenstart bleibt unverändert.
- Der mittlere Ball öffnet einen grafischen, Pokédex-artigen Partnerkatalog.
  **Ausgewogen** bietet eine kuratierte Auswahl früher beziehungsweise
  schwächerer Partner; **Frei** enthält exakt die 129 niedrigsten Basisstufen
  oder linienlosen Arten innerhalb #001-251 (Pichu statt Pikachu; Nebulak und
  Ditto ja, Gengar und Dragoran nein). Die Auswahl zeigt Art, Typ und Entwicklungstempo, verlangt eine doppelte
  Bestätigung und trägt ausschließlich den tatsächlich gewählten Partner in
  den Pokédex ein.
- Den rechten Ball nimmt der Rivale mit charakterabhängigem Dialog zuerst und
  er verschwindet noch vor der Spielerwahl. Welche Art und Entwicklungslinie
  er tatsächlich erhält, wird jedoch erst aus der bestätigten Partnerwahl des
  Spielers bestimmt. Partner, Rivale, Pokédex und Vermächtnisarchiv werden als
  eine dauerhafte, atomare Entscheidung gespeichert.
- In Gelb bleibt die eigens verfasste Pikachu-oder-Katalog-Verzweigung samt
  Evoli-Logik des Rivalen erhalten.
- Dafür sind ausschließlich die drei Hoenn-Starterfamilien #252-260 samt
  Rückseiten, Shinys, Rufen, Teamicons und Followergrafiken registriert. Sie
  tauchen nicht wild auf und schalten kein übriges Hoenn frei.
- Die drei Pfadsiegel schalten weiterhin ihre dauerhaften Vermächtnistitel
  frei; der abgeschlossene Vermächtnis-Pass bleibt ebenfalls als Titel im
  Kronenarchiv erhalten.
- Die drei Rot-/Blau-/Grün-Risskampagnen sind über den regulären
  `main.lua`-Pfad mit lauflokalen und dauerhaften Vermächtnisdaten sowie
  `HEVO_DOOR_QUEST_READY` verbunden. Rätsellösungen und einzelne
  Durchgangsflags werden nicht als Ersatz für das dauerhafte Pfadsiegel
  gewertet.

## Johto und sichtbare Begegnungen

- Vor der Driftglass-Konfiguration kann keine Johto-Art über Gras, Wasser,
  Höhlen, Stadt-Pokémon, Lind-Forschung oder sichtbare Wilds durchsickern.
- **Wanderwellen** erlauben nur die aktuelle Welle, nur auf den bereits
  verfassten Routen und mit derselben 2-/4-Prozent-Rate wie ohne sichtbare
  Wilds.
- **Johto entfesselt** ist die ausdrückliche Alles-sofort-Auswahl: alle
  verfassten gewöhnlichen Basisspezies plus Endivie, Feurigel, Karnimani und
  Larvitar erscheinen auf ihren vorhandenen Routen mit derselben
  10-Prozent-Rate.
- Die sichtbare Welt übernimmt den nativen Begegnungswurf. Dadurch bleiben
  Routenverteilung und Anzahl der Pokémon identisch; nur ein erfolgreicher
  Johto-Ersatz ändert Art und passendes Level.
- Raikou, Entei, Suicune, Lugia, Ho-Oh, Celebi und andere mythische Abläufe
  bleiben aus generischen Pools ausgeschlossen. Sie werden nur sichtbar,
  wenn ihr jeweiliges Ereignis tatsächlich aktiv ist.
- Ein getrenntes Kompatibilitätsmodul registriert genau 19 genehmigte Arten
  auf den privaten Dex-Plätzen #261-279: 17 Weiterentwicklungen vorhandener
  Kanto-/Johto-Linien sowie Azurill und Isso. Ihre Leveltabellen stammen aus
  HGSS und werden ausschließlich auf bereits wirklich registrierte Attacken
  projiziert. Sie erhalten dadurch weder allgemeine Gen-IV-Wildplätze noch
  einen Sinnoh-Dex.
- Die 17 späteren Entwicklungen hängen an genau 15 Forschungsfreigaben:
  fünf für Rot, fünf für Blau und fünf gemeinsame Pakete mit sieben Zielen
  für Grün. Es gibt keinen allgemeinen `HEVO_*_RELIC`-Beutepool.
- Schutzpanzer, Magmaisierer, Stromisierer, Dubiosdisc, Scharfzahn,
  Scharfklaue, Leuchtstein und Finsterstein laufen als gezielte
  Einzelspieler-Entwicklungsitems. Magnet-, Moos- und Eisfeld bleiben
  wiederverwendbare Feldmethoden; Walzer, Antik-Kraft und Doppelschlag sind
  echte Kenntnisbedingungen.
- Vor dem passenden Pfadsiegel sind weder Erstfund noch Werkstattquelle oder
  Zufallsbeute verfügbar. Nach der ersten sicheren Vergabe kann die jeweilige
  Quelle in der Vermächtniswerkstatt wiederholt genutzt werden; Abbruch,
  Fehlziel, voller Beutel und Schreibfehler verbrauchen nichts.

## Hoenn-Megaformen

- Mega-Lohgock, Mega-Sumpex und Mega-Gewaldro besitzen eigene Steine,
  finale Formprofile, voneinander unabhängige Front-/Rückseiten sowie
  Normal-/Shiny-Animationen. Crystal-, Gen-I- und Voxelpfad verwenden die
  jeweilige Megaform und fallen nicht auf die Normalform zurück.
- **Noch offenes RC-Gate:** Die drei Steine sollen dauerhafte,
  charaktergebundene Geheimfunde ihrer Rot-/Blau-/Grün-Kampagne sein. Der
  aktuelle Zwischenstand vergibt sie jedoch zusätzlich beim normalen
  Dungeonabschluss und synchronisiert den optionalen Kartenfund noch nicht
  atomar mit Steinkoffer beziehungsweise Pending-Reconcile. Diese
  Progressionskante gilt erst nach Abschluss-ohne-Fund, späterem
  Wiederbetreten, Schreibfehler- und Exact-once-Test als freigegeben.

## Espeon-Learnset

- Behoben: Espeon lernt Psybeam als reguläre Gen-II-Level-Attacke auf Level 36.
- Bereits höherstufige Espeon können Psybeam ab Level 36 beim Attacken-Erinnerer
  nachlernen; unter Level 36 wird die Attacke noch nicht angeboten.
- Diese Korrektur verändert keine RBY-Level-Learnsets und fügt Psybeam nicht
  zur optionalen Johto Move Resonance hinzu.

## Johto-Attacken beim Attacken-Erinnerer

- Der Attacken-Erinnerer auf Route 5 liest nach der Reparatur des
  Driftglas-Empfängers nun denselben artspezifischen Katalog wie die optionale
  Johto Move Resonance. Dadurch kann etwa Sichlor ab Level 18 Trugschlag
  nachlernen, ohne dass sein RBY-Level-Learnset verändert wird.
- Alle 100 Johto-Arten bleiben auf ihrem regulären Crystal-Learnset-Pfad;
  Kanto-Arten erhalten ausschließlich kompatible, mechanisch vollständig
  implementierte Gen-II-Attacken. Es gibt keinen globalen Attackenpool.
- Nicht vollständig umgesetzte Spezialmechaniken wie Verfolgung bleiben im
  Audit sichtbar und werden nicht durch wirkungslose Ersatzattacken simuliert.

## Fangballgrafik

- Die Modern-Darstellung verwendet jetzt die gelieferten Journeys-/Essentials-
  Grafiken für Poké-, Super-, Hyper-, Meister- und Safariball sowie alle sieben
  Aprikoko-Bälle. Der frühere Frame-0-Fehler ist behoben; alle acht gelieferten
  Phasen laufen über das echte Fanganimations-Timing.
- Toss, Roll/Shake, Ausbruch, Erfolg, voller PC, No-Catch und Trainerblock sind
  in Rot, Blau und Gelb auf Modern- und Originalroute renderer-backed geprüft.
  Original behält bewusst die native Gen-I-Vierfarbendarstellung.
- Die getrennten `_open`-Master bleiben als belegte Quellassets erhalten. Sie
  werden nicht in einen falschen Zustand eingeblendet, weil die Gen-I-
  Animationskette keinen separaten Open-Ball-Zeichenschritt besitzt.

## Rückweg

RC23 ersetzt keine RC22-Datei außerhalb des neuen Pakets. Das getrennte
Rollback-ZIP enthält den unveränderten, bereits abgenommenen RC22-Stand.
