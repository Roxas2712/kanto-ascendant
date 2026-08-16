-- Bounded current-engine proof that HallOfFame keeps the selected
-- RED/GREEN/BLUE identity instead of crystal_v15's historic Red fallback.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local HallOfFame = require("src.ui.HallOfFame")
  local Pokemon = require("src.pokemon.Pokemon")
  local Sprites = require("src.pokemon.Sprites")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local ascendant = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(ascendant.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end
  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.character_sprite_style = "crystal"
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "character_sprite_style", value = "crystal",
  })

  for _, id in ipairs({ "RED", "GREEN", "BLUE" }) do
    clearStack()
    characters.select(id)
    characters.refreshVisuals(game)
    game.save.player.name = id == "GREEN" and "KRIS" or id
    game.save.party = { Pokemon.new(game.data, "PIKACHU", 70) }
    local expected = assert(characters.getPlayerSprite("hallOfFame"))
    local resolvedPath, resolvedTrueColor = Sprites.playerPath(
      game.data, "front", { kind = "hof" })
    local hall = HallOfFame.new(game, function() end)
    check(id .. " Hall source follows selected identity",
      hall.playerPic ~= nil and hall.playerTrueColor == true
        and resolvedTrueColor == true
        and tostring(resolvedPath):find(expected.path, 1, true))
    game.stack:push(hall)
    -- StateStack:push calls HallOfFame:enter(), which deliberately starts
    -- the first party member off-screen.  Stage the player-stats endpoint
    -- only after that enter hook so the accepted frame is fully settled.
    hall.index = #game.save.party + 1
    hall.phase = "player_stats"
    hall.scrollX = 96
    hall.timer = 120
    U.wait(8)
    check(id .. " Hall screenshot",
      U.shot(game, dir .. "/hof_" .. id:lower() .. ".png"))
  end

  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write(fail == 0 and "PASS\n" or "FAIL\n")
  result:write(("pass=%d\nfail=%d\n"):format(pass, fail))
  result:close()
  love.event.quit(fail == 0 and 0 or 1)
end
