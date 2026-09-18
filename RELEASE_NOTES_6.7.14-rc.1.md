# Kanto-Ascendant 6.7.14-rc.1 — local candidate

- Downloaded sprite maintenance shared by KASC and VASC: check/repair, reinstall, or delete downloaded packs. Interrupted operations retain a checksummed restart journal. Only download cache roots are cleared; saves, bundled art and Stadium imports remain.
- Corrupt/truncated sprite payloads, materialized copies and activation records are detected; repair downloads only affected packages. Fully clearing the download cache runs after save and restart, before mounting sprites.
- Save-local follower visibility switch, available in Game/Mod Options and VASC's quick menu. Hiding followers preserves count and custom order, including Yellow partner selection.

Local candidate only, not published. Native macOS render/input tests and phone-size touch simulations passed; no physical iPhone or Android device was tested.
