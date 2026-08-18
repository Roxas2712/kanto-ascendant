# Adaptive Trainer Levels / Adaptive Trainerlevel

## English

`ASCENDANT → OPTIONS → GAMEPLAY → CORE RULES → ADAPTIVE TRAINER-LV`
controls a party-relative trainer layer separately from the fixed Difficulty
curve. Wild Level Scaling is an independent option and is not affected.

The player reference `P` is the rounded arithmetic mean of every valid,
non-Egg Pokémon in the active party. Fainted Pokémon count; Eggs, boxed
Pokémon and invalid party records do not. Levels are frozen when the battle
is planned and never change during that battle.

| Setting | Target gap |
| --- | ---: |
| AUTO + STANDARD | OFF / classic |
| AUTO + HIGH | `P + 1` |
| AUTO + HARD | `P + 2` |
| AUTO + VERY HARD | `P + 3` |
| AUTO + EXTREME | `P + 4` |
| `-2`, MATCH, `+2`, `+4`, `+6`, `+8` | the selected fixed gap |
| OFF | classic authored levels |

Adaptive never lowers the authored level plus the badge-phased Difficulty
bonus. One shared upward shift preserves the authored level spacing. Story
ceilings and curated Gym moves remain authoritative. Fixed postgame,
Facility, Legacy and other explicitly owned battle lanes stay excluded.

For generic rematches, the old repeat/training bonus still controls rank,
evolution, recruitment, AI and rewards, but it is not stacked onto levels
while Adaptive is active. OFF keeps the classic authored + Difficulty +
rematch-growth path. If planning context is missing or invalid, the battle
fails safely back to that classic path without a partial level change.

New saves start on AUTO. Existing saves without an Adaptive marker remain on
classic behavior until the player deliberately changes Adaptive Trainer-LV
or reselects Difficulty. A later Difficulty change never overwrites a manual
Adaptive value.

When real level growth teaches moves, a scaled ordinary trainer keeps at
least one legal damaging or fixed-damage move. Unscaled authored teams and
curated story movesets are not rewritten.

## Deutsch

`ASCENDANT → OPTIONEN → GAMEPLAY → KERNREGELN → ADAPTIVE TRAINER-LV`
steuert eine teambezogene Trainerebene getrennt von der festen
Schwierigkeitskurve. Die Wild-Level-Skalierung bleibt unabhängig.

Die Spielerreferenz `P` ist der gerundete arithmetische Mittelwert aller
gültigen Nicht-Ei-Pokémon im aktiven Team. Besiegte Pokémon zählen mit; Eier,
Box-Pokémon und ungültige Teamdaten nicht. Die Level werden bei der
Kampfplanung eingefroren und ändern sich im laufenden Kampf nicht.

| Einstellung | Zielabstand |
| --- | ---: |
| AUTO + STANDARD | AUS / klassisch |
| AUTO + HOCH | `P + 1` |
| AUTO + SCHWER | `P + 2` |
| AUTO + SEHR SCHWER | `P + 3` |
| AUTO + EXTREM | `P + 4` |
| `-2`, GLEICH, `+2`, `+4`, `+6`, `+8` | gewählter fester Abstand |
| AUS | klassische, festgelegte Level |

Adaptiv senkt niemals das festgelegte Level plus den ordenabhängigen
Schwierigkeitsbonus. Eine gemeinsame Anhebung erhält die vorgesehenen
Levelabstände. Story-Obergrenzen und kuratierte Arenaleiter-Attacken bleiben
maßgeblich. Feste Postgame-, Facility-, Legacy- und andere eigens verwaltete
Kämpfe sind ausgeschlossen.

Bei normalen Revanchen steuert der alte Wiederholungs-/Trainingswert weiter
Rang, Entwicklung, Rekrutierung, KI und Belohnungen, wird bei aktivem Adaptiv
aber nicht zusätzlich auf die Level addiert. AUS behält den klassischen Pfad
aus Vorlage + Schwierigkeit + Revanchenwachstum. Fehlt ein sicherer Kontext,
fällt der Kampf ohne Teiländerung auf diesen klassischen Pfad zurück.

Neue Spielstände starten mit AUTO. Bestehende Spielstände ohne
Adaptiv-Markierung bleiben klassisch, bis Adaptiv oder Schwierigkeit bewusst
neu gewählt wird. Eine spätere Schwierigkeitsänderung überschreibt niemals
einen manuell gewählten Adaptiv-Wert.

Wenn echte Levelsteigerung neue Attacken lehrt, behält ein skalierter
normaler Trainer mindestens eine legale Schadens- oder Fixschadensattacke.
Unveränderte Vorlagenteams und kuratierte Story-Attacken werden nicht
umgeschrieben.
