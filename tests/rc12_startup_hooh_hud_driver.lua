-- Renderer-backed acceptance for the 6.5 startup, Ho-Oh vision and HUD fixes.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local OakSpeech = require("src.ui.OakSpeech")
  local Runtime = require("src.mods.Runtime")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local crystal = assert(exports.crystalAnimation)
  local visions = assert(exports.visionEncounters)
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
  local options = game.mods.modOptions.kanto_ascendant
  options.pokemon_sprite_style = "crystal"
  options.character_sprite_style = "crystal"
  options.crystal_animation = true
  options.sprite_style_battle = true
  options.sprite_style_scenes = true
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = options
  Runtime.emit("mod.options_changed", { game = game,
    mod = "kanto_ascendant" })

  -- The selector owns the three dedicated high-resolution standing models;
  -- 2D battles continue to use their separate native 64x64 fronts.
  clearStack()
  local selector = characters.CharacterSelect.new(game, {}, function() end)
  game.stack:push(selector)
  check("selector starts on Green HD standing model",
    characters.selectionOrder[selector.index] == "GREEN"
      and characters.selectionVisual("GREEN").path:find(
        "green_voxel_front.png", 1, true) ~= nil)
  check("character HD selector screenshot",
    U.shot(game, dir .. "/01_character_battle_fronts.png"))

  -- Drive Oak's real decorated demo object through two authored frames.
  clearStack()
  local speech = OakSpeech.new(game, function() end)
  table.insert(game.stack.states, speech)
  speech.pic, speech.picFlip = speech.demoPic, true
  local state = speech.__ascendantCrystalV15OakDemo
  local oakReceipt = speech.__kantoAscendantOakApproved
  check("Oak welcome owns the approved V1 portrait",
    oakReceipt and oakReceipt.schema == "ka-approved-oak-intro/v1"
      and oakReceipt.version == "v1"
      and speech.__kantoAscendantOakHdPortraits
      and speech.__kantoAscendantOakHdPortraits.oak)
  local demoReceipt = speech.__ascendantCrystalV15OakDemoReceipt
  check("Oak Nidorino owns a forced Crystal animation before gameplay",
    state and state.species == "NIDORINO" and state.animated == true
      and demoReceipt and demoReceipt.frameCount > 1
      and demoReceipt.forcedBundled == true)
  check("Oak Crystal frame A screenshot",
    U.shot(game, dir .. "/02_oak_crystal_frame_a.png"))
  local before = state and state.image
  if state then
    crystal.advancePresentation(state, 0.35, game)
    speech.demoPic, speech.pic = state.image, state.image
  end
  check("Oak demo advances to another image", state and state.image ~= before)
  check("Oak Crystal frame B screenshot",
    U.shot(game, dir .. "/03_oak_crystal_frame_b.png"))

  clearStack()
  U.teleport(game, "ROUTE_2", 4, 48, "down")
  check("Ho-Oh test cell is southern grass before Viridian Forest",
    game.overworld.map:isGrassCell(4, 48)
      and visions.eligibleStep(game, visions.DEFS[1],
        { mapId = "ROUTE_2", x = 4, y = 48 }, 0.009))
  local lead = Pokemon.new(game.data, "PIKACHU", 100)
  lead.dvs.attack = 15
  game.save.party = { lead }
  game.save.lastHeal = { map = "VIRIDIAN_POKECENTER", x = 3, y = 4,
    outdoor = { id = "VIRIDIAN_CITY", x = 22, y = 25 } }

  local overworldBattle
  local dramatic = game.mods.exports.DRAMALESS_SHAPE
    or game.mods.exports.DRAMATIC_SHAPE
  if dramatic then
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    overworldBattle = dramatic.lib.require("OverworldBattle")
    if overworldBattle and overworldBattle.setting then
      overworldBattle.setting:setIndex(1, game)
    end
  end

  check("Ho-Oh vision starts on Route 2", visions.start(game, visions.DEFS[1]))
  local battle = visions.active
  local ready = false
  for _ = 1, 1000 do
    if game.stack:top() == battle and battle.phase == "menu"
        and not battle.showEnemyTrainer and not battle.showPlayerBack then
      ready = true
      break
    end
    if U.frame() % 5 == 0 then U.tap(game, "a") else U.wait(1) end
  end
  check("Ho-Oh vision reaches the command HUD", ready)
  check("Ho-Oh is scoped as golden in this battle",
    battle.enemy.__ascendantVisionGold == true
      and battle.enemy.__ascendantCrystalAnimation
      and battle.enemy.__ascendantCrystalAnimation.visionGold == true)
  check("level-100 gender HUD screenshot",
    U.shot(game, dir .. "/04_golden_hooh_level100_hud.png"))

  battle.player.mon.status = "PAR"
  battle.player.shownStatus = "PAR"
  check("status/gender HUD screenshot",
    U.shot(game, dir .. "/05_golden_hooh_status_hud.png"))
  -- Model BattleState:finish's pop, then hand the loss to the real callback.
  if game.stack:top() == battle then game.stack:pop() end
  battle.onFinish("lose")
  for _ = 1, 240 do
    if game.overworld and game.overworld.map
        and game.overworld.map.id == "VIRIDIAN_POKECENTER" then break end
    U.wait(1)
  end
  check("Ho-Oh defeat warps to the last Pokemon Center",
    game.overworld and game.overworld.map
      and game.overworld.map.id == "VIRIDIAN_POKECENTER")
  check("Pokemon Center return screenshot",
    U.shot(game, dir .. "/06_hooh_defeat_pokemon_center.png"))

  U.log(("RC12 STARTUP/HO-OH/HUD RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
