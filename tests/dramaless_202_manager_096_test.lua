-- Exercise the real 0.1.96-era manager/loader implementation, not a copied
-- semver parser. Official DRAMALESS releases from the hardened baseline
-- through 2.x may be toggled beside KASC best-effort; 2.x stays native-owned.

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

local function draml(version, github)
  return Manifest.validate({
    id = "DRAMALESS_SHAPE", name = "Dramaless Shape Voxel Mod",
    version = version, api = 2, entry = "main.lua", profile = "content",
    game_version = ">=0.1.87 <2.0.0", priority = 100,
    dependencies = {}, optional_dependencies = {}, conflicts = {},
    permissions = { "engine_internals" },
    github = github or "artyrambles/DRAMALESS_SHAPE",
  }, "mods/DRAMALESS_SHAPE/manifest.json")
end

local function has(rows, expected)
  for _, row in ipairs(rows or {}) do
    if row == expected then return true end
  end
  return false
end

local accepted = draml("2.0.2")
local result = ManagerState.resolveToggle({
  kanto_ascendant = ascendant, DRAMALESS_SHAPE = accepted,
}, "kanto_ascendant", true, { DRAMALESS_SHAPE = true })
assert(not has(result.conflicts, "DRAMALESS_SHAPE"),
  "0.1.96 manager still blocks exact DRAMALESS 2.0.2")
assert(result.apply.DRAMALESS_SHAPE ~= false,
  "0.1.96 manager disabled the exact approved renderer")
local future = draml("2.9.9")
result = ManagerState.resolveToggle({
  kanto_ascendant = ascendant, DRAMALESS_SHAPE = future,
}, "kanto_ascendant", true, { DRAMALESS_SHAPE = true })
assert(not has(result.conflicts, "DRAMALESS_SHAPE")
    and result.apply.DRAMALESS_SHAPE ~= false,
  "0.1.96 manager blocked an in-range DRAMALESS release")

-- Production Loader check: the accepted version passes the actual static
-- conflict gate and both stub entries can initialize. The real KASC entry is
-- separately covered by the renderer resolver test; this isolates the
-- launcher gate that produced the user-visible conflict report.
local loaderRaw = assert(Json.decode(read(root .. "/manifest.json")))
loaderRaw.assets_transforms = nil
local loader = Loader.new({ fs = sdk.memfs({
  ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
  ["mods/kanto_ascendant/main.lua"] =
    "return function(mod) mod.exports.entryRan = true end",
  ["mods/DRAMALESS_SHAPE/manifest.json"] = Json.encode({
    id = accepted.id, name = accepted.name, version = accepted.version,
    api = accepted.api, entry = "main.lua", profile = "content",
    game_version = ">=0.1.87 <2.0.0", priority = accepted.priority,
    dependencies = {}, optional_dependencies = {}, conflicts = {},
    permissions = { "engine_internals" }, github = accepted.github,
  }),
  ["mods/DRAMALESS_SHAPE/main.lua"] =
    "return function(mod) mod.exports.rendererNative = true end",
}) })
assert(loader:load({}) == true, "0.1.96 Loader could not load the approved pair")
assert(loader.mods.kanto_ascendant.state == "loaded",
  "approved 2.0.2 reached KASC's conflict gate")
assert(loader.mods.DRAMALESS_SHAPE.state == "loaded",
  "approved 2.0.2 itself did not load")

for _, version in ipairs({ "1.6.2-ST.190", "1.6.1", "3.0.0", "3.1.0" }) do
  local candidate = draml(version)
  result = ManagerState.resolveToggle({
    kanto_ascendant = ascendant, DRAMALESS_SHAPE = candidate,
  }, "kanto_ascendant", true, { DRAMALESS_SHAPE = true })
  assert(#(result.conflicts or {}) > 0,
    "0.1.96 manager allowed out-of-range DRAMALESS " .. version)
end

-- Engine 0.1.96 does not expose the later rich allow-package policy to this
-- pure ManagerState helper. The exact repository is therefore enforced by
-- KASC's runtime camera resolver before any owner-loader request. Keep this
-- row as an explicit launcher limitation rather than claiming the old helper
-- rejects a repository that it cannot inspect.
local wrongRepo = draml("2.0.2", "someone-else/DRAMALESS_SHAPE")
result = ManagerState.resolveToggle({
  kanto_ascendant = ascendant, DRAMALESS_SHAPE = wrongRepo,
}, "kanto_ascendant", true, { DRAMALESS_SHAPE = true })
assert(#(result.conflicts or {}) == 0,
  "0.1.96 manager unexpectedly interpreted unsupported repository policy")

Version.engine = oldEngine
print("dramaless_202_manager_096_test: PASS")
