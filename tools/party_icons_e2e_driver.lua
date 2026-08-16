-- Dedicated real-LÖVE team-icon capture.  Keeping this driver to one screen
-- avoids fast screenshot batches sampling an intermediate palette canvas;
-- each process proves one deterministic animation phase in one ROM edition.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local frame = os.getenv("ASCENDANT_TEAM_FRAME") == "b" and "b" or "a"
  assert(GameVersion.get() == version, "wrong imported edition")
  U.wait(5)

  local api = assert(game.mods.exports.kanto_ascendant,
    "Kanto Ascendant exports missing")
  assert(api.partyIcons and api.partyIcons.loadedStyle == "animated",
    "animated party-icon mode was not loaded")
  local expectedPath = os.getenv("POKEPORT_EXPECT_MOD_PATH")
  if expectedPath then
    assert(game.mods.mods.kanto_ascendant.path == expectedPath,
      "wrong candidate path")
  end

  game.save.party = {}
  for _, species in ipairs({
    "BULBASAUR", "PIKACHU", "MEOWTH", "CHARMANDER", "SQUIRTLE", "RAICHU",
  }) do
    game.save.party[#game.save.party + 1] = Pokemon.new(game.data, species, 30)
    local icon = game.data.icons.bySpecies[species]
    assert(type(icon) == "table" and icon.frames == 6
      and icon.image:find("follower_", 1, true),
      species .. " exact authored team icon missing")
    local ok, image = pcall(love.graphics.newImage, icon.image)
    assert(ok and image and image:getWidth() == 16 and image:getHeight() == 96,
      species .. " team sheet is not loadable 16x96 art")
  end

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  local menu = require("src.ui.PartyMenu").new(game)
  menu.blink = frame == "b" and 6 or 0
  menu.update = function() end
  game.stack:push(menu)
  U.wait(8)
  local shotDir = os.getenv("SHOT_DIR") or "/tmp/party-icons-e2e"
  local path = ("%s/%s-team-icons-frame-%s.png"):format(
    shotDir, version, frame)
  assert(U.shot(game, path), "team icon screenshot failed")
  U.log("PARTY ICON REAL E2E PASS", version, frame,
    "6 distinct loadable species sheets")
  love.event.quit(0)
end
