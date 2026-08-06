# Kanto Ascendant 6.5.0 — interner Release Candidate 4

Dieser RC ist intern. STARFALL TIDES bleibt für 7.0 reserviert; die
6.x-Hotfix-Schiene bleibt offen.

## Neu und korrigiert

- Alle neuen Einstellungen liegen unter
  `ASCENDANT > OPTIONEN`: Beutel/Boxen, Sprites, QoL, Schnellwahl,
  Anzeige/Skins sowie Johto/Sicherheit.
- Das QoL-Paket besitzt einen echten Hauptschalter und weiterhin einzeln
  speicherbare Einstellungen für EP-Leiste, Fangsymbol, einfache
  Interaktionen, Gebietsanzeige, Pokédex-/Box-Filter und Texttempo.
- Schnellwahl ist getrennt konfigurierbar: Hauptschalter, SELECT-Tipp,
  Beutelregistrierung, Leerhinweis und Reitsteuerung.
- Fünf ASC-Beutelmodi:
  - aus / externe Useful Bag,
  - Spielstandard,
  - Standardgröße mit FireRed-Skin,
  - 999 Plätze mit Skin ohne Fächer,
  - 999 Plätze mit Skin und sechs Fächern.
- FireRed-inspirierte Beutel-, Box-, Team- und Statusoberflächen; schneller
  Boxwechsel mit Links/Rechts sowie artgerechte Team- und Boxporträts.
- Nach einem direkten Fangtransfer wird die Zielbox ausdrücklich genannt.
- Optionale Statusseite für Gen-I-DVs/IVs und Stat-Exp/EVs.
- Optionale moderne Poké-, Super-, Hyper-, Meister- und Safariball-Skins auf
  den originalen Wurf-, Roll- und Wackelanimationen.
- Vollständige Sprite-Steuerung für #001–251 nach Oberfläche, einschließlich
  normaler und schillernder Crystal-Front- und -Backsprites.
- Deutsche Kanto-Pokédex-Kategorien für alle 151 Pokémon korrigiert:
  FUKANO ist wieder `WELPEN` statt `SEEHUND`.
- Deutsche Boxaktion `ABLEGEN` korrigiert und der Spielername `ASH` bleibt
  als Name unverändert.
- Gen-I-inkompatible UI-Zeichen entfernt; keine fehlenden Glyphen in den
  neuen Laufzeit-Screens.

## Verifikation

- 67/67 gezielte 6.5-Plumbing-/Funktionstests
- 6581/6581 vollständige Modprüfungen
- 6603/6603 Upgrade- und Save-Matrix-Prüfungen
- 49/49 echte englische LÖVE-Laufzeit-/Screenshotprüfungen
- 9/9 echte deutsche LÖVE-Laufzeit-/Screenshotprüfungen
- alle fünf Beutelmodi separat mit Renderer, Fächern und Kapazität geprüft
- Importpaket wird zusätzlich auf Manifest an der ZIP-Wurzel geprüft

Implementierungsstand: `f8b8c4ee70800dee9e3d9d976a0a8aa570028986`

