# Kanto Ascendant 6.7.30 — integrated Hoenn NG+ and Blaine volcano

- Combines the complete public 6.7.29 / latest integration base with Hoenn NG+, the revised Hoenn visitor, Blaine's volcano route and the Crystal colour correction. Keeps the embedded startup/loading screen, character/wardrobe integration, Wilds and memory/performance fixes.
- Restores eligible previously caught Hoenn families as base forms in the shared NG+ habitat pool. Latias and Latios can roam in NG+ with the Hoenn Dex; the visitor uses revised Gen-1 artwork and visit scheduling.
- Moves Blaine from the original final Gym room through a connecting tunnel and volcano approach to a compact battle platform. Preserves the quiz, existing saves, native story battle, Volcano Badge, Fire Blast and Master/Crown recognition.
- Keeps Gorochu's normal/shiny colours when Crystal battle graphics are explicitly selected, including the static fallback. Intentional Classic/native monochrome palettes remain supported.

Recommended companion: **VASC 3.0.57**. No new save is required. This replaces the incomplete local 6.7.29-rc.4.pyro.1/.2 companion, which had accidentally been based on 6.7.28. The unfinished, separate Sevii expansion is not included.

13 targeted regression suites plus native startup/continue, save/reload, Blaine route/battle-entry/reward/return checks passed. The reward test completes the native battle callback with a fixture victory; it is not an AI or balance test.
