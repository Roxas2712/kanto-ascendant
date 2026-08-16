return function(game)
  local U = dofile("tests/drivers/util.lua")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  U.wait(30)

  local exports = assert(game.mods and game.mods.exports, "exports missing")
  local ascendant = assert(exports.kanto_ascendant, "Ascendant missing")
  local wilds = assert(exports.overworld_wild_spawns, "Wilds missing")
  assert(wilds.version == "1.12.2", "Wilds 1.12.2 required")
  local compat = assert(ascendant.wildsCompat, "Wilds adapter missing")
  assert(compat.townDensityWrapped, "town density bridge missing")
  assert(compat.townSpeciesWrapped, "town region bridge missing")
  assert(compat.townPokemonAmount() == 3,
    "test identity did not load exact town amount 3")
  assert(compat.townPokemonSpecies() == "johto",
    "test identity did not load Johto-only town population")

  U.teleport(game, "VIRIDIAN_CITY", 19, 20, "down")
  U.wait(180)
  local ambient = assert(wilds.ambient, "Wilds ambient manager missing")
  local johto = assert(ascendant.johtoData and ascendant.johtoData.species,
    "Ascendant Johto registry missing")
  local blocked = {
    RAIKOU = true, ENTEI = true, SUICUNE = true,
    LUGIA = true, HO_OH = true, CELEBI = true,
  }
  local count = 0
  local talkNpc
  for npc in pairs(ambient.active or {}) do
    count = count + 1
    talkNpc = talkNpc or npc
    assert(npc.wildsAmbientPokemon == true,
      "city Pokemon is not marked ambient")
    assert(npc.wildsBattleable == false
        and npc.wildsEncounterEnabled == false,
      "city Pokemon became battleable")
    assert(johto[npc.ambientSpecies] ~= nil,
      "Johto-only city spawned non-Johto species "
        .. tostring(npc.ambientSpecies))
    assert(not blocked[npc.ambientSpecies],
      "city population leaked protected species "
        .. tostring(npc.ambientSpecies))
    assert(type(npc._ambientSpriteKey) == "string"
        and npc._ambientSpriteKey:find(npc.ambientSpecies, 1, true),
      "Johto city Pokemon did not bind its own animated walker sheet: "
        .. tostring(npc.ambientSpecies))
  end
  assert(count == 3,
    "Viridian City expected exactly 3 peaceful Pokemon, got " .. count)
  assert(U.shot(game, shotDir .. "/viridian_city_johto_only_3.png"))

  local Runtime = require("src.mods.Runtime")
  local heard
  Runtime.events:on("sound.played", function(payload)
    if payload and payload.kind == "cry" then heard = payload.species end
  end, nil, "ka65-town-talk-e2e")
  local overworld = game.stack:top()
  local requested = os.getenv("TALK_SPECIES")
  if requested and requested ~= "" then
    assert(johto[requested], "requested talk species is not registered Johto")
    talkNpc.ambientSpecies = requested
    assert(ambient:_bindSprite(talkNpc, requested, game),
      "requested talk species could not bind its walker sheet")
  end
  local species = assert(talkNpc and talkNpc.ambientSpecies,
    "no ambient Pokemon available for talk test")
  local display = assert(game.data.pokemon[species]
    and game.data.pokemon[species].name, "localized species name missing")
  assert(game.data.audio and game.data.audio.cries
      and game.data.audio.cries[species],
    "species-authentic cry data missing for " .. species)
  ambient:talkTo(overworld, talkNpc)
  U.wait(60)
  assert(heard == species,
    "talk did not play the selected Pokemon cry: " .. species)
  local textBox = game.stack:top()
  local written = textBox and textBox.pages and textBox.pages[1]
    and textBox.pages[1][1]
  assert(written == display .. "!",
    ("localized written cry mismatch: expected %s!, got %s")
      :format(display, tostring(written)))
  assert(U.shot(game, shotDir .. "/viridian_city_localized_name_and_cry.png"))
  Runtime.events:removeOwner("ka65-town-talk-e2e")
  print(("WILDS 1.12.2 TOWN POPULATION PASS: VIRIDIAN_CITY exact=3 region=johto peaceful=3 talk=%s cry=played label=%s!")
    :format(species, display))
end
