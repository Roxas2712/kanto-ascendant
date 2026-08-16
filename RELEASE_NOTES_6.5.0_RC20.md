# Kanto Ascendant 6.5.0 RC20

## Roter Titelbildschirm

- Behoben: Der deutsche 80x8-Editionsstreifen konnte von einem späten
  Grafikanbieter zusätzlich als Titel-Pokémon geliefert werden.
- Dadurch flog neben dem festen „ROTE EDITION“-Band ein zweites Exemplar von
  rechts in die Pokémon-Fläche.
- Der finale Titelgrafik-Resolver akzeptiert dort nur noch bildförmige
  Pokémon-Grafiken und fällt bei Ribbon-/Textstreifen auf das echte Pokémon
  zurück.

## Abnahme

- Der Fehler wurde mit einem absichtlich als Pokémon eingespeisten
  „ROTE EDITION“-Streifen reproduziert.
- Anfang, Mitte und Ende des echten TitleState-Einflugs wurden mit aktivem
  Deutsch-Mod und Kanto Ascendant gerendert.
- Ergebnis: genau ein statisches Editionsband; im bewegten Slot erscheint
  ausschließlich das Pokémon.
