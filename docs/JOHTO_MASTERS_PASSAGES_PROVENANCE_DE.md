# Johto-Masters-Passagen – Provenienz und Abnahme

Laufzeitquelle ist ausschließlich die lokale `pret/pokecrystal`-Arbeitskopie
bei Commit `8e8f7e20052a596371a77022f0392c285e51bbf1`. Die Feld-Sheets wurden
unverändert aus dem vorhandenen Editorbestand übernommen: `gsc_gold.png`
(`30f405b7e5772999195459abb24fbfb570ff2fc293f0fee7daa54c86066e8b81`),
`gsc_silver.png` (`f4a0d1cef7dd42e5ab554712cf7cba106407d338a6aee120a0b0a72f68692eaa`)
und `gsc_crystal.png` (`198120128ffa5b1702f12a063dd817d68b474c295bae8428fc1783f542d2488e`).
Sie sind jeweils 16×96 Pixel.

Die Battle-Fronts/Backs wurden ohne Skalierung transparent auf 64×64
zentriert: Gold `gfx/player/chris.png`/`chris_back.png`, Kris
`gfx/player/kris.png`/`kris_back.png` und Silver ausschließlich
`gfx/trainers/rival1.png` als Front. Silver besitzt absichtlich keinen
synthetischen Back. Pokémon World wird nicht ausgeliefert und nicht als
Runtime-Quelle verwendet.

Der aktuelle technische Stand registriert die IDs 1960–1966 als Torhalle,
drei getrennte Passagen und drei eigene Finalarenen. Silver nutzt eine lokale
Radio-Tower-, Kris eine lokale Ruins-of-Alph- und Gold eine lokale
Tin-Tower-Komposition; alle sieben Karten laufen mit `MAP_STUDIO`. Der
Indigo-Wächter startet keine Lobby-Gauntlet mehr: Er tritt im Dialog beiseite
und transportiert den Spieler durch den geöffneten Eingang in die Torhalle.
Die drei Arena-Trainer verwenden ausnahmslos die eigenen Klassen
`KA_JOHTO_SILVER`, `KA_JOHTO_KRIS`, `KA_JOHTO_GOLD`; auch der latente
Datensatz enthält keine `OPP_RIVAL2`-/`OPP_RIVAL3`-/`OPP_COOLTRAINER_F`-
Abkürzung mehr. Ihre Battlekontexte besitzen eigene Dialoge, drei AI-Stufen,
`baseMoney=0`, keinen Postgame-Tier-Namensraum und erhalten zwischen den
Etappen die Party.

Der fokussierte Map-/Status-Test deckt Torübergabe, sequenzielle Freigaben,
Fehlentscheidung, Loss/Retry, Revanche, eigene Klassen/Sprites/Dialoge/AI,
unverändertes Geld und Reward-exact-once ab. Der echte Legacy-Archivtest
bewahrt zusätzlich Status, Versuche, Rätselschritt, Resets, Hinweis,
Rewardmarker, Titel, Golden-Card-Dekor und Pending Gift über einen echten
New-Game-Übergang; ein ausgeliefertes Pending Gift wird aus dem Archiv
gelöscht. Jede Passage schreibt dabei zuerst den Live-Bucket und stößt danach
über `legacy_journey.syncJohtoMastersPersistent` unmittelbar den
Journey-Archivabgleich an; ein Archivfehler bleibt sichtbar und wird beim
nächsten Johto-Zustandswechsel erneut abgeglichen. Ein isolierter echter
LÖVE-Lauf
vom 11. August über
`tools/johto_masters_passages_love_e2e.lua` hat Lobby-Handoff → Gate Hall →
Silver/Kris/Gold-Passage und -Finale sowie den Rückweg ausgeführt; nach jedem
Finale erfolgte ein natives Save/Load. Die echten 2D-PNGs liegen unter
`/tmp/ka-johto-masters-uat-0811b/2d`, die sieben DRAMALESS-Render-PNGs unter
`/tmp/ka-johto-masters-voxel-0811/voxel`. Diese temporären Pfade sind nur
Diagnosebeleg dieses Rechners und ausdrücklich kein persistenter
RC-Golden-/Releasebeleg; die Golden-Abnahme im RC-Baum bleibt offen.

Die beiden gewünschten G/S-Kompositionen sind jetzt als reproduzierbare
ChipAsm-Transkription eingebunden. `tools/build_johto_masters_music.py` liest
ausschließlich die gepinnte lokale `pret/pokecrystal`-Arbeitskopie am oben
genannten Commit und bricht bei unbekannten Befehlen, abweichendem Commit oder
abweichenden SHA-256-Werten ab. Quellen sind `audio/music/indigoplateau.asm`
(`953c1581d247468e60da5bd7ddcd2a1721900824249d1928948b951da38b8737`),
`audio/music/rivalbattle.asm`
(`80e50b34754dfa0eea5aa67e30ede7586b0709a3e5e10857d0dfadcdb15926ab`),
`audio/drumkits.asm`
(`6a4be3937b142958801238c38aa74dd2fcc8844ce9316a0809203907ceb45d53`)
und `audio/wave_samples.asm`
(`770259cd6b04841440e8b1d504c926666d0bdde6372e6b0afa74188110bead9c`).
Die generierte Laufzeitdatei `johto_masters_music_data.lua` enthält Noten,
Schleifen, Unterprogramme, Takt/Tempo, Hüllkurven, Vibrato, kanalgenaue
Stimmung/Stereoführung sowie die verwendeten Original-Waves und Drumkit-0-
Noise-Instrumente; es gibt keine OGG- oder erfundene Ersatzspur.

`Music_KA_GSC_IndigoPlateau` ist ausschließlich der Torhalle, den drei
Passagen und ihren drei Finalarenen zugeordnet. Die drei isolierten Klassen
`KA_JOHTO_SILVER`, `KA_JOHTO_KRIS` und `KA_JOHTO_GOLD` besitzen ausschließlich
`Music_KA_GSC_RivalBattle` als Trainer-`battleTheme`. Der Engine-Pfad reicht
die konkrete Trainer-ID sowohl beim Übergang als auch beim Eintritt in den
Kampf weiter; nach Kampfende verwendet der unveränderte `restoreMap`-Pfad
wieder die aktuelle Kartenmusik. Keine andere Karte oder Trainerklasse wird
umgebogen.

Für das vollständige historische Asset-Gate fehlen weiter Silver-Back, fünf
wirklich verschiedene Throw-Frames sowie Voxel-64/128-Familien; Bike/Fish
sind für die stationären Arena-Gegner nicht laufzeitrelevant, bleiben aber in
der Gesamtmatrix offen. Ohne echte oder professionell abgenommene Quellen
werden keine Spiegelungen oder erfundenen Varianten erzeugt. Die Pokémon-
Grafiken und -Musik werden nicht als CC0 oder frei lizenziert dargestellt.
