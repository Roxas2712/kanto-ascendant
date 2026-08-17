-- Kanto Ascendant 6.5's default-deny runtime-mod contract.
-- Run from the engine checkout with TRAINER_REMATCH_MOD_DIR set.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local Json = require("src.link.Json")
local Loader = require("src.mods.Loader")
local Manifest = require("src.mods.Manifest")
local ManagerState = require("src.mods.ManagerState")
local Semver = require("src.mods.Semver")
local sdk = require("tests.modkit.sdk")

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function read(path)
  local file = assert(io.open(path, "rb"), path)
  local body = file:read("*a")
  file:close()
  return body
end

local raw, decodeError = Json.decode(read(root .. "/manifest.json"))
assert(raw, "could not decode Ascendant manifest: " .. tostring(decodeError))
local ascendant = Manifest.validate(raw, root .. "/manifest.json")

local integrated = {
  "trainer_rematch", "all_pokemon_catchable_151_mod", "modern_party_ui",
  "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge",
  "pokepc_followers_rb", "pokepcfollowers", "quality_of_life",
  "quality_of_life_pr9_test", "crystal_animated_sprites_with_shiny_visuals",
  "shiny_indicators",
  "gender_mod", "pokemon_gender", "pokemon_genders",
  "pokemon_gender_system", "gen2_pokemon_gender", "pokemon_breeding",
  "gen2_breeding", "useful_bag", "jj_quick_select", "nuzlocke",
  "overworld_wild_spawns", "unique_menu_icons", "Dynamic_Cries",
}
local canonical = {
  trainer_rematch = true, PokePCFollowers_VoxelMerge = true,
  all_pokemon_catchable_151_mod = true, modern_party_ui = true,
  quality_of_life = true, crystal_animated_sprites_with_shiny_visuals = true,
  shiny_indicators = true, gender_mod = true, useful_bag = true, jj_quick_select = true,
  nuzlocke = true, overworld_wild_spawns = true,
  unique_menu_icons = true, Dynamic_Cries = true,
}
local incompatibleRenderers = {
  "DRAMATIC_SHAPE", "TERRARIUM", "ds_fp_ceiling",
}
local safeVoxelVersions = {
  "0.1.0-rc.1", "0.1.1", "0.2.0", "1.0.0", "2.9.9",
}
local unsafeVoxelVersions = {
  "0.0.9", "3.0.0-alpha.1", "3.0.0-rc.1", "3.0.0", "3.1.0",
}
local voxelConflictSpec =
  "VOXEL_ASCENDANT@<0.1.0-rc.1 || >=3.0.0-0"
local safePotatoVersion = "1.7.2"
local safePotatoVersions = {
  safePotatoVersion, "1.7.3", "2.0.0", "2.9.9",
}
local unsafePotatoVersions = {
  "1.6.1", "1.6.9", "1.7.0", "1.7.1", "3.0.0-alpha.1",
  "3.0.0-rc.1", "3.0.0",
}
local potatoConflictSpec = "potato_voxel@<1.7.2 || >=3.0.0-0"
local safeBattleArtVersion = "1.9.0"
local safeBattleArt192Version = "1.9.2"
local safeBattleArtVersions = {
  safeBattleArtVersion, safeBattleArt192Version, "1.9.3", "2.0.0", "2.9.9",
}
local unsafeBattleArtVersions = {
  "1.8.3", "3.0.0-alpha.1", "3.0.0-rc.1", "3.0.0", "3.1.0",
}
local battleArtConflictSpec =
  "BATTLE_ART_VOXEL_FORK@<1.9.0 || >=3.0.0-0"
local safeDramalessVersion = "1.6.2-ST.190.1"
local nativeDramalessVersion = "2.0.2"
local safeDramalessVersions = {
  safeDramalessVersion, "1.6.2-ST.190.2", "1.6.2", "1.6.4", "2.0.0",
  nativeDramalessVersion, "2.0.3", "2.9.9",
}
local unsafeDramalessVersions = {
  "1.6.2-ST.190", "1.6.1", "3.0.0-alpha.1", "3.0.0-rc.1",
  "3.0.0", "3.1.0",
}
local dramalessConflictSpec =
  "DRAMALESS_SHAPE@<1.6.2-ST.190.1 || >=3.0.0-0"
