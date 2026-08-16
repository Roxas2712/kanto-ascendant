# Mega and Ascendant Form Pipeline

This document preserves the implementation and QA lessons learned while
building Kanto Ascendant's official Mega forms and Ascendant Typhlosion. Use
it as the checklist for every future battle form.

## 1. Form policy

- Keep released Mega Evolutions in the official Stone Case catalog.
- Keep fan-made forms explicitly labelled and exported separately.
- Give every selectable X/Y form its own item, profile and preference entry.
- A battle may transform only once per side.
- Transformations last for the battle and must not rewrite the stored Pokémon.
- HP does not receive Mega points. The four Gen-I non-HP stats share a
  +100 base-stat-equivalent budget.
- Gen-I computes the runtime increase as
  `floor(2 * formBonus * level / 100)` per stat. A +100 profile therefore
  adds about 100 displayed points at level 50 or 200 at level 100.
- Type changes are battle-local and must be restored during cleanup.

## 2. Source and runtime art

Each form needs all four approved masters:

1. front normal;
2. front shiny;
3. back normal;
4. back shiny.

The current masters live in `assets/mega/` and use a 96×96 transparent
canvas. Never generate a back by blindly mirroring a front: it needs a real
player-facing pose.

The installation pipeline creates:

- sharp Crystal-style runtime fronts in `assets/mega_runtime/`;
- large 90×84 player backs in `assets/mega_runtime/`;
- static four-shade Red/Blue/Yellow-compatible cards in
  `assets/mega_gen1_runtime/`;
- side-aware animation frames in
  `assets/mega_animated/<form>/<front|back>/<normal|shiny>/`;
- matching optimized live frames in `assets/mega_animated_runtime/`.

Use nearest-neighbour sampling for pixel art. Do not enlarge a low-resolution
runtime card to produce a master; always reduce from the best approved source.

## 3. Animation

- Front and back animation trees are independent.
- Normal and shiny loops must have the same silhouette timing.
- Preserve integer-pixel motion; never use fractional resize or rotation in
  the runtime loop.
- Build movement around a recognizable idle pose. Effects may expand behind
  the body but must not replace or obscure the silhouette.
- Crystal-derived forms should inherit the base species' characteristic
  movement where possible. Ascendant Typhlosion, for example, merges the
  accepted armor with Crystal #157's flame timing.
- Record every frame duration in `mega_animation_data.lua`.
- A static fallback must remain available whenever Crystal animation is off.

<details>
<summary><strong>⚠️ FULL SPOILERS — three authored Legacy Mega forms</strong></summary>

### Locally authored derivative exception

Mega Blaziken, Mega Swampert and Mega Sceptile retain the four supplied,
independent static masters as their Voxel source and their Crystal-off/Gen-I
fallback source. Their Crystal-on movement is a separate local fan-project
derivative in `assets/mega_animated/`, made from each matching front/back
normal/shiny master by `tools/build_hoenn_mega_animation_frames.py`. It has
five recorded integer-pixel keys per view and is neither mirrored nor padded
with a duplicate dummy frame. `HOENN_MEGA_DERIVATIVE_SHA256.txt` records every
derived frame hash.

These frames are local derived fan-project graphics; they are **not** claimed
to be official artwork or freely licensed/redistributable. The source masters
remain attributed to the locally supplied pinned `PokeAPI/sprites` package.
Do not replace this provenance statement with a free-license claim. The
runtime uses the derivatives only when Crystal animation is enabled; Voxel
continues to read the approved static master directly.

</details>

## 4. 2D layout rules

- Enemy forms use the front drawing and face the player.
- Player forms use the back drawing and face the opponent.
- Never rotate a front drawing to fake a back.
- The original command panel is an opaque UI layer. No monster pixel may be
  visible inside its empty left pane.
- The name, level, HP label, bar and values must be repainted above the
  player sprite.
- Large backs fill the arena above the command panel; they do not continue
  through it.
- Every form needs an individual horizontal back anchor. One global position
  does not work for wings, tails, long heads and asymmetric poses.
- Derive the initial anchor from the union of every normal back-animation
  frame, then visually inspect it. Keep important facial and shoulder detail
  left of the HP HUD.
- Apply the same anchor to normal, shiny and all animated frames.

Current individual anchors are maintained in `mega_evolution.lua`. Mega
Feraligatr deliberately uses a stronger left shift than the geometric optimum
because its broad head is the important readability feature.

## 5. Voxel layout rules

- Dramatic Shape presents both battlers toward the camera, so Voxel uses the
  approved front drawing for both sides.
- Do not feed Voxel a card that has already been reduced for the 160×144 2D
  frame. Kanto Ascendant draws the 96px master directly into a supersampled
  230×207 side texture.
- Preserve the authored Crystal palette when Crystal art is enabled.
- Apply the active Red, Blue or Yellow four-shade monster palette to the
  Gen-I fallback.
- Confirm that the Voxel texture records the approved master source and does
  not fall back to the base species.

## 6. Sprite ownership and compatibility

- Mega ownership resolves after ordinary and external Crystal sprite hooks.
- A transformed Pokémon must never fall back to its ordinary form because a
  lower-priority art mod claimed the species.
- Turning Crystal animation off must stop the animation state and select the
  four-shade static derivative.
- Shiny selection is independent for front, back, Crystal and Gen-I modes.
- Party and overworld follower art remain species art unless a future form
  explicitly receives persistent field representation.

## 7. Adding a future form

1. Decide whether the form is official or an explicitly labelled fan form.
2. Confirm that its base species exists in the installed Pokédex.
3. Confirm that every requested battle type is registered with a complete
   matchup chart.
4. Add the profile, stat budget, battle-local types, unlock condition and
   item/relic.
5. Produce four 96×96 approved masters.
6. Build sharp front/back runtime cards and four-shade fallbacks.
7. Produce independent front/back normal/shiny animation loops.
8. Add animation timing data.
9. Add an individual 2D back anchor.
10. Test the form as player and opponent in 2D and Voxel.
11. Repeat with shiny art, Crystal animation off and Red/Blue/Yellow palettes.
12. Confirm the left command pane is empty and the player HUD is readable.
13. Run the headless suite, reachability audit, upgrade matrix and strict
    ModKit validation.
14. Only package art whose creator and redistribution terms are documented.

## 8. QA artifacts and tools

- `tools/mega_crystal_qa_driver.lua`: real 2D/Voxel battle capture.
- `tools/capture_all_mega_ingame.sh`: complete form capture loop.
- `tools/build_mega_screenshot_gallery.py`: 2D, Voxel or combined review sheet.
- `tools/install_all_mega_sprites.py`: installs prepared form art.
- `tools/build_mega_runtime_assets.py`: builds runtime derivatives.
- `tests/trainer_rematch_test.lua`: asset ownership, animation and gameplay.

The final 2D rear-view audit for all 30 official forms plus Ascendant
Typhlosion is stored outside the package at
einem vollständigen privaten 2D-Galerielauf geprüft.
