# Kanto Ascendant 6.5.6 — Gameplay, Character and Follower Hotfix

Kanto Ascendant 6.5.6 is a save-compatible hotfix for Pokémon Red, Blue and
Yellow. No new save or story reset is required.

## Characters and catching tutorials

- Red and Green keep their own English and German voices throughout every
  Oak's Lab starter branch. Blue retains the native confident dialogue and is
  the only rival who treats Oak as his grandfather.
- Red addresses Professor Oak respectfully. Green remains friendly and
  absent-minded, and now acknowledges and apologizes when she takes the
  starter that was intended for the player.
- Yellow's scripted catching tutorial uses the existing approved Professor
  Oak standee in supported staged renderers instead of their small 2D
  fallback. No approved staged model exists for Viridian's old man, so only
  the Red/Blue old-man tutorial temporarily delegates to the native 2D battle;
  the next battle uses the configured renderer normally. The selected player
  character replaces neither presenter.
- Red, Green and Blue use their newly supplied six-frame Crystal walking
  sheets. Each immediately preceding sheet remains the first validated
  fallback; Green also retains its public 6.5.5 sheet before the original v1
  fallback. Battle, profile, bicycle, fishing, throwing, HD and Voxel artwork
  are unchanged.

## Kanto Shiny followers

- All Kanto species #001-151 have separate normal and Shiny follower sheets
  derived from their canonical Crystal palettes.
- The owned Pokémon's actual DV-based Shiny state selects the matching sheet.
- If a Shiny sheet is absent or invalid, the normal sheet remains the safe
  fallback instead of breaking the follower.
- Existing Johto and Gorochu normal/Shiny routing remains unchanged.
- In Yellow, fainting or storing the authored partner no longer hides the
  independently selected extras. Its logical first slot remains reserved, so
  a configured count of two shows one extra and six shows up to five; when
  Pikachu returns, it is prepended exactly once and keeps its native story and
  mood interaction.

This follower update does not claim that free-roaming Wilds can preview the
Shiny state of a later battle encounter. Engines 0.1.96 and 0.1.98 generate
that Pokémon's DVs only when the battle starts; Ascendant does not pre-roll or
reroll them merely for an overworld colour preview.

## Pokédex boundary and areas

- A fresh Pokédex stops at #151. After its real Driftglass National Dex
  upgrade it stops at Celebi (#251), even though private runtime species slots
  #252-279 remain registered for their own systems.
- A seen Johto species shows its authored Kanto habitat on **AREA** only while
  that habitat is genuinely active under the save's research and migration
  current. Inactive or undiscovered habitats remain hidden.

## Difficulty, Gyms and rematches

- **Wild Level Scaling** is now a separate option and defaults to **OFF**.
  Trainer difficulty is unchanged. Turning the option on restores the previous
  badge-phased difficulty bonus for wild Pokémon; leaving it off preserves the
  level supplied by the game, Randomizer or encounter author.
- **Adaptive Trainer Levels** is a separate Core Rule. AUTO remains classic on
  Standard and targets the rounded active-party average +1/+2/+3/+4 on High,
  Hard, Very Hard and Extreme. Manual `-2`, Match, `+2`, `+4`, `+6`, `+8` and
  exact classic OFF are available. Existing saves stay classic until the
  player deliberately revisits Adaptive or Difficulty. Generic rematch rank,
  evolution, recruits, AI and rewards still progress without stacking their
  formerly unbounded numeric level bonus while Adaptive is active.
- The first canonical battle against each story Gym Leader now follows the
  selected Difficulty beyond levels alone. Standard preserves the exact
  Red/Blue/Yellow team and edition behavior, including Yellow's official
  special moves. High keeps that roster and assigns useful legal moves; Hard,
  Very Hard and Extreme add progressively broader themed teams, move coverage,
  AI and limited Leader healing. Postgame, Master, Apex and Crown battles are
  outside this contract. Generation-II moves remain sealed unless Beyond Kanto
  is active and that save's Driftglass receiver has been repaired.
- **Rematch Break** now offers Very Short, Short, Normal, Long, Very Long and
  Custom profiles. Fresh saves start at Normal (605-1255 completed player
  steps). Existing exact or hand-tuned ranges migrate without changing their
  values, and changing a profile affects only future rolls: already scheduled
  field recovery, silent training and postgame Gym recovery remain intact.
- With Adaptive set to OFF, the pre-battle rematch strength warning now previews
  the same Difficulty-adjusted levels used by the real battle. It no longer
  understates the opponent and then silently starts a stronger team.

The complete mechanics are documented in the
[Adaptive Trainer Levels contract](docs/adaptive-trainer-levels.md) and the
[story Gym difficulty contract](docs/STORY_GYM_DIFFICULTY_6_5_6.md).

## Battles, rewards and text

- Actually upscaled ordinary trainers retain at least one legal damaging or
  fixed-damage move after level-up learning. This fixes status-heavy species
  such as Butterfree losing their only attack; unscaled authored teams and
  curated story movesets are unchanged.
- Giga Drain keeps its Generation-II 60 power and now restores half the damage
  dealt instead of behaving as a damage-only attack.
- The one-time Thunder Tear is explicitly excluded from ordinary rematch loot.
  The current weighted reward pool, probabilities, OFF behavior and safe
  delivery order were audited and are now documented in the README and FAQ;
  native trainer prize money and Pay Day remain untouched.
- In native 2D battles, Ascendant-owned enemy Crystal fronts sit eight pixels
  higher and farther left. Large animated, Shiny, Mega and Gorochu frames no
  longer cover the player's Pokémon name; Gen-I sprites, trainer art, player
  backs and staged renderers keep their existing placement.
- Dialogue now uses both visible text rows before asking for another button
  press. Authored pauses and page breaks remain intact, while long English and
  German lines still paginate safely instead of scrolling past unread.
- Yellow's Mt. Moon fossil Super Nerd now uses his own challenge, victory and
  post-battle dialogue instead of inheriting the generic Shorts text. The
  fossil choice and the Jessie/James event remain unchanged.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.6.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.6.txt`.

Please report reproducible issues with edition, engine version, platform,
renderer, enabled mods, exact steps and—when progression is involved—a save
file.
