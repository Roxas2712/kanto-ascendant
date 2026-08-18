# Story Gym difficulty contract (6.5.6)

This package changes only the first, pre-Hall-of-Fame battle against each of
Kanto's eight story Gym Leaders. It requires the canonical Gym map, trainer
class, party index, unearned badge and exact official edition party. Rematches,
forced battles, randomizer replacements after the authored seam, postgame
variants, Master/Apex/Crown fights and invalid contexts fail closed.

## Tiers

| Tier | Team | Moves | AI | Leader healing | Other |
| --- | --- | --- | --- | --- | --- |
| Standard | Exact Red/Blue/Yellow edition team | Exact edition behavior; Yellow's eight `SpecialTrainerMoves` tables are restored | Native | Native | Full Red/Blue pass-through |
| High | Same species and size as Standard | Three useful, legal moves | Native | Native | No roster expansion |
| Hard | One themed addition | Three useful, legal moves | Layers 1 and 3 | One battle-wide heal | Native per-mon item reset is suppressed |
| Very Hard | One or two themed additions | Four useful, legal moves | Layers 1, 2, 3 and useful-move policy | Up to two battle-wide heals; Brock/Misty have one | Maximum six Pokémon |
| Extreme | Progressive early cap of four/five, later cap of six | Four useful, legal moves | Same layers as Very Hard | Up to two; Brock has one | Existing Difficulty policy locks player battle items |

`difficulty.lua` remains the only owner of the phased trainer-level bonus.
This package never adds a second numerical offset. Legal TMs/HMs and retained
pre-evolution moves are allowed, matching developed rematch and Wanderer team
quality. The exhaustive oracle rejects unavailable moves and Struggle-causing
empty sets across Red, Blue and Yellow.

## Authored rosters

Added species are inserted before the official ace. “VH additions” and
“Extreme additions” name the complete addition set for that tier.

| Leader | Red/Blue core | Yellow core | Hard addition | VH additions | Extreme additions | Ceiling |
| --- | --- | --- | --- | --- | --- | --- |
| Brock | Geodude, Onix | Geodude, Onix | Sandshrew | Sandshrew, Rhyhorn | Sandshrew, Rhyhorn | 25 |
| Misty | Staryu, Starmie | Staryu, Starmie | Psyduck | Psyduck, Horsea | Psyduck, Horsea | 32 |
| Lt. Surge | Voltorb, Pikachu, Raichu | Raichu | Magnemite / Voltorb | Magnemite, Electabuzz / Voltorb, Magnemite | Magnemite, Electabuzz / Voltorb, Magneton, Electabuzz, Jolteon | 40 |
| Erika | Victreebel, Tangela, Vileplume | Tangela, Weepinbell, Gloom | Parasect | Parasect, Exeggcute | Parasect, Exeggutor | 48 |
| Koga | Koffing, Muk, Koffing, Weezing | Venonat, Venonat, Venonat, Venomoth | Arbok | Arbok, Golbat | Arbok, Golbat | 60 |
| Sabrina | Kadabra, Mr. Mime, Venomoth, Alakazam | Abra, Kadabra, Alakazam | Hypno / Mr. Mime | Hypno, Jynx / Mr. Mime, Hypno | Hypno, Jynx / Mr. Mime, Hypno, Jynx | 65 |
| Blaine | Growlithe, Ponyta, Rapidash, Arcanine | Ninetales, Rapidash, Arcanine | Ninetales / Growlithe | Ninetales, Magmar / Growlithe, Magmar | Ninetales, Magmar / Growlithe, Magmar, Flareon | 70 |
| Giovanni | Rhyhorn, Dugtrio, Nidoqueen, Nidoking, Rhydon | Dugtrio, Persian, Nidoqueen, Nidoking, Rhydon | Sandslash | Sandslash | Sandslash | 72 |

Slash-separated additions list Red/Blue first and Yellow second.

## Beyond-Kanto move gate

High and above may replace at most the final curated move with a legal
Generation-II move for the same Kanto species. This uses the exact injected
Driftglass resonance catalogue. It opens only when both conditions are true:

- the save's authoritative Beyond-Kanto boundary is active; and
- that same save has repaired the Driftglass receiver.

A sealed boundary, copied receiver milestone, active-but-unrepaired save,
missing rule, malformed rule, unmet level requirement or missing live move
definition all retain the Generation-I move. No Generation-II species or Mega
forms enter these story teams.

## Composition seams

The `trainer.party` order is `Difficulty (150) > Story Gym (110) > Randomizer
(70)`. The Randomizer therefore receives all authored slots and Difficulty
then scales every resolved slot. A resolved species/level/move signature must
match the real `BattleState` before policy is attached, preventing abandoned
constructors from leaking stale Arena policy.

On a matched battle the module publishes:

- `ascendantStoryGym` and `ascendantStoryGymClass`;
- `ascendantStoryGymDifficulty`;
- `ascendantStoryLevelCeiling`;
- `ascendantStoryPreserveAuthoredMoves`;
- authored, post-Randomizer resolved and live adjusted party views.

The adaptive trainer-level layer runs later, may adjust levels only within the
published story ceiling and must preserve the curated moves.