local approved = {
  { id = "deutsch", version = "1.0.0" },
  { id = "deutsch-blau", version = "1.0.0" },
  { id = "deutsch-gelb", version = "1.0.0" },
  { id = "VOXEL_ASCENDANT", version = "0.1.0-rc.1",
    github = "Roxas2712/voxel-ascendant" },
  { id = "VOXEL_ASCENDANT", version = "0.1.1",
    github = "Roxas2712/voxel-ascendant" },
  { id = "VOXEL_ASCENDANT", version = "2.9.9",
    github = "Roxas2712/voxel-ascendant" },
  { id = "DRAMALESS_SHAPE", version = safeDramalessVersion,
    github = "artyrambles/DRAMALESS_SHAPE" },
  { id = "DRAMALESS_SHAPE", version = nativeDramalessVersion,
    github = "artyrambles/DRAMALESS_SHAPE" },
  { id = "DRAMALESS_SHAPE", version = "2.9.9",
    github = "artyrambles/DRAMALESS_SHAPE" },
  { id = "BATTLE_ART_VOXEL_FORK", version = safeBattleArtVersion,
    github = "absol89/DramaticShapeVoxelMod" },
  { id = "BATTLE_ART_VOXEL_FORK", version = safeBattleArt192Version,
    github = "absol89/DramaticShapeVoxelMod" },
  { id = "BATTLE_ART_VOXEL_FORK", version = "2.9.9",
    github = "absol89/DramaticShapeVoxelMod" },
  { id = "potato_voxel", version = safePotatoVersion,
    github = "ShaneMcGovernIE/potato_voxel" },
  { id = "potato_voxel", version = "2.9.9",
    github = "ShaneMcGovernIE/potato_voxel" },
}

local expectedClassic = {}
for _, id in ipairs(integrated) do expectedClassic[id] = true end
expectedClassic["Kanto-Reforged"] = true
for _, id in ipairs(incompatibleRenderers) do expectedClassic[id] = true end
expectedClassic[voxelConflictSpec] = true
expectedClassic[dramalessConflictSpec] = true
expectedClassic[battleArtConflictSpec] = true
expectedClassic[potatoConflictSpec] = true
local actualClassic = {}
for _, id in ipairs(raw.conflicts or {}) do actualClassic[id] = true end
for id in pairs(expectedClassic) do
  assert(actualClassic[id], "stock 0.1.90 conflict missing: " .. id)
end

for id in pairs(actualClassic) do
  assert(expectedClassic[id], "unexpected stock conflict: " .. id)
end
assert(#(raw.conflicts or {}) == 32 and #(raw.incompatible or {}) == 0,
  "stock 0.1.90 conflict boundary is not exact")

local function external(id, version, github, dependencies, conflicts)
  return Manifest.validate({
    id = id, name = id, version = version or "1.0.0", api = 2,
    entry = "main.lua", profile = "content", github = github,
    dependencies = dependencies or {}, conflicts = conflicts or {},
  }, "mods/" .. id .. "/manifest.json")
end

local function contains(rows, wanted)
  for _, value in ipairs(rows or {}) do
    if value == wanted then return true end
  end
  return false
end

-- Every official renderer family uses the same major-series policy. The
-- classic fence protects old managers by ID/version; newer launchers also
-- require the canonical repository through exclusive.allow_packages.
local parsedVoxelConflict
for _, spec in ipairs(ascendant.conflictSpecs or {}) do
  if spec.id == "VOXEL_ASCENDANT" then parsedVoxelConflict = spec end
end
assert(parsedVoxelConflict
    and parsedVoxelConflict.range == "<0.1.0-rc.1 || >=3.0.0-0",
  "classic Voxel Ascendant supported-series fence did not parse")
for _, version in ipairs(unsafeVoxelVersions) do
  assert(Semver.satisfies(version, parsedVoxelConflict.range),
    "classic Voxel Ascendant fence missed " .. version)
  local candidate = external("VOXEL_ASCENDANT", version,
    "Roxas2712/voxel-ascendant")
  local mods = { kanto_ascendant = ascendant, VOXEL_ASCENDANT = candidate }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { VOXEL_ASCENDANT = true })
  assert(contains(result.conflicts, "VOXEL_ASCENDANT")
      or result.apply.VOXEL_ASCENDANT == false,
    "out-of-range Voxel Ascendant was retained: " .. version)
