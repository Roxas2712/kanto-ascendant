# Kanto Ascendant 6.5.9 — Yellow Kanto-151 Hotfix Candidate

> **Unpublished candidate:** this build is prepared for maintainer review and
> is not live. The current public release remains 6.5.8.

Kanto Ascendant 6.5.9 is a save-compatible gameplay and validation hotfix for
Pokémon Red, Blue and Yellow. No new save or story reset is required.

## Yellow Koffing and Weezing acquisition fixed

- With KANTO 151 set to REWARDS or WILD, Yellow now places Koffing Lv.35 in
  Pokémon Mansion B1F slot 4 (10%) and Weezing Lv.40 in slot 8 (5%).
- Both entries replace native Raticate slots. Red and Blue retain their
  existing edition encounter tables.
- Grimer/Muk, Growlithe, Magmar, Ditto, Ponyta and the Growlithe/Vulpix
  edition identity are unchanged.
- Koffing's level-35 evolution into Weezing remains a second valid route.

## Editions are audited independently

- The reachability check now consumes the actual Red, Blue or Yellow wild and
  fishing data instead of seeding every run with Red encounters.
- Horsea is recognized through the real Blue/Yellow Super Rod table.
- Red/Blue's Poliwhirl-for-Jynx NPC trade is edition-scoped. Yellow instead
  reaches Jynx through the guaranteed Smoochum research egg and evolution.
- Gifts, fossils, NPC trades, events, Johto research rewards and eggs,
  renewable evolution items, static/roaming/generated legends, Mew and Celebi
  are included without assuming external player trades.
- Red, Blue and Yellow each reach 251/251 in both REWARDS and WILD.
- KANTO 151 OFF is not advertised as 251/251. Disabled legendary options are
  shown as deliberate configuration boundaries with an adjusted target.

## Install or update

This candidate is intentionally not available for download. If approved, it
can be packaged and published through the normal Kanto Ascendant release
process. Existing saves remain compatible.
