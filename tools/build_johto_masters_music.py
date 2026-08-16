#!/usr/bin/env python3
"""Transcribe the two pinned pret/pokecrystal songs into ChipAsm source data.

This is intentionally a narrow parser, not a general RGBDS music converter.
It accepts exactly the commands used by IndigoPlateau and RivalBattle, carries
their wave/noise dependencies, and fails closed on a source or command drift.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
from pathlib import Path


PINNED_COMMIT = "8e8f7e20052a596371a77022f0392c285e51bbf1"
PINNED_HASHES = {
    "audio/music/indigoplateau.asm":
        "953c1581d247468e60da5bd7ddcd2a1721900824249d1928948b951da38b8737",
    "audio/music/rivalbattle.asm":
        "80e50b34754dfa0eea5aa67e30ede7586b0709a3e5e10857d0dfadcdb15926ab",
    "audio/drumkits.asm":
        "6a4be3937b142958801238c38aa74dd2fcc8844ce9316a0809203907ceb45d53",
    "audio/wave_samples.asm":
        "770259cd6b04841440e8b1d504c926666d0bdde6372e6b0afa74188110bead9c",
}
SONGS = {
    "indigo": ("Music_IndigoPlateau", "audio/music/indigoplateau.asm"),
    "rival": ("Music_RivalBattle", "audio/music/rivalbattle.asm"),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_lines(path: Path) -> list[str]:
    lines: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split(";", 1)[0].strip()
        if line:
            lines.append(line)
    return lines


def args_for(line: str, command: str) -> list[str]:
    body = line[len(command):].strip()
    return [part.strip() for part in body.split(",")] if body else []


def parse_int(value: str) -> int:
    return int(value, 0)


def label_name(value: str) -> str:
    return value.strip().lstrip(".")


def parse_song(path: Path, root_label: str) -> dict:
    lines = source_lines(path)
    count_line = next(line for line in lines if line.startswith("channel_count "))
    channel_count = parse_int(args_for(count_line, "channel_count")[0])
    channel_labels: list[tuple[int, str]] = []
    for line in lines:
        if not line.startswith("channel "):
            continue
        number, label = args_for(line, "channel")
        channel_labels.append((parse_int(number), label))
    assert len(channel_labels) == channel_count, (path, channel_labels)

    roots = {label: lines.index(label + ":") for _, label in channel_labels}
    ordered_roots = sorted(roots.values())
    song = {"tempo": None, "channels": [], "drumkits": set()}

    for number, channel_label in channel_labels:
        start = roots[channel_label] + 1
        end = next((index for index in ordered_roots if index > start), len(lines))
        events: list[dict] = []
        speed = 12
        frequency_offset = None
        pan_left = None
        pan_right = None
        drumkit = None

        for line in lines[start:end]:
            if line.endswith(":"):
                events.append({"label": label_name(line[:-1])})
                continue
            command = line.split(None, 1)[0]
            values = args_for(line, command)
            if command == "tempo":
                tempo = parse_int(values[0])
                if song["tempo"] is not None:
                    assert song["tempo"] == tempo
                song["tempo"] = tempo
            elif command == "volume":
                assert values == ["7", "7"], (path, line)
            elif command == "duty_cycle":
                events.append({"duty": parse_int(values[0])})
            elif command == "pitch_offset":
                frequency_offset = parse_int(values[0])
            elif command == "stereo_panning":
                assert all(value in {"TRUE", "FALSE"} for value in values)
                pan_left, pan_right = (value == "TRUE" for value in values)
            elif command in {"note_type", "drum_speed"}:
                speed = parse_int(values[0])
                spec = {"speed": speed}
                if command == "note_type" and number == 3:
                    spec["waveLevel"] = parse_int(values[1])
                    spec["waveInstrument"] = parse_int(values[2])
                elif command == "note_type" and number != 4:
                    spec["volume"] = parse_int(values[1])
                    spec["fade"] = parse_int(values[2])
                events.append({"notetype": spec})
            elif command == "volume_envelope":
                assert number in {1, 2}, (path, line)
                events.append({"notetype": {
                    "speed": speed,
                    "volume": parse_int(values[0]),
                    "fade": parse_int(values[1]),
                }})
            elif command == "octave":
                events.append({"octave": parse_int(values[0])})
            elif command == "note":
                note = values[0].replace("_", "")
                events.append({"note": note, "len": parse_int(values[1])})
            elif command == "rest":
                events.append({"rest": parse_int(values[0])})
            elif command == "drum_note":
                events.append({"drum": parse_int(values[0]),
                               "len": parse_int(values[1])})
            elif command == "vibrato":
                events.append({"vibrato": {
                    "delay": parse_int(values[0]),
                    "depth": parse_int(values[1]),
                    "rate": parse_int(values[2]),
                }})
            elif command == "toggle_noise":
                drumkit = parse_int(values[0])
                song["drumkits"].add(drumkit)
            elif command == "sound_call":
                events.append({"call": label_name(values[0])})
            elif command == "sound_loop":
                events.append({"loop": {
                    "count": parse_int(values[0]),
                    "to": label_name(values[1]),
                }})
            elif command == "sound_ret":
                events.append({"ret": True})
            else:
                raise ValueError(f"unsupported {path.name} command: {line}")

        channel = {"hw": number, "program": events}
        if frequency_offset is not None:
            channel["frequencyOffset"] = frequency_offset
        if pan_left is not None:
            channel["panLeft"], channel["panRight"] = pan_left, pan_right
        if drumkit is not None:
            channel["drumkit"] = drumkit
        song["channels"].append(channel)

    assert song["tempo"] is not None, (root_label, "tempo")
    song["drumkits"] = sorted(song["drumkits"])
    return song


def parse_waves(path: Path) -> list[list[int]]:
    waves = []
    for line in source_lines(path):
        if line.startswith("dn "):
            values = [parse_int(value) for value in args_for(line, "dn")]
            assert len(values) == 32 and all(0 <= value <= 15 for value in values)
            waves.append(values)
    assert len(waves) == 10
    return waves


def parse_drumkits(path: Path, requested: set[int]) -> dict[int, dict[int, list[dict]]]:
    lines = source_lines(path)
    labels = {line[:-1]: index for index, line in enumerate(lines)
              if line.endswith(":")}
    sorted_label_starts = sorted(labels.values())

    def block(name: str) -> list[str]:
        start = labels[name] + 1
        end = next((index for index in sorted_label_starts if index > start), len(lines))
        return lines[start:end]

    out: dict[int, dict[int, list[dict]]] = {}
    for kit in sorted(requested):
        names = [args_for(line, "dw")[0]
                 for line in block(f"Drumkit{kit}") if line.startswith("dw ")]
        assert names
        rows: dict[int, list[dict]] = {}
        for instrument, name in enumerate(names):
            program = []
            for line in block(name):
                command = line.split(None, 1)[0]
                values = args_for(line, command)
                if command == "noise_note":
                    program.append({
                        "len": parse_int(values[0]),
                        "volume": parse_int(values[1]),
                        "fade": parse_int(values[2]),
                        "parameter": parse_int(values[3]),
                    })
                elif command == "sound_ret":
                    pass
                else:
                    raise ValueError(f"unsupported drum command: {line}")
            rows[instrument] = program
        out[kit] = rows
    return out


def lua_atom(value) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "nil"
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return str(value)


def lua_inline(value) -> str:
    if isinstance(value, dict):
        return "{" + ",".join(f"{key}={lua_inline(item)}"
                               for key, item in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua_inline(item) for item in value) + "}"
    return lua_atom(value)


def render(root: Path) -> str:
    source_hashes = {name: sha256(root / name) for name in PINNED_HASHES}
    assert source_hashes == PINNED_HASHES
    commit = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    assert commit == PINNED_COMMIT, commit

    songs = {key: parse_song(root / path, label)
             for key, (label, path) in SONGS.items()}
    requested_kits = {kit for song in songs.values() for kit in song["drumkits"]}
    drumkits = parse_drumkits(root / "audio/drumkits.asm", requested_kits)
    waves = parse_waves(root / "audio/wave_samples.asm")

    out = [
        "-- GENERATED by tools/build_johto_masters_music.py; do not hand-edit.",
        "-- Semantic ChipAsm transcription; no PCM/OGG fallback is bundled.",
        "return {",
        "  provenance = {",
        '    project = "pret/pokecrystal",',
        f'    commit = "{commit}",',
        "    files = {",
    ]
    for name, digest in source_hashes.items():
        out.append(f'      ["{name}"] = "{digest}",')
    out.extend(["    },", "  },", "  waves = {"])
    for wave in waves:
        out.append("    " + lua_inline(wave) + ",")
    out.extend(["  },", "  drumkits = {"])
    for kit, instruments in drumkits.items():
        out.append(f"    [{kit}] = {{")
        for instrument, rows in instruments.items():
            out.append(f"      [{instrument}] = {lua_inline(rows)},")
        out.append("    },")
    out.extend(["  },", "  songs = {"])
    for key, song in songs.items():
        out.append(f"    {key} = {{")
        out.append(f"      tempo = {song['tempo']},")
        out.append("      channels = {")
        for channel in song["channels"]:
            fields = [f"hw={channel['hw']}"]
            for field in ("frequencyOffset", "panLeft", "panRight", "drumkit"):
                if field in channel:
                    fields.append(f"{field}={lua_atom(channel[field])}")
            out.append("        { " + ",".join(fields) + ", program={")
            for event in channel["program"]:
                out.append("          " + lua_inline(event) + ",")
            out.append("        }},")
        out.extend(["      },", "    },"])
    out.extend(["  },", "}", ""])
    return "\n".join(out)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pokecrystal", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = render(args.pokecrystal.resolve())
    if args.check:
        current = args.output.read_text(encoding="utf-8")
        if current != rendered:
            raise SystemExit(f"generated file is stale: {args.output}")
        print("build_johto_masters_music: CHECK PASS")
        return
    args.output.write_text(rendered, encoding="utf-8")
    print(f"build_johto_masters_music: wrote {args.output}")


if __name__ == "__main__":
    main()
