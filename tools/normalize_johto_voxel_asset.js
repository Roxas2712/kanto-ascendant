#!/usr/bin/env node
"use strict";

const sharp = require("sharp");

const [input, hdOutput, lowOutput, mode] = process.argv.slice(2);
if (!input || !hdOutput || !lowOutput) {
  throw new Error(
    "usage: normalize_johto_voxel_asset.js INPUT HD_OUTPUT LOW_OUTPUT"
  );
}

const transparent = { r: 0, g: 0, b: 0, alpha: 0 };

async function hardAlpha(image) {
  const { data, info } = await image
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  for (let i = 3; i < data.length; i += info.channels) {
    data[i] = data[i] >= 80 ? 255 : 0;
  }
  return sharp(data, { raw: info });
}

async function writeQuantizedRgba(image, output, colours) {
  const indexed = await image
    .png({ palette: true, colours, dither: 0 })
    .toBuffer();
  const rgba = await hardAlpha(sharp(indexed));
  await rgba.png({ palette: false }).toFile(output);
}

async function main() {
  if (mode === "--low-first") {
    const lowFrame = sharp(input)
      .trim({ background: transparent })
      .resize({
        width: 58,
        height: 58,
        fit: "contain",
        position: "bottom",
        kernel: sharp.kernel.nearest,
        background: transparent,
      })
      .extend({
        top: 3,
        bottom: 3,
        left: 3,
        right: 3,
        background: transparent,
      });
    const low = await hardAlpha(lowFrame);
    await writeQuantizedRgba(low, lowOutput, 24);
    const hd = await hardAlpha(
      sharp(lowOutput).resize({
        width: 128,
        height: 128,
        fit: "fill",
        kernel: sharp.kernel.nearest,
      })
    );
    await writeQuantizedRgba(hd, hdOutput, 48);
    return;
  }

  const framed = sharp(input)
    .trim({ background: transparent })
    .resize({
      width: 116,
      height: 116,
      fit: "contain",
      position: "bottom",
      kernel: sharp.kernel.nearest,
      background: transparent,
    })
    .extend({
      top: 6,
      bottom: 6,
      left: 6,
      right: 6,
      background: transparent,
    });

  const hd = await hardAlpha(framed);
  await writeQuantizedRgba(hd, hdOutput, 48);

  const low = await hardAlpha(
    sharp(hdOutput).resize({
      width: 64,
      height: 64,
      fit: "fill",
      kernel: sharp.kernel.nearest,
    })
  );
  await writeQuantizedRgba(low, lowOutput, 24);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error}\n`);
  process.exitCode = 1;
});
