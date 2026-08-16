# Aprikoko-Bälle – P1 Integrationsvertrag

`apricorn_balls.lua` ist ein abgegrenztes Runtimepaket. `main.lua` bindet es
nach der kanonischen Gen-II-Geschlechtsquelle ein und exportiert es als
`apricornBalls`. Es berührt keine Mega-, Dungeon- oder Legacy-Dateien. Die
Factory bleibt dabei ohne Import-Nebeneffekt testbar.

## Runtime-Umfang

Es registriert genau diese sieben echten Ball-Items und deren `content.balls`
Catch-Callbacks: `HEAVY_BALL`, `LEVEL_BALL`, `LURE_BALL`, `FAST_BALL`,
`LOVE_BALL`, `FRIEND_BALL`, `MOON_BALL`. `GS_BALL` ist nicht Bestandteil des
Pakets.

Die Bonusauskunft `quote(ball, context)` ist die einzige Regelquelle für die
Kampf-UI und die Catch-Callback-Logik. `formatQuote()` erzeugt daraus zwei
lokalisierte Zeilen mit höchstens 18 Font-Glyphen: aktuell wirksamer Bonus und
verständlicher Grund. Fehlende Art-, Gewicht-, Basis-Initiative- oder
Geschlechtsdaten ergeben immer `available=false` samt Grund; es gibt keinen
stillen 1×-Fallback.

- Heavy Ball: moderne additive Catch-Rate-Korrektur: >=300 kg +30, 200–299,9
  kg +20, 100–199,9 kg +0, darunter -20 (danach 1..255).
- Level Ball: ×8 / ×4 / ×2 bei mindestens vierfacher / zweifacher / höherer
  Spielerstufe, sonst ×1.
- Lure Ball: ×3 ausschließlich für den echten Angelpfad: `goFishing` erzeugt
  den nativen `hooked`-Kampf und der Runtime-Hook markiert genau diesen Kampf
  als `encounterSource=fishing`. Wasser, Angel im Beutel oder ein loses Flag
  genügen nicht.
- Fast Ball: ×4 ab Basis-Initiative 100.
- Love Ball: ×8 nur bei gleicher Art und gegensätzlichem, nicht geschlechts-
  losem Gen-II-Geschlecht.
- Friend Ball: normale Fangrate; exakt nach `pokemon.caught` wird
  `johtoBond` des tatsächlich gefangenen Party- oder PC-Mons mindestens 200.
- Moon Ball: ×4 für die vollständige, zur Laufzeit aus der gemergten
  Evolutionsregistry ermittelte Mondsteinlinie. Startpunkte sind echte
  `MOON_STONE`-Kanten; Vor- und Nachentwicklungen werden graphbasiert
  eingeschlossen. Fehlt die Registry oder eine Mondstein-Kante, ist der Wurf
  explizit nicht verfügbar – keine statische Artenliste und kein stilles ×1.

`validateSpecies(data)` prüft datengesteuert die vollständige 1..251-Abdeckung
für Gewicht, Basis-Initiative und Gen-II-Geschlechtsquote. Kanto liefert im
Engine-Datensatz keine Gewichte; [apricorn_ball_data.lua](../apricorn_ball_data.lua)
enthält deshalb die daraus fehlenden Kilogrammwerte, generiert durch
`tools/build_apricorn_ball_data.py` aus dem lokal vorhandenen
`.downloads/pokecrystal/data/pokemon/dex_entries/*.asm`. Johto darf weiter
sein direktes `weightKg` liefern. Ungeeignete rohe Gen-I-`weight`-Werte werden
absichtlich nicht als Kilogramm fehlinterpretiert.

## Beutel, PC und Saves

Neben den registrierten Item-/Ball-Daten ergänzt das Paket die bestehende
`ItemEffects.BALLS`-Tabelle minimal. Damit verwenden Kampfbeutel, Inventar und
PC die normalen Enginewege; es wird kein zweites Inventar geführt. Der
Save-Key `apricorn_balls` hat Version 1 und migriert einen vorläufigen
`friendCatchLedger` verlustfrei, ohne eine alte Freundschaftsbelohnung erneut
auszulösen. Die Markierung sitzt am gefangenen Mon, daher ist der Erfolg auch
bei mehrfacher Eventauslieferung idempotent.

Jeder der sieben Items besitzt zusätzlich einen kleinen Battle-Preflight als
registrierten Item-Effekt. Der Preflight ruft dieselbe `quote()`-Regelquelle
und denselben Formatter auf, bevor `BagMenu` den Ball entfernt. Bei einem
legalen Wurf schließt der Beutel und zeigt den Bonus samt Grund im echten
Kampf-Textfenster; erst nach Bestätigung wird exakt ein Ball verbraucht und
geworfen. Trainer-, Story-/`noCatch`- und
fehlende-Daten-Fälle geben daher den präzisen Grund zurück, behalten den Ball
im Beutel, zeigen keine Bonusmeldung und starten keinen Wurf.

## Animationen und Art-Status

Die ursprüngliche Prüfung fand im Authority-Baum keine spezifischen
Aprikoko-Masters. Der nachträglich vom Nutzer bereitgestellte lokale
Pokemon-Journeys-/Essentials-Baum liefert diese nun für alle sieben Bälle
sowie die fünf klassischen Bälle. Die getrennte, hash-verifizierte
Import-/Runtime-Integration ist in
[JOURNEYS_BALLS_DE.md](JOURNEYS_BALLS_DE.md) dokumentiert. Sie bleibt rein
visuell; die native `ULTRATOSS_ANIM`-Toss-Pipeline und sämtliche Fangregeln
dieses Pakets ändern sich dadurch nicht.

## Fokustest

```sh
"$GEN1RECOMP_DIR/.tools/luajit-src/src/luajit" \
  tests/apricorn_balls_test.lua

cd "$GEN1RECOMP_DIR"
TRAINER_REMATCH_MOD_DIR=mods/ka_rc11_integration \
  ./.tools/luajit-src/src/luajit \
  mods/ka_rc11_integration/tests/apricorn_balls_engine_test.lua
```

Der Test deckt Registrierung/Beutel, positive und negative Schwellen,
echtes Fischen, Trainer-/Story-Sperren ohne Verbrauch, fehlende Daten,
Registry-basierte Mondsteinlinien, echte Catch-Callback-Weitergabe,
Party-/PC-Friend-Ball-Erfolg, Idempotenz, Save-Migration und eine vollständige
251-Arten-Datenabdeckung ab. Der Engine-Test prüft zusätzlich die reale
`BagMenu -> TextBox -> consume -> throwBall`-Reihenfolge. Vier echte
LÖVE-Kampfbilder (positiver/negativer Fast-Ball-Fall, Deutsch und Englisch)
wurden im privaten Abnahmearchiv geprüft; Bonus und Grund sind dort
vollständig sichtbar, bevor der Ball verbraucht wird.