end
for _, version in ipairs(safeVoxelVersions) do
  assert(not Semver.satisfies(version, parsedVoxelConflict.range),
    "classic Voxel Ascendant fence included " .. version)
  local candidate = external("VOXEL_ASCENDANT", version,
    "Roxas2712/voxel-ascendant")
  local mods = { kanto_ascendant = ascendant, VOXEL_ASCENDANT = candidate }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { VOXEL_ASCENDANT = true })
  assert(#result.conflicts == 0,
    "supported-series Voxel Ascendant was blocked: " .. version)
end

-- PotatoVoxel is admitted from the known 1.7.2 baseline through the 2.x
-- series. Runtime capability checks still reject an incompatible facade.
local safePotato = external("potato_voxel", safePotatoVersion,
  "ShaneMcGovernIE/potato_voxel")
local parsedPotatoConflict
for _, spec in ipairs(ascendant.conflictSpecs or {}) do
  if spec.id == "potato_voxel" then parsedPotatoConflict = spec end
end
assert(parsedPotatoConflict
    and parsedPotatoConflict.range == "<1.7.2 || >=3.0.0-0",
  "classic PotatoVoxel supported-series fence did not parse")
for _, version in ipairs(unsafePotatoVersions) do
  assert(Semver.satisfies(version, parsedPotatoConflict.range),
    "classic PotatoVoxel conflict range missed " .. version)
  local candidate = external("potato_voxel", version,
    "ShaneMcGovernIE/potato_voxel")
  local mods = { kanto_ascendant = ascendant, potato_voxel = candidate }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { potato_voxel = true })
  assert(contains(result.conflicts, "potato_voxel")
      or result.apply.potato_voxel == false,
    "out-of-range PotatoVoxel was retained: " .. version)
  result = ManagerState.resolveToggle(mods, "potato_voxel", true,
    { kanto_ascendant = true })
  assert(contains(result.conflicts, "kanto_ascendant"),
    "reverse conflict allowed PotatoVoxel " .. version)
end
for _, version in ipairs(safePotatoVersions) do
  assert(not Semver.satisfies(version, parsedPotatoConflict.range),
    "classic PotatoVoxel conflict range included " .. version)
  local safePackage = external("potato_voxel", version,
    "ShaneMcGovernIE/potato_voxel")
  local mods = { kanto_ascendant = ascendant, potato_voxel = safePackage }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { potato_voxel = true })
  assert(#result.conflicts == 0,
    "versioned conflict blocked PotatoVoxel " .. version)
  result = ManagerState.resolveToggle(mods, "potato_voxel", true,
    { kanto_ascendant = true })
  assert(#result.conflicts == 0,
    "reverse conflict blocked PotatoVoxel " .. version)
end

-- Battle Art admits the official series from 1.9.0 through 2.x. The 1.9.2
-- cache adapter remains exact-version-only in the runtime resolver.
local safeBattleArt = external("BATTLE_ART_VOXEL_FORK",
  safeBattleArtVersion, "absol89/DramaticShapeVoxelMod")
local safeBattleArt192 = external("BATTLE_ART_VOXEL_FORK",
  safeBattleArt192Version, "absol89/DramaticShapeVoxelMod")
local parsedBattleArtConflict
for _, spec in ipairs(ascendant.conflictSpecs or {}) do
  if spec.id == "BATTLE_ART_VOXEL_FORK" then parsedBattleArtConflict = spec end
end
assert(parsedBattleArtConflict
    and parsedBattleArtConflict.range ==
      "<1.9.0 || >=3.0.0-0",
  "classic Battle Art supported-series fence did not parse")
for _, version in ipairs(unsafeBattleArtVersions) do
  assert(Semver.satisfies(version, parsedBattleArtConflict.range),
    "classic Battle Art conflict range missed " .. version)
  local candidate = external("BATTLE_ART_VOXEL_FORK", version,
    "absol89/DramaticShapeVoxelMod")
  local mods = {
    kanto_ascendant = ascendant, BATTLE_ART_VOXEL_FORK = candidate,
  }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { BATTLE_ART_VOXEL_FORK = true })
  assert(contains(result.conflicts, "BATTLE_ART_VOXEL_FORK")
      or result.apply.BATTLE_ART_VOXEL_FORK == false,
    "out-of-range Battle Art was retained: " .. version)
  result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
    { kanto_ascendant = true })
  assert(contains(result.conflicts, "kanto_ascendant"),
    "reverse conflict allowed Battle Art " .. version)
