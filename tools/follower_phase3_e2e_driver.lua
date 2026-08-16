-- Guarded real-LÖVE coverage acceptance for Phase 3's data-driven follower
-- registry.  Run with POKEPORT_VERSION=red in the dedicated phase-3 identity;
-- Phase-2's Red/Blue/Yellow driver remains the lifecycle/Yellow-story gate.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")

  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  U.wait(2) -- allow game.ready subscribers to finish their first refresh
  assert(identity:find("follower%-phase3"),
    "refusing to write outside follower-phase3 identity")
  assert(version == "red" and GameVersion.get() == "red",
    "Phase-3 catalogue coverage is pinned to Red's isolated test run")
  assert(SaveData.setActiveSlot(version, "slot6303") == "slot6303")

  local exports = game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant
  if not exports then
    local errors = game.modStatus and game.modStatus.errors or {}
    error("Ascendant exports unavailable; loader errors: "
      .. table.concat(errors, " | "))
  end
  local native = assert(exports.singleFollower, "native follower export unavailable")
  local registry = assert(exports.followerSprites, "sprite registry unavailable")
  assert(native.active and not native.external, "native follower is not active")

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike = false
  game.save.repelSteps = 9999
  game.save.player.name = "PHASE3"

  local coverage = {
    "PIKACHU", "RAICHU", "CHARIZARD", "ONIX", "LAPRAS",
    "CHIKORITA", "CYNDAQUIL", "TOTODILE", "CROBAT", "ESPEON",
    "UMBREON", "SCIZOR", "HERACROSS", "TYRANITAR", "LUGIA", "HO_OH",
    "GOROCHU",
  }

  local function countFollowers(ow)
    local count = 0
    for _, npc in ipairs(ow and ow.npcs or {}) do
      if npc.pikachuFollower then count = count + 1 end
    end
    return count
  end

  local function stepOne()
    local ow, player = game.overworld, game.overworld.player
    local map = ow.map
    local choices = {
      { "up", 0, -1 }, { "down", 0, 1 },
      { "left", -1, 0 }, { "right", 1, 0 },
    }
    for _, choice in ipairs(choices) do
      local direction, dx, dy = choice[1], choice[2], choice[3]
      if map:isWalkableCell(player.cellX + dx, player.cellY + dy)
          and not ow:npcAtCell(player.cellX + dx, player.cellY + dy) then
        local beforeX, beforeY = player.cellX, player.cellY
        for _ = 1, 64 do
          table.insert(game.input.pressQueue, direction)
          game.input.state[direction] = true
          coroutine.yield()
          if player.cellX ~= beforeX or player.cellY ~= beforeY then break end
        end
        game.input.state[direction] = false
        assert(player.cellX ~= beforeX or player.cellY ~= beforeY,
          "could not walk one cell " .. direction)
        U.wait(20)
        return direction
      end
    end
    error("no walkable adjacent cell for follower walk check")
  end

  local shotDir = os.getenv("SHOT_DIR") or "/tmp/follower-phase3"
  for _, species in ipairs(coverage) do
    assert(game.data.pokemon[species], "species missing from live game data: " .. species)
    local mon = Pokemon.new(game.data, species, 30)
    game.save.party = { mon }

    -- Teleport intentionally triggers the real onMapEntered pipeline for
    -- every species: this catches stale transport sheets after map rebuilds.
    U.teleport(game, "PALLET_TOWN", 10, 8, "down")
    U.wait(12)
    local entity = assert(native.entity(game), species .. ": follower missing")
    assert(countFollowers(game.overworld) == 1,
      species .. ": expected exactly one follower after map entry")
    assert(native.activeMon(game) == mon and entity.followerSpecies == species,
      species .. ": wrong active follower identity")
    assert(entity.sprite and entity.sprite.def and entity.sprite.def.frames == 6
        and entity.sprite.def.walker and entity.sprite.def.trueColor,
      species .. ": renderer was not configured as true-colour six-pose walker")
    local width, height = entity.sprite.image:getDimensions()
    assert(width == 16 and height == 96,
      ("%s: runtime image is %dx%d, expected 16x96"):format(species, width, height))
    local path = assert(entity.followerSprite, species .. ": runtime sheet missing")
    assert(path:match("follower_" .. species .. "%.png$")
        or path:match(("follower_%03d%%.png$")
          :format(tonumber(game.data.pokemon[species].dex) or -1)),
      species .. ": selected an unrelated sheet: " .. path)

    local direction = stepOne()
    entity = assert(native.entity(game), species .. ": follower vanished while walking")
    assert(entity.followerAnimation == "stand" or entity.followerAnimation == "walk",
      species .. ": walk state not synchronized")
    assert(entity.followerFacing == entity.facing,
      species .. ": facing state not synchronized after " .. direction)
    assert(native.movement(game) and #native.movement(game).history >= 1,
      species .. ": movement history was not recorded")
    assert(U.shot(game, ("%s/%s-native-follower.png")
      :format(shotDir, species:lower())), species .. ": screenshot failed")
  end

  game.save._followerPhase3Probe = { coverage = coverage, count = #coverage }
  assert(game:writeSave(), "Phase-3 save write failed")
  U.log("FOLLOWER PHASE 3 E2E PASS", "17 species actual map-entry walker coverage")
  love.event.quit(0)
end
