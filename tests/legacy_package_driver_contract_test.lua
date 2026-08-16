-- Fail-closed harness contract for the installed-package 4x4 Pact/Bank and
-- uninterrupted three-Journey driver.  Product correctness is exercised by
-- legacy_pacts_test.lua and legacy_archive_integrity_test.lua; this gate makes
-- sure the visual package harness cannot manufacture their result directly.

local root = assert(os.getenv("KA_LEGACY_MOD"), "KA_LEGACY_MOD required")
local driverPath = root .. "/tests/legacy_pact_three_journeys_visual_driver.lua"
assert(loadfile(driverPath), "Legacy package driver does not compile")
assert(loadfile(root .. "/legacy_archive.lua"), "Legacy archive does not compile")
assert(loadfile(root .. "/legacy_journey.lua"), "Legacy Journey does not compile")
assert(loadfile(root .. "/legacy_starters.lua"), "Legacy starters do not compile")
local manifest = assert(loadfile(root .. "/tools/legacy_package_matrix_manifest.lua"))()

local stream = assert(io.open(driverPath, "rb"))
local source = stream:read("*a"); stream:close()
local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function contains(needle)
  check(source:find(needle, 1, true) ~= nil, "driver missing " .. needle)
end

for _, needle in ipairs({
  "archive.beginJourney(game.save", "SaveData.newGame(game:bootConfig())",
  "game:restoreSave(fresh, false)", "game:writeSave()", "SaveData.load()",
  "starters.choose(game", "archive.setAvatar(game.save, avatar)",
  "archive.bankAccess(game.save)", "archive.isEligible(game.save)",
  "matrix=16/16 pacts=4/4 policies=4/4",
  "journeys=3/3 fresh_new_game_hooks=3/3 save_reload=3/3",
  "STAGED_POST_RIVAL_BALL_PRE_PARTNER_BOUNDARY",
  "direct_archive_state_writes=false",
}) do contains(needle) end

for _, forbidden in ipairs({
  "archive.seedNewSave", "archive.markRunStarted", "archive.write(",
  "SaveData.save(", "snapshot.bank[", "snapshot.hallOfLegacy[",
}) do
  check(source:find(forbidden, 1, true) == nil,
    "driver bypasses product state with " .. forbidden)
end
for _, field in ipairs({
  "partnerChosen", "bankPolicy", "pact", "status", "runId",
}) do
  check(source:find("%." .. field .. "%s*=%s*[^=]") == nil,
    "driver assigns protected Legacy field " .. field)
end

check(type(manifest) == "table" and #manifest == 4,
  "package manifest must own three 4x4 editions plus one connected lane")
local seen = {}
for _, row in ipairs(manifest) do
  check(row.identity == "ka-legacy-pact-4x4-" .. row.version .. "-package"
      or row.identity == "ka-legacy-three-journeys-package",
    "manifest contains a non-isolated identity")
  check(not seen[row.identity], "manifest identity is duplicated")
  seen[row.identity] = true
  check(row.driver == root .. "/tests/legacy_pact_three_journeys_visual_driver.lua",
    "manifest does not use the frozen combined driver")
  check(type(row.required) == "table" and #row.required >= 9,
    "manifest receipt is incomplete for " .. tostring(row.id))
end
for index, version in ipairs({ "red", "blue", "yellow" }) do
  check(manifest[index].version == version
      and manifest[index].env.KA_LEGACY_ACCEPTANCE_MODE == "pact4x4"
      and manifest[index].images == 16,
    version .. " 4x4 row must demand sixteen visible pair captures")
end
check(manifest[4].version == "red"
    and manifest[4].env.KA_LEGACY_ACCEPTANCE_MODE == "three_journeys"
    and manifest[4].images == 3,
  "three-Journey row must demand one visible capture per life")

print(("LEGACY PACKAGE DRIVER CONTRACT PASS: %d assertions")
  :format(assertions))
