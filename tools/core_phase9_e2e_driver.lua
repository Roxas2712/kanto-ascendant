-- Real-LÖVE Phase-9 acceptance across imported Red, Blue and Yellow data.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local version = assert(os.getenv("POKEPORT_VERSION"))
  assert(GameVersion.get() == version, "wrong imported edition")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "QA identity required")
  assert(identity:find("core%-phase9"),
    "refusing to run outside a dedicated core-phase9 QA identity")
  U.wait(5)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 50) }
  local api = assert(game.mods.exports.kanto_ascendant,
    "Kanto Ascendant exports missing")
  local expectedPath = os.getenv("POKEPORT_EXPECT_MOD_PATH")
  if expectedPath then
    assert(game.mods.mods.kanto_ascendant.path == expectedPath,
      "wrong candidate path: " .. tostring(game.mods.mods.kanto_ascendant.path))
  end
  assert(api.difficulty and api.bicycleSelect and api.itemProtection
      and api.visionEncounters, "Phase-9 exports incomplete")
  assert(not api.ascendant.rankLine(20):find("★", 1, true),
    "trainer rank line contains an unsupported Gen-I font glyph")

  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.difficulty = "extreme"
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.difficulty = "extreme"
  local level, overflow = api.difficulty.adjustLevel(98, "trainer")
  assert(level == 100 and overflow == 8, "Level-100 overflow contract failed")
  assert(not api.difficulty.itemsAllowed({ kind = "trainer" })
      and api.difficulty.itemsAllowed({ kind = "wild" }),
    "Extreme item/ball policy failed")
  local party = Runtime.call("trainer.party", function(_, _, rows) return rows end,
    "OPP_YOUNGSTER", 1, { { species = "RATTATA", level = 95 } })
  assert(party[1].level == 100, "real trainer hook did not clamp Extreme")

  game.save.inventory.BICYCLE = 1
  local function dismissBikeText()
    assert(game.stack:top() ~= game.overworld,
      "bicycle shortcut did not provide feedback")
    game.stack:pop()
  end
  game:keypressed("tab")
  U.wait(1)
  game:keyreleased("tab")
  assert(game.save.onBike == true,
    "default keyboard SELECT could not mount in Pallet Town")
  dismissBikeText()
  game:gamepadpressed(nil, "back")
  U.wait(1)
  game:gamepadreleased(nil, "back")
  assert(game.save.onBike == false,
    "default controller SELECT could not dismount")
  dismissBikeText()
  game.input:applyBindings({ select = { key = "q", pad = "x" } })
  game:keypressed("q")
  U.wait(1)
  game:keyreleased("q")
  assert(game.save.onBike == true,
    "remapped keyboard SELECT could not mount")
  dismissBikeText()
  game:gamepadpressed(nil, "x")
  U.wait(1)
  game:gamepadreleased(nil, "x")
  assert(game.save.onBike == false,
    "remapped controller SELECT could not dismount")
  dismissBikeText()
  game.input:applyBindings(game.save.options.bindings)

  assert(api.itemProtection.isProtected("MASTER_BALL"),
    "Master Ball protection missing")
  local Bag = require("src.inventory.Bag")
  local BagMenu = require("src.ui.BagMenu")
  local ListMenu = require("src.ui.ListMenu")
  assert(Bag.add(game.save, "MASTER_BALL", 1, game.data),
    "could not seed protected item")
  local function dismissProtected(label, callbackRan)
    local choice = game.stack:top()
    assert(choice and choice.index == 2 and not callbackRan(),
      label .. " must be intercepted with default NO")
    game.stack:pop(); game.stack:pop()
  end
  local function protectedBag(label, bagOpts)
    local list = BagMenu.new(game, bagOpts)
    local row
    for _, item in ipairs(list.items) do
      if item.value == "MASTER_BALL" then row = item break end
    end
    assert(row, label .. " did not expose the Master Ball")
    local before = game.save.inventory.MASTER_BALL
    list.onChoose(row, list)
    dismissProtected(label, function()
      return game.save.inventory.MASTER_BALL ~= before
    end)
  end
  protectedBag("field use", {})
  protectedBag("battle throw", { battle = { kind = "wild" } })
  local function protectedList(title)
    local ran = false
    local row = { label = "MASTER BALL", value = "MASTER_BALL" }
    local list = ListMenu.new(game, title, { row }, {
      onChoose = function() ran = true end,
    })
    list.onChoose(row, list)
    dismissProtected(title, function() return ran end)
  end
  protectedList("TOSS ITEM")
  protectedList("SELL")
  local ordinaryRan = false
  local ordinary = { label = "POKE BALL", value = "POKE_BALL" }
  local ordinaryList = ListMenu.new(game, "SELL", { ordinary }, {
    onChoose = function() ordinaryRan = true end,
  })
  ordinaryList.onChoose(ordinary, ordinaryList)
  assert(ordinaryRan, "ordinary item was slowed by rare-item protection")
  assert(api.visionEncounters.DEFS[1].species == "HO_OH"
      and api.visionEncounters.DEFS[2].species == "LUGIA",
    "vision registry incomplete")
  local grotto = assert(game.data.maps.KANTO_ASCENDANT_PRISM_GROTTO,
    "Prism Grotto missing")
  local visibleExit
  for _, object in ipairs(grotto.objects or {}) do
    if object.name == "PRISM_EXIT_ARCH" then visibleExit = object end
  end
  assert(visibleExit and visibleExit.x == 7 and visibleExit.y == 13,
    "Prism return is not visible")

  local startRows = Runtime.call("ui.start_menu.items",
    function(_, rows) return rows end, game, {})
  local gateway
  for _, row in ipairs(startRows) do if row.label == "ASCENDANT" then gateway = row end end
  assert(gateway and gateway.onSelect, "ASCENDANT gateway missing")
  gateway.onSelect()
  local asc = game.stack:top()
  local options
  for _, row in ipairs(asc.items or {}) do
    if row.ascendantKey == "options" then options = row end
  end
  assert(options, "central OPTIONS entry missing")
  asc.onChoose(options, asc)
  local root = game.stack:top()
  assert(#root.items == 5, "central options must have five clean categories")
  root.onChoose(root.items[1], root)
  local gameplay = game.stack:top()
  local foundDifficulty, found151
  for _, row in ipairs(gameplay.items or {}) do
    if row.value == "difficulty" then foundDifficulty = true end
    if row.value == "kanto_151" then found151 = true end
  end
  assert(foundDifficulty and found151,
    "Difficulty/Kanto151 absent from central GAMEPLAY")

  assert(api.gorochu and api.gorochu.dex == 1026,
    "Gorochu guest Dex registration missing")
  local beforeHP = game.save.party[1].hp
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
  game.save.modData.kanto_ascendant.vision_encounters = {}
  for _, def in ipairs(api.visionEncounters.DEFS) do
    assert(api.visionEncounters.start(game, def),
      "real " .. def.species .. " vision did not start")
    local vision = assert(api.visionEncounters.active)
    assert(vision.noCatch and not vision.demo
        and vision.ascendantVision == def.key,
      "vision must be uncatchable without Old-Man demo rendering")
    assert(Runtime.call("battle.exp_award", function() return 777 end,
        { battle = vision }) == nil,
      "vision leaked a normal EXP award")
    game.save.party[1].hp = 1
    vision.onFinish("run")
    assert(game.save.party[1].hp == beforeHP,
      def.species .. " vision did not restore the complete party snapshot")
    game.stack:pop() -- discard the not-yet-entered transition in this probe
    assert(not api.visionEncounters.start(game, def),
      def.species .. " once-per-save flag did not latch")
  end
  assert(Runtime.call("battle.exp_award", function() return 777 end,
      { battle = {} }) == 777,
    "normal EXP remained suppressed after a vision")
  local normal = Runtime.call("encounter.species", function(enc) return enc end,
    { species = "RATTATA", level = 3 }, {})
  assert(normal and normal.species == "RATTATA",
    "normal encounter state did not resume after visions")
  U.log("PHASE 9 REAL E2E PASS", version,
    "difficulty cap input matrix item actions options Kanto151 prism two visions Gorochu")
  love.event.quit(0)
end
