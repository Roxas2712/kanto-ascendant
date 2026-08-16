-- Real-LOVE visual smoke driver for the 6.5 FireRed-inspired Bag and boxes.
-- Run from the engine checkout with this mod linked as mods/kanto_ascendant.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-qol-shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local Boxes = require("src.pokemon.Boxes")
  local Screens = require("src.ui.Screens")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1; U.log("PASS", label)
    else fail = fail + 1; U.log("FAIL", label) end
  end
  local loaded = game.mods and game.mods.mods
    and game.mods.mods.kanto_ascendant
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local modOptions = game.mods.modOptions.kanto_ascendant
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = modOptions
  U.log("MODPATH", loaded and loaded.path or "missing",
    loaded and loaded.manifest and loaded.manifest.version or "missing")

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  game.save.inventory = {
    POTION = 7, ANTIDOTE = 3, POKE_BALL = 12, GREAT_BALL = 4,
    RARE_CANDY = 2, ESCAPE_ROPE = 1, BICYCLE = 1, TOWN_MAP = 1,
    X_ATTACK = 2, TM01 = 1,
  }
  game.save.bagOrder = {
    "POTION", "ANTIDOTE", "POKE_BALL", "GREAT_BALL", "RARE_CANDY",
    "ESCAPE_ROPE", "BICYCLE", "TOWN_MAP", "X_ATTACK", "TM01",
  }

  Screens.push(game, "BagMenu")
  U.wait(8)
  local bag = game.stack:top()
  check("integrated Bag uses the modern renderer",
    bag and bag.__ascendantModernBag == true)
  check("Bag keeps the five-row FireRed layout", bag and bag.rows == 5)
  check("Bag screenshot", U.shot(game, DIR .. "/bag_items.png"))
  U.tap(game, "right")
  U.wait(3)
  check("pocket navigation changes the visible pocket",
    bag and bag.title == "MEDICINE")
  check("medicine pocket screenshot",
    U.shot(game, DIR .. "/bag_medicine.png"))
  U.tap(game, "b")
  U.wait(3)

  local exports = game.mods.exports and game.mods.exports.kanto_ascendant
  local storageUi = exports and exports.modernStorageUi
  check("Player-PC item lists stay outside the Pokémon grid renderer",
    storageUi and not storageUi.isBoxList("DEPOSIT ITEM")
      and not storageUi.isBoxList("WITHDRAW ITEM")
      and storageUi.isBoxList("PARTY (DEPOSIT)"))
  local balls = exports and exports.modernBallSkins
  check("modern Ball skin renderer is enabled",
    balls and balls.enabled() == true and type(balls.draw) == "function")
  game.stack:push({
    isOpaque = true,
    draw = function()
      love.graphics.setColor(1, .97, .80, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      love.graphics.setColor(.07, .20, .40, 1)
      local Font = require("src.render.Font")
      Font.draw("MODERN BALLS", 28, 12)
      for index, ballId in ipairs({
        "POKE_BALL", "GREAT_BALL", "ULTRA_BALL",
        "MASTER_BALL", "SAFARI_BALL",
      }) do
        balls.draw(ballId, 14 + (index - 1) * 29, 52,
          (index - 1) * .45)
      end
      love.graphics.setColor(.07, .20, .40, 1)
      Font.draw("PB  GB  UB  MB  SB", 8, 76)
      Font.draw("ROLL / TOSS / SHAKE", 4, 104)
      love.graphics.setColor(1, 1, 1, 1)
    end,
  })
  U.wait(2)
  check("modern Ball skin screenshot",
    U.shot(game, DIR .. "/modern_ball_skins.png"))
  game.stack:pop()
  U.wait(2)

  local boxes = Boxes.ensure(game.save)
  game.save.currentBox = 1
  boxes[1] = {
    Pokemon.new(game.data, "PIKACHU", 18),
    Pokemon.new(game.data, "BULBASAUR", 12),
    Pokemon.new(game.data, "MAGNEMITE", 14),
    Pokemon.new(game.data, "PIDGEY", 9),
    Pokemon.new(game.data, "NIDORAN_F", 13),
    Pokemon.new(game.data, "RATTATA", 8),
    Pokemon.new(game.data, "NIDORAN_M", 11),
  }
  boxes[1][1].dvs.attack = 0
  boxes[1][2].dvs.attack = 15

  Screens.push(game, "BoxMenu")
  U.wait(8)
  check("storage main screenshot",
    U.shot(game, DIR .. "/box_main.png"))
  U.tap(game, "right")
  U.wait(2)
  check("storage root switches boxes directly with left/right",
    game.save.currentBox == 2)
  U.tap(game, "left")
  U.wait(2)
  U.tap(game, "a") -- WITHDRAW
  U.wait(8)
  local grid = game.stack:top()
  check("withdraw opens the FireRed-style grid",
    grid and grid.__ascendantBoxGrid == true)
  check("selected female Box Pokémon has a dedicated gender marker",
    storageUi and storageUi.genderSymbol(game, boxes[1][1]) == "♀")
  check("box grid screenshot", U.shot(game, DIR .. "/box_grid.png"))
  U.tap(game, "right")
  check("selected male Box Pokémon has a dedicated gender marker",
    storageUi and storageUi.genderSymbol(game, boxes[1][2]) == "♂")
  check("male Box gender screenshot",
    U.shot(game, DIR .. "/box_grid_gender_male.png"))
  U.tap(game, "right")
  check("genderless Box Pokémon leaves the marker blank",
    storageUi and storageUi.genderSymbol(game, boxes[1][3]) == nil)
  check("genderless Box row screenshot",
    U.shot(game, DIR .. "/box_grid_genderless.png"))
  grid.index = 1
  U.tap(game, "right")
  U.tap(game, "down")
  check("grid D-pad navigation uses five columns", grid and grid.index == 7)
  check("male-only Nidoran keeps its Box gender",
    storageUi and storageUi.genderSymbol(game, boxes[1][7]) == "♂")
  check("box grid selection screenshot",
    U.shot(game, DIR .. "/box_grid_selected.png"))
  U.tap(game, "b")
  U.tap(game, "b")
  U.wait(3)

  Screens.push(game, "JohtoAscendantFeatures")
  U.wait(5)
  local features = game.stack:top()
  check("ASCENDANT OPTIONS root opens",
    features and features.__ascendantFeatureRoot == true)
  check("feature tree screenshot",
    U.shot(game, DIR .. "/ascendant_features.png"))

  U.tap(game, "down") -- POKéMON SPRITES
  U.tap(game, "a")
  U.wait(3)
  local spriteOptions = game.stack:top()
  check("sprite submenu opens",
    spriteOptions
      and spriteOptions.__ascendantFeatureGroup == "sprites")
  check("sprite submenu screenshot",
    U.shot(game, DIR .. "/ascendant_sprite_options.png"))

  local oldStyle = modOptions and modOptions.pokemon_sprite_style
  U.tap(game, "right")
  local newStyle = modOptions and modOptions.pokemon_sprite_style
  check("sprite submenu writes the global style", oldStyle ~= newStyle)
  for _ = 1, 3 do
    if modOptions.pokemon_sprite_style == "crystal" then break end
    U.tap(game, "right")
  end
  check("sprite submenu selects CRYSTAL for all surface tests",
    modOptions.pokemon_sprite_style == "crystal")

  U.tap(game, "b") -- back to the root, still on POKéMON SPRITES
  U.tap(game, "up")
  U.tap(game, "a")
  U.wait(2)
  check("bag and Box options are grouped under Ascendant",
    game.stack:top()
      and game.stack:top().__ascendantFeatureGroup == "storage")
  check("bag and Box options screenshot",
    U.shot(game, DIR .. "/ascendant_storage_options.png"))
  U.tap(game, "b")

  U.tap(game, "down")
  U.tap(game, "down")
  U.tap(game, "a")
  U.wait(2)
  check("individual QoL submenu opens",
    game.stack:top()
      and game.stack:top().__ascendantFeatureGroup == "qol")
  check("individual QoL screenshot",
    U.shot(game, DIR .. "/ascendant_qol_options.png"))
  U.tap(game, "b")

  U.tap(game, "down")
  U.tap(game, "a")
  U.wait(2)
  check("configurable Quick Select submenu opens",
    game.stack:top()
      and game.stack:top().__ascendantFeatureGroup == "quick")
  check("Quick Select options screenshot",
    U.shot(game, DIR .. "/ascendant_quick_select_options.png"))
  U.tap(game, "b")

  U.tap(game, "down")
  U.tap(game, "a")
  U.wait(2)
  check("display and Ball skin submenu opens",
    game.stack:top()
      and game.stack:top().__ascendantFeatureGroup == "display")
  check("display and Ball options screenshot",
    U.shot(game, DIR .. "/ascendant_display_options.png"))
  U.tap(game, "b")

  local animation = exports and exports.crystalAnimation
  local allFronts = animation ~= nil
  for dex = 1, 251 do
    allFronts = allFronts and animation.staticAvailable[dex]
      and animation.staticShinyAvailable[dex]
  end
  check("Crystal front sprites cover all 251 Pokémon", allFronts == true)

  local backs = exports and exports.kantoCrystalBacks
  local allKantoBacks = backs ~= nil
  for dex = 1, 151 do
    allKantoBacks = allKantoBacks and backs.normal[dex] and backs.shiny[dex]
  end
  check("Crystal back sprites cover all 151 Kanto Pokémon",
    allKantoBacks == true)
  local allJohtoBacks = exports and exports.johtoData ~= nil
  for _, species in ipairs(exports and exports.johtoData.order or {}) do
    local stem = loaded.path .. "/assets/crystal/" .. species:lower()
    allJohtoBacks = allJohtoBacks
      and love.filesystem.getInfo(stem .. "_back.png", "file") ~= nil
      and love.filesystem.getInfo(stem .. "_back_shiny.png", "file") ~= nil
  end
  check("Crystal back sprites cover all 100 Johto Pokémon",
    allJohtoBacks == true)

  local Sprites = require("src.pokemon.Sprites")
  local bulba = Pokemon.new(game.data, "BULBASAUR", 12)
  for _, surface in ipairs({
    { "battle", "sprite_style_battle" },
    { "summary", "sprite_style_summary" },
    { "dex", "sprite_style_dex" },
    { "box", "sprite_style_box" },
    { "evolution", "sprite_style_scenes" },
  }) do
    local kind, option = surface[1], surface[2]
    modOptions[option] = true
    local state = animation.presentationAnimation(
      "BULBASAUR", bulba, "front", kind, { data = game.data })
    local crystal = state and state.path or Sprites.path(
      game.data, "BULBASAUR", "front", { mon = bulba, kind = kind })
    check(kind .. " surface resolves the selected Crystal sprite",
      type(crystal) == "string"
        and crystal:find("crystal_animated", 1, true) ~= nil)
    modOptions[option] = false
    local original = Sprites.path(game.data, "BULBASAUR", "front",
      { mon = bulba, kind = kind })
    check(kind .. " surface independently restores the game sprite",
      original == game.data.pokemon.BULBASAUR.spriteFront)
    modOptions[option] = true
  end

  -- The icon registry is created at boot because it changes the renderer's
  -- authored-sheet contract. A live option change therefore keeps the loaded
  -- FollowerEX sheet until restart and reports that restart explicitly.
  modOptions.party_icon_style = "classic"
  local crystalIcon = Sprites.iconPath(
    game.data, bulba, "fixture_party_icon.png")
  check("party list keeps its loaded FollowerEX icon until restart",
    type(crystalIcon) == "string"
      and crystalIcon:find("followers_kanto/follower_001.png", 1, true) ~= nil)
  check("party icon option reports its required restart",
    exports.partyIcons and exports.partyIcons.restartRequired())
  modOptions.sprite_style_summary = false
  check("party list remains a separate surface from status art",
    Sprites.iconPath(game.data, bulba, "fixture_party_icon.png")
      == crystalIcon)
  modOptions.sprite_style_summary = true
  modOptions.party_icon_style = "species"

  local bulbaBack = Sprites.path(game.data, "BULBASAUR", "back",
    { mon = bulba, kind = "battle" })
  check("Kanto battle backs use the complete Crystal pack",
    type(bulbaBack) == "string"
      and bulbaBack:find("crystal_animated/back/", 1, true) ~= nil
      and bulbaBack:find("/1/001.png", 1, true) ~= nil
      and bulbaBack ~= game.data.pokemon.BULBASAUR.spriteBack)
  local chikorita = Pokemon.new(game.data, "CHIKORITA", 12)
  local chikoritaBack = Sprites.path(game.data, "CHIKORITA", "back",
    { mon = chikorita, kind = "battle" })
  check("Johto battle backs use the complete Crystal pack",
    type(chikoritaBack) == "string"
      and chikoritaBack:find("crystal/chikorita_back", 1, true) ~= nil)
  local BattleState = require("src.battle.BattleState")
  check("Kanto Crystal 2D backs use native scale without Dramatic Shape",
    BattleState.resolveBattleScale(game.data, "back", bulbaBack,
      "BULBASAUR") == 1)
  check("Johto Crystal 2D backs use native scale without Dramatic Shape",
    BattleState.resolveBattleScale(game.data, "back", chikoritaBack,
      "CHIKORITA") == 1)

  local partyCases = {
    { "BULBASAUR", 1 }, { "PIKACHU", 25 }, { "MEW", 151 },
    { "CHIKORITA", 152 }, { "UNOWN", 201 }, { "CELEBI", 251 },
  }
  game.save.party = {}
  for _, case in ipairs(partyCases) do
    local mon = Pokemon.new(game.data, case[1], 12)
    game.save.party[#game.save.party + 1] = mon
    local icon = Sprites.iconPath(game.data, mon, "fixture_party_icon.png")
    check(("party icon #%03d resolves its bundled sheet"):format(case[2]),
      type(icon) == "string"
        and (icon:find(("followers_kanto/follower_%03d.png")
          :format(case[2]), 1, true) ~= nil
          or icon:find(("followers_runtime/normal/follower_%s.png")
            :format(case[1]), 1, true) ~= nil))
  end
  Screens.push(game, "PartyMenu")
  U.wait(4)
  check("six-member Crystal party-list screenshot",
    U.shot(game, DIR .. "/sprite_party_crystal.png"))
  -- Keep the counter inside the alternate-frame window even when the fast
  -- visual runner advances more than one driver tick before the capture.
  game.stack:top().blink = 32
  U.wait(1)
  check("selected Crystal party icon animation screenshot",
    U.shot(game, DIR .. "/sprite_party_crystal_animated.png"))
  U.tap(game, "b")
  Screens.push(game, "PartyMenu")
  U.wait(3)
  check("Crystal party list reopens cleanly",
    game.stack:top() and game.stack:top().index == 1)
  U.tap(game, "b")
  local fullParty = game.save.party
  game.save.party = { fullParty[1] }
  Screens.push(game, "PartyMenu")
  U.wait(2)
  check("one-member Crystal party list opens cleanly",
    game.stack:top() and game.stack:top().index == 1
      and #game.save.party == 1)
  U.tap(game, "b")
  game.save.party = { fullParty[1], fullParty[2], fullParty[3] }
  Screens.push(game, "PartyMenu")
  U.wait(2)
  check("three-member Crystal party list opens cleanly",
    game.stack:top() and game.stack:top().index == 1
      and #game.save.party == 3)
  U.tap(game, "b")
  game.save.party = fullParty
  Screens.push(game, "SummaryMenu", bulba)
  U.wait(4)
  check("Crystal party/status screenshot",
    U.shot(game, DIR .. "/sprite_summary_crystal.png"))
  modOptions.status_values = "full"
  U.tap(game, "a")
  U.wait(2)
  U.tap(game, "a")
  U.wait(3)
  local insight = game.stack:top()
  check("optional DV/IV and EV page is reachable",
    insight and insight.page == 3)
  check("DV/IV and EV status screenshot",
    U.shot(game, DIR .. "/status_values_full.png"))
  U.tap(game, "b")
  Screens.push(game, "DexEntryMenu", "BULBASAUR")
  U.wait(4)
  check("Crystal Pokédex screenshot",
    U.shot(game, DIR .. "/sprite_dex_crystal.png"))
  U.tap(game, "b")
  U.tap(game, "b")
  U.tap(game, "b")

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
  assert(fail == 0, ("visual QoL E2E failed: %d checks"):format(fail))
end
