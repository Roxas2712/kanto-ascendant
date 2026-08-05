-- Exact public-contract regression for Wilds of Kanto 1.7.1.
--
-- Run from the Kanto Ascendant mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/wilds_1_7_1_compat_test.lua

local modulePath = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local createCompat = assert(loadfile(modulePath .. "/wilds_compat.lua"))()

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
local optionValues = { johto_wilds_integration = true }
local mod = {
  id = "trainer_rematch",
  path = "mods/trainer_rematch",
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
}
local followerCalls = {}
local spriteAssets = {}
function spriteAssets.follower(species, shiny)
  followerCalls[#followerCalls + 1] = { species = species, shiny = shiny }
  return ("mods/trainer_rematch/assets/followers_runtime/%s/follower_%s.png")
    :format(shiny and "shiny" or "normal", species)
end

local research = { rolls = 0 }
function research.rollHabitat(mapId, terrain)
  research.rolls = research.rolls + 1
  eq(mapId, "ROUTE_1", "the live Wilds map reaches Ascendant")
  eq(terrain, "grass", "the Wilds surface becomes grass terrain")
  return { species = "SENTRET", level = 12 }
end

local compat = createCompat(mod, {
  johtoResearch = research,
  data = data,
  spriteAssets = spriteAssets,
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
local wilds = {
  version = "1.7.1",
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
}

local game = {
  data = { sprites = registered },
  mods = { exports = { overworld_wild_spawns = wilds } },
}
eq(compat.install(game, { random = function(lo) return lo end }), true,
  "Wilds 1.7.1 installs through its public export")
eq(compat.wildsVersion, "1.7.1",
  "the linked Wilds version remains visible")
eq(compat.providerInstalled, true,
  "the Johto follower provider is active")
eq(refreshes, 1,
  "existing visible entities refresh after provider registration")

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
eq(record.level, 12,
  "the visible Johto spawn keeps its authored habitat level")
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
    mod = "trainer_rematch",
    key = "johto_wilds_integration",
  })
end
eq(logic.clearCalls, 1,
  "changing VISIBLE JOHTO clears stale visible encounter rolls")
for _, handler in ipairs(handlers["mod.options_changed"] or {}) do
  handler({
    mod = "trainer_rematch",
    key = "johto_signals_enable",
  })
end
eq(logic.clearCalls, 2,
  "disabling early Johto also clears stale visible Johto entities")

print(("WILDS 1.7.1 COMPAT PASS: %d assertions"):format(assertions))
