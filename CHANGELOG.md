# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Fixed

- Red's Crystal walking cycle now uses the maintainer-supplied corrected
  down/left gait phases instead of keeping those silhouettes on the idle
  Y-position. The approved master, runtime copy and review board remain native
  16×16 nearest-neighbour art; Green, Blue and every non-walking surface are
  unchanged.


## [6.5.10] - 2026-08-22

### Fixed

- Red and Green now interpret Yellow's rival-party indices correctly, keeping
  the established Squirtle/Wartortle line and advancing every Pokémon Tower,
  Silph Co. and late Route 22 variant to the intended story tier.
- Winning the Pokémon Tower rival battle now restores the room music
  immediately on affected engine builds.
- Folipurba/Leafeon learns Leaf Blade/Laubklinge at level 71. The move remains
  a classic special Grass move globally and uses physical Attack only when
  used by Leafeon.
- Yellow's partner Raichu portraits no longer contain clipped edge fragments.
  A Yellow-only RAICHU FACES option switches between the corrected Ascendant
  set and animated classic Yellow-style faces; Pikachu, Gorochu and Red/Blue
  remain unchanged.

## [6.5.9] - 2026-08-22

### Fixed

- Yellow now has renewable Koffing and Weezing encounters in Pokémon Mansion
  B1F whenever KANTO 151 is set to REWARDS or WILD. Only two former Raticate
  slots change; Red, Blue and every other Mansion species remain untouched.
- The reachability audit now evaluates the actual Red, Blue and Yellow wild,
  fishing, gift, fossil, NPC-trade, event, research, evolution and legendary
  authorities separately. It no longer lets Red's Mansion table mask a Yellow
  gap, correctly finds Horsea through the Super Rod and derives Yellow's Jynx
  from the guaranteed Smoochum research egg.
- KANTO 151 OFF and deliberately disabled legendary options are reported as
  explicit configuration boundaries instead of false 251-species success or
  product defects.

## [6.5.8] - 2026-08-21

### Fixed

- New games no longer return to the first player-name prompt or stall after
  player/rival selection on Gen1Recomp 0.2.14. Ascendant now releases the
  engine's held Oak-intro TextBox before opening its custom NamingScreen;
  engines without that lifecycle method keep the previous path unchanged.

## [6.5.7] - 2026-08-18

### Fixed

- The native Trainer Card now renders the approved 640×400 HD standard layout
  with fixed KANTO ASCENDANT branding, the selected identity and active title,
  money, play time and eight Leader/badge cells. Existing 128-pixel player and
  Leader masters stay sharp, and Giovanni remains a black silhouette until a
  genuine Giovanni victory flag is present; an Earth Badge alone is not an
  identity reveal. No unlockable card collection, title expansion or
  pre-battle card overlay from the later roadmap is included.
- Yellow's exact level-5 Oak gift now receives its persistent partner marker
  when the original three-argument Lab command creates it. Unrelated Pikachu
  remain ordinary; storage, fainting and evolution into Raichu or Gorochu do
  not erase the marked partner or its native mood/emotion behavior. Existing
  saves adopt only one unambiguous eligible self-owned candidate.
- Yellow's German Oak's Lab exchange now reads naturally and preserves its
  intentional two-page, two-line layout. The adjacent English dialogue and
  the broader Red/Green/Blue character scripts are unchanged.

### Added

- A default-off **BOX ICONS → HGSS WALKERS** setting can use frame zero of the
  already bundled Wilds 16×96 normal/Shiny walking sheets in only the right-hand
  5×4 storage grid. The large left preview stays on its existing renderer, and
  missing species, Gorochu and unsupported forms fail closed to the current
  grid icon. No new art bytes are shipped; the existing third-party attribution
  remains unchanged.

## [6.5.6] - 2026-08-18

### Fixed

- Red and Green now retain their complete English and German identities in
  every Oak's Lab starter branch. Only Blue uses the native grandson dialogue;
  Red addresses Professor Oak respectfully, while Green acknowledges and
  apologizes when she absent-mindedly takes the intended starter.
- Yellow's catching tutorial now uses the existing approved Professor Oak
  standee in supported staged renderers instead of their small 2D fallback.
  Because no approved staged old-man model exists, only Red/Blue's old-man
  tutorial delegates to native 2D; later battles return to the configured
  renderer. Neither presenter is replaced by the selected player identity.
- Red, Green and Blue's newly supplied six-frame Crystal walking sheets are
  now primary. Their immediately preceding 6.5.6 sheets remain byte-exact as
  the first validated fallback; Green's public 6.5.5 sheet and every older
  per-character fallback remain behind that lane. No battle, profile, bicycle,
  fishing, throwing, HD or Voxel art is replaced.
- All Kanto species #001-151 now have separate Crystal-palette normal and Shiny
  follower sheets. The owned Pokémon's real DV-based Shiny state selects the
  matching sheet, while a missing or invalid Shiny asset fails safely to the
  normal follower.
- The ordinary Pokédex now remains exactly #001-151 before Driftglass and
  #001-251 after the National Dex upgrade; private runtime catalogue slots
  #252-279 no longer leak into that list. Seen Johto species also show an AREA
  marker when their authored Kanto habitat is genuinely active for this save.
- Wild-level scaling is now controlled by its own option and defaults to off.
  Trainer difficulty remains unchanged; enabling the option restores the
  previous badge-phased wild-level bonus exactly.
- Adaptive Trainer Levels is now independent from Difficulty's authored floor.
  AUTO is classic on Standard and targets the rounded active-party average
  +1/+2/+3/+4 on High through Extreme; manual -2, Match, +2, +4, +6, +8 and
  exact classic OFF remain available. Existing saves retain classic behavior
  until Adaptive or Difficulty is deliberately revisited. With Adaptive
  active, rematch ranks, evolution, recruits, AI and rewards progress without
  stacking the old unbounded numeric rematch bonus.
- The first canonical pre-Hall-of-Fame battle against each story Gym Leader
  now has authored Difficulty tiers. Standard passes through the exact
  Red/Blue team and restores Yellow's official special-move tables; High keeps
  the edition roster with three legal useful moves; Hard adds one themed
  member, stronger AI and one battle-wide heal; Very Hard and Extreme expand
  legal four-move teams and advanced AI within their documented roster and
  healing caps. Randomizer composition remains authoritative at its seam, and
  postgame, forced, Master, Apex and Crown battles fail closed. A legal
  Generation-II move can enter only after Beyond Kanto and the repaired
  Driftglass receiver are both active for that save.
- Rematch Break now offers Very Short 151-302, Short 303-604, Normal 605-1255,
  Long 1256-1882, Very Long 1883-2510 and Custom profiles. Fresh saves use
  Normal. Existing 151-2510, historical 128-256 and other hand-tuned pairs
  migrate to Custom without rewriting their values; switching profiles affects
  only future intervals and preserves every scheduled field `readyAt`, silent
  `nextTrainingAt` and postgame Gym `bossRest` timestamp.
- The classic Adaptive-OFF rematch strength preview now includes the same
  badge-phased Difficulty level adjustment as the constructed battle, so the
  greater-than-ten-level warning cannot understate the actual opponent.
- Actually upscaled ordinary trainer Pokémon retain at least one legal
  damaging or fixed-damage move instead of learning themselves into an
  attackless status set. Curated and unscaled authored parties remain intact.
- Giga Drain now uses its Generation-II 60-power half-damage recovery effect
  instead of dealing damage without healing.
- The one-time Thunder Tear is explicitly progression-locked and excluded from
  the ordinary rematch reward pool. The published field-rematch and Legacy
  Wanderer probabilities, weighted pools, OFF scope and capacity-safe delivery
  order were re-audited against the current implementation; native prize money
  and Pay Day remain unchanged.
- Dialogue fills both visible text rows before inserting another required
  button press, while preserving authored pauses, page breaks and safe wrapping
  for English and German text.
- Yellow's Mt. Moon fossil Super Nerd now receives his own challenge, victory
  and post-battle text instead of the generic Shorts fallback. Red/Blue, the
  fossil choice and Jessie/James scripting are unchanged.
- Yellow's independently selected followers no longer disappear when its
  authored partner is fainted or stored. Pikachu's logical first slot and
  story interaction remain reserved; up to five extras continue behind the
  player, and Pikachu returns to the front without duplicates or reordering.
- Ascendant-owned enemy Crystal fronts in native 2D battles are positioned
  eight pixels up and left so oversized animated, Shiny, Mega and Gorochu
  frames no longer overlap the player's Pokémon name. Gen-I sprites, trainer
  art, player backs and staged renderers retain their existing ownership and
  placement.

## [6.5.5] - 2026-08-17

### Fixed

- Replaced the Red, Green and Blue Crystal walking sheets with their new
  authored six-frame versions. The previous sheets remain byte-exact runtime
  fallbacks, and the resolver rejects damaged geometry, alpha or frame data
  without changing bicycle, fishing, battle, profile, throw or Voxel art.
- Wilds of Kanto can no longer place overworld Pokémon on starter/story
  positions, doors, exits, warps, NPCs, items, signs, switches or critical
  corridors. Oak's Lab stays Wilds-free until the starter has been received,
  and unsafe persisted or targeted spawns are repaired deterministically for
  the bundled and compatible external providers.
- Rival dialogue again follows the selected identity throughout the original
  story and postgame: Blue keeps the confident native voice, Red is calm and
  considerate, and Green is friendly, funny and occasionally absent-minded.
  English and German branches use the same identity contract.
- A short SELECT press in the overworld now uses the saved favourite Field Kit
  tool, while holding SELECT opens the full kit. Inside the kit, A uses a tool,
  SELECT assigns the favourite and B closes it. In the Bag, SELECT performs
  classic mark-and-place sorting, START opens help and B cancels or exits.
- Trainer Card character art is rendered with temporary nearest-neighbour
  filtering and restores the original graphics state, keeping pixel art crisp
  instead of blurry at scaled resolutions.
- Battle Art's retained staged-battle canvas now refreshes when an authored
  Mega form advances to a new animation frame, instead of freezing on its
  first frame. Battle Art remains the sole owner of its stage, camera and HUD.
- Kanto Ascendant now declares explicit conflicts with Unique Menu Icons and
  Dynamic Cries because those packages register the same expanded-species icon
  and cry keys. This replaces the late duplicate-registration crash with a
  clear manager conflict.
