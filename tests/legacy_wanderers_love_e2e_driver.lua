-- Real Authority-main/LÖVE acceptance for the Legacy NG+ surprise trainer.
--
-- The driver owns a disposable SaveData slot and stages only the conditions
-- that would otherwise require hundreds of steps: an active Legacy run and
-- a NORMAL cycle at step 199 with its map target met. The final physical
-- Route 1 step, dynamic NPC spawn,
-- HALT/title dialogue, approach, trainer battle, EXP hook, battle-ended
-- transaction, Bag reward, native save write and native reload are all the
-- production lifecycle.
--
-- Run 2D first with only Kanto Ascendant.  After it passes, run FULL with a
-- dependency-closure QA mod that loads Kanto Ascendant + DRAMALESS_SHAPE:
--
--   POKEPORT_ONLY_MOD=kanto_ascendant QA_RENDER_MODE=2d ... love .
--   POKEPORT_ONLY_MOD=qa008_dramaless_runner QA_RENDER_MODE=full ... love .

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local Experience = require("src.battle.Experience")
  local Bag = require("src.inventory.Bag")
  local TextBox = require("src.render.TextBox")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local mode = (os.getenv("QA_RENDER_MODE") or "2d"):lower()
  assert(mode == "2d" or mode == "full",
    "QA_RENDER_MODE must be 2d or full")

  local exports = assert(game.mods and game.mods.exports,
    "live mod exports are unavailable")
  local api = assert(exports.kanto_ascendant,
    "Kanto Ascendant did not load")
  local wanderers = assert(api.legacyWanderers,
    "Legacy Wanderers export did not load")
  local journey = assert(api.legacyJourney,
    "Legacy Journey export did not load")
  local hall = assert(api.legacyHall, "Legacy Hall export did not load")
  local ascendant = assert(api.ascendant, "Ascendant export did not load")
  local pass, fail = 0, 0
  local report = {
    "scope=LEGACY-WANDERERS-CORE",
    "authority=Authority-main/LÖVE",
    "renderer=" .. mode,
  }

  local function line(key, value)
    report[#report + 1] = tostring(key) .. "=" .. tostring(value)
  end

  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    report[#report + 1] = (value and "PASS\t" or "FAIL\t") .. label
    return value
  end

  local function finish(code)
    line("pass", pass)
    line("fail", fail)
    local output = assert(io.open(dir .. "/driver_result.txt", "wb"),
      "could not write driver_result.txt")
    output:write(table.concat(report, "\n"), "\n")
    output:close()
    U.log(("LEGACY WANDERERS LOVE RESULT renderer=%s pass=%d fail=%d")
      :format(mode, pass, fail))
    love.event.quit(code or (fail == 0 and 0 or 1))
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end

  local function isText(value)
    return value and getmetatable(value) == TextBox
  end

  local function waitForPage(box, page, frames)
    return waitFor(function()
      if game.stack:top() == box and box.pageIndex == page
          and (box.waiting or box.done) then return true end
      return nil
    end, frames or 600) == true
  end

  local function boxText(box)
    local out = {}
    for _, page in ipairs(box and box.pages or {}) do
      for _, row in ipairs(page or {}) do out[#out + 1] = row end
    end
    return table.concat(out, "\n")
  end

  local function contains(list, value)
    for _, candidate in ipairs(list or {}) do
      if candidate == value then return true end
    end
    return false
  end

  local function inventoryCount(item)
    return math.max(0, math.floor(tonumber(
      game.save.inventory and game.save.inventory[item]) or 0))
  end

  local function copyFlat(source)
    local out = {}
    for key, value in pairs(source or {}) do out[key] = value end
    return out
  end

  local function copyList(source)
    local out = {}
    for index, value in ipairs(source or {}) do out[index] = value end
    return out
  end

  local function sameFlat(left, right)
    for key, value in pairs(left or {}) do
      if right == nil or right[key] ~= value then return false end
    end
    for key, value in pairs(right or {}) do
      if left == nil or left[key] ~= value then return false end
    end
    return true
  end

  local function sameList(left, right)
    if #(left or {}) ~= #(right or {}) then return false end
    for index, value in ipairs(left or {}) do
      if right[index] ~= value then return false end
    end
    return true
  end

  local function rosterString(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
      out[#out + 1] = tostring(row.species) .. ":" .. tostring(row.level)
    end
    return table.concat(out, ",")
  end

  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  assert(identity:find("legacy%-wanderer", 1, false),
    "refusing to write outside a Legacy Wanderer QA identity")
  local edition = GameVersion.get()
  local expectedEdition = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION is required")
  assert(edition == expectedEdition,
    "wrong imported edition for Legacy Wanderer package proof")
  line("edition", edition)
  local slot = os.getenv("QA_SLOT")
    or ("slot65legacywanderer_" .. edition .. "_" .. mode)
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve the isolated Legacy Wanderer slot")

  local fresh = SaveData.newGame(game:bootConfig())
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { save = fresh })
  game.save.flags = game.save.flags or {}
  -- An active Legacy Journey is post-Hall-of-Fame by construction.  Stage
  -- the same public postgame receipts a lawful archived journey owns so the
  -- late Wanderer below exercises the real opponent-Mega listener instead
  -- of a pre-HOF negative.
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.hallOfFame = {
    { player = "RED", rival = "BLUE", source = "legacy_journey" },
  }
  game.save.inventory = game.save.inventory or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant =
    game.save.modData.kanto_ascendant or {}
  game.mods.modSave = game.save.modData
  local bucket = game.save.modData.kanto_ascendant
  bucket.legacy_journey = {
    version = 6,
    cycle = 2,
    runId = "legacy-wanderer-runtime-" .. mode,
    bankUnlocked = true,
    wanderersEnabled = true,
    pact = "journey",
    avatar = "RED",
    avatarQuestStage = 1,
    pathComplete = false,
    completedPaths = { red = false, blue = false, green = false },
  }
  bucket.onboarding = { version = 1, shown = true }
  bucket.legacy_wanderers = nil
  bucket.legacy_hall = { version = 1, visits = 0 }
  bucket.ascendant = bucket.ascendant or {}
  bucket.ascendant.achievements = bucket.ascendant.achievements or {}
  game.save.player.name = "RED"
  game.save.player.rival = "BLUE"
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.legacy_wanderer_frequency =
    "normal"
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.legacy_wanderer_frequency = "normal"
  game.save.repelSteps = 9999

  local hero = Pokemon.new(game.data, "MEWTWO", 50,
    function(_, high) return high end)
  hero.moves = {
    { id = "PSYCHIC_M", pp = assert(game.data.moves.PSYCHIC_M).pp },
  }
  game.save.party = { hero }
  game:adoptSave(game.save)
  game.mods.modSave = game.save.modData

  check("fresh disposable save is an active Legacy NG+ run only",
    journey.isActive(game.save) and wanderers.legacyRunEnabled(game)
      and journey.state(game.save).cycle == 2
      and journey.state(game.save).runId == bucket.legacy_journey.runId)

  -- Authority audit: these are the real items/moves/species loaded into the
  -- current engine process, not the narrow fixture used by unit tests.
  local registeredTMs = wanderers.registeredTMs(game)
  local tmIds, generations = {}, {}
  for _, row in ipairs(registeredTMs) do
    tmIds[#tmIds + 1] = row.item
    generations[row.generation] = true
  end
  line("registered_tm_count", #registeredTMs)
  line("registered_tm_ids", table.concat(tmIds, ","))
  U.log(("AUTHORITY REGISTERED TMS count=%d ids=%s")
    :format(#registeredTMs, table.concat(tmIds, ",")))
  if not check("Authority exposes at least one real compatible Gen2/Gen3 TM",
      #registeredTMs > 0) then
    line("blocker", "registeredTMs(game) returned 0")
    finish(1)
    return
  end
  local tmRowsValid = true
  for _, row in ipairs(registeredTMs) do
    local item = game.data.items[row.item]
    local machine = item and item.machine
    if not (machine and machine.kind == "TM"
        and machine.move == row.move and game.data.moves[row.move]
        and (row.generation == 2 or row.generation == 3)) then
      tmRowsValid = false
      break
    end
  end
  check("every Authority TM row resolves to a live Gen2/Gen3 TM item/move",
    tmRowsValid and (generations[2] or generations[3]))

  -- One installed-package run must enumerate the whole deterministic
  -- economy, not infer it from the single LOVE BALL chosen for the visual
  -- battle below.  These are the public controller functions used by the
  -- actual encounter transaction.
  local rewardRows = wanderers.rewardPool(game)
  local ballRows, tmRows = {}, {}
  local ballQuantities = {}
  for _, row in ipairs(rewardRows) do
    if row.kind == "ball" then
      ballRows[row.item] = true
      ballQuantities[row.item] = ballQuantities[row.item] or {}
      ballQuantities[row.item][row.qty] = true
    elseif row.kind == "tm" then
      tmRows[row.item] = true
    end
  end
  local everyApricorn = true
  for _, id in ipairs(wanderers.APRICORN_BALLS) do
    everyApricorn = everyApricorn and ballRows[id] == true
  end
  check("installed reward pool owns all seven Apricorn Balls",
    everyApricorn)
  check("installed reward pool exposes every registered Gen2/3 TM",
    #registeredTMs >= 20 and #registeredTMs == (function()
      local count = 0
      for _ in pairs(tmRows) do count = count + 1 end
      return count
    end)())
  check("installed Ball stacks expose the authored Poke/Great/Ultra bands",
    ballQuantities.POKE_BALL and ballQuantities.POKE_BALL[3]
      and ballQuantities.POKE_BALL[5] and ballQuantities.POKE_BALL[8]
      and ballQuantities.GREAT_BALL and ballQuantities.GREAT_BALL[2]
      and ballQuantities.GREAT_BALL[3] and ballQuantities.GREAT_BALL[5]
      and ballQuantities.ULTRA_BALL and ballQuantities.ULTRA_BALL[1]
      and ballQuantities.ULTRA_BALL[2]
      and ballQuantities.ULTRA_BALL[3])

  local livePool = wanderers.liveTrainerPool(game)
  local exactClasses, fallbackClasses = {}, {}
  local noFeatureBosses = true
  for _, row in ipairs(livePool) do
    local target = row.fieldSpriteExact and exactClasses or fallbackClasses
    target[#target + 1] = row.class
    if row.class:find("^KA_") then noFeatureBosses = false end
  end
  line("live_trainer_pool_count", #livePool)
  line("live_trainer_exact_count", #exactClasses)
  line("live_trainer_exact_ids", table.concat(exactClasses, ","))
  line("live_trainer_fallback_count", #fallbackClasses)
  line("live_trainer_fallback_ids", table.concat(fallbackClasses, ","))
  U.log(("AUTHORITY TRAINER POOL total=%d exact=%d fallback=%d")
    :format(#livePool, #exactClasses, #fallbackClasses))
  check("Authority trainer pool reports exact and honest fallback sprites",
    #livePool == #exactClasses + #fallbackClasses
      and #exactClasses > 0 and #fallbackClasses > 0)
  check("Authority ordinary pool excludes every KA feature/story boss",
    noFeatureBosses)

  local balls = wanderers.registeredBallIds(game)
  local liveApricorn = {}
  for _, row in ipairs(wanderers.rewardPool(game)) do
    if row.kind == "ball" and row.apricorn == true then
      liveApricorn[row.item] = true
    end
  end
  local allApricorn = true
  for _, id in ipairs({ "FAST_BALL", "FRIEND_BALL", "HEAVY_BALL",
      "LEVEL_BALL", "LOVE_BALL", "LURE_BALL", "MOON_BALL" }) do
    allApricorn = allApricorn and game.data.items[id] ~= nil
      and contains(balls, id) and liveApricorn[id] == true
  end
  check("all seven registered Apricorn Balls are live rewards",
    allApricorn)
  local surpriseHits, surpriseDenominator = wanderers.masterBallOdds(game)
  local rematchMaster = api.rematchRewards and api.rematchRewards.loot
    and api.rematchRewards.loot.SPECIAL.rematchMaster
  line("surprise_master_odds", tostring(surpriseHits) .. "/"
    .. tostring(surpriseDenominator))
  line("rematch_master_odds", rematchMaster and
    (tostring(rematchMaster.hits) .. "/"
      .. tostring(rematchMaster.denominator)) or "missing")
  check("Surprise Master Ball is rarer than ordinary loot but more frequent than rematch Master Ball",
    surpriseHits == 1 and surpriseDenominator == 32
      and rematchMaster and rematchMaster.hits == 1
      and rematchMaster.denominator == 50)
  local masterWitness = wanderers.selectReward(game, 1, 1, {})
  check("installed Surprise pool resolves its exact one-in-32 Master Ball hit",
    masterWitness and masterWitness.kind == "master"
      and masterWitness.item == "MASTER_BALL"
      and masterWitness.qty == 1)

  -- Exercise the four real catch-up transactions, not just their published
  -- odds.  Their settings must remain OFF while unlock ownership advances in
  -- the required 1/4 -> 1/6 -> 1/12 -> 1/24 order.
  local catchState = wanderers.state()
  local catchupKinds = {
    { key = "expShare", denominator = 4, unlock = "expShare" },
    { key = "multiplier2", denominator = 6, unlock = 2 },
    { key = "multiplier3", denominator = 12, unlock = 3 },
    { key = "multiplier5", denominator = 24, unlock = 5 },
  }
  local catchupExact = true
  for index, expected in ipairs(catchupKinds) do
    local hits, denominator = wanderers.catchupOdds(expected.key)
    local rolls = {}
    rolls[expected.key] = 1
    local reward = wanderers.selectReward(game, 32, 1, rolls)
    local placement, reason = wanderers.grantReward(game, catchState,
      reward, "legacy-wanderer-catchup-" .. tostring(index))
    catchupExact = catchupExact and hits == 1
      and denominator == expected.denominator
      and reward and reward.kind == "catchup"
      and reward.unlock == expected.unlock
      and placement ~= nil and reason == nil
  end
  local rewardState = api.rematchRewards.state(game)
  local catchupDone = wanderers.catchupStatus(game)
  check("catch-up rewards transact at exact 1/4, 1/6, 1/12 and 1/24 bands",
    catchupExact and catchupDone.expShareMissing == false
      and catchupDone.multiplier2Missing == false
      and catchupDone.nextMultiplier == nil)
  check("catch-up ownership never silently changes selected EXP settings",
    rewardState.expShareUnlocked == true
      and rewardState.expShareSetting == "off"
      and rewardState.expMultiplierUnlocked == 5
      and rewardState.expMultiplierSetting == 0)
  local duplicateCatchup, duplicateReason = wanderers.grantReward(game,
    catchState, { item = "EXP_ALL", qty = 1, kind = "catchup",
      unlock = "expShare" }, "legacy-wanderer-catchup-1")
  check("catch-up encounter token is exact-once",
    duplicateCatchup == nil and duplicateReason == "duplicate")

  -- The four frequency modes and location allow/deny contract are pure
  -- deterministic state transitions in the installed product.  Exercise
  -- every boundary here; the visible NORMAL run below separately proves the
  -- physical world-step -> NPC -> BattleState lifecycle.
  local profileCases = {
    rare = { floor = 600, maps = 4, cap = 5000 },
    normal = { floor = 200, maps = 2, cap = 1800 },
    often = { floor = 200, maps = 1, cap = 900 },
  }
  local profilesExact = true
  for name, expectedProfile in pairs(profileCases) do
    local profile = wanderers.FREQUENCY_PROFILES[name]
    profilesExact = profilesExact and profile
      and profile.minSteps == expectedProfile.floor
      and profile.minMaps == expectedProfile.maps
      and profile.hardMaxSteps == expectedProfile.cap
    local floorState = {}
    wanderers.scheduleNext(floorState, {
      frequency = name, targetMapChanges = expectedProfile.maps,
      startMap = "ROUTE_1",
    })
    for index = 1, expectedProfile.floor - 1 do
      local mapId = index <= expectedProfile.maps
        and ((index % 2 == 0) and "VIRIDIAN_CITY" or "ROUTE_2")
        or "ROUTE_1"
      wanderers.advanceCadence(floorState, mapId)
    end
    profilesExact = profilesExact and floorState.due ~= true
    wanderers.advanceCadence(floorState, "PEWTER_CITY")
    profilesExact = profilesExact and floorState.due == true
    local capState = {}
    wanderers.scheduleNext(capState, {
      frequency = name, targetMapChanges = profile.maxMaps,
      startMap = "ROUTE_25",
    })
    for _ = 1, expectedProfile.cap - 1 do
      wanderers.advanceCadence(capState, "ROUTE_25")
    end
    profilesExact = profilesExact and capState.due ~= true
    wanderers.advanceCadence(capState, "ROUTE_25")
    profilesExact = profilesExact and capState.due == true
  end
  local neverState = {
    frequency = "never", cycleSteps = 77, eligibleSteps = 88,
  }
  check("NEVER/RARE/NORMAL/OFTEN exact floor and fail-safe profiles",
    profilesExact
      and not wanderers.advanceCadence(neverState, "ROUTE_1")
      and neverState.cycleSteps == 77 and neverState.eligibleSteps == 88)
  check("routes and towns qualify while caves, houses and HEVO never do",
    wanderers.isEligibleMap("ROUTE_1")
      and wanderers.isEligibleMap("ROUTE_25")
      and wanderers.isEligibleMap("PALLET_TOWN")
      and wanderers.isEligibleMap("SAFFRON_CITY")
      and not wanderers.isEligibleMap("ROCK_TUNNEL_1F")
      and not wanderers.isEligibleMap("OAKS_LAB")
      and not wanderers.isEligibleMap("HEVO_RED_CORE"))

  local dramatic, overworldBattle
  local worldReceipt, worldReceiptSerial = nil, 0
  if mode == "full" then
    dramatic = assert(exports.DRAMALESS_SHAPE,
      "FULL proof requires the real DRAMALESS_SHAPE mod")
    overworldBattle = assert(dramatic.lib.require("OverworldBattle"),
      "DRAMALESS OverworldBattle is unavailable")
    -- FULL is a one-shot preset. Enter it from another rung so every owned
    -- dependent option is applied before the Route 1 scene is built.
    Pipelines.setLevel("voxel", 2)
    U.wait(3)
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    overworldBattle.setting:setIndex(1, game)
    overworldBattle.backSetting:setIndex(1, game)
    check("real DRAMALESS FULL world pipeline is active",
      Pipelines.level("voxel") == 1
        and Pipelines.levelLabel("voxel") == "FULL"
        and Pipelines.worldPipeline() == "voxel")
    -- A screenshot is not accepted merely because the FULL option is stored.
    -- Wrap the real compositor so each field/dialog/reward capture can prove
    -- that DRAMALESS produced a fresh world canvas for the live Route 1
    -- OverworldState after that capture's own wait began.
    local present = Pipelines.worldPresent
    Pipelines.worldPresent = function(canvas, ctx)
      local out = present(canvas, ctx)
      local state = ctx and ctx.state
      local mapId = state and state.map and state.map.id
      if out and mapId and Pipelines.worldPipeline() == "voxel" then
        worldReceiptSerial = worldReceiptSerial + 1
        worldReceipt = {
          serial = worldReceiptSerial,
          state = state,
          mapId = mapId,
          canvas = out,
          pipeline = "voxel",
          level = Pipelines.level("voxel"),
        }
      end
      return out
    end
  else
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    check("2D run owns the flat renderer without DRAMALESS",
      Pipelines.level("voxel") == 0
        and Pipelines.worldPipeline() ~= "voxel"
        and exports.DRAMALESS_SHAPE == nil)
  end

  local function receiptFailure(label, reason)
    check("fresh FULL render receipt before " .. label, false)
    line("blocker", "FULL receipt " .. label .. ": " .. tostring(reason))
    finish(1)
    error("FULL receipt failed before " .. label .. ": " .. tostring(reason), 0)
  end

  local function fullReceipt(label, battle)
    if mode ~= "full" then return true end
    if Pipelines.level("voxel") ~= 1
        or Pipelines.levelLabel("voxel") ~= "FULL"
        or Pipelines.worldPipeline() ~= "voxel" then
      return receiptFailure(label, "FULL voxel pipeline is not live")
    end

    local receipt, kind
    if battle then
      -- While a BattleState is opaque, DRAMALESS renders the arena through
      -- OverworldBattle/BattleScene rather than OverworldState.worldPresent.
      -- Require a newly rendered battle canvas, its live session/arena, and
      -- the exact BattleState-owned shot instead of mislabelling that canvas
      -- as a worldPresent callback.
      local before = overworldBattle.shot()
      receipt = waitFor(function()
        local shot = overworldBattle.shot()
        if shot and shot ~= before and shot.canvas
            and overworldBattle.battle() == battle
            and overworldBattle.arena() ~= nil
            and battle.dramaticShapeShot == shot then
          return shot
        end
        return nil
      end, 900)
      kind = "battleScene"
    else
      local before = worldReceiptSerial
      receipt = waitFor(function()
        local current = worldReceipt
        if current and current.serial > before
            and current.state == game.overworld
            and game.overworld and game.overworld.map
            and current.mapId == game.overworld.map.id
            and current.pipeline == "voxel" and current.level == 1 then
          return current
        end
        return nil
      end, 900)
      kind = "worldPresent"
    end
    if not (receipt and receipt.canvas and receipt.canvas.getDimensions) then
      return receiptFailure(label, "no fresh " .. kind .. " canvas")
    end
    local width, height = receipt.canvas:getDimensions()
    if not (width > 0 and height > 0) then
      return receiptFailure(label, kind .. " returned an empty canvas")
    end
    line("full_receipt_" .. label,
      ("kind=%s;pipeline=voxel;level=1;map=%s;canvas=%dx%d")
        :format(kind, game.overworld.map.id, width, height))
    check("fresh FULL render receipt before " .. label, true)
    return true
  end

  local function runtimeShot(label, path, battle)
    fullReceipt(label, battle)
    return U.shot(game, path)
  end

  check("Factory Architect unlocks in the isolated save",
    ascendant.unlockAchievement("factory_architect"))
  check("Factory Architect is the selected live title",
    hall.selectTitle("factory_architect"))
  local titleId, titleName = hall.currentTitle()
  check("selected title resolves through the live Hall provider",
    titleId == "factory_architect"
      and (titleName == "FACTORY ARCHITECT"
        or titleName == "FABRIK-ARCHITEKT"))
  local titleWord = titleName == "FABRIK-ARCHITEKT"
    and "FABRIK" or "FACTORY"
  line("language", titleWord == "FABRIK" and "de" or "en")

  -- Keep random selection honest but reproducible: Scientist is an actual
  -- ordinary trainer class with actual source parties. LOVE BALL is verified
  -- above as an actual live pool member; only this QA draw is pinned.
  local originalArchetypes = wanderers.ARCHETYPES
  local originalSelectReward = wanderers.selectReward
  wanderers.ARCHETYPES = {
    { class = "OPP_SCIENTIST", sprite = "SPRITE_SCIENTIST" },
  }
  wanderers.selectReward = function()
    return {
      item = "LOVE_BALL", qty = 1, kind = "ball",
      apricorn = true, weight = 4,
    }
  end

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(mode == "full" and 240 or 35)
  check("safe Route 1 overworld is settled before the due step",
    game.overworld and game.overworld.map.id == "ROUTE_1"
      and game.stack:top() == game.overworld
      and wanderers.contextSafe(game))

  local cadence = wanderers.state()
  cadence.eligibleSteps = 0
  cadence.frequency = "normal"
  cadence.cadenceMode = "normal"
  cadence.cycleSteps = 199
  cadence.mapChanges = 2
  cadence.targetMapChanges = 2
  cadence.lastEligibleMap = "ROUTE_1"
  cadence.stepsRemaining = 1601
  cadence.due = false
  cadence.encounter = nil
  cadence.nextToken = 1
  cadence.rotation = {}
  cadence.rewardedTokens = cadence.rewardedTokens or {}
  cadence.pendingRewards = {}
  bucket.legacy_wanderers = cadence
  local rewardBefore = inventoryCount("LOVE_BALL")
  local startX, startY = game.overworld.player.cellX,
    game.overworld.player.cellY

  local active
  for _, direction in ipairs({ "down", "up", "right", "left" }) do
    U.tap(game, direction)
    active = waitFor(function() return wanderers.active end, 90)
    if active then break end
  end
  wanderers.selectReward = originalSelectReward
  active = active or wanderers.active
  local stepped = game.overworld.player.cellX ~= startX
    or game.overworld.player.cellY ~= startY
  check("one physical eligible overworld step makes the encounter due",
    stepped and active ~= nil and cadence.eligibleSteps == 1
      and cadence.due == true and cadence.stepsRemaining == 0)
  if not active then
    wanderers.ARCHETYPES = originalArchetypes
    line("blocker", "real world.stepped path did not spawn a wanderer")
    finish(1)
    return
  end

  local token = active.token
  local trainer = game.data.trainers[active.archetype.class]
  local sourceParty = trainer and trainer.parties
    and trainer.parties[active.partyIndex]
  local expectedLevel = math.min(100,
    hero.level + active.tier.effectiveLevelBonus)
  line("trainer_class", active.archetype.class)
  line("trainer_party_index", active.partyIndex)
  line("source_party", rosterString(sourceParty))
  line("player_party", rosterString(game.save.party))
  line("scaled_team", rosterString(active.team))
  line("level_bonus", active.tier.effectiveLevelBonus)
  line("loss_relief", active.tier.lossRelief)
  line("ai_layers", active.tier.aiLayers)
  line("exp_bonus_percent", active.expBonusPercent)
  line("reward_token", token)
  line("reward_item", active.reward and active.reward.item)
  check("spawn uses a real live non-story Scientist party",
    active.archetype.class == "OPP_SCIENTIST"
      and trainer ~= nil and sourceParty ~= nil
      and not wanderers.isStoryTrainer(active.archetype.class, trainer))
  check("field sprite is an honest exact live Scientist sprite",
    active.archetype.sprite == "SPRITE_SCIENTIST"
      and active.archetype.fieldSpriteExact == true
      and game.data.sprites[active.archetype.sprite] ~= nil)
  local liveNpc = false
  for _, npc in ipairs(game.overworld.npcs or {}) do
    if npc.id == active.npcId then liveNpc = true break end
  end
  check("spawn selected a collision-safe scripted approach",
    #active.path >= 2 and #active.path <= 4
      and active.npcId ~= nil and liveNpc)
  check("team is only one to three levels over the fair usable-party baseline",
    active.tier.effectiveLevelBonus >= 1
      and active.tier.effectiveLevelBonus <= 3
      and active.tier.teamSize == 1 and #active.team == 1
      and active.team[1].level == expectedLevel)
  check("encounter owns an exact 15-20 percent EXP bonus",
    active.expBonusPercent >= 15 and active.expBonusPercent <= 20)

  -- Preserve the physical early battle above, then prove the same installed
  -- providers produce the authored late Lv100/AI/Mega tier.  The late sample
  -- is read-only with respect to the active encounter: teamFor(..., false)
  -- does not rotate or commit its roster.
  local legacyState = journey.state(game.save)
  local oldCycle, oldPact = legacyState.cycle, legacyState.pact
  local oldWins = cadence.wins
  local oldLevels = {}
  for index, mon in ipairs(game.save.party) do
    oldLevels[index] = mon.level
    mon.level = 100
  end
  legacyState.cycle, legacyState.pact = 3, "ascendant"
  cadence.wins = 10
  local lateIndex, lateTeam, lateTier = wanderers.teamFor(game,
    active.archetype, cadence, 3, false)
  local lateBattle = require("src.battle.BattleState").newTrainer(
    game, active.archetype.class, lateIndex)
  -- This bounded second BattleState is explicitly staged from the exact
  -- product teamFor result; the first encounter remains the fully physical
  -- world lifecycle.  Rebuild its engine Pokemon objects so recruitment and
  -- one-player-mon team sizing cannot be hidden by the registered source
  -- party's different length.
  lateBattle.enemyParty = {}
  for _, row in ipairs(lateTeam or {}) do
    local mon = Pokemon.new(game.data, row.species, row.level)
    if type(row.moves) == "table" then
      mon.moves = {}
      for _, moveId in ipairs(row.moves) do
        local move = assert(game.data.moves[moveId],
          "late Wanderer resolved an unregistered move")
        mon.moves[#mon.moves + 1] = { id = moveId, pp = move.pp }
      end
    end
    lateBattle.enemyParty[#lateBattle.enemyParty + 1] = mon
  end
  if lateBattle.enemy and lateBattle.enemyParty[1] then
    lateBattle.enemy.mon = lateBattle.enemyParty[1]
    lateBattle.enemy.curStats = lateBattle.enemy.mon.stats
    lateBattle.enemy.curMoves = lateBattle.enemy.mon.moves
    lateBattle.enemy.shownHP = lateBattle.enemy.mon.hp
  end
  wanderers.configureBattle(game, lateBattle, {
    token = "legacy-wanderer-late-package", tier = lateTier,
    expBonusPercent = 20,
  })
  Runtime.emit("battle.started", { battle = lateBattle })
  local lateLegal, latePerfect = true, true
  for _, mon in ipairs(lateBattle.enemyParty or {}) do
    lateLegal = lateLegal and mon.level == 100
      and #(mon.moves or {}) >= 1 and #(mon.moves or {}) <= 4
    local reportRow
    for _, row in ipairs((lateBattle.rematchMasteryReport
        and lateBattle.rematchMasteryReport.party) or {}) do
      if row.species == mon.species then reportRow = row break end
    end
    local dvs, statExp = mon.dvs or {}, mon.statExp or {}
    latePerfect = latePerfect and reportRow ~= nil
      and dvs.attack == 15 and dvs.defense == 15
      and dvs.speed == 15 and dvs.special == 15
      and statExp.hp == 65535 and statExp.attack == 65535
      and statExp.defense == 65535 and statExp.speed == 65535
      and statExp.special == 65535
  end
  local lateMega = api.megaEvolution.opponentEligible(lateBattle)
    and lateBattle._ascMegaEnemyPending == true
  check("late Wanderer is Lv100 with legal perfect mastery and three AI layers",
    lateTeam ~= nil and lateTier and lateTier.perfectMastery == true
      and #lateBattle.enemyParty == #lateTeam
      and lateLegal and latePerfect
      and lateBattle.enemyAIMods[1] == 1
      and lateBattle.enemyAIMods[2] == 2
      and lateBattle.enemyAIMods[3] == 3
      and lateBattle.ascendantLegacyHealItemCap == 1)
  check("late Wanderer is automatically eligible and armed for one enemy Mega",
    lateMega)
  line("late_sample", "STAGED_REAL_BATTLESTATE_FROM_PRODUCT_TEAM")
  legacyState.cycle, legacyState.pact = oldCycle, oldPact
  cadence.wins = oldWins
  for index, mon in ipairs(game.save.party) do mon.level = oldLevels[index] end
  check("deterministic runtime reward is the registered LOVE BALL",
    active.reward and active.reward.item == "LOVE_BALL"
      and game.data.items[active.reward.item] ~= nil)
  check("Factory Architect produces the class-reactive title intro",
    wanderers.reactionContext(active).kind == "title_factory"
      and wanderers.challengeText(active):find(titleWord, 1, true) ~= nil)
  check("safe-spawn field screenshot",
    runtimeShot("01_due_safe_spawn", dir .. "/01_due_safe_spawn.png"))

  local challenge = waitFor(function()
    local top = game.stack:top()
    return isText(top) and top or nil
  end, 420)
  check("spawn reaches the real HALT TextBox after the emote",
    challenge ~= nil)
  if not challenge then
    wanderers.cleanup(active)
    wanderers.ARCHETYPES = originalArchetypes
    line("blocker", "HALT TextBox did not open")
    finish(1)
    return
  end
  check("HALT page renders",
    waitForPage(challenge, 1, 300)
      and runtimeShot("02_halt", dir .. "/02_halt.png"))
  U.tap(game, "a")
  check("Factory Architect title-reaction page renders",
    waitForPage(challenge, 2, 420)
      and boxText(challenge):find(titleWord, 1, true) ~= nil
      and runtimeShot("03_factory_architect_title",
        dir .. "/03_factory_architect_title.png"))

  -- Close every authored page through real input. The TextBox callback walks
  -- the spawned NPC along its safe path and constructs the trainer battle.
  for _ = 1, 900 do
    if game.stack:top() ~= challenge then break end
    if challenge.waiting or challenge.done then U.tap(game, "a")
    else
      game.input.state.a = true
      U.wait(1)
      game.input.state.a = false
    end
  end
  local battle = waitFor(function()
    return active.battle and active.battle or nil
  end, 900)
  check("NPC completes its real approach and pushes a trainer battle",
    battle ~= nil and battle.ascendantLegacyWanderer == true
      and battle.ascendantLegacyToken == token)
  if not battle then
    wanderers.cleanup(active)
    wanderers.ARCHETYPES = originalArchetypes
    line("blocker", "safe NPC approach did not reach BattleState")
    finish(1)
    return
  end

  local observedExp, observedEnd, fullBattleProof
  local originalEmit = Runtime.emit
  Runtime.emit = function(name, payload)
    if name == "battle.exp_gained" and payload
        and payload.battle == battle and payload.mon == hero then
      observedExp = {
        gained = payload.gained,
        enemySpecies = battle.enemy and battle.enemy.mon
          and battle.enemy.mon.species,
        enemyLevel = battle.enemy and battle.enemy.mon
          and battle.enemy.mon.level,
      }
    elseif name == "battle.ended" and payload
        and payload.battle == battle then
      observedEnd = payload.result
    end
    return originalEmit(name, payload)
  end

  local introReady = waitFor(function()
    if game.stack:top() == battle and battle.showEnemyTrainer
        and battle.showPlayerBack then return true end
    return nil
  end, 720)
  if introReady then
    waitFor(function()
      return (battle.introSlide or 0) <= 0 and true or nil
    end, 180)
    U.wait(3)
  end
  check("real Scientist trainer introduction renders",
    introReady and battle.trainer ~= nil
      and runtimeShot("04_real_scientist_intro",
        dir .. "/04_real_scientist_intro.png", battle))
  if mode == "full" then
    fullBattleProof = overworldBattle.battle() == battle
      or (overworldBattle.arena() ~= nil
        and battle.dramaticShapeShot ~= nil)
  end

  local menuReady = waitFor(function()
    if game.stack:top() == battle and battle.phase == "menu" then return true end
    if game.stack:top() == battle then U.tap(game, "a") end
    return nil
  end, 1200)
  check("scaled live battle reaches the command menu",
    menuReady and battle.enemyParty and #battle.enemyParty == 1
      and battle.enemyParty[1].level == expectedLevel)
  if not menuReady then
    Runtime.emit = originalEmit
    wanderers.ARCHETYPES = originalArchetypes
    line("blocker", "trainer battle did not reach command menu")
    finish(1)
    return
  end
  check("scaled party HUD screenshot",
    runtimeShot("05_scaled_team_hud",
      dir .. "/05_scaled_team_hud.png", battle))

  -- Preserve the real roster and EXP math while making the bounded demo win
  -- deterministic in one real move. No result event or reward API is forged.
  battle.rng = function(low) return low end
  battle.enemy.mon.hp = 1
  battle.enemy.mon.stats.speed = 1
  local expBefore = hero.exp
  U.tap(game, "a") -- FIGHT
  local moveReady = waitFor(function()
    return battle.phase == "moveSelect" and true or nil
  end, 180)
  check("real battle opens the move selector", moveReady)
  if moveReady then U.tap(game, "a") end -- PSYCHIC -> real KO

  local expMessage = waitFor(function()
    local current = battle.current
    if observedExp and current and type(current.text) == "string"
        and current.text:find(tostring(observedExp.gained), 1, true) then
      return true
    end
    if game.stack:top() == battle then U.tap(game, "a") end
    return nil
  end, 1800)
  local baseExp, expectedExp
  if observedExp then
    baseExp = Experience.gainFor(
      game.data.pokemon[observedExp.enemySpecies],
      observedExp.enemyLevel, true, 1, hero.traded, game.data.constants)
    expectedExp = wanderers.applyExpBonus(baseExp, active.expBonusPercent)
  end
  line("base_trainer_exp", baseExp)
  line("actual_bonus_exp", observedExp and observedExp.gained)
  check("real battle EXP event applies the exact configured 15-20 percent",
    expMessage and observedExp ~= nil
      and observedExp.gained == expectedExp
      and hero.exp - expBefore == observedExp.gained)
  U.wait(35)
  check("exact bonus EXP message screenshot",
    expMessage and runtimeShot("06_exact_bonus_exp",
      dir .. "/06_exact_bonus_exp.png", battle))

  local loveBallName = assert(game.data.items.LOVE_BALL).name or "LOVE BALL"
  local rewardBox = waitFor(function()
    local top = game.stack:top()
    if isText(top) and boxText(top):find(loveBallName, 1, true) then
      return top
    end
    if game.stack:top() == battle then U.tap(game, "a") end
    return nil
  end, 3000)
  check("real trainer lifecycle ends in a win", observedEnd == "win")
  check("win places one LOVE BALL in the real Bag",
    rewardBox ~= nil and inventoryCount("LOVE_BALL") == rewardBefore + 1)
  if rewardBox then
    waitForPage(rewardBox, rewardBox.pageIndex, 300)
  end
  check("Bag reward confirmation screenshot",
    rewardBox and runtimeShot("07_love_ball_bag",
      dir .. "/07_love_ball_bag.png"))
  if rewardBox then
    for _ = 1, 600 do
      if game.stack:top() ~= rewardBox then break end
      U.tap(game, "a")
    end
  end

  local wonState = wanderers.state()
  local scheduled = wonState.stepsRemaining
  line("next_schedule", scheduled)
  line("next_frequency", wonState.frequency)
  line("next_cadence_mode", wonState.cadenceMode)
  line("next_target_maps", wonState.targetMapChanges)
  line("next_encore_map", wonState.encoreMap)
  check("victory commits reward exact-once and clears the encounter",
    wonState.rewardedTokens[token] == true
      and wonState.encounter == nil and #wonState.pendingRewards == 0
      and inventoryCount("LOVE_BALL") == rewardBefore + 1)
  check("victory commits a fair NORMAL or rare same-map encore schedule",
    wonState.due == false and wonState.frequency == "normal"
      and ((wonState.cadenceMode == "normal" and scheduled == 1800
          and wonState.targetMapChanges >= 2
          and wonState.targetMapChanges <= 3)
        or (wonState.cadenceMode == "encore" and scheduled >= 240
          and scheduled <= 480 and wonState.encoreMap == "ROUTE_1")))
  if mode == "full" then
    check("DRAMALESS owns a real staged battle arena/shot",
      fullBattleProof == true)
  end

  -- Drive the real stack-cap -> PC -> pending fallback transaction in the
  -- same disposable package save. Kanto imports predate explicit Gen 2
  -- pocket metadata, and a mod may enlarge that pocket beyond the number of
  -- registered items. Saturate only the two real reward stacks: this proves
  -- Bag.add rejection without touching LOVE BALL or fabricating filler.
  -- Never mutate game.data.constants.bagSize to manufacture this boundary.
  local oldPcCap = game.data.field.pcItemCap
  local inventoryBeforeFallback = copyFlat(game.save.inventory)
  local bagOrderBeforeFallback = copyList(Bag.order(game.save))
  local pcItemsBeforeFallback = copyFlat(game.save.pcItems)
  local pcOrderBeforeFallback = copyList(game.save.pcOrder)
  local targetPocket = Bag.pocketOf("GREAT_BALL", game.data)
  local ultraPocket = Bag.pocketOf("ULTRA_BALL", game.data)
  local targetCapacity = Bag.capacity(game.data, targetPocket)
  local targetIds = { "GREAT_BALL", "ULTRA_BALL" }
  line("target_reward_pocket", targetPocket)
  line("ultra_reward_pocket", ultraPocket)
  line("target_pocket_capacity", targetCapacity)
  check("Great and Ultra Ball rewards resolve to the same live target pocket",
    targetPocket == ultraPocket)
  local itemBefore = {}
  local saturationSucceeded = targetPocket == ultraPocket
  for _, id in ipairs(targetIds) do
    itemBefore[id] = inventoryCount(id)
    local delta = 99 - itemBefore[id]
    if delta > 0 then
      saturationSucceeded = Bag.add(game.save, id, delta, game.data)
        and saturationSucceeded
    end
  end
  local greatRejected = not Bag.add(game.save, "GREAT_BALL", 2, game.data)
  local ultraRejected = not Bag.add(game.save, "ULTRA_BALL", 3, game.data)
  check("real Great and Ultra Ball stacks saturate at the native stack cap",
    saturationSucceeded
      and inventoryCount("GREAT_BALL") == 99
      and inventoryCount("ULTRA_BALL") == 99)
  check("native Bag.add rejects both saturated Wanderer reward quantities",
    greatRejected and ultraRejected
      and inventoryCount("GREAT_BALL") == 99
      and inventoryCount("ULTRA_BALL") == 99)
  local pcOccupied = 0
  for _, qty in pairs(game.save.pcItems or {}) do
    if tonumber(qty) and tonumber(qty) > 0 then pcOccupied = pcOccupied + 1 end
  end
  game.data.field.pcItemCap = math.max(1, pcOccupied + 1)
  local pcBefore = tonumber(game.save.pcItems
    and game.save.pcItems.GREAT_BALL) or 0
  local ultraBefore = itemBefore.ULTRA_BALL or 0
  local pcUltraBefore = tonumber(game.save.pcItems
    and game.save.pcItems.ULTRA_BALL) or 0
  check("fallback staging starts without pre-existing Great or Ultra PC stacks",
    pcBefore == 0 and pcUltraBefore == 0)
  local pcPlacement = wanderers.grantReward(game, wonState,
    { item = "GREAT_BALL", qty = 2, kind = "ball" },
    "legacy-wanderer-pc-fallback")
  local pendingPlacement = wanderers.grantReward(game, wonState,
    { item = "ULTRA_BALL", qty = 3, kind = "ball" },
    "legacy-wanderer-pending-fallback")
  game.data.field.pcItemCap = oldPcCap
  line("great_ball_placement", pcPlacement)
  line("ultra_ball_placement", pendingPlacement)
  check("full live target pocket sends the Wanderer Ball stack to the real PC",
    pcPlacement == "pc"
      and (tonumber(game.save.pcItems.GREAT_BALL) or 0) == pcBefore + 2)
  check("full target pocket and then-full PC reserve the next Ball stack exactly once",
    pendingPlacement == "pending" and #wonState.pendingRewards == 1
      and wonState.pendingRewards[1].item == "ULTRA_BALL"
      and wonState.pendingRewards[1].qty == 3)
  local duplicatePending, duplicatePendingReason = wanderers.grantReward(
    game, wonState, { item = "ULTRA_BALL", qty = 3, kind = "ball" },
    "legacy-wanderer-pending-fallback")
  check("pending fallback token cannot duplicate",
    duplicatePending == nil and duplicatePendingReason == "duplicate"
      and #wonState.pendingRewards == 1)

  Runtime.emit = originalEmit
  wanderers.ARCHETYPES = originalArchetypes
  check("native save write succeeds after the committed win",
    game:writeSave())
  local loaded, recovered = SaveData.load()
  check("native SaveData reload returns the isolated slot", loaded ~= nil)
  if loaded then game:restoreSave(loaded, recovered) end
  U.wait(mode == "full" and 180 or 45)
  local reloadedState = wanderers.state()
  line("reloaded_schedule", reloadedState.stepsRemaining)
  line("love_ball_after_reload", inventoryCount("LOVE_BALL"))
  check("reload preserves exact-one Bag reward and token receipt",
    inventoryCount("LOVE_BALL") == rewardBefore + 1
      and reloadedState.rewardedTokens[token] == true
      and reloadedState.encounter == nil
      and #reloadedState.pendingRewards == 1)
  check("reload preserves PC and pending fallback transactions",
    (tonumber(game.save.pcItems.GREAT_BALL) or 0) == pcBefore + 2
      and reloadedState.pendingRewards[1].item == "ULTRA_BALL"
      and reloadedState.pendingRewards[1].qty == 3)
  check("reload preserves the exact next schedule without rerolling",
    reloadedState.due == false
      and reloadedState.stepsRemaining == scheduled
      and reloadedState.frequency == wonState.frequency
      and reloadedState.cadenceMode == wonState.cadenceMode
      and reloadedState.targetMapChanges == wonState.targetMapChanges
      and reloadedState.encoreMap == wonState.encoreMap)
  -- Remove only the two temporary target-stack deltas via the real Bag API.
  -- The pre-transaction inventory/order must be exact before the queued
  -- Ultra Ball is delivered into the newly available native target slot.
  for _, id in ipairs(targetIds) do
    local staged = inventoryCount(id)
    local original = itemBefore[id] or 0
    if staged > original then Bag.remove(game.save, id, staged - original) end
  end
  check("saturated reward stacks restore the exact prior Bag state",
    sameFlat(game.save.inventory, inventoryBeforeFallback)
      and sameList(Bag.order(game.save), bagOrderBeforeFallback))
  check("fallback staging changes only the intended Great Ball PC stack",
    (tonumber(game.save.pcItems.GREAT_BALL) or 0) == pcBefore + 2
      and (tonumber(game.save.pcItems.ULTRA_BALL) or 0) == pcUltraBefore
      and (function()
        local expectedItems = copyFlat(pcItemsBeforeFallback)
        expectedItems.GREAT_BALL = pcBefore + 2
        local expectedOrder = copyList(pcOrderBeforeFallback)
        expectedOrder[#expectedOrder + 1] = "GREAT_BALL"
        return sameFlat(game.save.pcItems, expectedItems)
          and sameList(game.save.pcOrder, expectedOrder)
      end)())
  local pendingResult, delivered, deliveredRow = wanderers.deliverPending(
    game, reloadedState)
  check("making target-pocket room delivers the reserved stack exactly once",
    delivered == true and pendingResult == "bag" and deliveredRow
      and deliveredRow.item == "ULTRA_BALL"
      and inventoryCount("ULTRA_BALL") == ultraBefore + 3
      and #reloadedState.pendingRewards == 0)
  local noSecondDelivery, deliveredTwice = wanderers.deliverPending(
    game, reloadedState)
  check("reserved stack cannot deliver twice",
    noSecondDelivery == nil and deliveredTwice == false
      and inventoryCount("ULTRA_BALL") == ultraBefore + 3)
  check("native save write persists the delivered fallback", game:writeSave())
  local deliveredSave, deliveredRecovered = SaveData.load()
  check("native reload after pending delivery succeeds", deliveredSave ~= nil)
  if deliveredSave then game:restoreSave(deliveredSave, deliveredRecovered) end
  U.wait(mode == "full" and 180 or 45)
  check("delivered Ball stack and empty pending queue survive reload",
    inventoryCount("ULTRA_BALL") == ultraBefore + 3
      and #wanderers.state().pendingRewards == 0)

  -- A loss resolves this surprise trainer instead of trapping a weakened
  -- party in an immediate rematch. This is the production loss transaction
  -- followed by a native SaveData roundtrip (the first encounter above
  -- already proves the full physical win path).
  local retryState = wanderers.state()
  retryState.due, retryState.stepsRemaining = true, 0
  retryState.encounter = nil
  local retryEncounter = assert(wanderers.prepareEncounter(game, retryState))
  retryEncounter.mapId = "ROUTE_1"
  local lossesBefore = retryState.losses or 0
  local retryResult = wanderers.resolveEncounter(game, retryState,
    retryEncounter, "lose")
  check("loss removes the Wanderer and starts a fresh delayed cadence",
    retryResult == "resolved_loss" and retryState.due == false
      and retryState.encounter == nil
      and retryState.losses == lossesBefore + 1
      and retryState.lossRelief == 1
      and retryState.forceMapChanges == true
      and retryState.targetMapChanges == wanderers.MAX_MAP_CHANGES)
  local lossReceipt = wanderers.lossText(retryState.lossRelief)
  check("loss receipt reports LOST and confirms money protection",
    (lossReceipt:find("LOST", 1, true) ~= nil
        or lossReceipt:find("VERLOREN", 1, true) ~= nil)
      and (lossReceipt:find("money is safe", 1, true) ~= nil
        or lossReceipt:find("Geld bleibt sicher", 1, true) ~= nil))
  check("native loss-save write succeeds", game:writeSave())
  local retrySave, retryRecovered = SaveData.load()
  check("native loss-save reload succeeds", retrySave ~= nil)
  if retrySave then game:restoreSave(retrySave, retryRecovered) end
  U.wait(mode == "full" and 180 or 45)
  local recoveredRetry = wanderers.state()
  check("reload preserves loss cooldown without reviving the trainer",
    recoveredRetry.due == false and recoveredRetry.encounter == nil
      and recoveredRetry.losses == lossesBefore + 1
      and recoveredRetry.lossRelief == 1
      and recoveredRetry.forceMapChanges == true
      and recoveredRetry.targetMapChanges == wanderers.MAX_MAP_CHANGES
      and recoveredRetry.stepsRemaining > 0)
  check("next outdoor step cannot immediately respawn after a loss",
    wanderers.advanceCadence(recoveredRetry, "ROUTE_1") == false
      and recoveredRetry.due == false and recoveredRetry.encounter == nil)
  check("clean final loss cooldown writes natively", game:writeSave())
  line("wanderer_matrix",
    "frequency/location/L100/AI/Mega/economy/loss-cooldown/reload")
  check("post-reload renderer screenshot",
    runtimeShot("08_post_reload_exact_once",
      dir .. "/08_post_reload_exact_once.png"))

  finish()
end