end
for _, safeVersion in ipairs(safeBattleArtVersions) do
  assert(not Semver.satisfies(safeVersion, parsedBattleArtConflict.range),
    "classic Battle Art conflict range included " .. safeVersion)
  local safePackage = external("BATTLE_ART_VOXEL_FORK", safeVersion,
    "absol89/DramaticShapeVoxelMod")
  local mods = {
    kanto_ascendant = ascendant, BATTLE_ART_VOXEL_FORK = safePackage,
  }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { BATTLE_ART_VOXEL_FORK = true })
  assert(#result.conflicts == 0,
    "versioned conflict blocked Battle Art " .. safeVersion)
  result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
    { kanto_ascendant = true })
  assert(#result.conflicts == 0,
    "reverse conflict blocked Battle Art " .. safeVersion)
end

-- Dramaless follows the same baseline-through-2.x fence. Exact 2.0.2 keeps
-- its native-camera adapter; other in-range versions receive no such adapter.
local safeDramaless = external("DRAMALESS_SHAPE", safeDramalessVersion,
  "artyrambles/DRAMALESS_SHAPE")
local nativeDramaless = external("DRAMALESS_SHAPE", nativeDramalessVersion,
  "artyrambles/DRAMALESS_SHAPE")
local parsedDramalessConflict
for _, spec in ipairs(ascendant.conflictSpecs or {}) do
  if spec.id == "DRAMALESS_SHAPE" then parsedDramalessConflict = spec end
end
assert(parsedDramalessConflict
    and parsedDramalessConflict.range ==
      "<1.6.2-ST.190.1 || >=3.0.0-0",
  "classic DRAMALESS supported-series fence did not parse")
local richPolicies = type(Manifest.replacement) == "function"
  and type(Manifest.exclusiveAllows) == "function"
for _, version in ipairs(unsafeDramalessVersions) do
  assert(Semver.satisfies(version, parsedDramalessConflict.range),
    "classic DRAMALESS conflict range missed " .. version)
  local candidate = external("DRAMALESS_SHAPE", version,
    "artyrambles/DRAMALESS_SHAPE")
  local mods = { kanto_ascendant = ascendant, DRAMALESS_SHAPE = candidate }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { DRAMALESS_SHAPE = true })
  if richPolicies then
    assert(result.apply.DRAMALESS_SHAPE == false,
      "rich policy retained unsafe DRAMALESS " .. version)
  else
    assert(contains(result.conflicts, "DRAMALESS_SHAPE"),
      "versioned conflict allowed DRAMALESS " .. version .. " beside Ascendant")
  end
  result = ManagerState.resolveToggle(mods, "DRAMALESS_SHAPE", true,
    { kanto_ascendant = true })
  assert(contains(result.conflicts, "kanto_ascendant"),
    "reverse versioned conflict allowed DRAMALESS " .. version)
end
do
  for _, version in ipairs(safeDramalessVersions) do
    assert(not Semver.satisfies(version, parsedDramalessConflict.range),
      "classic DRAMALESS conflict range included approved " .. version)
    local candidate = external("DRAMALESS_SHAPE", version,
      "artyrambles/DRAMALESS_SHAPE")
    local mods = { kanto_ascendant = ascendant, DRAMALESS_SHAPE = candidate }
    local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
      { DRAMALESS_SHAPE = true })
    assert(#result.conflicts == 0,
      "versioned conflict blocked approved DRAMALESS " .. version)
    result = ManagerState.resolveToggle(mods, "DRAMALESS_SHAPE", true,
      { kanto_ascendant = true })
    assert(#result.conflicts == 0,
      "reverse versioned conflict blocked approved DRAMALESS " .. version)
  end
end

