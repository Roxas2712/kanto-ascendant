-- Exact installed-package upgrade matrix for L01 / DRV-UPGRADE-MATRIX-PACKAGE.
--
-- This source manifest is deliberately independent of the generated final
-- same-hash plan/receipt.  The package freeze may consume these cells to
-- replace the historical L01 blocker, but source/headless PASS is never a
-- substitute for the four clean LÖVE processes named by each cell.

local DRIVER = "tests/upgrade_matrix_package_driver.lua"
local PHASES = { "stage", "migrate", "disabled", "reenabled" }
local EDITIONS = { "red", "blue", "yellow" }

local sources = {
  {
    key = "v6_0_11",
    slug = "6-0-11",
    archiveName = "kanto-ascendant-6.0.11.modpkg",
    archiveBytes = 16662061,
    archiveSha256 = "72779b0a9923e2e3908573552858718aa09bc6eae25222d1268bf3f1e41b62e7",
    expectedInitialRuleState = "unlocked",
  },
  {
    key = "rc25",
    slug = "rc25",
    archiveName = "kanto-ascendant-6.5.0-rc25-test.zip",
    archiveBytes = 37749193,
    archiveSha256 = "9d340d9badf940adc7bd1a36b43d66a4d02b84229a63df8c5caa85939fdab9a5",
    expectedInitialRuleState = "unlocked",
  },
  {
    key = "rc26",
    slug = "rc26",
    archiveName = "kanto-ascendant-6.5.0-rc26-test.zip",
    archiveBytes = 37794577,
    archiveSha256 = "0b0fcd765a1dd6d64584d2dd5c116bbabf9a8218c77314e7d5de5937d63e2418",
    expectedInitialRuleState = "locked",
  },
  {
    key = "rc27",
    slug = "rc27",
    archiveName = "kanto-ascendant-6.5.0-rc27-test.zip",
    archiveBytes = 37983841,
    archiveSha256 = "fb870c51b22ac87be7a3c79ec98e6fe798196946c96abec439e5915d99af5912",
    expectedInitialRuleState = "locked",
  },
}

local required = {
  "status=PASS",
  "scope=UPGRADE-MATRIX-PACKAGE",
  "provenance=schema-derived-sanitized",
  "published_save=false",
  "archive_verified=1/1",
  "migration=1/1",
  "rules_select_or_preserve=1/1",
  "final_rule_lock=1/1",
  "native_save_reload=1/1",
  "failed_write_rollback=1/1",
  "backup_rollback=1/1",
  "rollback_shadow=1/1",
  "disable_quarantine=2/2",
  "reenable_restore=2/2",
  "data_equality=1/1",
  "fail=0",
}

local cells = {}
for _, source in ipairs(sources) do
  for _, edition in ipairs(EDITIONS) do
    local contains = {}
    for index, value in ipairs(required) do contains[index] = value end
    contains[#contains + 1] = "edition=" .. edition
    contains[#contains + 1] = "source=" .. source.key
    contains[#contains + 1] = "archive_sha256=" .. source.archiveSha256
    contains[#contains + 1] = "initial_rules="
      .. source.expectedInitialRuleState

    local passes = {}
    for _, phase in ipairs(PHASES) do
      passes[#passes + 1] = {
        name = phase,
        driver = DRIVER,
        timeout_seconds = 1800,
        env = {
          QA_UPGRADE_PHASE = phase,
          QA_UPGRADE_SOURCE = source.key,
        },
      }
    end

    cells[#cells + 1] = {
      id = ("l01-upgrade-%s-%s"):format(source.slug, edition),
      identity = ("ka65-upgrade-matrix-%s-%s"):format(source.key, edition),
      edition = edition,
      closure = "base_deutsch",
      driver = DRIVER,
      timeout_seconds = 1800,
      env = {},
      passes = passes,
      result = { path = "driver_result.txt", contains = contains },
      images = { exact_count = 0 },
      source = source.key,
      archive = "immutable_inputs/upgrade_sources/" .. source.archiveName,
      archiveBytes = source.archiveBytes,
      archiveSha256 = source.archiveSha256,
      provenance = {
        kind = "schema-derived-sanitized",
        publishedSave = false,
        containsPlayerPII = false,
      },
    }
  end
end

return {
  schema = "ka-l01-upgrade-package-matrix/v1",
  blocker = "DRV-UPGRADE-MATRIX-PACKAGE",
  replacementCell = "l01-blocked-upgrade-matrix",
  supportFiles = {
    "tests/upgrade_matrix_package_driver.lua",
    "immutable_inputs/upgrade_sources/upgrade_matrix_package_driver.lua",
    "immutable_inputs/upgrade_sources/upgrade_package_sources.lua",
    "immutable_inputs/upgrade_sources/upgrade_package_matrix_manifest.lua",
    "immutable_inputs/upgrade_sources/immutable_input_receipt.json",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.0.11.modpkg",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc25-test.zip",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc26-test.zip",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc27-test.zip",
  },
  phases = PHASES,
  editions = EDITIONS,
  sources = sources,
  cells = cells,
}
