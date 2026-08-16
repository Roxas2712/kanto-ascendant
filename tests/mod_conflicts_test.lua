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
  "trainer_rematch", "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge",
  "pokepc_followers_rb", "pokepcfollowers", "quality_of_life",
  "quality_of_life_pr9_test", "crystal_animated_sprites_with_shiny_visuals",
  "shiny_indicators",
  "gender_mod", "pokemon_gender", "pokemon_genders",
  "pokemon_gender_system", "gen2_pokemon_gender", "pokemon_breeding",
  "gen2_breeding", "useful_bag", "jj_quick_select", "nuzlocke",
  "overworld_wild_spawns",
}
local canonical = {
  trainer_rematch = true, PokePCFollowers_VoxelMerge = true,
  quality_of_life = true, crystal_animated_sprites_with_shiny_visuals = true,
  shiny_indicators = true, gender_mod = true, useful_bag = true, jj_quick_select = true,
  nuzlocke = true, overworld_wild_spawns = true,
}
local incompatibleRenderers = {
  "DRAMATIC_SHAPE", "potato_voxel", "TERRARIUM", "ds_fp_ceiling",
}
local safeBattleArtVersion = "1.9.0"
local unsafeBattleArtVersions = { "1.8.3", "1.9.1" }
local battleArtConflictSpec =
  "BATTLE_ART_VOXEL_FORK@<1.9.0 || >1.9.0"
local safeDramalessVersion = "1.6.2-ST.190.1"
local unsafeDramalessVersions = {
  "1.6.2-ST.190", "1.6.2-ST.190.2", "1.6.4",
}
local dramalessConflictSpec =
  "DRAMALESS_SHAPE@<1.6.2-ST.190.1 || >1.6.2-ST.190.1"
local approved = {
  { id = "deutsch", version = "1.0.0" },
  { id = "deutsch-blau", version = "1.0.0" },
  { id = "deutsch-gelb", version = "1.0.0" },
  { id = "all_pokemon_catchable_151_mod", version = "1.0.0" },
  { id = "VOXEL_ASCENDANT", version = "0.1.0-rc.1",
    github = "Roxas2712/voxel-ascendant" },
  { id = "VOXEL_ASCENDANT", version = "0.1.1",
    github = "Roxas2712/voxel-ascendant" },
  { id = "DRAMALESS_SHAPE", version = safeDramalessVersion,
    github = "artyrambles/DRAMALESS_SHAPE" },
  { id = "BATTLE_ART_VOXEL_FORK", version = safeBattleArtVersion,
    github = "absol89/DramaticShapeVoxelMod" },
}

local expectedClassic = {}
for _, id in ipairs(integrated) do expectedClassic[id] = true end
expectedClassic["Kanto-Reforged"] = true
for _, id in ipairs(incompatibleRenderers) do expectedClassic[id] = true end
expectedClassic[dramalessConflictSpec] = true
expectedClassic[battleArtConflictSpec] = true
local actualClassic = {}
for _, id in ipairs(raw.conflicts or {}) do actualClassic[id] = true end
for id in pairs(expectedClassic) do
  assert(actualClassic[id], "stock 0.1.90 conflict missing: " .. id)
end

for id in pairs(actualClassic) do
  assert(expectedClassic[id], "unexpected stock conflict: " .. id)
end
assert(#(raw.conflicts or {}) == 27 and #(raw.incompatible or {}) == 0,
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

-- Battle Art follows the same exact-package rule: only upstream 1.9.0 is
-- admitted; 1.8.3 still assigns forbidden callbacks/filesystem APIs and any
-- future release requires a fresh review.
local safeBattleArt = external("BATTLE_ART_VOXEL_FORK",
  safeBattleArtVersion, "absol89/DramaticShapeVoxelMod")
local parsedBattleArtConflict
for _, spec in ipairs(ascendant.conflictSpecs or {}) do
  if spec.id == "BATTLE_ART_VOXEL_FORK" then parsedBattleArtConflict = spec end
end
assert(parsedBattleArtConflict
    and parsedBattleArtConflict.range == "<1.9.0 || >1.9.0",
  "classic Battle Art 1.9.0 exception did not parse exactly")
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
    "unreviewed Battle Art was retained: " .. version)
  result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
    { kanto_ascendant = true })
  assert(contains(result.conflicts, "kanto_ascendant"),
    "reverse conflict allowed Battle Art " .. version)
end
do
  assert(not Semver.satisfies(safeBattleArtVersion,
      parsedBattleArtConflict.range),
    "classic Battle Art conflict range included 1.9.0")
  local mods = {
    kanto_ascendant = ascendant, BATTLE_ART_VOXEL_FORK = safeBattleArt,
  }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { BATTLE_ART_VOXEL_FORK = true })
  assert(#result.conflicts == 0,
    "versioned conflict blocked Battle Art 1.9.0")
  result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
    { kanto_ascendant = true })
  assert(#result.conflicts == 0,
    "reverse conflict blocked Battle Art 1.9.0")
end

