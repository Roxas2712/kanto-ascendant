# Kanto Ascendant 6.7.8 — Story Level Cap Hotfix

Fixes the empty Story Level Cap after defeating Misty and before obtaining Cut. The next undefeated Gym remains the cap while its route is being opened. This also covers the route gaps before Koga and Blaine; accessible Gyms still take priority for nonlinear progress.

CUSTOM can again edit the current and upcoming milestones during these intervals. RESET CURRENT and RESET ALL restore the derived caps by clearing custom overrides. No save reset or migration is required.

Built directly on the published 6.7.7 package, retaining all earlier fixes. Import the new mod ZIP and fully restart the game. Requires Gen1 Recomp 0.2.57 or newer.

## Reproduce and verify

Download the published 6.7.7 ZIP, then run:

```sh
python3 hotfixes/6.7.8/build.py /path/to/kanto_ascendant-6.7.7.zip /path/to/output
python3 hotfixes/6.7.8/verify.py /path/to/output/packed /path/to/engine-0.2.57 /path/to/gen1recomp-source --results /path/to/results.json
```

The verifier uses LuaJIT by default; `--runner` accepts an alternative LuaJIT runner. Coverage includes all Kanto badge intervals in Red/Blue/Yellow, nonlinear progression, current/upcoming Custom edits, Reset Current/All, daycare and menu behavior, League/Champion and Master-Circuit selection, and full-package Mod SDK loading with engine 0.2.57. The test suite uses fixtures; no physical mobile-device test was performed.

Only story_level_cap.lua, manifest.json and the package hash index change inside the download. No level values are hardcoded and no save fields are migrated. Rollback: reinstall the published 6.7.7 ZIP.
