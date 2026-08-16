# Character asset inventory — Phases 1–3

## Method and scope

This inventory records known, loadable assets from the accompanying Gen1
Recomp checkout at `../../gen1recomp`.  Kanto Ascendant 6.5.0 currently ships
no player-character art override of its own.  PNG dimensions are source-image
dimensions; the renderer applies Gen-I tile/palette handling.  “Missing” means
not present in the checked-out generated asset set, not that art can never be
authored later.

## Engine loading paths

| Visual state | Resolver / loader | Current default |
|---|---|---|
| overworld walk and directional frames | `src/world/Player.lua` → `data.field.playerSprites.walk` → `data.sprites` | `SPRITE_RED` |
| bike | same, `playerSprites.bike` | `SPRITE_RED_BIKE` |
| surf | same, `playerSprites.surf` | `SPRITE_SEEL` mount; no human player sheet selected |
| fishing pose tiles | `Player.lua` → `data.field.overworldFx.redFish*` | Red-only overlay tiles |
| flying | `playerSprites.fly` | `SPRITE_BIRD` mount |
| battle back | `Sprites.playerPath(..., "back")` | `field.playerPics.back` |
| Oak intro, Trainer Card, Hall of Fame | `Sprites.playerPath(..., "front")` | the shared `field.playerPics.front` |
| Oak shrink endpoint | `src/ui/OakSpeech.lua` directly requests `SPRITE_RED` | hard coupling requiring a resolver |
| rival overworld | map-object `sprite` in `data/generated/maps.lua` | `SPRITE_BLUE` |
| rival battle art | `data.generated.trainers[OPP_RIVAL*].pic` | RIVAL1/2/3 portraits |

`SPRITE_RED`, `SPRITE_BLUE` and `SPRITE_DAISY` are six-frame 16×96 RGBA
walking sheets in the generated cache.  Frame/direction semantics belong to
the shared `SpriteRenderer`; each sheet must retain that layout.

## Red

| State | Asset | Dimensions / constraints | Completeness |
|---|---|---|---|
| overworld standing/walk, down/up/left/right frames | `assets/generated/sprites/red.png` (`SPRITE_RED`) | 16×96; six-frame walker | present |
| bicycle | `assets/generated/sprites/red_bike.png` (`SPRITE_RED_BIKE`) | 16×96; six-frame walker | present |
| surf | no separate Red sheet; the engine uses `SPRITE_SEEL` | mount logic, not interchangeable player art | functional vanilla presentation only |
| fishing, down/up/side | `assets/generated/fx/red_fish_front.png`, `red_fish_back.png`, `red_fish_side.png` | each 16×8 overlay tiles | present |
| battle backsprite | `assets/generated/battle/redb.png` | 32×32 | present |
| Oak intro / Trainer Card / Hall of Fame front | `assets/generated/trainer_card/red.png` | 56×56; one shared player-front resolver | present |
| title player art | `assets/generated/title/player.png` | 40×56 | present; title-specific path |
| intro shrink frames | `assets/generated/intro/shrink1.png`, `shrink2.png` | used by Oak Speech, not character-resolved | Red-oriented shared animation |
| credits/special | Hall of Fame is covered by the front resolver; no separate per-character credits art was found | — | no extra Red-specific asset required by current renderer |

## Blue

| State | Asset | Dimensions / constraints | Completeness |
|---|---|---|---|
| overworld standing/walk, down/up/left/right frames | `assets/generated/sprites/blue.png` (`SPRITE_BLUE`) | 16×96; six-frame walker | present as rival/NPC art |
| rival battle portraits | `assets/generated/battle/trainers/rival1.png`, `rival2.png`, `rival3.png` | each 56×56; trainer-class art, not a player front/back API | present |
| player bike | no `blue_bike` sheet found | must keep 16×96 six-frame layout | missing |
| player surf/fishing | no Blue human surf/fishing overlays found | surf is mount-based; fishing needs directional overlays or a defined Red fallback | missing |
| player battle back | no Blue back picture found | player API expects a 32×32 path | missing |
| Oak intro / Trainer Card / Hall of Fame front | no Blue player-front picture found | player API expects shared 56×56 front path | missing |
| title / shrink / credits special art | no Blue-specific source found | title and shrink are separate consumers | missing |

## Green

| State | Asset | Dimensions / constraints | Completeness |
|---|---|---|---|
| overworld walk/bike/surf/fishing | no Green sheet or overlays found in Kanto Ascendant or the engine generated cache | walk/bike need the 16×96 six-frame layout | missing |
| battle back | no Green asset found | 32×32 player back expectation | missing |
| intro/card/Hall-of-Fame front | no Green asset found | 56×56 shared front expectation | missing |
| title, shrink, credits and special scenes | no Green asset found | separate title/Oak/credits consumers | missing |

## Yellow-specific assets and rules

Yellow's distinctive visual/gameplay content is implemented in
`data/scripts/oaks_lab_yellow.lua`, `src/world/PikachuFollower.lua`,
`data/palettes_yellow.lua` and the selected Yellow ROM-derived data.  No
separate Red/Blue/Green character-sheet family is present in this checkout.
The Pikachu follower's art is partner-Pokémon art, not player-character art.

## Asset acceptance constraints for a later visual phase

* Preserve the 16×96 six-frame walker geometry for an overworld player/NPC
  replacement and retain the expected sprite tile/palette behavior.
* Supply a 32×32 player back and a 56×56 player front for every selectable
  character.  The front is reused by Oak, Trainer Card and Hall of Fame.
* Treat bike, fishing and the Oak shrink transition as individual render
  consumers; changing only the walking sheet leaves obvious Red leakage.
* Do not reuse `OPP_RIVAL*` battle portraits as player backs.  They are
  opponent trainer art and resolve through a different path.
* Before enabling Green, capture all Red/Blue/Yellow modes, battle, card,
  Hall-of-Fame, bike, surf, fishing and the Oak intro with fallback behavior
  documented for every deliberately missing state.

## Phase 3 implementation status

The Phase-3 resolver in `extended_characters.lua` now owns player/rival art
selection by character identity.  Player fronts and backs use the live
`player.sprite` seam; overworld sheets are installed on the live player and
the existing rival map objects after map entry.  `OPP_RIVAL1..3` keep their
normal starter counter-pick, party stage and event flags; only their runtime
portrait is selected from `rival_character`.  Custom rival names continue to
come from `save.player.rival` in the engine role overlay.

| Character | Usable now | Explicit development fallback | Release status |
|---|---|---|---|
| Red | full existing Gen-I player set; surf mount is shared | Red front is also a temporary Red-rival portrait | playable baseline |
| Blue | `SPRITE_BLUE` walking sheet and the existing Blue rival portrait | Red bike/fishing/back/front/card/HoF/credits art | not art-complete |
| Green | `SPRITE_COOLTRAINER_F` walk sheet and `cooltrainerf.png` portrait stand in during development | Red bike/fishing/back/front/card/HoF/credits art | **not release-ready** |

`assets/sources/characters/green_gen1_concept_v1.png` is a 1254×1254
chroma-key concept/reference sheet produced for the next art pass.  It is
not a runtime asset and must not be shipped as a generated sprite sheet.
Green still needs original, reviewed 16×96 walk/bike sheets, 16×8 fishing
overlays, a 32×32 battle back and 56×56 player/rival fronts.  Blue needs the
same player-only states except for the already usable walk sheet.
