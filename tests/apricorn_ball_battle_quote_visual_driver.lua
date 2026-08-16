-- Real LÖVE/UI proof for the live Apricorn Ball quote shown by BagMenu.
-- Captures a positive and negative Fast Ball target in the requested locale.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local BagMenu = require("src.ui.BagMenu")
  local Pokemon = require("src.pokemon.Pokemon")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local locale = os.getenv("QA_LANGUAGE") or "en"
  assert(locale == "en" or locale == "de", "QA_LANGUAGE must be en/de")

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports missing")
  local apricorn = assert(api.apricornBalls, "Apricorn runtime missing")
  assert(api.language and api.language() == locale,
    "requested runtime language is not active")

  game.save.player.name = locale == "de" and "ROT" or "RED"
  game.save.party = { Pokemon.new(game.data, "BULBASAUR", 20) }
  game.save.party[1].hp = game.save.party[1].stats.hp
  game.save.pokedex = game.save.pokedex or { owned = {}, seen = {} }
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = "fast"
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local overworld = game.overworld

  local expected = {
    VOLTORB = locale == "de"
      and "FANGRATE x4\nBASIS-INIT. HOCH"
      or "CATCH RATE x4\nBASE SPEED HIGH",
    RATTATA = locale == "de"
      and "FANGRATE x1\nBASIS-INIT. NIED."
      or "CATCH RATE x1\nBASE SPEED LOW",
  }

  local function pageText(box)
    return box and box.pages and box.pages[1]
      and table.concat(box.pages[1], "\n") or ""
  end

  local function returnToOverworld()
    while game.stack:top() and game.stack:top() ~= overworld do
      game.stack:pop()
    end
    U.wait(3)
  end

  local function capture(species, tag)
    game.save.inventory = { FAST_BALL = 2 }
    game.save.bagOrder = { "FAST_BALL" }
    local battle = BattleState.newWild(game, species, 20)
    battle.onFinish = function() end
    game.stack:push(battle)
    for _ = 1, 100 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(3)
    end
    assert(battle.phase == "menu", species .. " battle command menu missing")

    local bag = BagMenu.new(game, { battle = battle })
    game.stack:push(bag)
    U.wait(8)
    assert(bag.items[1] and bag.items[1].value == "FAST_BALL",
      "Fast Ball is not the selected live Bag row")
    U.tap(game, "a")
    U.wait(160)

    local preview = game.stack:top()
    assert(preview ~= battle and pageText(preview) == expected[species],
      species .. " quote mismatch: " .. pageText(preview))
    assert(game.save.inventory.FAST_BALL == 2,
      "quote must be visible before consumption")
    assert(battle.lastBall == nil, "quote must be visible before the throw")
    assert(battle.apricornBallQuote
      and battle.apricornBallQuote.formatted
      and battle.apricornBallQuote.formatted.text == expected[species],
      "battle and UI must share one formatted quote")
    assert(battle.apricornBallQuote.formatted.maxGlyphs
      <= apricorn.DISPLAY_WIDTH, "quote overflows the 18-glyph box")
    assert(U.shot(game, ("%s/%s_fast_%s.png"):format(
      shotDir, locale, tag)), "quote screenshot failed")

    for _ = 1, 12 do
      if game.stack:top() ~= preview then break end
      U.tap(game, "a")
      U.wait(3)
    end
    assert(game.stack:top() == battle, "quote did not return to battle")
    assert(game.save.inventory.FAST_BALL == 1,
      "dismissing quote must consume exactly one Fast Ball")
    returnToOverworld()
  end

  capture("VOLTORB", "positive")
  capture("RATTATA", "negative")
  U.log("APRICORN BALL BATTLE QUOTE VISUAL PASS", locale,
    "positive + negative, pre-consume, 18-glyph")
  love.event.quit(0)
end
