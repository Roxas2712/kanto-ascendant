#!/usr/bin/env python3
"""Build native-size Red/Blue/Green character assets for Phase 8.

Green's visual direction is based on Felix Jones' 2025 Pokémon Green work:
https://felixjones.co.uk/2025/04/30/pokegreen.html

The source site's final 56x56 trainer front, 16x16 overworld poses and 32x32
battle back are stored below as four-shade run-length data so the build is
deterministic. The trainer front is the final frame of Felix's progress.gif,
selected by the user as Casey/Green's binding portrait. It is distinct from
the overworld walker and does not use the discarded handheld-device title
pose. The walking sheet uses the exact first two frames of Felix's
walk_down.gif, walk_up.gif and walk_side.gif, reordered to the engine's
stand-down/up/left, walk-down/up/left convention.
Public redistribution should credit Felix Jones and confirm permission,
because the source page does not state an asset licence.

Blue's 32x32 battle back adapts the first rear-facing frame from MegaBlueAce's
public Blue backsprite set into the native Gen-I four-shade grid. The author
explicitly permits use on the source page.
"""

from pathlib import Path
import re

from PIL import Image
from PIL.PngImagePlugin import PngInfo


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters"
DEMO_OUT = ROOT / "character_demo/assets/characters"
REFERENCE_URL = "https://felixjones.co.uk/2025/04/30/pokegreen.html"
BLUE_BACK_URL = ("https://www.deviantart.com/megablueace/art/"
                 "Pokemon-Trainer-Blue-Back-Sprite-621777914")

# Frame order: stand down/up/left, walk down/up/left. Right is mirrored by
# SpriteRenderer. These are exact 16x16 source frames, without added pixels.
GREEN_WALK_RLE = """
6.4K10.2K4M2K7.K8MK6.K2MK2MK2MK5.K2MK4MK2MK4.K2MLM2LML2MK4.K2M6L2MK4.
KM2LK2LK2LMK4.KM2LK2LK2LMK4.KMK2L2M2LKMK3.K2L8K2LK2.K2L8K2LK3.5K2M5K5.
10K7.K2L2K2LK8.K2M2K2MK10.4K10.2K4M2K7.K8MK6.K8MK5.K10MK4.KML6MLMK4.
K2M6L2MK4.K10MK4.K10MK4.2K8M2K3.KLK8MKLK2.KL2K6M2KLK3.12K5.10K7.
K2M2K2MK8.8K10.4K10.2K4M2K7.K8MK5.K2MK6MK5.K2MLK5MLK5.K3L3M2LMK5.
KLKLMK4MK5.KLK2L2K3MK5.K3LK2MK2MK6.KMLK2LK2MK7.5K3MK8.4K3MK8.2K2LK2MK7.
3K2L3K8.K2M3K11.4K28.4K10.2K4M2K7.K8MK6.K2MK2MK2MK5.K2MK4MK2MK4.
K2MLM2LML2MK4.K2M6L2MK4.KM2LK2LK2LMK4.KM2LK2LK2LMK3.4K2L2M2LKMK3.
KL9KLK4.8K2LK6.4K2MK2LK7.8K8.K2MK30.4K10.2K4M2K7.K8MK6.K8MK5.K10MK4.
KML6MLMK4.K2M6L2MK4.K10MK3.K10M2K3.K10M2K3.K9M3K4.K6M2K2LK5.8K2LK6.
K2M6K7.4K30.4K10.2K4M2K7.K8MK5.K2MK6MK5.K2MLK5MLK5.K3L3M2LMK5.
KLKLMK4MK5.KLK2L2K3MK5.K3LK2MK3MK5.KMLK2LK3MK6.5K4MK5.6K4MK4.KMK2L6K6.
KM2L2K2MK8.7K4.
"""

# Final 56x56 frame of https://felixjones.co.uk/assets/pokegreen/progress.gif.
# The source GIF is an exact 3x nearest-neighbour presentation; its white
# paper is keyed to transparency without changing any character pixel.
GREEN_FRONT_RLE = """
82.2K2M2K48.MK3MK2LML45.KM3LM2L.L.L43.KM8L3.L41.KM9L4.L40.KMLMLM6L3.M39.7M6L2.LML39.K3MK2M
2LM2L.2L2M39.K3MK6M3L2MK38.3MKMLKMK4ML3MK39.2M2KLKML2K6M40.2MK.KLKL.K.K2MKMK37.LMKMK.K3L.K
2.K4M38.MKMK7L2.M2KM40.2MK2LM3L2.2K2ML41.KMK2LKML.K2MKML41.K2MK2L2.MK2.KML41.K3M5KM2K3M40.
L3MKM4K3M.KML37.L4MKM5KMKL.K2MLM33.K5MKML4K2MKL.K2MK35.K3MKMLM3K2M2KL.K2M35.L3MKM2L8KL.K3M
34.KM2KM2L10K2MKM37.MKM2L5.MK.M3.M39.K2M4L3.M.M2.2M40.4M2K3MKLML.M41.M2.LM3L2MK3M42.KLM10K
M41.15KM39.16KM39.17KM37.19KM36.K5M13KM37.2KLMLKM9KM2K39.KLMKLM8KM2K40.3KLMKMK2M2KMLMK42.K
2L3KLMK3MK43.KL.K2.K2LK46.KL.K3.2L.M45.KL.K3.M2LKM44.KL.K4.4KL42.5KL3.3K2MK41.K4MK3.2K2MKM
K40.4KMK3.M3K3M40.5KL4.2K2MKM39.MK2M2KM4.4MKL39.2K3M2K4.3M2K39.2KM2KM2K4.4K40.K4MKMK5.2K41
.K3M2KMK48.M4KM197.
"""