-- The classic conflict grammar is version-aware on stock 0.1.90 as well as
-- on newer launchers. Only the hardened transition build is admitted; the
-- same real manifest ID at an older, newer or upstream version is blocked in
-- both toggle directions.
local safeDramaless = external("DRAMALESS_SHAPE", safeDramalessVersion,
  "artyrambles/DRAMALESS_SHAPE")
local parsedDramalessConflict
for _, spec in ipairs(ascendant.conflictSpecs or {}) do
  if spec.id == "DRAMALESS_SHAPE" then parsedDramalessConflict = spec end
end
assert(parsedDramalessConflict
    and parsedDramalessConflict.range ==
      "<1.6.2-ST.190.1 || >1.6.2-ST.190.1",
  "classic hardened-DRAMALESS exception did not parse exactly")
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
  assert(not Semver.satisfies(safeDramalessVersion,
      parsedDramalessConflict.range),
    "classic DRAMALESS conflict range included the hardened build")
  local mods = { kanto_ascendant = ascendant, DRAMALESS_SHAPE = safeDramaless }
  local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
    { DRAMALESS_SHAPE = true })
  assert(#result.conflicts == 0,
    "versioned conflict blocked hardened DRAMALESS ST.190.1")
  result = ManagerState.resolveToggle(mods, "DRAMALESS_SHAPE", true,
    { kanto_ascendant = true })
  assert(#result.conflicts == 0,
    "reverse versioned conflict blocked hardened DRAMALESS ST.190.1")
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

assert(ascendant.exclusive and #ascendant.compatibilityConflicts == 12,
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
      "Use Voxel Ascendant, Battle Art 1.9.0, the hardened DRAMALESS 1.6.2-ST.190.1 build, or native 2D."
      and detail.resolution_de ==
      "Verwende Voxel Ascendant, Battle Art 1.9.0, den gehärteten DRAMALESS-Build 1.6.2-ST.190.1 oder die native 2D-Darstellung.",
    "broken renderer resolution drifted: " .. id)
end
assert(Manifest.compatibilityConflict(ascendant, safeDramaless) == nil,
  "hardened DRAMALESS must not inherit the rich broken-renderer block")
assert(Manifest.compatibilityConflict(ascendant, safeBattleArt) == nil,
  "Battle Art 1.9.0 must not inherit the rich broken-renderer block")
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
    external("VOXEL_ASCENDANT", "0.1.2",
      "Roxas2712/voxel-ascendant")),
  "an unreviewed Voxel Ascendant version bypassed the exact RC pin")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", safeDramalessVersion,
      "other/DRAMALESS_SHAPE")),
  "a package spoofing the exact DRAMALESS id/version bypassed provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", "1.6.2-ST.190", "other/DRAMALESS_SHAPE")),
  "a package spoofing the renderer id bypassed repository provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", "1.6.2.ST",
      "artyrambles/DRAMALESS_SHAPE")),
  "the pre-sandbox DRAMALESS build bypassed the exact version pin")
assert(not Manifest.exclusiveAllows(ascendant,
    external("DRAMALESS_SHAPE", "1.6.4",
      "artyrambles/DRAMALESS_SHAPE")),
  "the sandbox-incompatible upstream DRAMALESS build was admitted")
assert(not Manifest.exclusiveAllows(ascendant,
    external("BATTLE_ART_VOXEL_FORK", "1.9.0",
      "someone-else/DramaticShapeVoxelMod")),
  "a package spoofing Battle Art id/version bypassed repository provenance")
assert(not Manifest.exclusiveAllows(ascendant,
    external("BATTLE_ART_VOXEL_FORK", "1.8.3",
      "absol89/DramaticShapeVoxelMod")),
  "Battle Art 1.8.3 bypassed the exact version pin")
assert(not Manifest.exclusiveAllows(ascendant,
    external("BATTLE_ART_VOXEL_FORK", "1.9.1",
      "absol89/DramaticShapeVoxelMod")),
  "unreviewed future Battle Art bypassed the exact version pin")
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
local voxel = external("VOXEL_ASCENDANT", "0.1.1",
  "Roxas2712/voxel-ascendant")
local voxelRc = external("VOXEL_ASCENDANT", "0.1.0-rc.1",
  "Roxas2712/voxel-ascendant")
local mods = {
  kanto_ascendant = ascendant, trainer_rematch = rematch,
  unknown_runtime_mod = unknown, VOXEL_ASCENDANT = voxel,
  BATTLE_ART_VOXEL_FORK = battleArt,
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
mods.VOXEL_ASCENDANT = voxel
result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
  { kanto_ascendant = true })
assert(contains(result.conflicts, "kanto_ascendant"),
  "Battle Art 1.8.3 was not blocked by the exact version guard")
mods.BATTLE_ART_VOXEL_FORK = battleArt190
result = ManagerState.resolveToggle(mods, "BATTLE_ART_VOXEL_FORK", true,
  { kanto_ascendant = true })
assert(#result.conflicts == 0 and result.apply.BATTLE_ART_VOXEL_FORK == true,
  "reviewed Battle Art 1.9.0 support was blocked in manager")

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
  approved[5],
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

-- The renderer-free closure plus exact DRAMALESS and Battle Art closures boot
-- cleanly. Other Voxel packages remain outside the allowlist.
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
