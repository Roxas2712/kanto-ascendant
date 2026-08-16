#!/usr/bin/env node
"use strict";

const sharp = require("sharp");

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  throw new Error("usage: remove_connected_white_background.js INPUT OUTPUT");
}

function isBackground(data, offset) {
  const r = data[offset];
  const g = data[offset + 1];
  const b = data[offset + 2];
  return r >= 205 && g >= 205 && b >= 205
    && Math.max(r, g, b) - Math.min(r, g, b) <= 32;
}

async function main() {
  const { data, info } = await sharp(input)
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const { width, height, channels } = info;
  const seen = new Uint8Array(width * height);
  const queue = new Int32Array(width * height);
  let head = 0;
  let tail = 0;

  function enqueue(x, y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    const index = y * width + x;
    if (seen[index] || !isBackground(data, index * channels)) return;
    seen[index] = 1;
    queue[tail++] = index;
  }

  for (let x = 0; x < width; x += 1) {
    enqueue(x, 0);
    enqueue(x, height - 1);
  }
  for (let y = 0; y < height; y += 1) {
    enqueue(0, y);
    enqueue(width - 1, y);
  }

  while (head < tail) {
    const index = queue[head++];
    const x = index % width;
    const y = Math.floor(index / width);
    enqueue(x - 1, y);
    enqueue(x + 1, y);
    enqueue(x, y - 1);
    enqueue(x, y + 1);
    enqueue(x - 1, y - 1);
    enqueue(x + 1, y - 1);
    enqueue(x - 1, y + 1);
    enqueue(x + 1, y + 1);
  }

  const rgba = Buffer.alloc(width * height * 4);
  for (let index = 0; index < width * height; index += 1) {
    const source = index * channels;
    const target = index * 4;
    rgba[target] = data[source];
    rgba[target + 1] = data[source + 1];
    rgba[target + 2] = data[source + 2];
    rgba[target + 3] = seen[index] ? 0 : 255;
  }

  await sharp(rgba, { raw: { width, height, channels: 4 } })
    .png()
    .toFile(output);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
