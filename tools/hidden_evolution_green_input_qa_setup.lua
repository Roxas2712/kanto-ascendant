-- One-shot prerequisite slot for GREEN's physical-input release proof.
-- It selects GREEN and starts on the audited Route 3 approach; it never
-- enters a trial map or manufactures questions, gates, secrets or rewards.
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Bag = require("src.inventory.Bag")
  local version = assert(os.getenv("POKEPORT_VERSION"), "POKEPORT_VERSION required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "POKEPORT_IDENTITY required")
  local render=os.getenv("GREEN_QA_RENDER")=="voxel" and "full" or "2d"
  assert(identity=="ka65-final-hevo-green-fresh-"..render,
    "refusing non-orchestrated GREEN Fresh identity")
  assert(os.getenv("KA_PACKAGE_GATE")=="1",
    "refusing GREEN Fresh setup outside the immutable package gate")
  assert(GameVersion.get() == version, "game version mismatch")
  assert(game.mods.exports.kanto_ascendant, "Kanto Ascendant must be loaded")

  local save = SaveData.newGame({ version=version, playerName="GREEN", rivalName="RED" })
  save.meta = SaveData.buildMeta(assert(game.modStatus and game.modStatus.loaded,
    "active GREEN QA package closure missing"))
  save.modData.kanto_ascendant = {
    extended_characters = {
      version=1, enabled=true, player_character="GREEN",
      rival_character="RED", third_character="BLUE",
    },
  }
  save.options = save.options or {}
  save.options.modOptions = save.options.modOptions or {}
  save.options.modOptions.kanto_ascendant = {
    ascendant_qol=true, qol_easy_interactions=true,
    qol_location_banners=false,
  }
  save.player.map, save.player.x, save.player.y, save.player.facing =
    "ROUTE_3", 41, 4, "up"
  save.lastHeal = { map="PEWTER_CITY", x=35, y=17 }
  save.lastOutdoor = { id="ROUTE_3", x=41, y=4 }
  save.flags = {
    EVENT_GOT_STARTER=true, EVENT_GOT_POKEDEX=true,
    EVENT_BEAT_BROCK=true, EVENT_BEAT_MISTY=true, EVENT_GOT_HM01=true,
    EVENT_BEAT_CHAMPION_RIVAL=true,
    -- The physical run begins immediately after Arbo's post-League riddle;
    -- no puzzle, package, seal or reward state is manufactured here.
    KA_HEVO_FISSURE_DISCOVERED_GREEN=true,
  }
  local cutter=Pokemon.new(game.data,"BULBASAUR",20)
  cutter.moves={
    {id="CUT",pp=assert(game.data.moves.CUT).pp},
    {id="TACKLE",pp=assert(game.data.moves.TACKLE).pp},
  }
  save.party={cutter}
  assert(Bag.add(save,"CASCADEBADGE",1,game.data),
    "could not add GREEN's legal Cascade Badge")
  assert(Bag.add(save,"HM_CUT",1,game.data),
    "could not add GREEN's narratively legal HM01")
  save.version = version

  assert(SaveData.setActiveSlot(version, "slothevo65greenrelease")
    == "slothevo65greenrelease")
  assert(SaveData.writeSlot(version, "slothevo65greenrelease", save),
    "could not write GREEN prerequisite slot")
  local verified = assert(SaveData.load())
  assert(verified.player and verified.player.map=="ROUTE_3"
      and verified.player.x==41 and verified.player.y==4,
    "GREEN prerequisite did not retain the Route 3 approach")
  assert(verified.inventory and verified.inventory.CASCADEBADGE
      and verified.inventory.HM_CUT,
    "GREEN prerequisite did not retain the legal CUT inventory")
  assert(verified.party and verified.party[1]
      and verified.party[1].species=="BULBASAUR"
      and verified.party[1].moves and verified.party[1].moves[1]
      and verified.party[1].moves[1].id=="CUT",
    "GREEN prerequisite did not retain its legal CUT carrier")
  local bucket = verified.modData and verified.modData.kanto_ascendant
  assert(not (bucket and bucket.hevo_run),
    "setup must not manufacture GREEN progress")
  U.log("HEVO GREEN SETUP PASS: Route 3 + legal Bulbasaur CUT/Cascade prerequisite")
  love.event.quit(0)
end
