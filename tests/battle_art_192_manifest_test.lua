-- Focused package-policy acceptance for exact upstream Battle Art 1.9.2.
-- This intentionally ignores unrelated renderer policy so it remains useful
-- while another compatibility branch updates its own allowlist.

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
local expectedRange = "<1.9.0 || >1.9.0 <1.9.2 || >1.9.2"
local conflict
for _, row in ipairs(ascendant.conflictSpecs or {}) do
  if row.id == "BATTLE_ART_VOXEL_FORK" then conflict = row end
end
ok(conflict and conflict.range == expectedRange,
  "Battle Art conflict fence is not the exact 1.9.0/1.9.2 pair")
for _, version in ipairs({ "1.9.0", "1.9.2" }) do
  ok(not Semver.satisfies(version, expectedRange),
    "reviewed Battle Art " .. version .. " is inside the conflict fence")
  local package = external(version, "absol89/DramaticShapeVoxelMod")
  ok(Manifest.exclusiveAllows(ascendant, package),
    "reviewed Battle Art " .. version .. " is absent from exclusive policy")
  local mods = {
    kanto_ascendant = ascendant,
    BATTLE_ART_VOXEL_FORK = package,
  }
  local result = ManagerState.resolveToggle(
    mods, "BATTLE_ART_VOXEL_FORK", true, { kanto_ascendant = true })
  ok(#result.conflicts == 0
      and result.apply.BATTLE_ART_VOXEL_FORK == true,
    "manager blocks reviewed Battle Art " .. version)
end
for _, version in ipairs({ "1.8.3", "1.9.1", "1.9.3", "2.0.0" }) do
  ok(Semver.satisfies(version, expectedRange),
    "unreviewed Battle Art " .. version .. " escaped the conflict fence")
  ok(not Manifest.exclusiveAllows(ascendant,
      external(version, "absol89/DramaticShapeVoxelMod")),
    "unreviewed Battle Art " .. version .. " escaped exclusive policy")
end
ok(not Manifest.exclusiveAllows(ascendant,
    external("1.9.2", "someone-else/DramaticShapeVoxelMod")),
  "spoofed Battle Art 1.9.2 repository escaped exclusive policy")

print(("battle_art_192_manifest_test: PASS (%d checks)"):format(checks))
