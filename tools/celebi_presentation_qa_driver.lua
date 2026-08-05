-- Real-client Celebi presentation audit.
--
-- Run for Red/Blue/Yellow and English/German. It verifies canonical Dex data,
-- captures the Dex page, then stages normal/shiny enemy fronts and the player
-- back in ordinary 2D. Mythic capture behavior is covered by the generic
-- mythic_signals_adversarial_qa_driver with MYTHIC_QA_SPECIES=CELEBI.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local Screens = require("src.ui.Screens")
  local Sprites = require("src.pokemon.Sprites")
  local Stats = require("src.pokemon.Stats")

  U.wait(30)
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local shiny = assert(exports.shinySystem, "Shiny controller missing")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local version = GameVersion.get()
  local qaLanguage = os.getenv("QA_LANGUAGE")
  if qaLanguage then
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.trainer_rematch =
      game.mods.modOptions.trainer_rematch or {}
    game.mods.modOptions.trainer_rematch.language = qaLanguage
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.trainer_rematch =
      game.save.options.modOptions.trainer_rematch or {}
    game.save.options.modOptions.trainer_rematch.language = qaLanguage
    if game.mods.events then
      game.mods.events:emit("mod.options_changed", {
        mod = "trainer_rematch", key = "language", value = qaLanguage,
      })
    end
    if exports.johtoAudio and exports.johtoAudio.refreshLocalization then
      exports.johtoAudio.refreshLocalization(game.data, qaLanguage == "de")
    end
    U.wait(4)
    assert(exports.language() == qaLanguage,
      "could not select QA language " .. tostring(qaLanguage))
  end

  local def = assert(game.data.pokemon.CELEBI, "Celebi is not registered")
  assert(def.dex == 251, "Celebi is not National Dex #251")
  local expectedKind = exports.language() == "de" and "ZEITREISE"
    or "TIME TRAVEL"
  assert(def.dexEntry and def.dexEntry.kind == expectedKind,
    "Celebi Dex category is wrong: " .. tostring(def.dexEntry
      and def.dexEntry.kind))
  local dexText = assert(game.data.text[def.dexEntry.text],
    "Celebi Dex prose key does not resolve")
  assert(#dexText > 20, "Celebi Dex prose is empty")

  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.pokedex.seen.CELEBI = true
  game.save.pokedex.owned.CELEBI = true
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  Pipelines.setLevel("voxel", 0)
  Pipelines.syncOptions(game.save.options)

  local dexPath = Sprites.path(
    game.data, "CELEBI", "front", { kind = "dex" })
  assert(type(dexPath) == "string"
      and dexPath:find("assets/crystal/celebi_front.png", 1, true),
    "Celebi Dex still uses the obsolete placeholder: " .. tostring(dexPath))
  Screens.push(game, "DexEntryMenu", "CELEBI")
  U.wait(55)
  assert(U.shot(game, shotDir .. "/01_celebi_dex.png"))
  U.tap(game, "b")
  U.wait(15)

  local player = Pokemon.new(game.data, "CELEBI", 70,
    function() return 9 end)
  player.stats = Stats.calc(def, 70, player.dvs, player.statExp)
  player.hp = player.stats.hp
  game.save.party = { player }
  U.teleport(game, "ROUTE_1", 5, 5, "down")

  local function closeBattle()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  for index, makeShiny in ipairs({ false, true }) do
    local battle = BattleState.newWild(game, "CELEBI", 70)
    if makeShiny then
      assert(shiny.forceMon(battle.enemy.mon, def),
        "could not force shiny Celebi")
      battle.enemy = BattleState.makeBattler(
        game.data, battle.enemy.mon, false, game.save)
    end
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    for _ = 1, 300 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(4)
    end
    assert(battle.phase == "menu", "Celebi battle did not reach menu")
    local animation = assert(battle.enemy.__ascendantCrystalAnimation,
      "Celebi enemy did not receive bundled Crystal animation")
    local firstFrame = assert(animation.frame,
      "Celebi Crystal animation has no first frame")
    assert(U.shot(game, ("%s/%02d_celebi_enemy_%s.png")
      :format(shotDir, index + 1, makeShiny and "shiny" or "normal")))
    for _ = 1, 240 do
      U.wait(1)
      if animation.frame ~= firstFrame then break end
    end
    assert(animation.frame ~= firstFrame,
      "Celebi Crystal animation did not advance")
    closeBattle()
    U.wait(10)
  end

  local backPath = Sprites.path(game.data, "CELEBI", "back", {
    kind = "battle", side = "back", mon = player,
  })
  assert(type(backPath) == "string"
      and backPath:find("celebi", 1, true),
    "Celebi player back resolved to another species: " .. tostring(backPath))

  U.log("CELEBI PRESENTATION QA PASS", version,
    exports.language(), expectedKind, dexPath, backPath)
end
