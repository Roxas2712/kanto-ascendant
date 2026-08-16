# Character asset matrix — Phases 3–4

“Development fallback” is visible resolver metadata
(`status = "dev-fallback"`) and is not an approval to ship the route as
visually complete.

## Character / role matrix

| Player choice | Player | Rival | Third | Rival battle role | Starter / party source |
|---|---|---|---|---|---|
| Red | Red (male) | Blue (male) | Green | `OPP_RIVAL1..3` | existing role-based counter-pick and stage tables |
| Blue | Blue (male) | Green (female) | Red | `OPP_RIVAL1..3` | unchanged existing role-based counter-pick and stage tables |
| Green | Green (female) | Red (male) | Blue | `OPP_RIVAL1..3` | unchanged existing role-based counter-pick and stage tables |

`save.player.name` and `save.player.rival` remain free-form names.  They are
not IDs: battle text retains the engine’s custom-rival-name overlay, while
this matrix supplies only identity, gender and art.

## Player state matrix

The table below remains the optional **ASCENDANT CHARS** Gen-I family.
**CRYSTAL CHARS** is the default, atomic family; switching styles never
replaces or mutates either asset set.

| State | Red | Blue | Green |
|---|---|---|---|
| overworld frames | `SPRITE_RED` — final | `SPRITE_BLUE` — final | `SPRITE_KA_GREEN` — final, exact Felix Jones six-frame sheet |
| bike | `SPRITE_RED_BIKE` — final | Red bike — development fallback | Red bike — development fallback |
| surf | `SPRITE_SEEL` shared mount — final | same shared mount | same shared mount |
| fishing | Red overlay set — final | Red overlays — development fallback | Red overlays — development fallback |
| battle back | derived `characters/red_back.png` — final | `blue_back.png` — final 32×32 adaptation of MegaBlueAce's first rear pose | `green_back.png` — final 32×32 in 2D; Voxel battle uses the separate 56×56 standing Casey front |
| Oak / selector / Trainer Card / Hall of Fame | derived `characters/red_front.png` — final | derived Blue rival front — final 56×56 | `green_front.png` — final 56×56 Casey trainer portrait from the final `progress.gif` frame; independent of the walker |
| credits / special scenes | shared player-front resolver — final | Blue front — final | Green front — final |

### Default CRYSTAL CHARS family

The user-reviewed native Walking masters and their frame contract are frozen
under `assets/sources/characters/crystal_chars/approved_walk/`. See
`CHARACTER_ASSET_AUTHORING_DE.md` for the exact Red, Blue and Green/Casey
design decisions and the proposed safe Character Tool workflow. The asset
builder copies these masters byte-for-byte; it must not recreate them through
automatic reduction or broad palette replacement.

| State | Red | Blue | Green / Casey |
|---|---|---|---|
| overworld | custom six-frame 16×16 Gen-I geometry | custom six-frame 16×16 Gen-I geometry | custom six-frame 16×16, approved long-hair silhouette |
| bicycle | custom six-frame 16×16 Gen-I geometry | custom six-frame 16×16 Gen-I geometry | custom six-frame 16×16 Gen-I geometry |
| fishing | custom six-frame 16×16 body plus engine rod | custom six-frame 16×16 body plus engine rod | custom six-frame 16×16 body plus engine rod |
| 2D battle front | ROM-derived native Gen-I Red fallback | custom KASC Blue adaptation | custom hard-reduced 64×64 manga-oriented Casey |
| Voxel standing card | custom 128×128 HD Red on a 320×288 billboard | custom 128×128 HD Blue on a 320×288 billboard | custom 128×128 HD Casey on a 320×288 billboard |
| 2D battle back / throw | five custom native 64×64 FRLG-style upper-body frames | five custom native 64×64 FRLG-style upper-body frames | five custom native 64×64 FRLG-style upper-body frames |
| intro / selector / card / Hall of Fame / credits | custom front resolver | custom front resolver | custom front resolver |

All three rows were authored as one shared pixel-art set. `character_sprite_style`
defaults to `crystal`; selecting `ascendant` restores the Gen-I alternative,
while Crystal refreshes the live player, bicycle,
fishing pose, rival NPC, battle/card portrait paths and all 42 used Kanto
opponent classes together. Compact opponent fronts use the edition-original
Gen-I art; KASC's own Voxel pairs remain the optional 3D presentation. The
identity-aware Red/Blue/Casey rival remains the final override. Surf remains
the character-neutral shared mount. Every field state keeps the engine's native
six-frame 16×96 sheet contract, so collision cells, Voxel billboards and map
event positions need no special renderer path.

The 2D back sequence is deliberately not reused by Voxel. Dramatic Shape gets
the full front picture for all three identities and mirrors the player-side
card around its own anchor, so player and opponent face each other. Dedicated
128×128 sources are rasterized into a 320×288 trainer-only texture while the
original Game Boy anchors and world dimensions stay unchanged. This preserves
twice the facial detail and a transparent six-pixel floor gap under the shoes.

The Oak shrink’s final walking sheet is refreshed from the central resolver
when a character is chosen.  The two intermediate shrink frames remain
explicit Red development fallback frames for Blue and Green; no separate
character shrink art exists yet.

Dramatic Shape compatibility is intentionally battle-only: while its Voxel
pipeline is active, a Green player's `side="back", kind="battle"` request
resolves through `green_voxel_front.png` plus its HD billboard source.
`SPRITE_KA_GREEN` remains 16×96 in both flat and
Voxel overworld rendering; its dimensions and hash are asserted before the
real Voxel battle screenshot is taken.

