-- Connected Johto Masters authority: migrate a BLITZ-era direct-gauntlet
-- save, keep the first arena run available until cleared, then consume one
-- Elite-Four Hall receipt for each additional shiny-farm run.

local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR must point at the read-only test runtime")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local make = assert(loadfile("johto_masters.lua"))()
local data = assert(loadfile("johto_masters_data.lua"))()
local makeShiny = assert(loadfile("shiny_system.lua"))()
local Stats = require("src.pokemon.Stats")
local SaveSerializer = require("src.core.SaveSerializer")

local bucket = {
  johto_masters = {
    version = 2, clears = 4, gifts = 4, title = true,
    passages = {
      silver = { status = "locked" },
      kris = { status = "locked" },
      gold = { status = "locked" },
    },
  },
  legacy_journey = { runId = "BLITZ:ORIGINAL" },
}
local archiveSnapshots = {}
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return bucket[key] end,
    set = function(_, key, value) bucket[key] = value end,
  },
  events = { on = function() end },
}
local postgame = {
  hasHallOfFame = function(save)
    return type(save.hallOfFame) == "table" and #save.hallOfFame > 0
  end,
}
local shinyMod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return bucket[key] end,
    set = function(_, key, value) bucket[key] = value end,
  },
  options = { get = function() return nil end },
  hooks = { wrap = function() end },
  events = { on = function() end },
}
local shinySystem = makeShiny(shinyMod, {})
local forced, caught = 0, 0
local realForceMon, realMarkCaught = shinySystem.forceMon, shinySystem.markCaught
shinySystem.forceMon = function(...)
  forced = forced + 1
  return realForceMon(...)
end
shinySystem.markCaught = function(mon)
  assert(mon.shiny == nil and Stats.isShiny(mon.dvs),
    "Gold's reward must use canonical Gen-II shiny DVs")
  caught = caught + 1
  return realMarkCaught(mon)
end
local game = {
  data = { pokemon = {
    CELEBI = { dex = 251, name = "CELEBI" },
  } },
  save = {
    version = "yellow", player = { id = 77, name = "BLITZ" },
    hallOfFame = { {}, {}, {}, {} }, party = {}, boxes = { {} },
    modData = { kanto_ascendant = bucket },
  },
}

package.preload["src.pokemon.Pokemon"] = function()
  return {
    new = function(_, species, level)
      return { species = species, level = level, moves = {} }
    end,
  }
