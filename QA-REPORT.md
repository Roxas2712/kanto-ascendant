# Public release verification — 29 September 2026

Source: sealed complete RC11 candidates, the five-file native Recompiler startup hotfix, and the Game Corner seat recovery correction. Personal saves/options are excluded from the archives.

## Game Corner (VASC)
- Reproduced the orphan-seat case before the fix: directional input left the player at (2,11).
- Native LOVE 11.5 test: 28 unoccupied arcade seats; ordinary B exit and all six orphan departure inputs (four directions, B, Start) return to the valid adjacent aisle. Neighbor stools remain blocked.
- Actual slot prompt entered and declined; actual slot minigame entered and quit before betting; player leaves into the aisle and coins remain unchanged.
- Lua regressions cover ownership through scripts/input locks, occupied exits, recovery and retry, map/mode cleanup, NPC ownership and 15,360 seat contact-plane combinations.

## Startup
- Final-source native matrix: Red/KASC, Blue/VASC, Yellow/both, Gold/both, Silver/VASC and Crystal/KASC. Each covers New Game and Continue, exactly one shared intro, native introduction ownership, readiness before reveal and no hidden player movement.
- Prior native Recompiler 0.2.22 test on the user's Mac: largest observed startup gap fell from 7.133 s to 0.838 s; wardrobe cache reuse avoided the repeated composition. Pikachu, Eevee, rotating balls and Mew visibly progressed. Existing save-validation acknowledgement and world reveal were checked; save contents were unchanged.
- Startup lifecycle tests cover shared ownership, adoption once, readiness, cleanup, failures and a simulated seven-second stall without skipping animation. Authored wardrobe cache test: cold 3.120 s, warm 0.0009 s, with key invalidation coverage.
- ContinuePreparation and wardrobe-card regressions pass.

## Packaging
All packaged Lua files compile against the target Lua 5.1 runtime. ZIP CRC, exact source equality, unique archive paths and content receipts are verified. Explicit .modkit/ directory entries support launcher metadata writes. VASC prepared/binary model and terrain source hashes are verified; removed HD assets match the optional DLC payload.

## Limits
The six-version runtime matrix uses desktop LOVE, not physical mobile hardware. A new outfit can still incur its first synchronous composition, and native restore/GPU upload stalls remain possible. Existing RC rooftop/performance tests are retained as historical evidence, not repeated universal FPS benchmarks. No claim of constant 60 FPS, fully stall-free loading or complete external-mod compatibility.
