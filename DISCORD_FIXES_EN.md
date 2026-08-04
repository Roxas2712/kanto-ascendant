## 🛠️ KANTO ASCENDANT 5.4.1 — RANDOMIZER HOTFIX

This hotfix repairs Ascendant's authored post-game battles when the Gen-I
Randomizer is enabled.

- Master/Crown Leaders, Apex/Crown Elite battles, Johto Masters, Grand Tour,
  Heritage Cups, research trials, tournaments and hunts now give the
  Randomizer their intended roster instead of the trainer's original party 1.
- Randomized species and moves stay randomized. Ascendant still owns the
  authored team size, slot levels, boss AI, rules, rewards and progression.
- Invalid or swallowed Randomizer output safely falls back to the authored
  team, and temporary battle data is always cleaned up.
- Ordinary field rematches keep their existing randomized species and continue
  persistent training up to level 100.
- Researched Johto families can now join suitable field trainers
  deterministically; locked families remain absent and existing recruits never
  reroll.
- Gorochu remains fully optional: no opposing trainer can use it until the
  player has personally evolved a Raichu into Gorochu on that save. Before
  discovery, authored and Randomizer-generated teams receive Raichu instead.
- New independent **DEX SPRITES** option: keep each ROM's original
  Red/Blue/Yellow Pokédex fronts (default), or select static Crystal frame-one
  art for Kanto #001-151. Battle graphics and animation settings are unchanged;
  Johto, Gorochu and external sprite mods retain their own art.
- Existing Red, Blue and Yellow saves need no migration.

📥 https://github.com/Roxas2712/kanto-ascendant/releases/tag/v5.4.1

Please retest both normal rematches and Ascendant boss battles with your usual
Randomizer settings. Thank you! 💚

---

## KANTO ASCENDANT 5.4.0 — FIX & COMPATIBILITY LOG

Alongside **Gorochu** and **Thunderheart Awakening**, this release includes the
latest fixes and compatibility hardening:

### 💛 YELLOW PARTNER

- Oak's starter is correctly identified as Pikachu again, including with PokéPC
  Followers and stacked graphics wrappers. The protected scene marker fixes
  the actual opening encounter without rewriting unrelated level-5 Pokémon.
- The exact original partner is tracked through boxing, evolution, upgrades and
  follower mods. Ambiguous old saves ask the player instead of guessing.
- Raichu bond portraits move away from the reaction bubble. Sleepy and unwell
  have distinct expressions; the other five moods keep their official Crystal
  expressions. Battle sprites are unchanged.
- All seven Raichu moods have matching animation, bubbles and spoken one-bit
  mono voices.

### 🎨 SPRITES, FOLLOWERS & AUDIO

- Fixed oversized Gen-II back sprites such as Natu.
- Restored missing Gen-II cries.
- Fixed missing or incorrect Johto followers and the crash when selecting one.
- Mobile follower caches rebuild automatically.
- Added authentic normal and shiny Crystal back sprites for all 151 Kanto
  Pokémon at correct 1× scale.
- Disabling Crystal art cleanly restores the original Gen-I sprites.

### 🌿 WILDS & SAVE SAFETY

- Wilds of Kanto encounters now use researched Johto habitats and correct
  species art.
- Existing Yellow saves that received Oak's starter get Thunderheart
  automatically; Red and Blue saves never receive Yellow-only behavior.
- Thunderheart cannot be consumed, sold, discarded or deposited.

Existing Red, Blue and Yellow saves remain fully compatible.

📥 https://github.com/Roxas2712/kanto-ascendant/releases/tag/v5.3.0

Please feel free to retest and report anything unusual. Thank you! 💚
