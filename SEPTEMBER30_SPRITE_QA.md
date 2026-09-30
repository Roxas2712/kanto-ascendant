# KASC 6.7.29-rc.4.pyro.2 — explicit Crystal colours

Companion to VASC 3.0.57-rc.12; based on the compact-Pyro candidate. Only Crystal display-variant selection changes: an explicit encounter-local Crystal choice bypasses the saved Classic style for Gorochu, for static and animated front/rear normal/shiny art. Native monochrome colour modes and unforced Classic/AUTO remain unchanged; menus retain authored colours. Saves and gameplay are not modified.

`tests/crystal_explicit_style_test.lua` reproduced the grayscale static selection before the fix and passes after it. It covers normal/shiny, both sides, animation advancement, ordinary Classic/AUTO, native monochrome and menu art. The paired VASC isolated native test displays coloured Gorochu against Starmie and returns to Route 5 three times. A separate native TERARRIUM run explicitly combines saved KASC Classic with VASC Crystal, verifies coloured Gorochu and completes another return. Optional art is a QA dependency with a matching pinned manifest hash; it is not added to this base package.

Retains the rc.4.pyro.1 compact arena, native routes, rewards and story guards. Without KASC, VASC retains the original Pyro gym. No public release or live installation was performed.
