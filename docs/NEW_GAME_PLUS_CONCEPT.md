# Kanto Ascendant 6.5 — Vermächtnis-Reisen

## Grundregel

Eine Vermächtnis-Reise ist ein echtes neues Spiel, das ohne Umweg über den
Titelbildschirm beginnt. Das externe Kronenarchiv bewahrt ausschließlich die
dafür vorgesehenen Vermächtnisdaten. Bank und wandernde Trainer stehen im
frischen Lauf sofort zur Verfügung; normaler Storyfortschritt wird neu
begonnen.

## Drei Wege

Die Charakterwahl bindet den aktuellen Lauf an genau einen Weg:

- RED: Kampfweg mit fünf Stationen
- BLUE: Forschungs- und Strategieweg mit vier Stationen
- GREEN: Natur- und Erkundungsweg mit vier Stationen

Beim Abschluss wird das jeweilige Pfadsiegel dauerhaft im Archiv gespeichert.
Der aktive Avatar und der aktuelle Abschnitt werden im nächsten Lauf
zurückgesetzt. Die Vermächtnis-Galerie zeigt jedes verdiente Siegel; noch
unbekannte Trophäen bleiben verdeckt.

Jedes Pfadsiegel vergibt außerdem einen dauerhaften Vermächtnistitel:

- RED: **Kanto-Herausforderer**
- BLUE: **Eichs Erbe**
- GREEN: **Hüterin der Wildnis**

Nach dem Gesamtabschluss kommt **Vermächtnis-Hüter** hinzu. Freigeschaltete
und ausgewählte Titel bleiben über weitere echte Vermächtnis-Reisen hinweg im
Kronenarchiv erhalten.

## Eichs Partnerwahl

Die folgende Sequenz ersetzt Eichs normale Starterwahl ausschließlich während
einer aktiven Vermächtnis-Reise. Ein gewöhnlicher neuer Spielstand verwendet
weiterhin unverändert den Ablauf seiner Edition.

In Rot/Blau besitzen die drei Bälle feste Rollen:

1. **Links – Hoenn-Starter:** Der aktuelle Charakter erhält seinen festen
   Partner: RED → Flemmli, BLUE → Hydropi, GREEN → Geckarbor – jedoch erst,
   wenn genau dieser Charakter sein Höhlensiegel in einer früheren
   Vermächtnis-Reise verdient hat. Vorher bleibt der Ball sichtbar; Eich
   erklärt storygerecht, dass er für einen bewährten Trainer bestimmt ist und
   vielleicht im nächsten Leben geöffnet werden kann. Fremde Siegel schalten
   ihn nicht frei. Hier wird kein Sinnoh-Starter angeboten.
2. **Mitte – Partnerkatalog:** Ein grafischer, Pokédex-artiger Katalog zeigt
   Sprite, Nummer, Name, Typ und Entwicklungstempo. **Ausgewogen** enthält eine
   kuratierte Auswahl früher beziehungsweise schwächerer Partner. **Frei**
   enthält exakt die 129 niedrigsten Basisstufen oder linienlosen kanonischen
   Arten innerhalb #001-251. Existiert eine Babystufe in diesem Bereich,
   ersetzt sie die Entwicklung (Pichu statt Pikachu); Nebulak und Ditto sind
   zulässig, Gengar und Dragoran nicht. Vor der Vergabe sind zwei
   Bestätigungen nötig; Abbrechen verändert weder Team noch Pokédex.
3. **Rechts – Rivale:** Der Rivale ist schneller, kommentiert seine Wahl
   charakterabhängig und nimmt den Ball noch vor der Partnerwahl des Spielers
   aus der Szene. Das ist zunächst nur die sichtbare Reservierung: Seine
   tatsächliche Art und Entwicklungslinie werden erst nach der endgültigen
   Spielerwahl passend dazu bestimmt.

Der Katalog schaltet nicht vorsorglich #001-251 im Pokédex frei. Erst die
wirklich vergebene Art wird als gesehen und gefangen eingetragen. Vergabe,
Pokédex-Eintrag, Rivalenlinie und Vermächtnisarchiv bilden eine atomare,
dauerhafte Entscheidung: Entweder wird der vollständige Zustand gespeichert
oder die Wahl bleibt offen.

In Gelb bleibt die verfasste Pikachu-oder-Katalog-Verzweigung bestehen. Wer
Pikachu wählt, durchläuft die ursprüngliche Szene; eine Katalogwahl nutzt den
neuen Auswahlbildschirm. Die dazugehörige Evoli-Entscheidung und spätere
Entwicklungslinie des Rivalen bleiben an Gelbs eigene Logik gebunden.

## Abschluss

Nach allen drei Pfadsiegeln erscheint das Finale in Eichs Labor. Sein
Abschluss archiviert den dauerhaften Vermächtnis-Pass. Siegel und Pass bleiben
auch in weiteren echten Vermächtnis-Reisen erhalten.

## Sicherheitsregeln

- Archivschreibvorgänge bleiben transaktional und besitzen eine
  Rollback-Kopie.
- Ein abgebrochener Partnerkatalog oder ein fehlgeschlagener Schreibvorgang
  darf weder einen Pokédex-Eintrag noch eine halbfertige Rivalenwahl
  hinterlassen.
