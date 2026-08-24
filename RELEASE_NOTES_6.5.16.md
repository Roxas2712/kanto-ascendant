# Kanto Ascendant 6.5.16 — FireRed PC, Bag and Legacy Bank

Kanto Ascendant 6.5.16 is a save-compatible interface update for Pokémon Red,
Blue and Yellow. No new game, story reset or archive migration is required.

## FireRed / LeafGreen PC

- The new default is a readable 480×320 FireRed / LeafGreen organizer.
- Each normal PC Box has its own cycling wallpaper and matching title fill.
- Normal/Shiny and configured Crystal sprites, nickname, species, level and
  gender use KASC's existing authorities.
- The transparent hand carries the selected Pokémon while Boxes are changed
  or the view slides between Box and Party.
- Pokémon can swap or move across Boxes and Party. At least one Party Pokémon
  remains protected, Box/Party limits remain authoritative, and `CLOSE BOX`
  cancels an uncommitted carry safely.
- Changing a Box is navigation and no longer jumps to a save confirmation.

Use **ASCENDANT OPTIONS → PC INTERFACE** to select `FIRERED / LEAFGREEN`, the
former `KANTO ASCENDANT` blue/cream view, or `GAME DEFAULT`. A missing or
invalid FireRed atlas falls back to the Kanto Ascendant renderer.

## Legacy Bank

- The Legacy Bank uses the matching FireRed organizer when that PC style is
  active. The previous list view remains the fallback for the other styles.
- Run locks and extended-species withdrawal gates are shown on the Pokémon and
  open their complete bilingual reason instead of hiding the stored entry.
- Bank slots persist. Pokémon can move between Bank slots, into the Party, or
  from the Party back to a chosen Bank slot through the archive's existing
  staged save-safe operations.
- The UI begins with 500 virtual 20-slot Boxes. Empty pages are not written to
  the archive. Wallpapers repeat cyclically, and Box 501 appears only when all
  10,000 initial slots are occupied; the same rule continues without a fixed
  final capacity.

## FireRed Bag

- `FIRERED POCKETS / 999` is the new default Bag mode.
- Six pockets, persistent SELECT ordering, START help, optional R3 actions,
  Field Kit, Quick Select, battle filtering, USE/TOSS and rare/key-item safety
  are preserved. This update changes presentation, not item authority.
- `KASC SKIN`, `KASC SKIN / 999`, `GAME DEFAULT` and external-owner OFF modes
  remain selectable.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.16.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.16.txt`.
