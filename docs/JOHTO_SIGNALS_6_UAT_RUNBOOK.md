# Kanto Ascendant 6.0 Signals — isolated UAT runbook

This runbook covers only the 6.0 release boundary:

- optional early Johto signals;
- the four primal traces and their pity guarantees;
- Mew/Celebi echoes, Resonance Seal, true manifestations and bound retries;
- Red, Blue and Yellow;
- English and German;
- optional original full-save upgrade copies; and
- save/restart plus disabling and re-enabling the mod.

The only non-vanilla map in these saves is the production Driftglass signal
station, `KANTO_ASCENDANT_DRIFTGLASS`. No Orange Islands, Starfall map or
experimental Lab map is used.

## Safety contract

The builder in
`tools/johto_signals_uat_save_builder.lua` aborts before writing unless all
of these are true:

1. LOVE identity is exactly `kanto-ascendant-signals-uat`;
2. `POKEPORT_IDENTITY` was explicitly set to that value;
3. `POKEPORT_VERSION` explicitly matches the live Red, Blue or Yellow
   engine; and
4. portable mode is off. A `portable.txt` marker is a hard failure.

It writes only reserved `slot6001`–`slot6099` rows inside that isolated
identity. It never searches for, edits or deletes ordinary saves.

An old save is never invented. Manual upgrade rows exist only when an
original local/player/UAT save path is supplied. The file is opened
read-only, decoded, checked for the correct game version and a safe current
map, then copied into the isolated identity. The source bytes are not
changed. Such a file is described by its real provenance; it is not called a
published save unless there is independent evidence that the save itself was
published.

Do not run the builder against a normal identity, and do not bypass one of
its assertions.

## Prerequisites

- A candidate Kanto Ascendant `6.0.3` `.modpkg`.
- A clean `gen1recomp` checkout capable of launching all three game
  versions.
- Legally supplied Red, Blue and Yellow ROM caches already prepared for the
  isolated identity.
- Original 5.3 play or release-UAT saves selected for optional full-save
  upgrade testing. Keep their real provenance and SHA-256 beside the report.

The repository's automated upgrade matrix contains three separate
schema-derived 5.3 fixtures for Red, Blue and Yellow. They pin the exact
public 5.3 package SHA-256
`ebcbdbee9f416f9c58ff675b5e97c6d35931348946817b526152fd4b423ca666`
and assert the new Signals state after restart and mod off/on. They are
sanitized test buckets, not playable or published player saves. The matrix
round-trips the complete constructed save through the engine's native
`SaveData.encode/decode` boundary and also checks:

- pre-Hall-of-Fame Yellow does not receive postgame onboarding or a warp;
- an active 5.3 `johto_migration` world event remains unchanged;
- owned Mew/Celebi repair contradictory legacy completion state;
- Signals starts in Kanto First without a hidden roll, choice or false trace;
- party, boxes, Bag order, money, trainer flags and return points do not move.

The Yellow
partner and Mega subtrees are additionally corroborated by the local 5.3
release-UAT file
`releases/yellow-partner-manual-test/slot3-heart-mega.lua`; no equivalent
original Red or Blue player save is currently claimed by this repository.

Run the package boundary audit before creating saves:

```sh
cd /Users/maarten/Documents/Recompile/kanto-ascendant-6.0-current
python3 tools/johto_signals_release_audit.py \
  /absolute/path/to/kanto-ascendant-6.0.3.modpkg
```

Use `tools/johto_signals_launcher_smoke/` to import the actual current
5.4.1 package
and then replace it with the actual 6.0 package under the same isolated
identity. That smoke tool has its own identity guard. Do not substitute the
source directory for this final package gate.

## Build the native UAT slots

The driver must be launched from the `gen1recomp` root because it deliberately
uses the engine's native `SaveData`, `Pokemon`, `Boxes`, `Bag` and map
implementations.

Run it once per version:

```sh
cd /Users/maarten/Documents/Recompile/gen1recomp
LOVE_BIN=/Users/maarten/Documents/Recompile/gen1recomp/.tools/love-11.5-macos/love.app/Contents/MacOS/love

POKEPORT_IDENTITY=kanto-ascendant-signals-uat \
POKEPORT_VERSION=red \
POKEPORT_DRIVER=/Users/maarten/Documents/Recompile/kanto-ascendant-6.0-current/tools/johto_signals_uat_save_builder.lua \
"$LOVE_BIN" .

POKEPORT_IDENTITY=kanto-ascendant-signals-uat \
POKEPORT_VERSION=blue \
POKEPORT_DRIVER=/Users/maarten/Documents/Recompile/kanto-ascendant-6.0-current/tools/johto_signals_uat_save_builder.lua \
"$LOVE_BIN" .

POKEPORT_IDENTITY=kanto-ascendant-signals-uat \
POKEPORT_VERSION=yellow \
POKEPORT_DRIVER=/Users/maarten/Documents/Recompile/kanto-ascendant-6.0-current/tools/johto_signals_uat_save_builder.lua \
"$LOVE_BIN" .
```

