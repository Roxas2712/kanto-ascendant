-- One-shot QA save builder for the trial-bound cycle-1 Level-70 habitats.
--
-- Required environment:
--   KA_HEVO_MOD=/absolute/path/to/Authority-worktree
--   HEVO_ENCOUNTER_DEMO_CHARACTER=RED|BLUE|GREEN
--   POKEPORT_VERSION=red|blue|yellow
--   POKEPORT_IDENTITY=<isolated identity containing hevo-encounter-demo>
--
-- This is a prerequisite generator, not a completion shortcut: it places the
-- rightful traveler just inside the first trial floor, records the real
-- fissure-entry admission flag and grants no HEVO package, seal or reward.
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local GBCFX = require("src.render.GBCFX")
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing HEVO encounter setup outside the immutable package gate")
  local harness = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR package harness required")
  local character = assert(os.getenv("HEVO_ENCOUNTER_DEMO_CHARACTER"),
    "HEVO_ENCOUNTER_DEMO_CHARACTER required"):upper()
  local manifest = assert(loadfile(harness
    .. "/tools/hevo_dungeon_encounter_demo_manifest.lua"))()
  local demo = assert(manifest[character],
    "demo character must be RED, BLUE or GREEN")
  assert(manifest.GBCFX == 0, "demo manifest must require GBCFX OFF")
  assert(manifest.BASE_CYCLE == 1 and manifest.BASE_LEVEL == 70
      and manifest.LEVEL_STEP == 5 and manifest.MAX_LEVEL == 100,
    "demo manifest has stale Legacy-cycle scaling")
  assert(demo.cycle == manifest.BASE_CYCLE
      and demo.expectedLevel == manifest.BASE_LEVEL,
    "demo must remain the accepted first-cycle Level-70 baseline")
  local requestedCycle = math.max(1, math.floor(tonumber(
    os.getenv("HEVO_ENCOUNTER_DEMO_CYCLE")) or demo.cycle))
  local expectedLevel = math.min(manifest.MAX_LEVEL,
    manifest.BASE_LEVEL + manifest.LEVEL_STEP * (requestedCycle - 1))
  local version = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY required")
  assert(identity:find("hevo%-encounter%-demo"),
    "refusing non-isolated HEVO encounter demo identity")
  assert(GameVersion.get() == version, "game version mismatch")
  local exports = assert(game.mods.exports.kanto_ascendant,
    "Kanto Ascendant must be loaded")
  local encounters = assert(exports.hiddenEvolutionCampaign
      and exports.hiddenEvolutionCampaign.encounters,
    "HEVO encounter controller must be loaded")

  local rival = ({ RED="BLUE", BLUE="GREEN", GREEN="RED" })[character]
  local third = ({ RED="GREEN", BLUE="RED", GREEN="BLUE" })[character]
  local save = SaveData.newGame({ version=version, playerName=character,
    rivalName=rival })
  -- Stamp the exact active closure.  FULL acceptance adds DRAMALESS and its
  -- dependency runner; omitting those rows makes the engine correctly open
  -- its mod-change warning instead of rendering the requested world frame.
  save.meta = SaveData.buildMeta(assert(game.modStatus and game.modStatus.loaded,
    "active mod closure missing"))
  local parents = {}
  for _, row in ipairs(encounters.rows({
      flags = { [encounters.ENTERED_FLAG_PREFIX .. character] = true },
      modData = { kanto_ascendant = { extended_characters = {
        player_character = character,
      } } },
    }, character)) do
    parents[#parents + 1] = row.species
  end
  assert(#parents > 0, "demo parent registry is empty")
  save.modData.kanto_ascendant = {
    extended_characters = {
      version=1, enabled=true, player_character=character,
      rival_character=rival, third_character=third,
    },
    hevo_encounter_demo = {
      version=1, character=character, map=demo.map,
      start={x=demo.start.x,y=demo.start.y,facing=demo.start.facing},
      routeCells=demo.routeCells, cycle=requestedCycle,
      level=expectedLevel,
      expectedParents=parents,
    },
    -- This is the same save-local cycle source the product seeds for a later
    -- Legacy Journey. It changes only the encounter-level formula; no path,
    -- package, item, seal or completion authority is granted.
    legacy_journey = requestedCycle > 1 and {
      version=1, cycle=requestedCycle,
    } or nil,
  }
  assert(encounters.levelFor(save) == expectedLevel,
    "demo save did not resolve its requested Legacy-cycle level")
  save.flags = save.flags or {}
  save.flags.KA_HEVO_CHARACTER_ARCHITECTURE_V1 = true
  save.flags[encounters.ENTERED_FLAG_PREFIX .. character] = true
  save.flags.EVENT_GOT_STARTER = true
  save.flags.EVENT_GOT_POKEDEX = true
  save.player.map, save.player.x, save.player.y, save.player.facing =
    demo.map, demo.start.x, demo.start.y, demo.start.facing
  save.lastHeal = { map="VIRIDIAN_CITY", x=19, y=17 }
  save.lastOutdoor = { id="ROUTE_22", x=35, y=2 }

  -- A neutral high-level test partner keeps the slot usable if QA chooses to
  -- touch a visible spawn.  It is fixture-only and grants no campaign item.
  local partner = Pokemon.new(game.data, "MEW", 75)
  partner.moves = {
    { id="STRENGTH", pp=15 }, { id="SURF", pp=15 },
    { id="CUT", pp=30 }, { id="PSYCHIC", pp=10 },
  }
  save.party = { partner }
  save.inventory = save.inventory or {}
  save.inventory.BOULDERBADGE = 1
  save.inventory.CASCADEBADGE = 1
  save.inventory.RAINBOWBADGE = 1
  save.inventory.SOULBADGE = 1
  save.options = save.options or {}
  -- Acceptance screenshots must show the authored sprites and visibility
  -- masks without GBCFX level-3's LCD raster/drop-shadow presentation.  This
  -- is fixture-local; the user's product option remains available elsewhere.
  save.options.gbcfx = manifest.GBCFX
  save.options.modOptions = save.options.modOptions or {}
  save.options.modOptions.kanto_ascendant = {
    living_world_enabled=true,
    living_world_density="very_high",
    living_world_random_encounters=false,
    living_world_caves="reachable",
    -- The natural-spawn acceptance run must receive a visible, reachable
    -- contact encounter.  Hidden/aggressive behaviours are independent user
    -- options and are covered by Wilds' own suite; disabling them here does
    -- not choose the species, cell, or invoke the test-spawn API.
    enable_hidden=false,
    enable_aggressive=false,
    qol_location_banners=false,
  }
  save.version = version

  GBCFX.setLevel(manifest.GBCFX)
  assert(GBCFX.level == 0 and not GBCFX.active(),
    "HEVO encounter demo requires runtime GBCFX OFF")
  assert(SaveData.saveOptions(save.options),
    "could not persist HEVO encounter demo renderer options")
  assert(SaveData.setActiveSlot(version, demo.slot) == demo.slot)
  assert(SaveData.writeSlot(version, demo.slot, save),
    "could not write HEVO encounter demo slot")
  local verified = assert(SaveData.load())
  assert(verified.player and verified.player.map == demo.map
      and verified.player.x == demo.start.x
      and verified.player.y == demo.start.y,
    "HEVO encounter demo did not retain its trial entry")
  assert(verified.options and verified.options.gbcfx == 0,
    "HEVO encounter demo did not retain GBCFX OFF")
  local bucket = assert(verified.modData.kanto_ascendant)
  assert(bucket.hevo_encounter_demo
      and #bucket.hevo_encounter_demo.expectedParents == #parents,
    "HEVO encounter demo manifest did not persist")
  assert(not bucket.hevo_persistent,
    "demo setup must not manufacture permanent HEVO unlocks")
  U.log(("HEVO %s CYCLE-%d LEVEL-%d DEMO PASS: %s at %d,%d; %d parents; %d route cells")
    :format(character, requestedCycle, expectedLevel,
      demo.map, demo.start.x, demo.start.y,
      #parents, #demo.routeCells))
  love.event.quit(0)
end
