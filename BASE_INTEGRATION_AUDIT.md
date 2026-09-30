# KASC 6.7.30-rc.1 – vollständiger Basisabgleich

## Fehler und Korrektur

Der mit VASC rc.9–rc.14 beigelegte KASC-Begleiter 6.7.29-rc.4.pyro.1/.2 stammte aus dem Hoenn/Pyro-Zweig auf Basis **6.7.28**. Die Versionsnummer suggerierte einen neueren Gesamtstand. Die spätere Integrations-/6.7.29-Basis war darin nicht enthalten. Dies war ein Paketierungsfehler.

Neuer Kandidat: vollständige Quelle `09df020f16c0235d19682d48edb410dedb321523` (öffentlicher 6.7.29 inklusive Integrations-RC.3) zusammengeführt mit `5edc6a4bae6a2a4451aebd4ed24478fa412fd8ff` (Hoenn NG+, kompakter Pyro-Vulkan, Gorochu). Gemeinsamer Vorfahr: `4a1c8c66da75e2a9461aacc08b427e100328d5b4`.

Der Quellvergleich prüft jede seit dem gemeinsamen Vorfahren geänderte Datei beider Zweige: 40 Dateien des neueren Basiszweigs und 25 des Hoenn/Pyro-Zweigs. Alle Laufzeitdateien und Assets beider Seiten bleiben bytegleich zur jeweiligen Quellrevision erhalten. Nur README, aktuelle Versions-/Installationshinweise und Paketquittungen werden zusammengeführt beziehungsweise erneuert. Es gab keine Laufzeit-Codekonflikte.

## Wiederhergestellte Änderungen

Im alten Pyro-Begleiter fehlten gegenüber der neueren Basis **24 vollständige Dateien**. Zusätzlich standen zwölf bestehende Laufzeitdateien auf dem älteren Stand:

- Vollständiger eingebetteter Startbildschirm mit nativer Vorbereitung, VASC-Vorbereitung, Warteschlange, Szene, Bildern und Klang; Verdrahtung über `entry.lua`. Die öffentliche 6.7.29 enthält gegenüber Integrations-RC.3 zusätzlich Startdiagnostik und eine bei langen Frames nicht übersprungene Animationszeit. Diese neuere Fassung bleibt erhalten.
- Geschenkprofil-Historien mit gemeinsam genutzten unveränderlichen Datensätzen (`backend_gift_profiles_67.lua`), optimierte Live-Lernlisten und Generationsprojektion. Dadurch gehen die neueren Speicher-/CPU-Optimierungen nicht erneut verloren.
- Figuren-/Kleiderschrank-Anbindung und Porträtprüfung (`extended_characters.lua`, `wardrobe_authored_assets.lua`, `wardrobe_presentation.lua`).
- Wilds: Umgebungsfigurenplanung, Behandlung zunächst leerer Begegnungstabellen, Darstellung und Abschluss der Sprite-Quellen-Ermittlung.
- Zwischengespeicherte Versionsprüfung mit weiterhin aktueller Funktions-/Herkunftsprüfung des Renderers.
- Acht zugehörige Regressionstests, RC-Dokumentation und überprüfbare Paketquittungen.

Die Hoenn-NG+-Habitate, Eon-Roamer, Besucherfigur/-Zeitplan, Pyro-Route und kompakte Plattform sowie Gorochus explizite Crystal-Farbwahl bleiben zusätzlich enthalten.

## Archivvergleich

Alle Dateien der folgenden fünf lokalen Referenzarchive wurden mit der zusammengeführten Quelle verglichen. Aus keinem Referenzarchiv fehlt eine Datei. Abweichende Dateien sind entweder die oben zusammengeführten Funktionen, die spätere Startbildschirmkorrektur oder Versions-/Release-/Paketmetadaten.

