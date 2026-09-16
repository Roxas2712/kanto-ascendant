# Crystal character title-intro animations

Production package for Blue, Green, and Red. Each character now has two
alternating variants. Every variant has:

- 16 transparent RGBA frames at 128x128
- one horizontal 16-frame sheet
- one 4x4 review contact sheet
- one GIF preview
- native 40x56 title-slot frames and sheet

The Kanto Ascendant worktree copy reconstructs Green and Red from connected
figures on their complete 4x4 source boards before any grid split. Their shoes
legitimately cross the mathematical quarter-row boundaries; treating those
pixels as sheet bleed was the cause of the visibly amputated feet. Both the
128x128 masters and their 40x56 derivatives now retain those pixels. Blue,
Green and Red all use the exact Blue geometry at x=82, y=68 and scale 0.50.
Every authored frame is a transparent RGBA overlay; no identity uses a
per-frame horizontal or vertical canvas offset. Animated title Pokémon receive
a transparent eight-pixel footer reserve, so their visible pixels end above
KANTO ASCENDANT.

## Motion variants

- **Blue A:** calmly pulls out, inspects, and pockets one Poké Ball.
- **Blue B:** keeps an arrogant grin and his right hand on his hip while he
  gives the ball one short left-hand toss, catches it, and pockets it. The
  two-finger gesture from the concept board is deliberately omitted so the
  single action reads calmly at title speed.
- **Green A:** gives the two-finger forehead salute and outward wave.
- **Green B:** pulls out, finger-spins, catches, and pockets one Poké Ball while
  lifting one leg into the relaxed pose.
- **Red A:** rotates his cap 180 degrees backward, raises a compact confident
  fist, then rotates the cap forward again.
- **Red B:** pulls out, vertically tosses, catches, and pockets one Poké Ball;
  the corrected ball arc stays directly over the same catching palm.

## Timing and title synchronization

Use 8 engine ticks per frame at 60 Hz. An action therefore takes 128 ticks or
2.13 seconds. On every `kaTitlePairId` change, select the opposite variant from
the last appearance of that character, reset it to frame 1, play through frame
16 once, then hold frame 16 until the next pair change.

This fits comfortably inside both title timings present in the project:

- current authored Pokémon hold: 200 ticks / 3.33 seconds, plus transitions
- legacy whole-pair interval: 240 ticks / 4 seconds

The existing `title_intro.lua` already publishes trainer and Pokémon identity
together on the Pokémon-change edge. The animation should use that same edge;
it should not own a separate timer for switching identities.

See `animation_manifest.json` for machine-readable paths and timing.
