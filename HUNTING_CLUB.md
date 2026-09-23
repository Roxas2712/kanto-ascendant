# PKMN Hunting Club – integrierter RC29

Integriert in KASC 6.7.19-rc.7 auf dem lokalen RC28; VASC 3.0.37-rc.26 bleibt unverändert.
Getestet mit isolierten Spielständen; kein öffentlicher Release.

## Spielregeln

- Leiterin Mira: Prismania City, freie Straße bei den Zellen (29–31, 10).
- Zugang mit allen acht Kanto-Orden, vor der Liga möglich.
- 120 feste, einmalige Auftrags-IDs: 40 Bronze, 35 Silber, 30 Gold, 15 Meister.
- 60 Kanto-Aufträge sind ohne zusätzliche Generationen abschließbar, einschließlich Meisteraufträgen. Die restlichen Aufträge nutzen Johto oder Hoenn und erscheinen erst unter den passenden freigeschalteten Regeln.
- Drei Angebote, ein aktiver Auftrag; kostenlose andere Auswahl. Pausieren erhält Anforderungen und bereits vorgezeigte Pokémon. Erledigte IDs werden nie erneut angeboten.
- Silber ab 10, Gold ab 30, Meister ab 45 Abschlüssen. Bronze/Silber: ein Pokémon; Gold: zwei; Meister: drei. Partner einzeln vorzeigen und behalten.
- Jede einzelne Pokémon-Instanz zählt einmal. Ein Ei zählt nicht als Auftragspartner. Mindestlevel 30/40/50/60, jeweils 1/2/3/3 geforderte Attacken; übrige Attacken frei.
- Auftragsarten müssen bereits erhalten, tatsächlich registriert, züchtbar und nach den aktiven Generationsregeln verfügbar sein. Legendäre und nicht züchtbare Arten sind ausgeschlossen.
- Attacken stammen aus den echten aktuell projizierten Level-Lernlisten. Anforderungen werden beim Annehmen eingefroren. Wechsel auf ältere Regeln pausiert unzulässige Anforderungen; er erzeugt keinen Ersatzauftrag und setzt nichts zurück.

## Belohnungen

- 10/20/35/60 Clubpunkte je Auftrag.
- Sonderbonbon 30 CP, AP-Plus 60 CP, Top-Elixier 40 CP; ein Meisterball je Spielstand für 500 CP.
- 27 registrierte Club-Outfits, jeweils 100 CP ab 10 Abschlüssen; angeboten werden nur Belohnungen der aktuellen Figur. Ein Kauf schaltet ein vollständiges Outfit und seine Kleidungsstücke zum einzelnen Kombinieren frei. Bereits getragene normale Outfits werden bei der ersten Übernahme erhalten.
- Rot/Blau: Stadtbummel, Pfadfinder, Küstentour, Abendrunde und Classic. Grün: Stadtbummel, Pfadfinder, Küstentour, Abendrunde und Lotta.
- Die reine Champion-Tunika samt ihren Teilen kommt ausschließlich über den Liga-Sieg der betreffenden Figur. Gemischte Outfits mit Champion-Teilen benötigen zusätzlich ihre eigene Club-Freischaltung. Ein Liga-Sieg füllt den Schrank daher nicht mit sämtlichen Misch-Outfits.
- Champion-Freigabe beim tatsächlichen Ruhmeshallen-Eintrag nach Top Vier und Championkampf; Rot, Blau und Grün getrennt. Bei einem alten Spielstand mit nachgewiesenem Liga-Sieg erhält einmalig die aktuelle Figur die Freigabe.
- Garantiertes Shiny-Ei bei 30, 60, 90 und 120 Abschlüssen. 10 % Chance auf den freigeschalteten legendären/mysteriösen Pool, sonst normaler Pool. Ei-Belohnungen dürfen ausdrücklich nicht züchtbare Legendäre enthalten. Kein Fangbesitz nötig, aber Generation und Spezies müssen freigeschaltet sein.
- Die Art wird vor Abholung gespeichert; Menü-Neuöffnung würfelt nicht neu. Volles Team oder voller Beutel verbraucht keine Belohnung/Punkte.

## Prüfung und Grenzen

4.402 automatisierte Prüfungen: Katalog für Gen-I–VI-Regeln, vollständige 120-Auftragskette, eigenständige Kanto-Kette, Speichern/Neuladen, Wiederholungsschutz, Teilabgaben, volle Kapazitäten, Schreibfehler und legendäre Eier.

Zusätzlich echter LÖVE-Spieltest mit vollständig geladenem KASC: NPC-Interaktion in Prismania, keine doppelten Leiterinnen, Clubmenü, natives Speichern/Laden, vorhandene Outfit-Grafiken, figurenspezifische Champion-Sperre, tatsächlicher Ruhmeshallen-Skriptbefehl und Schlüpfen eines legendären Shiny-Eis.

Kein vollständiger manueller Durchlauf aller 120 Aufträge; kein physischer Android-/iOS-Test. Aufträge, Punkte, Ei-Abholungen und Outfit-/Champion-Freischaltungen werden über die bestehende Legacy-NG+-Transaktion mitgenommen; abgeschlossene Aufträge wiederholen sich auch dort nicht. Die tatsächliche Archivtransaktion und das Anlegen des Folge-Spielstands wurden zusätzlich mit isoliertem Speicher geprüft.

## Installation und Rückweg

Das ZIP über den normalen Mod-Import als Kanto Ascendant importieren. Für den ersten Test eine Kopie des Spielstands verwenden. Der Teststand behält die Mod-ID `kanto_ascendant` und enthält den vollständigen aktuellen KASC-RC mit Hunting Club.

Rückweg: ursprüngliches `Kanto-Ascendant-6.7.19-rc.6.zip` aus dem RC28 erneut importieren. Zusätzliche Clubdaten bleiben im Spielstand und werden von der Basis ignoriert. Der Kandidat verändert keine Engine- oder VASC-Dateien.

RC29-Integration: zusätzliche native Tests für rückwirkende Freigabe anhand Ruhmeshalle oder Champion-Flag, Speichern/Neuladen, Charakterwechsel ohne doppelte Anerkennung und eigenen Ligaabschluss des nächsten NG+-Charakters. KASC und VASC gemeinsam geladen.

RC31: Freischaltung der Misch-Outfits korrigiert; die Einzelteil-Auswahl ist direkt im Schrank sichtbar. Der Darstellungswechsel auf Vanilla erhält die Kleidung und nutzt den nativen 16-Pixel-Kleidungsrenderer. Zubehör gehört zu kompletten Belohnungen: Stadtbummel schaltet die L-Cap in beiden Richtungen und die Brille frei, Pfadfinder die Sonnenbrille, Lotta auch die rückwärts getragene Lotta-Cap. Bereits gekaufte Sets erhalten ihr Zubehör rückwirkend. Originalkopf, Haare und das Absetzen einer Kopfbedeckung bleiben frei; der Club verkauft keine zufälligen Einzelteile. Grafische Detailunterschiede der separat gezeichneten HD-/Voxel-/Pixel-Champion-Varianten sind noch offen.
