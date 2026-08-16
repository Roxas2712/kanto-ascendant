local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local hooks, events, scripts = {}, {}, {}
local spawned, removed = 0, 0
local mod = {
  id = "kanto_ascendant",
  log = { error = function() end },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  content = { map_scripts = { register = function(_, map, def)
    scripts[map] = scripts[map] or {}
    scripts[map][#scripts[map] + 1] = def
  end } },
  world = {
    spawnNpc = function()
      spawned = spawned + 1
      return "runtime:" .. spawned
    end,
    removeNpc = function() removed = removed + 1 return true end,
  },
}

local current = {
  runId = "RUN:1", cycle = 1, avatarQuestStage = 0,
  pathComplete = false, completedPaths = {},
}
local durable = {
  completedPaths = { red = false, blue = false, green = false },
  pathSealCycles = {},
  current = { cycle = 1 },
  legacyPass = false,
}
local calls = { avatar = 0, stage = 0, finale = 0 }
local journey = {
  state = function() return current end,
  profile = function()
    return { current = durable.current, completedPaths = durable.completedPaths,
      pathSealCycles = durable.pathSealCycles,
      legacyPass = durable.legacyPass }
  end,
  setAvatar = function(_, avatar)
    calls.avatar = calls.avatar + 1
    current.avatar = avatar
    return true
  end,
  advancePath = function(_, stage, complete)
    calls.stage = calls.stage + 1
    current.avatarQuestStage = stage
    current.pathComplete = complete == true
    if complete then durable.completedPaths[current.avatar:lower()] = true end
    return true
  end,
  completeFinale = function()
    calls.finale = calls.finale + 1
    durable.legacyPass = true
    return true
  end,
}
local wanderers = {
  progressTier = function()
    return { targetLevel = 30, teamSize = 3, badges = 4,
      cycle = 2, pact = "journey" }
  end,
}
local data = assert(loadfile("legacy_paths_data.lua"))()
local makePaths = assert(loadfile("legacy_paths.lua"))()
local paths = makePaths(mod, {
  journey = journey, wanderers = wanderers, data = data,
  i18n = { text = function(en) return en end },
})

ok(scripts.ROUTE_3 ~= nil, "red route station registers a map script")
ok(scripts.ROUTE_4 ~= nil, "blue research station registers a map script")
ok(scripts.ROUTE_2 ~= nil, "green trail station registers a map script")
ok(scripts.OAKS_LAB ~= nil, "meta finale registers in Oak's lab")

local save = {
  inventory = {},
  modData = { kanto_ascendant = { legacy_journey = current,
    extended_characters = { enabled = true, player_character = "RED" } } },
}
ok(type(events["character.selected"]) == "function",
  "Fresh-Save character selection registers an immediate path listener")
events["character.selected"]({ save = save })
eq(current.avatar, "RED", "red character activates red path")
eq(calls.avatar, 1, "avatar is persisted exactly once")

local locked = paths.objective({ save = save })
eq(locked.target, 2, "first red station needs two badges")
eq(locked.location, "KANTO GYMS", "locked station hides its route")
save.inventory.BOULDERBADGE = 1
save.inventory.CASCADEBADGE = 1
local game = {
  save = save,
  data = { constants = { badges = {
    { id = "BOULDERBADGE" }, { id = "CASCADEBADGE" },
    { id = "THUNDERBADGE" }, { id = "RAINBOWBADGE" },
    { id = "SOULBADGE" }, { id = "MARSHBADGE" },
    { id = "VOLCANOBADGE" }, { id = "EARTHBADGE" },
  } } },
}
local unlocked = paths.objective(game)
eq(unlocked.location, "ROUTE 3", "two badges reveal the red route")

local map = {
  id = "ROUTE_3", widthCells = 12, heightCells = 12,
  inBounds = function(_, x, y) return x >= 0 and x < 12 and y >= 0 and y < 12 end,
  isWalkableCell = function() return true end,
  warpAtCell = function() return nil end,
  signAtCell = function() return nil end,
  isWarpTileCell = function() return false end,
}
local ow = {
  map = map, player = { cellX = 5, cellY = 5 },
  scriptMoves = {}, engaging = false,
  npcAtCell = function() return nil end,
  runner = { isRunning = function() return false end },
}
game.overworld = ow
game.stack = { top = function() return ow end }
game.data.maps = { ROUTE_3 = { objects = {} } }
ok(paths.refresh(game, "ROUTE_3"), "eligible stage spawns on its exact route")
eq(spawned, 1, "eligible station creates one runtime NPC")
ok(paths.refresh(game, "ROUTE_3"), "refresh keeps the existing stage NPC")
eq(spawned, 1, "refresh never duplicates a stage NPC")

local team = paths.scaledTeam(game,
  { "TAUROS", "STARMIE", "SNORLAX", "GENGAR", "DRAGONITE" }, 2)
eq(team[1].level, 34, "path level uses stable progression tier")
save.party = { { hp = 1, level = 2 } }
save.money = 0
local unchanged = paths.scaledTeam(game,
  { "TAUROS", "STARMIE", "SNORLAX", "GENGAR", "DRAGONITE" }, 2)
eq(unchanged[1].level, team[1].level,
  "damaged party and empty wallet never lower path battles")

map.isWalkableCell = function() return false end
paths.spawned = nil
eq(paths.findSpawnCell(ow), nil, "blocked map has no legal quest spawn")

durable.completedPaths.red = true
durable.completedPaths.blue = true
durable.completedPaths.green = false
durable.pathSealCycles.red = 1
durable.pathSealCycles.blue = 1
ok(not paths.allPathsComplete(), "two seals do not unlock the finale")
durable.completedPaths.green = true
durable.pathSealCycles.green = 1
ok(paths.allPathsComplete(), "all three seals unlock the finale")
local finale = paths.objective(game)
eq(finale.id, "legacy_finale", "Oak finale becomes the active objective")
ok(not paths.titleUnlocked("legacy_pass"), "final title waits for finale win")
durable.legacyPass = true
ok(paths.titleUnlocked("legacy_pass"), "permanent pass unlocks its title")
eq(paths.titleName("legacy_path_green"), "WILDERNESS KEEPER",
  "green seal exposes its permanent title")

local finaleStarts = 0
paths.setFinale({ start = function(_, _, npc)
  finaleStarts = finaleStarts + 1
  npc.frozen = true
  return true
end })
local oakNpc = { frozen = false }
scripts.OAKS_LAB[#scripts.OAKS_LAB].talk.KA_LEGACY_FINALE(game, ow, oakNpc)
eq(finaleStarts, 1, "authoritative Oak controller replaces the old generic finale")
ok(oakNpc.frozen, "Oak controller owns the finale NPC handoff")

print(("legacy paths: %d assertions"):format(assertions))
