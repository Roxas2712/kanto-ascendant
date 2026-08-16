-- Public-contract regression for the legacy 1.7.1 and current 1.12.2 APIs.
--
-- Run from the Kanto Ascendant mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/wilds_1_7_1_compat_test.lua

local modulePath = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local fixtureVersion = os.getenv("WILDS_FIXTURE_VERSION") or "1.7.1"
local createCompat = assert(loadfile(modulePath .. "/wilds_compat.lua"))()
local encounterLevels =
  assert(loadfile(modulePath .. "/johto_encounter_levels.lua"))()

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local registered = {}
local handlers = {}
local optionValues = {
  johto_wilds_integration = true,
  living_world_enabled = true,
  living_world_density = "high",
  living_world_random_encounters = false,
  living_world_water = "swimming_sprites",
  living_world_caves = "reachable",
  living_world_grass = "immersed",
  living_world_idle = true,
  living_world_wander = true,
  living_world_chase = false,
  living_world_hidden = true,
  living_world_silhouettes = false,
  living_world_towns = true,
  wilds_town_pokemon_amount = "auto",
  wilds_town_pokemon_species = "mixed",
}
local mod = {
  id = "kanto_ascendant",
  path = "mods/kanto_ascendant",
  content = {
    sprites = {
      register = function(_, id, def) registered[id] = def end,
    },
  },
  options = {
    get = function(_, key) return optionValues[key] end,
  },
  events = {
    on = function(_, name, fn)
      handlers[name] = handlers[name] or {}
      handlers[name][#handlers[name] + 1] = fn
    end,
  },
  log = { info = function() end },
}
function mod:read(path)
  if path:find("assets/followers_runtime/", 1, true) then return "png" end
end

local data = {
  order = { "SENTRET", "HOOTHOOT" },
  species = {
    SENTRET = { dex = 161 },
    HOOTHOOT = { dex = 163 },
  },
  habitats = {
    SENTRET = { map = "ROUTE_1", terrain = "grass" },
    HOOTHOOT = { map = "ROUTE_2", terrain = "grass" },
  },
}
local followerCalls = {}
local spriteAssets = {}
function spriteAssets.follower(species, shiny)
  followerCalls[#followerCalls + 1] = { species = species, shiny = shiny }
  return ("mods/kanto_ascendant/assets/followers_runtime/%s/follower_%s.png")
    :format(shiny and "shiny" or "normal", species)
end

local research = { rolls = 0 }
function research.rollHabitat(
    mapId, terrain, _, _, _, routeAverageLevel)
  research.rolls = research.rolls + 1
  eq(mapId, "ROUTE_1", "the live Wilds map reaches Ascendant")
  eq(terrain, "grass", "the Wilds surface becomes grass terrain")
  eq(routeAverageLevel, 3,
    "the compatibility bridge forwards the rounded route average")
  return { species = "SENTRET", level = routeAverageLevel + 5 }
end

local migration = { pool = {} }
function migration.allowedSpeciesPool()
  local out = {}
  for index, species in ipairs(migration.pool) do out[index] = species end
  return out
end

local compat = createCompat(mod, {
  johtoResearch = research,
  johtoSignals = migration,
  data = data,
  spriteAssets = spriteAssets,
  encounterLevels = encounterLevels,
})
eq(compat.registeredSprites, 2,
  "all fixture Johto walker sheets register during load")
check(registered.KANTO_ASCENDANT_WILDS_SENTRET ~= nil,
  "normal Sentret has a stable content sprite")
eq(registered.KANTO_ASCENDANT_WILDS_SENTRET.frames, 6,
  "normal Sentret uses the six-frame walker contract")
eq(registered.KANTO_ASCENDANT_WILDS_SENTRET.walker, true,
  "normal Sentret is marked as a walker")
check(registered.KANTO_ASCENDANT_WILDS_SHINY_SENTRET ~= nil,
  "shiny Sentret has a stable content sprite")

local originalFollower = {
  isAvailable = function() return true, "fixture PokePC" end,
  resolve = function(_, species)
    if species == "PIKACHU" then
      return {
        id = "POKEPC_PIKACHU",
        image = "mods/PokePCFollowers_VoxelMerge/assets/sprites/follower_PIKACHU.png",
        frames = 6,
        walker = true,
        trueColor = true,
      }, { providerId = "followers_ex" }
    end
  end,
}

local logic = {
  activeMapId = "ROUTE_1",
  surfaceInfo = { surface = "GRASS" },
  render = {
    speciesSpriteIds = {},
    registrationInfo = {},
    invalidateAssetCache = function() end,
  },
  clearCalls = 0,
}
logic.mod = {
  world = {
    overworld = function() return { map = { id = "ROUTE_1" } } end,
  },
}
function logic:trySpawn(_, opts)
  return {
    species = opts.species or "PIDGEY",
    level = opts.level or 3,
  }
end
function logic:clearAll()
  self.clearCalls = self.clearCalls + 1
end

local provider
local refreshes = 0
local ambientClass = {}
function ambientClass.targetCount()
  return 2
end
function ambientClass.speciesPool()
  return { "PIKACHU", "RATTATA" }
end
function ambientClass:clearAll()
  self.clearCalls = self.clearCalls + 1
end
function ambientClass:spawnForMap()
  self.spawnCalls = self.spawnCalls + 1
end
local ambient = setmetatable({ clearCalls = 0, spawnCalls = 0 }, {
  __index = ambientClass,
})
local ambientCries = {
  CURATED = { PIKACHU = "Pikaa..." },
}
local forwardedOptions = {}
local wildsOwner = { id = "overworld_wild_spawns" }
local wilds = {
  version = fixtureVersion,
  logic = logic,
  render = logic.render,
  getSpriteProvider = function(id)
    if id == "followers_ex" then return originalFollower end
  end,
  registerSpriteProvider = function(id, value)
    eq(id, "followers_ex",
      "Ascendant extends Wilds' documented follower provider")
    provider = value
    return true
  end,
  refreshAllEntitySprites = function()
    refreshes = refreshes + 1
    return true
  end,
  ambient = ambient,
  lib = {
    mod = wildsOwner,
    require = function(name)
      if name == "ambient_cries" then return ambientCries end
      if name == "config" then
        return { setOption = function(_, key, value, source, opts)
          local active = assert(opts and opts.game, "fixture needs active game")
          active.mods = active.mods or {}
          active.mods.modOptions = active.mods.modOptions or {}
          local bucket = active.mods.modOptions.overworld_wild_spawns or {}
          active.mods.modOptions.overworld_wild_spawns = bucket
          bucket[key] = value
          active.save.options = active.save.options or {}
          active.save.options.modOptions = active.save.options.modOptions or {}
          local saved = active.save.options.modOptions.overworld_wild_spawns or {}
          active.save.options.modOptions.overworld_wild_spawns = saved
          saved[key] = value
          forwardedOptions[#forwardedOptions + 1] = {
            name = "mod.options_changed", mod = "overworld_wild_spawns",
            key = key, value = value, source = source,
          }
          return true
        end }
      end
      error("fixture module unavailable: " .. tostring(name))
    end,
  },
}

mod.find = function(id)
  if id == "overworld_wild_spawns" then
    return { id = id, version = fixtureVersion, exports = wilds }
  end
end
local game = {
  data = {
    sprites = registered,
    pokemon = {
      PIKACHU = { name = "PIKACHU" },
      -- A localized name proves the bridge uses the active game language
      -- rather than hard-coding an English species catalogue.
      SENTRET = { name = "WIESOR" },
    },
    encounters = {
      ROUTE_1 = {
        grass = {
          slots = {
            { species = "PIDGEY", level = 2 },
            { species = "RATTATA", level = 4 },
          },
        },
      },
    },
  },
  save = { options = {} },
  mods = {},
}
eq(compat.install(game, { random = function(lo) return lo end }), true,
  "Wilds installs through its public export")
eq(game.mods.modOptions.overworld_wild_spawns.spawn_density, "high",
  "Living Regions density forwards to the Wilds option namespace")
eq(game.mods.modOptions.overworld_wild_spawns.random_encounters, false,
  "Living Regions classic battle toggle forwards to Wilds")
eq(game.mods.modOptions.overworld_wild_spawns.enable_aggressive, false,
  "Living Regions behavior toggle forwards to Wilds")
eq(game.save.options.modOptions.overworld_wild_spawns.spawn_density, "high",
  "forwarded Living Regions options persist in the save option bucket")
if fixtureVersion == "1.12.2" then
  eq(game.mods.modOptions.overworld_wild_spawns.water_spawns,
    "swimming_sprites", "Wilds 1.12.2 receives its water choice value")
  eq(game.mods.modOptions.overworld_wild_spawns.cave_spawns, "reachable",
    "Wilds 1.12.2 receives its cave placement mode")
  eq(game.mods.modOptions.overworld_wild_spawns.town_pokemon, true,
    "Wilds 1.12.2 receives its peaceful town switch")
  eq(game.mods.modOptions.overworld_wild_spawns.wild_silhouettes, false,
    "Wilds 1.12.2 receives its silhouette switch")
  check(#forwardedOptions >= 12,
    "current Living Regions settings did not notify Wilds 1.12.2")
else
  eq(game.mods.modOptions.overworld_wild_spawns.water_spawns, true,
    "Wilds 1.7.1 receives its legacy boolean water value")
  eq(game.mods.modOptions.overworld_wild_spawns.cave_spawns, nil,
    "new cave settings do not leak into Wilds 1.7.1")
  check(#forwardedOptions >= 9,
    "legacy Living Regions settings did not notify Wilds 1.7.1")
end
eq(compat.wildsVersion, fixtureVersion,
  "the linked Wilds version remains visible")
eq(compat.providerInstalled, true,
  "the Johto follower provider is active")
eq(refreshes, 1,
  "existing visible entities refresh after provider registration")
eq(compat.townDensityWrapped, true,
  "the exact town Pokemon amount bridge is active")
eq(compat.townSpeciesWrapped, true,
  "the town Pokemon region bridge is active")
eq(compat.townCriesInstalled, true,
  "localized written cries are installed for ambient Pokemon")
eq(ambientCries.CURATED.PIKACHU, "PIKACHU!",
  "English game data supplies the English written species name")
eq(ambientCries.CURATED.SENTRET, "WIESOR!",
  "German game data supplies the German written species name")
eq(compat.runtimeStatus().townCryNames, 2,
  "diagnostics report every localized ambient cry name")
eq(ambientClass.targetCount(game, "PALLET_TOWN", {}), 2,
  "automatic town amount preserves Wilds' own map density")
optionValues.wilds_town_pokemon_amount = 0
eq(ambientClass.targetCount(game, "PALLET_TOWN", {}), 0,
  "town amount zero suppresses the ambient population")
optionValues.wilds_town_pokemon_amount = 4
eq(ambientClass.targetCount(game, "PALLET_TOWN", {}), 4,
  "an exact town amount overrides Wilds' random target")
eq(compat.runtimeStatus().townPokemonAmount, 4,
  "the live town amount is visible to diagnostics")
local function contains(pool, species)
  for _, value in ipairs(pool) do
    if value == species then return true end
  end
  return false
end
optionValues.wilds_town_pokemon_species = "kanto"
local townPool = ambientClass.speciesPool(game, "PALLET_TOWN", {})
eq(#townPool, 2, "Kanto-only keeps Wilds' native pool size")
check(contains(townPool, "PIKACHU") and not contains(townPool, "SENTRET"),
  "Kanto-only keeps Johto out of peaceful city walkers")
optionValues.wilds_town_pokemon_species = "mixed"
townPool = ambientClass.speciesPool(game, "PALLET_TOWN", {})
eq(#townPool, 2,
  "mixed towns cannot leak Johto before Driftglass opens migration")
check(contains(townPool, "PIKACHU") and not contains(townPool, "SENTRET"),
  "pre-Driftglass mixed towns remain Kanto-only")
optionValues.wilds_town_pokemon_species = "johto"
townPool = ambientClass.speciesPool(game, "PALLET_TOWN", {})
eq(#townPool, 2,
  "Johto-only safely falls back to native Kanto while migration is closed")
check(contains(townPool, "PIKACHU") and not contains(townPool, "SENTRET"),
  "the closed receiver never leaks Johto through the fallback pool")

migration.pool = { "SENTRET", "HOOTHOOT" }
optionValues.wilds_town_pokemon_species = "mixed"
townPool = ambientClass.speciesPool(game, "PALLET_TOWN", {})
eq(#townPool, 4, "open migration combines Kanto and permitted Johto pools")
check(contains(townPool, "PIKACHU") and contains(townPool, "SENTRET"),
  "mixed towns expose only the receiver-permitted Johto set")
optionValues.wilds_town_pokemon_species = "johto"
townPool = ambientClass.speciesPool(game, "PALLET_TOWN", {})
eq(#townPool, 2, "Johto-only uses the permitted authored subset")
check(contains(townPool, "SENTRET") and not contains(townPool, "PIKACHU"),
  "Johto-only removes Kanto after Driftglass opens migration")
eq(compat.runtimeStatus().townPokemonSpecies, "johto",
  "the selected town region is visible to diagnostics")

local def, meta = provider:resolve("SENTRET", "normal", game)
eq(def.frames, 6, "visible Sentret keeps six animation frames")
eq(def.walker, true, "visible Sentret uses walker poses")
check(def.image:find("follower_SENTRET.png", 1, true) ~= nil,
  "visible Sentret uses its bundled species sheet")
eq(meta.kind, "kanto_ascendant_johto",
  "diagnostics identify the Ascendant Johto provider")

local shinyDef, shinyMeta = provider:resolve(161, "shiny", game)
check(shinyDef.image:find("/shiny/", 1, true) ~= nil,
  "numeric dex 161 resolves the bundled shiny sheet")
eq(shinyMeta.usedVariant, "shiny",
  "shiny provider metadata remains exact")

local kantoDef = provider:resolve("PIKACHU", "normal", game)
eq(kantoDef.id, "POKEPC_PIKACHU",
  "Kanto species still delegate to the installed follower provider")

local record = logic:trySpawn(game, {})
eq(record.species, "SENTRET",
  "enabled integration turns a Wilds Route 1 spawn into Sentret")
eq(record.level, 8,
  "the visible Johto spawn applies the configured minimum route bonus")
eq(research.rolls, 1,
  "one visible spawn performs one research roll")

optionValues.johto_wilds_integration = false
record = logic:trySpawn(game, {})
eq(record.species, "PIDGEY",
  "VISIBLE JOHTO off leaves Wilds' native species untouched")
eq(research.rolls, 1,
  "disabled integration performs no hidden Johto roll")
eq(compat.runtimeStatus().enabled, false,
  "the menu can report the disabled bridge")

for _, handler in ipairs(handlers["mod.options_changed"] or {}) do
  handler({
    mod = "some_other_mod",
    key = "johto_wilds_integration",
  })
end
eq(logic.clearCalls, 0,
  "another mod's similarly named option does not clear Wilds entities")
for _, handler in ipairs(handlers["mod.options_changed"] or {}) do
  handler({
    mod = "kanto_ascendant",
    key = "johto_wilds_integration",
  })
end
eq(logic.clearCalls, 1,
  "changing VISIBLE JOHTO clears stale visible encounter rolls")
for _, handler in ipairs(handlers["mod.options_changed"] or {}) do
  handler({
    mod = "kanto_ascendant",
    key = "johto_signals_enable",
  })
end
eq(logic.clearCalls, 2,
  "disabling early Johto also clears stale visible Johto entities")
for _, handler in ipairs(handlers["mod.options_changed"] or {}) do
  handler({
    mod = "kanto_ascendant",
    key = "wilds_town_pokemon_amount",
  })
end
eq(ambient.clearCalls, 1,
  "changing the town amount removes the old ambient population")
eq(ambient.spawnCalls, 1,
  "changing the town amount immediately repopulates the current safe map")
for _, handler in ipairs(handlers["mod.options_changed"] or {}) do
  handler({
    mod = "kanto_ascendant",
    key = "wilds_town_pokemon_species",
  })
end
eq(ambient.clearCalls, 2,
  "changing the town region removes the previous decorative population")
eq(ambient.spawnCalls, 2,
  "changing the town region immediately repopulates the current safe map")

for _, handler in ipairs(
    handlers["mod.kanto_ascendant.johto_migration_changed"] or {}) do
  handler({ reason = "wave-rotated" })
end
eq(logic.clearCalls, 3,
  "a Driftglass wave change removes stale visible route entities")
eq(ambient.clearCalls, 3,
  "a Driftglass wave change removes stale town Johto entities")
eq(ambient.spawnCalls, 3,
  "the current town is repopulated from the newly permitted wave")

optionValues.living_world_density = "very_high"
for _, handler in ipairs(handlers["mod.options_changed"] or {}) do
  handler({
    mod = "kanto_ascendant",
    key = "living_world_density",
  })
end
eq(game.mods.modOptions.overworld_wild_spawns.spawn_density, "very_high",
  "a live Living Regions change reaches Wilds immediately")

print(("WILDS %s COMPAT PASS: %d assertions")
  :format(fixtureVersion, assertions))
