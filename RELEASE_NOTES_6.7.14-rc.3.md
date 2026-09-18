# Kanto Ascendant 6.7.14-rc.3 — private test candidate

Based on the agreed 6.7.14 sprite-maintenance line and rc.2 save-size hotfix.

- Publishes the actual source-card pixel density for animated and static VASC fronts, so high-resolution artwork no longer becomes a physically oversized Pokémon. Pair with VASC 3.0.28-rc.4.
- Retains the full artwork when large form cards extend above the former canvas edge. Physical size remains based on Pokédex measurements; active form height survives VASC finalization. Classic 2D artwork is unchanged.
- Includes the independently prepared visible-Wilds discovery counter / 50-encounter guarantee and Swagger/Flatter confusion fixes, integrated as the narrow d6c3121 patch and regression-tested again.
- Retains rc.2 lossless save-text compaction, sprite maintenance, follower visibility and iOS support. No save migration and no Pokémon/boxes removed.

This is a local review build, not a published release. Automated catalog/provider tests and selected native battle captures are documented in the accompanying test report. No physical mobile-device test.