- `deliverables/VASC-Live-Wetter-Cobble-RC1/Kanto-Ascendant-6.7.29-rc.integration.1.zip`: 5761 Dateien; 0 fehlend.
- `deliverables/Ascendant-Startup-RC10/Kanto-Ascendant-6.7.29-rc.integration.2.zip`: 5774 Dateien; 0 fehlend.
- `deliverables/Ascendant-Startup-RC11/Kanto-Ascendant-6.7.29-rc.integration.3.zip`: 5774 Dateien; 0 fehlend.
- `deliverables/Ascendant-Public-20260929/KASC/Kanto-Ascendant-6.7.29.zip`: 5774 Dateien; 0 fehlend.
- `deliverables/VASC-3.0.57-rc.14-Local/Kanto-Ascendant-6.7.29-rc.4.pyro.2.zip`: 5765 Dateien; 0 fehlend.

Die vollständigen Dateilisten und Abweichungen liegen unter `artifacts/kasc-complete-base-audit-20260930/archive-comparison.json` und `base-preservation.json` im Projekt. Die Archivprüfung am fertig gebauten ZIP wird zusätzlich in `kasc-verification.json` festgehalten.

## Separater Sevii-Arbeitsstand

`.worktrees/kasc-sevii-expedition-20260928` ist ein eigener, weiterentwickelter Arbeitsstand mit uncommittierten Erweiterungen. Er war kein Bestandteil der hier verglichenen Integrations-RCs. Die dortige `SEVII_DELIVERY_CHECKLIST_DE.md` nennt ausdrücklich: „Dieser Arbeitsstand ist noch nicht die fertige Erweiterung.“ Noch offen sind unter anderem Teile der Gebäudefunktionen/Items, weitere Legendenpfade und das vollständige Installationskonzept der zusätzlichen Grafiken. Dieser Stand wurde nur gelesen und weder verändert noch blind in den Reparaturkandidaten gemischt. Er ist kein im damaligen RC verlorener Fix.

## Validierung und Grenzen

Alle 13 gezielt ausgewählten Regressionstests bestanden: acht neuere Basis-/Performance-Tests, NG+-Habitate (3913 Prüfungen), native NG+-Integration (130), Besucherzeitplan/Speicherupgrade (24), Pyro-Route (1554), expliziter Crystal-Stil einschließlich normal/shiny, front/back und fortlaufenden Frames.

Mit dem zusammengeführten KASC im isolierten nativen Client: Pyro fehlt im alten Raum auch nach Speichern/Laden und existiert genau einmal im Vulkan. Die neuen VASC-Türproportionen und Nachtbeleuchtung sind in separaten Aufnahmen geprüft. Ein geometrischer Lauf über 145 unterstützte Räume prüft alle 103 dort gefundenen geschlossenen Holztüröffnungen auf normale Proportionen.

Zusätzlicher nativer Pyro-Durchlauf bestanden (`blaine-roundtrip2.log`): alte Arena → Gang → Vulkanfuß → Plattform, Speichern/Laden im neuen Raum, echter Aufruf des Storykampfes, Vulkanorden/Feuersturm ohne doppelte Belohnung, Erkennung für Meister-/Kronenkämpfe und Rückweg nach Zinnober. Der Sieg wird vom Prüftreiber über den nativen Abschluss-Callback gesetzt; dies prüft Belohnungen und Fortsetzung, nicht KI oder Kampfbalancing. Der erste Versuch brach wegen einer fehlenden QA-Umgebungsvariable vor Testbeginn ab und ist kein Produktfehlernachweis.

Nativer Startbildschirmtest mit beiden Mods bestanden (`startup-native.log`): Neues Spiel erst nach dem ersten dargestellten Startbildschirmframe; Spielfigur im Hintergrund unbeweglich; Eichen-Dialog erhalten. Fortsetzen übernimmt den ausgewählten QA-Spielstand, wartet auf native Assets und VASC-Zielszene, zeigt danach die spielbare Welt und stellt die native Zeichenfunktion wieder her. Alle Pflichtjobs sind `ready`; kein Startbildschirmfehler.

Keine persönlichen Spielstände geändert. Kein öffentlicher Release, kein Push und keine Installation in das Benutzerprofil. Keine Behauptung eines vollständigen Spieldurchlaufs oder einer physischen Android-FPS-Messung. Der separate Sevii-Entwicklungsstand und nicht zu diesen Quellzweigen gehörende offene Featurewünsche sind nicht als erledigt deklariert.
