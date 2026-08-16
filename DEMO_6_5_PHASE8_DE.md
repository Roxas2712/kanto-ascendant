# Kanto Ascendant 6.5 — Phase-8-Demo

## Installieren

1. Importiere `Kanto-Ascendant-6.5.0-phase8-full-demo.zip` im Gen1-Recomp-
   Launcher.
2. Starte das Spiel neu und aktiviere **Kanto Ascendant**.
3. Für die Charakterauswahl wähle ein neues Spiel in Red, Blue oder Yellow.
   Bestehende Saves dürfen weitergeladen werden, zeigen den Oak-Auswahldialog
   aber naturgemäß nicht rückwirkend.

## Schnelle Demo-Route

1. Bereits das Titelbild zeigt die Mod: Grün erscheint zuerst; bei jedem
   Pokémonwechsel folgen Blau, Rot und wieder Grün. Pokémon und Figuren
   behalten exakt ihre Originalpositionen; Grün und Blau werden als sauber
   freigestellte PNG-Flächen ohne weißen Hintergrund darüber gezeichnet.
   Der Schriftzug `KANTO ASCENDANT` steht horizontal zentriert am unteren
   Bildschirmrand.
2. Im Eich-Intro erscheint direkt die verpflichtende Auswahl für Grün, Blau
   oder Rot; Grün ist zuerst markiert und die Vorschau zeigt ihr vollständiges
   56×56-Casey-Trainerporträt. Die separate 16×16-Laufgrafik erscheint erst in
   der Spielwelt. Eich übernimmt den gewählten Walker noch im selben New-Game-
   Ablauf; der Rivale und die dritte Zuordnung folgen der festen Matrix.
   Vor der Benennung stehen in allen drei Auswahlzeilen nur `???`; Porträt und
   Rollenbeschreibung wechseln mit dem Cursor. Grün erhält
   `GRÜN / CASEY / JEAN`, Rot `ROT / ASH / JACK` und Blau
   `BLAU / GARY / JOHN`. Die drei Vorschläge stehen oben, `NEUER NAME` immer
   unten. Bei aktivem Voxel nutzen Casey/Grün und Blue/Gary ihre vollständigen
   56×56-Standporträts. Sie werden nur auf der spielerseitigen Kampfkarte
   gespiegelt, damit sie zum Gegner blicken; die Laufblätter bleiben
   unverändert.
3. Spiele bis zum Party-Menü und öffne die Werte eines Pokémon. Arten mit
   Geschlecht zeigen dort `♂` oder `♀`; geschlechtslose Arten erhalten kein
   falsches Symbol. Dasselbe gilt jetzt für beide Kampf-HUDs. Im Voxel-Modus
   werden die Zeichen direkt in die verschobenen HUD-Flächen gerendert und
   stehen deshalb neben Name/Level statt frei in der Bildschirmmitte.
   Nidoran♀ und
   Nidoran♂ behalten trotz gegenteiliger Test-DVs ihr festes Geschlecht; im
   Kampf zeigt die separate Crystal-Zelle das Zeichen neben Level/Status.
4. Besuche die Route-5-Pension mit zwei geeigneten Pokémon. Die Pension zeigt
   die Crystal-Kompatibilität, erzeugt Eier schrittweise und bewahrt ein Ei
   bei vollem Team auf.
5. Prüfe ein Ei im Party-Menü: Es kann angesehen und außerhalb eines Kampfes
   umsortiert werden, aber es bietet weder Feldattacken noch einen
   Kampfwechsel an. Laufe die verbleibenden Schritte für den Schlupf. Das Ei
   wackelt zunehmend, bekommt sichtbare Risse, wirft Schalenstücke ab und
   enthüllt das neue Pokémon samt Schrei, bevor der Schlüpftext erscheint.
6. Starte testweise auch Yellow: Pikachu, Begleiterreaktionen, Eevee-Rivale
   und Storyfortschritt bleiben Yellow-eigen; nur die Trainer-Präsentation
   folgt der Charakterwahl.
