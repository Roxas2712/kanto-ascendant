local matrix = dofile("tools/upgrade_package_matrix_manifest.lua")

assert(matrix.schema == "ka-l01-upgrade-package-matrix/v1")
assert(matrix.blocker == "DRV-UPGRADE-MATRIX-PACKAGE")
assert(matrix.replacementCell == "l01-blocked-upgrade-matrix")
assert(table.concat(matrix.phases, ",") == "stage,migrate,disabled,reenabled")
assert(table.concat(matrix.editions, ",") == "red,blue,yellow")
assert(#matrix.sources == 4 and #matrix.cells == 12)
assert(#matrix.supportFiles == 9)
local support = {}
for _, path in ipairs(matrix.supportFiles) do
  assert(not support[path]); support[path] = true
end
for _, path in ipairs({
    "tests/upgrade_matrix_package_driver.lua",
    "immutable_inputs/upgrade_sources/upgrade_matrix_package_driver.lua",
    "immutable_inputs/upgrade_sources/upgrade_package_sources.lua",
    "immutable_inputs/upgrade_sources/immutable_input_receipt.json",
  }) do
  assert(support[path], path)
end

local expected = {
  v6_0_11 = {
    archive = "kanto-ascendant-6.0.11.modpkg",
    bytes = 16662061,
    sha = "72779b0a9923e2e3908573552858718aa09bc6eae25222d1268bf3f1e41b62e7",
    rules = "unlocked",
  },
  rc25 = {
    archive = "kanto-ascendant-6.5.0-rc25-test.zip",
    bytes = 37749193,
    sha = "9d340d9badf940adc7bd1a36b43d66a4d02b84229a63df8c5caa85939fdab9a5",
    rules = "unlocked",
  },
  rc26 = {
    archive = "kanto-ascendant-6.5.0-rc26-test.zip",
    bytes = 37794577,
    sha = "0b0fcd765a1dd6d64584d2dd5c116bbabf9a8218c77314e7d5de5937d63e2418",
    rules = "locked",
  },
  rc27 = {
    archive = "kanto-ascendant-6.5.0-rc27-test.zip",
    bytes = 37983841,
    sha = "fb870c51b22ac87be7a3c79ec98e6fe798196946c96abec439e5915d99af5912",
    rules = "locked",
  },
}

for _, source in ipairs(matrix.sources) do
  local want = assert(expected[source.key])
  assert(source.archiveName == want.archive)
  assert(source.archiveBytes == want.bytes)
  assert(source.archiveSha256 == want.sha)
  assert(source.expectedInitialRuleState == want.rules)
end

local ids, identities, combinations = {}, {}, {}
for _, cell in ipairs(matrix.cells) do
  assert(not ids[cell.id] and not identities[cell.identity])
  ids[cell.id], identities[cell.identity] = true, true
  local combo = cell.source .. "/" .. cell.edition
  assert(not combinations[combo])
  combinations[combo] = true
  local want = assert(expected[cell.source])
  assert(cell.closure == "base_deutsch")
  assert(cell.driver == "tests/upgrade_matrix_package_driver.lua")
  assert(cell.archive == "immutable_inputs/upgrade_sources/" .. want.archive)
  assert(cell.archiveBytes == want.bytes and cell.archiveSha256 == want.sha)
  assert(cell.images.exact_count == 0)
  assert(cell.provenance.kind == "schema-derived-sanitized")
  assert(cell.provenance.publishedSave == false)
  assert(cell.provenance.containsPlayerPII == false)
  assert(#cell.passes == 4)
  for index, phase in ipairs(matrix.phases) do
    local pass = cell.passes[index]
    assert(pass.name == phase)
    assert(pass.driver == cell.driver)
    assert(pass.env.QA_UPGRADE_PHASE == phase)
    assert(pass.env.QA_UPGRADE_SOURCE == cell.source)
  end
  local result = table.concat(cell.result.contains, "\n")
  for _, token in ipairs({
      "status=PASS", "scope=UPGRADE-MATRIX-PACKAGE",
      "edition=" .. cell.edition, "source=" .. cell.source,
      "archive_sha256=" .. want.sha,
      "initial_rules=" .. want.rules,
      "failed_write_rollback=1/1", "backup_rollback=1/1",
      "disable_quarantine=2/2", "reenable_restore=2/2",
      "data_equality=1/1", "fail=0",
    }) do
    assert(result:find(token, 1, true), token)
  end
end

for source in pairs(expected) do
  for _, edition in ipairs(matrix.editions) do
    assert(combinations[source .. "/" .. edition])
  end
end

print("Upgrade package matrix manifest PASS: 12 cells x 4 clean processes")
