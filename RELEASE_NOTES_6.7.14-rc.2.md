# Kanto Ascendant 6.7.14-rc.2 — Save-size hotfix

Built on the complete, agreed 6.7.14-rc.1 package. Sprite maintenance,
follower visibility and the existing iOS support fixes remain included.

KASC game saves now omit unnecessary formatting whitespace outside quoted
strings. Pokémon, boxes, party, progress, mod data and text values are kept.
The original engine serializer, parser, backup procedure and save format
remain in use. Options and saves without a KASC data bucket are unchanged.

After updating, fully restart the game, load the affected save, save normally
once, then retry Sync. Existing files are not rewritten during installation.
The 2 MiB server/client limit is unchanged: sufficiently large saves may still
exceed it. This is compact text, not gzip and not an alternative cloud service.

Validation with LÖVE/LuaJIT and engine 0.2.57 / 0.2.61 core modules:
- Two real save backups: 603,478 -> 325,581 and 606,894 -> 327,363 bytes.
- Synthetic 2,400-Pokémon save: 2,352,692 -> 1,016,822 bytes. The unchanged
  SyncClient rejects the original and accepts the compact request.
- Every parsed key, type and value retained, including all byte values,
  quotes, backslashes, physical escaped newlines, sparse keys and nested data.
- Mod sandbox, Red/Blue/Yellow slot writes, normal saves, cartridge saves,
  backup preservation, simulated failed writes and unmodified-reader rollback.

Local test candidate. No public release, live-server upload, or physical
iPhone/Android test is claimed. The screenshot reporter's save was not supplied.

For a desktop update that preserves previously installed optional graphics,
use the accompanying preserving installer. The ordinary full ZIP follows the
engine's replacement-import behavior. Rollback: restore the prior mod folder
backup and restart; compact saves remain readable by the original engine.
