-- Renderer-backed Phase-8 acceptance capture.
--
-- Run from the Gen1 Recomp checkout with the mod linked at
-- mods/kanto_ascendant:
--   POKEPORT_DRIVER=../kanto-ascendant/tests/phase8_ingame_visual_driver.lua \
--   POKEPORT_IDENTITY=ka65-phase8-captures POKEPORT_VERSION=red \
--   SHOT_DIR=/tmp/ka65-phase8 love .

return function(game)
  local trace = assert(io.open((os.getenv("SHOT_DIR") or "/tmp")
    .. "/phase8_driver_trace.txt", "wb"))
  trace:write("driver-started\n")
  trace:close()
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  local exports = game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant
  local characters = exports and exports.extendedCharacters
  local gender = exports and exports.pokemonGender
  local daycare = exports and exports.daycare
  local hatchAnimation = exports and exports.eggHatchAnimation
  check("Kanto Ascendant and its Phase-8 exports are loaded",
    characters and gender and daycare and hatchAnimation)
  check("Crystal character family is the active default",
    characters and characters.characterStyle() == "crystal")
  local exportTrace = assert(io.open(dir .. "/phase8_driver_trace.txt", "ab"))
  exportTrace:write("exports=" .. tostring(characters and gender and daycare) .. "\n")
  exportTrace:close()
  if fail > 0 then love.event.quit(1) return end

  U.wait(12)
  U.teleport(game, "ROUTE_1", 5, 5, "down")

  local blue = characters.select("BLUE")
  characters.refreshVisuals(game)
  U.wait(8)
  check("Blue matrix assigns Green rival and Red third", blue.enabled
    and blue.rival_character == "GREEN" and blue.third_character == "RED")
  check("Blue player uses the complete Crystal overworld sheet",
    characters.getPlayerSprite("overworld").sprite
      == "SPRITE_KA_CRYSTAL_BLUE_WALK")
  check("Blue uses his native-size Crystal battle back",
    characters.getPlayerSprite("battleBack").status == "final"
      and characters.getPlayerSprite("battleBack").path
        == "assets/characters/crystal_chars/blue_back.png")
  check("Blue overworld capture", U.shot(game, dir .. "/01_blue_overworld.png"))

  local green = characters.select("GREEN")
  characters.refreshVisuals(game)
  U.wait(8)
  check("Green matrix assigns Red rival and Blue third", green.enabled
    and green.rival_character == "RED" and green.third_character == "BLUE")
  check("Green uses the authored Crystal walking sheet",
    characters.getPlayerSprite("overworld").sprite
      == "SPRITE_KA_CRYSTAL_GREEN_WALK"
      and characters.getPlayerSprite("overworld").status == "final")
  check("Green overworld capture", U.shot(game, dir .. "/02_green_overworld.png"))
  local greenPlayer = game.overworld.player
  greenPlayer.facing = "left"
  U.wait(3)
  check("Green side-pose capture",
    U.shot(game, dir .. "/02b_green_side_pose.png"))
  greenPlayer.facing = "up"
  U.wait(3)
  check("Green rear-pose capture",
    U.shot(game, dir .. "/02c_green_rear_pose.png"))
  greenPlayer.facing = "down"
  greenPlayer.bumpFrames, greenPlayer.animClock = 16, 6
  U.wait(1)
  check("Green live walk-frame capture",
    U.shot(game, dir .. "/02d_green_walk_frame.png"))
  greenPlayer.bumpFrames = nil

  local female = Pokemon.new(game.data, "PIKACHU", 12)
  local male = Pokemon.new(game.data, "PIKACHU", 12)
  local neutral = Pokemon.new(game.data, "MAGNEMITE", 12)
  female.dvs.attack, male.dvs.attack, neutral.dvs.attack = 0, 15, 0
  game.save.party = { female, male, neutral }
  clearStack()
  Screens.push(game, "PartyMenu")
  U.wait(8)
  check("female Pikachu has a female marker", gender.symbol(female, game) == "♀")
  check("male Pikachu has a male marker", gender.symbol(male, game) == "♂")
  check("genderless Magnemite has no marker", gender.symbol(neutral, game) == nil)
  check("Party gender capture", U.shot(game, dir .. "/03_party_gender.png"))

  clearStack()
  Screens.push(game, "SummaryMenu", female)
  U.wait(8)
  check("Summary gender capture",
    U.shot(game, dir .. "/03b_summary_gender.png"))

  clearStack()
  Screens.push(game, "SummaryMenu", male)
  U.wait(8)
  check("Male summary gender capture",
    U.shot(game, dir .. "/03c_summary_male_gender.png"))

  clearStack()
  Screens.push(game, "SummaryMenu", neutral)
  U.wait(20)
  check("Genderless summary omits its marker",
    gender.symbol(neutral, game) == nil)
  check("Genderless summary capture",
    U.shot(game, dir .. "/03d_summary_genderless.png"))

  clearStack()
  game.save.party = { male }
  local BattleState = require("src.battle.BattleState")
  local genderBattle = BattleState.newWild(game, "PIKACHU", 10)
  genderBattle.enemy.mon.dvs.attack = 0
  genderBattle.onFinish = function() end
  game.stack:push(genderBattle)
  for _ = 1, 80 do
    if genderBattle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(4)
  end
  check("battle reached its command menu for gender QA",
    genderBattle.phase == "menu")
  check("battle HUD derives female foe and male player",
    gender.symbol(genderBattle.enemy.mon, game) == "♀"
      and gender.symbol(genderBattle.player.mon, game) == "♂")
  check("Battle HUD gender capture",
    U.shot(game, dir .. "/03e_battle_gender.png"))

  clearStack()
  local nidoranMale = Pokemon.new(game.data, "NIDORAN_M", 10)
  nidoranMale.dvs.attack = 0 -- contrary DV cannot change a male-only species
  game.save.party = { nidoranMale }
  local nidoranBattle = BattleState.newWild(game, "NIDORAN_F", 10)
  nidoranBattle.enemy.mon.dvs.attack = 15 -- likewise remains female-only
  nidoranBattle.onFinish = function() end
  game.stack:push(nidoranBattle)
  for _ = 1, 80 do
    if nidoranBattle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(4)
  end
  check("Nidoran sexes ignore contrary Attack DVs",
    gender.symbol(nidoranBattle.enemy.mon, game) == "♀"
      and gender.symbol(nidoranBattle.player.mon, game) == "♂")
  check("Nidoran battle gender capture",
    U.shot(game, dir .. "/03f_battle_nidoran_gender.png"))

  local egg = Pokemon.new(game.data, "PICHU", 5)
  egg.nickname, egg.isEgg, egg.hp, egg.status = "EGG", true, 0, nil
  egg.moves = { { id = "CUT", pp = 30, maxPP = 30 } }
  game.save.party = { egg, female }
  clearStack()
  Screens.push(game, "PartyMenu")
  U.wait(6)
  U.tap(game, "a")
  U.wait(5)
  local eggMenu = game.stack:top()
  local actions, hasUnsafe = {}, false
  for _, item in ipairs(eggMenu and eggMenu.subItems or {}) do
    actions[item.action] = true
    hasUnsafe = hasUnsafe or item.action == "cut" or item.action == "surf"
      or item.action == "fly" or item.action == "battle_switch"
  end
  check("Egg submenu keeps STATS and normal reordering", actions.stats
    and actions.switch and not hasUnsafe)
  check("Egg submenu capture", U.shot(game, dir .. "/04_egg_safe_party_menu.png"))

  U.teleport(game, "DAYCARE", 3, 3, "down")
  local parentFemale = Pokemon.new(game.data, "PIKACHU", 18)
  local parentMale = Pokemon.new(game.data, "PIKACHU", 18)
  parentFemale.dvs.attack, parentFemale.dvs.defense,
    parentFemale.dvs.special, parentFemale.otId = 0, 1, 2, 111
  parentMale.dvs.attack, parentMale.dvs.defense,
    parentMale.dvs.special, parentMale.otId = 15, 2, 3, 222
  local daycareState = daycare.status()
  daycareState.parents = {
    { mon = parentFemale, depositLevel = 18, steps = 0 },
    { mon = parentMale, depositLevel = 18, steps = 0 },
  }
  daycareState.reservedEggs = {}
  local compatible, compatibility = daycare.compatible(
    game, parentFemale, parentMale)
  check("opposite-gender Pikachu pair is highly compatible",
    compatible and compatibility == 255)
  daycare.reserveEgg("PICHU", 64, "PHASE 8 QA EGG", "phase8_visual")
  local caretaker = {
    def = { name = "DAYCARE_GENTLEMAN" },
    facePlayer = function() end,
  }
  check("Route 5 Day-Care opens through its live talk handler",
    daycare.handleTalk(game.overworld, caretaker, game))
  U.wait(8)
  check("Day-Care pair and Egg capture",
    U.shot(game, dir .. "/05_daycare_egg_menu.png"))
  U.tap(game, "down")
  U.tap(game, "down")
  U.tap(game, "a")
  U.wait(90)
  check("Day-Care compatibility capture",
    U.shot(game, dir .. "/05b_daycare_compatibility.png"))

  -- Exercise the real world-step integration, not a detached animation
  -- mock: the Day-Care listener detects the zero-cycle party Egg and pushes
  -- the authored hatch state.
  clearStack()
  local hatchEgg = Pokemon.new(game.data, "PICHU", 5)
  hatchEgg.nickname, hatchEgg.isEgg = "EGG", true
  hatchEgg.eggSpecies = "PICHU"
  hatchEgg.eggStepsRemaining, hatchEgg.eggTotalSteps = 1, 1
  hatchEgg.hp, hatchEgg.status = 0, nil
  game.save.party = { hatchEgg, female }
  require("src.mods.Runtime").emit("world.stepped", {})
  check("final Egg step pushes the hatch movie",
    game.stack:top() and game.stack:top().mon == hatchEgg)
  U.wait(50)
  check("Egg wobble animation capture",
    U.shot(game, dir .. "/06a_egg_hatch_wobble.png"))
  U.wait(95)
  check("Egg crack animation capture",
    U.shot(game, dir .. "/06b_egg_hatch_crack.png"))
  U.wait(15)
  check("Egg reveal mutates and displays the newborn",
    not hatchEgg.isEgg and hatchEgg.species == "PICHU")
  check("Egg hatch reveal capture",
    U.shot(game, dir .. "/06c_egg_hatch_reveal.png"))

  -- Selection stays enabled for the caller's real save only when the player
  -- selects it in Oak Speech. This isolated identity is disposable QA state.
  U.log(("PHASE8 INGAME RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
