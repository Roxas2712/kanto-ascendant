-- Real-LOVE regression for Ascendant's post-catch decision:
-- ASK must run even with party room, a full active box must overflow into
-- the next box, and the nickname prompt must keep the caught Pokémon visible.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-catch-destination"
  local BattleState = require("src.battle.BattleState")
  local Boxes = require("src.pokemon.Boxes")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local Pokemon = require("src.pokemon.Pokemon")

  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function pageText(state)
    local out = {}
    for _, page in ipairs(state and state.pages or {}) do
      for _, line in ipairs(page) do out[#out + 1] = line end
    end
    return table.concat(out, "\n")
  end

  local function waitFor(predicate, limit, mash)
    for frame = 1, (limit or 300) do
      local top = game.stack:top()
      if predicate(top) then return top end
      if mash and frame % 6 == 0 then U.tap(game, "a") end
      U.wait(1)
    end
    return nil
  end

  local function finishTextIntoChoice(limit)
    return waitFor(function(top)
      return getmetatable(top) == ChoiceBox
    end, limit or 300, true)
  end

  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.catch_destination = "ask"
  options.catch_box_notice = true
  options.pokemon_sprite_style = "crystal"
  options.sprite_style_battle = true
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = options

  -- A Johto back is intentional: this is the path that previously missed
  -- the derived-cache scale record unless Dramatic Shape replaced it.
  game.save.party = { Pokemon.new(game.data, "CHIKORITA", 15) }
  game.save.pokedex = game.save.pokedex or { owned = {}, seen = {} }
  game.save.pokedex.owned.PIDGEY = true
  game.save.pokedex.seen.PIDGEY = true
  local boxes = Boxes.ensure(game.save)
  for index = 1, Boxes.COUNT do boxes[index] = {} end
  game.save.currentBox = 1
  for _ = 1, Boxes.CAPACITY do
    boxes[1][#boxes[1] + 1] = Pokemon.new(game.data, "RATTATA", 3)
  end

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local overworld = game.overworld
  local battle = BattleState.newWild(game, "PIDGEY", 8)
  battle.onFinish = function() end
  overworld:pushBattle(battle)
  local battleReady = waitFor(function(top)
    return top == battle and battle.phase == "menu"
  end, 600, true)
  check("wild battle reaches its command menu", battleReady ~= nil)

  -- Exercise the engine's actual successful-catch bookkeeping without
  -- spending hundreds of frames on the already-covered Ball animation.
  battle.queue = {}
  battle.current = nil
  battle.nextInsert = 0
  battle.phase = "messages"
  battle.afterQueue = "menu"
  local caught = battle.enemy.mon
  battle:storeCaughtMon()

  local destination = waitFor(function(top)
    return pageText(top):find("Where should", 1, true) ~= nil
      or pageText(top):find("Wohin soll", 1, true) ~= nil
  end, 180)
  check("ASK appears even though the party has room", destination ~= nil)
  check("caught Pokémon initially joins the party",
    game.save.party[#game.save.party] == caught)

  local destinationChoice = finishTextIntoChoice()
  check("destination prompt opens YES/NO", destinationChoice ~= nil)
  check("destination prompt screenshot",
    destinationChoice
      and U.shot(game, DIR .. "/catch_destination_ask.png"))
  if destinationChoice then
    U.tap(game, "down") -- NO: BOX
    U.tap(game, "a")
  end

  local nickname = waitFor(function(top)
    return battle.blankForAskName and top and top.pages ~= nil
  end, 180)
  check("nickname prompt follows the destination decision", nickname ~= nil)
  local exports = game.mods.exports
    and game.mods.exports.kanto_ascendant
  check("capture preview renderer is installed",
    exports and exports.capturePreview ~= nil)

  local nicknameChoice = finishTextIntoChoice()
  check("nickname prompt opens YES/NO", nicknameChoice ~= nil)
  check("nickname prompt with Pokémon preview screenshot",
    nicknameChoice
      and U.shot(game, DIR .. "/nickname_with_pokemon.png"))
  if nicknameChoice then
    U.tap(game, "down") -- no nickname
    U.tap(game, "a")
  end

  local boxNotice = waitFor(function(top)
    local text = pageText(top)
    return text:find("BOX 2", 1, true) ~= nil
  end, 240)
  if not boxNotice then
    U.log("NOTICE_DEBUG", pageText(game.stack:top()),
      "queue", battle.queue and #battle.queue or -1,
      "phase", tostring(battle.phase), "after", tostring(battle.afterQueue),
      "waitingUI", tostring(battle.waitingUI),
      "blank", tostring(battle.blankForAskName))
    U.shot(game, DIR .. "/notice_debug.png")
  end
  check("overflow notice names BOX 2", boxNotice ~= nil)
  check("BOX 2 notice screenshot",
    boxNotice and U.shot(game, DIR .. "/catch_overflow_box_2.png"))

  local count, boxIndex = 0, nil
  for index, box in ipairs(boxes) do
    for _, mon in ipairs(box) do
      if mon == caught then
        count = count + 1
        boxIndex = index
      end
    end
  end
  check("caught Pokémon is removed from party",
    game.save.party[#game.save.party] ~= caught)
  check("full active box overflows exactly once into BOX 2",
    count == 1 and boxIndex == 2 and #boxes[1] == Boxes.CAPACITY)

  if boxNotice then
    for _ = 1, 80 do
      if game.stack:top() == overworld then break end
      U.tap(game, "a")
      U.wait(2)
    end
  end
  check("capture flow returns to the overworld",
    game.stack:top() == overworld)
  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
