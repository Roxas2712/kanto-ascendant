#!/usr/bin/env node
/**
 * Build the two Yellow-partner-only expressions Crystal does not provide.
 *
 * The Pokémon Crystal battle/animation sources are read but never edited.
 * Derived 56x56 RGBA portraits live in their own asset tree and are used only
 * by yellow_partner.lua's framed follower reactions.
 */

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SOURCE = path.join(ROOT, "assets", "crystal_animated", "front");
const OUTPUT = path.join(ROOT, "assets", "yellow_partner_raichu_portraits");

const BLACK = [0, 0, 0, 255];

const MOODS = {
  sleepy: [5, 6],
  unwell: [4, 5, 6],
};

function pixelOffset(width, x, y) {
  return (y * width + x) * 4;
}

function setPixel(data, width, x, y, rgba) {
  const offset = pixelOffset(width, x, y);
  for (let channel = 0; channel < 4; channel += 1) {
    data[offset + channel] = rgba[channel];
  }
}

function paint(data, width, points, rgba) {
  for (const [x, y] of points) setPixel(data, width, x, y, rgba);
}

function clearRect(data, width, body, x1, y1, x2, y2) {
  for (let y = y1; y <= y2; y += 1) {
    for (let x = x1; x <= x2; x += 1) {
      setPixel(data, width, x, y, body);
    }
  }
}

function bodyColor(data, width) {
  // This coordinate is Raichu's cheek in every bundled #026 frame. It gives
  // orange in the normal set and olive-gold in the shiny set.
  const offset = pixelOffset(width, 16, 21);
  return [
    data[offset],
    data[offset + 1],
    data[offset + 2],
    data[offset + 3],
  ];
}

function eraseOriginalFace(data, width, body) {
  clearRect(data, width, body, 11, 16, 13, 20);
  clearRect(data, width, body, 20, 16, 23, 20);
}

function drawSleepy(data, width) {
  paint(data, width, [
    [11, 19], [12, 20], [13, 20],
    [20, 20], [21, 20], [22, 20], [23, 19],
  ], BLACK);
}

function drawUnwell(data, width) {
  const body = bodyColor(data, width);
  clearRect(data, width, body, 9, 22, 15, 27);
  paint(data, width, [
    [11, 18], [12, 19], [13, 20],
    [20, 20], [21, 19], [22, 19], [23, 18],
    // A small downturned mouth reads cleanly after the engine applies the
    // Yellow palette; the original mouth looked accidentally cheerful here.
    [9, 25], [10, 24], [11, 23], [12, 23],
    [13, 24], [14, 25],
  ], BLACK);
}

const DRAW = {
  sleepy: drawSleepy,
  unwell: drawUnwell,
};

async function buildPortrait(variant, mood, frame) {
  const filename = `${String(frame).padStart(3, "0")}.png`;
  const source = path.join(SOURCE, variant, "26", filename);
  const targetDir = path.join(OUTPUT, variant, mood);
  const target = path.join(targetDir, filename);
  const decoded = await sharp(source)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  if (decoded.info.width !== 56 || decoded.info.height !== 56
      || decoded.info.channels !== 4) {
    throw new Error(`Unexpected source shape: ${source}`);
  }
  const data = Buffer.from(decoded.data);
  const body = bodyColor(data, decoded.info.width);
  eraseOriginalFace(data, decoded.info.width, body);
  DRAW[mood](data, decoded.info.width);
  await fs.mkdir(targetDir, { recursive: true });
  await sharp(data, {
    raw: {
      width: decoded.info.width,
      height: decoded.info.height,
      channels: 4,
    },
  // Keep the exact four opaque Crystal shades plus transparency. Palette
  // quantization can only index four entries at 2-bit depth and would merge
  // white into yellow, so derived portraits stay lossless RGBA like sources.
  }).png({ compressionLevel: 9 }).toFile(target);
  return target;
}

export async function build() {
  const written = [];
  for (const variant of ["normal", "shiny"]) {
    for (const [mood, frames] of Object.entries(MOODS)) {
      for (const frame of frames) {
        written.push(await buildPortrait(variant, mood, frame));
      }
    }
  }
  return written;
}
