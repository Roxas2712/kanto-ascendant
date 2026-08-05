-- Focused, ROM-free tests for the production Johto Signals state/content
-- boundary.
--
-- Run from either repository:
--   luajit tests/johto_signals_content_test.lua

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local root = testDir:match("^(.*)/tests$") or "."

local function loadModule(name)
  return assert(loadfile(root .. "/" .. name))()
end

local function equal(actual, expected, message)
  if actual ~= expected then
    error(("%s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local function truthy(value, message)
  if not value then error(message, 2) end
end

local function registry()
  local R = { values = {}, order = {} }
  function R:register(id, value)
    assert(self.values[id] == nil, "duplicate registration: " .. id)
    self.values[id] = value
    self.order[#self.order + 1] = id
  end
  function R:get(id) return self.values[id] end
  return R
end

local function fakeMod(bucket)
  local language = "en"
  local saveStats = { get = 0, set = 0 }
  local events = { rows = {} }
  function events:on(name, fn, priority)
    self.rows[name] = self.rows[name] or {}
    self.rows[name][#self.rows[name] + 1] = {
      fn = fn, priority = priority,
    }
  end

  local items, maps, scripts = registry(), registry(), registry()
  local current = { mapId = "PALLET_TOWN", x = 10, y = 12 }
  local warps = {}
  local liveGame
  local nextChoice = true
  local blocked = {}
  local mod = {
    id = "trainer_rematch",
    save = {
      get = function(_, key)
        saveStats.get = saveStats.get + 1
        return bucket[key]
      end,
      set = function(_, key, value)
        saveStats.set = saveStats.set + 1
        bucket[key] = value
      end,
    },
    events = events,
    content = {
      items = items,
      maps = maps,
      map_scripts = scripts,
    },
    log = {
      errors = {},
      error = function(self, formatString, value)
        self.errors[#self.errors + 1] = formatString:format(value)
      end,
    },
  }
  local liveMap = {
    id = "PALLET_TOWN",
    heightCells = 18,
    widthCells = 20,
    inBounds = function(_, x, y)
      return x >= 0 and x < 20 and y >= 0 and y < 18
    end,
    isWalkableCell = function(_, x, y)
      return blocked[x .. ":" .. y] ~= true
    end,
    warpAtCell = function() return nil end,
  }
  local liveOverworld = {
    map = liveMap,
    player = { cellX = 10, cellY = 12 },
    npcAtCell = function() return nil end,
  }
  mod.world = {
    current = function() return current end,
    overworld = function()
      liveMap.id = current.mapId
      return liveOverworld
    end,
    warpTo = function(_, mapId, x, y, facing)
      warps[#warps + 1] = {
        mapId = mapId, x = x, y = y, facing = facing,
      }
      current = { mapId = mapId, x = x, y = y, facing = facing }
      return true
    end,
    spawnNpc = function(_, mapId, object)
      local map = liveGame and liveGame.data.maps[mapId]
      if not map then return nil, "unknown map" end
      map.objects = map.objects or {}
      local copy = {}
      for key, value in pairs(object) do copy[key] = value end
      copy.index = #map.objects + 1
      copy.runtime = true
      copy.owner = mod.id
      map.objects[#map.objects + 1] = copy
      return mapId .. "_obj_" .. copy.index
    end,
    removeNpc = function(_, id)
      for mapId, map in pairs(liveGame and liveGame.data.maps or {}) do
        for index = #(map.objects or {}), 1, -1 do
          local object = map.objects[index]
          if object.runtime
              and mapId .. "_obj_" .. tostring(object.index) == id then
            table.remove(map.objects, index)
            return true
          end
        end
      end
      return nil, "missing"
    end,
  }
  local i18n = {
    text = function(english, german)
      return language == "de" and german or english
    end,
  }
  return mod, i18n, {
    items = items,
    maps = maps,
    scripts = scripts,
    events = events,
    warps = warps,
    saveStats = saveStats,
    language = function(value) language = value end,
    setMap = function(mapId)
      current = { mapId = mapId }
      liveMap.id = mapId
    end,
    current = function() return current end,
    bindGame = function(game) liveGame = game end,
    block = function(x, y) blocked[x .. ":" .. y] = true end,
    choose = function(value) nextChoice = value end,
    takeChoice = function()
      local value = nextChoice
      nextChoice = true
      return value
    end,
  }
end

local StateModule = loadModule("johto_signals_state.lua")
local ContentModule = loadModule("johto_signals_content.lua")

-- ---------------------------------------------------- missing base catalog

local gatedMod, gatedI18n, gatedFixture = fakeMod({})
gatedMod.content.tilesets = {
  get = function(_, id)
    equal(id, "OVERWORLD", "the content gate queries the canonical tileset")
    return nil
  end,
}
local gatedState = StateModule.create(gatedMod)
local gatedContent = ContentModule.create(gatedMod, {
  state = gatedState,
  i18n = gatedI18n,
  canTravel = function() return true end,
})
truthy(gatedContent.register(),
  "non-map Signals content still registers without OVERWORLD")
equal(gatedContent.mapSupported, false,
  "a catalog-aware base without OVERWORLD fails closed")
equal(gatedContent.mapRecord.tileset, "OVERWORLD",
  "the authored record remains available for inspection")
equal(#gatedFixture.items.order, 2,
  "the portable key items do not depend on a map tileset")
equal(#gatedFixture.maps.order, 0,
  "no unresolved Driftglass map operation reaches the loader")
equal(#gatedFixture.scripts.order, 0,
  "neither Driftglass nor Pallet receives a dangling map script")
equal(gatedFixture.events.rows["map.entered"], nil,
  "the unavailable map registers no boat refresh event")

local gatedGame = {
  save = { player = { map = "PALLET_TOWN" } },
  data = {
    maps = {
      PALLET_TOWN = {
        id = "PALLET_TOWN",
        objects = {
          {
            index = 1, runtime = true, owner = "trainer_rematch",
            name = "DRIFTGLASS_PALLET_BOAT",
          },
        },
      },
    },
  },
}
gatedFixture.bindGame(gatedGame)
gatedContent.install(gatedGame)
equal(#gatedGame.data.maps.PALLET_TOWN.objects, 0,
  "install removes a stale departure boat when Driftglass is unsupported")
local gatedTravel, gatedReason = gatedContent.travelToOutpost(gatedGame)
equal(gatedTravel, false, "unsupported Driftglass can never be targeted")
equal(gatedReason, "OVERWORLD tileset unavailable",
  "the catalog gate reports a precise travel failure")

local catalogMod, catalogI18n, catalogFixture = fakeMod({})
catalogMod.content.tilesets = {
  get = function(_, id)
    return id == "OVERWORLD" and { id = id } or nil
  end,
}
local catalogContent = ContentModule.create(catalogMod, {
  state = StateModule.create(catalogMod),
  i18n = catalogI18n,
})
truthy(catalogContent.register(),
  "a real OVERWORLD catalog enables Driftglass content")
equal(catalogContent.mapSupported, true,
  "the supported catalog takes the production branch")
equal(#catalogFixture.maps.order, 1,
  "the supported catalog receives the authored Driftglass map")
equal(#catalogFixture.scripts.order, 2,
  "the supported catalog receives Driftglass and Pallet scripts")
truthy(catalogFixture.events.rows["map.entered"],
  "the supported catalog enables the departure-boat lifecycle")
truthy(catalogFixture.events.rows["player.step"],
  "the supported catalog enables the active-map boatman retry")
truthy(catalogFixture.events.rows["save.writing"],
  "the supported catalog installs its native-map save safety hook")

-- --------------------------------------------------------------- save state

local bucket = {
  johto_signals = {
    version = 0,
    early_johto = {
      mode = "waves",
      outpostVisits = 2,
      capsulePromptOpen = true,
    },
    resonance = {
      echoes = 2,
      pendingSpecies = "MEW",
    },
    obsoleteCampaign = { phase = 99 },
  },
}
local mod, i18n, fixture = fakeMod(bucket)
local state = StateModule.create(mod)
local rootState = state.root()
equal(rootState.version, 1, "old state migrates to schema version 1")
equal(rootState.earlyJohto.mode, "waves",
  "the legacy early section migrates")
equal(rootState.earlyJohto.outpostVisits, 2,
  "durable outpost progress migrates")
equal(rootState.earlyJohto.capsulePromptOpen, nil,
  "dialog prompt state is never persisted")
equal(rootState.resonance.pendingSpecies, nil,
  "a pending encounter is runtime-only")
equal(rootState.obsoleteCampaign, nil,
  "only the two public progression sections survive")
local normalizedSetCalls = fixture.saveStats.set
state.root()
state.section("earlyJohto")
state.status()
equal(fixture.saveStats.set, normalizedSetCalls,
  "read-only state access does not rewrite a normalized save")

local early = state.section("earlyJohto")
early.receiverRepaired = true
state.persist()

local restartedMod, _, restartedFixture = fakeMod(bucket)
local restarted = StateModule.create(restartedMod)
equal(restarted.section("earlyJohto").receiverRepaired, true,
  "progress survives a fresh module instance")
equal(restarted.section("resonance").echoes, 2,
  "resonance progress survives a fresh module instance")
truthy(restarted.status().present, "restart reports a present save root")
equal(restartedFixture.saveStats.set, 0,
  "a clean restart can read state without a redundant write")

local topKeys = {}
for key in pairs(bucket.johto_signals) do topKeys[#topKeys + 1] = key end
table.sort(topKeys)
equal(table.concat(topKeys, ","), "earlyJohto,resonance,version",
  "the save root has one version and exactly two sections")

-- ------------------------------------------------------------ static content

local shown = {}
local researcherCalls = 0
local travelUnlocked = false
local capsuleVisible = false
local capsuleCalls = 0
local content = ContentModule.create(mod, {
  state = state,
  i18n = i18n,
  showText = function(_, text, onDone, options)
    shown[#shown + 1] = text
    if options and options.choice then
      options.choice(fixture.takeChoice())
    elseif onDone then
      onDone()
    end
    return true
  end,
  onResearcher = function(_, _, _, onDone)
    researcherCalls = researcherCalls + 1
    if onDone then onDone() end
    return true
  end,
  canTravel = function() return travelUnlocked end,
  canShowBoatman = function() return travelUnlocked end,
  canShowCapsule = function() return capsuleVisible end,
  onCapsule = function(game, _, _, onDone, instance)
    capsuleCalls = capsuleCalls + 1
    capsuleVisible = false
    instance.refreshCapsule(game, "PALLET_TOWN")
    if onDone then onDone() end
    return true
  end,
})

truthy(content.register(), "content registers once")
equal(content.register(), false, "content registration is idempotent")
equal(#fixture.items.order, 2, "only two key items are registered")
equal(fixture.items.order[1], "MIGRATION_RECEIVER",
  "the Migration Receiver is registered")
equal(fixture.items.order[2], "RESONANCE_SEAL",
  "the Resonance Seal is registered")
equal(#fixture.maps.order, 1, "only one map is registered")
equal(fixture.maps.order[1], "KANTO_ASCENDANT_DRIFTGLASS",
  "the standalone outpost owns its production map id")

local map = fixture.maps:get(content.MAP_ID)
equal(map.index, 1900, "the map index is outside the stock map range")
equal(#map.blocks, map.width * map.height,
  "the map owns a complete rectangular block layer")
equal(#map.warps, 0, "the outpost has no unsafe map warp")
equal(#map.connections, 0, "the outpost cannot leak into another map")
equal(#map.objects, 3,
  "researcher, lookout and return boat are authored")
equal(map.objects[3].name, "DRIFTGLASS_RETURN_BOAT",
  "the permanent third NPC is the return boat")
equal(#map.signs, 1, "the outpost has an authored station sign")

local talk = fixture.scripts:get(content.MAP_ID).talk
truthy(talk[content.TEXT.RESEARCHER], "the researcher has a handler")
truthy(talk[content.TEXT.LOOKOUT], "the lookout has a handler")
truthy(talk[content.TEXT.RETURN_BOAT], "the return boat has a handler")
truthy(talk[content.TEXT.SIGN], "the station sign has a handler")
local palletTalk = fixture.scripts:get("PALLET_TOWN").talk
truthy(palletTalk[content.TEXT.PALLET_BOAT],
  "Pallet Town owns the physical departure handler")
truthy(palletTalk[content.TEXT.PALLET_CAPSULE],
  "Pallet Town owns the physical dark-capsule handler")

-- --------------------------------------------------------------- round trip

local game = {
  save = { player = { map = "PALLET_TOWN" } },
  data = {
    maps = {
      PALLET_TOWN = { id = "PALLET_TOWN", objects = {} },
      [content.MAP_ID] = map,
    },
  },
}
fixture.bindGame(game)
content.install(game)
equal(#game.data.maps.PALLET_TOWN.objects, 0,
  "Pallet actors stay absent before their quest gates")
local locked, lockedReason = content.travelToOutpost(game)
equal(locked, false, "the helper cannot bypass quest permission")
equal(lockedReason, "travel not unlocked",
  "locked travel reports its actual reason")

capsuleVisible = true
truthy(content.refreshCapsule(game, "PALLET_TOWN"),
  "Oak's call spawns the physical dark capsule")
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "exactly one physical capsule is spawned")
local palletCapsule = game.data.maps.PALLET_TOWN.objects[1]
equal(palletCapsule.name, content.PALLET_CAPSULE.name,
  "the shore object uses the dedicated capsule identity")
equal(palletCapsule.sprite, "SPRITE_POKE_BALL",
  "the shore object is visibly represented by an item-ball sprite")
equal(palletCapsule.x, 14, "the capsule prefers the southern coast")
equal(palletCapsule.y, 14, "the capsule prefers the southern coast")
content.refreshCapsule(game, "PALLET_TOWN")
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "refreshing cannot duplicate the capsule")
palletTalk[content.TEXT.PALLET_CAPSULE](
  game, nil, { frozen = false }, function() end)
equal(capsuleCalls, 1,
  "interacting with the shore object reaches the authored capsule flow")
equal(#game.data.maps.PALLET_TOWN.objects, 0,
  "taking the capsule removes the physical object immediately")

travelUnlocked = true
truthy(content.refreshTravelNpc(game, "PALLET_TOWN"),
  "permission spawns the Pallet boatman")
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "exactly one Pallet boatman is spawned")
content.refreshTravelNpc(game, "PALLET_TOWN")
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "refreshing cannot duplicate the boatman")
local palletBoat = game.data.maps.PALLET_TOWN.objects[1]
equal(palletBoat.name, content.PALLET_BOAT.name,
  "the runtime NPC is the Driftglass boatman")
equal(palletBoat.x, 8, "the boatman prefers the safe Pallet coast")
equal(palletBoat.y, 14, "the boatman prefers the safe Pallet coast")

truthy(mod.world:removeNpc("PALLET_TOWN_obj_" .. palletBoat.index),
  "the live retry test can remove the first boatman")
equal(#game.data.maps.PALLET_TOWN.objects, 0,
  "the simulated failed live boatman is absent")
for _, row in ipairs(fixture.events.rows["player.step"] or {}) do
  row.fn({ game = game, mapId = "PALLET_TOWN" })
end
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "the next Pallet step recreates a missing accepted boatman")
palletBoat = game.data.maps.PALLET_TOWN.objects[1]

fixture.choose(false)
local departureNpc = { frozen = false }
local beforeDecline = #fixture.warps
palletTalk[content.TEXT.PALLET_BOAT](
  game, nil, departureNpc, function() end)
equal(#fixture.warps, beforeDecline,
  "declining the explicit sailing prompt stays in Pallet")
equal(fixture.current().mapId, "PALLET_TOWN",
  "declining never changes the active map")
equal(departureNpc.frozen, false,
  "the departure NPC is released after a decline")

palletTalk[content.TEXT.PALLET_BOAT](
  game, nil, departureNpc, function() end)
equal(fixture.warps[#fixture.warps].mapId, content.MAP_ID,
  "accepting the physical NPC targets only Driftglass")
equal(state.section("earlyJohto").outpostVisits, 3,
  "the accepted crossing is persisted")

local warpCount = #fixture.warps
local repeated, repeatedWhy = content.travelToOutpost(game)
equal(repeated, false, "travel never warps to the active map")
equal(repeatedWhy, "already at outpost",
  "a same-map travel attempt is explicit")
equal(#fixture.warps, warpCount, "same-map travel emits no warp")

local returned, returnWhy = content.returnToPallet(game)
truthy(returned, "the return boat reaches Pallet: " .. tostring(returnWhy))
equal(fixture.warps[#fixture.warps].mapId, "PALLET_TOWN",
  "the return route always targets Pallet")
equal(fixture.warps[#fixture.warps].x, 10,
  "the return lands on the known safe Pallet cell")
equal(state.section("earlyJohto").outpostReturns, 1,
  "a return crossing is persisted")

local returnedAgain, alreadyHome = content.returnToPallet(game)
equal(returnedAgain, false, "return never self-warps in Pallet")
equal(alreadyHome, "already in Pallet Town",
  "the home-map guard is explicit")

travelUnlocked = false
content.refreshTravelNpc(game, "PALLET_TOWN")
equal(#game.data.maps.PALLET_TOWN.objects, 0,
  "revoked permission removes the runtime departure NPC")
travelUnlocked = true
local enteredHandlers = fixture.events.rows["map.entered"]
truthy(enteredHandlers and enteredHandlers[1],
  "map entry refresh is registered")
enteredHandlers[1].fn({ game = game, mapId = "PALLET_TOWN" })
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "entering Pallet restores one eligible boatman")
enteredHandlers[1].fn({ game = game, mapId = "PALLET_TOWN" })
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "repeated map entry still cannot duplicate the boatman")

travelUnlocked = false
local loadedHandlers = fixture.events.rows["save.loaded"] or {}
for _, handler in ipairs(loadedHandlers) do
  handler.fn({ game = game })
end
equal(#game.data.maps.PALLET_TOWN.objects, 0,
  "save refresh removes the boatman when permission is missing")
for _, cell in ipairs(content.PALLET_BOAT.preferred) do
  fixture.block(cell[1], cell[2])
end
travelUnlocked = true
truthy(content.refreshTravelNpc(game, "PALLET_TOWN"),
  "a blocked coast still finds a safe fallback cell")
equal(#game.data.maps.PALLET_TOWN.objects, 1,
  "fallback spawning still creates exactly one boatman")
local fallbackBoat = game.data.maps.PALLET_TOWN.objects[1]
equal(fallbackBoat.x == 8 and fallbackBoat.y == 14, false,
  "fallback spawning does not reuse a blocked preferred cell")

-- The permanent NPC invokes the same guarded helper. This remains available
-- without inventory, flags or an external progression callback.
fixture.setMap(content.MAP_ID)
local boatNpc = { frozen = false }
talk[content.TEXT.RETURN_BOAT](game, nil, boatNpc, function() end)
equal(fixture.current().mapId, "PALLET_TOWN",
  "the authored boat NPC always provides a way home")
equal(boatNpc.frozen, false, "the boat NPC is released after interaction")

fixture.setMap(content.MAP_ID)
talk[content.TEXT.RESEARCHER](
  game, {}, { frozen = false }, function() end)
equal(researcherCalls, 1,
  "researcher progression is delegated through the public callback")

-- Saving never serializes a dependency on the custom map. The live world
-- remains on Driftglass, while only the captured save snapshot resumes at
-- the native Pallet landing.
local saveSnapshot = {
  player = {
    map = content.MAP_ID,
    x = content.ARRIVAL.x,
    y = content.ARRIVAL.y,
    facing = "down",
    surfing = true,
  },
  lastOutdoor = {
    id = content.MAP_ID,
    x = content.ARRIVAL.x,
    y = content.ARRIVAL.y,
  },
}
local writingHandlers = fixture.events.rows["save.writing"] or {}
equal(#writingHandlers, 1,
  "Driftglass owns exactly one final save-location normalizer")
writingHandlers[1].fn({ save = saveSnapshot })
equal(saveSnapshot.player.map, "PALLET_TOWN",
  "a Driftglass save serializes a native Pallet map")
equal(saveSnapshot.player.x, content.PALLET_RETURN.x,
  "the safe save resumes at the authored Pallet landing")
equal(saveSnapshot.player.y, content.PALLET_RETURN.y,
  "the safe save resumes at the authored Pallet landing")
equal(saveSnapshot.player.facing, content.PALLET_RETURN.facing,
  "the safe save preserves the intended landing direction")
equal(saveSnapshot.player.surfing, false,
  "the safe save never resumes surfing on land")
equal(saveSnapshot.lastOutdoor.id, "PALLET_TOWN",
  "the safe save carries no custom last-outdoor dependency")
equal(fixture.current().mapId, content.MAP_ID,
  "normalizing the snapshot never interrupts the live island visit")
equal(content.secureSaveLocation(saveSnapshot), false,
  "normalizing an already-native snapshot is idempotent")
equal(content.status().safeSaveRedirects, 1,
  "the runtime status records one actual safe-save redirect")

-- ------------------------------------------------------------- localization

fixture.language("en")
truthy(content.dialogue().travel:find("Sail to\nDRIFTGLASS?", 1, true),
  "English outbound confirmation is explicit")
truthy(content.dialogue().travel:find("resume at\nPALLET pier", 1, true),
  "English travel dialogue discloses the safe resume point")
truthy(content.dialogue().returnTrip:find("Return now?", 1, true),
  "English return confirmation is explicit")
fixture.language("de")
truthy(content.dialogue().travel:find("Nach DRIFTGLAS?", 1, true),
  "German outbound confirmation is explicit")
truthy(content.dialogue().travel:find("ALABASTIA-Steg", 1, true),
  "German travel dialogue discloses the safe resume point")
truthy(content.dialogue().returnTrip:find("Jetzt zurück?", 1, true),
  "German return confirmation is explicit")

-- Production content must not register encounter data. The focused fake has
-- no encounter registry; registration would already have failed. Also check
-- that the two implementation units do not carry identifiers from postponed
-- systems.
for _, filename in ipairs({
  "johto_signals_state.lua",
  "johto_signals_content.lua",
}) do
  local file = assert(io.open(root .. "/" .. filename, "rb"))
  local body = file:read("*a")
  file:close()
  for _, forbidden in ipairs({
    "STAR" .. "FALL",
    "OR" .. "ANGE",
    "FA" .. "IRY",
    "JIR" .. "ACHI",
    "DE" .. "BUG",
  }) do
    equal(body:upper():find(forbidden, 1, true), nil,
      filename .. " excludes postponed-system identifiers")
  end
end

print("JOHTO SIGNALS STATE/CONTENT PASS")
