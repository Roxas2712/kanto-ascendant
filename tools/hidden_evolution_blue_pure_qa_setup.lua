-- One-shot prerequisite save for the separate BLUE physical-input proof.
--
-- This script is deliberately limited to selecting BLUE and placing an
-- otherwise untouched new-game save at the *real* Route 24 fissure approach.
-- It neither enters a HEVO map nor initializes/solves its campaign state.
-- The companion driver must boot it through CONTINUE and use only joypad
-- input plus the native SaveData reload boundary.
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local version = assert(os.getenv("POKEPORT_VERSION"), "POKEPORT_VERSION required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "POKEPORT_IDENTITY required")
  local render=os.getenv("BLUE_QA_RENDER")=="voxel" and "full" or "2d"
  assert(identity=="ka65-final-hevo-blue-fresh-"..render,
    "refusing non-orchestrated HEVO BLUE Fresh identity")
  assert(os.getenv("KA_PACKAGE_GATE")=="1",
    "refusing BLUE Fresh setup outside the immutable package gate")
  assert(GameVersion.get() == version, "game version mismatch")
  assert(game.mods.exports.kanto_ascendant, "Kanto Ascendant must be loaded")

  local save = SaveData.newGame({ version = version, playerName = "BLUE", rivalName = "GREEN" })
  save.meta = SaveData.buildMeta(assert(game.modStatus and game.modStatus.loaded,
    "active BLUE QA package closure missing"))
  save.modData.kanto_ascendant = {
    extended_characters = {
      version = 1, enabled = true, player_character = "BLUE",
      rival_character = "GREEN", third_character = "RED",
    },
    -- Keep the isolated long-walk fixture free of the unrelated, random
    -- Johto-Signals Oak phone call.  Only the notification flags are seeded;
    -- no capsule, receiver or campaign reward is granted.
    johto_signals = {
      version = 2,
      earlyJohto = {
        version = 2,
        oakCallShown = true,
        oakReminderShown = true,
        pokedexSteps = 0,
      },
      resonance = {},
      prismGrotto = {},
    },
  }
  -- This is the checked Route-24 approach cell, directly south of the real
  -- dynamically-spawned fissure.  It is a documented fixture start only;
  -- all HEVO traversal belongs to the pure input driver after title CONTINUE.
  save.player.map, save.player.x, save.player.y, save.player.facing = "ROUTE_24", 10, 4, "up"
  save.lastHeal = { map = "CERULEAN_CITY", x = 24, y = 2 }
  save.lastOutdoor = { id = "ROUTE_24", x = 10, y = 4 }
  save.flags = {
    EVENT_GOT_STARTER = true,
    EVENT_GOT_POKEDEX = true,
    EVENT_BEAT_MISTY = true,
    EVENT_BEAT_CHAMPION_RIVAL = true,
    -- The current product requires Nera's post-League field riddle before
    -- the wall may open.  This fixture begins after that single prerequisite;
    -- it still manufactures no tunnel entry, statue, package or seal state.
    KA_HEVO_FISSURE_DISCOVERED_BLUE = true,
  }
  -- One ordinary legal fixture mon carries the three field moves this
  -- acceptance journey must invoke through START -> POKeMON.  The driver is
  -- forbidden from setting flashLit, strengthActive or surfing directly.
  local fieldMon = Pokemon.new(game.data, "MEW", 30)
  fieldMon.nickname = "LOTSE"
  fieldMon.moves = {
    { id = "FLASH", pp = 15 },
    { id = "STRENGTH", pp = 15 },
    { id = "SURF", pp = 15 },
  }
  save.party = { fieldMon }
  save.inventory = save.inventory or {}
  save.inventory.BOULDERBADGE = true
  save.inventory.RAINBOWBADGE = true
  save.inventory.SOULBADGE = true
  save.options = save.options or {}
  save.options.modOptions = save.options.modOptions or {}
  save.options.modOptions.kanto_ascendant = {
    ascendant_qol = true,
    qol_easy_interactions = true,
    -- Keep the visual evidence focused on the traversed world.  This is a
    -- presentation-only fixture option; the product's default remains
    -- unchanged and every map is still reached through normal input.
    qol_location_banners = false,
  }
  save.options.pipelines = save.options.pipelines or {}
  save.options.pipelines.voxel = os.getenv("BLUE_QA_RENDER") == "voxel" and 1 or 0
  save.options.tilt = 0
  save.version = version
  -- Display pipelines live in the identity-wide options.lua, not in the
  -- slot payload.  Write them before selecting the slot; setActiveSlot then
  -- merges its own slot metadata over these display choices.
  assert(SaveData.saveOptions(save.options), "could not write BLUE renderer options")
  assert(SaveData.setActiveSlot(version, "slothevo65bluepure") == "slothevo65bluepure")
  assert(SaveData.writeSlot(version, "slothevo65bluepure", save), "could not write BLUE prerequisite slot")
  local verified = assert(SaveData.load())
  assert(verified.player and verified.player.map == "ROUTE_24" and verified.player.x == 10 and verified.player.y == 4,
    "BLUE prerequisite did not retain Route 24 approach")
  assert(not (verified.modData.kanto_ascendant.hevo_run), "setup must not manufacture HEVO progress")
  assert((verified.options.pipelines.voxel or 0) == save.options.pipelines.voxel,
    "BLUE renderer option did not survive setup")
  U.log("HEVO BLUE PURE SETUP PASS: Route 24 approach only; restart into input driver")
  love.event.quit(0)
end