-- The released 0.1.90 loader knows only classic conflicts. It blocks either
-- attempted co-enable in the manager; at boot, the declaring Ascendant entry
-- fails before execution while the other package remains available. Rich
-- replacement/default-deny metadata below is an optional newer-engine layer.
if not richPolicies then
  local stockIds = {}
  for _, id in ipairs(integrated) do stockIds[#stockIds + 1] = id end
  stockIds[#stockIds + 1] = "Kanto-Reforged"
  for _, id in ipairs(incompatibleRenderers) do
    stockIds[#stockIds + 1] = id
  end
  for _, id in ipairs(stockIds) do
    local candidate = external(id)
    local mods = { kanto_ascendant = ascendant, [id] = candidate }
    local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
      { [id] = true })
    assert(contains(result.conflicts, id),
      "stock manager allowed Ascendant beside " .. id)
    result = ManagerState.resolveToggle(mods, id, true,
      { kanto_ascendant = true })
    assert(contains(result.conflicts, "kanto_ascendant"),
      "stock manager allowed reverse co-enable for " .. id)
  end
  for _, item in ipairs(approved) do
    local candidate = external(item.id, item.version, item.github)
    local result = ManagerState.resolveToggle({
      kanto_ascendant = ascendant, [item.id] = candidate,
    }, "kanto_ascendant", true, { [item.id] = true })
    assert(#result.conflicts == 0,
      "stock manager blocked approved support package: " .. item.id)
  end
  print("Kanto Ascendant stock 0.1.90 conflict tests passed")
  return
end

assert(ascendant.exclusive and #ascendant.compatibilityConflicts == 16,
  "newer-engine default-deny or replacement metadata missing")

for _, id in ipairs(integrated) do
  local detail = Manifest.replacement(ascendant, external(id))
  assert(detail and detail.policy == "replace" and detail.reason_de,
    "integrated subsystem lacks replacement credit/guard: " .. id)
end
for _, id in ipairs(incompatibleRenderers) do
  local detail = Manifest.compatibilityConflict(ascendant, external(id))
  assert(detail and detail.policy == "block",
    "broken 0.1.90 renderer lacks a friendly block row: " .. id)
  assert(detail.reason_en ==
      "This renderer currently does not work with Gen1 Recomp 0.1.90."
      and detail.reason_de ==
      "Dieser Renderer funktioniert derzeit nicht mit Gen1 Recomp 0.1.90.",
    "broken renderer reason drifted: " .. id)
  assert(detail.resolution_en ==
      "Use one official supported-series Voxel renderer or native 2D."
      and detail.resolution_de ==
      "Verwende genau einen offiziellen Voxel-Renderer aus einer zugelassenen Versionsreihe oder die native 2D-Darstellung.",
    "broken renderer resolution drifted: " .. id)
end
assert(Manifest.compatibilityConflict(ascendant, safeDramaless) == nil,
  "hardened DRAMALESS must not inherit the rich broken-renderer block")
assert(Manifest.compatibilityConflict(ascendant, nativeDramaless) == nil,
  "native DRAMALESS 2.0.2 must not inherit the rich broken-renderer block")
assert(Manifest.compatibilityConflict(ascendant, safeBattleArt) == nil,
  "Battle Art 1.9.0 must not inherit the rich broken-renderer block")
assert(Manifest.compatibilityConflict(ascendant, safeBattleArt192) == nil,
  "Battle Art 1.9.2 must not inherit the rich broken-renderer block")
assert(Manifest.compatibilityConflict(ascendant, safePotato) == nil,
  "PotatoVoxel 1.7.2 must not inherit the broken-renderer block")
for _, item in ipairs(approved) do
  assert(Manifest.exclusiveAllows(ascendant, external(
      item.id, item.version, item.github)),
    "reviewed support package was blocked: " .. item.id)
end
assert(not Manifest.exclusiveAllows(ascendant,
    external("VOXEL_ASCENDANT", "0.1.1",
      "other/voxel-ascendant")),
  "a package spoofing the Voxel Ascendant id bypassed repository provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("VOXEL_ASCENDANT", "0.1.0-rc.1",
      "other/voxel-ascendant")),
  "a package spoofing the legacy Voxel Ascendant RC bypassed provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("VOXEL_ASCENDANT", "3.0.0",
      "Roxas2712/voxel-ascendant")),
  "Voxel Ascendant 3.x bypassed the supported-series ceiling")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", safeDramalessVersion,
      "other/DRAMALESS_SHAPE")),
  "a package spoofing the exact DRAMALESS id/version bypassed provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", nativeDramalessVersion,
      "other/DRAMALESS_SHAPE")),
  "a package spoofing native DRAMALESS 2.0.2 bypassed provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", "1.6.2-ST.190", "other/DRAMALESS_SHAPE")),
  "a package spoofing the renderer id bypassed repository provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", "1.6.2.ST",
      "artyrambles/DRAMALESS_SHAPE")),
  "the pre-sandbox DRAMALESS build bypassed the exact version pin")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", "3.0.0",
      "artyrambles/DRAMALESS_SHAPE")),
  "DRAMALESS 3.x bypassed the supported-series ceiling")
