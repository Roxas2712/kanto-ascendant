# Kanto Ascendant Core — Phase 9

Phase 9 keeps the released 6.0.7 save/manifest identity and adds the remaining
core systems without starting Phase 10.

## Implemented

- Five difficulty presets with exact trainer/wild offsets, an absolute level
  100 cap, modest Phase-7 mastery conversion for overflow, and Extreme's
  trainer-battle item ban. Wild battle Balls remain available.
- Gorochu and future registered guest Dex species use their Crystal animation
  frame only when the Crystal Dex option is selected. Original mode keeps the
  registered non-Crystal art. The generic battle renderer's send-out gate is
  retained, so a Pokémon is not drawn before its Ball opens.
- Remappable logical SELECT toggles the Bicycle only when the overworld is the
  active screen. Existing menu SELECT behavior is untouched.
- Driftglass Prism Grotto's hidden return sign is now a visible, reachable map
  object at the original return position and keeps the existing destination.
- The central Ascendant Options root exposes Gameplay, Followers, Visuals,
  Content and System categories. Every legacy schema row, including Kanto 151,
  edits the same persistent option bucket; EXP helpers remain dynamic rows.
- Optional shared rare-item protection covers use/throw, Bag toss, PC toss and
  selling. The initial protected registry contains Master Ball and always
  defaults the explicit confirmation to NO.
- Once-per-save Ho-Oh (1%) and Lugia (0.75%) visions use the normal battle UI,
  are uncatchable and EXP-free, suppress a competing encounter on that step,
  restore the full party, and scope the Nuzlocke exemption only to faint
  handling. They do not use Old-Man demo rendering.

## Verification

- `tests/core_phase9_test.lua`: exact offsets, cap/overflow, Extreme policy,
  rare-item registry, vision rates/once flags, visible exit and logical SELECT.
- Phase 6, 7 and 8 deterministic suites pass, including all 130,091 Phase-8
  assertions.
- Complete integration, imported recruitment, upgrade matrix, Atlas, field
  economy, 251/251 reachability, all follower phases, Gorochu, Driftglass,
  Johto Signals, Mythic Signals and Wilds compatibility suites pass.
- Strict Modkit validation passes against imported data.
- `tools/core_phase9_e2e_driver.lua` passes in separate real LÖVE processes for
  imported Red, Blue and Yellow data with Kanto Ascendant 6.0.7 and Nuzlocke
  loaded. It covers difficulty hooks/cap, Extreme policy, Bicycle mount/dismount,
  Master Ball default-NO, the complete central menu/Kanto151 route, visible
  Prism return, Gorochu registration and an actual uncatchable non-demo vision
  start plus party restoration.

Phase 10 remains intentionally untouched.
