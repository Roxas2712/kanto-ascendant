# KASC 6.7.25 — Public Test Update

Complete installable update. Published as a regular GitHub Latest release so the launcher can update it; test status is documented here. Recommended pairing: VASC 3.0.45.

## Changes since 6.7.24
- Brought standalone KASC Errors reports up to the richer shared report format. With VASC installed, the Ascendant menu continues using VASC's combined Errors screen.
- Preserve detailed errors up to 4096 characters, separate errors with different long-message tails, and retain incident-time context rather than menu-time measurements.
- Show available GPU/renderer, logical processors, Lua architecture, Lua heap, texture allocation and frame-time information near the top. Exact CPU/device model, total/free/system-used RAM and process RAM are marked unavailable when the engine does not expose them. Lua heap and texture allocation are not total process RAM or VRAM.
- Include engine/game/mod version, map position, named diagnostic details, first/last occurrence, repetition counts and nearby earlier incidents when recorded. Gameplay and graphics-check reports remain separate; earlier incidents are not automatically claimed as causes.
- Paginate readable screenshot reports with incident/session identifiers. Full text copying is supported where the host permits it; blocked clipboard access no longer appears successful. Reports are bounded, session-only and are not automatically transmitted.

## Scope and validation
The complete 6.7.24 gameplay/content baseline is retained. This update does not change Legacy Bank ownership/counts, NG+ rules, habitat puzzles or existing saves. The VASC shader, battle-button and spring-blossom changes are in the paired VASC update.

Packaged Lua syntax, archive CRC/file receipts, detailed report regressions and native standalone/combined menu checks are validated; see QA-REPORT.md. Physical Android/iPhone verification remains pending. Logs may still be needed for timing history, crashes or defects without a recorded error.

## Install
Close the game, import Kanto-Ascendant-6.7.25.zip through the launcher updater and restart. Keep your existing saves and optional artwork.
