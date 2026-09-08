# 6.7.0-rc.10 verification

- Field evolution rejection: English/German feedback for locked packages, unavailable epochs and incompatible Pokémon. Success still calls Evolution.request, cancellation still completes the map interaction, no inventory mutation.
- Native Red/Yellow: cancel and select three incompatible Pokémon repeatedly, dismiss feedback, verify the field object unfreezes.
- Wanderer native constructor: one badge, party level 15, advertised adaptive target 17; STANDARD/HIGH/HARD/VERY HARD/EXTREME preserve 17. Ordinary trainer adjustments and mismatched-marker validation retain difficulty scaling.
- Safari Ball excluded from future wanderer reward rolls; owned inventory and pending rewards are preserved.
- Ho-Oh renderer lifecycle correction lives in VASC 3.0.8, not this package. The combined package tests cover Red, Blue and Yellow, MAP/ARENA/DISCS, Crystal/Stadium 2 and the following wild/trainer encounter.

Runtime patch applies to the published 6.7.0-rc.9 package. Package receipts record the base and output SHA-256 and all changed entries. Assets, save identity, generation gates and package compatibility ranges are unchanged.