end
package.preload["src.pokemon.Party"] = function()
  return {
    add = function(party, mon)
      if #party >= 6 then return false end
      party[#party + 1] = mon
      return true
    end,
  }
end
package.preload["src.pokemon.Boxes"] = function()
  return {
    deposit = function(save, mon)
      save.boxes[1] = save.boxes[1] or {}
      if #save.boxes[1] >= 20 then return nil end
      save.boxes[1][#save.boxes[1] + 1] = mon
      return 1
    end,
  }
end
package.preload["src.battle.BattleState"] = function()
  return { stampOT = function(save, mon) mon.otId = save.player.id end }
end

local masters = make(mod, {
  data = data, postgame = postgame, shinySystem = shinySystem,
  journey = {
    syncJohtoMastersPersistent = function(save)
      assert(save == game.save)
      local snapshot = {}
      for key, value in pairs(bucket.johto_masters) do snapshot[key] = value end
      archiveSnapshots[#archiveSnapshots + 1] = snapshot
      return true
    end,
  },
})

local function eq(actual, expected, message)
  assert(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function appendHall(count)
  for _ = 1, count or 1 do game.save.hallOfFame[#game.save.hallOfFame + 1] = {} end
end

local expectedStarter = {
  silver = "FERALIGATR", kris = "MEGANIUM", gold = "TYPHLOSION",
}
local starterFamily = {
  CHIKORITA=true,BAYLEEF=true,MEGANIUM=true,
  CYNDAQUIL=true,QUILAVA=true,TYPHLOSION=true,
  TOTODILE=true,CROCONAW=true,FERALIGATR=true,
}
local globalPoolSeen,trainerByKey={},{}
for _,trainer in ipairs(data.trainers) do
  trainerByKey[trainer.key]=trainer
  local ownStarter=0
  for _,slot in ipairs(trainer.pool) do
    local previous=globalPoolSeen[slot.species]
    assert(not previous,
      "Johto Master pools repeat species "..slot.species.." between "
        ..tostring(previous).." and "..trainer.key)
    globalPoolSeen[slot.species]=trainer.key
    if starterFamily[slot.species] then
      assert(slot.species==expectedStarter[trainer.key],
        trainer.key.." borrows another Master's starter line: "..slot.species)
      ownStarter=ownStarter+1
    end
  end
  eq(ownStarter,1,trainer.key.." pool must contain only its exclusive starter")
end
eq(#trainerByKey.silver.pool+#trainerByKey.kris.pool+#trainerByKey.gold.pool,36,
  "three twelve-species Johto pools")
assert(globalPoolSeen.ENTEI=="silver" and globalPoolSeen.TYPHLOSION=="gold",
  "Silver's duplicate Typhlosion slot was not replaced by unique Entei")
local connectedTeamSeen={}
for _,key in ipairs({"silver","kris","gold"}) do
  for _,slot in ipairs(masters.teamFor(key,1)) do
    assert(not connectedTeamSeen[slot.species],
      "attempt-one connected teams repeat species "..slot.species)
    connectedTeamSeen[slot.species]=key
  end
end
for key, species in pairs(expectedStarter) do
  for attempt = 1, 12 do
    local team, found = masters.teamFor(key, attempt), 0
    assert(#team == 6, key .. " roster must contain six unique members")
    local seen = {}
    for _, slot in ipairs(team) do
      assert(not seen[slot.species], key .. " roster repeated " .. slot.species)
      seen[slot.species] = true
      if slot.species == species then found = found + 1 end
    end
    eq(found, 1, key .. " must always bring exactly one signature starter")
  end
  eq(masters.megaTargetFor(key), species,
    key .. " transformation target must be its signature starter")
end
eq(masters.secretFormFor("gold"), "TYPHLOSION_ASCENDANT",
  "Gold must be allowed to awaken Ascendant Typhlosion")
eq(masters.secretFormFor("silver"), nil,
  "Silver must use the official Feraligatr Mega path")

-- Old direct wins are lifetime history only. They cannot suppress the new
-- connected host or pre-mark Gold as rewarded.
local state = masters.syncCadence(game)
eq(state.clears, 4, "BLITZ lifetime clears survive migration")
eq(state.gifts, 4, "BLITZ lifetime gifts survive migration")
eq(state.connectedClears, 0, "direct-gauntlet clears are not connected clears")
eq(state.journeyClears, 0, "BLITZ still owns its first connected run")
assert(masters.hostAvailable(game), "BLITZ Hall save lost the Johto host")
local ready, reason = masters.beginRun(game)
assert(ready and reason == "new", "BLITZ first connected run did not start")
state = masters.state()
assert(state.activeRun and state.passages.silver.status == "unlocked"
    and state.passages.kris.status == "locked"
    and state.passages.gold.status == "locked",
  "new run did not reset to the Silver-only Gate Hall")

local beforeParty = #game.save.party
local message, delivered = masters.completeRun(game)
assert(delivered and message:find("shiny", 1, true),
  "first connected Gold clear did not deliver its shiny")
assert(message:find("ELITE FOUR", 1, true)
    and message:find("CHAMPION", 1, true),
  "Gold did not explain the Hall-of-Fame requirement for another run")
state = masters.state()
eq(state.connectedClears, 1, "first connected clear counted once")
eq(state.journeyClears, 1, "first connected journey clear counted once")
eq(state.lastHallTicket, 4, "first connected run consumed current Hall receipt")
eq(#game.save.party, beforeParty + 1, "first run delivered exactly one Pokémon")
eq(state.gifts, 5, "first run incremented lifetime gifts exactly once")
assert(not masters.hostAvailable(game),
  "host remained available without a fresh Elite-Four clear")

-- The real reward is DV-shiny, not a transient Lua-only `shiny` marker.  Use
-- the native deterministic save grammar, then prove the loaded Pokémon still
-- drives Ascendant's visible Summary marker and that the consumed Hall ticket
-- remains consumed across the same reload.
local awarded = game.save.party[#game.save.party]
assert(awarded.shiny == nil and Stats.isShiny(awarded.dvs)
    and shinySystem.isShiny(awarded),
  "Gold's delivered Pokémon is not a canonical visible shiny")
assert(awarded.johtoMasterGift and awarded.johtoMasterGift.trainer == "GOLD",
  "Gold provenance was not attached to the shiny reward")
local encoded = SaveSerializer.encode(game.save)
game.save = assert(SaveSerializer.decode(encoded))
bucket = assert(game.save.modData.kanto_ascendant)
local reloadedGift = game.save.party[#game.save.party]
assert(reloadedGift.shiny == nil and Stats.isShiny(reloadedGift.dvs)
    and shinySystem.isShiny(reloadedGift),
  "native save/reload lost Gold's DV-shiny identity")
assert(not masters.hostAvailable(game),
  "native save/reload resurrected a consumed Johto cycle")

local priorLove = love
local baseSummaryDraws, shinyMarkerPixels = 0, 0
package.loaded["src.ui.SummaryMenu"] = nil
package.preload["src.ui.SummaryMenu"] = function()
  return { draw = function() baseSummaryDraws = baseSummaryDraws + 1 end }
end
package.loaded["src.ui.BoxMenu"] = nil
package.preload["src.ui.BoxMenu"] = function()
  return { new = function() return { items = {} } end }
end
love = { graphics = {
  setColor = function() end,
  rectangle = function(mode)
    if mode == "fill" then shinyMarkerPixels = shinyMarkerPixels + 1 end
  end,
} }
shinySystem.install(game)
require("src.ui.SummaryMenu").draw({ mon = reloadedGift })
love = priorLove
assert(baseSummaryDraws == 1 and shinyMarkerPixels > 0,
  "reloaded Gold gift did not draw Ascendant's visible shiny marker")

local duplicateMessage, duplicateDelivered = masters.completeRun(game)
assert(not duplicateDelivered and duplicateMessage:find("already recorded", 1, true),
  "duplicate Gold completion was not rejected")
eq(#game.save.party, beforeParty + 1, "duplicate callback created another shiny")
eq(masters.state().gifts, 5, "duplicate callback incremented gifts")

appendHall(1)
assert(masters.hostAvailable(game),
  "one Elite-Four re-clear did not restore the Johto host")
ready, reason = masters.beginRun(game)
assert(ready and reason == "new", "re-clear did not start a farm run")
eq(masters.state().runTicket, 5, "farm run did not consume the next Hall receipt")
masters.completeRun(game)
eq(masters.state().gifts, 6, "second connected run did not award one shiny")
assert(not masters.hostAvailable(game),
  "one Hall receipt unlocked more than one completed farm run")

-- Two accumulated League re-clears are two independent tickets.  Consuming
-- the first must leave the host available for the second.
appendHall(2)
assert(masters.beginRun(game))
eq(masters.state().runTicket, 6, "oldest queued Hall receipt was not consumed first")
masters.completeRun(game)
assert(masters.hostAvailable(game),
  "second queued Hall receipt disappeared after one farm run")

-- A real NG+ owner receives a fresh local cadence only after that journey's
-- own Hall of Fame, while lifetime title/clear/gift totals remain durable.
bucket.legacy_journey.runId = "BLITZ:NGPLUS:1"
game.save.player.id = 88
game.save.hallOfFame = { {} }
state = masters.syncCadence(game)
eq(state.journeyClears, 0, "NG+ inherited the prior journey ticket clock")
assert(not state.activeRun and state.passages.silver.status == "unlocked"
    and state.passages.kris.status == "locked",
  "NG+ did not reset the connected Gate Hall")
assert(masters.hostAvailable(game), "NG+ Hall clear did not unlock its first run")

-- Full storage retains, rather than loses, that run's exact pending shiny;
-- the host is present solely for recovery and another run cannot start.
for index = 1, 6 do game.save.party[index] = { species = "CELEBI" } end
for index = 1, 20 do game.save.boxes[1][index] = { species = "CELEBI" } end
assert(masters.beginRun(game))
local _, stored = masters.completeRun(game)
assert(not stored and masters.state().pendingGift,
  "full storage lost the run's pending shiny")
assert(masters.hostAvailable(game), "pending shiny did not keep the host available")
local canBegin, blocked = masters.beginRun(game)
assert(not canBegin and blocked == "gift",
  "pending shiny allowed a second connected run")
game.save.party[6] = nil
local _, recovered = masters.deliverGift(game, masters.state())
assert(recovered and not masters.state().pendingGift,
  "host recovery did not deliver and clear the pending shiny")
assert(not masters.hostAvailable(game),
  "recovery invented another run without a League receipt")

-- A pre-cadence save may have entered the authored Silver passage but not
-- yet reached Gold.  Migration must reserve a live run serial so completing
-- that route can still award exactly once; 0/0 must never look rewarded.
local partialBucket = {
  johto_masters = {
    version = 2, clears = 0, gifts = 0,
    passages = {
      silver = { status = "entered", clue = true, step = 1 },
      kris = { status = "locked" }, gold = { status = "locked" },
    },
  },
  legacy_journey = { runId = "PARTIAL:ORIGINAL" },
}
local partialMod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return partialBucket[key] end,
    set = function(_, key, value) partialBucket[key] = value end,
  },
  events = { on = function() end },
}
local partialGame = {
  data = game.data,
  save = {
    version = "red", player = { id = 91, name = "PARTIAL" },
    hallOfFame = { {} }, party = {}, boxes = { {} },
    modData = { kanto_ascendant = partialBucket },
  },
}
local partialMasters = make(partialMod, {
  data = data, postgame = postgame, shinySystem = shinySystem,
})
local partialState = partialMasters.syncCadence(partialGame)
assert(partialState.activeRun and partialState.runSerial == 1
    and partialState.rewardedRunSerial == 0,
  "migrated partial passage was not reserved as an unrecorded active run")
local _, partialDelivered = partialMasters.completeRun(partialGame)
assert(partialDelivered and partialMasters.state().connectedClears == 1
    and partialMasters.state().gifts == 1,
  "migrated partial passage could not finish and reward exactly once")

-- The earliest passage prototype encoded a finished Gold seal directly as
-- status="rewarded".  Preserve that as one connected clear rather than
-- degrading it to locked and granting the first connected reward twice.
local rewardedBucket = {
  johto_masters = {
    version = 2, clears = 1, gifts = 1,
    passages = {
      silver = { status = "cleared" }, kris = { status = "cleared" },
      gold = { status = "rewarded" },
    },
  },
  legacy_journey = { runId = "REWARDED:ORIGINAL" },
}
local rewardedMod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return rewardedBucket[key] end,
    set = function(_, key, value) rewardedBucket[key] = value end,
  },
  events = { on = function() end },
}
local rewardedGame = {
  save = {
    version = "blue", player = { id = 92, name = "REWARDED" },
    hallOfFame = { {} },
    modData = { kanto_ascendant = rewardedBucket },
  },
}
local rewardedMasters = make(rewardedMod, {
  data = data, postgame = postgame, shinySystem = shinySystem,
})
local rewardedState = rewardedMasters.syncCadence(rewardedGame)
assert(rewardedState.passages.gold.status == "cleared"
    and rewardedState.passages.gold.rewarded == true
    and rewardedState.connectedClears == 1
    and rewardedState.journeyClears == 1
    and not rewardedMasters.hostAvailable(rewardedGame),
  "legacy rewarded Gold seal was not preserved as one consumed connected run")

eq(forced, caught + 1,
  "only the deliberately full-storage construction awaits a caught receipt")
assert(#archiveSnapshots > 0
    and archiveSnapshots[#archiveSnapshots].cadenceSerial
      >= archiveSnapshots[1].cadenceSerial,
  "cadence persistence did not advance monotonically")
print("johto_masters_connected_cadence_test: PASS")
