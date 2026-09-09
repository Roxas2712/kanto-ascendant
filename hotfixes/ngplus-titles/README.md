NG+ title menu hotfix (6.7.4 baseline)

Active Legacy Journey saves can open Events + Titles -> Titles / Trophies -> Select Title before repeating the League. First-run access and curator spawn retain their existing Hall of Fame gate. No title unlock or save schema changes.

The released distribution branch contains overlays, so legacy_hall.lua is added from the checksum-verified official 6.7.4 package. runtime.patch shows the narrow change. origin/main is still 6.5.17 and is not the current distribution baseline.

Validation: 8 bilingual NG+/first-run/champion menu scenarios; baseline fails before fix. Existing title catalog, Surprise trainer, title archive and Legacy Pact suites pass (3137 assertions), run via Lua 5.1 with engine modules from qa/current-gen2-engine-live-A20. No manual game playthrough.
