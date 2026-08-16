-- Real-LÖVE Phase-1 baseline for the future native follower system.
--
-- Run once with POKEPORT_VERSION=red, blue and yellow under a dedicated
-- POKEPORT_IDENTITY which contains legal ROM caches and only the candidate
-- Kanto Ascendant source/package.  This establishes the smallest reusable
-- E2E seam for later phases: boot, input walking, a real Warp.destination
-- transition outside->inside->outside, party order mutation, evolution, and
-- native save/reload.  It intentionally contains no follower implementation.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Map = require("src.world.Map")
  local Pokemon = require("src.pokemon.Pokemon")
  local Evolution = require("src.pokemon.Evolution")
  local SaveData = require("src.core.SaveData")

  local version = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION must be red, blue or yellow")
  assert(GameVersion.get() == version, "engine booted the wrong version")
  assert(os.getenv("POKEPORT_IDENTITY")
      and os.getenv("POKEPORT_IDENTITY"):find("follower%-phase1"),
    "refusing to write outside a follower-phase1 identity")

  local ascendant
  for _, row in ipairs((game.modStatus and game.modStatus.loaded) or {}) do
    if row.id == "kanto_ascendant" then ascendant = row break end
  end
  assert(ascendant, "Kanto Ascendant is not loaded")
  assert(ascendant.version == "6.0.8",
    "expected Kanto Ascendant 6.0.8, got " .. tostring(ascendant.version))

  -- Use one reserved slot per edition inside the guarded QA identity only.
  local slot = "slot6101"
  assert(SaveData.setActiveSlot(version, slot) == slot,
    "could not reserve Phase-1 save slot")

  -- Real input path: discover a pair of adjacent walkable outdoor cells, then
  -- press the corresponding Game Boy direction until one step commits.
  U.teleport(game, "PALLET_TOWN", 5, 6, "down")
  local map = game.overworld.map
  assert(Map.isOutdoor(map.def), "PALLET_TOWN is not classified outdoors")
  local directions = {
    { "up", 0, -1 }, { "down", 0, 1 },
    { "left", -1, 0 }, { "right", 1, 0 },
  }
  local sx, sy, direction
  -- Stay away from connection edges: Map:isWalkableCell deliberately knows
  -- neighbouring maps, and a valid edge step would test a connection instead
  -- of the ordinary local walking path intended here.
  for y = 2, map.heightCells - 3 do
    for x = 2, map.widthCells - 3 do
      if map:isWalkableCell(x, y) then
        for _, row in ipairs(directions) do
          if map:isWalkableCell(x + row[2], y + row[3]) then
            sx, sy, direction = x, y, row[1]
            break
          end
        end
      end
      if direction then break end
    end
    if direction then break end
  end
  assert(direction, "no adjacent walkable Pallet Town cells found")
  U.teleport(game, "PALLET_TOWN", sx, sy, direction)
  local player = game.overworld.player
  local beforeX, beforeY = player.cellX, player.cellY
  for _ = 1, 48 do
    table.insert(game.input.pressQueue, direction)
    game.input.state[direction] = true
    coroutine.yield()
    if player.cellX ~= beforeX or player.cellY ~= beforeY then break end
  end
  game.input.state[direction] = false
  assert(player.cellX ~= beforeX or player.cellY ~= beforeY,
    "directional input did not commit a walking step")
  assert(game.overworld.map.id == "PALLET_TOWN",
    "walking probe unexpectedly crossed a map connection")

  -- Use Pallet's real warp data rather than teleporting across the boundary.
  local outward = game.overworld
  local entry
  for _, warp in ipairs(outward.map.def.warps or {}) do
    if warp.destMap and warp.destMap ~= "LAST_MAP" then entry = warp break end
  end
  assert(entry, "PALLET_TOWN has no usable interior warp")
  local outsideId = outward.map.id
  outward.player.cellX, outward.player.cellY = entry.x, entry.y
  outward.player.facing = "up"
  outward:takeWarp(entry)
  for _ = 1, 240 do
    if outward.map.id ~= outsideId and not outward.transitioning then break end
    coroutine.yield()
  end
  assert(outward.map.id ~= outsideId, "outside-to-inside warp did not complete")
  assert(not Map.isOutdoor(outward.map.def),
    "Pallet destination was not classified indoors")
  local insideId = outward.map.id
  local exit
  for _, warp in ipairs(outward.map.def.warps or {}) do
    if warp.destMap == "LAST_MAP" or warp.destMap == outsideId then
      exit = warp break
    end
  end
  assert(exit, insideId .. " has no return warp")
  outward.player.cellX, outward.player.cellY = exit.x, exit.y
  outward.player.facing = "down"
  outward:takeWarp(exit)
  for _ = 1, 240 do
    if outward.map.id == outsideId and not outward.transitioning then break end
    coroutine.yield()
  end
  assert(outward.map.id == outsideId,
    "inside-to-outside return warp did not complete")

  -- Party order and in-place evolution are the two identity-sensitive
  -- mutations the later follower selection layer must survive.
  local first = Pokemon.new(game.data, "BULBASAUR", 10)
  local second = Pokemon.new(game.data, "CATERPIE", 7)
  first._phase1Identity = version .. ":first"
  second._phase1Identity = version .. ":second"
  game.save.party = { first, second }
  game.save.party[1], game.save.party[2] =
    game.save.party[2], game.save.party[1]
  assert(game.save.party[1] == second and game.save.party[2] == first,
    "party reorder changed object identity")
  Evolution.apply(game, second, "METAPOD", "PHASE1_E2E")
  assert(second.species == "METAPOD", "evolution did not mutate in place")
  assert(second._phase1Identity == version .. ":second",
    "evolution discarded per-Pokemon identity data")

  game.save._followerPhase1Probe = {
    version = version, map = game.overworld.map.id,
    first = game.save.party[1]._phase1Identity,
    species = game.save.party[1].species,
  }
  assert(game:writeSave(), "native save write failed")
  local loaded = assert(SaveData.load(version), "native save reload failed")
  assert(loaded.version == version, "reloaded save has wrong version")
  assert(loaded._followerPhase1Probe
      and loaded._followerPhase1Probe.first == version .. ":second",
    "Phase-1 probe did not survive reload")
  assert(loaded.party[1].species == "METAPOD"
      and loaded.party[1]._phase1Identity == version .. ":second",
    "party/evolution identity did not survive reload")

  U.log("FOLLOWER PHASE 1 E2E PASS", version,
    "boot walk warp party evolution save/reload")
  love.event.quit(0)
end
