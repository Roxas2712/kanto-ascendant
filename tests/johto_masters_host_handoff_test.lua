-- The Indigo host is a production map-script event.  This focused test keeps
-- the legacy trial factory honest: when passage content is present, spawning
-- and speaking to the host must delegate to the Gate Hall, never to Rival-2.
local make = assert(loadfile("johto_masters.lua"))()
local data = assert(loadfile("johto_masters_data.lua"))()

-- BLITZ carried lifetime wins from the removed direct lobby gauntlet, but no
-- connected Silver/Kris/Gold passage receipt.  It must therefore still see
-- the first real arena host after migration.
local saved = { johto_masters = {
  version = 2, clears = 4, gifts = 4, title = true,
  passages = {
    silver = { status = "locked" }, kris = { status = "locked" },
    gold = { status = "locked" },
  },
} }
local spawned, removed, scripts = {}, {}, {}
local gameData
local handlers = {}
local overworld = { map = {
  id = "INDIGO_PLATEAU_LOBBY", widthCells = 20, heightCells = 16,
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 20 and y < 16 end,
  isWalkableCell = function() return true end,
  warpAtCell = function() return nil end,
}, npcAtCell = function() return nil end, player = {
  cellX = 5, cellY = 5,
} }
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  events = { on = function(_, name, fn) handlers[name] = fn end },
  content = { map_scripts = {
    register = function(_, mapId, spec) scripts[mapId] = spec end,
  } },
  world = {
    overworld = function() return overworld end,
    spawnNpc = function(_, mapId, def)
      spawned[#spawned + 1] = { mapId = mapId, def = def }
      local objects = gameData.maps[mapId].objects
      def.index = #objects + 1
      def.runtime, def.owner = true, "kanto_ascendant"
      objects[#objects + 1] = def
      overworld.npcs = overworld.npcs or {}
      overworld.npcs[#overworld.npcs + 1] = {
        id = mapId .. "_obj_" .. def.index, def = def,
      }
    end,
    removeNpc = function(_, id)
      removed[#removed + 1] = id
      for index = #gameData.maps.INDIGO_PLATEAU_LOBBY.objects, 1, -1 do
        local object = gameData.maps.INDIGO_PLATEAU_LOBBY.objects[index]
        if "INDIGO_PLATEAU_LOBBY_obj_" .. object.index == id then
          table.remove(gameData.maps.INDIGO_PLATEAU_LOBBY.objects, index)
        end
      end
      for index = #(overworld.npcs or {}), 1, -1 do
        if overworld.npcs[index].id == id then table.remove(overworld.npcs, index) end
      end
    end,
  },
}
local postgame = {
  -- A migrated Hall-of-Fame save need not have completed the later CROWN
  -- ladder; the Johto host must still be present until his own sequence is
  -- played.
  state = function() return { crownChampion = false } end,
  hasHallOfFame = function(save) return #(save.hallOfFame or {}) > 0 end,
}
local hostCalls = 0
local archiveSyncs = 0
local gameSave
local passages = {
  contentEnabled = true,
  install = function() end,
  hostTalk = function(game, ow, npc)
    hostCalls = hostCalls + 1
    assert(game.save == gameSave and ow == overworld and npc.def.text == data.textId)
    return "gate-hall"
  end,
}
local masters = make(mod, {
  data = data, postgame = postgame, shinySystem = { forceMon = function() end },
  journey = { syncJohtoMastersPersistent = function(save)
    assert(save == gameSave, "Johto persistence received a detached save")
    archiveSyncs = archiveSyncs + 1
    return true
  end },
})
masters.passages = passages
gameSave = { hallOfFame = { {} }, objectToggles = {
  INDIGO_PLATEAU_LOBBY = { KANTO_ASCENDANT_JOHTO_MASTERS = false },
} }
gameData = { maps = { INDIGO_PLATEAU_LOBBY = { objects = {} } } }
local game = { save = gameSave, data = gameData,
  stack = { push = function() end } }

masters.install(game)
local syncsAfterInstall = archiveSyncs
assert(syncsAfterInstall >= 1,
  "Johto cadence migration was not synchronized during install")
assert(masters.persist(masters.state(), game),
  "Johto controller could not synchronize its live persistence bucket")
assert(archiveSyncs == syncsAfterInstall + 1,
  "Johto controller did not immediately synchronize the Journey archive")
assert(#spawned == 1, "eligible Indigo lifecycle did not spawn the Johto host")
local host = spawned[1]
assert(host.mapId == "INDIGO_PLATEAU_LOBBY" and host.def.text == data.textId,
  "Indigo host did not expose johtoMastersData.textId")
assert(host.def.x == 10 and host.def.y == 8,
  "Indigo host did not use the authored public visitor-floor position")
assert(data.publicArea.minY == 7 and host.def.y >= data.publicArea.minY,
  "Indigo host regressed into the staff/counter area")
assert(host.def.trainerClass == nil,
  "Indigo host must not retain the legacy Rival-2 direct-gauntlet class")
assert(game.save.objectToggles.INDIGO_PLATEAU_LOBBY[data.name] == nil,
  "eligible host did not clear a stale hidden-object toggle")

-- A runtime definition can outlive its pooled live actor after a seamless
-- reload.  The host lifecycle must replace that stale definition exactly
-- once instead of treating it as proof that the visible NPC still exists.
overworld.npcs = {}
handlers["map.reloaded"]({ mapId = "INDIGO_PLATEAU_LOBBY" })
assert(#removed == 1 and #spawned == 2,
  "map reload did not reconcile a stale host definition")
assert(#gameData.maps.INDIGO_PLATEAU_LOBBY.objects == 1
    and #overworld.npcs == 1,
  "map reload did not restore exactly one live Johto host")
local talk = assert(scripts.INDIGO_PLATEAU_LOBBY).talk[data.textId]
assert(talk(game, overworld, { def = host.def }) == nil,
  "map script callback must own the host response")
assert(hostCalls == 1, "Indigo host did not hand off to passage hostTalk")

-- Completing the connected run consumes the current Hall-of-Fame ticket.
-- The host stays gone at the same count, then returns once and only once for
-- a subsequent Elite-Four receipt.
local cadence = masters.state()
cadence.activeRun = false
cadence.connectedClears, cadence.journeyClears = 1, 1
cadence.runSerial, cadence.rewardedRunSerial = 1, 1
cadence.lastHallTicket = #game.save.hallOfFame
cadence.passages.gold.status, cadence.passages.gold.rewarded = "cleared", true
assert(masters.persist(cadence, game))
masters.refresh(game, "INDIGO_PLATEAU_LOBBY")
assert(#gameData.maps.INDIGO_PLATEAU_LOBBY.objects == 0
    and #overworld.npcs == 0,
  "consumed Hall ticket left a duplicate Johto host alive")
game.save.hallOfFame[#game.save.hallOfFame + 1] = {}
masters.refresh(game, "INDIGO_PLATEAU_LOBBY")
local respawnCount = #spawned
assert(#gameData.maps.INDIGO_PLATEAU_LOBBY.objects == 1
    and #overworld.npcs == 1,
  "Elite-Four re-clear did not unlock the next Johto shiny run")
masters.refresh(game, "INDIGO_PLATEAU_LOBBY")
assert(#spawned == respawnCount and #overworld.npcs == 1,
  "refresh duplicated the re-unlocked Johto host")
print("johto_masters_host_handoff_test: PASS")
