# Kanto Ascendant 6.7.11-rc.1

Public release candidate — manual preserving desktop installation.

## This transition

- Optional Pokémon graphics are managed through the in-game download/import
  pages instead of being bundled again in the mod. KASC alone exposes its
  301-package catalogue; with VASC, both entries use the shared content session.
- Installed files omitted by the new package are preserved by the supplied
  external installer. A verified full backup is created before replacement.
- KASC includes its own fullscreen presentation for Start/options, feature
  menus, downloads, Bag, party, summary and PC storage. With VASC enabled,
  local presentation yields to VASC; KASC entries and gameplay remain active.
- Native PC capacity remains at least 60 boxes of 20 Pokémon. Existing saves
  are extended without removing occupied boxes; larger existing stores stay.

## Installation — important

Use the accompanying `.tar.gz` preserving installer. Close the game and its
launcher, extract the entire archive and run `python3 install.py` (Windows:
`py -3 install.py`). Python 3.8+ and space for a complete backup are required.
Select the exact mod folder inside your game's `mods` directory.

Do NOT rename `mod.payload` to ZIP or import it with the engine's ordinary ZIP
replacement. That path deletes old omitted files and cannot preserve your
previously bundled Pokémon graphics. Update KASC and VASC one at a time.
No ROM or save is included. Do not copy another person's options or save.

## Scope of verification

macOS native solo and KASC+VASC menu tests; normal/portable DLC download,
import, restart, GPU loading and explicit package deletion; storage migration,
Box 60 serialization and full/overflow behavior; guarded UI ownership and
language-regression tests. Exact final package/install receipts accompany the
release. No physical Windows, Linux, Android or iOS verification is claimed.

Old loose sprites remain usable; they are not falsely labelled as a complete
verified download package. The package manager's delete operation manages
downloaded packages, not every historical loose file in a mixed installation.
Original-scanner image flags remain documented maintainer-disputed findings,
not an external clean-scan approval. This is a pre-release, not an unrestricted
certification of every historical feature or every platform.
