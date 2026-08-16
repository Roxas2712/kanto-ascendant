-- Real-renderer hostile-path UAT for Mythic Signals.
--
-- Exercises an unsealed Mew or Celebi echo with a Master Ball and RUN, then
-- proves that a sealed true manifestation remains an ordinary catchable
-- battle. Set MYTHIC_QA_SPECIES=CELEBI for the second species.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")
  local TextBox = require("src.render.TextBox")

  U.wait(30)
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local mythic = assert(exports.mythicSignals,
    "Mythic Signals export missing")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local version = os.getenv("POKEPORT_VERSION") or "red"
  local species = (os.getenv("MYTHIC_QA_SPECIES") or "MEW"):upper()
  assert(species == "MEW" or species == "CELEBI",
    "MYTHIC_QA_SPECIES must be MEW or CELEBI")
  local qaLanguage = os.getenv("QA_LANGUAGE")
  if qaLanguage then
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.kanto_ascendant =
      game.mods.modOptions.kanto_ascendant or {}
    game.mods.modOptions.kanto_ascendant.language = qaLanguage
  end

  game.save.player = game.save.player or {}
  game.save.player.name = "SIGNAL"
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.inventory = game.save.inventory or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  local tank = Pokemon.new(game.data, "BLASTOISE", 100,
    function() return 15 end)
  tank.stats = Stats.calc(game.data.pokemon.BLASTOISE, 100,
    tank.dvs, tank.statExp)
  tank.hp = tank.stats.hp
  game.save.party = { tank }
  U.teleport(game, "ROUTE_1", 10, 5, "down")

  local function waitForMenu(battle, limit)
    for _ = 1, limit or 220 do
      if battle.phase == "menu" then return true end
      U.tap(game, "a")
      U.wait(4)
    end
    return battle.phase == "menu"
  end

  local echo = BattleState.newWild(game, species, 70)
  assert(mythic.applyBattleTicket(echo, {
    kind = "echo", species = species,
  }) == true, "could not mark echo battle")
  echo.onFinish = function() end
  game.overworld:pushBattle(echo)
  assert(waitForMenu(echo, 260), "echo battle did not reach its menu")
  assert(echo.noCatch == true and echo.kaMythicEcho == species,
    "echo is not protected from capture")
  assert(U.shot(game, shotDir .. "/01_echo_battle_menu.png"))

  -- BagMenu consumes first; the Mythic wrapper must restore exactly one.
  game.save.inventory.MASTER_BALL = nil
  echo:throwBall("MASTER_BALL")
  for frame = 1, 520 do
    if frame % 22 == 0 then U.tap(game, "a") else U.wait(1) end
    if frame == 100 then
      assert(U.shot(game, shotDir .. "/02_echo_master_ball_toss.png"))
    end
  end
  assert(game.save.inventory.MASTER_BALL == 1,
    "echo did not return the consumed Master Ball")
  assert(echo.kaMythicMasterBallReturned == true,
    "echo battle lacks the returned-ball marker")
  assert(game.save.pokedex.owned[species] ~= true,
    "echo became owned despite no-catch protection")
  local warning = exports.language() == "de"
    and ("Oh nein!\n%s lässt sich\nnicht fangen!"):format(species)
    or ("Oh no!\n%s cannot be\ncaught!"):format(species)
  game.stack:push(TextBox.new(game, warning))
  U.wait(50)
  assert(U.shot(game, shotDir .. "/03_echo_capture_rejected.png"))
  game.stack:pop()

  -- Yellow's partner/audio cadence may leave one more text/cry transition
  -- pending than Red/Blue. Keep advancing the real stack instead of
  -- assuming the shorter edition timing.
  assert(waitForMenu(echo, 500), "echo did not return to battle menu")
  echo.menuIndex = 4
  U.tap(game, "a")
  U.wait(35)
  assert(echo.result == nil,
    "RUN escaped from the Mythic echo")
  assert(U.shot(game, shotDir .. "/04_echo_run_refused.png"))

  -- Remove only this in-memory battle and stage the post-seal counterpart.
  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  local trueBattle = BattleState.newWild(game, species, 70)
  assert(mythic.applyBattleTicket(trueBattle, {
    kind = "true", species = species,
  }) == true, "could not mark true manifestation")
  assert(trueBattle.noCatch ~= true
      and trueBattle.kaMythicTrue == species,
    "sealed manifestation is incorrectly protected")
  trueBattle.onFinish = function() end
  game.overworld:pushBattle(trueBattle)
  assert(waitForMenu(trueBattle, 260),
    "true manifestation did not reach its menu")
  assert(U.shot(game, shotDir .. "/05_true_manifestation_menu.png"))

  game.save.inventory.MASTER_BALL = nil
  trueBattle:throwBall("MASTER_BALL")
  for frame = 1, 1400 do
    local top = game.stack:top()
    if top ~= trueBattle and top ~= game.overworld then
      U.tap(game, "b")
      U.wait(2)
    elseif frame % 18 == 0 then
      U.tap(game, "a")
    else
      U.wait(1)
    end
    if frame == 190 then
      assert(U.shot(game, shotDir .. "/06_true_manifestation_catch.png"))
    end
    if game.save.pokedex.owned[species] == true then break end
  end
  assert(game.save.inventory.MASTER_BALL == nil,
    "catchable manifestation incorrectly returned the Master Ball")
  assert(game.save.pokedex.owned[species] == true,
    "sealed true manifestation was not caught")

  U.log("MYTHIC SIGNALS ADVERSARIAL QA PASS", version, species)
end