- All Pokémon Catchable and Modern Party UI are explicit conflicts as well;
  the existing Kanto Reforged and Trainer Rematch guards remain active. These
  packages overlap Ascendant's encounter, registry, party/summary or rematch
  ownership and must not initialize beside it.
- The Pokémon battle-animation default remains enabled. Existing saves that
  deliberately turned it off keep that choice rather than being overwritten
  during the update.

## [6.5.4] - 2026-08-17

### Fixed

- Fresh Red, Blue and Yellow campaigns now start the save-local Johto Signals
  cadence after receiving a starter and the Pokédex. Unlocking Johto also
  expands an active normal Randomizer to the deterministic #001-251 pool.
- Legacy/New Game+ saves that confirmed Johto now activate the intended wild
  distribution. Existing affected 6.5.3 saves receive the same idempotent
  repair after updating, without resetting their run choices.
- Legacy storage can be opened from every player PC during an eligible run.
  Item withdrawals accept a quantity and commit atomically, so a failed or
  cancelled transfer cannot duplicate or lose part of a stack.
- The three original Kanto starters can appear through their rare authored
  early Legacy habitats, while protected story encounters remain unchanged.
- Names remain `???` until Oak's naming confirmation instead of leaking the
  selected default name one screen too early.
- Surprise trainers use fairer loss-aware scaling, and the early difficulty
  curve phases level bonuses by badge progress instead of applying the full
  endgame modifier to a new party.
- Pokédex `AREA` no longer crashes on incomplete or incompatible encounter
  metadata.
- The Fighting Dojo prize choice is selectable again and rolls back safely if
  delivery fails. A previously blocked optional cave exit now triggers from a
  reachable movement tile while keeping its interaction fallback.
- Rematch combatants and their displayed evolved forms stay synchronized.
  Expert rematch AI no longer loops recovery moves when they have no useful
  effect.
- The native follower cap now covers the complete six-Pokémon party. Yellow's
  party-menu follower action is visible again, its genuine partner remains
  follower one, and the partner's evolved forms retain their dedicated face
  and bond presentation without granting it to unrelated Pokémon of the same
  species.
- Fresh Trainer Cards no longer claim the player is Champion before earning a
  title, and normal 2D battles use the selected Red, Blue or Green back sprite.
  Scripted catching tutorials retain their own trainer art.
- Every Ascendant visual option is inspectable again and is grouped into clear
  Pokémon-sprite and character/trainer sections.
- Trainer Cards now show the approved KASC Brock-through-Giovanni portraits
  in unearned badge slots while preserving the original badge artwork once a
  badge is owned. Red, Blue and Green profile art is kept wholly inside the
  card frame, including in the restricted runtime sandbox.
- Character-specific battle art now follows the renderer's actual battle
  mode instead of the mere presence of a voxel world. Native/normal battles
  always use the selected Red, Blue or Green back sprite; only a genuinely
  staged 3D battle uses that character's standing front card. The ORIGINAL
  and CRYSTAL HD presets now switch the complete 2D identity family for Red,
  Blue and Green, including selector, profile, scene, rival and battle art.
- The manager now admits official Voxel Ascendant, Battle Art, Dramaless and
  PotatoVoxel builds from their hardened baselines through 2.x on a best-effort
  basis. Ascendant exposes a closed,
  allowlisted renderer facade while PotatoVoxel retains its native camera, HUD,
  quality controls and cache. Out-of-range versions and multi-renderer
  combinations remain blocked; canonical repositories remain the support
  contract. Documentation also calls out the
  upstream `LOGS TO DEV` option, which is ON by default and can be disabled.
- Dramaless is admitted from `1.6.2-ST.190.1` through 2.x on the 0.1.96 stack
  instead of displaying a false conflict. Every Dramaless 2.x build is
  renderer-native and owns its voxel world, battle cards and battle HUD.
  Exact `2.0.2` exposes only a narrow fixed camera-preset control;
  its private loader, renderer modules, raw camera table and HUD authority stay
  private. Dramaless 3.x and multi-renderer combinations remain blocked; other
  in-range builds never inherit that exact adapter.
- Battle Art is admitted from 1.9.0 through 2.x. Exact 1.9.2's optional mesh
  cache no longer discards a completed live
  mesh merely because persistent cache storage is unavailable or the current
  map is ineligible; genuine eligible read, encoding and write failures remain
  fatal. Other in-range builds receive no exact cache repair; 3.x versions
  still fail closed.

## [6.5.3] - 2026-08-16

### Added

- Added the save-local, irreversible **BEYOND KANTO / JENSEITS VON KANTO**
  Hall-of-Fame decision. Before opt-in, original Kanto data, rematches and
  surprise battles stay Gen-I; non-Kanto bank withdrawals, Johto waves,
  Masters and extended rewards/evolutions remain sealed. HEVO/Hoenn caves keep
  one shared map/script set and substitute deterministic #001-151 encounters
  while sealed.
- Rematch 2.0 now evolves each field trainer's recognizable original roster
  through the registered evolution graph. Exact progressive two-stage and
  three-stage odds are constrained by real levels and existing Johto/custom
  unlock state; registered branches remain data-driven.
- All 47 authored class pools now expand from live species/type metadata.
  Released Johto families enter matching classes naturally, and the generic
  catalog remains open to future registered content.
- Dynamically added rematch members keep a compact three-battle history. The
  immediately previous species is strongly down-weighted, twice-consecutive
  use is excluded where alternatives exist, and exhausted pools relax without
  an unbounded selection loop.
- The Ascendant options tree now keeps essential gameplay choices visible and
  moves rematch, EXP training, Johto, legendary and heritage controls into
  focused FireRed-style submenus.

### Fixed

- Major Bob/Lt. Surge now recognizes the canonical victory flag when an
  upgraded or imported save has lost its Thunder Badge inventory entry, so
  Red, Blue and Yellow reach the Thunderheart hand-off instead of only the
  vanilla Ground-type advice. Yellow can also reconsider a declined trial,
  and a previously earned but missing permanent Thunderheart is restored on
  every loss, without replaying its choice or ever stacking above one, with
  an explicit English/German explanation.
- Re-authored the HEVO cave light relics as solid, discoverable side-branch
  objects instead of placing them on traversal lines. Red, Blue and Green now
  use varied forward stairs, and the real 0.1.90 collision path is checked
  from entrance through interaction, retreat and continuation.
- Restored the intended hybrid cave ecology: visible Wilds and classic random
  encounters can coexist, while Beyond Kanto adds registered Johto swimmers
  and a single rare Gyarados slot without changing either user option.

- Raised the supported engine minimum to Gen 1 Recomp 0.1.90. Version 6.5.1
  repaired the engine boundary; 6.5.2 adds the independently packaged Voxel
  Ascendant choice while retaining native 2D and the hardened DRAMALESS
  transition build.
- Extended the guarded Apricorn-Bag compatibility bridge to the unchanged
  0.1.90 menu surfaces. ASC RUN is available directly at Oak's Lab KASC
  Terminal, while the pre-throw Apricorn Ball explanation remains reachable
  on the current engine.
- The matching 0.1.90 clientfix now renders discovered HEVO fissures through
  the proper flat wall-decal pass instead of leaving only an invisible
  interaction anchor in 2D.

- The current standalone `shiny_indicators` release is not advertised as an
  engine-0.1.90 partner. Ascendant declares its exact manifest ID as a hard
  conflict because the package overlaps built-in shiny presentation hooks and
  still uses APIs denied by the reviewed sandbox.
- Engine-0.1.90 Voxel discovery admits the standalone
  `VOXEL_ASCENDANT 0.1.0` package and the fully audited
  `DRAMALESS_SHAPE 1.6.2-ST.190.1` compatibility build. The full game also remains
  available in native 2D. Other upstream Dramatic Shape, Battle Art and First
  Person releases fail closed instead of being advertised as supported while
  using APIs removed by the sandbox; the capability bridge remains
  renderer-neutral for a future reviewed build.
- Declared 0.1.90 hard conflicts for every bundled standalone subsystem
  and for the exact `Kanto-Reforged` manifest ID. The manager now prevents
  simultaneous initialization and asks the player to disable the other
  package first; Reforged remains untouched and loadable on its own.
- Removed the unconditional Generation-II retyping of Magnemite, Magneton,
  Bite, Gust, Sand-Attack and Karate Chop introduced in 3.0.0. Dark, Steel and
  the Johto records remain additive, while existing Generation-I type, stat,
  learnset and move records retain their vanilla Kanto data by default.
- Re-enabling Kanto Ascendant beside the standalone Useful Bag no longer
  fails with `screens already registered: BagMenu`. Ascendant now explicitly
  overrides the earlier optional-dependency screen while its own bag mode is
  active, so the engine can complete its normal restoration of Pokémon and
  items quarantined by a save made while Ascendant was disabled.
- Individual field-trainer progress now increments only after a won rematch.
  Losses and escapes no longer count as victories; existing `rematches` values
  remain the authoritative backward-compatible per-trainer save field.
- Voxel battle framing now defaults to `WIDE VOXEL`; existing saved camera
  choices still take precedence.
- Rematch recovery controls cycle through useful 151–2510 presets instead of
  requiring thousands of individual button presses.

## [6.0.11] - 2026-08-08

### Changed

- Player-facing Voxel camera wording is now renderer-neutral: `VOXEL DEFAULT`,
  `CLASSIC VOXEL` and `WIDE VOXEL` replace fork-specific terminology.

## [6.0.10] - 2026-08-08

### Fixed

- `CLASSIC VOXEL` now changes the compatible Voxel renderer's actual battle frame size as
  well as its camera position. The calibrated wider frame compensates for
  its larger models and matches the original Voxel battle scale; switching
  back restores the standard renderer frame exactly.
- `WIDE VOXEL` provides a further-out 3× framing for large Mega models whose
  head or wings would otherwise remain outside the battle view.
- The Voxel camera choice now appears next to Voxel controls in the
  regular OPTIONS menu and no longer clutters Kanto Ascendant's mod page.

## [6.0.9] - 2026-08-08

### Fixed

- Mega Evolution and Gorochu now use the compatible renderer's native 160×144 staged
  battle cards and 80×96 anchor, keeping their dedicated masters aligned in
  2D-3D FRONT SPRITES and world-space BACK SPRITES views.

