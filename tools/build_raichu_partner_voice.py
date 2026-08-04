#!/usr/bin/env python3
"""Build seven Yellow-style 1-bit partner Raichu voice clips.

The source is the ten-second Pokémon Channel voice compilation credited in
THIRD_PARTY_NOTICES.md. The full source is never copied into the mod: fixed
voice-group intervals are filtered, downmixed and sigma-delta quantized to
the same two unsigned sample values used by Yellow's imported Pikachu PCM.
"""

from __future__ import annotations

import argparse
import struct
import subprocess
import tempfile
import wave
from pathlib import Path


SEGMENTS = (
    ("sleepy", 0.00, 0.90),
    ("unwell", 1.14, 1.80),
    ("upset", 2.07, 3.54),
    ("wary", 3.70, 4.27),
    ("content", 4.40, 5.59),
    ("devoted", 5.76, 6.54),
    ("excited", 6.82, 9.96),
)


def convert_segment(ffmpeg: Path, source: Path, target: Path,
                    start: float, end: float) -> None:
    subprocess.run(
        [
            str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y",
            "-ss", f"{start:.3f}", "-to", f"{end:.3f}",
            "-i", str(source), "-vn", "-ac", "1", "-ar", "22050",
            "-af",
            (
                "highpass=f=120,lowpass=f=7500,"
                "loudnorm=I=-16:LRA=7:TP=-2,"
                "afade=t=in:st=0:d=0.01,"
                f"afade=t=out:st={max(0.0, end - start - 0.025):.3f}:d=0.025"
            ),
            "-c:a", "pcm_s16le", str(target),
        ],
        check=True,
    )


def one_bit_pcm(source: Path, target: Path) -> None:
    with wave.open(str(source), "rb") as src:
        assert src.getnchannels() == 1
        assert src.getsampwidth() == 2
        assert src.getframerate() == 22050
        count = src.getnframes()
        raw = src.readframes(count)
    samples = struct.unpack("<" + "h" * count, raw)

    # First-order sigma-delta modulation retains speech shape while producing
    # the exact two-level 8-bit stream used by Yellow's 1-bit Pikachu WAVs.
    error = 0.0
    encoded = bytearray()
    for sample in samples:
        value = max(-0.92, min(0.92, sample / 32768.0))
        driven = value + error
        bit = 1.0 if driven >= 0.0 else -1.0
        error = max(-1.0, min(1.0, driven - bit))
        encoded.append(224 if bit > 0 else 32)

    with wave.open(str(target), "wb") as dst:
        dst.setnchannels(1)
        dst.setsampwidth(1)
        dst.setframerate(22050)
        dst.writeframes(encoded)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ffmpeg", required=True, type=Path)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="raichu-voice-") as temp:
        temp_dir = Path(temp)
        for name, start, end in SEGMENTS:
            pcm = temp_dir / f"{name}.wav"
            convert_segment(args.ffmpeg, args.source, pcm, start, end)
            one_bit_pcm(pcm, args.output / f"raichu_{name}.wav")


if __name__ == "__main__":
    main()
