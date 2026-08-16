-- Live proof that the first Route 22 rival battle is entered through the
-- real map event, with the exact pre-Brock/Pokedex flag window.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  characters.select("GREEN")
  characters.refreshVisuals(game)
  game.save.player.name, game.save.player.rival = "CASEY", "RED"
  game.save.party = { Pokemon.new(game.data, "MEWTWO", 100) }
  game.save.flags = {
    EVENT_GOT_STARTER = true,
    EVENT_CHOSE_SQUIRTLE = true,
    EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true,
    EVENT_GOT_POKEDEX = true,
  }
  game.save.objectToggles = {}

  U.teleport(game, "ROUTE_22", 28, 4, "right")
  U.wait(24)
  check("Route 22 starts one tile before the canonical ambush", game.overworld
    and game.overworld.map.id == "ROUTE_22"
    and game.overworld.player.cellX == 28
    and game.overworld.player.cellY == 4)
  U.hold(game, "right", 24)

  local sawEventText = false
  for _ = 1, 500 do
    local top = game.stack:top()
    if top and top.pages then
      sawEventText = true
      break
    end
    U.wait(2)
  end
  check("real Route 22 onStep opens the rival event", sawEventText)
  local routeRival
  for _, npc in pairs(game.overworld.npcs or {}) do
    local role = tostring(npc.def and npc.def.name or "") .. ":"
      .. tostring(npc.id or "")
    if role:find("RIVAL", 1, true) then
      routeRival = npc
      break
    end
  end
  local expectedField = characters.getRivalSprite("overworld")
  check("Green route resolves the spawned Route 22 field rival as Red",
    routeRival and routeRival.ascendantCharacter == "RED"
    and routeRival.sprite
    and expectedField and routeRival.sprite.def
      == game.data.sprites[expectedField.sprite])
  U.wait(100)
  check("Route 22 event capture",
    U.shot(game, dir .. "/route22_01_real_ambush.png"))

  local battle
  for _ = 1, 700 do
    local top = game.stack:top()
    if getmetatable(top) == BattleState then battle = top break end
    if top ~= game.overworld then U.tap(game, "a") end
    U.wait(2)
  end
  check("Route 22 event pushes a real trainer battle", battle ~= nil)
  if battle then
    for _ = 1, 240 do
      if battle.showEnemyTrainer then break end
      U.wait(2)
    end
  end
  check("Route 22 battle uses the Red rival presentation",
    battle and battle.showEnemyTrainer and battle.oppClass == "OPP_RIVAL1"
    and battle.trainer and battle.trainer.ascendantCharacter == "RED")
  check("Route 22 battle capture",
    U.shot(game, dir .. "/route22_02_battle_started.png"))

  U.log(("ROUTE22 EVENT RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
