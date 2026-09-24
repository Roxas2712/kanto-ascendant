# Kanto Ascendant 6.7.23 — Legacy Bank NG+ fix

Update based on 6.7.22. Recommended pairing: VASC 3.0.40.

## Fix and recovery

- Reloading the previous save after a committed NG+ handoff no longer marks its Pokémon as withdrawn from the new journey's Bank. The interrupted New Game can still be retried through Oak.
- Previous-run saves cannot withdraw, deposit, rearrange or release Pokémon in a Bank that has already moved to the next journey. The menu explains which save to use.
- Affected current saves automatically recover obsolete withdrawal markers when the stored NG+ transaction, rollback save and Pokémon identities prove the transfer. Pokémon already in the current party, PC or Day-Care remain withdrawn. Unverifiable or unrelated leases are left untouched.
- Individual and bulk withdrawal use the same recovery rules. Recovery uses the Bank's existing verified write/backup mechanism and is safe to repeat; it does not change the save schema.

## For affected players

Back up your save folder, including mod_storage. Close the game, install this complete update through the launcher, then load the affected **new NG+ save** and open Legacy Bank. No manual Bank-file replacement or new NG+ reset is required for the verified failure pattern. If the count remains wrong, keep the backups and provide the matching save and Bank export for review.

The Bank counts individual Pokémon; the Pokédex counts species. A partially occupied first Bank box does not represent the full Bank. This update does not restore a previous journey's caught-species total.

## Validation

Regression coverage includes Red, Blue and Yellow; pending-handoff retry; existing affected saves; current PC and Day-Care identities; single/bulk withdrawal; repeated loads; rejected foreign-run operations; incomplete provenance; and write failures. A private supplied-save replay verifies recovery without shipping player data. See the companion QA report for final results and platform limits.
