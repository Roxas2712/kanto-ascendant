#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa" / "trainer_full_normal_rework_root_20260812" / "candidates"
STEMS = ("beauty", "biker", "bird_keeper", "black_belt", "burglar", "channeler")

for stem in STEMS:
    low_path = OUT / f"{stem}_voxel_front_v2.png"
    hd_path = OUT / f"{stem}_voxel_front_hd_v2.png"
    assert low_path.is_file() and hd_path.is_file(), stem
    low = Image.open(low_path).convert("RGBA")
    hd = Image.open(hd_path).convert("RGBA")
    assert low.size == (64, 64) and hd.size == (128, 128), stem
    assert set(low.getchannel("A").getdata()) <= {0, 255}, stem
    assert set(hd.getchannel("A").getdata()) <= {0, 255}, stem
    assert low.getchannel("A").getbbox() and hd.getchannel("A").getbbox(), stem
    assert all(hd.getpixel(point)[3] == 0 for point in ((0, 0), (127, 0), (0, 127), (127, 127))), stem
    expected = hd.resize((64, 64), Image.Resampling.NEAREST)
    expected.putalpha(expected.getchannel("A").point(lambda value: 255 if value else 0))
    assert list(low.getdata()) == list(expected.getdata()), stem
    live = ROOT / "assets" / "characters" / "frlg_trainers"
    assert (live / f"{stem}_voxel_front_v2.png").read_bytes() == low_path.read_bytes(), stem
    assert (live / f"{stem}_voxel_front_hd_v2.png").read_bytes() == hd_path.read_bytes(), stem

print(f"ROOT NORMAL TRAINER SOURCES PASS: {len(STEMS)}/{len(STEMS)} approved pairs promoted")
