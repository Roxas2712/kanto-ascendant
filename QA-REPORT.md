# KASC 6.7.26 validation

Date: 2026-09-25. Full package retains 6.7.25.

4,402 contract checks and menu/dialogue regressions passed. Native Red checks cover music playback in all twelve habitats, battle takeover and return, route exit, Mira's style switching and four facings, and the dialogue/accept/pause/party/cancel flow. Package Lua syntax and archive checks are documented in QA-REPORT.md. No new physical phone test or full playthrough is claimed.


Packaging: every Lua file is compiled with the bundled Lua runtime; ZIP CRC and byte-for-byte source equality are checked. Embedded receipts, where present, are regenerated and verified. Public asset digests and anonymous downloads are verified after upload.

Limits: native tests use Red on macOS; no fresh native Crystal, physical phone/console test or complete playthrough is claimed. No changes to save-file formats.