GREEN_BACK_RLE = """
72.L6KLKM21.2KM5LK2LM19.KM8LM2LM17.2M12LM17.KM13LM15.MKM10LM2LML14.
3M10L2ML2M14.K2M9L5MK14.K3M5LML3MKMKM14.K3M5L3M2KMLK15.K4M4L2MKMKLK16.
MK4M2L3MKM2.K17.K5ML2M2KL3.M16.K7MK2MK3.K16.K7MKL.KL.K16.MK8M2KMLK17.
K10M2KM17.MK6M2K2M2K3.2ML12.K6MKL.K2MK3.M.2K10.K6MKL3.K2ML.M3.LK8.
K2MK3MKM4.2K2M.K4.L8.KMK4MK4.L4K.M4.M8.3K3MKL4.5K.M4.M9.MK3MK4.L6KL2.MK10.
K3MKL3.L6K4LM11.KM2KM3.LM5K4LM138.
"""

# First rear-facing pose from MegaBlueAce's 245x64 four-frame sheet, reduced
# with nearest-neighbour sampling and a fixed four-shade threshold. This RLE
# locks the reviewed native 32x32 result and prevents later filtering drift.
BLUE_BACK_RLE = """
79.K2M26.2M3L23.M.K5LM2K2M19.LM5LM3LM19.KLM9LK19.13L2M16.2M10LM2LMK15.
K3M9LML3M15.8M2LM2LMK17.10MKMLKM17.12ML.K17.MK5ML2ML2M20.6M6L21.7M4L22.
5M3LM23.KMK4MLM23.3K2M2K27.2KM3K23.K8MK21.12MK18.2K12MK17.
3K9MK2M17.5K2M5K3MK15.13K3MK15.14K3M15.14K3MK14.15K3M14.LM2K.8K.2KMK13.
M2LM2.8K.M3LK12.3LM2.8K2.M3L7.
"""

DMG = {".": (0, 0, 0, 0), "L": (170, 170, 170, 255),
       "M": (85, 85, 85, 255), "K": (0, 0, 0, 255)}
# Transparent pixels keep black RGB under alpha zero. This is visually
# identical to the source's white background being keyed out, while preventing
# Modkit's alpha-blind perceptual hash from confusing Green with a ROM sprite.
GREEN_OVERWORLD = {".": (0, 0, 0, 0), "L": (170, 170, 170, 255),
                   "M": (85, 85, 85, 255), "K": (0, 0, 0, 255)}


def decode_rle(width, height, encoded, palette):
    encoded = re.sub(r"\s+", "", encoded)
    pixels = []
    for count, shade in re.findall(r"(\d*)([.LMK])", encoded):
        pixels.extend([palette[shade]] * (int(count) if count else 1))
    assert len(pixels) == width * height, (width, height, len(pixels))
    image = Image.new("RGBA", (width, height))
    image.putdata(pixels)
    return image


def metadata():
    info = PngInfo()
    info.add_text("Source", REFERENCE_URL)
    info.add_text("Credit", "Green design/source spritework: Felix Jones; Kanto Ascendant adaptation")
    info.add_text("Redistribution", "Confirm permission before public redistribution; no asset licence stated on source page")
    return info


def blue_metadata():
    info = PngInfo()
    info.add_text("Source", BLUE_BACK_URL)
    info.add_text("Credit", "Blue backsprite set by MegaBlueAce")
    info.add_text("Adaptation", "First rear pose; 32x32 four-shade conversion; detached throw particle removed")
    return info


def main():
    walk = decode_rle(16, 96, GREEN_WALK_RLE, GREEN_OVERWORLD)
    front = decode_rle(56, 56, GREEN_FRONT_RLE, GREEN_OVERWORLD)
    back = decode_rle(32, 32, GREEN_BACK_RLE, DMG)
    blue = decode_rle(32, 32, BLUE_BACK_RLE, GREEN_OVERWORLD)
    for target in (OUT, DEMO_OUT):
        target.mkdir(parents=True, exist_ok=True)
        walk.save(target / "green_walk.png", pnginfo=metadata())
        front.save(target / "green_front.png", pnginfo=metadata())
        back.save(target / "green_back.png", pnginfo=metadata())
        blue.save(target / "blue_back.png", pnginfo=blue_metadata())


if __name__ == "__main__":
    main()