### Added

- `VOXEL BATTLE CAMERA`: an optional `CLASSIC VOXEL` framing mode that
  restores the historical Dramatic Shape telephoto battle camera. The default
  remains the renderer's wider framing for its larger models.

## [6.0.8] - 2026-08-08

### Fixed

- Renamed the permanent manifest identity from the conflicting
  `trainer_rematch` to `kanto_ascendant`, so the launcher no longer rejects
  Kanto Ascendant because an unrelated mod owns the old ID.
- Added lossless first-load migration for 6.0.7 progress, active-mod metadata
  and all configured Ascendant options. Existing current values take
  precedence; the old namespaces remain untouched for rollback.
- Declared the historical `trainer_rematch` identity as a runtime conflict so
  an accepted old build and 6.0.8 cannot execute over the same save together.
- Battle Art Voxel 1.7.6 renamed its public API export to
  `BATTLE_ART_VOXEL_FORK`. Mega Evolution and Gorochu now use that API as
  well as the legacy Dramatic Shape ID, so front-facing Voxel fights do not
  receive the obsolete classic Mega rear overlay.

## [6.0.7] - 2026-08-08

### Fixed

- The ROM-free Atlas/Legacy regression now expects the current release
  manifest and the CI package/audit paths are versioned for 6.0.7. This
  restores the release gate without changing gameplay or save data.

## [6.0.6] - 2026-08-08

### Fixed

- The Ascendant New Game+ Steward now spawns in the reachable Indigo Plateau
  Lobby instead of the one-way Hall of Fame cutscene map. The Research Atlas,
  README and spoiler FAQ now direct ready players to the lobby.

## [6.0.5] - 2026-08-06

### Fixed

- Ordinary Johto wild replacements now scale to the rounded, Gen-I-weighted
  average level of their current route plus a random 2-5 levels. This applies
  identically to classic encounters, Wilds of Kanto and permanent researched
  habitats; explicitly authored primal/story encounters retain their intended
  levels.
- The public FAQ now describes researched Johto habitats as route-dependent
  encounter locations instead of displaying obsolete fixed habitat levels.

## [6.0.4] - 2026-08-06

### Added

- Added the optional **Prism Grotto** beneath Driftglass. Six native cave
  pillars and a bilingual Prism Reader provide short, reusable sequence
  riddles for the Sun Stone, King's Rock, Metal Coat, Dragon Scale and
  Up-Grade.
- Added a repeatable ten-note Twilight Mirror rite. An Eevee in the party
  reaches the existing friendship threshold, after which its next level by
  day or night produces Espeon or Umbreon.
- Added persistent puzzle progress, non-duplicating rewards, full-Bag
  reservation, mode-aware researcher guidance and safe map fallback when the
  mod is disabled.
- The central crystal tablet behind the Prism Reader now offers optional
  **Johto Move Resonance** for 104 original Kanto species. It follows Crystal's
  legal TM, inherited and level-up access for the Gen-II moves implemented by
  Ascendant; genuine level-up moves remain locked until their original level.
  The tablet never replaces moves itself: a full moveset is directed to the
  existing Route 5 Move Deleter, and every crystal-taught move is recorded for
  the existing Move Reminder.

### Fixed

- Johto Signals now writes accepted or declined onboarding choices to the
  selected game save immediately, so the prompt does not return after a
  restart merely because the player had not reached another manual save.
- Loading an older or already repaired save can no longer briefly queue the
  Johto direct-start question from the provisional title-screen save. The
  question is now created only after the selected slot is fully loaded (or
  after the first real step of a new game).
- All #152-251 species now use their bundled species-authentic legacy cries
  instead of type-based Gen-I pitch/length substitutes. External cry providers
  remain authoritative.
- All #152-251 species now register their own bundled Crystal front/back art
  instead of a same-type Kanto silhouette. The National Dex also resolves
  every Johto entry to its species-authentic static Crystal frame in either
  Dex style, including UI paths that previously exposed the fallback.
- **DEX SPRITES → CRYSTAL** now also controls the static portrait on the
  party's **STATS/status screen**. It previously affected Pokédex pages while
  that separate team-detail renderer continued to show the active
  Red/Blue/Yellow front sprite.
- Guaranteed and bonus-roll wild shinies now receive their shiny state before
  Crystal, Voxel or other battle-graphics wrappers select artwork, preventing
  non-delegating visual wrappers from displaying their normal sprites.
- Optional native Driftglass and Prism Grotto music now remains active with
  imported Red, Blue or Yellow audio while cleanly skipping the deliberately
  audio-free ROM-less Modkit fixture, restoring strict package validation.

## [6.0.3] - 2026-08-05

### Added

- Driftglass' researcher now upgrades the ordinary Kanto Pokédex into the
  **National Dex** when the Migration Receiver is repaired.
- Added an optional **VISIBLE JOHTO** bridge for Wilds of Kanto 1.7.1.
- Added an in-game **WILDS LINK** status page that explains whether visible
  encounters are linked, disabled or unavailable.
- Added normal and shiny six-frame Johto walker providers that preserve the
  existing PokéPC/Followers EX provider for Kanto species.

### Fixed

- The Pokédex no longer exposes #152-251 merely because Johto species are
  registered by the mod. Before the Driftglass upgrade it remains Kanto-only.
- The former immediately available Johto submenu is now a gated National Dex
  shortcut with the complete ordinary data pages.
- Existing 6.0.0-6.0.2 saves whose Johto receiver was already active receive
  the National Dex automatically. A quest that had only begun keeps the
  intended Driftglass researcher unlock.
- Early Johto currents and researched Johto habitats now apply to newly
  generated Wilds of Kanto overworld encounters.
- Changing the current, scanning a primal trace or toggling the related
  runtime options now clears stale visible encounter rolls.
- Visible Johto species no longer fall back to static Crystal battle
  portraits in Wilds of Kanto.

## [6.0.2] - 2026-08-05

### Fixed

- Professor Oak's English and German Johto Signals calls now read the
  trainer's actual name from the active save instead of displaying the
  unresolved `[PLAYER]` placeholder.
- Added regression coverage for the initial call and reminder in Red, Blue
  and Yellow, including localized dialogue rendering.

## [6.0.1] - 2026-08-05

### Changed

- Rebuilt the opening Johto Signals sequence as a coherent field quest.
  Professor Oak now calls after 1–200 eligible post-Pokédex steps and directs
  the player to Pallet Town's southern coast.
- Oak gives one reminder after another 400 eligible steps if the shore object
  remains untouched. Taking the capsule permanently cancels further calls.
- The dark capsule is now a real, persistent coast object. It can be left
  alone, taken and opened immediately, or kept sealed and opened later from
  **ASCENDANT → WORLD → JOHTO SIGNALS**.
- Opening the capsule reveals foreign pollen, starry sand, a damaged receiver
  and coordinates. The Pallet boatman must identify those coordinates before
  offering the reversible Driftglass crossing.
- Rewrote and reflowed the English and German Oak, capsule, boatman,
  researcher, menu, Journal and Mythic guidance text.

### Fixed

- Repeatedly declining the first prompt can no longer produce a false
  “capsule waiting” message or permanently remove the quest giver.
- Existing 6.0 saves migrate to the staged capsule flow without losing an
  already opened capsule, Driftglass access, receiver progress or encounter
  counters.
- The original 128–768-step/five-visit discovery condition is replaced by a
  strict 200-step maximum, including upgraded saves whose old hidden target
  was higher.
- The physical capsule and boatman refresh independently and cannot duplicate
  each other on Pallet Town's coast.
- Long German lines in the researcher and Mythic guidance now fit the Gen-I
  text renderer.

## [6.0.0] - 2026-08-05

### Added

- **Johto Signals**, an optional early-story migration quest that begins only
  after the starter and Pokédex. Its Pallet capsule uses a hidden 128–768-step
  target and is guaranteed by the fifth eligible Pallet visit.
- The reversible Driftglass signal-station trip, Migration Receiver and three
  player-selected currents: unchanged **Kanto First**, 2%/4%
  **Wanderwaves**, and 10% **Johto Unleashed**.
- Four spoiler-safe primal traces that independently unlock Chikorita,
  Totodile, Cyndaquil and Larvitar. Their 1:512 or 1:256 encounter counters
  retain progress across mode changes and guarantee the next eligible battle
  at the limit.
- **Mythic Signals** for Mew and Celebi. Three protected echoes lead to a
  physical Resonance Seal handoff after four Badges, followed by true
  manifestations with a guaranteed 1:8192 counter.
- Persistent bound retries for a failed true manifestation, preserving its
  species, DVs, HP and status rather than restarting the full search.
- Complete English/German Driftglass dialogue, receiver guidance, Journal
  objectives and localized Atlas location names.

### Changed

- The Ascendant **WORLD** submenu now owns Johto Signals, Mythic Signals and
  the existing rotating world-event report without adding duplicate Start
  menu rows.
- Disabling **EARLY JOHTO** now affects only migration encounters. An enabled
  Mythic Signals path retains the shared capsule, receiver and Driftglass
  researcher while enforcing Kanto First.
- Journal and Atlas signal goals are explicitly optional and never replace
  Gold or another mandatory main objective. Unseen objective species remain
  `???`.
- Wilds of Kanto and ordinary grass encounters share the same transactional
  selection. Scripted encounters, roamers, outbreaks, research replacements,
  Repel and failed visible spawns cannot spend a signal pity counter.
- Professor Elm recognizes an early-caught Johto specimen and awards a
  deterministic, Bag-safe research compensation instead of a duplicate.
- The upgrade matrix now has distinct schema-derived 5.3 Red, Blue and Yellow
  cases. It verifies non-invasive Signals defaults, pre/postgame starts,
  legacy world-event preservation, canonical Mew/Celebi repair, native save
  serialization, restart and mod off/on while explicitly distinguishing
  those fixtures from original player-save evidence.

### Fixed

- Echoes cannot be knocked out by direct, fixed, multi-hit or residual
  damage, and flee after one to three turns without allowing a Master Ball to
  be consumed.
- Exactly three echoes pause further echo rolls until the receiver is sealed.
  Already-owned or disabled Mew/Celebi outcomes are excluded from later
  searches.
- Driftglass always retains a valid return route, including upgraded saves,
  restarts and mod disable/re-enable cycles.
