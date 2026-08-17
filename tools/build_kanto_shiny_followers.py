#!/usr/bin/env python3
"""Build #001-151 follower walkers with exact Pokémon Crystal shiny indices.

The PokéPC/Crystal Clear walkers contain transparency, black and exactly two
authored species colours.  Those two colours are matched bijectively to the
two middle colour *indices* of the canonical Crystal normal front palette.
The corresponding shiny.pal index then replaces each role.  This is an index
mapping, not a light/dark or luminance heuristic.

Canonical palette source:
  https://github.com/pret/pokecrystal/tree/7a7881d0d62e0ddbd82dcf10e7116807487ac651
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import tempfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "followers_kanto"
OUTPUT = SOURCE / "shiny"
TRANSFORMS = ROOT / "shiny_transforms.lua"
SOURCE_COMMIT = "7a7881d0d62e0ddbd82dcf10e7116807487ac651"

# Palette entries 1 and 2 from each canonical Crystal normal front PNG in
# National-Dex order.  Values are the PNG's exact 8-bit RGB entries and are
# used only to identify each existing follower colour's palette index.
CRYSTAL_NORMAL = """\
63ff5aff523163ff5aff528442ce5aef3973ff6b21b52929f74231941839ff5a00314a7bb59442527bffb594425273ffc6a518425aff63b531ff4a7b
7bff004a730894ceffd6296bd68c29ce2918d6ce18a57342ff9c21f72108f7de6b9c4210ff52639c4210ff52639c4210b542f784188cefbd528c5200
9c5208f75263b55a21ff3184a542adad003994429cb5214aefd629d63100ffd639ff6300b59431633908bd94006b390094adf76331736ba5ff396373
de9c394a84dede42ad8c1084b542b55229849431a55a215aff73946b3900ff73946b3900ff6339ad2942ffff31947b00ff73ad3184ffff73ad3184ff
637b9c29428c637b9c29428c5abd18314a4aff6300424a6bff3118424a6bff6318bd1800ff4a21732908e729105a0073de52c66329739c5a21c63121
9c5a21c63121ffde6ba54218ffe752634a21ffff009c7b39b5add6425ac6efa55a9c4a39ff9463844229de9c39c64200ffbd39c63118d64229394252
4a73843139528484d631317be79c18634252e79c18634252e79c18634252a58c5a4a5a21848c5ab52121ad945a4a5a21a5ff39de524a6bff39ef4a4a
7bd618ff526b5aa5fff731525aa5ffd61010948c7b425a398c8c94425a39948442425a39d6de21ff2918d6de21ff2918ff528cad2942ff528c638c5a
7b8cc6ff31107b8cc6ff3110bd634231d608ad6b4a634231d684429442319cadffef4a6b9cadff425a94ef10a5630863ef10a563086384426bad3908
ad52b563216bf742f78c00bdce393173009cff29104a00848c7ba54a315affbd21945263ffce00ad6300ef8c4aef2921ef8c4aef2921a5a58cc62929
a5a58cc62929ff7b8c9c294aa56b31298439a59c63845221a59c63845221b573297b847bad7b63de1894ff5294d63129ce52ce943194ce52ce5a2973
7b5a8c394a217b5a8c394a21e784adff4a9c4a6bbd8c31319c7321424210e7de635a8cffe7b5844a84ffff639cff52109cb5f7ff5210bd8c5aff2918
d6b5009c3994ff5affe7396b7bd600bdce0073107bef319cffff29c68429ffa500bd3931a5a5738c5239ce7b29523921ef523194184adece394a73d6
e7ad6b4284e7bd63e76b3984c684318c421084b5ff4a5affffff18e75a08ff5208ad2910c64a21427ba5a58c5a3973ada58c5a3973ada57300634a31
a57300634a319c9c7b635a5ade94736b4a4a5aadff425a84ffe700bd8400ffb500ff6318e7d6394273c68c9cff2973bdc68c215a528cb5a5ce8429a5
ff7bff395ad6
""".replace("\n", "")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgb_at(packed: str, offset: int) -> tuple[int, int, int]:
    return tuple(int(packed[offset + index : offset + index + 2], 16)
                 for index in (0, 2, 4))


def display(colour: tuple[int, int, int]) -> str:
    return "#%02X%02X%02X" % colour


def distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
    return sum((a - b) ** 2 for a, b in zip(left, right))


def source_tables() -> tuple[list[str], str]:
    text = TRANSFORMS.read_text(encoding="utf-8")
    stems = re.search(r'local STEMS = "([^"]+)"', text)
    shiny = re.search(r'local COLORS = "([0-9a-f]+)"', text)
    assert stems and shiny, "shiny_transforms.lua palette tables unavailable"
    order = stems.group(1).split(",")
    assert len(order) == 151
    assert len(CRYSTAL_NORMAL) == 151 * 12
    assert len(shiny.group(1)) == 151 * 12
    return order, shiny.group(1)


def build(target: Path) -> dict[str, object]:
    stems, crystal_shiny = source_tables()
    target.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, object]] = []
    for dex, stem in enumerate(stems, 1):
        source = SOURCE / f"follower_{dex:03d}.png"
        image = Image.open(source).convert("RGBA")
        assert image.size == (16, 96), f"wrong walker geometry: {source}"
        pixels = list(image.getdata())
        follower_colours = sorted({
            pixel[:3] for pixel in pixels
            if pixel[3] > 0 and pixel[:3] != (0, 0, 0)
        })
        assert len(follower_colours) == 2, (
            f"#{dex:03d} must have exactly two non-black opaque roles"
        )
        offset = (dex - 1) * 12
        normal = [rgb_at(CRYSTAL_NORMAL, offset),
                  rgb_at(CRYSTAL_NORMAL, offset + 6)]
        shiny = [rgb_at(crystal_shiny, offset),
                 rgb_at(crystal_shiny, offset + 6)]
        nearest: list[int] = []
        for follower_colour in follower_colours:
            costs = [distance(follower_colour, role) for role in normal]
            assert costs[0] != costs[1], (
                f"ambiguous Crystal role mapping: #{dex:03d} {follower_colour}"
            )
            nearest.append(0 if costs[0] < costs[1] else 1)
        assert sorted(nearest) == [0, 1], (
            f"non-bijective Crystal role mapping: #{dex:03d} {nearest}"
        )
        indices = tuple(nearest)
        mapping = {
            follower_colours[0]: shiny[indices[0]],
            follower_colours[1]: shiny[indices[1]],
        }
        recoloured = [
            (mapping[pixel[:3]] + (pixel[3],))
            if pixel[3] > 0 and pixel[:3] in mapping else pixel
            for pixel in pixels
        ]
        output = Image.new("RGBA", image.size)
        output.putdata(recoloured)
        destination = target / f"follower_{dex:03d}.png"
        output.save(destination, format="PNG", optimize=False, compress_level=9)
        colour_keys = [display(value) for value in follower_colours]
        entries.append({
            "dex": dex,
            "stem": stem,
            "normalFollowerColours": colour_keys,
            "crystalNormal": [display(value) for value in normal],
            "crystalShiny": [display(value) for value in shiny],
            "crystalIndexByFollowerColour": {
                colour_keys[0]: indices[0] + 1,
                colour_keys[1]: indices[1] + 1,
            },
            "normalSha256": sha256(source),
            "shinySha256": sha256(destination),
        })
    contract = {
        "schema": 1,
        "source": {
            "repository": "https://github.com/pret/pokecrystal",
            "commit": SOURCE_COMMIT,
            "normalIndexSource": "gfx/pokemon/<species>/front.png palette entries 1 and 2",
            "shinySource": "gfx/pokemon/<species>/shiny.pal",
            "expansion": "5-bit channel << 3",
            "mapping": "minimum-distance bijection to normal indices; never luminance",
            "auditAliases": {
                "nidoranf": "nidoran_f",
                "nidoranm": "nidoran_m",
                "farfetchd": "farfetch_d",
                "mr.mime": "mr__mime",
            },
        },
        "entries": entries,
    }
    (target / "palette_contract.json").write_text(
        json.dumps(contract, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return contract


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="rebuild privately and compare pixels/contract")
    args = parser.parse_args()
    if not args.check:
        build(OUTPUT)
        print("built 151 Kanto shiny follower walkers")
        return 0
    with tempfile.TemporaryDirectory(prefix="ka-kanto-shiny-") as temp:
        candidate = Path(temp)
        build(candidate)
        for dex in range(1, 152):
            expected = Image.open(OUTPUT / f"follower_{dex:03d}.png").convert("RGBA")
            actual = Image.open(candidate / f"follower_{dex:03d}.png").convert("RGBA")
            assert expected.size == actual.size and list(expected.getdata()) == list(actual.getdata())
        expected_contract = json.loads((OUTPUT / "palette_contract.json").read_text())
        actual_contract = json.loads((candidate / "palette_contract.json").read_text())
        assert expected_contract == actual_contract
    print("verified 151 reproducible Kanto shiny follower walkers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
