# Kanto Ascendant 6.7.22 — Public Test Update

Complete installable update, published as a regular GitHub release so the launcher updater can detect it. Testing status is described here; the GitHub prerelease flag is not used. Recommended pairing: VASC 3.0.40.

## Changes since 6.7.21
- Added an Errors submenu with readable, screenshot-friendly reports, report IDs, pagination and touch navigation. Repeated reports are grouped; reports stay local and session-only with no automatic transmission.
- Download introductions now appear once per installation. They remain manually accessible in the Ascendant menu. The matching VASC update applies the same rule independently to the Your Look setup guide.
- Ordinary updates and new saves do not repeatedly reopen the introductions. Separate maintainer-controlled revision counters allow a deliberate future re-invitation.
- Updated the shared content-session integration, including mixed-version compatibility, and removed the obsolete every-start download prompt option.

## Validation and scope
Packaged Lua syntax, focused startup/report tests, archive integrity and a preserving update-install fixture are checked. Final runtime/package results are in QA-REPORT.md.

This update does not change Legacy Bank/NG+ inventory or Pokédex rules. The reported bank-count discrepancy is deferred pending the separate bank archive and affected save; no repair is claimed. Existing habitat, Regi wayfinding, wardrobe and setup integration from 6.7.21 remain included.

## Installation
Close the game and import the complete ZIP as an update to kanto_ascendant through your launcher. Restart after updating. Keep your existing saves and optional artwork. No engine, ROM or player save is included. For reports, include version, device and an Errors screenshot; attach the session log for deeper investigation.
