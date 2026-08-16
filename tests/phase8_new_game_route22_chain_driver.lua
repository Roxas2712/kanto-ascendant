-- One-process proof of the fresh-game story chain: Oak escort, starter,
-- automatic lab rival battle, parcel/Pokedex handoff, then Route 22 ambush.

local runOakFlow = dofile("tests/drivers/oak_test.lua")

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local characters = assert(game.mods.exports.kanto_ascendant.extendedCharacters)
  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  -- A genuinely fresh story state; character identity is the only mod data.
  game.save.flags = {}
  game.save.party = {}
  game.save.objectToggles = {}
  game.save.inventory = {}
  game.save.pokedex = { seen = {}, owned = {} }
  characters.select("GREEN")
  characters.refreshVisuals(game)
  game.save.player.name, game.save.player.rival = "CASEY", "RED"

  runOakFlow(game)
  check("fresh chain completed Oak's Lab rival battle",
    game.save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true)
  check("fresh chain received the Pokedex",
    game.save.flags.EVENT_GOT_POKEDEX == true)
  check("fresh chain has not beaten Brock",
    game.save.flags.EVENT_BEAT_BROCK ~= true)

  U.teleport(game, "ROUTE_22", 28, 4, "right")
  U.wait(24)
  U.hold(game, "right", 24)
  local sawAmbush = false
  for _ = 1, 500 do
    local top = game.stack:top()
    if top and top.pages then sawAmbush = true break end
    U.wait(2)
  end
  check("fresh-game Route 22 ambush fires", sawAmbush)
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
  check("fresh-game spawned Route 22 rival stays Red for Casey",
    routeRival and routeRival.ascendantCharacter == "RED"
    and routeRival.sprite
    and expectedField and routeRival.sprite.def
      == game.data.sprites[expectedField.sprite])
  U.wait(100)
  check("fresh-game Route 22 text capture",
    U.shot(game, dir .. "/new_game_16_route22_ambush.png"))

  local battle
  for _ = 1, 700 do
    local top = game.stack:top()
    if getmetatable(top) == BattleState then battle = top break end
    if top ~= game.overworld then U.tap(game, "a") end
    U.wait(2)
  end
  check("fresh-game Route 22 battle starts", battle
    and battle.oppClass == "OPP_RIVAL1"
    and battle.trainer and battle.trainer.ascendantCharacter == "RED")
  if battle then U.wait(100) end
  check("fresh-game Route 22 battle capture",
    U.shot(game, dir .. "/new_game_17_route22_battle.png"))

  U.log(("NEW GAME ROUTE22 RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
