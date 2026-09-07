# Kanto Ascendant 6.7 RC2 — Custom Carts & Live VASC

Public pre-release. Stable 6.5.22 is not replaced.

## Changes from RC1

Compatibility only: explicit admission of live **VASC RC66g / 3.0.0-rc.15**.
Only manifest, renderer admission and archive metadata changed. Gameplay and
assets are byte-identical to RC1. No VASC code was edited.

Three Custom Carts: **Red, Blue and Yellow**, retaining original covers and
Cart/save identities. Required pair: **KASC 6.7.0-rc.2 + VASC 3.0.0-rc.15**.

## Installation

Use a Recompiler supporting Custom Carts and mod indexes (tested host 0.2.56).
Supply your own matching game ROM; none is distributed here.

1. Back up saves and download the `.g1rcart` for your edition below.
2. Add this feed in the launcher's **Find mods** sources:

   https://raw.githubusercontent.com/Roxas2712/kanto-ascendant/codex/kasc-6.7-card-distribution/kasc-card-index.json

3. Import/open the Cart, install its pinned mods, then Play.

The index supplies exact prerelease versions: this host's direct GitHub
lookup truncates their suffixes. Cart SHA256 checks remain enforced.
Alternatively import both exact mod ZIPs manually before opening the Cart.
Do not install GitHub's automatically generated “Source code” archives.

Existing Cart identities are retained. Ordinary non-Cart saves can have a
different launcher scope; automatic migration is not promised. Back up first.

## Limits

RC1's unfinished mechanics remain unfinished/inactive: later move/item/
ability effects, missing form artwork, Gigantamax battles and Link battles
are not newly enabled. Full physical-device and sprite review is separate.

**Riolu gift limitation:** Riolu can hatch and battle, but its evolution to
Lucario is missing in RC1 and this compatibility-only RC2. A separate gameplay
hotfix is next. Backend registration alone does not implement evolution rules.

VASC retains its own published limitations, including the separately reported
graphics-resource issue; this release does not claim to fix those.

Carts pin this tested pair, not arbitrary future VASC. Updating the pair
requires a new reviewed Cart version. The host allows deliberately breaking
the seal; this is not DRM.

## Provenance

KASC: `60cf3ea2a5cd905d202063895939c4d6e1d1058b137e2d2d40f12480a6ac1a40`

VASC: `e054242d9c56bb967bd0345d8ddd054d70c3b566a97f4be2f0e302f61c4bd3ea`

This tag holds distribution records. Runtime Lua/assets are in the installable
ZIP, not the automatic source snapshot. RC1 remains unchanged for rollback.