assert(not Manifest.exclusiveAllows(ascendant,
    external("BATTLE_ART_VOXEL_FORK", "1.9.0",
      "someone-else/DramaticShapeVoxelMod")),
  "a package spoofing Battle Art id/version bypassed repository provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("BATTLE_ART_VOXEL_FORK", "1.9.2",
      "someone-else/DramaticShapeVoxelMod")),
  "a package spoofing Battle Art 1.9.2 bypassed repository provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("BATTLE_ART_VOXEL_FORK", "1.8.3",
      "absol89/DramaticShapeVoxelMod")),
  "Battle Art 1.8.3 bypassed the exact version pin")
assert(not Manifest.exclusiveAllows(ascendant,
    external("BATTLE_ART_VOXEL_FORK", "3.0.0",
      "absol89/DramaticShapeVoxelMod")),
  "Battle Art 3.x bypassed the supported-series ceiling")
assert(not Manifest.exclusiveAllows(ascendant,
    external("potato_voxel", "1.7.2", "someone-else/potato_voxel")),
  "a package spoofing PotatoVoxel id/version bypassed provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("potato_voxel", "1.6.9",
      "ShaneMcGovernIE/potato_voxel")),
  "an older PotatoVoxel bypassed the exact version pin")
assert(not Manifest.exclusiveAllows(ascendant,
    external("potato_voxel", "3.0.0",
      "ShaneMcGovernIE/potato_voxel")),
  "PotatoVoxel 3.x bypassed the supported-series ceiling")
for _, row in ipairs({
  { id = "VOXEL_ASCENDANT", github = "Roxas2712/voxel-ascendant" },
  { id = "DRAMALESS_SHAPE", github = "artyrambles/DRAMALESS_SHAPE" },
  { id = "BATTLE_ART_VOXEL_FORK", github = "absol89/DramaticShapeVoxelMod" },
  { id = "potato_voxel", github = "ShaneMcGovernIE/potato_voxel" },
}) do
  assert(not Manifest.exclusiveAllows(ascendant,
      external(row.id, "latest", row.github)),
    "malformed renderer version escaped policy: " .. row.id)
  local unversioned = external(row.id, "2.0.0", row.github)
  unversioned.version = nil
  assert(not Manifest.exclusiveAllows(ascendant, unversioned),
    "unversioned renderer escaped policy: " .. row.id)
end
for _, id in ipairs(incompatibleRenderers) do
  assert(Manifest.exclusiveAllows(ascendant, external(id)),
    "known broken renderer must pass the generic deny boundary so the " ..
    "explicit 0.1.90 explanation is shown: " .. id)
end
assert(Manifest.exclusiveBlock(ascendant, external("unknown_runtime_mod")),
  "unknown runtime mod bypassed the default-deny policy")

-- Manager behavior: enabling Ascendant turns redundant/unknown mods off,
-- while reviewed support packages remain active. Re-enabling a redundant or
-- unknown package next to Ascendant is blocked with the precise reason.
local rematch = external("trainer_rematch")
local unknown = external("unknown_runtime_mod")
local battleArt = external("BATTLE_ART_VOXEL_FORK", "1.8.3",
  "absol89/DramaticShapeVoxelMod")
local battleArt190 = safeBattleArt
local battleArt192 = safeBattleArt192
local potato172 = safePotato
local voxel = external("VOXEL_ASCENDANT", "0.1.1",
  "Roxas2712/voxel-ascendant")
local voxelRc = external("VOXEL_ASCENDANT", "0.1.0-rc.1",
  "Roxas2712/voxel-ascendant")
local mods = {
  kanto_ascendant = ascendant, trainer_rematch = rematch,
  unknown_runtime_mod = unknown, VOXEL_ASCENDANT = voxel,
  BATTLE_ART_VOXEL_FORK = battleArt,
  potato_voxel = potato172,
}
local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true, {
  trainer_rematch = true, unknown_runtime_mod = true, VOXEL_ASCENDANT = true,
})
assert(result.apply.kanto_ascendant == true
    and result.apply.trainer_rematch == false
    and result.apply.unknown_runtime_mod == false
    and result.apply.VOXEL_ASCENDANT == nil,
  "manager did not retain only Ascendant plus reviewed support")
