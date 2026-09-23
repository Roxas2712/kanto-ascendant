## KASC 6.7.19 — Hunting Club and wardrobe (1/3)

Public test release, published as a regular GitHub release. Recommended pairing: VASC 3.0.37. These notes cover changes since KASC 6.7.18.

- Integrated the PKMN Hunting Club: 120 one-time contracts available after the eighth badge, requests involving up to three Pokemon, generation-aware requirements, Club Points, rare items, outfits and shiny eggs.
- Integrated a separate wardrobe Card with a home cabinet, outfit previews and per-character ownership. Only the current character's wardrobe is shown: Red cannot turn into Blue or Green by changing clothes.
- Club outfits unlock complete sets; their clothing and accessory parts can then be combined individually. Club sets cost 100 CP after ten completed contracts. Rewards belonging to other characters cannot be purchased for the current character.
- Champion clothing is awarded for that character's League/Hall of Fame victory. Existing victories are credited retroactively without another Elite Four clear or Club visit. Blue/Green need their own NG+ League victory; one character's win does not unlock everyone else's Champion outfit.
- The Champion reward unlocks its own set and parts, not the entire wardrobe. Other sets retain their individual Club reward requirements.
- Caps, reversed caps, glasses and sunglasses are exposed through their corresponding unlocked sets. Existing purchases receive the matching accessories retroactively without paying again.
- Switching HD, Voxel or native presentation preserves the selected clothing. Champion colors, collars, bags, trousers, shoes and fishing-pose overlays have been aligned more closely while retaining each style's own artwork.
- Club and wardrobe progress survives Legacy transitions. Combined installations use KASC's wardrobe authority; VASC alone supplies Red's wardrobe.

---

## KASC 6.7.19 — Exploration and combat fixes (2/3)

- Roaming rivals now provide the appropriate starter-habitat follow-up hints in normal postgame and NG+, including eligible NG+ runs without a new current-run Hall of Fame entry.
- Rival clues create starter-family traces, and the existing Trace Finder opens the authored paths. No extra unlock item is required. Normal-run opening receipts remain in that save.
- Fixed Route 14's unreachable search target and separated the southern clue from the eastern exit. Fixed Fuchsia's approach/return placement and Route 6's blocked passage; already-open Route 6 entrances are repaired.
- All 16 starter entrances were exercised in normal postgame and NG+, including entry and return. Red/Yellow geometry for all 20 starter/legendary access definitions was checked. The four legendary gates retain their existing NG+ and character-seal requirements.
- Driftglass's crystal now reports that it is dormant. Its evolution items can instead appear as very rare rematch drops.
- Volcano stairs activate automatically when walked onto, across both approach columns. Arrival landings prevent immediate return loops; expedition/puzzle gates and boat-return dialogue remain intact.
- Fixed the Research Atlas crash when selecting a seen Bulbasaur from habitats.
- Corrected Heavy Slam's interaction with Focus Punch disruption.
- Paired VASC includes safer hero-art handling, improved battle presentation and consistent character/outfit rendering.

---

## KASC 6.7.19 — Mythic Signals, Johto trials and validation (3/3)

- Fixed Mythic Signals progress being blocked by the first unfought visible Pokemon. Other eligible wild battles now advance the hunt independently.
- Regression example: starting at 432 remaining, 15 eligible battles now show 417 even when an earlier visible Pokemon remains unfought.
- Merely spawning or despawning Pokemon does not consume progress. Exact opponent matching, duplicate-event protection and single reservations for visible rare signals remain enforced. Concurrent progress cannot overwrite a newer seal, completion or bound signal.
- Status text explains eligible ordinary Kanto land encounters; water, Safari and protected special encounters do not count. Existing counters resume, but previously missed progress cannot be reconstructed.
- Removed repeated Legacy-archive writes from Johto quiz availability checks and repeated question reads. New quiz selection and actual answers/gate transitions still create checkpoints; wrong answers still reset the challenge.
- In the local nine-question comparison, archive writes fell from 54 to 12 and processing time from 346 to 80 ms (about 77% less). This measures processing/storage work, not the time spent reading or overall game FPS.
- Silver, Kris and Gold question/answer flows and their battle-portal transitions were checked in native LOVE. The paired VASC update shows the live countdown and question in ORAS fullscreen.
- The community's multi-minute quiz delay was not reproduced locally and still needs confirmation on the affected device/save. Physical Windows/mobile and longer sessions with the final paired build remain open checks.

Install: close the game and update the existing mod, preserving saves and optional artwork. Use the Preserve-Installed-Sprites installer for a backed-up desktop update, or merge the ZIP contents into the existing mod folder. Fully restart after updating.