- Saving during a live Driftglass visit now writes the native Pallet landing
  as the resume point without interrupting the current visit.
- Celebi's ordinary Pokédex/fallback presentation now uses its sharp bundled
  Crystal sprite instead of the obsolete placeholder. Normal, Shiny, 2D,
  Crystal Animated and Voxel battle paths retain the same Celebi identity.
- Reflowed Celebi's English and German Pokédex prose to the real Gen-1 text
  width so no words are cut off.
- Verified the retroactive Gorochu route after an already-completed Lt. Surge
  battle: repeated refusals remain reversible, the permanent Thunderheart is
  still available from Surge, and the remote condenser can be declined and
  used later without consuming the Heart.
- After giving the Thunderheart, Lt. Surge/Major Bob now hands later
  conversations back to the normal postgame controller. His Master and Crown
  rematches are therefore reachable even while Gorochu is in the party.

## [5.4.2] - 2026-08-05

### Added

- Added a complete public `FAQ.md` with GitHub-native spoiler sections for
  installation, Kanto/Johto acquisition, item milestones, shiny odds,
  outbreaks, the red Gyarados, Mega Evolution, Gorochu, Heritage events,
  post-game progression and troubleshooting.
- Event Archive entries now explain that `READY` means unlocked and direct
  Festival players to the correct Cup city or Roaming Hunt players to the
  appropriate habitat.

### Fixed

- Master and Crown Leader victories are now committed on `battle.ended` as
  well as the battle callback. Existing saves with a missing circuit crest are
  repaired safely from Ascendant's victory-only boss history.
- Lt. Surge/Major Bob now keys his optional hand-off to the permanent
  Thunderheart itself: a postgame save missing the item receives it first,
  while an owner immediately reaches the normal Master/Crown rematch chain.

## [5.4.1] - 2026-08-04

### Added

- Added a persistent bilingual **THUNDER PATH / DONNERPFAD** guide after the
  Thunderheart is obtained. It points to the Power Plant condenser, reports
  when the Thunder Tear is ready and records the completed Gorochu discovery.
- Added dedicated sharp 96×96 normal/shiny Gorochu front and back masters for
  Dramatic Shape/Voxel. They are rendered on a supersampled battle texture
  instead of enlarging the smaller 2D Crystal card.
- Added independent normal/shiny six-pose Gorochu follower sheets for classic
  2D and Voxel follower paths.
- Completed the animated normal/shiny dialogue-portrait sets for both Raichu
  and Gorochu across sleepy, unwell, upset, wary, content, devoted and excited
  partner moods.

### Changed

- Repeatable field trainers can now recruit a class-appropriate Johto family
  after that family is exposed by Elm's research controller. Before its
  unlock, the same trainer remains Kanto-only.
- Johto recruitment is deterministic per save and trainer. Existing recruit
  choices do not reroll when more research families become available, and
  non-level evolution families use stable level thresholds for NPC teams.
- Normal rematches retain their established order: the Randomizer constructs
  the roster first, Ascendant adds earned recruits second, then persistent
  rematch and background-training levels are applied up to level 100.
- Added the independent **DEX SPRITES** option. `ORIGINAL` (the default)
  preserves the active Red/Blue/Yellow ROM's palette-aware Pokédex fronts;
  `CRYSTAL` uses bundled normal frame one for Kanto #001-151 only. Battle
  artwork and Crystal animation remain controlled by their existing options.
- Replaced 5.4.0's Gorochu bond/Thunder/Power-Plant level-up trigger with a
  deliberate item journey. Red and Blue receive the permanent Thunderheart
  from Lt. Surge after the Thunder Badge; Yellow retains its 251-step,
  three-trainer-battle partner trial. A remote condenser in the Power Plant's
  east wing turns the Heart's charge into one consumable Thunder Tear, which
  permanently evolves the Raichu selected from the Bag.
- Gorochu audio is now edition-aware. Yellow uses the dedicated spoken clip;
  Red and Blue use a Raichu-derived Gen-I chip cry with pitch/length data.
  Any Gorochu cry owned by another mod remains authoritative.

### Fixed

- Rebuilt all authored Ascendant trainer battles around a temporary synthetic
  trainer party. Randomizers now receive the intended Master, Crown, Apex,
  Johto Master, Grand Tour, Heritage, research-trial, tournament and hunt
  roster instead of the trainer's original party 1.
- Forced battles now chain `trainer.party` cooperatively in either hook order.
  Valid randomized species and moves are preserved while Ascendant reapplies
  the authored team size, slot levels, stats, experience, full HP, AI and boss
  metadata.
- Added a final forced-battle guard that rejects empty, oversized, invalid,
  wrong-size and obvious vanilla-party fallbacks, then reconstructs a coherent
  authored opponent without double-boosting levels.
- Synthetic parties and construction state are cleaned after success or error,
  preventing hot reloads and back-to-back battles from contaminating the next
  normal trainer encounter.
- Hardened Ascendant's trainer-party construction boundary so invalid hook
  output falls back before Pokémon construction, including on the frozen
  public engine API.
- Gorochu now remains a player-led optional discovery in Red, Blue and Yellow.
  Opposing trainers and Randomizer-produced trainer teams use Raichu instead
  until the player has personally evolved a Raichu into Gorochu on that save.
- Dramatic Shape/Voxel no longer enlarges Gorochu's smaller Crystal battle
  card. Normal and shiny player/enemy views now route to their dedicated
  high-resolution front or back master with nearest-neighbor filtering.
- Replaced the temporary repeated follower views with readable species-shaped
  walking art containing six distinct poses in both normal and shiny colors.
- Raichu and Gorochu bond conversations now keep their selected normal/shiny
  portrait animation separate from battle art and from the emotion bubble.
- Yellow NPC lines that explicitly refer to the player's original partner now
  say Pikachu, Raichu or Gorochu as appropriate; unrelated wild, fan-owned and
  Pokédex references to Pikachu remain unchanged.

### Compatibility

- Existing Red, Blue and Yellow saves require no migration.
- Ordinary randomized field rematches keep their randomized species and their
  existing persistent level/team-growth behavior.
- Existing saves without a Dex-art preference resolve to `ORIGINAL`. Johto,
  guest species and explicitly installed external sprite mods retain ownership
  of their registered Pokédex art.
- Existing 5.4.0 saves that already completed the Gorochu evolution retain
  trainer access automatically; merely owning its quest items does not unlock
  it for opponents.
- Accepted saves from the unpublished Storm Bond prototype receive the
  permanent Thunderheart. Existing externally registered Gorochu cries and
  sprite ownership are not overwritten.

## [5.4.0] - 2026-08-04

### Added

- Raichu can permanently evolve into the separate guest species Gorochu in
  Red, Blue and Yellow after the Hall of Fame by reaching high bond, knowing
  Thunder and leveling up inside the Power Plant.
- Gorochu is registered as guest Pokédex #1026 with an original Electric
  stat/learn profile, Pokédex entry and safe Raichu-derived fallback cry.
- Dedicated normal/shiny front, back, six-frame Crystal battle animation and
  follower art.
- Yellow's original partner keeps its per-Pokémon identity, happiness,
  memories and follower when Raichu evolves again. Partner Gorochu has seven
  separate animated normal/shiny faces for sleepy, unwell, upset, wary,
  content, devoted and excited reactions.
- The Research Atlas reveals Gorochu and its evolution condition after
  discovery. The Shiny Dex recognizes it without adding it to the original
  251-species completion target.
- A real-client UAT driver verifies evolution, save identity, normal/shiny
  battle art, follower behavior, seven expressions and emotion-bubble
  separation.

### Changed

- The standalone Crystal animation controller now supports explicitly
  registered guest Pokédex numbers and player-side guest animations.
- Breeding resolves Gorochu back to Pichu, while follower compatibility can
  safely proxy the full Raichu family.

### Fixed

- Hardened Pokémon Yellow's Professor Oak intro against PokéPC Followers
  1.3.0 and stacked graphics wrappers. The scripted catch now carries a
  stable scene marker through `BattleState.newWild`, is normalized to the
  canonical level-5 Pikachu inside the engine and has a tightly scoped Pallet
  pre-starter fallback for older builds. Ordinary level-5 encounters are not
  globally rewritten, and a temporary Charmander conversion no longer leaves
  a false Pokédex sighting.

## [5.3.0] - 2026-08-04

### Added

- Yellow's exact Oak-gift partner Pikachu now receives a persistent identity
  that survives boxing, evolution, existing saves and follower wrappers.
- After earning the Thunder Badge, Lt. Surge offers the optional bilingual
  **Heart of Thunder** journey: walk 251 steps and win three trainer battles
  with the partner, then return to receive the permanent **Thunderheart**.
- Thunderheart is an unsellable, non-discardable and non-consumable key item.
  Using it lets the partner choose Raichu, remain Pikachu or decide later.
- An evolved partner Raichu keeps Yellow's happiness, memories, follower
  behavior and new happiness-sensitive bond moments. Follower conversations
  now give Raichu distinct sleepy, unwell, upset, wary, content, devoted and
  excited reactions with matching bubbles, mood-specific animated Crystal
  portraits and dedicated spoken Raichu clips converted to Yellow-style
  one-bit mono PCM.
- Partner Raichu's framed portrait now selects the screen side opposite its
  emotion bubble, keeping both readable. Ten restrained normal/shiny custom
  frames add the two expressions Crystal lacks: closed sleepy eyelids with the
  original yawn, and drooping unwell eyelids with a small downturned mouth.
  Upset, wary and all positive moods keep the cleaner official Crystal faces.
  Raichu's Crystal battle sprites are never replaced or modified.
- If the partner remains Pikachu, an owned Raichunite X or Y can resonate
  directly in battle. It temporarily becomes the corresponding official Mega
  Raichu and returns to the same Pikachu after battle.

### Changed

- Every upgraded Yellow save that already received Oak's starter receives
  Thunderheart automatically with the early trial complete.
- A unique old-save Pikachu/Raichu is adopted automatically. If several
  self-owned candidates exist, Thunderheart asks the player to identify the
  original partner once instead of guessing.
- Red and Blue explicitly reject the Yellow-only item and partner-Mega bridge.

## [5.2.3] - 2026-08-04

### Fixed

