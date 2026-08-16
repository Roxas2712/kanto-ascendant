# Kanto Ascendant 6.5.0 – Phase 8 Abnahmebericht

Stand: 10. August 2026

## Ergebnis

Die aktuelle Phase-8-Fassung besteht die vollständige Charakter-, Rivalen-,
Gender- und Breeding-Abnahme ohne offenen Testfehler.

- `CRYSTAL CHARS` ist der Standard.
- `ASCENDANT CHARS` bleibt als umschaltbare Alternative erhalten.
- Rot, Blau und Grün/Casey verwenden in 2D- und Voxel-Kämpfen ausschließlich
  ihre festgelegten Crystal-Dateien. Ein Rückfall auf GBA/FRLG- oder
  Walking-Sprites wird von den Tests ausdrücklich abgelehnt.
- Rot, Blau und Gelb wurden jeweils mit ihrem echten Datensatz gebootet.
- Deutsch und Englisch wurden getrennt mit den echten Menüs und Dialogboxen
  gerendert.

## Charakterdarstellung

Die aktiven Crystal-Quellen sind:

- `assets/characters/crystal_chars/red_front.png`
- `assets/characters/crystal_chars/blue_front.png`
- `assets/characters/crystal_chars/green_front.png`
- `assets/characters/crystal_chars/red_back.png`
- `assets/characters/crystal_chars/blue_back.png`
- `assets/characters/crystal_chars/green_back.png`
- `assets/characters/crystal_chars/red_voxel_front_hd.png`
- `assets/characters/crystal_chars/blue_voxel_front_hd.png`
- `assets/characters/crystal_chars/green_voxel_front_hd.png`

Der Voxel-Test prüft zusätzlich den exakten HD-Quellpfad, die 320×288-
Billboard-Erzeugung, Spiegelung, Kopfbegrenzung, Gender-HUD und das Erreichen
des Kampfmenüs. Ergebnis: **44/44**.

Kuratierte Belege im RC-Zweig:

- [Casey gegen Rot in Voxel](../qa/phase8_full_acceptance_final/casey_vs_red_voxel.png)
- [Rot gegen Blau in 2D](../qa/phase8_full_acceptance_final/red_vs_blue_champion.png)
- [Blau gegen Grün in 2D](../qa/phase8_full_acceptance_final/blue_vs_green_champion.png)

## Alle Rivalenkämpfe

Jeder vorhandene Rivalen-Kampf wurde live bis zum vollständig eingelaufenen
Trainer-Intro gestartet. Pro Kampf wurden Team, Level, Identitätszuordnung,
64×64-Crystal-Front, 64×64-Crystal-Back und Screenshot geprüft.

| Edition | Varianten | Prüfungen | Ergebnis |
| --- | ---: | ---: | --- |
| Rot | 72 | 371 | 371/371 |
| Blau | 72 | 371 | 371/371 |
| Gelb | 48 | 251 | 251/251 |

Gelb besitzt absichtlich nur 16 echte Rivalenvarianten je Identität: Die
frühen Kämpfe sind fest, die späteren Kämpfe verzweigen nach Evoli-Entwicklung.
Darum sind dort 48 statt 72 Live-Kämpfe korrekt. Insgesamt entstanden
**192 Live-Kämpfe und 192 aktuelle Screenshots**.

Die vollständigen 192 Rohaufnahmen und Laufprotokolle wurden in der
ursprünglichen Abnahme aufbewahrt. Der RC-Zweig enthält bewusst nur die drei
repräsentativen, oben verlinkten Endbilder; QA-Massenartefakte gelangen nicht
in das Spielerpaket.

Rots Champion-Team ist in allen drei Starterzweigen fest geprüft:
Pikachu 81, Psiana 73, Relaxo 75, Bisaflor 77, Glurak 77 und Turtok 77.

## Namen und Dialoge

Die echte englische Charaktersequenz besteht unter Rot, Blau und Gelb jeweils
mit **61/61** Prüfungen. Die echte deutsche Sequenz besteht mit **20/20**.

Geprüft wurden unter anderem:

- Charakterwahl beginnt bei Grün und zeigt die unveränderliche Identität als
  `GREEN/BLUE/RED` bzw. `GRÜN/BLAU/ROT`; der frei wählbare Spielername folgt
  weiterhin erst auf dem separaten Namensbildschirm.
- Grün: `GRÜN`, `CASEY`, `JEAN`, danach `NEUER NAME`.
- Spielt man Grün, erhält Rot: `ROT`, `ASH`, `JACK`, danach `NEUER NAME`.
- Rollen: `MEINE ENKELIN`, `MEIN ENKEL`, `EIN JUNGE AUS ALABASTIA`.
- Rot wird als Trainer aus Alabastia bestätigt und nicht als Eichs Enkel.
- Grüns Mutter sagt: `Alle Mädchen ziehen eines Tages los.`
- Rots Labordialog ist ruhig: `Sehen wir, was unsere POKéMON können.`
- Englisch und Deutsch werden nicht vermischt.

Die Dialogläufe wurden als Teil der vollständigen Abnahme protokolliert. Ihre
Ergebnisse werden zusätzlich durch die automatischen Sprach- und
Editionsprüfungen im RC reproduziert.

## Pokémon-Gender und Breeding

Der aktuelle Ingame-Lauf besteht mit **36/36** Prüfungen und 17 Screenshots.
Zusätzlich bestehen die isolierten Gender-Checks mit **36/36** und die
Breeding-Checks mit **31/31**.

Geprüft wurden:

- weibliche, männliche und geschlechtslose Anzeige in Team und Bericht;
- Gender-Symbole im 2D- und Voxel-Kampf;
- Nidoran♀ und Nidoran♂ unabhängig von entgegenstehenden DVs;
- Day-Care-Paarung und Kompatibilität;
- Ei-sicheres Teammenü;
- Wackeln, Riss und Enthüllung der Schlüpfanimation.

Die vollständigen Gender-, Day-Care- und Schlüpfaufnahmen gehören zum
archivierten Abnahmelauf; die zugehörigen Logikverträge laufen im RC erneut als
36 Gender- und 31 Breeding-Prüfungen.

## Automatische Tests

Alle aktuellen isolierten Tests bestehen:

| Test | Ergebnis |
| --- | ---: |
| Charaktere | 139/139 |
| Gelb-Kompatibilität | 19/19 |
| Sprachtrennung | 18/18 |
| Rivalenteams | 16/16 |
| Pokémon-Gender | 36/36 |
| Breeding | 31/31 |
| Crystal-Assetstruktur | 306/306 |

Das sind nach der RC-Integration **565/565** automatische Einzelprüfungen.

## Abnahmestatus

Für den geprüften Umfang sind keine offenen Fehler verblieben. Die Demo kann
mit `CRYSTAL CHARS` als Standard ausgeliefert werden; die bisherigen
Ascendant-Charaktere bleiben über das Kanto-Ascendant-Menü anwählbar.
