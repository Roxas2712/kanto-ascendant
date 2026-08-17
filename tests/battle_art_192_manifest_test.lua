-- Focused package-policy acceptance for the official Battle Art series.
-- Exact-version runtime repairs are tested separately; this file verifies
-- only the best-effort manager boundary and canonical repository pin.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local Json = require("src.link.Json")
local Manifest = require("src.mods.Manifest")
local ManagerState = require("src.mods.ManagerState")
local Semver = require("src.mods.Semver")
local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local checks = 0
local function ok(value, message)
  checks = checks + 1
  assert(value, message)
end
local function read(path)
  local file = assert(io.open(path, "rb"), path)
  local body = file:read("*a")
  assert(file:close())
  return body
end
local function external(version, repository)
  return Manifest.validate({
    id = "BATTLE_ART_VOXEL_FORK",
    name = "Battle Art", version = version,
    api = 2, entry = "main.lua", profile = "content",
    github = repository, dependencies = {}, conflicts = {},
  }, "mods/BATTLE_ART_VOXEL_FORK/manifest.json")
end

local decoded, decodeError = Json.decode(read(root .. "/manifest.json"))
assert(decoded, "manifest decode failed: " .. tostring(decodeError))
local ascendant = Manifest.validate(decoded, root .. "/manifest.json")
local richPolicies = type(Manifest.exclusiveAllows) == "function"
local packagePolicy
for _, row in ipairs(decoded.exclusive and decoded.exclusive.allow_packages or {}) do
  if row.repositories and row.repositories[1] ==
      "absol89/DramaticShapeVoxelMod" then
    packagePolicy = row
  end
end
ok(packagePolicy and packagePolicy.version == ">=1.9.0 <3.0.0",
  "Battle Art canonical repository/range policy drifted")
local expectedRange = "<1.9.0 || >=3.0.0"
local conflict
for _, row in ipairs(ascendant.conflictSpecs or {}) do
  if row.id == "BATTLE_ART_VOXEL_FORK" then conflict = row end
end
ok(conflict and conflict.range == expectedRange,
  "Battle Art conflict fence is not the supported >=1.9.0 <3.0.0 series")
for _, version in ipairs({ "1.9.0", "1.9.2", "1.9.3", "2.0.0", "2.9.9" }) do
  ok(not Semver.satisfies(version, expectedRange),
    "in-range Battle Art " .. version .. " is inside the conflict fence")
  local package = external(version, "absol89/DramaticShapeVoxelMod")
  if richPolicies then
    ok(Manifest.exclusiveAllows(ascendant, package),
      "official in-range Battle Art " .. version .. " is absent from policy")
  end
  local mods = {
    kanto_ascendant = ascendant,
    BATTLE_ART_VOXEL_FORK = package,
  }
  local result = ManagerState.resolveToggle(
    mods, "BATTLE_ART_VOXEL_FORK", true, { kanto_ascendant = true })
  ok(#result.conflicts == 0
      and result.apply.BATTLE_ART_VOXEL_FORK == true,
    "manager blocks official in-range Battle Art " .. version)
end
for _, version in ipairs({ "1.8.3", "3.0.0", "3.1.0", "9.0.0" }) do
  ok(Semver.satisfies(version, expectedRange),
    "out-of-range Battle Art " .. version .. " escaped the conflict fence")
  if richPolicies then
    ok(not Manifest.exclusiveAllows(ascendant,
        external(version, "absol89/DramaticShapeVoxelMod")),
      "out-of-range Battle Art " .. version .. " escaped exclusive policy")
  end
end
if richPolicies then
  ok(not Manifest.exclusiveAllows(ascendant,
      external("2.5.0", "someone-else/DramaticShapeVoxelMod")),
    "spoofed in-range Battle Art repository escaped exclusive policy")
end

print(("battle_art_192_manifest_test: PASS (%d checks)"):format(checks))
