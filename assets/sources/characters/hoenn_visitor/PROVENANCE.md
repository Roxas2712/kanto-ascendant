# Hoenn visitor — Gen-1 revision 2

`gen1_master_v2.png` is the selected built-in Imagegen output, guided by the original Gen-1 female NPC sprite proportions and pixel grid. `build.py` preserves enclosed light face/bandana pixels while removing exterior white, then converts to a three-shade 16x96 OBJ sheet. `master.png` is the superseded first design and is no longer used by the build or runtime.

The exact revision-2 prompt is recorded in the paired VASC package under `assets/hoenn_visitor/PROVENANCE.md`.

## Revision-2 prompt

Edit this EXACT Gen1 16x16 character sprite sheet while retaining the precise pixel grid, original 16x16 proportions, and pose positions. The reference has six 16x16 sprites enlarged32times to1536x1024: three columns bytwo rows; stand facing down/up/left above walk facing down/up/left. Design a distinct visiting woman from Hoenn: short dark bob hair, a small triangular light bandana tied at back (NO sunhat or wide brim), simple travel tunic over shorts, a small square honey satchel at her hip with one dark diagonal strap, sturdy black shoes. Keep tiny simple original Pokemon Red/Blue overworld face (two vertical black eyes, tiny expression), head/body ratio exactly as reference, one-pixel outline and details, authentic 1996 Game Boy appearance. Only black #000000, darkgray #555555, lightgray #AAAAAA and white #FFFFFF background. Every block MUST be32x32px, aligned to48x32 logical grid. No finer detail. White blank exterior. Keep top/bottom and left/right frame positions exactly matching input. No gradients, no antialias, no glow, no 3D, no modern pixelart, no cute huge hat. Same woman in all six views. This is the actual in-game native sprite sheet, not concept art.

## Superseded first design provenance

# Hoenn visitor

Original project character generated using the built-in Imagegen tool on 2026-09-28. The existing project-owned `assets/characters/green_walk.png` was supplied as a style and scale reference. No third-party sprite sheet was copied. `master.png` is the selected generated output.

`build.py` crops each generated pose to its alpha bounds, samples it to the native 14x15 footprint with nearest-neighbor, quantizes to three hardware shades plus transparency, and packs six poses into `assets/characters/hoenn_visitor_walk.png` (16x96). The runtime applies the regular sprite palette, including monochrome modes. The six native frames were visually inspected after conversion.

## Final prompt

Reference image is the game's EXISTING sprite sheet. Create a new original Hoenn honey merchant woman sprite sheet matching the reference's VERY LOW RESOLUTION and CHIBI proportions exactly. New character with floppy cream sunhat with broad brim, dark bob hair, short dress/travel tunic and a small shoulder satchel. THIS MUST BE AN ACTUAL 16x16 PIXEL CHARACTER DESIGN, not a detailed larger sprite reduced later. Each character's head occupies upper9pixel rows, torso/feet occupy only6rows. Figure12pixels wide15pixels tall. Each logical pixel a single huge solid square. Arrange the same SIX POSES as a3columns by2rows grid: top stand down/up/left; bottom step down/up/left. Entire sheet logical resolution48x32, enlarged32x nearest neighbor to1536x1024. Each logical pixel must be exactly32px square aligned with that48x32 grid. Use ONLY 3 opaque grayscale shades 0,85,170 and actual transparent background. Big black2pixel eyes separated by2pixels, light gray face readable at16px. Huge simple head and stubby body, tiny2pixel black shoes. Preserve reference's sprite scale and visual readability, but new merchant design with recognizable hat. No smaller subpixels or curves, no antialias, no glow, no labels, no shadows, no gridlines, no background. Every pose center of cell, feet on same baseline. Do NOT produce tall detailed humanoid sprites.