7. Die gesonderten Battle-Test-Saves zeigen im Startmenü `RIVALEN-TEST`.
   Darin stehen alle acht Storykämpfe jeweils für Wasser-, Pflanzen- und
   Feuer-Starterzweig. `11 BATTLES BLUE`, `12 BATTLES CASEY` und
   `13 BATTLES RED` decken damit zusammen 72 konkrete Rivalenteams ab.
   Blau bleibt vollständig Gen-I-original, Casey/Grün erhält eine eigene
   durchgängige Teamlinie und Rots Champion-Kampf nutzt sein vollständiges
   Mt.-Silber-Team aus Gold/Crystal.
   Diese drei Matrix-Saves haben Brock bereits besiegt und können deshalb
   den ersten Route-22-Event nicht mehr auslösen. Für echte Karten-Events
   stehen zusätzlich `21–23 LAB ...` direkt vor dem Schritt aus Eichs Labor
   sowie `31–33 R22 ...` genau ein Feld vor dem ersten Route-22-Hinterhalt
   bereit. Die Event-Saves existieren jeweils für Rot, Blau und Casey und
   starten die Kämpfe ausschließlich über die originalen Karten-Flags.
8. Unter **OPTIONEN → VOXEL-KAMPFKAMERA** stehen die aus 6.5 übernommenen
   Modi `VOXEL-STANDARD`, `KLASSISCHES VOXEL` und `WEITES VOXEL`. Die Demo
   startet für die Abnahme mit der klassischen, vollständig sichtbaren
   Kampfführung; `VOXEL-STANDARD` lässt die Renderer-Vorgabe unangetastet.

## Demo-Status

Gameplay, Save-Kompatibilität und die Egg-Sicherheitsgrenzen entsprechen dem
Phase-8-Stand. `CRYSTAL CHARS` ist standardmäßig aktiv und enthält für Rot,
Blau und Grün/Casey vollständige Lauf-, Fahrrad-, Angel-, 2D-Kampf- und
Voxel-Kampfzustände. `ASCENDANT CHARS` bleibt als umschaltbare Alternative
erhalten. Die aktive Crystal-Familie fällt weder auf GBA/FRLG-Kampfbilder noch
auf Walking-Sprites im Kampf zurück. Greens Gestaltung folgt der
Pokémon-Green-Arbeit von Felix Jones (siehe `docs/green_sprite_credit.md`);
vor einer öffentlichen Veröffentlichung ist die Erlaubnis zur Weitergabe der
adaptierten Pixel zu klären. Details stehen in
`docs/character_asset_matrix.md` und im aktuellen Abnahmebericht unter
`qa/full_acceptance_20260810/ABNAHMEBERICHT_DE.md`.

Das 2D-Kampf-Rückenbild von Casey ist vollständig freigestellt. Seine
Platzierung erhält einen separaten vertikalen Render-Offset, sodass die
sichtbaren Pixel auf dem Menürahmen aufliegen. Die PNG-Datei selbst wurde
weder verschoben noch verlängert.

Rot, Blau und Casey besitzen im 2D-Kampf jeweils eine eigene, zusammengehörige
fünfteilige 64×64-Wurfsequenz mit gleichem Schulter-/Oberkörperausschnitt. Im
Voxel-Kampf werden stattdessen vollständige 128×128-Frontansichten auf einer
320×288-Trainertextur verwendet und die Spielerkarte gespiegelt, sodass sich
beide Trainer ansehen. Die höhere Voxel-Auflösung hält Gesichter lesbar; sechs
transparente Pixel unter den Schuhen trennen jede Figur sichtbar vom Boden.
Details stehen in `docs/blue_back_credit.md`.

## Paketkonvention

Jede künftige Demo wird als Launcher-kompatible `.zip` ausgeliefert. Eine
interne `.modpkg`-Datei darf für Build- oder Prüfzwecke existieren, ist aber
nicht das primäre Demo-Artefakt.
