# Gen-IV--VII starter animation source

`SHOWDOWN-SOURCE-MANIFEST.json` pins PokeAPI/sprites commit
`c10459b9b0129eaca5c5d9b1cac65336debb1d08`, whose `other/showdown` tree
credits the Smogon community. All 36 registered starter-family species have
animated normal/Shiny fronts and backs: 144 GIFs and 6,465 frames.

The GIF files deliberately remain `SOURCE_CANDIDATE_NOT_RUNTIME` and are
package-excluded: LÖVE does not decode them directly. The deterministic
`tools/install_showdown_starter_runtime.py` projection materializes their
6,465 RGBA frames under `assets/crystal_animated`, publishes exact clocks in
`starter_animation_data.lua`, and seals every output in
`animated_runtime/RUNTIME-MANIFEST.json`. Those generated PNGs are the live
runtime surfaces; the existing static 96×96 art remains a damaged-install
fallback.

Run `tests/showdown_starter_animation_source_67_test.py` for source coverage
and `tests/starter_runtime_animation_67_test.py` for the live 36×4 runtime,
clock, frame-byte and package-boundary contract.