result = ManagerState.resolveToggle(mods, "trainer_rematch", true,
  { kanto_ascendant = true })
assert(contains(result.conflicts, "kanto_ascendant")
    and result.conflictDetails.kanto_ascendant.policy == "replace",
  "integrated standalone mod can be re-enabled beside Ascendant")
result = ManagerState.resolveToggle(mods, "unknown_runtime_mod", true,
  { kanto_ascendant = true })
assert(contains(result.conflicts, "kanto_ascendant")
    and result.conflictDetails.kanto_ascendant.policy == "exclusive",
  "unknown runtime mod can be re-enabled beside Ascendant")
result = ManagerState.resolveToggle(mods, "VOXEL_ASCENDANT", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.VOXEL_ASCENDANT == true,
  "reviewed Voxel Ascendant support was blocked in manager")
mods.VOXEL_ASCENDANT = voxelRc
result = ManagerState.resolveToggle(mods, "VOXEL_ASCENDANT", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.VOXEL_ASCENDANT == true,
  "reviewed Voxel Ascendant RC support was blocked in manager")
mods.VOXEL_ASCENDANT = external("VOXEL_ASCENDANT", "2.9.9",
  "Roxas2712/voxel-ascendant")
result = ManagerState.resolveToggle(mods, "VOXEL_ASCENDANT", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.VOXEL_ASCENDANT == true,
  "in-range Voxel Ascendant future release was blocked in manager")
mods.VOXEL_ASCENDANT = voxel
result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
  { kanto_ascendant = true })
assert(contains(result.conflicts, "kanto_ascendant"),
  "Battle Art 1.8.3 was not blocked by the series floor")
mods.BATTLE_ART_VOXEL_FORK = battleArt190
result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.BATTLE_ART_VOXEL_FORK == true,
  "reviewed Battle Art 1.9.0 support was blocked in manager")
mods.BATTLE_ART_VOXEL_FORK = battleArt192
result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.BATTLE_ART_VOXEL_FORK == true,
  "reviewed Battle Art 1.9.2 support was blocked in manager")
mods.BATTLE_ART_VOXEL_FORK = external("BATTLE_ART_VOXEL_FORK", "2.9.9",
  "absol89/DramaticShapeVoxelMod")
result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.BATTLE_ART_VOXEL_FORK == true,
  "in-range Battle Art future release was blocked in manager")
mods.potato_voxel = external("potato_voxel", "2.9.9",
  "ShaneMcGovernIE/potato_voxel")
result = ManagerState.resolveToggle(mods, "potato_voxel", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.potato_voxel == true,
  "in-range PotatoVoxel future release was blocked in manager")

local function encoded(mod)
  return Json.encode({
    id = mod.id, name = mod.name or mod.id, version = mod.version or "1.0.0",
    api = 2, entry = "main.lua", profile = "content", github = mod.github,
    dependencies = mod.dependencies or {},
    conflicts = mod.conflicts or {},
    priority = mod.priority or 0,
    exclusive = mod.exclusive,
    compatibility_conflicts = mod.compatibility_conflicts,
  })
end

local function statusById(loader)
  local result = {}
  for _, row in ipairs(loader:status().available) do result[row.id] = row end
  return result
end

-- Real Loader path with a replacement, an unknown package and two approved
-- presentation packages. Ascendant must remain loaded and boot stays clean.
local loaderRaw = assert(Json.decode(read(root .. "/manifest.json")))
loaderRaw.assets_transforms = nil
-- Synthetic policy loaders in a development checkout report 0.0.0-dev;
-- exact 0.1.90 range validation is a separate release gate.
loaderRaw.game_version = nil
local files = {
  ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
  ["mods/kanto_ascendant/main.lua"] = "return function() end",
}
for _, item in ipairs({
  { id = "trainer_rematch" },
  { id = "unknown_runtime_mod" },
  approved[4],
}) do
  files["mods/" .. item.id .. "/manifest.json"] = encoded(item)
  files["mods/" .. item.id .. "/main.lua"] = "return function() end"
