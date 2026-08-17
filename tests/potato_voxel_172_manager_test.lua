-- Exercise the real 0.1.96-era manager/loader implementation, not a copied
-- semver parser. Official PotatoVoxel releases from the 1.7.2 baseline
-- through 2.x are admitted best-effort; older/3.x versions remain blocked.

package.path = "./?.lua;./?/init.lua;" .. package.path

local Json = require("src.link.Json")
local Loader = require("src.mods.Loader")
local Manifest = require("src.mods.Manifest")
local ManagerState = require("src.mods.ManagerState")
local Version = require("src.core.Version")
local sdk = require("tests.modkit.sdk")

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local oldEngine = Version.engine
Version.engine = "0.1.96"

local function read(path)
  local file = assert(io.open(path, "rb"), path)
  local body = file:read("*a")
  file:close()
  return body
end

local raw = assert(Json.decode(read(root .. "/manifest.json")))
local ascendant = Manifest.validate(raw, root .. "/manifest.json")

local function potato(version, github)
  return Manifest.validate({
    id = "potato_voxel", name = "PotatoVoxel",
    version = version, api = 2, entry = "main.lua", profile = "content",
    game_version = ">=0.1.87 <2.0.0", priority = 95,
    dependencies = {}, optional_dependencies = {},
    conflicts = { "VOXEL_ASCENDANT", "DRAMALESS_SHAPE",
      "BATTLE_ART_VOXEL_FORK" },
    permissions = { "engine_internals", "network" },
    github = github or "ShaneMcGovernIE/potato_voxel",
  }, "mods/potato_voxel/manifest.json")
end

local function has(rows, expected)
  for _, row in ipairs(rows or {}) do
    if row == expected then return true end
  end
  return false
end

local accepted = potato("1.7.2")
local result = ManagerState.resolveToggle({
  kanto_ascendant = ascendant, potato_voxel = accepted,
}, "kanto_ascendant", true, { potato_voxel = true })
assert(not has(result.conflicts, "potato_voxel"),
  "0.1.96 manager still blocks exact PotatoVoxel 1.7.2")
assert(result.apply.potato_voxel ~= false,
  "0.1.96 manager disabled the exact approved renderer")
local future = potato("2.9.9")
result = ManagerState.resolveToggle({
  kanto_ascendant = ascendant, potato_voxel = future,
}, "kanto_ascendant", true, { potato_voxel = true })
assert(not has(result.conflicts, "potato_voxel")
    and result.apply.potato_voxel ~= false,
  "0.1.96 manager blocked an in-range PotatoVoxel release")

-- Production Loader check: the accepted package passes the actual static
-- conflict gate and both entries initialize. The real package/API contract
-- is covered separately by the exact-release test.
local loaderRaw = assert(Json.decode(read(root .. "/manifest.json")))
loaderRaw.assets_transforms = nil
local loader = Loader.new({ fs = sdk.memfs({
  ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
  ["mods/kanto_ascendant/main.lua"] =
    "return function(mod) mod.exports.entryRan = true end",
  ["mods/potato_voxel/manifest.json"] = Json.encode({
    id = accepted.id, name = accepted.name, version = accepted.version,
    api = accepted.api, entry = "main.lua", profile = "content",
    game_version = ">=0.1.87 <2.0.0", priority = accepted.priority,
    dependencies = {}, optional_dependencies = {},
    conflicts = { "VOXEL_ASCENDANT", "DRAMALESS_SHAPE",
      "BATTLE_ART_VOXEL_FORK" },
    permissions = { "engine_internals", "network" },
    github = accepted.github,
  }),
  ["mods/potato_voxel/main.lua"] =
    "return function(mod) mod.exports.rendererNative = true end",
}) })
assert(loader:load({}) == true, "0.1.96 Loader could not load approved pair")
assert(loader.mods.kanto_ascendant.state == "loaded",
  "approved PotatoVoxel reached KASC's conflict gate")
assert(loader.mods.potato_voxel.state == "loaded",
  "approved PotatoVoxel itself did not load")

for _, version in ipairs({
    "1.6.1", "1.6.9", "1.7.0", "1.7.1", "3.0.0", "3.1.0",
}) do
  local candidate = potato(version)
  result = ManagerState.resolveToggle({
    kanto_ascendant = ascendant, potato_voxel = candidate,
  }, "kanto_ascendant", true, { potato_voxel = true })
  -- Stock 0.1.96 reports a conflict and leaves the staged set untouched;
  -- its UI refuses to apply that unresolved result. It does not yet rewrite
  -- the conflicting mod to `false` (newer ManagerState builds may do so).
  assert(#(result.conflicts or {}) > 0,
    "0.1.96 manager missed out-of-range PotatoVoxel " .. version)
end

local wrongRepo = potato("1.7.2", "someone-else/potato_voxel")
result = ManagerState.resolveToggle({
  kanto_ascendant = ascendant, potato_voxel = wrongRepo,
}, "kanto_ascendant", true, { potato_voxel = true })
-- The stock 0.1.96 manager does not interpret `exclusive.allow_packages`, so
-- it cannot diagnose repository provenance. KASC's own exact resolver does
-- that before exposing any Potato module (voxel_renderer_compat_test.lua).
assert(#(result.conflicts or {}) == 0,
  "0.1.96 unexpectedly gained repository-aware manager policy")

Version.engine = oldEngine
print("potato_voxel_172_manager_test: PASS")