- **KANTO CRYSTAL ART** now includes authentic normal and shiny player-side
  sprites for all #001-151. Yellow's special Pikachu and every other Kanto
  battler now use a matching 56×56 Crystal back at native 1× scale instead of
  retaining the enlarged Gen-I rear view.
- Disabling **KANTO CRYSTAL ART** still restores both original Gen-I fronts
  and backs; external Kanto visual mods retain ownership of their sprites.
- Researched Johto habitats now feed directly into **Wilds of Kanto**. Their
  intended two-percent post-Hall-of-Fame encounters can appear as visible
  overworld Pokémon instead of being bypassed by Wilds' direct table picker.
- Wilds receives stable sprite registrations for all 100 Johto species and
  renders its generated species art rather than a shared placeholder.
- PokéPC Followers no longer changes Yellow's scripted level-5 Pikachu into
  Charmander. Oak now catches Pikachu in the opening again, the starter keeps
  its correct name and dialogue, and PokéPC's follower selection remains
  fully available.

## [5.2.2] - 2026-08-04

### Fixed

- Johto fallback cries now use Gen1 Recomp's ROM-native derived-cry path
  instead of mod-local chip synthesis, restoring Gen-II audio on Android.
- Release packages now include all 200 normal/shiny Johto follower sheets in
  renderer-ready 16×96 form, removing mobile runtime conversion and cache
  writes from follower selection.
- A renderer-level compatibility guard redirects PokéPC Followers and wrapper
  mods to Ascendant's bundled Johto art even when Lua closure inspection is
  unavailable. Selecting a Gen-II follower can no longer reach a missing
  `follower_<SPECIES>.png` path and crash.

## [5.2.1] - 2026-08-04

### Fixed

- All 100 Johto player-side Crystal sprites now use their intended native
  1× scale instead of Gen I's 2× back-sprite enlargement. Natu and the rest
  of #152-251 no longer cover most of the battle screen.
- Late Gen-II cry binding now runs again after the selected save is adopted
  and clears stale failed audio lookups, so Johto cries remain audible when
  follower or UI mods request them early during startup.
- PokéPC Followers compatibility now reaches its sprite resolver through
  additional Followers EX or graphics wrappers, refreshes an already visible
  follower immediately and rebuilds stale mobile-derived follower sheets.

## [5.2.0] - 2026-08-03

### Added

- **Ascendant Typhlosion**, Kanto Ascendant's first deliberately unofficial
  secret form. It is kept outside the official 30-form Mega Stone catalog and
  requires Gold, a complete 251-species Pokédex and a level-100 Typhlosion at
  the new Basalt Seal in Pokémon Mansion B1F.
- A permanent Basalt Core relic, bilingual discovery sequence, spoiler-safe
  Starter Relic tracking and optional Journal/Prestige progress.
- Dedicated 96×96 normal/shiny front/back art for all 30 official Mega forms,
  with 736 side-aware integer-pixel frames covering 2D enemy fronts, player
  backs, shinies and Voxel-facing battles.
- Static four-shade normal/shiny front/back derivatives for every official
  Mega and Ascendant Typhlosion. Disabling Crystal art now produces genuine
  edition-aware Red, Blue or Yellow Mega views in both 2D and Voxel instead of
  continuing to show the full-colour Crystal-style animation.
- Acquisition-independent Starter Relic journeys for the Chikorita, Totodile
  and Cyndaquil families. They assign from Pokédex ownership, party or PC box,
  so trial gifts, wild catches, other gifts and upgraded saves all work.
- Full one-time Verdant and Torrent Relic journeys for Endivie and Karnimani.
  Alongside their shared walking and trainer-battle bond goals, Endivie's
  family must awaken the old growth of Viridian Forest and Karnimani's family
  must cross the ice and tide of Seafoam Islands. Their keepers in Celadon and
  Cerulean award the otherwise unforgeable Meganiumite and Feraligatrite.
- Visible `NEW` markers and a bilingual next-objective guide for every Johto
  Starter Relic. Feurigel's guide now points to Gold first, then the 251
  Pokédex, level-100 Tornupto and only finally the Basalt Seal.
- Late Gen-II cry binding that preserves every externally registered species
  cry and installs Ascendant's synthesized audio only for genuinely missing
  Johto entries. Mega and Ascendant forms retain that resolved species cry.

### Changed

- The transformation animator now supports distinct front and back frame
  trees for every supported form while remaining backward-compatible with
  older flat animation data.
- Classic 2D Mega rear views now use larger 90×84 runtime cards. Their upper
  bodies fill the player arena beneath the redrawn HUD, while the original
  opaque battle-command box cleanly masks every pixel below its border.
- Every official Mega form and Ascendant Typhlosion now has an individual
  2D rear-view anchor derived from its complete back-animation silhouette.
  Broad heads, wings and shoulders stay left of the player HP HUD in normal
  and shiny frames instead of sharing one unsuitable global position.
- Mega Charizard X's broad player-back pose is anchored farther left so its
  right wing and body sit correctly beneath the player HUD.
- Ascendant Typhlosion uses Fire/Ground, a +100 Gen-I stat adaptation and
  restores 25% HP once on awakening.
- Ascendant Typhlosion's approved design is merged with Crystal #157's full
  23-frame front flame motion and timing. Its broad obsidian chest-and-
  shoulder mantle, open V, bracers and greaves are now reduced directly from
  the accepted full-resolution concept, replacing the broken geometric
  overlays that obscured its arms. Both the front and 12-frame back loop build
  into a full cyan volcanic eruption behind the body without covering it.
- Meganiumite and Feraligatrite show `QUEST` instead of a price in the Stone
  Case and can no longer be forged for money.

## [5.1.1] - 2026-08-03

### Added

- Bundled authentic normal and shiny Pokémon Crystal front animations for
  Kanto #001-151. Together with the Johto pack, Ascendant now supplies all
  #001-251 without requiring a separate visual mod.
- A `KANTO CRYSTAL ART` option that restores original Gen-I fronts at any
  time while leaving the Johto art choice independent.
- Standalone Kanto 2D QA alongside the existing Johto, Voxel and mixed-mod
  animation scenes.
- Dedicated normal and shiny 56×56 pixel animations plus static player backs
  for Mega Charizard X, adapted from BLaDoM's recognizable Gen-V-style work.

### Changed

- Crystal Animated Sprites with Shiny Visuals is optional. When installed it
  automatically keeps ownership of #001-151, avoiding competing animation
  states, duplicate shiny effects or sounds.
- `CRYSTAL ANIMATION` now controls all bundled #001-251 front animations.
  Original 2D player backs remain static and Dramatic Shape still receives
  the front-facing normal or shiny frame.
- Mega Charizard X keeps its own detailed animation in both 2D and Voxel
  battles, even when an external full-roster sprite mod is active.

## [5.1.0] - 2026-08-03

### Added

- Authentic normal and shiny Pokémon Crystal front animations for all 100
  Johto species. The complete numbered-frame pack and original GIF timing are
  bundled; no separate download is required.
- A `CRYSTAL ANIMATION` option under Kanto Ascendant. Ordinary 2D battles
  animate the opponent while retaining the player's authentic Crystal back;
  Dramatic Shape's staged Voxel battles animate both front-facing Pokémon.
- First-class coexistence with **Crystal Animated Sprites with Shiny
  Visuals**. That mod owns Kanto #001-151 while Ascendant supplies Johto
  #152-251, including shiny artwork and presentation.
- A real-LÖVE compatibility driver covering 2D, Voxel and a mixed
  externally-animated Kanto versus Ascendant-animated Johto battle.

### Changed

- Official Mega art now resolves outside lower-priority full-species sprite
  replacements, so Mega Evolution cannot be hidden by the Crystal mod.
- Kanto Ascendant suppresses duplicate shiny sparkles and chimes only for the
  Kanto species the external Crystal mod actually supports. Johto keeps
  Ascendant's effects and Shiny Dex presentation.
- A visual mod that explicitly replaces a Johto sprite keeps ownership of
  that species; the bundled animation remains the safe default and fallback.

### Fixed

- Crystal Animated Sprites and Dramatic Shape can now run together with Kanto
  Ascendant without Totodile-through-Celebi falling back to unrelated Kanto
  battle art.
- Normal 2D player backs remain static, while Dramatic Shape's intentional
  back-to-front substitution receives the matching normal or shiny animation.

## [5.0.2] - 2026-08-03

### Added

- All 400 normal/shiny Pokémon Crystal front/back sprites for the 100 Johto
  species are now bundled directly with ZIP and MODPKG releases.
- All 198 normal/shiny PokeWilds six-pose sheets for the 99 standard Johto
  followers are bundled; Unown continues to derive its matching walking art
  from the included Crystal sprite.

### Changed

- `JOHTO ART` now identifies Crystal art as bundled instead of local.
- The sprite installer scripts remain available as repair/refresh tools.

### Fixed

- Fresh launcher installations no longer show related Kanto fallback species
  such as Squirtle for Totodile when the external sprite installers were not
  run.

## [5.0.1] - 2026-08-03

### Added

- A one-time bilingual 5.0 onboarding for every new or upgraded Hall-of-Fame
  save. Oak introduces the Ascendant menu, Route 5, Elm's research and the
  new Indigo, Vermilion and Celadon facilities.
- One authoritative next-objective tracker shared by the Journal and Research
  Atlas, with a localized location, exact progress and separate optional
  prestige records for the Battle Factory and S.S. Anne.
- Visible `NEW` / `NEU` markers when another Ascendant utility becomes
  available.
- A 1,086-check upgrade matrix based on the public 1.1.0 and 2.0.0 schemas
  plus real 3.1.0 and 4.1.1 launcher saves. It covers Red, Blue and Yellow in
  English and German, restart, mod-disable and re-enable paths.

### Changed

- Gold is now the mandatory final main battle before KANTO ASCENDANT and the
  first or any later New Game Plus cycle can begin. Battle Factory and S.S.
  Anne clears remain optional prestige challenges.
- Unknown Legacy Gallery trophies display only `???` until completed.
- Atlas locations use authored English/German names, and known Pokémon now
  show their evolution method without revealing an unseen target.

### Fixed

- Disabled Johto research or Frontier options no longer leave an impossible
  New Game Plus requirement.
- The TM FIFO, Johto research, trainer growth, titles, shinies, Gold clears
  and base player data survive all covered historical upgrade paths.

## [5.0.0] - 2026-08-03

### Added

