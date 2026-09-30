# Kanto Ascendant 6.7.31 — volcano audio and visitor fixes

- Plays one native transition cue after each successful scripted volcano stair link. Failed transitions stay silent.
- Uses Gym music in Blaine's corridor and battle chamber; keeps Dungeon music at the volcano foot.
- Supplies exact stair metadata for the matching VASC route geometry without changing collision or destinations.
- Declining honey no longer makes the Hoenn visitor disappear as her visit timer expires. She stays until the player leaves the house, then resumes her normal return schedule; the reward remains one-time.
- Makes rival spectator-duel Pokémon available to VASC's follower-style selection while retaining KASC's actor movement and lifetime.

Update together with **VASC 3.0.58** for the restored gatehouses, continuous glass-door view, lava battle arena, 3D stairs and seated visitor. Complete public 6.7.30 integration retained; no new save required.

The paired candidates passed 25 targeted suites and native desktop checks. A controlled Gorochu/Arcanine entry test found Intimidate lowering temporary Attack only; the user's uncertain historical stat change was not reproduced. No stat or ability logic changed. See the attached QA report for precise coverage.
