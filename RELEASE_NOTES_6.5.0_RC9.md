# Kanto Ascendant 6.5.0 — interner Release Candidate 9

Dieser RC ersetzt RC8 intern. STARFALL TIDES bleibt für 7.0 reserviert; die
6.x-Hotfix-Schiene bleibt offen.

## Teamicons auf gen1recomp 0.1.75

- Die mitgelieferten, animierten Crystal-/FollowerEX-artigen Teamicons für
  Nationaldex #001–251 werden nun über die öffentliche
  `PartyMenu.drawIcon`-Schnittstelle der ausgelieferten Engine 0.1.75
  eingebunden.
- Auf älteren Engine-Ständen bleibt der bisherige kompatible Hook erhalten.
- Globales `CRYSTAL 2D` plus aktivierte Team-/Status-Sprites stellt auch bei
  einem alten gespeicherten `TEAM-ICONS: KLASSISCH` automatisch die
  artgenauen Ascendant-Icons her.
- Eine separat installierte Icon-Mod behält weiterhin Vorrang; Follower EX
  ist für das integrierte Paket nicht erforderlich.

## Tasche

- Ist das normale ITEMS-Fach leer, öffnet der Ascendant-Beutel automatisch
  das erste nichtleere Fach. Leere Fächer bleiben weiterhin über L/R
  erreichbar.
- Deutsche und englische Leertexte bleiben vollständig innerhalb der
  FireRed-artigen Beutelrahmen.
- Auswahl, Fachwechsel und die engine-eigenen BENUTZEN/WEGWERFEN-Aktionen
  bleiben unverändert funktionsfähig.

## Verifikation

- 10/10 Laufzeitprüfungen auf der tatsächlich ausgelieferten
  `gen1recomp-0.1.75.love`
- 10/10 weitere Prüfungen mit isolierter Kopie der installierten Mods,
  deutschen Optionen und RED++-Darstellung
- getrennte Ruhe-/Animations-Screenshot-Nachweise für artgenaue
  #001/#025/#151-Teamicons
- sichtbarer Screenshot-Nachweis für gefüllten und leeren modernen Beutel
- 585/585 gezielte 6.5-QoL-, Fang-, Ball- und Icon-Prüfungen
