-- Foreign-mod discovery contract for exact engine 0.1.86.
-- Consumers may see only explicit mod.find(id).exports capabilities; missing
-- and malformed handles fail closed without a loader-global alias.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local calls, handles = {}, {}
local function find(id)
  calls[#calls + 1] = id
  return handles[id]
end

local options = {
  pokemon_sprite_style = "crystal",
  sprite_style_battle = true,
  kanto_crystal_art = true,
  legend_art = "crystal",
}
local mod = {
  id = "kanto_ascendant",
  path = root,
  find = find,
  read = function() return nil end,
  options = { get = function(_, key) return options[key] end },
  events = { on = function() end },
  hooks = { wrap = function() end },
  save = { get = function() return nil end, set = function() end },
  content = { battle_sprite_scales = { register = function() end } },
  exports = {},
}

local crystal = assert(loadfile(root .. "/crystal_animation.lua"))()(mod, {})
assert(crystal.externalKantoActive(25) == false,
  "missing Crystal handle did not fail closed")
handles.crystal_animated_sprites_with_shiny_visuals = {
  id = "crystal_animated_sprites_with_shiny_visuals", version = "old",
  exports = "malformed",
}
assert(crystal.externalKantoActive(25) == false,
  "malformed Crystal exports became active")
handles.crystal_animated_sprites_with_shiny_visuals.exports = { api = 1 }
assert(crystal.externalKantoActive(25) == true,
  "valid Crystal exports were not discovered through mod.find")

local shiny = assert(loadfile(root .. "/shiny_system.lua"))()(mod, {})
shiny.game = { data = { pokemon = { PIKACHU = { dex = 25 } } } }
handles.shiny_indicators = nil
handles.crystal_animated_sprites_with_shiny_visuals = nil
assert(shiny.externalActive({ species = "PIKACHU" }) == false,
  "missing shiny capabilities did not fail closed")
handles.shiny_indicators = {
  id = "shiny_indicators", version = "unknown", exports = "malformed",
}
assert(shiny.externalActive({ species = "PIKACHU" }) == false,
  "malformed shiny-indicator export became active")
handles.shiny_indicators.exports = { statusIcon = function() end }
assert(shiny.externalActive({ species = "PIKACHU" }) == true,
  "valid shiny-indicator export was not discovered through mod.find")
handles.shiny_indicators = nil
handles.crystal_animated_sprites_with_shiny_visuals = {
  id = "crystal_animated_sprites_with_shiny_visuals",
  version = "any", exports = { api = 1 },
}
assert(shiny.externalActive({ species = "PIKACHU" }) == true,
  "valid Crystal capability did not suppress duplicate shiny visuals")

local allowed = {
  crystal_animated_sprites_with_shiny_visuals = true,
  shiny_indicators = true,
}
assert(#calls >= 8, "foreign consumers did not exercise mod.find")
for _, id in ipairs(calls) do
  assert(allowed[id], "unexpected foreign id was queried: " .. tostring(id))
end

local consumers = {
  ["extended_species_runtime.lua"] = { "overworld_wild_spawns" },
  ["follower_compat.lua"] = { "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge" },
  ["yellow_partner.lua"] = { "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge" },
  ["single_follower.lua"] = { "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge" },
  ["johto_signals_hub.lua"] = { "overworld_wild_spawns" },
  ["johto_signals_wilds.lua"] = { "overworld_wild_spawns" },
  ["crystal_animation.lua"] = { "crystal_animated_sprites_with_shiny_visuals" },
  ["shiny_system.lua"] = {
    "shiny_indicators", "crystal_animated_sprites_with_shiny_visuals",
  },
  ["wilds_compat.lua"] = { "overworld_wild_spawns" },
  ["voxel_renderer_compat.lua"] = {
    "VOXEL_ASCENDANT", "DRAMALESS_SHAPE",
  },
}
for file, ids in pairs(consumers) do
  local handle = assert(io.open(root .. "/" .. file, "rb"))
  local body = handle:read("*a"); handle:close()
  assert(not body:find("game.mods.exports", 1, true)
      and not body:find("loader.exports", 1, true)
      and not body:find("loader.mods", 1, true),
    file .. " still uses a loader-global foreign channel")
  for _, id in ipairs(ids) do
    assert(body:find(id, 1, true), file .. " lost explicit id " .. id)
  end
  assert(body:find("mod.find", 1, true), file .. " does not use mod.find")
end

local internal = assert(io.open(root .. "/internal_wilds.lua", "rb")):read("*a")
assert(not internal:find("currentGame.mods.exports", 1, true),
  "bundled Wilds still publishes a foreign global alias")
assert(not internal:find("mods.modOptions", 1, true)
    and not internal:find("loader.modOptions", 1, true),
  "bundled Wilds still reads a foreign loader option bucket")
assert(internal:find("local function game()", 1, true)
    and internal:find("return proxy.world and proxy.world.game", 1, true),
  "bundled Wilds lost its sandbox-safe active-game accessor")
assert(internal:find("voxelRenderer.isRendererRequest(id)", 1, true)
    and internal:find("hit = voxelRenderer.findAlias(mod, id)", 1, true),
  "bundled Wilds lost its pinned historical renderer request bridge")
local renderer = assert(io.open(
  root .. "/voxel_renderer_compat.lua", "rb")):read("*a")
assert(renderer:find('DRAMATIC_SHAPE = true', 1, true),
  "renderer authority lost the historical Wilds request mapping")
assert(renderer:find('R.ids = {\n    "VOXEL_ASCENDANT",\n    "DRAMALESS_SHAPE",', 1, true)
    and not renderer:find('R.ids = {\n    "DRAMATIC_SHAPE",', 1, true),
  "historical request was incorrectly promoted to an approved renderer id")

-- Gold_Silver_Sprites 1.0.1 publishes no option API. Its private loader/save
-- buckets must never be inspected; a future explicit export may opt in.
local providerDeps = {
  config = {}, runtime_sheets = {}, debug_log = {}, luminance_sheet = {},
  animated_sprites = { normalizeVariant = function(v) return v end },
}
local SpriteProviders = assert(loadfile(
  root .. "/vendor/wilds_1_12_2/lib/sprite_providers.lua"))({
    require = function(name) return assert(providerDeps[name], name) end,
    exists = function() return false end,
  })
local goldHandle
local goldOwner = setmetatable({
  mod = { find = function(id)
    assert(id == "Gold_Silver_Sprites", "unexpected Gold provider id")
    return goldHandle
  end },
}, { __index = SpriteProviders })
local poisonedGame = {
  save = { options = { modOptions = {
    Gold_Silver_Sprites = { spritePack = "silver" },
  } } },
  mods = { modOptions = {
    Gold_Silver_Sprites = { spritePack = "silver" },
  }, loader = { modOptions = {
    Gold_Silver_Sprites = { spritePack = "silver" },
  } } },
}
assert(goldOwner:_goldPackChoice(poisonedGame) == "gold",
  "Gold provider read a private option bucket")
goldHandle = { id = "Gold_Silver_Sprites", exports = "malformed" }
assert(goldOwner:_goldPackChoice(poisonedGame) == "gold",
  "malformed Gold exports did not fail closed")
goldHandle.exports = { spritePack = "silver" }
assert(goldOwner:_goldPackChoice(poisonedGame) == "silver",
  "public Gold spritePack export was ignored")
goldHandle.exports = { getSpritePack = function() return "silver" end }
assert(goldOwner:_goldPackChoice(poisonedGame) == "silver",
  "public Gold pack getter was ignored")
goldHandle.exports = { spritePack = "bronze" }
assert(goldOwner:_goldPackChoice(poisonedGame) == "gold",
  "invalid Gold pack export did not fail closed")

local providerSource = assert(io.open(
  root .. "/vendor/wilds_1_12_2/lib/sprite_providers.lua", "rb")):read("*a")
assert(not providerSource:find("game.save.options.modOptions", 1, true)
    and not providerSource:find("game.mods.modOptions", 1, true)
    and not providerSource:find("game.mods.loader.modOptions", 1, true),
  "Gold provider still reads a private foreign option bucket")

print("PASS sandbox 0.1.86 cross-mod: explicit ids, missing/malformed fail closed, no aliases")
