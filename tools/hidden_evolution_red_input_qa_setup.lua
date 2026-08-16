-- One-shot prerequisite slot for the RED product traversal.  It creates a
-- legitimate RED traveler with the two required field moves at the real
-- Route-22 wall-fissure approach; it never enters or mutates a RED puzzle,
-- secret, seal or reward.  Every tunnel/dungeon transition therefore remains
-- part of the companion driver's physical D-pad proof.
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local version = assert(os.getenv("POKEPORT_VERSION"), "POKEPORT_VERSION required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "POKEPORT_IDENTITY required")
  local render=os.getenv("RED_QA_RENDER")=="voxel" and "full" or "2d"
  assert(identity=="ka65-final-hevo-red-fresh-"..render,
    "refusing non-orchestrated RED Fresh QA identity")
  assert(os.getenv("KA_PACKAGE_GATE")=="1",
    "refusing RED Fresh setup outside the immutable package gate")
  assert(GameVersion.get() == version, "game version mismatch")
  assert(game.mods.exports.kanto_ascendant, "Kanto Ascendant must be loaded")

  local save = SaveData.newGame({ version = version, playerName = "RED", rivalName = "BLUE" })
  save.meta = SaveData.buildMeta(assert(game.modStatus and game.modStatus.loaded,
    "active RED QA mod closure missing"))
  save.modData.kanto_ascendant = {
    extended_characters = {
      version = 1, enabled = true, player_character = "RED",
      rival_character = "BLUE", third_character = "GREEN",
    },
  }
  save.options = save.options or {}
  save.options.modOptions = save.options.modOptions or {}
  save.options.modOptions.kanto_ascendant = {
    ascendant_qol = true, qol_easy_interactions = true,
    qol_location_banners = false,
    -- The separate habitat acceptance owns real visible-spawn/contact proof.
    -- Disable pursuit only in this deterministic puzzle traversal so a wild
    -- cannot interrupt the exact sight-mask route mid-screenshot.
    living_world_enabled = false,
    enable_aggressive = false,
    living_world_random_encounters = false,
  }
  local mon = Pokemon.new(game.data, "BLASTOISE", 55)
  mon.moves = {
    { id = "SURF", pp = 15 }, { id = "STRENGTH", pp = 15 },
    { id = "BITE", pp = 25 }, { id = "HYDRO_PUMP", pp = 5 },
  }
  save.party = { mon }
  save.inventory = save.inventory or {}
  save.inventory.SOULBADGE, save.inventory.RAINBOWBADGE = 1, 1
  -- Start directly south of RED's real, dynamically spawned wall fissure.
  -- This is the sole fixture placement; after title CONTINUE the acceptance
  -- driver may move only through normal input, interactions and native warps.
  save.player.map, save.player.x, save.player.y, save.player.facing =
    "ROUTE_22", 35, 2, "up"
  save.lastHeal = { map = "VIRIDIAN_CITY", x = 19, y = 17 }
  save.lastOutdoor = { id = "ROUTE_22", x = 35, y = 2 }
  save.flags = save.flags or {}
  save.flags.EVENT_GOT_STARTER = true
  save.flags.EVENT_GOT_POKEDEX = true
  -- Discovery is post-League content. Keep this prerequisite internally
  -- coherent so the final black-door sequence can prove Oak's real call and
  -- Legacy-Journey gate instead of ending in the deliberate pre-Hall branch.
  save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  -- The bounded dungeon traversal begins after the separate Scientist-riddle
  -- acceptance.  Record only that real discovery token; the driver still
  -- performs the fissure confirmation and every subsequent warp itself.
  save.flags.KA_HEVO_FISSURE_DISCOVERED_RED = true
  save.version = version

  assert(SaveData.setActiveSlot(version, "slothevo65redinput") == "slothevo65redinput")
  assert(SaveData.writeSlot(version, "slothevo65redinput", save), "could not write RED prerequisite slot")
  local verified = assert(SaveData.load())
  assert(verified.player and verified.player.map == "ROUTE_22"
      and verified.player.x == 35 and verified.player.y == 2
      and verified.player.facing == "up",
    "RED prerequisite did not retain the Route-22 fissure approach")
  local bucket = verified.modData and verified.modData.kanto_ascendant
  assert(not (bucket and bucket.hevo_run), "setup must not manufacture RED progress")
  U.log("HEVO RED INPUT SETUP PASS: Route-22 fissure + real SURF/STRENGTH only")
  love.event.quit(0)
end