end
local loader = Loader.new({ fs = sdk.memfs(files) })
assert(loader:load({}) == true,
  "default-deny stack should keep Ascendant boot clean")
local status = statusById(loader)
assert(status.kanto_ascendant.state == "loaded",
  "Ascendant lost the default-deny boot")
assert(status.trainer_rematch.state == "replaced"
    and status.trainer_rematch.replacedBy == "kanto_ascendant",
  "integrated rematch was not visibly replaced")
assert(status.unknown_runtime_mod.state == "not_approved"
    and status.unknown_runtime_mod.replacedBy == "kanto_ascendant",
  "unknown runtime package was not visibly blocked")
assert(status.VOXEL_ASCENDANT.state == "loaded",
  "reviewed Voxel Ascendant 0.1.90 build did not load")

-- The renderer-free closure plus supported-series DRAMALESS and Battle Art
-- closures boot cleanly. Out-of-range packages remain outside the allowlist.
local baseLoader = Loader.new({ fs = sdk.memfs({
  ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
  ["mods/kanto_ascendant/main.lua"] = "return function() end",
}) })
assert(baseLoader:load({}) == true
    and statusById(baseLoader).kanto_ascendant.state == "loaded",
  "the renderer-free base closure must boot on its own")

local dramaless = safeDramaless
local dramalessFiles = {
  ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
  ["mods/kanto_ascendant/main.lua"] = "return function() end",
  ["mods/DRAMALESS_SHAPE/manifest.json"] = encoded(dramaless),
  ["mods/DRAMALESS_SHAPE/main.lua"] = "return function() end",
}
local dramalessLoader = Loader.new({ fs = sdk.memfs(dramalessFiles) })
assert(dramalessLoader:load({}) == true,
  "the exact DRAMALESS ST.190.1 compatibility closure must boot")
local dramalessStatus = statusById(dramalessLoader)
assert(dramalessStatus.kanto_ascendant.state == "loaded"
    and dramalessStatus.DRAMALESS_SHAPE.state == "loaded",
  "the exact DRAMALESS ST.190.1 closure did not retain both packages")

local battleArtFiles = {
  ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
  ["mods/kanto_ascendant/main.lua"] = "return function() end",
  ["mods/BATTLE_ART_VOXEL_FORK/manifest.json"] = encoded(safeBattleArt),
  ["mods/BATTLE_ART_VOXEL_FORK/main.lua"] = "return function() end",
}
local battleArtLoader = Loader.new({ fs = sdk.memfs(battleArtFiles) })
assert(battleArtLoader:load({}) == true,
  "the exact upstream Battle Art 1.9.0 closure must boot")
local battleArtStatus = statusById(battleArtLoader)
assert(battleArtStatus.kanto_ascendant.state == "loaded"
    and battleArtStatus.BATTLE_ART_VOXEL_FORK.state == "loaded",
  "the exact Battle Art 1.9.0 closure did not retain both packages")

local renamedVoxel = external("renamed_voxel", "0.1.1",
  "Roxas2712/voxel-ascendant")
assert(Manifest.exclusiveAllows(ascendant, renamedVoxel),
  "the exact reviewed Voxel Ascendant repository rename was blocked")

-- Repository matching survives harmless package-id renames for integrated
-- credits and for version-pinned support packages.
local renamedCrystal = external("renamed_crystal", "9.9.9",
  "LOW-K3YS/crystal_animated_sprites_with_shiny_visuals")
assert(Manifest.replacement(ascendant, renamedCrystal),
  "renamed integrated repository bypassed replacement")
local renamedDramaless = external("renamed_dramaless", safeDramalessVersion,
  "artyrambles/DRAMALESS_SHAPE")
assert(Manifest.exclusiveAllows(ascendant, renamedDramaless),
  "the exact reviewed DRAMALESS repository rename was blocked")
local renamedBattleArt = external("renamed_battle_art", safeBattleArtVersion,
  "absol89/DramaticShapeVoxelMod")
assert(Manifest.exclusiveAllows(ascendant, renamedBattleArt),
  "the exact reviewed Battle Art repository rename was blocked")

for id in pairs(canonical) do
  assert(not contains(raw.optional_dependencies, id),
    id .. " cannot be both integrated and optional")
end

print("PASS mod policy: Ascendant wins; integrated replaced; unknown blocked; reviewed support pinned")
