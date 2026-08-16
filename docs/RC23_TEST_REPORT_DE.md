# Kanto Ascendant 6.5.0 RC23 – Testbericht

Stand: 11. August 2026

## Ergebnis

RC23 besteht die Quell-, Laufzeit-, E2E- und Paketprüfungen. Es wurden keine
Höhlenkarten oder Tür-Questinhalte aus Package 3 vorweggenommen. Die 19
gezielt freigegebenen Arten sind als getrenntes Kompatibilitätsmodul auf
#261-279 registriert, erhalten aber noch keine automatischen Wildhabitate.

## Automatisierte Einzelprüfungen

- Vollständige Kanto-Ascendant-Suite: **6599/6599**
- HEVO-Arten, Dex, Assets, Attackenfilter und Entwicklungen: **295/295**
- Johto Signals einschließlich exakter 19er-Allowlist: **2487/2487**
- Johto-Signals-/Wilds-Adapter: **243/243**
- Wilds-Vertrag 1.7.1: **65/65**
- Wilds-Vertrag 1.12.2: **67/67**
- Vermächtnisarchiv und Reset-/Preserve-Vertrag: **90/90**
- Vermächtnisreise und Charakterzustände: **17/17**
- Verdiente Hoenn-Starter: **14/14**
- Frühe charaktergebundene Vermächtniswege ohne VM-/Champ-Gate: **23/23**
- PC-Regelkonfiguration und Laufsperre: **37/37**
- Psiana im echten Erfahrungs-/Attacken-Erinnerer-Pfad: **432/432**
- Phase-9-Kernregression: **31/31**
- Phase-10-Releaseaudit: **28/28**
- Crystal-Learnset-Kompatibilität: bestanden
- Deterministischer Crystal-Learnset-Audit: bestanden; `FALSE_SWIPE` ist nun
  real registriert, deshalb verbleiben **47** statt 48 nicht verfügbare
  Crystal-Attacken.
- Johto-Scope-Audit: bestanden
- `git diff --check`: bestanden

Die HEVO-Projektion überspringt insbesondere `ROLLOUT`, `ANCIENTPOWER`,
`DOUBLE_HIT`, `MIRROR_COAT`, `SAFEGUARD` und `DESTINY_BOND`, solange keine
vollständige Kampfmechanik vorhanden ist. Es wurden dafür keine No-op-Attacken
registriert. Die betreffenden Entwicklungspfade verwenden stabile, derzeit
noch nicht vergebene `HEVO_*_RELIC`-IDs.

## Echter LÖVE-E2E-Lauf

Der NG+-Treiber lief in einer echten Gen1-Recomp/LÖVE-Instanz mit
**42/42** bestandenen Prüfungen. Abgedeckt wurden normale Regeln,
Randomizer/Nuzlocke-Regeln, das Sperren nach Reisebeginn, der direkte Weg zu
Eich, die Vermächtnisbank, drei Siegel plus aktueller Champ,
`HEVO_DOOR_QUEST_READY` (einmalig konsumierbar) und der tatsächlich verdiente
Flemmli-Ball bei Eich.

Bildnachweise:

1. `qa/rc23-ngplus-johto/01_run_rules_main.png`
2. `qa/rc23-ngplus-johto/02_randomizer_rules.png`
3. `qa/rc23-ngplus-johto/03_nuzlocke_rules.png`
4. `qa/rc23-ngplus-johto/04_run_rules_locked.png`
5. `qa/rc23-ngplus-johto/05_direct_oak_handoff.png`
6. `qa/rc23-ngplus-johto/06_legacy_bank.png`
7. `qa/rc23-ngplus-johto/07_earned_torchic_oak_card.png`

## Paketprüfung

- Launcher-Paket: **27.705 Archiveinträge**, Manifest-ID
  `kanto_ascendant`, Version `6.5.0`
- Erforderliche HEVO-/NG+-Laufzeitdateien: vollständig
- QA-, Test-, Tool-, Quellasset- und Release-Notiz-Leaks: **0**
- ZIP-Integrität: bestanden
- Strikte Fixture-Validierung des entpackten Pakets: bestanden
- `.modpkg` und Test-`.zip` sind bytegleich
- Rollback ist eine bytegleiche Kopie des abgenommenen RC22

SHA-256:

- RC23 `.modpkg`/`.zip`:
  `82f734cad1cd6e50eaa2e795086631c6f8a35c3590709cbc752dd1b52900c058`
- RC22-Rollback:
  `773da89f5ae67de963d3135b74e6c85e72de0b2129023d3bff5e74b0eb9dbb09`