- A spoiler-safe Research Atlas under `ASCENDANT` with Oak's current
  objective, recorded trainer locations/ranks/exact cooldowns, authoritative
  reward bands and gates, TM queue status and habitats only for species
  already seen or caught.
- Permanent thematic Kanto habitats for 44 researched Johto base species.
  Each relevant habitat keeps a 2% total replacement chance and unlocks only
  after its specimen, starter trial or Larvitar finale has been recorded.
- Individual English/German Pokédex entries, classifications, canonical
  height/weight data, explicit Crystal-shaped level plans and varied legal
  TM/HM profiles for all 100 Johto species.
- A Route 5 Move Reminder for legal level-up moves, moves previously forgotten
  through the machine, exact event-provenance moves and earned Crown starter
  signatures.
- A Frontier Exchange after the Crown Champion. Released evolution items are
  renewable for 6-10 Frontier Points and any individually archived TM can be
  selected again for 3 points.
- A level-100 Indigo Battle Factory: draft three of six changing,
  fully-evolved non-legendary rentals and clear three sealed-Bag battles for
  4 Frontier Points, or 6 without a faint.
- A five-battle level-100 S.S. Anne Grand Tour with healing after rounds two
  and four, 8 Frontier Points and a 4096-real-step departure timer.
- A Celadon Legacy Gallery with completion and challenge trophy displays,
  plus selection of any unlocked achievement as the active Trainer Card title.
- Factory Architect and Sea Champion, bringing the permanent title catalogue
  to seventeen.
- A standalone 251-species reachability/evolution-economy audit and pinned
  GitHub Actions regression workflow.

### Changed

- Training Rush now accelerates only defeated-trainer recovery and silent
  growth. Eggs, friendship, outbreaks, world events and S.S. Anne departures
  always count literal walked tiles.
- TM archive rewards use a persistent FIFO. A full Bag no longer pauses the
  win clock, later TMs queue behind earlier ones, and the exact oldest waiting
  reward is reported and delivered first.
- TM51-53 become permanent entitlements on the winning Crown battle even when
  the Bag is full.
- Rematch loot is determined only by the selected BALANCED or GENEROUS table.
  Trainer rank still affects presentation, team growth and AI but never adds
  hidden probability bands.
- Shiny outbreaks require the Hall of Fame and all three Johto starter trials.
  Larvitar cannot enter a migration before Elm's research finale.
- The content-patching `KANTO 151` option now warns that changing it requires a
  restart; its loaded mode is visible in the Journal.

### Fixed

- Battle Factory runs restore the exact original party on victory or defeat,
  block saving while a rental party is active, and repair stale interrupted
  saves from earlier builds on load instead of persisting temporary rentals.
- Factory rental and opponent-construction errors now roll back the exact
  original party immediately, clear the save veto and release the host.
- Factory and S.S. Anne clear dialogue reports the Frontier Points actually
  credited, including the active Frontier Festival multiplier.
- The first TM no longer counts as a completed archive cycle.
- Blocked TMs and blocked Crown signatures can no longer be lost, reordered or
  require repeating a boss battle.
- Evolution-item and archived-TM purchases are atomic: locked stock, a full
  Bag or insufficient points never consumes Frontier Points.
- Johto registration and habitat access never pre-fill `seen` or `owned`
  Pokédex flags.
- Seeing a research-gated Johto species on an opponent's team no longer
  advertises or activates its habitat before Elm records the specimen.
- Atlas habitats now distinguish caves, buildings and other interiors from
  grass, and label pool/species odds as base chances before temporary
  encounter overrides.
- Atlas odds use the Gen-1-font-safe `PCT`/`PROZ` labels instead of a missing
  percent glyph, with location and chance details split into readable pages.
- Selected Trainer Card titles survive New Game Plus, stale Grand Tour title
  flags self-heal, and localized titles are clipped by glyph rather than byte.

## [4.2.2] - 2026-08-03

### Added

- Renewable level-25 Eevee now replace 2% of Route 7 grass encounters after
  the first Hall of Fame, providing enough copies for all five Kanto/Johto
  branches without trading or relying on random end-game gifts.

### Changed

- EXP.ALL remains unique but now occupies a 5% band in both loot modes.
- Rare Candy now occupies 5% and Nugget 15% in both loot modes. Removed
  probability becomes no drop; no other reward band was increased.

### Fixed

- Johto branch registration now appends to the original evolution list
  instead of replacing it. Gloom retains Vileplume, Poliwhirl retains
  Poliwrath, Eevee retains Vaporeon/Jolteon/Flareon, and Slowpoke retains
  Slowbro while their Generation-II alternatives remain available.

## [4.2.1] - 2026-08-03

### Changed

- Field trainers and post-game bosses now draw each new recovery/training
  period from **151-2510 completed steps** by default.
- The two rest-step options now use the same thematic 151 minimum and 2510
  maximum, with single-step precision.
- Untouched 128/256 settings from older profiles migrate automatically, while
  genuinely customized ranges remain user-controlled.
- Active trainer timers that were created inside the old 1-256-step window
  are safely rerolled once into the expanded range on save load.
- Silent cycles still keep ready trainers available while raising their next
  team after every completed background period.
- The headless suite now covers 1619 checks.

## [4.2.0] - 2026-08-03

### Added

- A self-contained `KANTO 151` option with authored REWARDS, convenience WILD
  and OFF modes. A separate all-catchable mod is no longer required.
- Version-independent habitats for every former Red/Blue/Yellow exclusive,
  renewable Eevee and both Fighting Dojo prize species.
- Level evolutions for Kadabra, Graveler and Haunter at 42 and Machoke at 45.
- Renewable ¥2100 Moon Stones in Pewter Mart and Celadon Department Store 4F.
- Bulbasaur, Squirtle and Charmander prizes from Master Erika, Misty and
  Blaine, with party/PC-full reservation.
- The unchosen Dome or Helix Fossil as a Master Brock prize. Imported saves
  missing both can receive the other from Crown Brock, and full Bags reserve
  the fossil safely.
- A WILD alternative with rare starter, fossil, Aerodactyl and final trade
  evolution encounters.

### Changed

- Mew is explicitly removed from overlapping random encounter patches and
  remains exclusive to Kanto Ascendant's authored event.
- The rematch loot documentation now lists every base band, rank bonus, gate,
  full Legend distribution and true no-drop percentage.
- The headless suite now covers 1614 ROM-free checks plus imported-data Kanto
  encounter, evolution, shop and reward validation.

## [4.1.1] - 2026-08-03

### Changed

- The vanilla Start menu is tidy again: Journal, World Status, Johto Pokédex,
  Shiny Dex, Event Archive, Dex Certificates and Mega Stones now live behind
  one bilingual `ASCENDANT` submenu.
- Every nested entry keeps its original progression gate, and backing out of
  the Ascendant screen returns to the Start menu.
- The headless suite now covers 1610 checks, with German in-engine screenshots
  for both the cleaned Start menu and the fully unlocked submenu.

## [4.1.0] - 2026-08-03

### Added

- A permanent Field Kit awarded after the first won field rematch. It invokes
  CUT, FLY, SURF, STRENGTH and FLASH from the Bag without consuming a Pokémon
  move slot while preserving each original HM and Badge requirement.
- A guaranteed renewable TM archive after the Hall of Fame: every second won
  field rematch awards the next original TM, and all 50 appear before the
  archive cycles.
- A bilingual Move Deleter and TM Archive status page in the Route 5 Day-Care
  machine. HMs may be removed, but a Pokémon's final move is protected.
- TM51 Frenzy Plant / Flora-Statue from Crown Erika, TM52 Blast Burn /
  Lohekanonade from Crown Blaine and TM53 Hydro Cannon / Aquahaubitze from
  Crown Misty. Both matching Kanto and Johto starter families can learn them.

### Fixed

- Independent rematch rewards are now composed without a leading empty reward
  suppressing later Johto or shiny reward messages.
- The headless suite expanded to 1592 checks, plus an in-engine Bag, Field Kit,
  HM deletion, starter compatibility and renewable-TM QA route.

## [4.0.0] - 2026-08-03

### Added

- A repeatable Silver, Kris and Gold Johto Masters gauntlet after the Crown
  Champion. All three use changing six-Pokémon level-100 teams, maximum AI,
  automatic between-round healing and an unconditional battle-item lock.
- Gold awards exactly one uniformly random genuine-DV shiny from all 251
  Pokémon after every clear. Full parties use the PC; a completely full PC
  reserves the already-selected gift without rerolling it.
- The permanent KANTO ASCENDANT title and a golden Trainer Card treatment
  after the first Johto Masters clear.
- Four Pokédex certificates for #001-150, all 151 Kanto species, #001-250 and
  the complete #001-251 roster. Future certificate tiers remain hidden until
  the corresponding collection milestone has actually been reached.
- Four rotating 2048-step world events: Training Rush, Johto Migration,
  Golden Wind and Frontier Festival.
- A unified Start-menu Journal for legendary sightings, live roamer
  locations, titles, type masteries, world events and Johto Masters records.
- Per-species shiny encounter/capture records and optional protection from
  accidental PC release.

### Changed

- Johto and Shiny Pokédex lists now match the original Pokédex presentation:
  unseen entries remain `-----`, seen entries reveal their names and captured
  entries use the Poké Ball marker instead of pre-filled `OWN/HAT` text.
- The Grand Tournament is presented as the Ascendant Battle Frontier and now
  awards persistent Frontier Points, doubled during Frontier Festival.
- Crown Leader victories permanently register eight individual type
  masteries.
- Blue's adaptive boss roster now rotates strong Johto counter-picks as well
  as reacting to the player's dominant party type.
- The headless suite expanded from 1547 to 1574 checks.

## [3.2.0] - 2026-08-03

### Added

- A self-contained Generation-II shiny system for all 251 Pokémon. Shininess
  uses Crystal's real Defense/Speed/Special/Attack DV rule, so no proprietary
  save flag is required and existing virtual shinies migrate automatically.
- A bilingual 251-entry Shiny Dex with separate seen and caught records.
- The Shiny Charm is awarded after all 251 species are owned. It grants two
  additional 1/8192 rolls while Ascendant shiny hunting is enabled.
- Consecutive field-rematch wins add one, three or seven shiny rolls at
  streaks 10, 25 and 50. Every tenth victory also starts a deterministic
  2048-step Johto outbreak with a 25% species replacement rate and fifteen
  additional shiny rolls on its route.
