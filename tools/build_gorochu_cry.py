#!/usr/bin/env python3
"""Build Gorochu's compact Yellow-style spoken cry.

The source syllables are synthesized locally as "Go-ro-chu", then converted
to the same 22.05 kHz, unsigned 1-bit PCM shape used by Yellow's partner
voice clips. No external recording is embedded in the finished asset.
"""

from __future__ import annotations

import argparse
import array
import subprocess
import tempfile
import wave
from pathlib import Path


RATE = 22050


def synthesize(target: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="gorochu-cry-") as temp:
        root = Path(temp)
        aiff = root / "gorochu.aiff"
        pcm = root / "gorochu.wav"
        subprocess.run(
            [
                "/usr/bin/say",
                "-v",
                "Eddy (Englisch (USA))",
                "-r",
                "280",
                "-o",
                str(aiff),
                "Go-ro-chew!",
            ],
            check=True,
        )
        subprocess.run(
            [
                "/usr/bin/afconvert",
                "-f",
                "WAVE",
                "-d",
                f"LEI16@{RATE}",
                str(aiff),
                str(pcm),
            ],
            check=True,
        )
        quantize(pcm, target)


def quantize(source: Path, target: Path) -> None:
    with wave.open(str(source), "rb") as src:
        if (
            src.getnchannels() != 1
            or src.getsampwidth() != 2
            or src.getframerate() != RATE
        ):
            raise ValueError("expected 16-bit mono 22050 Hz source")
        samples = array.array("h")
        samples.frombytes(src.readframes(src.getnframes()))
        if samples.itemsize != 2:
            raise ValueError("unexpected native short width")

    # Tight silence trim keeps the cry responsive in battle and partner talk.
    threshold = 280
    audible = [i for i, value in enumerate(samples) if abs(value) >= threshold]
    if not audible:
        raise ValueError("synthesized cry is silent")
    pad = int(RATE * 0.012)
    start = max(0, audible[0] - pad)
    end = min(len(samples), audible[-1] + pad + 1)
    samples = samples[start:end]

    # One-pole high/low pass followed by a short attack/release envelope.
    high_passed: list[float] = []
    previous_input = 0.0
    previous_output = 0.0
    alpha_high = 0.965
    for raw in samples:
        value = raw / 32768.0
        filtered = alpha_high * (previous_output + value - previous_input)
        high_passed.append(filtered)
        previous_input = value
        previous_output = filtered

    low_passed: list[float] = []
    smooth = 0.0
    alpha_low = 0.58
    for value in high_passed:
        smooth += alpha_low * (value - smooth)
        low_passed.append(smooth)

    peak = max(abs(value) for value in low_passed) or 1.0
    attack = max(1, int(RATE * 0.008))
    release = max(1, int(RATE * 0.022))
    normalized: list[float] = []
    for index, value in enumerate(low_passed):
        envelope = min(
            1.0,
            (index + 1) / attack,
            (len(low_passed) - index) / release,
        )
        normalized.append(max(-0.92, min(0.92, value / peak * 0.9 * envelope)))

    # First-order sigma-delta modulation: exact two-level 8-bit PCM while
    # retaining the three spoken syllables on Game Boy-scale audio.
    error = 0.0
    encoded = bytearray()
    for value in normalized:
        driven = value + error
        bit = 1.0 if driven >= 0.0 else -1.0
        error = max(-1.0, min(1.0, driven - bit))
        encoded.append(224 if bit > 0 else 32)

    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as dst:
        dst.setnchannels(1)
        dst.setsampwidth(1)
        dst.setframerate(RATE)
        dst.writeframes(encoded)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=Path("assets/audio/gorochu/gorochu_cry.wav"),
    )
    args = parser.parse_args()
    synthesize(args.output)
    print(f"built {args.output}")


if __name__ == "__main__":
    main()
