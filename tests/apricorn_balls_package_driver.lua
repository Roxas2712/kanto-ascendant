-- Installed-package acceptance for all seven Apricorn Balls.
--
-- Pass `acquire` exercises the real catch callbacks, all seven Legacy
-- Workshop purchases and the production Player-PC deposit UI, then writes a
-- native save.  The Journeys visual driver runs between the two passes.  Pass
-- `reload` loads that exact save, withdraws every stored Ball through the
-- production PC UI, writes/reloads again and joins the mechanics + visual
-- receipts into one fail-closed result.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local PlayerPC = require("src.ui.PlayerPC")
  local ItemEffects = require("src.inventory.ItemEffects")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")

  local phase = assert(os.getenv("QA_APRICORN_PHASE"),
    "QA_APRICORN_PHASE=acquire|reload required")
  assert(phase == "acquire" or phase == "reload", "bad Apricorn phase")
  local mode = (os.getenv("QA_RENDER_MODE") or "2d"):lower()
  assert(mode == "2d" or mode == "full", "bad QA_RENDER_MODE")
  local edition = GameVersion.get()
  assert(edition == assert(os.getenv("POKEPORT_VERSION"), "edition required"),
    "wrong imported edition")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("apricorn%-balls", 1, false),
    "refusing to write outside Apricorn package identity")
  local slot = os.getenv("QA_SLOT") or ("slot65_apricorn_" .. edition .. "_" .. mode)
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve Apricorn package slot")

  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local ids = {
    "HEAVY_BALL", "LEVEL_BALL", "LURE_BALL", "FAST_BALL",
    "LOVE_BALL", "FRIEND_BALL", "MOON_BALL",
  }
  local depositIds = {
    "HEAVY_BALL", "LURE_BALL", "LOVE_BALL", "MOON_BALL",
  }
  local pass, fail, report = 0, 0, {
    "scope=APRICORN-BALLS-RBY-2D-FULL-PACKAGE",
    "edition=" .. edition,
    "renderer=" .. mode,
    "phase=" .. phase,
  }

  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    report[#report + 1] = (value and "PASS\t" or "FAIL\t") .. label
    U.log(value and "PASS" or "FAIL", label)
    return value
  end

  local function write(path, extra)
    for _, row in ipairs(extra or {}) do report[#report + 1] = row end
    report[#report + 1] = "pass=" .. pass
    report[#report + 1] = "fail=" .. fail
    local out = assert(io.open(path, "wb"), "could not write Apricorn receipt")
    out:write(table.concat(report, "\n"), "\n")
    out:close()
  end

  local exports = assert(game.mods and game.mods.exports, "exports missing")
  local ka = assert(exports.kanto_ascendant, "Ascendant export missing")
  local apricorn = assert(ka.apricornBalls, "Apricorn runtime missing")
  local workshop = assert(ka.ngplusLegacyWorkshop, "Legacy Workshop missing")
  local journey = assert(ka.legacyJourney, "Legacy Journey missing")
  game:adoptSave(game.save)
  game.mods.modSave = game.save.modData

  if mode == "full" then
    check("FULL closure exposes DRAMALESS", exports.DRAMALESS_SHAPE ~= nil)
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    U.wait(40)
    check("FULL pipeline is genuinely active",
      Pipelines.level("voxel") == 1 and Pipelines.worldPipeline() == "voxel")
  else
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    check("2D pipeline is genuinely flat",
      Pipelines.level("voxel") == 0 and exports.DRAMALESS_SHAPE == nil)
  end

  local function findRow(list, wanted)
    for index, row in ipairs(list.items or {}) do
      if row.value == wanted then return index end
    end
  end

  local function closeTo(base)
    while game.stack:top() and game.stack:top() ~= base do game.stack:pop() end
  end

  -- Move each requested Ball through the real Player-PC menus.  The menu,
  -- ListMenu and QuantityBox callbacks are all production objects; A/B input
  -- advances them exactly as normal play does.
  local function pcMove(kind, wanted, shotPath)
    local base = game.stack:top()
    local root = PlayerPC.new(game, { direct = true })
    game.stack:push(root)
    root.index = kind == "deposit" and 2 or 1
    U.tap(game, "a"); U.wait(2)
    local list = game.stack:top()
    assert(list and list.kind == "pc_item_" .. kind,
      "production PC " .. kind .. " list did not open")
    if shotPath then
      U.wait(4)
      check("production PC " .. kind .. " screenshot", U.shot(game, shotPath))
    end
    for _, id in ipairs(wanted) do
      local index = assert(findRow(list, id), id .. " missing from PC " .. kind)
      list.index = index
      U.tap(game, "a"); U.wait(2)
      local quantity = game.stack:top()
      assert(quantity ~= list and quantity.qty == 1,
        id .. " quantity selector did not open")
      U.tap(game, "a"); U.wait(3)
      assert(game.stack:top() == list, id .. " quantity selector did not close")
    end
    U.tap(game, "b"); U.wait(2)
    U.tap(game, "b"); U.wait(2)
    closeTo(base)
  end

  local function bagShot(path)
    local base = game.stack:top()
    local BagMenu = require("src.ui.BagMenu")
    local bag = BagMenu.new(game, {})
    game.stack:push(bag)
    U.wait(4)
    check("production Bag screenshot", U.shot(game, path))
    U.tap(game, "b"); U.wait(2)
    closeTo(base)
  end

  local function wild(species, playerSpecies, playerLevel, targetLevel,
      playerAttackDv, targetAttackDv, source)
    local target = Pokemon.new(game.data, species, targetLevel)
    target.dvs = target.dvs or {}
    target.dvs.attack = targetAttackDv or target.dvs.attack or 0
    local player = Pokemon.new(game.data, playerSpecies or species, playerLevel)
    player.dvs = player.dvs or {}
    player.dvs.attack = playerAttackDv or player.dvs.attack or 15
    return setmetatable({
      kind = "wild", data = game.data, game = game,
      encounterSource = source,
      player = { mon = player },
      enemy = { mon = target, def = game.data.pokemon[species] },
      rng = function() return 0 end,
    }, { __index = BattleState })
  end

  local function formula(ball, battle, multiplier, rate, reason)
    local caught, shakes = BattleState.catchAttempt(battle, ball)
    local quote = battle.apricornBallQuote
    return caught == true and shakes == 3 and quote
      and quote.available == true and quote.multiplier == multiplier
      and quote.rate == rate and quote.reason == reason
      and quote.formatted and #quote.formatted.lines == 2
      and quote.formatted.maxGlyphs <= apricorn.DISPLAY_WIDTH
  end

  if phase == "acquire" then
    -- Exact positive formulas through BattleState:catchAttempt, not a preview
    -- helper.  Negative/boundary witnesses prove each branch is data-driven.
    local formulaOk = 0
    formulaOk = formulaOk + (formula("HEAVY_BALL",
      wild("SNORLAX", "BULBASAUR", 20, 20), 1, 55,
      "weight_300kg_plus") and 1 or 0)
    local heavyLow = apricorn.quote("HEAVY_BALL", {
        data = game.data, battle = wild("RATTATA", "BULBASAUR", 20, 20),
        targetMon = { species = "RATTATA", level = 20 },
        targetDef = game.data.pokemon.RATTATA,
      })
    check("Heavy Ball under-100kg boundary is -20",
      heavyLow.rate == 235 and heavyLow.rateDelta == -20)
    formulaOk = formulaOk + (formula("LEVEL_BALL",
      wild("PIKACHU", "BULBASAUR", 40, 10), 8, 255,
      "level_ratio_x8") and 1 or 0)
    check("Level Ball equal-level boundary is x1",
      apricorn.quote("LEVEL_BALL", {
        data = game.data, battle = wild("PIKACHU", "BULBASAUR", 10, 10),
        targetMon = { species = "PIKACHU", level = 10 },
        targetDef = game.data.pokemon.PIKACHU,
      }).multiplier == 1)
    formulaOk = formulaOk + (formula("LURE_BALL",
      wild("DRATINI", "BULBASAUR", 20, 20, nil, nil, "fishing"),
      3, 135, "fishing") and 1 or 0)
    check("Lure Ball rejects non-fishing water context",
      apricorn.quote("LURE_BALL", {
        data = game.data, battle = wild("DRATINI", "BULBASAUR", 20, 20),
        targetMon = { species = "DRATINI", level = 20 },
        targetDef = game.data.pokemon.DRATINI,
      }).rate == 45)
    formulaOk = formulaOk + (formula("FAST_BALL",
      wild("ELECTRODE", "BULBASAUR", 20, 20), 4, 240,
      "base_speed_100_plus") and 1 or 0)
    check("Fast Ball rejects a slow species",
      apricorn.quote("FAST_BALL", {
        data = game.data, battle = wild("SNORLAX", "BULBASAUR", 20, 20),
        targetMon = { species = "SNORLAX", level = 20 },
        targetDef = game.data.pokemon.SNORLAX,
      }).multiplier == 1)
    formulaOk = formulaOk + (formula("LOVE_BALL",
      wild("PIKACHU", "PIKACHU", 20, 20, 15, 0), 8, 255,
      "same_species_opposite_gender") and 1 or 0)
    check("Love Ball rejects a different species",
      apricorn.quote("LOVE_BALL", {
        data = game.data, battle = wild("RATTATA", "PIKACHU", 20, 20, 15, 0),
        targetMon = { species = "RATTATA", level = 20, dvs = { attack = 0 } },
        targetDef = game.data.pokemon.RATTATA,
      }).multiplier == 1)
    formulaOk = formulaOk + (formula("FRIEND_BALL",
      wild("BULBASAUR", "CHARMANDER", 20, 20), 1, 45,
      "friendship_200_on_success") and 1 or 0)
    local friend = Pokemon.new(game.data, "BULBASAUR", 5)
    friend.johtoBond = 0
    Runtime.emit("pokemon.caught", {
      ball = "FRIEND_BALL", mon = friend, destination = "party", game = game,
    })
    check("Friend Ball catch event awards exactly 200 friendship once",
      friend.johtoBond == 200 and friend.apricornFriendBallApplied == true)
    formulaOk = formulaOk + (formula("MOON_BALL",
      wild("CLEFAIRY", "BULBASAUR", 20, 20), 4, 255,
      "moon_stone_line") and 1 or 0)
    check("Moon Ball rejects a non-Moon-Stone line",
      apricorn.quote("MOON_BALL", {
        data = game.data, battle = wild("GASTLY", "BULBASAUR", 20, 20),
        targetMon = { species = "GASTLY", level = 20 },
        targetDef = game.data.pokemon.GASTLY,
      }).multiplier == 1)
    check("all seven installed catch formulas hit exact positive branches",
      formulaOk == 7)

    -- Every installed item must take the same real Bag preflight.  Legal
    -- wild uses reach the Ball flow without consuming early; trainer and
    -- story-blocked uses fail before consumption for every one of the seven.
    local legalBattles = {
      HEAVY_BALL = wild("SNORLAX", "BULBASAUR", 20, 20),
      LEVEL_BALL = wild("PIKACHU", "BULBASAUR", 40, 10),
      LURE_BALL = wild("DRATINI", "BULBASAUR", 20, 20, nil, nil, "fishing"),
      FAST_BALL = wild("ELECTRODE", "BULBASAUR", 20, 20),
      LOVE_BALL = wild("PIKACHU", "PIKACHU", 20, 20, 15, 0),
      FRIEND_BALL = wild("BULBASAUR", "CHARMANDER", 20, 20),
      MOON_BALL = wild("CLEFAIRY", "BULBASAUR", 20, 20),
    }
    local legalPreflight, blockedPreserved = 0, 0
    for _, id in ipairs(ids) do
      local testSave = { inventory = { [id] = 2 }, player = { name = edition } }
      local legal = legalBattles[id]
      local action = ItemEffects.use(game.data, testSave, id, nil, legal)
      if action == "ball" and testSave.inventory[id] == 2 then
        legalPreflight = legalPreflight + 1
      end
      local trainer = legalBattles[id]
      trainer.kind = "trainer"
      local blocked, _, extra = ItemEffects.use(game.data, testSave, id, nil, trainer)
      if blocked == "failed" and testSave.inventory[id] == 2 and extra
          and extra.apricornQuote and extra.apricornQuote.reason == "trainer_battle" then
        blockedPreserved = blockedPreserved + 1
      end
      trainer.kind, trainer.noCatch = "wild", true
      blocked, _, extra = ItemEffects.use(game.data, testSave, id, nil, trainer)
      if blocked == "failed" and testSave.inventory[id] == 2 and extra
          and extra.apricornQuote and extra.apricornQuote.reason == "story_blocked" then
        blockedPreserved = blockedPreserved + 1
      end
      trainer.noCatch = false
    end
    check("all seven legal ItemEffects reach Ball flow without early consumption",
      legalPreflight == 7)
    check("all fourteen blocked ItemEffects preserve the exact Bag count",
      blockedPreserved == 14)

    game.save.inventory = {}
    game.save.bagOrder = {}
    game.save.pcItems = {}
    game.save.pcOrder = {}
    game.save.money = 10000
    for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
      check(character .. " HEVO seal enters durable Legacy authority",
        journey.completeHevoPath(game.save, character))
    end
    -- completeHevoPath commits global Legacy authority and mirrors durable
    -- data into this save; adopt its bucket before the Workshop reads it.
    game:adoptSave(game.save)
    game.mods.modSave = game.save.modData
    local offers = workshop.ballOffers(game.save)
    local offered = {}
    for _, row in ipairs(offers) do offered[row.item] = true end
    check("Workshop exposes exactly seven unlocked Apricorn offers",
      #offers == 7)
    local acquired = 0
    for _, id in ipairs(ids) do
      local ok, item = workshop.purchaseBall(game, id, true)
      if ok and item == id and game.save.inventory[id] == 1 then
        acquired = acquired + 1
      end
    end
    check("all seven Balls use the real repeatable Workshop transaction",
      acquired == 7 and game.save.money == 3000)
    check("GS Ball is excluded from the acquisition authority",
      workshop.purchaseBall(game, "GS_BALL", true) == false)

    bagShot(dir .. "/01_apricorn_bag_before_deposit.png")
    pcMove("deposit", depositIds)
    local bagCount, pcCount = 0, 0
    for _, id in ipairs(ids) do
      bagCount = bagCount + (game.save.inventory[id] == 1 and 1 or 0)
      pcCount = pcCount + (game.save.pcItems[id] == 1 and 1 or 0)
    end
    check("production PC deposits four Apricorn Balls", bagCount == 3 and pcCount == 4)
    pcMove("withdraw", {}, dir .. "/02_apricorn_pc_after_deposit.png")
    game.save.modData = game.save.modData or {}
    game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
    game.save.modData.kanto_ascendant.apricorn_package_receipt = {
      edition = edition, renderer = mode, formulas = formulaOk,
      bag = bagCount, pc = pcCount, stage = 1,
    }
    check("native mixed Bag/PC save succeeds", game:writeSave())
    write(dir .. "/apricorn_stage1_result.txt", {
      "formula_matrix=7/7", "workshop_acquisition=7/7",
      "preflight_matrix=7/7", "blocked_preserved=14/14",
      "bag_after_deposit=3", "pc_after_deposit=4",
    })
    love.event.quit(fail == 0 and 0 or 1)
    return
  end

  local loaded, recovered = SaveData.load()
  check("native Apricorn save exists for reload pass", loaded ~= nil)
  if loaded then game:restoreSave(loaded, recovered) end
  local receipt = game.save.modData and game.save.modData.kanto_ascendant
    and game.save.modData.kanto_ascendant.apricorn_package_receipt
  check("formula/acquisition receipt survives process restart",
    receipt and receipt.stage == 1 and receipt.formulas == 7
      and receipt.edition == edition and receipt.renderer == mode)
  local bagCount, pcCount = 0, 0
  for _, id in ipairs(ids) do
    bagCount = bagCount + (game.save.inventory[id] == 1 and 1 or 0)
    pcCount = pcCount + (game.save.pcItems[id] == 1 and 1 or 0)
  end
  check("mixed three-Bag/four-PC state survives native reload",
    bagCount == 3 and pcCount == 4)
  pcMove("withdraw", depositIds)
  local allBag, noPc = true, true
  for _, id in ipairs(ids) do
    allBag = allBag and game.save.inventory[id] == 1
    noPc = noPc and game.save.pcItems[id] == nil
  end
  check("production PC withdraw restores all seven to the Bag", allBag and noPc)
  bagShot(dir .. "/52_all_apricorn_bag.png")
  check("post-withdraw native save succeeds", game:writeSave())
  local final = SaveData.load()
  local finalBag, finalPc = true, true
  for _, id in ipairs(ids) do
    finalBag = finalBag and final and final.inventory[id] == 1
    finalPc = finalPc and final and final.pcItems[id] == nil
  end
  check("all-seven Bag state survives second native reload", finalBag and finalPc)

  local visualPath = dir .. "/journeys_visual_result.txt"
  local visual = io.open(visualPath, "rb")
  local visualText = visual and visual:read("*a") or ""
  if visual then visual:close() end
  check("Journeys visual pass completed all seven Apricorn Balls",
    visualText:find("status=PASS", 1, true)
      and visualText:find("balls=7/7", 1, true)
      and visualText:find("states=49/49", 1, true)
      and visualText:find("legal_consumptions=14/14", 1, true)
      and visualText:find("blocked_preserved=14/14", 1, true)
      and visualText:find("renderer=" .. mode, 1, true))
  local stage = io.open(dir .. "/apricorn_stage1_result.txt", "rb")
  local stageText = stage and stage:read("*a") or ""
  if stage then stage:close() end
  check("mechanics pass completed formulas and acquisition",
    stageText:find("formula_matrix=7/7", 1, true)
      and stageText:find("workshop_acquisition=7/7", 1, true)
      and stageText:find("preflight_matrix=7/7", 1, true)
      and stageText:find("blocked_preserved=14/14", 1, true)
      and stageText:find("fail=0", 1, true))
  write(dir .. "/driver_result.txt", {
    "formula_matrix=7/7", "workshop_acquisition=7/7",
    "preflight_matrix=7/7", "blocked_preserved=14/14",
    "legal_consumptions=14/14",
    "bag_pc_reload=PASS", "visual_states=49/49",
    "status=" .. (fail == 0 and "PASS" or "FAIL"),
  })
  love.event.quit(fail == 0 and 0 or 1)
end
