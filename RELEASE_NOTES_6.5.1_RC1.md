# Kanto Ascendant 6.5.1 RC1 – Gen1Recomp 0.1.90 compatibility

This patch release supersedes the incompatible 6.5.0 package for the current
Gen1Recomp client.

## Compatibility repair

- The manifest now requires Gen1Recomp `>=0.1.90`, so the current mod manager
  can enable Ascendant instead of showing the 6.5.0 package as incompatible.
- The mod version is 6.5.1, allowing the manager to offer it as a real update.
- The exact 0.1.90 Player-PC and Bag surfaces retain the guarded ASC RUN and
  Apricorn Ball preview bridges.
- The matching clientfix includes the flat wall-decal renderer required for
  visible discovered HEVO fissures, as well as the reviewed Legacy storage
  and sandbox hardening.
- The approved Voxel companion is supplied as
  `DRAMALESS_SHAPE-1.6.2-ST.190.zip` with one root `manifest.json`.

## Installation

1. Close the game.
2. Start the supplied Gen1Recomp 0.1.90 clientfix in an isolated test setup.
3. Import the Ascendant 6.5.1 ZIP itself, not the outer complete-bundle ZIP.
4. Optionally import the supplied DRAMALESS `.zip` and enable it.
5. Leave the conflicts reported by the manager disabled, then restart.

Existing Red, Blue and Yellow saves remain supported. The repair does not
require deleting or replacing a save.