Each run validates every generated save against the currently merged game
data, writes it through the native slot API, reads it back from disk and
decodes it again. The run ends with `PASS` or an assertion; do not treat a
partial run as usable.

It also writes a machine-readable manifest inside the isolated identity:

```text
uat/johto_signals_red_manifest.lua
uat/johto_signals_blue_manifest.lua
uat/johto_signals_yellow_manifest.lua
```

The manifest records the actual safe cell selected on each map, every slot,
the expected action and whether real upgrade copies were seeded.

### Seed real upgrade copies

One source:

```sh
LOVE_BIN=/Users/maarten/Documents/Recompile/gen1recomp/.tools/love-11.5-macos/love.app/Contents/MacOS/love
KA_SIGNALS_UPGRADE_RED_SAVE=/absolute/path/to/original-5.3-red-save.lua \
POKEPORT_IDENTITY=kanto-ascendant-signals-uat \
POKEPORT_VERSION=red \
POKEPORT_DRIVER=/Users/maarten/Documents/Recompile/kanto-ascendant-6.0-current/tools/johto_signals_uat_save_builder.lua \
"$LOVE_BIN" .
```

Several releases can be supplied in chronological order, separated by
semicolons:

```sh
LOVE_BIN=/Users/maarten/Documents/Recompile/gen1recomp/.tools/love-11.5-macos/love.app/Contents/MacOS/love
KA_SIGNALS_UPGRADE_RED_SAVES='/abs/original-1.x.lua;/abs/original-5.3.lua' \
POKEPORT_IDENTITY=kanto-ascendant-signals-uat \
POKEPORT_VERSION=red \
POKEPORT_DRIVER=/Users/maarten/Documents/Recompile/kanto-ascendant-6.0-current/tools/johto_signals_uat_save_builder.lua \
"$LOVE_BIN" .
```

Use `BLUE` or `YELLOW` in the environment-variable name for those games.
The builder assigns genuine copies to `slot6090` onward. If neither variable
is supplied, the manifest says `seeded = 0`; upgrade UAT is then **NOT
EXECUTED**, not PASS.

The reduced Lua tables under `tests/fixtures/` are automated migration
fixtures, not playable or published player saves. They prove schema
migration and Signals initialization; they must not be presented as manual
full-save upgrade evidence.

## Language matrix

Ascendant's language selection is a global mod option stored in the isolated
identity, not a field inside an individual save. Therefore separate “English
save” and “German save” files would be fake.

The builder starts the isolated profile in English. Complete the relevant
slot once with:

```text
OPTIONS → ASCENDANT → LANGUAGE → ENGLISH
```

Then reload the untouched checkpoint and repeat with:

```text
OPTIONS → ASCENDANT → LANGUAGE → DEUTSCH
```

For each language, verify the complete dialogue chain, choice text, Journal,
Atlas location, mode labels, `???` before a real sighting and the revealed
name afterwards. Repeat the matrix in Red, Blue and Yellow.

## Checkpoints and binary acceptance

