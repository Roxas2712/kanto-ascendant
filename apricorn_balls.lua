-- Isolated Apricorn Ball runtime package (P1).
--
-- The factory itself has no import-time side effect; main.lua constructs it
-- with the live breeding data / gender service and calls install() before
-- the content registries freeze.  The catch formula is entirely data-driven
-- and is installed as normal `content.balls` records, so it goes through
-- BattleState:catchAttempt rather than a UI-only preview.

return function(mod, opts)
  opts = opts or {}

  local A = {
    STATE_KEY = "apricorn_balls",
    STATE_VERSION = 1,
    FRIENDSHIP_ON_CATCH = 200,
    DISPLAY_WIDTH = 18,
    ITEM_IDS = {
      "HEAVY_BALL", "LEVEL_BALL", "LURE_BALL", "FAST_BALL",
      "LOVE_BALL", "FRIEND_BALL", "MOON_BALL",
    },
  }

  local breedingData = opts.breedingData or {}
  local speciesData = opts.speciesData or {}
  local genderService = opts.pokemonGender
  local itemEffects = opts.itemEffects
  local i18n = opts.i18n

  -- Gen1Recomp 0.1.86 and the public 0.1.90+ BagMenu discard an ItemEffects
  -- payload when the result is "ball": they consume and throw immediately.
  -- Keep the compatibility seam in the mod, scoped to that reviewed host
  -- family and to this package's own target-specific payload.  RC3-capable
  -- engines expose `BagMenu.nativeBallPreflight`; those hosts already show
  -- the payload and must never receive this second preview authority. The
  -- module-level state/bridge is
  -- deliberately stable across a dev hot reload; it never retains an old mod
  -- object, and restore() disables a buried wrapper or removes a directly
  -- owned one by identity.
  local BAG_PREVIEW_KEY = "__kantoAscendantApricornPreview0186"
  local BAG_PREVIEW_VERSION = 1

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local ITEM_NAMES = {
    HEAVY_BALL = function() return tr("HEAVY BALL", "SCHWERBALL") end,
    LEVEL_BALL = function() return tr("LEVEL BALL", "LEVELBALL") end,
    LURE_BALL = function() return tr("LURE BALL", "KÖDERBALL") end,
    FAST_BALL = function() return tr("FAST BALL", "TURBOBALL") end,
    LOVE_BALL = function() return tr("LOVE BALL", "LIEBESBALL") end,
    FRIEND_BALL = function() return tr("FRIEND BALL", "FREUNDSCHAFTSBALL") end,
    MOON_BALL = function() return tr("MOON BALL", "MONDBALL") end,
  }

  local function integer(value)
    value = tonumber(value)
    if not value then return nil end
    return math.floor(value)
  end

  local function clamp(value, lo, hi)
    return math.max(lo, math.min(hi, value))
  end

  local function lookupDef(ctx)
    local target = ctx and (ctx.targetMon or ctx.target)
    local def = ctx and ctx.targetDef
    if def then return def, target end
    local data = ctx and (ctx.data or (ctx.game and ctx.game.data)
      or (ctx.battle and ctx.battle.game and ctx.battle.game.data))
    return data and data.pokemon and target and data.pokemon[target.species], target
  end

  local function speciesId(def, mon)
    return (def and def.id) or (mon and mon.species)
  end

  local function catchRate(def)
    local value = integer(def and def.catchRate)
    if not value then return nil, "missing_catch_rate" end
    return clamp(value, 1, 255)
  end

  -- Johto definitions carry weightKg directly.  The base Kanto engine does
  -- not, so the checked-in #001-251 Pokecrystal-derived table supplies the
  -- same unit.  `weight` is accepted only for isolated test fixtures that
  -- explicitly label their unit; raw Gen-I fields must never be read as kg.
  local function weightKg(def)
    local value = tonumber(def and def.weightKg)
    if value and value >= 0 then return value end
    local dex = integer(def and def.dex)
    value = tonumber(dex and speciesData.weightKgByDex
      and speciesData.weightKgByDex[dex])
    if value and value >= 0 then return value end
    if def and def.weightUnit == "kg" then
      value = tonumber(def.weight)
      if value and value >= 0 then return value end
    end
    return nil, "missing_weight_kg"
  end

  local function baseSpeed(def)
    local stats = def and (def.baseStats or def.stats)
    local value = integer(stats and stats.speed)
    if value and value >= 1 then return value end
    return nil, "missing_base_speed"
  end

  local function genderOf(mon, data)
    if genderService and type(genderService.get) == "function" then
      return genderService.get(mon, data)
    end
    local def = data and data.pokemon and mon and data.pokemon[mon.species]
    local row = def and breedingData[def.dex]
    local ratio = integer(row and row.gender)
    if ratio == nil then return nil, "missing_gender_ratio" end
    if ratio < 0 then return "GENDERLESS" end
    if ratio == 0 then return "MALE" end
    if ratio >= 8 then return "FEMALE" end
    local attack = integer(mon and mon.dvs and mon.dvs.attack) or 0
    attack = clamp(attack, 0, 15)
    return attack < ratio * 2 and "FEMALE" or "MALE"
  end

  local function dataFor(ctx)
    return ctx and (ctx.data or (ctx.game and ctx.game.data)
      or (ctx.battle and ctx.battle.game and ctx.battle.game.data))
  end

  local function playerMon(ctx)
    if ctx and ctx.playerMon then return ctx.playerMon end
    local battle = ctx and ctx.battle
    return battle and battle.player and battle.player.mon
  end

  local function isFishing(ctx)
    local battle = ctx and ctx.battle
    -- `encounterSource=fishing` is stamped by the battle.wild hook below
    -- only when BattleState.newWild receives opts.hooked from goFishing.
    -- Water terrain, a fishing rod in the Bag, or an arbitrary encounter
    -- label are deliberately not enough for the Lure Ball bonus.
    return (ctx and ctx.encounterSource == "fishing")
      or (battle and battle.encounterSource == "fishing")
  end

  local function evolutionFields(row)
    if type(row) ~= "table" then return nil, nil, nil end
    return row.method or row[1], row.species or row[2], row.item or row[3]
  end

  -- This is deliberately calculated from the merged live evolution registry
  -- rather than a hand-maintained species list.  Starting at every explicit
  -- MOON_STONE edge and walking both directions includes babies and final
  -- forms while automatically following any future registry correction.
  local function moonStoneLine(data, wanted)
    local pokemon = data and data.pokemon
    if type(pokemon) ~= "table" then return nil, "missing_evolution_registry" end
    local forward, reverse, frontier, seen = {}, {}, {}, {}
    for id, def in pairs(pokemon) do
      for _, row in ipairs(def.evolutions or {}) do
        local _, target, item = evolutionFields(row)
        if target and pokemon[target] then
          forward[id] = forward[id] or {}
          reverse[target] = reverse[target] or {}
          forward[id][target], reverse[target][id] = true, true
          if item == "MOON_STONE" then
            frontier[#frontier + 1], frontier[#frontier + 2] = id, target
          end
        end
      end
    end
    if #frontier == 0 then return nil, "missing_moon_stone_registry" end
    local index = 1
    while frontier[index] do
      local id = frontier[index]
      index = index + 1
      if not seen[id] then
        seen[id] = true
        for nextId in pairs(forward[id] or {}) do frontier[#frontier + 1] = nextId end
        for nextId in pairs(reverse[id] or {}) do frontier[#frontier + 1] = nextId end
      end
    end
    return seen[wanted] == true
  end

  local function blocked(ctx)
    local battle = ctx and ctx.battle
    if battle and battle.kind and battle.kind ~= "wild" then return "trainer_battle" end
    if battle and (battle.noCatch or battle.ghost) then return "story_blocked" end
    if ctx and (ctx.noCatch or ctx.storyBlocked) then return "story_blocked" end
    return nil
  end

  local function unavailable(ball, reason, def, mon)
    return {
      ball = ball, available = false, reason = reason, target = speciesId(def, mon),
      multiplier = nil, rate = nil,
    }
  end

  local function result(ball, reason, def, mon, rate, multiplier, extra)
    local row = {
      ball = ball, available = true, reason = reason, target = speciesId(def, mon),
      baseRate = catchRate(def), rate = rate, multiplier = multiplier,
    }
    for key, value in pairs(extra or {}) do row[key] = value end
    return row
  end

  -- Public inspection seam shared by future UI and by the Catching.attempt
  -- callback.  A missing required data field is explicitly unavailable;
  -- callers must not disguise it as a neutral multiplier.
  function A.quote(ball, ctx)
    if type(ball) ~= "string" then return unavailable(ball, "unknown_ball") end
    local stop = blocked(ctx)
    if stop then return unavailable(ball, stop) end
    local def, target = lookupDef(ctx)
    if not def then return unavailable(ball, "missing_species_data") end
    local base, rateErr = catchRate(def)
    if not base then return unavailable(ball, rateErr, def, target) end

    if ball == "HEAVY_BALL" then
      local kg, err = weightKg(def)
      if not kg then return unavailable(ball, err, def, target) end
      local delta = kg >= 300 and 30 or kg >= 200 and 20 or kg >= 100 and 0 or -20
      return result(ball, delta == 30 and "weight_300kg_plus"
        or delta == 20 and "weight_200kg_to_299kg" or delta == 0
          and "weight_100kg_to_199kg" or "weight_under_100kg",
        def, target, clamp(base + delta, 1, 255), 1, { weightKg = kg, rateDelta = delta })
    elseif ball == "LEVEL_BALL" then
      local player = playerMon(ctx)
      local playerLevel, targetLevel = integer(player and player.level), integer(target and target.level)
      if not playerLevel then return unavailable(ball, "missing_player_level", def, target) end
      if not targetLevel then return unavailable(ball, "missing_target_level", def, target) end
      local mult = playerLevel >= targetLevel * 4 and 8
        or playerLevel >= targetLevel * 2 and 4
        or playerLevel > targetLevel and 2 or 1
      return result(ball, "level_ratio_x" .. mult, def, target,
        clamp(base * mult, 1, 255), mult,
        { playerLevel = playerLevel, targetLevel = targetLevel })
    elseif ball == "LURE_BALL" then
      local mult = isFishing(ctx) and 3 or 1
      return result(ball, mult == 3 and "fishing" or "not_fishing", def, target,
        clamp(base * mult, 1, 255), mult)
    elseif ball == "FAST_BALL" then
      local speed, err = baseSpeed(def)
      if not speed then return unavailable(ball, err, def, target) end
      local mult = speed >= 100 and 4 or 1
      return result(ball, mult == 4 and "base_speed_100_plus" or "base_speed_under_100",
        def, target, clamp(base * mult, 1, 255), mult, { baseSpeed = speed })
    elseif ball == "LOVE_BALL" then
      local player = playerMon(ctx)
      if not player then return unavailable(ball, "missing_player_species", def, target) end
      if player.species ~= target.species then
        return result(ball, "different_species", def, target, base, 1)
      end
      local data = dataFor(ctx)
      local playerGender, playerErr = genderOf(player, data)
      local targetGender, targetErr = genderOf(target, data)
      if not playerGender then return unavailable(ball, playerErr, def, target) end
      if not targetGender then return unavailable(ball, targetErr, def, target) end
      local mult = playerGender ~= "GENDERLESS" and targetGender ~= "GENDERLESS"
        and playerGender ~= targetGender and 8 or 1
      return result(ball, mult == 8 and "same_species_opposite_gender"
        or "same_species_same_or_genderless", def, target, clamp(base * mult, 1, 255), mult,
        { playerGender = playerGender, targetGender = targetGender })
    elseif ball == "FRIEND_BALL" then
      return result(ball, "friendship_200_on_success", def, target, base, 1,
        { friendshipOnSuccess = A.FRIENDSHIP_ON_CATCH })
    elseif ball == "MOON_BALL" then
      local inLine, err = moonStoneLine(dataFor(ctx), speciesId(def, target))
      if inLine == nil then return unavailable(ball, err, def, target) end
      local mult = inLine and 4 or 1
      return result(ball, mult == 4 and "moon_stone_line" or "not_moon_stone_line",
        def, target, clamp(base * mult, 1, 255), mult)
    end
    return unavailable(ball, "unknown_ball", def, target)
  end

  -- The battle Bag and the actual catch callback share this formatter.  It
  -- deliberately uses two authored 18-glyph lines: the first is the bonus
  -- that is effective for this exact target, the second is the live reason.
  -- No species name is repeated here because the enemy HUD already owns it.
  local function glyphCount(text)
    local count = 0
    for index = 1, #text do
      local byte = text:byte(index)
      if byte < 0x80 or byte >= 0xC0 then count = count + 1 end
    end
    return count
  end

  function A.formatQuote(quote)
    if type(quote) ~= "table" or quote.available ~= true then
      return nil, quote and quote.reason or "missing_quote"
    end

    local bonus
    if quote.ball == "HEAVY_BALL" then
      local delta = integer(quote.rateDelta) or 0
      if delta > 0 then
        bonus = tr("CATCH RATE UP " .. delta, "FANGRATE PLUS " .. delta)
      elseif delta < 0 then
        bonus = tr("CATCH RATE DOWN " .. math.abs(delta),
          "FANGRATE MINUS " .. math.abs(delta))
      else
        bonus = tr("CATCH RATE SAME", "FANGRATE GLEICH")
      end
    else
      bonus = tr("CATCH RATE x" .. tostring(quote.multiplier or 1),
        "FANGRATE x" .. tostring(quote.multiplier or 1))
    end

    local reason = ({
      weight_300kg_plus = function()
        return tr("WEIGHT 300 OR MORE", "GEWICHT AB 300 KG")
      end,
      weight_200kg_to_299kg = function() return tr("WEIGHT 200-299 KG", "GEWICHT 200-299") end,
      weight_100kg_to_199kg = function() return tr("WEIGHT 100-199 KG", "GEWICHT 100-199") end,
      weight_under_100kg = function() return tr("WEIGHT UNDER 100", "GEWICHT UNTER 100") end,
      level_ratio_x8 = function()
        return tr(("LV%d VS LV%d"):format(quote.playerLevel, quote.targetLevel),
          ("LV%d GEGEN LV%d"):format(quote.playerLevel, quote.targetLevel))
      end,
      level_ratio_x4 = function()
        return tr(("LV%d VS LV%d"):format(quote.playerLevel, quote.targetLevel),
          ("LV%d GEGEN LV%d"):format(quote.playerLevel, quote.targetLevel))
      end,
      level_ratio_x2 = function()
        return tr(("LV%d VS LV%d"):format(quote.playerLevel, quote.targetLevel),
          ("LV%d GEGEN LV%d"):format(quote.playerLevel, quote.targetLevel))
      end,
      level_ratio_x1 = function()
        return tr(("LV%d VS LV%d"):format(quote.playerLevel, quote.targetLevel),
          ("LV%d GEGEN LV%d"):format(quote.playerLevel, quote.targetLevel))
      end,
      fishing = function() return tr("HOOKED BY FISHING", "WILD GEANGELT") end,
      not_fishing = function() return tr("NOT HOOKED", "NICHT GEANGELT") end,
      base_speed_100_plus = function()
        return tr("BASE SPEED HIGH", "BASIS-INIT. HOCH")
      end,
      base_speed_under_100 = function()
        return tr("BASE SPEED LOW", "BASIS-INIT. NIED.")
      end,
      same_species_opposite_gender = function()
        return tr("SPECIES GENDER OK", "ART GESCHLECHT OK")
      end,
      different_species = function() return tr("DIFFERENT SPECIES", "ANDERE ART") end,
      same_species_same_or_genderless = function()
        return tr("NO OPPOSITE PAIR", "KEIN GEGENPAAR")
      end,
      friendship_200_on_success = function()
        return tr("CATCH: FRIEND 200", "FANG: FREUNDS.200")
      end,
      moon_stone_line = function() return tr("MOON STONE LINE", "MONDSTEIN-LINIE") end,
      not_moon_stone_line = function()
        return tr("NO MOON STONE LINE", "KEINE MOND-LINIE")
      end,
    })[quote.reason]
    reason = reason and reason() or nil
    if not reason then return nil, "unknown_display_reason:" .. tostring(quote.reason) end

    local lines = { bonus, reason }
    for _, line in ipairs(lines) do
      if glyphCount(line) > A.DISPLAY_WIDTH then
        return nil, "quote_overflow:" .. line
      end
    end
    local effective
    if quote.ball == "HEAVY_BALL" then
      effective = quote.rateDelta > 0 and "positive"
        or quote.rateDelta < 0 and "negative" or "neutral"
    elseif quote.reason == "friendship_200_on_success" then
      effective = "positive"
    else
      effective = (quote.multiplier or 1) > 1 and "positive" or "negative"
    end
    return {
      text = table.concat(lines, "\n"), lines = lines,
      bonus = bonus, reason = reason, effective = effective,
      maxGlyphs = math.max(glyphCount(bonus), glyphCount(reason)),
    }
  end

  function A.formattedQuote(ball, ctx)
    local quote = A.quote(ball, ctx)
    local formatted, err = A.formatQuote(quote)
    if formatted then quote.formatted = formatted end
    return quote, formatted, err
  end

  function A.validateSpecies(data)
    local missing, count = {}, 0
    for id, def in pairs(data and data.pokemon or {}) do
      local dex = integer(def.dex)
      if dex and dex >= 1 and dex <= 251 then
        count = count + 1
        local _, weightErr = weightKg(def)
        local _, speedErr = baseSpeed(def)
        local ratio = breedingData[dex] and integer(breedingData[dex].gender)
        if weightErr or speedErr or ratio == nil then
          missing[#missing + 1] = { id = id, dex = dex, weight = weightErr,
            speed = speedErr, gender = ratio == nil and "missing_gender_ratio" or nil }
        end
      end
    end
    table.sort(missing, function(a, b) return a.dex < b.dex end)
    return { complete = count == 251 and #missing == 0, species = count, missing = missing }
  end

  local function normalizedState(raw)
    raw = type(raw) == "table" and raw or {}
    -- v0 only had an in-memory friend-ball marker in pre-integration builds.
    -- Preserve the completed capture identities but never award friendship
    -- during migration: awards happen solely from pokemon.caught.
    local out = { version = A.STATE_VERSION, migrated = raw.migrated == true }
    if type(raw.friendCatchLedger) == "table" then
      out.migrated = true
      out.legacyFriendCatchLedger = raw.friendCatchLedger
    end
    return out
  end

  function A.state(create)
    if not (mod and mod.save and mod.save.get and mod.save.set) then return nil end
    local raw = mod.save:get(A.STATE_KEY)
    if type(raw) ~= "table" and create == false then return nil end
    local state = normalizedState(raw)
    if type(raw) ~= "table" or raw.version ~= A.STATE_VERSION
        or raw.friendCatchLedger ~= nil then mod.save:set(A.STATE_KEY, state) end
    return state
  end

  function A.migrate()
    return A.state(true)
  end

  function A.applyFriendship(mon)
    if type(mon) ~= "table" then return false, "missing_caught_mon" end
    if mon.apricornFriendBallApplied == true then return false, "already_applied" end
    mon.johtoBond = math.max(tonumber(mon.johtoBond) or 0, A.FRIENDSHIP_ON_CATCH)
    mon.apricornFriendBallApplied = true
    return true, "friendship_200_on_success"
  end

  local function attemptFor(ball)
    return function(ctx)
      local quote = A.formattedQuote(ball, {
        battle = ctx.battle, targetMon = ctx.targetMon, targetDef = ctx.targetDef,
      })
      if not quote.available then
        -- Missing metadata is a deterministic, inspectable refusal rather
        -- than a concealed neutral catch roll.  The UI can show `reason` via
        -- battle.apricornBallQuote before the ball is consumed.
        if ctx.battle then ctx.battle.apricornBallQuote = quote end
        return false, 0
      end
      if ctx.battle then ctx.battle.apricornBallQuote = quote end
      ctx.rateOverride = quote.rate
      return ctx.vanillaAttempt()
    end
  end

  local function preflightFor(ball)
    return function(data, save, itemId, target, battle)
      -- Stock 0.1.86 passes one context table; newer engines can dispatch the
      -- declared legacyArgs form. Normalize both before evaluating the throw.
      if save == nil and itemId == nil and type(data) == "table"
          and data.data ~= nil and data.itemId ~= nil then
        local context = data
        data, save, itemId, target, battle = context.data, context.save,
          context.itemId, context.target, context.battle
      end
      -- ItemEffects is also queried by engine/UI callers that only ask
      -- whether an item is a battle ball.  There is no target to validate at
      -- that point, so retain the stock ball category; an actual throw always
      -- reaches `attemptFor` with the live target and performs the strict
      -- metadata/trainer/story checks below.
      if battle and not (battle.enemy and battle.enemy.mon) then
        if battle.kind and battle.kind ~= "wild" then
          local quote = A.quote(ball, { data = data, battle = battle })
          if battle then battle.apricornBallQuote = quote end
          return "failed", { tr("This BALL can't be used now.",
            "Dieser BALL kann jetzt nicht benutzt werden.") },
            { apricornQuote = quote }
        end
        return "ball"
      end
      local quote, formatted, formatErr = A.formattedQuote(ball, {
        data = data, battle = battle,
        targetMon = battle and battle.enemy and battle.enemy.mon,
        targetDef = battle and battle.enemy and battle.enemy.def,
      })
      if quote.available and formatted then
        if battle then battle.apricornBallQuote = quote end
        return "ball", { formatted.text }, {
          apricornQuote = quote, apricornDisplay = formatted,
        }
      end
      if quote.available then
        quote.available, quote.reason = false, formatErr or "display_unavailable"
      end
      if battle then battle.apricornBallQuote = quote end
      return "failed", { tr("This BALL can't be used now.",
        "Dieser BALL kann jetzt nicht benutzt werden.") },
        { apricornQuote = quote }
    end
  end

  local function installStock0186BagPreview(effects)
    local okVersion, Version = pcall(require, "src.core.Version")
    local supported = okVersion and Version and Version.engine == "0.1.86"
    if okVersion and Version and not supported then
      local okSemver, Semver = pcall(require, "src.mods.Semver")
      supported = okSemver and Semver
        and (Semver.compare(Version.engine, "0.1.90") or -1) >= 0
    end
    if not supported then
      return false, "not_stock_0186"
    end

    local BagMenu = require("src.ui.BagMenu")
    if BagMenu.nativeBallPreflight == true then
      -- A process-stable dev import may have installed the compatibility
      -- wrapper before the host capability became visible.  Retire a directly
      -- owned wrapper and always deactivate/forget a buried one: its live
      -- lookup then delegates without opening a second TextBox.
      local prior = rawget(BagMenu, BAG_PREVIEW_KEY)
      if type(prior) == "table" and prior.version == BAG_PREVIEW_VERSION then
        if prior.bridge then prior.bridge.active = false end
        if BagMenu.new == prior.wrappedNew then
          BagMenu.new = prior.originalNew
        end
        rawset(BagMenu, BAG_PREVIEW_KEY, nil)
      end
      A.stockBagPreview0186 = nil
      return false, "native_ball_preflight"
    end
    local TextBox = require("src.render.TextBox")
    local ids = {}
    for _, id in ipairs(A.ITEM_IDS) do ids[id] = true end
    local bridge = {
      active = true,
      effects = assert(effects, "Apricorn Bag preview requires ItemEffects"),
      ids = ids,
      textBox = TextBox,
    }

    local prior = rawget(BagMenu, BAG_PREVIEW_KEY)
    if type(prior) == "table"
        and prior.version == BAG_PREVIEW_VERSION
        and type(prior.wrappedNew) == "function" then
      -- Later Ascendant presentation wrappers can legitimately sit above
      -- this one.  Refreshing the bridge keeps that chain intact and avoids
      -- stacking another preview on hot import.
      prior.bridge = bridge
      A.stockBagPreview0186 = prior
      return true, "refreshed"
    end

    local originalNew = assert(BagMenu.new, "BagMenu.new is unavailable")
    local state = {
      version = BAG_PREVIEW_VERSION,
      originalNew = originalNew,
      bridge = bridge,
    }
    local function wrappedNew(game, bagOpts)
      local list = originalNew(game, bagOpts)
      local battle = bagOpts and bagOpts.battle
      if not (battle and list and type(list.onChoose) == "function") then
        return list
      end

      local originalChoose = list.onChoose
      list.onChoose = function(item, liveList)
        local current = rawget(BagMenu, BAG_PREVIEW_KEY)
        local live = current and current.bridge
        local id = item and item.value
        local menu = liveList or list
        -- SELECT/A still completes the stock reorder operation.  Only a real
        -- battle-ball choice may be intercepted.
        if not (live and live.active and live.ids[id]) or menu.swapIndex then
          return originalChoose(item, liveList)
        end

        local result, payload, extra = live.effects.use(
          game.data, game.save, id, nil, battle, nil, game.overworld)
        local quote = type(extra) == "table" and extra.apricornQuote or nil
        local display = type(extra) == "table" and extra.apricornDisplay or nil
        if result ~= "ball" or type(payload) ~= "table" or #payload == 0
            or type(quote) ~= "table" or quote.ball ~= id
            or type(display) ~= "table" or display.text ~= payload[1] then
          return originalChoose(item, liveList)
        end

        -- Leave the Bag underneath the TextBox.  TextBox pops itself first;
        -- the callback then invokes the captured stock choice exactly once,
        -- where the reviewed stock host revalidates, consumes, closes and
        -- throws normally.
        game.stack:push(live.textBox.new(game, table.concat(payload, "\f"),
          function() originalChoose(item, menu) end))
        return true
      end
      return list
    end

    state.wrappedNew = wrappedNew
    state.restore = function()
      if state.bridge then state.bridge.active = false end
      if BagMenu.new ~= wrappedNew then return false, "not_direct_owner" end
      BagMenu.new = originalNew
      if rawget(BagMenu, BAG_PREVIEW_KEY) == state then
        rawset(BagMenu, BAG_PREVIEW_KEY, nil)
      end
      return true
    end
    BagMenu.new = wrappedNew
    rawset(BagMenu, BAG_PREVIEW_KEY, state)
    A.stockBagPreview0186 = state
    return true, "installed"
  end

  -- Public only as an inspectable lifecycle seam for the exact-engine gate:
  -- a hot import refreshes the bridge without stacking another constructor.
  function A.refreshStock0186BagPreview()
    local effects = itemEffects
    if not effects then
      local ok, loaded = pcall(require, "src.inventory.ItemEffects")
      if ok then effects = loaded end
    end
    return installStock0186BagPreview(effects)
  end

  function A.install()
    assert(mod and mod.content and mod.content.items and mod.content.balls
        and mod.content.item_effects,
      "Apricorn Balls require item, ball and item-effect registries")
    for _, id in ipairs(A.ITEM_IDS) do
      local effectId = "KA_APRICORN_" .. id
      mod.content.balls:register(id, {
        -- This is the existing engine's Ultra toss timing, deliberately not
        -- fabricated Apricorn art.  See docs/APRICORN_BALLS_P1_DE.md.
        randMax = 255, hpFactor = 12, wobbleFactor = 255,
        tossAnim = "ULTRATOSS_ANIM", attempt = attemptFor(id),
      })
      mod.content.items:register(id, {
        id = id, name = ITEM_NAMES[id](), price = 1000, tossable = true,
        needsTarget = false, ball = id, effect = effectId,
      })
      mod.content.item_effects:register(effectId, {
        battle = true, field = false, callStyle = "legacyArgs",
        use = preflightFor(id),
      })
    end
    local effects = itemEffects
    if not effects then
      local ok, loaded = pcall(require, "src.inventory.ItemEffects")
      if ok then effects = loaded end
    end
    if effects and type(effects.BALLS) == "table" then
      for _, id in ipairs(A.ITEM_IDS) do effects.BALLS[id] = true end
    end
    local previewInstalled, previewReason = A.refreshStock0186BagPreview()
    if previewReason ~= "not_stock_0186"
        and previewReason ~= "native_ball_preflight" then
      assert(previewInstalled, "Apricorn Bag preview compatibility failed")
    end
    if mod.events and mod.events.on then
      mod.events:on("pokemon.caught", function(ev)
        if ev and ev.ball == "FRIEND_BALL" then A.applyFriendship(ev.mon) end
      end)
    end
    if mod.hooks and mod.hooks.wrap then
      mod.hooks:wrap("battle.wild", function(nextEncounter, encounter, ctx)
        -- BattleState retains opts.encounterSource after this hook returns.
        -- Mark exactly the native rod path, never a generic water encounter.
        if ctx and ctx.opts and ctx.opts.hooked == true then
          ctx.opts.encounterSource = "fishing"
        end
        return nextEncounter(encounter)
      end, 100)
    end
    A.migrate()
    A.moonStoneLine = moonStoneLine
    return A
  end

  return A
end
