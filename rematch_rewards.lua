-- Rematch 2.0 rewards, persistent EXP helpers and their UI.

return function(mod, opts)
  opts = opts or {}
  local loot = assert(opts.loot, "rematch reward tables required")
  local optionSchema = opts.optionSchema or {}
  local i18n = opts.i18n
  local optionHelp = opts.optionHelp
  local ascendantUi = opts.ascendantUi
  local legacyWanderers = opts.legacyWanderers
  local R = {
    MULTIPLIER_ITEM = "ASCENDANT_EXP_MULTIPLIER",
    STATE_VERSION = 2,
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  mod.content.items:register(R.MULTIPLIER_ITEM, {
    id = R.MULTIPLIER_ITEM,
    name = tr("EXP MULTIPLIER", "EP-MULTIPLIKATOR"),
    price = 0, keyItem = true, tossable = false, needsTarget = false,
  })

  local function normalizeStage(value)
    value = math.floor(tonumber(value) or 0)
    if value >= 5 then return 5 end
    if value >= 3 then return 3 end
    if value >= 2 then return 2 end
    return 0
  end

  local function ownsAnywhere(game, item)
    local save = game and game.save or {}
    return ((save.inventory or {})[item] or 0) > 0
      or ((save.pcItems or {})[item] or 0) > 0
  end

  local function state(game, create)
    local s = mod.save:get("rematch_rewards")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = R.STATE_VERSION,
        expShareUnlocked = false,
        expShareSetting = "off",
        expMultiplierUnlocked = 0,
        expMultiplierSetting = 0,
        pendingItems = {},
        masterReceipts = {}, masterReceiptOrder = {},
      }
      mod.save:set("rematch_rewards", s)
    end
    if type(s) ~= "table" then return nil end

    local rawPending = type(s.pendingItems) == "table" and s.pendingItems or {}
    local compact, byItem = {}, {}
    for _, row in ipairs(rawPending) do
      if type(row) == "table" and type(row.item) == "string"
          and row.item ~= "" then
        local key = table.concat({ row.item, row.reason or "",
          row.trainer or "" }, "\0")
        local existing = byItem[key]
        if existing then
          existing.qty = math.min(9999, existing.qty
            + math.max(1, math.floor(tonumber(row.qty) or 1)))
        else
          existing = {
            item = row.item,
            qty = math.min(9999, math.max(1,
              math.floor(tonumber(row.qty) or 1))),
            reason = row.reason,
            trainer = row.trainer,
          }
          byItem[key], compact[#compact + 1] = existing, existing
        end
      end
    end
    s.pendingItems = compact
    s.masterReceipts = type(s.masterReceipts) == "table"
      and s.masterReceipts or {}
    s.masterReceiptOrder = type(s.masterReceiptOrder) == "table"
      and s.masterReceiptOrder or {}
    s.expShareUnlocked = s.expShareUnlocked == true
    local share = s.expShareSetting
    if share ~= "classic" and share ~= "team" then share = "off" end

    -- Reality-based migration: released Ascendant saves can already own the
    -- vanilla EXP.ALL (or have Oak's one-time flag after storing/tossing it).
    -- No released standalone EXP Doubler state exists, so none is invented.
    local save = game and game.save
    if save then
      local flags = save.flags or {}
      if ownsAnywhere(game, "EXP_ALL") or flags.EVENT_GOT_EXP_ALL then
        s.expShareUnlocked = true
      end
    end
    if not s.expShareUnlocked then share = "off" end
    s.expShareSetting = share

    local stage = normalizeStage(s.expMultiplierUnlocked)
    if s.exp_multiplier_unlock_5x == true then stage = 5
    elseif s.exp_multiplier_unlock_3x == true then stage = math.max(stage, 3)
    elseif s.exp_multiplier_unlock_2x == true then stage = math.max(stage, 2) end
    s.expMultiplierUnlocked = stage
    s.exp_multiplier_unlock_2x = stage >= 2
    s.exp_multiplier_unlock_3x = stage >= 3
    s.exp_multiplier_unlock_5x = stage >= 5
    local selected = normalizeStage(s.expMultiplierSetting)
    if selected > stage then selected = stage end
    s.expMultiplierSetting = selected
    s.version = R.STATE_VERSION
    mod.save:set("rematch_rewards", s)
    return s
  end

  local function persist(s)
    mod.save:set("rematch_rewards", s)
    return s
  end

  function R.state(game, create) return state(game, create) end

  function R.setExpShare(game, value)
    local s = state(game)
    if not s.expShareUnlocked then value = "off" end
    if value ~= "classic" and value ~= "team" then value = "off" end
    s.expShareSetting = value
    persist(s)
    return value
  end

  function R.setMultiplier(game, value)
    local s = state(game)
    value = normalizeStage(value)
    if value > s.expMultiplierUnlocked then value = s.expMultiplierUnlocked end
    s.expMultiplierSetting = value
    persist(s)
    return value
  end

  function R.nextMultiplierUnlock(game)
    local stage = state(game).expMultiplierUnlocked
    if stage < 2 then return 2 end
    if stage < 3 then return 3 end
    if stage < 5 then return 5 end
    return nil
  end

  local function pendingContains(s, item)
    for _, row in ipairs(s.pendingItems) do
      if row.item == item then return true end
    end
    return false
  end

  local function pcAdd(game, item, qty)
    local save = game and game.save
    if not save then return false end
    save.pcItems = type(save.pcItems) == "table" and save.pcItems or {}
    local current = math.max(0, math.floor(tonumber(save.pcItems[item]) or 0))
    if current + qty > 99 then return false end
    if current == 0 then
      local stacks = 0
      for _ in pairs(save.pcItems) do stacks = stacks + 1 end
      local capacity = math.max(1, math.floor(tonumber(game.data
        and game.data.field and game.data.field.pcItemCap) or 50))
      if stacks >= capacity then return false end
      save.pcOrder = type(save.pcOrder) == "table" and save.pcOrder or {}
      save.pcOrder[#save.pcOrder + 1] = item
    end
    save.pcItems[item] = current + qty
    return true
  end

  -- Reality-based availability for the Wanderer catch-up bands. If an old or
  -- externally edited save has the physical helper (or a pending copy) but no
  -- matching controller state, repair the state so the item is never a no-op.
  function R.catchupStatus(game)
    local s = state(game)
    local flags = game and game.save and game.save.flags or {}
    local sharePresent = ownsAnywhere(game, "EXP_ALL")
      or pendingContains(s, "EXP_ALL") or flags.EVENT_GOT_EXP_ALL == true
    local multiplierPresent = ownsAnywhere(game, R.MULTIPLIER_ITEM)
      or pendingContains(s, R.MULTIPLIER_ITEM)
    local repaired = false
    if sharePresent and not s.expShareUnlocked then
      s.expShareUnlocked, s.expShareSetting = true, "off"
      if game and game.save then
        game.save.flags = game.save.flags or {}
        game.save.flags.EVENT_GOT_EXP_ALL = true
      end
      repaired = true
    end
    if multiplierPresent and s.expMultiplierUnlocked < 2 then
      s.expMultiplierUnlocked = 2
      s.exp_multiplier_unlock_2x = true
      s.expMultiplierSetting = 0
      repaired = true
    end
    if repaired then persist(s) end
    local items = game and game.data and game.data.items or {}
    return {
      expShareMissing = items.EXP_ALL ~= nil
        and not s.expShareUnlocked and not sharePresent,
      multiplier2Missing = items[R.MULTIPLIER_ITEM] ~= nil
        and s.expMultiplierUnlocked < 2 and not multiplierPresent,
      nextMultiplier = s.expMultiplierUnlocked >= 2
        and R.nextMultiplierUnlock(game) or nil,
    }
  end

  local function reservePending(s, row)
    for _, existing in ipairs(s.pendingItems) do
      if existing.item == row.item and existing.reason == row.reason
          and existing.trainer == row.trainer then
        existing.qty = math.min(9999, math.max(1,
          math.floor(tonumber(existing.qty) or 1))
          + math.max(1, math.floor(tonumber(row.qty) or 1)))
        return existing
      end
    end
    row.qty = math.min(9999, math.max(1, math.floor(tonumber(row.qty) or 1)))
    s.pendingItems[#s.pendingItems + 1] = row
    return row
  end

  local function grantOrReserve(game, item, qty, reason, grantOptions)
    qty = math.max(1, math.floor(tonumber(qty) or 1))
    local s = state(game)
    if item == R.MULTIPLIER_ITEM and (ownsAnywhere(game, item)
        or pendingContains(s, item)) then return "owned" end
    local Bag = require("src.inventory.Bag")
    game.save.inventory = game.save.inventory or {}
    game.save.bagOrder = game.save.bagOrder or {}
    if Bag.add(game.save, item, qty, game.data) then return "bag" end
    if grantOptions and grantOptions.pcFallback
        and pcAdd(game, item, qty) then return "pc" end
    reservePending(s, {
      item = item, qty = qty, reason = reason or "special",
    })
    persist(s)
    return "pending"
  end

  local function unlockMessage(game, kind, placement)
    if kind == "expShare" then
      local tail = placement == "pending"
        and tr("The BAG is full; its item\nis reserved safely.",
          "Der BEUTEL ist voll;\ndas Item bleibt sicher.")
        or placement == "pc" and tr(
          "The BAG was full; its item\nwent to your PC.",
          "Der BEUTEL war voll;\ndas Item ging in den PC.")
        or tr("Its setting remains OFF.\nChoose it in GAMEPLAY.",
          "Die Einstellung bleibt AUS.\nWähle sie in GAMEPLAY.")
      return tr("EXP SHARE unlocked!", "EP-TEILER freigeschaltet!")
        .. "\f" .. tail
    end
    local stage = tonumber(kind) or 2
    local tail = placement == "pending"
      and tr("The BAG is full; the\nshortcut is reserved.",
        "Der BEUTEL ist voll;\ndie Schnellwahl bleibt sicher.")
      or placement == "pc" and tr(
        "The BAG was full; the\nshortcut went to your PC.",
        "Der BEUTEL war voll;\ndie Schnellwahl ging in den PC.")
      or tr("Your current setting\nwas not changed.",
        "Deine aktuelle Wahl\nbleibt unverändert.")
    return tr(("EXP MULTIPLIER ×%d unlocked!"):format(stage),
      ("EP-MULTIPLIKATOR ×%d frei!"):format(stage)) .. "\f" .. tail
  end

  function R.unlock(game, kind, grantOptions)
    local s = state(game)
    if kind == "expShare" then
      if s.expShareUnlocked then return nil, false, "owned" end
      s.expShareUnlocked = true
      s.expShareSetting = "off"
      game.save.flags = game.save.flags or {}
      game.save.flags.EVENT_GOT_EXP_ALL = true
      persist(s)
      local placement = ownsAnywhere(game, "EXP_ALL") and "owned"
        or grantOrReserve(game, "EXP_ALL", 1, "expShare", grantOptions)
      return unlockMessage(game, kind, placement), true, placement
    end

    local requested = normalizeStage(kind)
    local expected = R.nextMultiplierUnlock(game)
    if not expected or requested ~= expected then return nil, false end
    local previousSetting = s.expMultiplierSetting
    s.expMultiplierUnlocked = requested
    s.exp_multiplier_unlock_2x = true
    s.exp_multiplier_unlock_3x = requested >= 3
    s.exp_multiplier_unlock_5x = requested >= 5
    s.expMultiplierSetting = previousSetting
    persist(s)
    local placement = "owned"
    if requested == 2 then
      placement = grantOrReserve(game, R.MULTIPLIER_ITEM, 1,
        "multiplier", grantOptions)
    end
    return unlockMessage(game, requested, placement), true, placement
  end

  local function itemName(game, id)
    local def = game.data.items and game.data.items[id]
    return def and def.name or tostring(id):gsub("_", " ")
  end

  local function itemMessage(game, trainerName, item, qty, pending)
    local stack = qty > 1 and (" ×" .. qty) or ""
    if pending then
      return tr(
        ("Reward from %s:\n%s%s!\fThe BAG is full; the\nreward is reserved.")
          :format(trainerName, itemName(game, item), stack),
        ("Preis von %s:\n%s%s!\fDer BEUTEL ist voll;\nder Preis bleibt sicher.")
          :format(trainerName, itemName(game, item), stack))
    end
    return tr(
      ("Reward from %s:\n%s%s!\fIt was put in\nthe BAG.")
        :format(trainerName, itemName(game, item), stack),
      ("Preis von %s:\n%s%s!\fEr wurde in den\nBEUTEL gelegt.")
        :format(trainerName, itemName(game, item), stack))
  end

  local function addNormalItem(game, holder, trainerName, reward)
    local Bag = require("src.inventory.Bag")
    game.save.inventory = game.save.inventory or {}
    game.save.bagOrder = game.save.bagOrder or {}
    if Bag.add(game.save, reward.item, reward.qty, game.data) then
      return itemMessage(game, trainerName, reward.item, reward.qty, false)
    end
    local global = state(game)
    if holder == global then
      reservePending(global, {
        item = reward.item, qty = reward.qty, trainer = trainerName,
        reason = "normal",
      })
      persist(global)
    else
      holder.pendingLoot = {
        item = reward.item, qty = reward.qty, trainer = trainerName,
      }
    end
    return itemMessage(game, trainerName, reward.item, reward.qty, true)
  end

  local function randomRoll(deps, key, lo, hi)
    local supplied = deps and deps.rewardRolls and deps.rewardRolls[key]
    if supplied ~= nil then return math.max(lo, math.min(hi, math.floor(supplied))) end
    local rng = deps and (deps.rewardRandom or deps.lootRandom)
    if not rng and love and love.math then rng = love.math.random end
    return (rng or math.random)(lo, hi)
  end

  local function hasHallOfFame(save)
    return save and ((type(save.hallOfFame) == "table"
      and #save.hallOfFame > 0) or (save.flags
        and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) or false
  end

  local function registeredMasterBall(game)
    local data = game and game.data or {}
    local def = data.items and data.items.MASTER_BALL
    if not def then return false end
    if data.balls and data.balls.MASTER_BALL then return true end
    if type(def.ball) == "string" and (def.ball == "MASTER_BALL"
        or data.balls and data.balls[def.ball]) then return true end
    local ok, effects = pcall(require, "src.inventory.ItemEffects")
    return ok and effects and type(effects.isBall) == "function"
      and effects.isBall("MASTER_BALL") == true or false
  end

  local function masterReceiptKey(battle)
    if not battle then return nil end
    if type(battle.rematchRewardToken) == "string" then
      return battle.rematchRewardToken
    end
    local trainer = battle.rematchTrainerKey or battle.oppClass
      or battle.rematchTrainerClass
    local number = tonumber(battle.rematchNumber)
    if trainer and number then
      return tostring(trainer) .. ":" .. tostring(math.floor(number))
    end
    return nil
  end

  local function recordMasterReceipt(s, key, result)
    if not key or s.masterReceipts[key] ~= nil then return end
    s.masterReceipts[key] = result
    s.masterReceiptOrder[#s.masterReceiptOrder + 1] = key
    while #s.masterReceiptOrder > 256 do
      local stale = table.remove(s.masterReceiptOrder, 1)
      s.masterReceipts[stale] = nil
    end
    persist(s)
  end

  local function masterMessage(game, trainerName, placement)
    local name = itemName(game, "MASTER_BALL")
    if placement == "pc" then
      return tr(("Rare reward from %s:\n%s!\fThe BAG was full; it\nwent to your PC.")
          :format(trainerName, name),
        ("Seltener Preis von %s:\n%s!\fBEUTEL voll; im PC\nverstaut.")
          :format(trainerName, name))
    elseif placement == "pending" then
      return tr(("Rare reward from %s:\n%s!\fBAG and PC are full;\nit is reserved safely.")
          :format(trainerName, name),
        ("Seltener Preis von %s:\n%s!\fBEUTEL und PC voll;\nsicher vorgemerkt.")
          :format(trainerName, name))
    end
    return tr(("Rare reward from %s:\n%s!\fIt was put in\nthe BAG.")
        :format(trainerName, name),
      ("Seltener Preis von %s:\n%s!\fIm BEUTEL\nverstaut.")
        :format(trainerName, name))
  end

  local function allLevel100(team)
    if not team or #team == 0 then return false end
    for _, mon in ipairs(team) do
      if (tonumber(mon.level) or 0) < 100 then return false end
    end
    return true
  end

  function R.afterWin(game, battle, holder, deps)
    holder = holder or state(game)
    local messages = {}
    local s = state(game)

    if not s.expShareUnlocked then
      local spec = loot.SPECIAL.expShare
      local roll = randomRoll(deps, "expShare", 1, spec.denominator)
      if loot.specialHit("expShare", roll) then
        local text = R.unlock(game, "expShare")
        if text then messages[#messages + 1] = text end
      end
    end

    local nextStage = R.nextMultiplierUnlock(game)
    if nextStage then
      local key = "multiplier" .. nextStage
      local spec = loot.SPECIAL[key]
      local roll = randomRoll(deps, key, 1, spec.denominator)
      if loot.specialHit(key, roll) then
        local text = R.unlock(game, nextStage)
        if text then messages[#messages + 1] = text end
      end
    end

    local mode = mod.options:get("loot_mode") or "balanced"
    local trainerName = battle and battle.trainer and battle.trainer.name
      or tr("TRAINER", "TRAINER")
    local masterAwarded = false
    if mode ~= "off" and hasHallOfFame(game.save)
        and registeredMasterBall(game) then
      local receipt = masterReceiptKey(battle)
      local resolved = receipt and s.masterReceipts[receipt]
        or battle and battle._ascRematchMasterResolved
      if not resolved then
        local spec = loot.SPECIAL.rematchMaster
        local roll = randomRoll(deps, "rematchMaster", 1, spec.denominator)
        local hit = loot.specialHit("rematchMaster", roll)
        local result = hit and "hit" or "miss"
        if battle then battle._ascRematchMasterResolved = result end
        recordMasterReceipt(s, receipt, result)
        if hit then
          local placement = grantOrReserve(game, "MASTER_BALL", 1,
            "rematchMaster", { pcFallback = true })
          messages[#messages + 1] = masterMessage(
            game, trainerName, placement)
          masterAwarded = true
        end
      elseif resolved == "hit" then
        -- The original transaction already placed or reserved the Ball.
        masterAwarded = true
      end
    end

    if mode ~= "off" and not masterAwarded and not holder.pendingLoot then
      local team = battle and battle.enemyParty or {}
      local level100 = allLevel100(team)
      local context = {
        level100 = level100,
        averageLevel = loot.averageLevel(team),
        masteryWins = battle and (battle.postgameMasteryWins
          or (battle.rematchMastery and battle.rematchMastery.masteryWins))
          or holder.masteryWins or 0,
      }
      local normalRoll = randomRoll(deps, "normal", 1, loot.ROLL_MAX)
      local reward = loot.select(normalRoll, mode, context, game.data)
      if reward then
        messages[#messages + 1] = addNormalItem(
          game, holder, trainerName, reward)
      else
        local moneyRoll = randomRoll(deps, "money", 1, 10000)
        local amount = loot.money(moneyRoll, level100)
        if amount > 0 then
          game.save.money = math.min(999999,
            math.max(0, tonumber(game.save.money) or 0) + amount)
          messages[#messages + 1] = tr(
            ("Additional rematch bonus:\n¥%d!"):format(amount),
            ("Zusätzlicher Revanchensieg:\n¥%d!"):format(amount))
        end
      end
    end
    return #messages > 0 and table.concat(messages, "\f") or nil
  end

  local function deliverOne(game, row)
    local Bag = require("src.inventory.Bag")
    return Bag.add(game.save, row.item, row.qty or 1, game.data)
  end

  function R.hasPending(game, holder)
    local s = state(game)
    return #s.pendingItems > 0
      or (holder and holder.pendingLoot and holder.pendingLoot.item) ~= nil
      or (s.pendingLoot and s.pendingLoot.item) ~= nil
  end

  function R.deliverPending(game, holder)
    local s = state(game)
    local row, source
    if #s.pendingItems > 0 then row, source = s.pendingItems[1], "global"
    elseif holder and holder.pendingLoot then row, source = holder.pendingLoot, "holder"
    elseif s.pendingLoot then row, source = s.pendingLoot, "state" end
    if not (row and row.item) then return nil, false end
    if not deliverOne(game, row) then
      return tr(
        ("Reserved reward:\n%s\fThe BAG is still full.")
          :format(itemName(game, row.item)),
        ("Gesicherter Preis:\n%s\fDer BEUTEL ist noch voll.")
          :format(itemName(game, row.item))), false
    end
    if source == "global" then table.remove(s.pendingItems, 1)
    elseif source == "state" then s.pendingLoot = nil
    else holder.pendingLoot = nil end
    persist(s)
    return tr(
      ("Received reserved\n%s!"):format(itemName(game, row.item)),
      ("Gesichertes Item erhalten:\n%s!"):format(itemName(game, row.item))), true
  end

  -- ----------------------- ASCENDANT -> OPTIONS -> GAMEPLAY dynamic tree

  local function shareLabel(value)
    if value == "classic" then return tr("CLASSIC", "KLASSISCH") end
    if value == "team" then return tr("TEAM", "TEAM") end
    return tr("OFF", "AUS")
  end

  local function multiplierLabel(value)
    return tonumber(value) and tonumber(value) > 0
      and ("×" .. tostring(value)) or tr("OFF", "AUS")
  end

  local function cycle(list, value)
    for index, candidate in ipairs(list) do
      if candidate == value then return list[index % #list + 1] end
    end
    return list[1]
  end

  local function gameplayRows(game)
    local s = state(game)
    local rows = {}
    if s.expShareUnlocked then
      rows[#rows + 1] = {
        value = "exp_share", label = tr("EXP SHARE", "EP-TEILER"),
        right = shareLabel(s.expShareSetting),
        help = tr(
          "OFF disables shared EXP. CLASSIC mirrors EXP.ALL. TEAM shares EXP across the active party.",
          "AUS deaktiviert geteilte EP. KLASSISCH entspricht EP-TEILER. TEAM verteilt EP im aktiven Team."),
      }
    end
    if s.expMultiplierUnlocked >= 2 then
      rows[#rows + 1] = {
        value = "exp_multiplier",
        label = tr("EXP MULTIPLIER", "EP-MULTIPLIKATOR"),
        right = multiplierLabel(s.expMultiplierSetting),
        help = tr(
          "Applies the highest multiplier unlocked through rematch progression to earned EXP.",
          "Wendet den höchsten durch Revanchen freigeschalteten Multiplikator auf verdiente EP an."),
      }
    end
    if #rows == 0 then
      rows[1] = {
        value = "locked", label = tr("EXP HELPERS", "EP-HILFEN"),
        right = tr("LOCKED", "GESPERRT"),
        help = tr(
          "EXP helpers are earned through Ascendant rematch progression.",
          "EP-Hilfen werden über Ascendants Revanchen-Fortschritt freigeschaltet."),
      }
    end
    return rows
  end

  local function openGameplay(game, focus)
    local screen = (focus == "exp_share" or focus == "exp_multiplier")
      and "AscendantTrainingOptions" or "AscendantGameplayOptions"
    return mod.ui.push(game, screen, { focus = focus })
  end
  R.openGameplay = openGameplay

  local CATEGORY = {
    language = "system",
    difficulty = "core", wild_level_scaling = "core",
    kanto_151 = "core", ascendant_rules = "core",
    rare_item_lock = "capture",
    rest_min = "rematch", rest_max = "rematch", level_gain = "rematch",
    team_growth = "rematch", loot_mode = "rematch",
    legacy_wanderer_frequency = "rematch",
    vision_encounters = "adventure", shiny_hunts = "adventure",
    shiny_event = "adventure",
    mega_evolution = "adventure", mega_opponents = "adventure",
    rocket_story = "adventure", grand_tournament = "adventure",
    johto_time = "johto", johto_signals_enable = "johto",
    johto_signals_start = "johto", johto_level_bonus = "johto",
    mythic_signals = "johto", mew_profile = "johto",
    living_world_enabled = "living_encounters",
    living_world_density = "living_encounters",
    living_world_random_encounters = "living_encounters",
    living_world_water = "living_encounters",
    living_world_caves = "living_encounters",
    living_world_grass = "living_encounters",
    living_world_silhouettes = "living_encounters",
    living_world_idle = "living_behavior",
    living_world_wander = "living_behavior",
    living_world_chase = "living_behavior",
    living_world_hidden = "living_behavior",
    johto_wilds_integration = "living_towns",
    living_world_towns = "living_towns",
    wilds_town_pokemon_amount = "living_towns",
    wilds_town_pokemon_species = "living_towns",
    legend_articuno = "legends", legend_zapdos = "legends",
    legend_moltres = "legends", legend_mewtwo = "legends",
    legend_raikou = "legends", legend_entei = "legends",
    legend_suicune = "legends", legend_lugia = "legends",
    legend_ho_oh = "legends", legend_celebi = "legends",
    legend_mew = "legends",
    event_mode = "heritage", event_university_magikarp = "heritage",
    event_stamp_fearow = "heritage", event_flying_pikachu = "heritage",
    event_stamp_rapidash = "heritage", event_surfing_pikachu = "heritage",
    event_flee = "heritage",
    follower_count = "followers",
    follower_order = "followers", yellow_partner_presentation = "followers",
    legend_art = "visuals", kanto_crystal_art = "visuals",
    dex_sprite_style = "visuals", party_icon_style = "visuals",
    crystal_animation = "visuals",
    pokemon_sprite_style = "visual_pokemon",
    sprite_style_battle = "visual_pokemon",
    sprite_style_summary = "visual_pokemon",
    sprite_style_dex = "visual_pokemon",
    sprite_style_box = "visual_pokemon",
    sprite_style_scenes = "visual_pokemon",
    character_sprite_style = "visual_characters",
    trainer_portrait_style = "visual_characters",
    shiny_effects = "visuals", event_rosette = "visuals",
    modern_ball_skins = "visuals",
    ascendant_useful_bag = "menus", ascendant_bag_mode = "menus",
    modern_storage_ui = "menus", fast_box_switch = "menus",
    ascendant_quick_select = "controls", ride_control = "controls",
    quick_select_tap = "controls", quick_select_registration = "controls",
    quick_select_empty_notice = "controls",
    ascendant_qol = "qol", qol_exp_bar = "qol",
    qol_caught_indicator = "qol", qol_easy_interactions = "qol",
    qol_location_banners = "qol", text_speed = "qol",
    catch_destination = "capture", catch_box_notice = "capture",
    pokedex_filter = "capture", box_filter = "capture",
    status_values = "capture", shiny_protection = "capture",
  }
  local function optionValue(game, key)
    local bucket = game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket[key] ~= nil then return bucket[key] end
    return mod.options:get(key)
  end
  local function setOption(game, key, value)
    game.mods = game.mods or {}
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions[mod.id] = game.mods.modOptions[mod.id] or {}
    game.mods.modOptions[mod.id][key] = value
    game.save = game.save or {}
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions[mod.id] = game.save.options.modOptions[mod.id] or {}
    game.save.options.modOptions[mod.id][key] = value
    if game.writeOptions then game:writeOptions() end
    if game.mods and game.mods.events then
      game.mods.events:emit("mod.options_changed",
        { game = game, mod = mod.id, key = key, value = value })
    end
  end
  local function schemaValueLabel(row, value)
    if row.type == "toggle" then return value == false and tr("OFF", "AUS") or tr("ON", "AN") end
    for _, choice in ipairs(row.choices or {}) do
      if choice[2] == value then return choice[1] end
    end
    return tostring(value)
  end
  local function stepValue(values, current, direction)
    if #values == 0 then return current end
    for index, candidate in ipairs(values) do
      if candidate == current then
        return values[((index - 1 + direction) % #values) + 1]
      end
    end
    return direction < 0 and values[#values] or values[1]
  end

  local function stepSchema(game, row, direction)
    direction = direction < 0 and -1 or 1
    local current = optionValue(game, row.key)
    local value
    if row.type == "toggle" then value = current == false
    elseif row.type == "number" then
      if row.presets and #row.presets > 0 then
        value = stepValue(row.presets, tonumber(current) or row.default,
          direction)
      else
        value = (tonumber(current) or row.default)
          + direction * (row.step or 1)
        if value > row.max then value = row.min end
        if value < row.min then value = row.max end
      end
    else
      local values = {}
      for _, choice in ipairs(row.choices or {}) do values[#values + 1] = choice[2] end
      value = stepValue(values, current == nil and row.default or current,
        direction)
    end
    setOption(game, row.key, value)
    return schemaValueLabel(row, value)
  end
  local function optionRows(game, category)
    local rows = {}
    for _, schema in ipairs(optionSchema) do
      local bucket = CATEGORY[schema.key] or "content"
      local visible = schema.key ~= "legacy_wanderer_frequency"
        or (legacyWanderers
          and type(legacyWanderers.legacyRunEnabled) == "function"
          and legacyWanderers.legacyRunEnabled(game))
      if bucket == category and visible then
        local value = optionValue(game, schema.key)
        local valueLabel = schemaValueLabel(schema, value)
        rows[#rows + 1] = { value = schema.key, label = schema.label,
          right = valueLabel, schema = schema,
          help = optionHelp and optionHelp.text(schema.key, valueLabel) }
      end
    end
    if category == "training" then
      for _, row in ipairs(gameplayRows(game)) do rows[#rows + 1] = row end
    end
    return rows
  end

  local function chooseRow(game, item)
    if item and item.screen then
      mod.ui.push(game, item.screen)
    end
  end

  local function stepTraining(game, item, direction)
    if not item or item.value == "locked" then return false end
    local s = state(game)
    if item.value == "exp_share" then
      local value = stepValue({ "off", "classic", "team" },
        s.expShareSetting, direction)
      R.setExpShare(game, value); item.right = shareLabel(value)
      return true
    elseif item.value == "exp_multiplier" then
      local values = { 0, 2 }
      if s.expMultiplierUnlocked >= 3 then values[#values + 1] = 3 end
      if s.expMultiplierUnlocked >= 5 then values[#values + 1] = 5 end
      local value = stepValue(values, s.expMultiplierSetting, direction)
      R.setMultiplier(game, value); item.right = multiplierLabel(value)
      return true
    end
    return false
  end

  local function stepRow(game, item, category, direction)
    if item and item.schema then
      item.right = stepSchema(game, item.schema, direction)
      item.help = optionHelp
        and optionHelp.text(item.schema.key, item.right) or item.help
      return true
    end
    if category == "training" then
      return stepTraining(game, item, direction)
    end
    return false
  end

  local function newOptionsList(game, title, rows, category, args)
    local function rowFooter(item)
      if item and item.screen then
        return tr("A:OPEN SEL:HELP", "A:AUF SEL:HILFE")
      end
      return tr("L/R:CHG SEL:HELP", "L/R:AEND SEL:HILFE")
    end
    local list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      title, rows, {
        pageJump = false,
        footer = rowFooter(rows[1]),
        onSelectKey = function(item)
          if item and item.help and ascendantUi then
            ascendantUi.showHelp(game, item.label, item.help)
          end
        end,
        onChoose = function(item) chooseRow(game, item) end,
      })
    -- ListMenu reserves L/R for page jumps.  Ascendant option pages instead
    -- use those keys to change only the highlighted value.  Keep this wrapper
    -- instance-local so Bag, Pokédex and third-party lists retain stock input.
    list.pageJump = false
    local baseUpdate = list.update
    function list:ascendantStep(direction)
      return stepRow(game, self.items[self.index], category, direction)
    end
    function list:update(dt)
      local input = self.game and self.game.input
      if input and input:wasPressed("left") then
        self:ascendantStep(-1)
        self.footer = rowFooter(self.items[self.index])
        return
      elseif input and input:wasPressed("right") then
        self:ascendantStep(1)
        self.footer = rowFooter(self.items[self.index])
        return
      end
      local result
      if baseUpdate then result = baseUpdate(self, dt) end
      self.footer = rowFooter(self.items[self.index])
      return result
    end
    local focus = args and args.focus
    if focus then
      for index, row in ipairs(rows) do
        if row.value == focus then list.index = index; break end
      end
    end
    return list
  end

  local function registerCategory(name, category, title)
    mod.content.screens:register(name, { new = function(game, args)
      return newOptionsList(game, title, optionRows(game, category),
        category, args)
    end })
  end

  local function submenu(value, label, screen, help)
    return { value = value, label = label, screen = screen, help = help }
  end

  local function registerGroupedCategory(name, category, title, children)
    mod.content.screens:register(name, { new = function(game, args)
      local rows = {}
      for _, row in ipairs(children) do rows[#rows + 1] = row end
      for _, row in ipairs(optionRows(game, category)) do
        rows[#rows + 1] = row
      end
      return newOptionsList(game, title, rows, category, args)
    end })
  end

  registerCategory("AscendantCoreOptions", "core",
    tr("CORE RULES", "GRUNDREGELN"))
  registerCategory("AscendantRematchOptions", "rematch",
    tr("REMATCH", "REVANCHEN"))
  registerCategory("AscendantTrainingOptions", "training",
    tr("EXP / TRAINING", "EP / TRAINING"))
  registerCategory("AscendantFollowerOptions", "followers", tr("FOLLOWERS", "BEGLEITER"))
  registerCategory("AscendantPokemonSpriteOptions", "visual_pokemon",
    tr("POKéMON SPRITES", "POKéMON-SPRITES"))
  registerCategory("AscendantCharacterTrainerOptions", "visual_characters",
    tr("CHARACTERS / TRAINERS", "FIGUREN / TRAINER"))
  registerGroupedCategory("AscendantVisualOptions", "visuals",
    tr("VISUALS", "GRAFIK"), {
      submenu("pokemon_sprites", tr("POKéMON SPRITES", "POKéMON-SPRITES"),
        "AscendantPokemonSpriteOptions", tr(
          "Global Pokémon artwork and its individual screen surfaces.",
          "Globale Pokémon-Grafik und ihre einzelnen Bildschirmbereiche.")),
      submenu("characters_trainers",
        tr("CHARACTERS / TRAINERS", "FIGUREN / TRAINER"),
        "AscendantCharacterTrainerOptions", tr(
          "Field character sheets and trainer portrait presentation.",
          "Feldfiguren und die Darstellung von Trainer-Porträts.")),
    })
  registerCategory("AscendantAdventureOptions", "adventure",
    tr("ADVENTURE", "ABENTEUER"))
  registerCategory("AscendantLivingEncounterOptions", "living_encounters",
    tr("WILD ENCOUNTERS", "WILDBEGEGNUNGEN"))
  registerCategory("AscendantLivingBehaviorOptions", "living_behavior",
    tr("BEHAVIOR", "VERHALTEN"))
  registerCategory("AscendantLivingTownOptions", "living_towns",
    tr("JOHTO / TOWNS", "JOHTO / STÄDTE"))
  registerCategory("AscendantJohtoOptions", "johto",
    tr("JOHTO / SIGNALS", "JOHTO / SIGNALE"))
  registerCategory("AscendantLegendOptions", "legends",
    tr("LEGENDS", "LEGENDEN"))
  registerCategory("AscendantHeritageOptions", "heritage",
    tr("HERITAGE EVENTS", "HERITAGE-EVENTS"))
  registerCategory("AscendantCaptureOptions", "capture",
    tr("CAPTURE / STORAGE", "FANGEN / LAGERN"))
  registerCategory("AscendantControlOptions", "controls",
    tr("CONTROLS", "STEUERUNG"))
  registerCategory("AscendantQolOptions", "qol",
    tr("QUALITY OF LIFE", "KOMFORT"))
  registerCategory("AscendantMenuOptions", "menus",
    tr("BAG / MENUS", "BEUTEL / MENÜS"))
  registerGroupedCategory("AscendantGameplayOptions", "gameplay_hub",
    tr("GAMEPLAY", "GAMEPLAY"), {
      submenu("core", tr("CORE RULES", "GRUNDREGELN"),
        "AscendantCoreOptions", tr(
          "Difficulty, Kanto completion and Ascendant battle rules.",
          "Schwierigkeit, Kanto-Abschluss und Ascendant-Kampfregeln.")),
      submenu("rematch", tr("REMATCH", "REVANCHEN"),
        "AscendantRematchOptions", tr(
          "Recovery steps, level gain, team growth and rematch loot.",
          "Pausenschritte, Levelanstieg, Teamwachstum und Revanchensbeute.")),
      submenu("training", tr("EXP / TRAINING", "EP / TRAINING"),
        "AscendantTrainingOptions", tr(
          "Unlocked EXP Share and multiplier assistance.",
          "Freigeschaltete EP-Teiler- und Multiplikator-Hilfen.")),
      submenu("capture", tr("CAPTURE / STORAGE", "FANGEN / LAGERN"),
        "AscendantCaptureOptions", tr(
          "Catch destination, protection, filters and status information.",
          "Fangziel, Schutz, Filter und Statusinformationen.")),
      submenu("controls", tr("CONTROLS", "STEUERUNG"),
        "AscendantControlOptions", tr(
          "Bicycle and configurable SELECT shortcuts.",
          "Fahrrad und konfigurierbare SELECT-Kürzel.")),
    })
  registerGroupedCategory("AscendantContentOptions", "content_hub",
    tr("WORLD / CONTENT", "WELT / INHALTE"), {
      submenu("adventure", tr("ADVENTURE", "ABENTEUER"),
        "AscendantAdventureOptions", tr(
          "Visions, shiny hunts, Mega Evolution, stories and Ascendant Challenge.",
          "Visionen, Shiny-Jagd, Mega-Entwicklung, Story und Ascendant-Challenge.")),
      submenu("living_world", tr("LIVING REGIONS", "LEBENDE REGIONEN"),
        "AscendantLivingWorldOptions", tr(
          "Visible Pokémon, population, behavior and regional mixture.",
          "Sichtbare Pokémon, Menge, Verhalten und Regionsmischung.")),
      submenu("johto", tr("JOHTO / SIGNALS", "JOHTO / SIGNALE"),
        "AscendantJohtoOptions", tr(
          "Early Johto migration and Mythic Signal progression.",
          "Frühe Johto-Wanderung und Mythos-Signal-Fortschritt.")),
      submenu("legends", tr("LEGENDS", "LEGENDEN"),
        "AscendantLegendOptions", tr(
          "Individual profiles for Kanto and Johto legendary Pokémon.",
          "Einzelprofile für legendäre Pokémon aus Kanto und Johto.")),
      submenu("heritage", tr("HERITAGE EVENTS", "HERITAGE-EVENTS"),
        "AscendantHeritageOptions", tr(
          "Historical event encounters and their behavior.",
          "Historische Event-Begegnungen und ihr Verhalten.")),
    })
  registerGroupedCategory("AscendantComfortOptions", "comfort_hub",
    tr("QOL / MENUS", "KOMFORT / MENÜS"), {
      submenu("qol", tr("QUALITY OF LIFE", "KOMFORT"),
        "AscendantQolOptions", tr(
          "Text, interaction, location and battle information helpers.",
          "Text-, Interaktions-, Orts- und Kampfinformationshilfen.")),
      submenu("menus", tr("BAG / MENUS", "BEUTEL / MENÜS"),
        "AscendantMenuOptions", tr(
          "Bag layout, menu skin and faster Box switching.",
          "Beutelaufteilung, Menüoptik und schneller Boxwechsel.")),
    })
  registerGroupedCategory("AscendantLivingWorldOptions", "living_hub",
    tr("LIVING REGIONS", "LEBENDE REGIONEN"), {
      submenu("encounters", tr("WILD ENCOUNTERS", "WILDBEGEGNUNGEN"),
        "AscendantLivingEncounterOptions", tr(
          "Amount, land, water, cave and silhouette presentation.",
          "Menge sowie Land-, Wasser-, Höhlen- und Silhouettendarstellung.")),
      submenu("behavior", tr("BEHAVIOR", "VERHALTEN"),
        "AscendantLivingBehaviorOptions", tr(
          "Calm, wandering, chasing and concealed wild Pokémon.",
          "Ruhige, wandernde, verfolgende und verborgene Wild-Pokémon.")),
      submenu("towns", tr("JOHTO / TOWNS", "JOHTO / STÄDTE"),
        "AscendantLivingTownOptions", tr(
          "Johto habitats and peaceful town populations.",
          "Johto-Habitate und friedliche Stadtpopulationen.")),
    })

  mod.content.screens:register("AscendantOptionsRoot", {
    new = function(game)
      return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
        tr("ASCENDANT OPTIONS", "ASCENDANT-OPTIONEN"), {
          { value = "gameplay", label = tr("GAMEPLAY", "GAMEPLAY"), screen = "AscendantGameplayOptions",
            help = tr("Core rules, rematches, training, capture flow and controls.",
              "Grundregeln, Revanchen, Training, Fangablauf und Steuerung.") },
          { value = "content", label = tr("WORLD / CONTENT", "WELT / INHALTE"), screen = "AscendantContentOptions",
            help = tr("Living Regions, Johto signals, quests, legends and events.",
              "Lebende Regionen, Johto-Signale, Missionen, Legenden und Events.") },
          { value = "visuals", label = tr("VISUALS", "GRAFIK"), screen = "AscendantVisualOptions",
            help = tr("Battle, Dex, character and menu sprite presentation.",
              "Darstellung von Kampf-, Dex-, Figuren- und Menügrafiken.") },
          { value = "followers", label = tr("FOLLOWERS", "BEGLEITER"), screen = "AscendantFollowerOptions",
            help = tr("Number, order and presentation of following party Pokémon.",
              "Anzahl, Reihenfolge und Darstellung der folgenden Team-Pokémon.") },
          { value = "comfort", label = tr("QOL / MENUS", "KOMFORT / MENÜS"), screen = "AscendantComfortOptions",
            help = tr("Quality-of-life helpers, Bag layout and menu behavior.",
              "Komforthilfen, Beutelaufteilung und Menüverhalten.") },
        }, {
          footer = tr("A:OPEN SEL:HELP", "A:AUF SEL:HILFE"),
          onSelectKey = function(item)
            if item and item.help and ascendantUi then
              ascendantUi.showHelp(game, item.label, item.help)
            end
          end,
          onChoose = function(item)
            if item and item.screen then mod.ui.push(game, item.screen) end
          end,
        })
    end,
  })

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    out[#out + 1] = {
      label = tr("OPTIONS", "OPTIONEN"),
      ascendantLabel = tr("OPTIONS", "OPTIONEN"),
      ascendantMenu = true, ascendantKey = "options", ascendantOrder = 1,
      onSelect = function() mod.ui.push(game, "AscendantOptionsRoot") end,
    }
    return out
  end, 900)

  -- Both physical helper items are shortcuts only.  The wrapper intercepts
  -- the Bag row before USE/TOSS opens and never toggles assistance itself.
  local BagMenu = require("src.ui.BagMenu")
  if not BagMenu._ascendantExpShortcutWrapped then
    local originalNew = BagMenu.new
    BagMenu.new = function(game, bagOpts)
      local list = originalNew(game, bagOpts)
      local originalChoose = list.onChoose
      list.onChoose = function(item, menu)
        local shortcut = BagMenu._ascendantExpShortcut
        if not (bagOpts and bagOpts.battle) and item and shortcut
            and shortcut(game, item.value, menu or list) then return end
        return originalChoose(item, menu)
      end
      return list
    end
    BagMenu._ascendantExpShortcutWrapped = true
  end
  BagMenu._ascendantExpShortcut = function(game, item, list)
    local focus
    if item == "EXP_ALL" then focus = "exp_share"
    elseif item == R.MULTIPLIER_ITEM then focus = "exp_multiplier" end
    if not focus then return false end
    state(game) -- migrates old item-only saves before opening the row
    if list and list.close then list:close() end
    openGameplay(game, focus)
    return true
  end

  -- ------------------------- EXP allocation, then final multiplier

  mod.hooks:wrap("battle.exp_award", function(nextAward, ctx)
    local battle = ctx and ctx.battle
    local game = battle and battle.game
    if not game then return nextAward(ctx) end
    local s = state(game)
    local mode = s.expShareUnlocked and s.expShareSetting or "off"
    if mode == "off" then
      for _, mon in ipairs(ctx.alive or {}) do
        ctx.applyShare(mon, math.max(1, ctx.participants), true)
      end
      return
    end
    if mode == "classic" then
      for _, mon in ipairs(ctx.alive or {}) do
        ctx.applyShare(mon, math.max(1, ctx.participants) * 2, true)
      end
      local party = game.save.party or {}
      for _, mon in ipairs(party) do
        if (mon.hp or 0) > 0 then
          ctx.applyShare(mon,
            math.max(1, ctx.participants) * math.max(1, #party) * 2,
            "expAll")
        end
      end
      return
    end

    -- TEAM: surviving participants receive their normal divided award;
    -- every other healthy party member receives half of an undivided award.
    local participant = {}
    for _, mon in ipairs(ctx.alive or {}) do
      participant[mon] = true
      ctx.applyShare(mon, math.max(1, ctx.participants), true)
    end
    for _, mon in ipairs(game.save.party or {}) do
      if (mon.hp or 0) > 0 and not participant[mon] then
        ctx.applyShare(mon, 2, "expAll")
      end
    end
  end, 200)

  mod.hooks:wrap("exp.gain", function(nextGain, ctx)
    local gained = math.max(1, math.floor(tonumber(nextGain(ctx)) or 1))
    local multiplier = state(nil).expMultiplierSetting
    if multiplier ~= 2 and multiplier ~= 3 and multiplier ~= 5 then
      multiplier = 1
    end
    return gained * multiplier
  end, 200)

  mod.events:on("save.loaded", function(ev)
    if ev and ev.save then state({ save = ev.save }) end
  end)
  mod.events:on("game.ready", function(ev)
    if ev and ev.game then state(ev.game) end
  end)

  R.gameplayRows = gameplayRows
  R.optionRows = optionRows
  R.ownsAnywhere = ownsAnywhere
  R.loot = loot
  return R
end
