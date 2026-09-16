# Bald Crew: weibliche Teenager-Figur v1

Eigene, vom Nutzer beauftragte Figur mit Glatze, türkisfarbenem Oberteil,
dunklen Shorts und Turnschuhen. Keine bestehende Trainerfigur ersetzt.
Erstellt mit dem eingebauten Imagegen-Tool am 15.09.2026.

Augen-Update 16.09.2026: anatomisch rechts blau, links grün (von vorn im
Bild links blau/rechts grün), passend zur Fabelle-Vorlage. Die gezielten
Imagegen-Edits und Folgekorrekturen stehen in `PROMPTS-HETEROCHROMIA.json`;
die Originalmaster bleiben erhalten. Lauf-, Blink-, Wurf- und VASC-Atlanten
wurden neu gepackt. Geschlossene Lider brauchen keine Irisfarbe.
`walk_right.png` verhindert die falsche Augenfarbe beim nativen Spiegeln;
`walk_stepflip.png` gleicht das Spiegeln der frontalen Wechselschritte aus.
Der Charaktertest prüft die Auswahl beider Varianten mit der nativen
Draw-Signatur inklusive Kameraargumenten. Noch kein neuer vollständiger
Ingame-Durchlauf nach dieser reinen Grafikänderung.

## Dateien und Anbindung

- `source/`: unveränderte generierte Master (inklusive verworfener Zwischenlayouts).
- `walk.png`, `blink.png`: native 16×96-Fallbacks; Stand unten/oben/links,
  Schritt unten/oben/links. Rechts spiegelt die native Engine wie bei Grün.
- `cards_4x3.png`, `cards_blink_4x3.png`: 495×900-HD-Atlanten nach Grüns
  Zeilen unten/links/oben/rechts und Spalten Stand/Schritt A/Schritt B.
- `battle_56_*.png`, `battle_128_*.png`: Kampfporträts und Posen.
  Fünf Wurfposen: 1,3,4,5,6; Freigabe im vierten Animationsbild;
  sechs native Ticks pro Pose wie Grüns bestehende Wurffolge.
- `battle_heroes_3x10.png`: eigenes VASC-CharSprite-Paket mit Richtungen,
  Wurfposen und Blinzelzeilen. Über `bindTrainer` an die eigene Klasse gebunden,
  damit auch dauerhaft sichtbare Trainer und Terrarium keine Standardfigur zeigen.
- `bald_crew_67_character.lua`: eigene Sprite-/Trainer-IDs, gebündelte
  Fallbacks, Blinzeln und einmaliger Gegnerwurf vor der nativen Ausblendung.
  Keine Änderung von Team, Schaden, Zufall oder Kampfentscheidungen.

Imagegen liefert die Zeichnungen. Das QA-Packskript ordnet Zellen an,
konvertiert sie mit Nearest-Neighbour und harter Alpha in die Engineformate.
Beim Blinzeln wird nur der Augenbereich des generierten Gegenstücks verwendet;
Körper und Füße bleiben stabil. Keine vorhandenen Pokémon-Sprites bearbeitet.

Die Crew-Daten verweisen für FabelleMoon auf die neue Figur. Ihre sechs Arten
wurden am 16.09. geliefert und als starkes Team in `bald_crew_67_data.lua`
ausgearbeitet. Die Grafikregistrierung enthält weiterhin kein Testteam;
der spätere Encounter-Adapter muss die freigegebenen Daten übernehmen.
Ein registriertes Charakterpaket ist noch kein fertiger Mondberg-Durchlauf.

## Grenzen der Grün-Parität

Laufatlas, Kindergrößenklasse, Blinzelrhythmus und Fünf-Posen-Wurf folgen
Grüns Darstellungskonventionen. Grün bleibt unverändert. Fahrrad, Surfen
und Angeln sind keine Fähigkeiten dieser stationären Crew-Trainerin und
werden nicht als vorhanden ausgegeben. VASC-spezifische Körper-Rigs werden
nicht unter Grüns Identität auf den anders proportionierten Körper kopiert.
Der HD-Atlas wird über die bestehende `ascendantAtlasImage`-Schnittstelle
angeboten; die Sichtprüfung dokumentiert die tatsächlich erreichten Modi.
