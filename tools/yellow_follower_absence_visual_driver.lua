-- Real-LÖVE visual acceptance for Yellow's partner-independent extras.
--
-- The driver is restricted to a disposable QA identity and never writes a
-- save. It uses the installed Ascendant follower controller, actual Pokemon
-- objects, production follower sheets and the native Pallet Town renderer.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")

  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("yellow%-follower%-absence", 1, false),
    "refusing to run outside yellow-follower-absence QA identity")
  assert(GameVersion.get() == "yellow", "Yellow ROM cache required")

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local native = assert(exports.singleFollower, "native follower unavailable")
  local config = assert(exports.followerConfig, "follower config unavailable")
  local yellowPartner = assert(exports.yellowPartner, "Yellow partner unavailable")
  assert(native.active and not native.external,
    "Ascendant native follower controller did not install")

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike = false
  game.save.repelSteps = 9999
  game.save.player.name = "FOLLOWER QA"

  local pikachu = Pokemon.new(game.data, "PIKACHU", 30)
  local bulbasaur = Pokemon.new(game.data, "BULBASAUR", 30)
  local charmander = Pokemon.new(game.data, "CHARMANDER", 30)
  local squirtle = Pokemon.new(game.data, "SQUIRTLE", 30)
  local eevee = Pokemon.new(game.data, "EEVEE", 30)
  local lapras = Pokemon.new(game.data, "LAPRAS", 30)
  pikachu[yellowPartner.marker] = true
  local extras = { bulbasaur, charmander, squirtle, eevee, lapras }
  game.save.party = { pikachu, unpack(extras) }
  game.save.boxes = {}

  config.setMode("party")
  config.setCount(6)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(16)

  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local function assertChain(label, expected)
    local chain = native.entities(game)
    assert(#chain == #expected,
      ("%s: expected %d followers, got %d"):format(
        label, #expected, #chain))
    local seen = {}
    for index, species in ipairs(expected) do
      local npc = assert(chain[index], label .. ": missing chain row")
      assert(npc.followerSpecies == species,
        ("%s #%d expected %s, got %s"):format(
          label, index, species, tostring(npc.followerSpecies)))
      assert(not seen[npc.followerMon], label .. ": duplicated Pokemon")
      seen[npc.followerMon] = true
      assert(npc.sprite and npc.sprite.def and npc.sprite.def.frames == 6
          and npc.sprite.def.walker and npc.sprite.def.trueColor,
        label .. ": non-production follower renderer")
    end
    return chain
  end

  local full = {
    "PIKACHU", "BULBASAUR", "CHARMANDER", "SQUIRTLE", "EEVEE", "LAPRAS",
  }
  local withoutPartner = {
    "BULBASAUR", "CHARMANDER", "SQUIRTLE", "EEVEE", "LAPRAS",
  }

  -- Bend the real follower trail into a compact, contiguous U solely for
  -- capture.  A straight six-member trail extends above the 1024x768 frame
  -- when the camera centers on the player.  Every cell below is walkable and
  -- adjacent to its predecessor, so this is a reachable production formation
  -- rather than a composited/mock arrangement.
  local qaTrail = {
    { 10, 7, "left" }, { 9, 7, "left" }, { 8, 7, "down" },
    { 8, 8, "down" }, { 8, 9, "right" }, { 9, 9, "right" },
  }
  local function arrangeForCapture(label, chain)
    for index, npc in ipairs(chain) do
      local point = assert(qaTrail[index], label .. ": missing QA trail cell")
      assert(game.overworld.map:inBounds(point[1], point[2])
          and game.overworld.map:isWalkableCell(point[1], point[2]),
        ("%s #%d QA trail cell is not walkable"):format(label, index))
      npc.cellX, npc.cellY = point[1], point[2]
      npc.px, npc.py = point[1] * 16, point[2] * 16
      npc.targetX, npc.targetY, npc.goalX, npc.goalY = nil, nil, nil, nil
      npc.moving, npc.marching, npc.hopStep = false, nil, nil
      npc.progress, npc.facing = 0, point[3]
    end
    U.wait(3)
  end

  local healthy = assertChain("healthy partner", full)
  arrangeForCapture("healthy partner", healthy)
  assert(U.shot(game, shotDir .. "/01-healthy-partner.png"),
    "healthy-partner screenshot failed")

  pikachu.hp = 0
  native.refresh(game)
  U.wait(12)
  local fainted = assertChain("fainted partner", withoutPartner)
  assert(fainted[1].followerMon == bulbasaur
      and fainted[1].followerSelectionSource == "yellow_party",
    "fainted partner did not hand native transport to logical follower #2")
  arrangeForCapture("fainted partner", fainted)
  assert(U.shot(game, shotDir .. "/02-fainted-partner.png"),
    "fainted-partner screenshot failed")

  pikachu.hp = pikachu.maxHp or 30
  table.remove(game.save.party, 1)
  game.save.boxes = { { pikachu } }
  native.refresh(game)
  U.wait(12)
  local boxed = assertChain("boxed partner", withoutPartner)
  arrangeForCapture("boxed partner", boxed)
  assert(U.shot(game, shotDir .. "/03-boxed-partner.png"),
    "boxed-partner screenshot failed")

  game.save.boxes = {}
  game.save.party[#game.save.party + 1] = pikachu
  native.refresh(game)
  U.wait(12)
  local restored = assertChain("restored partner", full)
  local partnerCount = 0
  for _, npc in ipairs(restored) do
    if npc.followerMon == pikachu then partnerCount = partnerCount + 1 end
  end
  assert(restored[1].followerMon == pikachu and partnerCount == 1,
    "restored partner was not prepended exactly once")
  arrangeForCapture("restored partner", restored)
  assert(U.shot(game, shotDir .. "/04-restored-partner.png"),
    "restored-partner screenshot failed")

  local out = assert(io.open(shotDir .. "/driver_result.txt", "wb"))
  out:write("PASS real Yellow follower renderer\n")
  out:write("healthy=PIKACHU+BULBASAUR+CHARMANDER+SQUIRTLE+EEVEE+LAPRAS\n")
  out:write("fainted=BULBASAUR+CHARMANDER+SQUIRTLE+EEVEE+LAPRAS\n")
  out:write("boxed=BULBASAUR+CHARMANDER+SQUIRTLE+EEVEE+LAPRAS\n")
  out:write("restored=PIKACHU+BULBASAUR+CHARMANDER+SQUIRTLE+EEVEE+LAPRAS\n")
  out:close()
  U.log("YELLOW FOLLOWER ABSENCE VISUAL PASS",
    "healthy fainted boxed restored; no save write")
  love.event.quit(0)
end