- A guaranteed red Gyarados event in Seafoam Islands B4F after a 25-win
  post-Hall-of-Fame rematch streak. It persists until captured.
- Crystal-accurate egg DV inheritance. A compatible shiny donor can produce
  the authentic 1/64 shiny result; Crystal's matching Defense/Special-DV
  incompatibility rule is retained.
- Built-in battle sparkles, chime, battle marker and status-screen icon. An
  active `shiny_indicators` mod is detected automatically and becomes the
  sole effects provider, preventing doubled audio or animation.
- Official Crystal shiny front/back downloads for all 100 Johto species and
  PokeWilds shiny follower sheets for 99; Unown's follower is generated from
  its Crystal shiny front sprite.
- A scripted 2D/voxel QA driver for Shiny Feraligatr and Shiny Suicune.

### Changed

- The Crystal installer now validates and installs four views per Johto
  species: normal front/back plus shiny front/back.
- The follower bridge now resolves the selected individual, not merely its
  species, so normal and shiny copies of the same Pokémon use the right sheet.
- The same shiny follower art is shared by classic 2D and Dramatic Shape's
  voxel renderer.
- The headless suite expanded from 1525 to 1547 checks.

## [3.1.0] - 2026-08-02

### Added

- Route 5 is now a full two-parent Day-Care. Both deposited Pokémon gain one
  experience point per completed player step and retain the original
  ¥100-plus-¥100-per-level retrieval price.
- Canonical breeding data for National Pokédex entries 1-251: Generation-II
  egg groups, Attack-DV gender ratios, Ditto rules, baby-family resolution,
  species hatch cycles and unbreedable baby/legendary handling.
- Real party eggs. They occupy a party slot, cannot battle or be healed,
  count down only while carried and hatch into a level-5 Pokémon with Pokédex
  ownership and origin metadata.
- Elm's eight research eggs now wait at the Route 5 Day-Care and use the same
  party-egg system. Existing queued research eggs migrate automatically.
- A visible evolution machine inside the Day-Care. It handles every compatible
  item evolution and, after the Hall of Fame, forges the Mega Ring.
- A dedicated Mega Stone Case and 30 individual form-bound stones covering
  exactly the 27 species among #001-251 that officially have Mega Evolutions
  through July 2026. No invented Mega species are included.
- Once-per-battle Mega Evolution, activated with SELECT from the main battle
  menu. Every form has its own five-stat Kanto adaptation; HP and saved party
  stats never change.
- Optional enemy Mega Evolution for post-game bosses or all trainers.
- Four-shade original front/back sprites for Mega Raichu X and Mega Raichu Y.
  Other eligible species retain their normal sprite inside a visible Mega aura.
- A Route 5 form selector for Charizard X/Y, Mewtwo X/Y and Raichu X/Y once
  both matching stones are owned.

### Changed

- Crystal battle sprites now receive edge-connected transparency before use,
  preventing opaque 56x56 background cards in on-map voxel battles. Dramatic
  Shape's front-facing player-side choice is preserved instead of being
  overwritten with the Crystal back view.
- Optional species-accurate Gen-2-style follower sheets now cover all 100
  Johto Pokémon in both 2D and voxel rendering. A local installer downloads
  the PokeWilds art and Kanto silhouettes remain the safe per-species fallback.
- Elm's aide now reports research and egg status while directing item
  evolutions to the visible Route 5 machine.
- Classic stones unlock with the Mega Ring after the first Hall of Fame, new
  Z-A stones after all eight Master Leaders and Mewtwonite X/Y after the Apex
  Champion.
- The headless suite expanded from 1417 to 1525 checks.
- Johto party leaders now fall back to related, existing Kanto follower
  sheets when the optional all-species follower mod only ships Gen-1 art.
  This prevents missing-texture crashes in both 2D and voxel rendering.
- Raikou, Entei and Suicune now use the standard animated quadruped party
  icon; Lugia and Ho-Oh use the standard bird icon; Celebi uses the standard
  Mew-like fairy icon. The old single-frame thumbnails are no longer selected.

## [3.0.0] - 2026-08-02

### Added

- The complete canonical Johto Pokédex from Chikorita #152 through Celebi
  #251: 100 native species records, five-stat balancing, cries, learnsets,
  evolutions, Pokédex entries, icons and distributable sprite fallbacks.
- Dark and Steel types with the Generation-II matchup table. Magnemite and
  Magneton now use their Electric/Steel typing.
- Crunch, Metal Claw, Iron Tail, Shadow Ball, Flame Wheel, Giga Drain, Sludge
  Bomb, Spark and Powder Snow alongside Aeroblast and Sacred Fire.
- Three post-Hall-of-Fame starter trials in Celadon, Cinnabar and Cerulean.
  Each has three themed rounds and awards Chikorita, Cyndaquil or Totodile;
  all three can be earned in one save.
- Elm's persistent Kanto research programme in Oak's Lab. Once all starters
  are secured, every field-rematch victory awards one deterministic,
  class-themed, never-duplicate Johto family.
- Forty rematch specimen families, eight step-hatched baby eggs, fixed
  evolution-item milestones and Larvitar as the final research reward.
- Friendship, day/night Eevee and Tyrogue stat-branch evolution methods.
- Sun Stone, Metal Coat, King's Rock, Dragon Scale and Up-Grade, plus Elm's
  solo evolution machine.
- Eleven version-safe Kanto research partners, including two Eevee, so every
  Johto branch is obtainable in Red, Blue and Yellow.
- A bilingual 100-entry Johto Research Dex in the Start menu with owned/seen
  tracking, exact egg steps and full-PC prize reservation.
- Optional local Pokémon Crystal front/back sprites for all 100 Johto
  species. The installer now validates and downloads 200 views.

### Changed

- Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi keep their save-stable
  species IDs but now use canonical Pokédex numbers 243-245 and 249-251.
- `LEGEND ART` is now the broader `JOHTO ART` option. Missing Crystal pairs
  fall back independently to built-in four-shade silhouettes.
- The headless suite expanded from 1202 to 1417 checks and an imported-data
  smoke test now validates the full 251-species merge.

## [2.1.0] - 2026-08-02

### Added

- Five badge-gated, three-round Heritage Cups awarding faithful Generation-I
  University Magikarp, Pokémon Stamp Fearow, Flying Pikachu, Pokémon Stamp
  Rapidash and Surfing Pikachu builds at their original levels.
- An alternative roaming mode with persistent map, DVs, HP and status,
  optional first-action escape, relocation and three-map knockout recovery.
- A permanent bilingual Event Archive in the Start menu, including source,
  level, original moves, claim status and full-PC prize reservation.
- Event provenance on each obtained Pokémon, an EVENT INFO party entry and an
  optional battle rosette.
- An Ascendant Lv.100 / historical Lv.5 Mew profile choice. Historical Mew
  keeps Pound and the fixed 5/10/1/12/5 event DVs.
- Grand Tournament catch-up prizes for enabled, missed Heritage events.
- SET-Style and Kanto Purist Grand Tournament rules.
- SET, Trio and Purist Ascendant Cycle rules with automatic post-battle
  restoration of the player's saved battle style, HP and status.

### Changed

- Ascendant Cycle Master, Apex, Crown and Rocket teams now always reach level
  100, even when NEW GAME+ RULES is set to NORMAL.
- Adaptive circuit order expanded from three to six deterministic variants.
- NEW GAME+ RULES now defaults to a four-cycle rotation: No Items, SET Style,
  Trio and Kanto Purist. The legacy No-Item-only and unrestricted NORMAL
  presets remain available.
- The Grand Tournament now rotates six rulesets instead of four.
- The headless suite expanded from 1162 to 1202 checks.

## [2.0.0] - 2026-08-02

### Added

- Five persistent trainer ranks: Rookie, Veteran, Expert, Master and Legend.
- Stronger AI, visible overworld markers and new BALANCED bonus-loot bands for
  high-rank field trainers.
- Eight sequential Ascendant research assignments with rare rewards and
  Bag-full reservation.
- Personal bilingual missions for all eight Gym Leaders.
- Leader signature roster variants, rotating boss orders and an adaptive
  Champion counter-pick.
- A repeatable three-round Kanto Grand Tournament with six level-100
  opponents and Open, No-Item, Trio and Endurance rules.
- A four-chapter Rocket Resurgence story across the Power Plant, Silph Co.,
  Pokémon Tower and Viridian Gym.
- Expanded Rocket/Mew world reactions and four one-time environmental scenes.
- A three-clue Oak, Mr. Fuji and Cinnabar investigation ending with a
  persistent level-100 Mew encounter on Route 24.
- A dedicated Mew option plus independent Rocket and Tournament switches;
  disabled systems are removed from completion requirements.
- Fourteen permanent achievements and titles in the Crown Archive.
- A double-confirmed, save-safe Ascendant New Game Plus cycle that preserves
  base-story progress, Pokémon, items, captured legends, titles and tournament
  records.

### Changed

- Master, Apex and Crown repeat battles now rotate team order.
- Completed Leader missions unlock signature roster variants.
- The Champion adapts one non-legendary counter-pick to the player's dominant
  party type.
- The Crown Archive now includes title, research, Tournament, Rocket, Mew and
  cycle records.
- The headless suite expanded from 1080 to 1162 checks.

## [1.1.0] - 2026-08-02

### Added

- Oak's bilingual Research Log in his Lab, with current objectives, circuit
  progress, encounter requirements, caught status and live roamer routes.
- Phase-aware reactions from seven NPCs across Kanto, covering the initial
  rumors, Apex escalation, legendary hunt, Crown Circuit and final victory.
- Unique atmospheric introductions, cries and white-flash transitions for
  all ten legendary encounters.
- A one-time legendary-hunt Rival event after the first legendary capture,
  using a new six-Pokémon, non-legendary level-100 roster.
- A bilingual Crown Archive on the Hall-of-Fame console that records field
  rematches, circuit crests, titles, legendary captures and the Rival event.

### Changed

- Renamed the visible mod from **Trainer Rematch** to **Kanto Ascendant** to
  reflect its full post-game scope. The internal `trainer_rematch` ID remains
  unchanged for save and option compatibility.

## [1.0.10] - 2026-08-02

### Added