| Slot | Start | Action | PASS condition |
|---|---|---|---|
| 6001 | Pallet, step 127/128 | Walk one step, inspect, decline, leave/re-enter | Offer appears once; NO is safe and repeatable after re-entry |
| 6002 | Pallet, capsule ready | Accept; talk to boatman | Warning names Driftglass and promises a return route |
| 6003 | Driftglass, pre-repair | Save/restart; confirm Pallet resume; sail back; repair; test both boats | Written slot resumes at Pallet; stage persists; neither boat traps the player |
| 6004 | Route 1, Kanto First | Fight 30 eligible native battles | No Johto replacement; native results remain unchanged |
| 6005 | Route 1, Wanderwaves normal | Sample eligible battles | Badge pool is correct and displayed rate is 2 percent |
| 6006 | Route 1, Wanderwaves strong | Sample eligible battles | Badge pool is correct and displayed rate is 4 percent |
| 6007 | Route 1, Johto Unleashed | Sample several authored habitats | Displayed rate is 10 percent and species fit each habitat |
| 6008 | Viridian Forest, trace locked | Scan current area | Only forest trace unlocks; species remains `???` until seen |
| 6009 | Route 6, trace locked | Scan current area | Only coast trace unlocks |
| 6010 | Mansion B1F, trace locked | Scan current area | Only ember trace unlocks |
| 6011 | Victory Road 3F, trace locked | Scan current area | Only stone trace unlocks |
| 6012 | Route 24, forest pity 511 | Trigger the 512th eligible grass battle | Chikorita appears; Repel or protected encounter cannot burn pity |
| 6013 | Seafoam B2F, coast pity 511 | Trigger the 512th eligible cave battle | Totodile appears |
| 6014 | Mansion B1F, ember pity 255 | Trigger the 256th eligible battle | Cyndaquil appears |
| 6015 | Victory Road 3F, stone pity 255 | Trigger the 256th eligible battle | Larvitar appears |
| 6016 | Route 1, first echo pity 511 | Battle it; inflict status; throw Master Ball; try RUN | Echo stays at 1 HP, rejects capture and escape, restores the Master Ball and battles until party defeat |
| 6017 | Driftglass, three echoes/three badges | Ask researcher for the seal | Refusal clearly requires the fourth badge; state does not advance |
| 6018 | Driftglass, three echoes/four badges/full Bag | Ask researcher for the seal | Seal is granted atomically despite full ordinary Bag |
| 6019 | Route 1, true pity 8191 | Start next eligible native grass battle | An enabled, unowned Mew or Celebi manifests |
| 6020 | Route 1, bound Mew retry 31 | Trigger next eligible battle | Same Mew returns with recorded 17 HP and paralysis |
| 6021 | Route 1, bound Celebi retry 31 | Trigger next eligible battle | Same Celebi returns with recorded 23 HP and sleep |
| 6022 | Route 1, live Signals state and boxed Chikorita | Save; disable mod; load/save; re-enable | Native-map load is safe; boxed mon, Dex and both counter sections return without loss |
| 6023 | Celadon, postgame, early-owned Chikorita | Complete Verdant starter trial | Research acknowledges known species and grants compensation, never a duplicate |
| 6024 | Driftglass, live Signals state and boxed Chikorita | Save on Driftglass; disable mod; load and save; re-enable | Written save resumes at Pallet landing; no unknown-map crash; boxed mon, Dex and counters return |
| 6025 | Driftglass, repaired receiver and Johto Unleashed | Enter the second glass seam; solve, fail and replay Prism inscriptions | Grotto is reachable; rewards never duplicate; full-Bag rewards wait; Twilight Mirror requires Eevee |
| 6026 | Pallet, direct-start choice pending | Choose YES; fully quit; continue the same slot | Wanderwaves remains active and the onboarding question does not return |
| 6027 | Pallet, direct-start choice pending | Choose NO; fully quit; continue the same slot | The field quest remains active and the onboarding question does not return |
| 6028 | Route 1, complete National Dex test gallery | Browse #152–251 and open representative species pages | Every Johto species uses its authentic Crystal art/data and individual legacy cry |
| 6090+ | Original source copy with recorded provenance | Load, inspect, save, restart, disable/re-enable | No data loss, false Dex reveal, custom-map trap or reset counter |

For pity rows, first trigger one protected/scripted encounter or activate a
Repel where applicable and confirm the guarantee remains armed. Then trigger
the eligible native encounter. This proves the transactional ownership rule,
not only the denominator.

## Save/restart and mod off/on

For every major phase (capsule, repaired receiver, one trace, three echoes,
sealed, bound roamer):

1. record the displayed state and counters;
2. save normally;
3. fully quit to the launcher;
4. continue the same slot;
5. verify map, team, Bag, Dex, Journal and counters;
6. make one eligible encounter and verify only the expected counter changes.

Use slot 6022 for the destructive edge case:

1. export a copy from the isolated identity;
2. disable `trainer_rematch` in the launcher;
3. load and save the slot on native Route 1;
4. quit;
5. re-enable the exact 6.0 candidate;
6. load again and verify Chikorita, Pokédex ownership, Migration Receiver,
   early-Johto pity and Mythic echo progress.

A safe boot with lost state is FAIL. A launcher warning followed by complete
restoration is acceptable only if that warning is expected and recorded.

## Evidence sheet

Record one row per slot, version and language:

```text
Package:
SHA-256:
Engine commit:
Identity: kanto-ascendant-signals-uat
Version: red | blue | yellow
Language: en | de
Slot:
Source provenance (upgrade rows only):
Action:
Expected:
Actual:
PASS / FAIL:
Screenshot or log:
Save/restart checked:
Mod off/on checked:
```

Final acceptance requires:

- all generated rows PASS in Red, Blue and Yellow;
- every dialogue-sensitive row PASS in English and German;
- schema-derived 5.3 upgrade fixtures PASS separately for Red, Blue and
  Yellow, including Signals initialization, restart and mod off/on;
- every original full-save source that was actually supplied PASS with its
  provenance recorded; absent Red/Blue sources remain NOT EXECUTED and are
  never replaced by synthetic evidence;
- package audit PASS;
- launcher replace-import PASS; and
- no UAT slot or manifest in the player's ordinary identity.

Anything not executed is reported as **NOT EXECUTED**, never inferred from an
automated fixture and never marked PASS.