## Rival presentation matrix

| Rival identity | Map walker | Battle portrait | Status |
|---|---|---|---|
| Blue | `SPRITE_BLUE` | derived `characters/blue_rival.png` | final existing rival art |
| Green | `SPRITE_KA_GREEN` | `assets/characters/crystal_chars/green_front.png` | final clean 64×64 Casey battle art |
| Red | `SPRITE_RED` | derived `characters/red_front.png` | final existing player art |

The compact 56×56 Gen-I `assets/characters/green_front.png` remains available
for card/credits consumers. Live rival battles deliberately use the cleaner
colored 64×64 Casey front from the Crystal character set in both character
styles; walking, battle back and throw assets are independent and unchanged.

The implementation changes live NPC renderers rather than map object IDs,
so triggers and flags keep their imported identity.  It changes the runtime
`pic` for the `OPP_RIVAL*` role only; it does not replace party definitions,
starter selection or Yellow’s `rivalStarter` flow.

## Required art handoff before release

1. Blue: original 16×96 bike sheet, fishing overlays and matching
   title/shrink treatment.
2. Green: original bike sheet, fishing overlays and title/shrink treatment.
3. Capture and approve Red, Blue and Green flows for Oak, overworld, bike,
   surf, fishing, trainer battle, Trainer Card, Hall of Fame and credits.
4. Yellow-specific Blue/Green player art listed below must be completed and
   visually approved before release.

## Phase 4 — Yellow integration

Yellow gameplay and character identity are now deliberately separate:

| Concern | Owner | Phase-4 behavior |
|---|---|---|
| player starter / follower | Yellow role and party (`PIKACHU`) | unchanged for Red, Blue and Green players |
| follower reactions / happiness | `PikachuFollower` and `save.pikachu*` | unchanged; never keyed from trainer character |
| rival Eevee and evolution path | Yellow role and `save.rivalStarter` | unchanged; never stored in character state |
| rival battles | `OPP_RIVAL1..3` plus Yellow party table | unchanged IDs/stages; portrait and map walker follow `rival_character` |
| starter/Oak/cutscenes | shared Yellow scripts | one shared script path; character resolver supplies presentation only |

The required Oak Speech selection refreshes its live game immediately, so
Yellow New Game receives the selected player walker and rival portrait before
the first map-enter cycle.  The regular player-sprite hook now also covers
Yellow battle back, intro, Trainer Card, Hall of Fame, credits and special
front-picture consumers. Legacy Yellow saves without character state stay on
their vanilla presentation.

### Yellow visual gaps

| Yellow surface | Red | Blue | Green |
|---|---|---|---|
| player overworld / Oak shrink endpoint | final Red baseline | `SPRITE_BLUE` final walk; bike/fishing still Red fallback | `SPRITE_COOLTRAINER_F` development fallback |
| starter Pikachu and follower | authentic Yellow system, character-neutral | same | same |
| battle/intro/card/HoF/credits | derived Red baseline | Red portrait/back development fallback | Red portrait/back development fallback |
| rival walker / portrait | Blue existing art | Green development fallback | Red development fallback |

There is no separate character-specific Yellow player sheet in the currently
available assets.  The Pikachu follower is intentionally not substituted: it
is the Yellow starter Pokémon, not an avatar for Red, Blue or Green.

## Phase 5 — Review-A corrections

The selection retains a strict no-op presentation path for legacy/rollback state:
the engine's player, map-rival and `OPP_RIVAL*` portrait values are not
overridden on a vanilla/legacy save, and captured values are restored if a
selection is turned off.  This preserves the Phase-4 Yellow promise without
touching Pikachu, `rivalStarter`, parties or progression.

Front-facing consumers now select their own declared visual state
(`trainerCard`, `hallOfFame`, `credits`, `intro`, `special`) instead of being
collapsed into the generic `front` state. The currently shipped values remain
the same where the matrix names a Red fallback, but future art can now be
supplied without another routing change.

The user-supplied Green concept is preserved at
`assets/sources/characters/green_reference_phase5.png` (1254×1254 RGB). It
shows the desired Green silhouette and directional-walk concept, but is a
magenta-key composite and not an engine-ready production sprite sheet. It is
source-only and does not change the explicit Green runtime fallback status.

## Phase 8 release classification

The Phase-8 final review retains this matrix's history and classifies its
current assets as follows:

- **FINAL / RELEASE READY:** all routed Red surfaces; Blue's overworld,
  front, back and rival art; Green's 16×96 walker and standard 2D front/back.
- **CRYSTAL CHARS:** ROM-derived native Gen-I Red front, KASC Blue/Casey
  fronts, custom five-frame upper-body throws for all three identities and
  separate HD Voxel standing pictures. Field sprites remain on native 16×16
  sheets.
- **ATTRIBUTION / PERMISSION GATE:** Green follows Felix Jones' Pokémon Green
  work; see `green_sprite_credit.md` before public redistribution.
- **ORIGINAL MODEL-PACK ART:** Blue and Casey's optional Crystal battle-back
  sequences are project-owned FRLG-style adaptations; `blue_back_credit.md`
  records why Blue cannot use an official source back.
- **FALLBACK:** Blue/Green bike, fishing and intermediate Oak-shrink frames
  remain deliberate shared Red baselines.
- **MISSING:** dedicated Blue/Green Yellow surfaces and production assets for
  every fallback row.

Consequently the resolver is integration-ready, but this **is not a
release-ready character-art package** until the listed runtime formats are
authored, installed and visually approved.