- A one-time Professor Oak event scene after the first Champion victory and
  immediately before the Hall of Fame. Oak reports increasing legendary
  sightings, strange shadows, storms and unknown beasts across Kanto.
- Complete English and German versions selected by the existing language
  system. If every legendary encounter is disabled, Oak uses a matching
  non-legendary post-game announcement instead.

### Changed

- Later League clears restore Oak's original invitation, keeping the sighting
  announcement a story event rather than repeatable dialogue.

## [1.0.9] - 2026-08-02

### Changed

- Raised BALANCED rematch loot to Nugget 20%, Rare Candy 15%, PP Up 10%,
  Max Revive 8%, the unique EXP.ALL/EP-Teiler 20%, and Master Ball 1%.
- Reworked GENEROUS into its own richer table: Nugget 26%, Rare Candy 20%,
  PP Up 15%, Max Revive 12%, EXP.ALL/EP-Teiler 25%, and Master Ball 2%.
- Kept all strength and progression requirements unchanged. Once unlocked, a
  Master Ball now takes about 100 BALANCED or 50 GENEROUS eligible victories
  on average instead of roughly 1,000.

## [1.0.8] - 2026-08-02

### Added

- Optional rare item loot after winning field-trainer rematches.
- Balanced drop bands: Nugget 10%, Rare Candy 4%, PP Up 3%, Max Revive 2%,
  the unique EXP.ALL/EP-Teiler 1%, and Master Ball 0.1%.
- Strength gates for valuable loot. EXP.ALL requires an average level-40
  opponent; Master Ball requires average level 80 and the Apex Champion win.
- **REMATCH LOOT / REVANCHEN-BEUTE** with `OFF`, `BALANCED` and `GENEROUS`.
  Generous mode doubles each fixed band.
- Full-Bag protection: the individual trainer reserves a rolled reward and
  delivers it later when room is available.

### Changed

- Removed the artificial +20 field-trainer boost limit. Repeated battles and
  silent training now continue until each enemy Pokémon naturally reaches
  level 100.
- EXP.ALL is treated as a unique reward and uses the engine's existing,
  functional Gen-1 party experience distribution. Its Oak's Aide flag is
  synchronized to prevent a duplicate.
- Master Balls remain repeatable but cannot drop before the legendary hunt.

## [1.0.7] - 2026-08-02

### Added

- All 47 trainer classes now have thematic Pokémon recruitment pools.
- Growing field trainers add another party member at every second strength
  tier until they reach the six-Pokémon limit.
- Recruitment prefers species sharing the original team's types, avoids
  duplicates where possible and is deterministic per individual trainer.
- Recruited evolutionary families advance through their normal level
  evolutions when the projected rematch level is high enough.
- A bilingual **TEAM GROWTH / TEAM-WACHSTUM** option can disable recruitment
  while leaving step cooldowns and level growth active.

### Changed

- Both completed rematches and silent background-training cycles contribute
  toward party recruitment.
- Ordinary field trainers can never recruit legendary Pokémon.
- Strength warnings now preview the expanded party as well as its higher
  levels.

## [1.0.6] - 2026-08-02

### Added

- Ready field trainers now continue training on invisible background counters
  when the player walks past them without accepting a rematch.
- Every fully completed silent counter adds one normal growth tier to that
  trainer's next team: +2 levels with the default setting.
- Silent training is persisted separately from the number of actual rematches,
  so the first real repeat battle is still identified correctly even if its
  team has already grown several times.

### Changed

- Finishing the visible recovery period no longer freezes a trainer's strength.
  The trainer stays continuously battle-ready while subsequent randomized
  128-256-step training cycles run.
- Passive and battle-earned growth share the existing +20 and level-100 caps.
- Older saves start their first silent cycle when loaded or next inspected;
  they are not granted speculative levels for time that was never tracked.

## [1.0.5] - 2026-08-02

### Added

- Character-specific Master and Crown dialogue sets for Brock, Misty,
  Lt. Surge, Erika, Koga, Sabrina, Blaine and Giovanni.
- Each circuit Leader now has a personal challenge, rejection reaction,
  exact-step recovery line, defeat quote and story-progression hint in both
  English and German.
- Separate Apex and Crown scenes for Lorelei, Bruno, Agatha, Lance and the
  Champion, including new pre-battle, in-battle defeat and post-battle text.

### Changed

- Circuit dialogue now reflects the boss's team and personality, including
  Suicune with Misty, Raikou with Lt. Surge, Celebi with Erika, Lugia with
  Sabrina, Entei with Blaine, and Lugia plus Ho-Oh with Lance.
- If one of those legends is disabled in OPTIONS, the affected boss uses an
  alternate line that matches the non-legendary replacement team.
- The ordinary first Elite Four and Champion story clear still uses the
  original game or translation-mod dialogue; new scenes activate only in the
  Apex and Crown circuits.

## [1.0.4] - 2026-08-02

### Added

- Complete English and German variants for all mod-owned trainer challenges,
  rejection reactions, strength warnings, cooldown reports, boss prompts and
  legendary messages.
- Automatic German text detection for `deutsch`, `deutsch-blau` and
  `deutsch-gelb`, with optional dependency ordering so the matching
  translation loads first when installed.
- A **LANGUAGE** option with `AUTO`, `ENGLISH` and `DEUTSCH` overrides.

### Changed

- A resting field trainer now says its normal post-battle line as a second
  page after reporting the exact remaining steps.
- Mod-option labels are German when a matching German translation is detected
  during loading.

## [1.0.3] - 2026-08-02

### Added

- Individual legendary encounter controls in the mod's **OPTIONS** submenu.
  Articuno, Zapdos, Moltres and Mewtwo each offer `APEX`, `VANILLA` and
  `OFF`; every added Johto legend has its own `ON/OFF` toggle.
- `VANILLA` restores the original availability and level for a Kanto static
  legend: level 50 for each bird and level 70 for Mewtwo.
- Disabling a legend removes its encounter and catch requirement. Any copy
  used by a Crown boss is replaced with a suitable non-legendary Pokémon.

### Fixed

- A defeated trainer with no existing mod record now starts a recovery period
  lazily when spoken to instead of skipping directly to an immediate rematch.
- Previously defeated Master Leaders now report their exact remaining steps
  and become repeatable when their recovery period ends.

## [1.0.2] - 2026-08-02

### Added

- Visible Raikou, Entei and Suicune sightings on each beast's current roaming
  route. Talking to the overworld Pokémon starts the same level-85 encounter;
  the existing random grass encounter remains available too.

### Changed

- Overworld appearances now reuse the game's standard sprite sheets:
  `SPRITE_MONSTER` for the three beasts, `SPRITE_BIRD` for Lugia and Ho-Oh,
  and `SPRITE_FAIRY` for Celebi.

## [1.0.1] - 2026-08-02

### Added

- Optional Pokémon Crystal front/back battle sprites for all six added
  species, installed locally from Pokémon Database with
  `tools/install_crystal_sprites.py`.
- A **LEGEND ART** option for switching between local Crystal art and the
  original distributable four-shade sprites.
- Automatic fallback to the original sprites when the local Crystal pack is
  incomplete or absent.

### Changed

- Crystal art is now the preferred local style. Copyrighted game sprites are
  excluded from source and release ZIPs; the installer downloads them only for
  the user's personal installation.

## [1.0.0] - 2026-08-02

### Added

- A five-stage Hall-of-Fame progression: eight Master Gym Leaders, the Apex
  Elite Four and Champion, a gated legendary hunt, eight level-100 Crown Gym
  battles, and a final level-100 Crown Elite Four.
- Six-Pokémon fixed-move boss rosters for every Master, Apex and Crown battle.
- Legendary progression gates: all legendary battles stay sealed until the
  Apex Champion; the birds unlock Lugia, the roaming beasts unlock Ho-Oh, and
  Lugia plus Ho-Oh unlock the Crown Circuit.
- Level-80 Articuno/Zapdos/Moltres, level-90 Mewtwo, roaming level-85 Raikou,
  Entei and Suicune, level-95 Lugia/Ho-Oh, and a secret level-90 Celebi.
- Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi as full custom species,
  including stats, learnsets, Pokédex data, cries, front/back sprites and
  party icons.
- Aeroblast and Sacred Fire.
- Original, reproducible four-shade pixel assets and an asset generation tool.
- Recovery for old vanilla static legends hidden by a KO or flee when they
  have not actually been caught.
- 302-check headless coverage for field rematches, progression gates and every
  boss roster.

### Changed

- Scripted Gym Leaders now enter the post-game rematch flow after the first
  Hall of Fame; Giovanni returns to Viridian Gym.
- All Master, Apex and Crown battles are marked as rematches and pay no money.
- Static legendary encounters disappear permanently only after capture.

## [0.4.0] - 2026-08-02

### Added

- Per-trainer recovery periods: the first rematch and every later rematch
  require a random 128-256 completed player steps by default.
- Resting trainers report the exact number of steps still required.
- Progressive rematch teams: +2 levels on the first rematch, another +2
  after each completed rematch, capped at +20 and Pokémon level 100.
- Persistent, per-save trainer rest and growth state in
  `save.modData.trainer_rematch`.
- Mod-manager options for the minimum/maximum rest steps and level gain.

### Changed

- The strength-gap warning now measures the actually boosted rematch team.

## [0.3.0] - 2026-08-01

### Added

- Strength warning: when the rematch team averages more than 10 levels
  above the player's party, the trainer warns in its own voice ("My team
  is far stronger than yours...") and asks a second time before the battle
  starts.  Declining walks away with the class's usual decline line.

## [0.2.0] - 2026-08-01

### Added

- A trainer record may mark a dedicated rematch team via `rematchIndex`
  (Yellow Legacy Changes 1.6.0+ ships the hack's gym-leader, Elite Four
  and Champion rematch teams this way); the rematch battle then uses that
  team instead of the trainer's own.  Without a marker, behavior is
  unchanged.

## [0.1.0] - 2026-08-01

### Added

- Rematch prompt when talking to a defeated field trainer (YES/NO).
- Per-trainer-class rematch dialogue in the class's own voice.
- Per-trainer-class decline reaction: mocking for cocky classes, understanding for wise ones.
- No money rewards for rematch battles (trainer prize and Pay Day suppressed).
- The trainer's vanilla post-battle dialogue follows the decline reaction.
