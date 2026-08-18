-- Save-compatible adaptive trainer-level policy.
--
-- This module deliberately separates two contracts:
--   * classic: authored level + badge-phased Difficulty + rematch growth B;
--   * adaptive: authored level + badge-phased Difficulty is the immutable
--     floor, then one shared shift targets the player's party reference.
--
-- Rematch B still drives rank, evolution, recruits, AI and rewards outside
-- this module. It is suppressed only as a numeric level bonus while adaptive
-- mode is active. Every planner is pure; callers freeze one result for both
-- the warning preview and the real battle.

return function(mod, opts)
  opts = opts or {}
  local difficulty = assert(opts.difficulty,
    "adaptive trainer levels require difficulty policy")
  local A = {
    STATE_KEY = "adaptive_trainer_levels_state",
    STATE_VERSION = 1,
    OPTION_KEY = "adaptive_trainer_levels",
  }

  local VALID = {
    auto = true, off = true,
    ["-2"] = true, ["0"] = true, ["2"] = true, ["4"] = true,
    ["6"] = true, ["8"] = true,
  }
  local AUTO_GAP = {
    high = 1, hard = 2, very_hard = 3, extreme = 4,
  }
  local EXCLUDED = {
    "ascendantForcedBattle", "ascendantLegacyWanderer",
    "ascendantLegacyPath", "acceptanceBattle", "ascendantOakBeta",
    "ascendantDedicatedContext", "grandTourFacility",
  }
  local DAMAGING_EFFECT = {
    SPECIAL_DAMAGE_EFFECT = true, -- SonicBoom/Dragon Rage/level/Psywave
    SUPER_FANG_EFFECT = true,
    OHKO_EFFECT = true,
  }

  local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[clone(key, seen)] = clone(child, seen) end
    return out
  end

  local function integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) then return nil end
    if minimum and value < minimum then return nil end
    if maximum and value > maximum then return nil end
    return value
  end

  local function rounded(value)
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
  end

  function A.normalizeSelection(value)
    value = type(value) == "string" and value or tostring(value or "")
    return VALID[value] and value or nil
  end

  function A.effectiveGap(selection, difficultyName)
    selection = A.normalizeSelection(selection)
    if not selection or selection == "off" then return nil end
    if selection == "auto" then return AUTO_GAP[difficultyName] end
    return tonumber(selection)
  end

  function A.playerReference(party, pokemonData)
    if type(party) ~= "table" then return nil, { reason = "invalid_party" } end
    local total, count, highest = 0, 0, 0
    for _, mon in ipairs(party) do
      local species = type(mon) == "table" and mon.species
      local validSpecies = type(species) == "string" and species ~= ""
        and (type(pokemonData) ~= "table" or pokemonData[species] ~= nil)
      if validSpecies and mon.isEgg ~= true then
        local level = integer(mon.level, 1, 100)
        if level then
          total, count = total + level, count + 1
          highest = math.max(highest, level)
        end
      end
    end
    if count == 0 then return nil, { reason = "invalid_player_party" } end
    local mean = rounded(total / count)
    return mean, {
      mean = mean, highest = highest, count = count,
    }
  end

  local function validateRows(rows)
    if type(rows) ~= "table" or #rows < 1 or #rows > 6 then
      return nil, "invalid_authored_party"
    end
    local out = {}
    for index, row in ipairs(rows) do
      local level = type(row) == "table" and integer(row.level, 1, 100)
      if type(row) ~= "table" or type(row.species) ~= "string"
          or row.species == "" or not level then
        return nil, "invalid_authored_party"
      end
      out[index] = clone(row)
      out[index].level = level
    end
    return out
  end

  local function difficultyBonus(context)
    if type(context) ~= "table" then return nil end
    local direct = integer(context.difficultyBonus, 0, 99)
    if direct then return direct end
    local badges = integer(context.badges, 0, 8)
    if not badges or type(context.difficultyName) ~= "string"
        or type(difficulty.progressionBonus) ~= "function" then return nil end
    local ok, value = pcall(difficulty.progressionBonus,
      "trainer", badges, context.difficultyName)
    if not ok then return nil end
    return integer(value, 0, 99)
  end

  local function levelsMean(rows)
    local total = 0
    for _, row in ipairs(rows) do total = total + row.level end
    return rounded(total / #rows)
  end

  function A.previewGap(rows, playerParty, pokemonData)
    local validated = validateRows(rows)
    local reference = A.playerReference(playerParty, pokemonData)
    if not validated or not reference then return nil end
    return levelsMean(validated) - reference
  end

  local function levelCeiling(context)
    local raw = context and (context.maxLevel or context.ceiling)
    if raw == nil then return 100 end
    return integer(raw, 1, 100)
  end

  local function baseRows(rows, fixedBonus, rematchBoost)
    local out = clone(rows)
    for _, row in ipairs(out) do
      row.level = math.min(100, row.level + fixedBonus + rematchBoost)
    end
    return out
  end

  local function classicRematchRows(rows, fixedBonus, rematchBoost,
      originalCount)
    local out = clone(rows)
    for index, row in ipairs(out) do
      -- This intentionally preserves the pre-6.5.6 classic constructor:
      -- original slots already passed through trainer.party (D) while later
      -- appended recruits did not. Both then receive numeric rematch B.
      local fixed = index <= originalCount and fixedBonus or 0
      row.level = math.min(100, row.level + fixed + rematchBoost)
    end
    return out
  end

  -- Pure rematch planner. `rows` is the recruitment/evolution plan at its
  -- authored levels; classicBoost is B and has already influenced that plan.
  function A.planRematch(rows, playerParty, context)
    context = context or {}
    local authored, reason = validateRows(rows)
    if not authored then return nil, { reason = reason, fallback = "classic" } end
    local selection = A.normalizeSelection(context.selection)
    if not selection then
      return nil, { reason = "invalid_selection", fallback = "classic" }
    end
    local fixedBonus = difficultyBonus(context)
    local classicBoost = integer(context.classicBoost, 0, 99)
    local originalCount = integer(context.originalCount, 1, #authored)
    local ceiling = levelCeiling(context)
    if fixedBonus == nil or classicBoost == nil or not originalCount
        or ceiling == nil then
      return nil, { reason = "invalid_context", fallback = "classic" }
    end
    local gap = A.effectiveGap(selection, context.difficultyName)
    if gap == nil then
      local classic = classicRematchRows(
        authored, fixedBonus, classicBoost, originalCount)
      return classic, {
        mode = "classic", selection = selection,
        difficultyBonus = fixedBonus, classicBoost = classicBoost,
        teamMean = levelsMean(classic), originalCount = originalCount,
      }
    end

    local reference, referenceDetail = A.playerReference(
      playerParty, context.pokemon)
    if not reference then
      return nil, { reason = "invalid_player_party", fallback = "classic" }
    end
    local floor = baseRows(authored, fixedBonus, 0)
    local floorMean = levelsMean(floor)
    local targetMean = math.max(1, math.min(100, reference + gap))
    local shift = math.max(0, targetMean - floorMean)
    for _, row in ipairs(floor) do
      row.level = math.max(row.level, math.min(ceiling, row.level + shift))
    end
    return floor, {
      mode = "adaptive", selection = selection, gap = gap,
      playerReference = reference, player = referenceDetail,
      authoredFloorMean = floorMean, targetMean = targetMean, shift = shift,
      teamMean = levelsMean(floor), difficultyBonus = fixedBonus,
      levelCeiling = ceiling,
      classicBoostSuppressed = classicBoost,
    }
  end

  -- Story rows already include the fixed Difficulty bonus because they came
  -- through the authoritative trainer.party hook. This pure variant adds only
  -- the shared adaptive shift and never lowers that resolved floor.
  function A.planAdjusted(rows, playerParty, context)
    context = context or {}
    local adjusted, reason = validateRows(rows)
    if not adjusted then return nil, { reason = reason, fallback = "classic" } end
    local selection = A.normalizeSelection(context.selection)
    if not selection then
      return nil, { reason = "invalid_selection", fallback = "classic" }
    end
    local gap = A.effectiveGap(selection, context.difficultyName)
    if gap == nil then
      return adjusted, { mode = "classic", selection = selection,
        teamMean = levelsMean(adjusted) }
    end
    local reference, referenceDetail = A.playerReference(
      playerParty, context.pokemon)
    if not reference then
      return nil, { reason = "invalid_player_party", fallback = "classic" }
    end
    local floorMean = levelsMean(adjusted)
    local ceiling = levelCeiling(context)
    if ceiling == nil then
      return nil, { reason = "invalid_context", fallback = "classic" }
    end
    local targetMean = math.max(1, math.min(100, reference + gap))
    local shift = math.max(0, targetMean - floorMean)
    for _, row in ipairs(adjusted) do
      row.level = math.max(row.level, math.min(ceiling, row.level + shift))
    end
    return adjusted, {
      mode = "adaptive", selection = selection, gap = gap,
      playerReference = reference, player = referenceDetail,
      authoredFloorMean = floorMean, targetMean = targetMean, shift = shift,
      teamMean = levelsMean(adjusted), levelCeiling = ceiling,
    }
  end

  local function damagingMove(data, move)
    local id = type(move) == "table" and move.id or move
    local def = type(data) == "table" and type(data.moves) == "table"
      and data.moves[id]
    local fixedDamage = type(def) == "table"
      and DAMAGING_EFFECT[def.effect] == true
    return type(id) == "string" and type(def) == "table"
      and ((tonumber(def.power) or 0) > 0 or fixedDamage), id, def
  end

  function A.hasDamagingMove(data, moves)
    if type(moves) ~= "table" then return false end
    for _, move in ipairs(moves) do
      if damagingMove(data, move) then return true end
    end
    return false
  end

  -- Gen-I Day Care learning shifts the oldest move out when all four slots
  -- are full. Butterfree can consequently forget CONFUSION while crossing
  -- its powder levels and arrive with status moves only. This conservative
  -- post-growth guard first restores a damaging move the constructed trainer
  -- already knew, then considers a level-legal move, and only finally the
  -- weakest compatible TM/HM. It never runs for an unscaled or explicitly
  -- preserved authored moveset.
  function A.ensureDamagingMove(data, mon, speciesDef, previousMoves, target)
    if A.hasDamagingMove(data, mon and mon.moves) then return true end
    if type(mon) ~= "table" or type(speciesDef) ~= "table"
        or type(data) ~= "table" or type(data.moves) ~= "table" then
      return false, "invalid_move_context"
    end
    local chosen, chosenDef, chosenSlot
    for index = #(previousMoves or {}), 1, -1 do
      local move = previousMoves[index]
      local isDamage, _, def = damagingMove(data, move)
      if isDamage then
        chosen = type(move) == "table" and move.id or move
        chosenDef = def
        chosenSlot = type(move) == "table" and clone(move) or nil
        break
      end
    end
    if not chosen then
      local Pokemon = require("src.pokemon.Pokemon")
      local ok, atLevel = pcall(Pokemon.movesAtLevel,
        speciesDef, integer(target, 1, 100) or 1)
      if ok and type(atLevel) == "table" then
        for index = #atLevel, 1, -1 do
          local isDamage, id, def = damagingMove(data, atLevel[index])
          if isDamage then chosen, chosenDef = id, def break end
        end
      end
    end
    if not chosen then
      local weakestPower
      for _, id in ipairs(speciesDef.tmhm or {}) do
        local isDamage, candidate, def = damagingMove(data, id)
        local power = isDamage and tonumber(def.power) or nil
        if power and (not weakestPower or power < weakestPower
            or (power == weakestPower and candidate < chosen)) then
          chosen, chosenDef, weakestPower = candidate, def, power
        end
      end
    end
    if not chosen then return false, "no_legal_damaging_move" end
    chosenSlot = chosenSlot or { id = chosen, pp = chosenDef.pp or 0 }
    mon.moves = type(mon.moves) == "table" and mon.moves or {}
    if #mon.moves < 4 then
      mon.moves[#mon.moves + 1] = chosenSlot
    else
      local replace = 1
      for index, move in ipairs(mon.moves) do
        if not damagingMove(data, move) then replace = index break end
      end
      mon.moves[replace] = chosenSlot
    end
    return true, chosen
  end

  local function defaultGrow(game, mon, target, context)
    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local Growth = require("src.pokemon.Growth")
    local species = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    assert(species, "unknown adaptive trainer species " .. tostring(mon.species))
    local oldLevel = integer(mon.level, 1, 100)
    assert(oldLevel and target >= oldLevel, "invalid adaptive level target")
    if target == oldLevel then return end
    if not (context and context.preserveAuthoredMoves) then
      local previousMoves = clone(mon.moves)
      Pokemon.learnMovesFromDayCare(game.data, mon, species, oldLevel, target)
      A.ensureDamagingMove(game.data, mon, species, previousMoves, target)
    end
    mon.level = target
    mon.exp = Growth.expForLevel(species.growthRate, target,
      game.data.growth_rates)
    local fresh = Stats.calc(species, target, mon.dvs, mon.statExp, mon)
    mon.stats = mon.stats or {}
    for stat in pairs(mon.stats) do mon.stats[stat] = nil end
    for stat, value in pairs(fresh) do mon.stats[stat] = value end
    mon.hp = mon.stats.hp
  end
  local growMon = opts.growMon or defaultGrow

  -- Exact targets are applied atomically. Validation happens before the first
  -- mutation; runtime errors restore levels, moves, EXP, HP and stats in place.
  function A.applyBattleTargets(game, battle, targets, context)
    local party = battle and battle.enemyParty
    if type(party) ~= "table" or type(targets) ~= "table"
        or #party < 1 or #party ~= #targets then return false, "party_mismatch" end
    local snapshots = {}
    for index, mon in ipairs(party) do
      local row = targets[index]
      local oldLevel = type(mon) == "table" and integer(mon.level, 1, 100)
      local target = type(row) == "table" and integer(row.level, 1, 100)
      if type(mon) ~= "table" or type(row) ~= "table" or not oldLevel
          or not target or target < oldLevel
          or (not (context and context.allowSpeciesRemap)
            and mon.species ~= row.species) then
        return false, "target_mismatch"
      end
      snapshots[index] = {
        level = mon.level, exp = mon.exp, hp = mon.hp,
        stats = clone(mon.stats), moves = clone(mon.moves),
      }
    end
    local ok, err = pcall(function()
      for index, mon in ipairs(party) do
        local target = targets[index].level
        if target > mon.level then growMon(game, mon, target, context) end
      end
    end)
    if not ok then
      for index, mon in ipairs(party) do
        local old = snapshots[index]
        mon.level, mon.exp, mon.hp = old.level, old.exp, old.hp
        mon.stats, mon.moves = clone(old.stats), clone(old.moves)
      end
      return false, tostring(err)
    end
    if battle.enemy and battle.enemy.mon then
      battle.enemy.shownHP = battle.enemy.mon.hp
    end
    return true
  end

  local function state(create, legacyHold)
    local value = mod.save:get(A.STATE_KEY)
    if type(value) ~= "table" and create then
      value = { version = A.STATE_VERSION, legacyHold = legacyHold == true,
        explicit = false }
      mod.save:set(A.STATE_KEY, value)
    end
    if type(value) ~= "table" then return nil end
    value.version = A.STATE_VERSION
    value.legacyHold = value.legacyHold == true
    value.explicit = value.explicit == true
    return value
  end

  function A.currentSelection()
    local selected = A.normalizeSelection(mod.options:get(A.OPTION_KEY))
    if not selected then return nil end
    local saved = state(false)
    if saved and saved.legacyHold and not saved.explicit then return "off" end
    return selected
  end

  function A.currentGap()
    return A.effectiveGap(A.currentSelection(),
      mod.options:get("difficulty") or "standard")
  end

  function A.isAdaptive()
    return A.currentGap() ~= nil
  end

  function A.storyExcluded(battle)
    if not (battle and battle.kind == "trainer") or battle.rematch then return true end
    for _, key in ipairs(EXCLUDED) do if battle[key] then return true end end
    local save = battle.game and battle.game.save
    if save and ((type(save.hallOfFame) == "table" and #save.hallOfFame > 0)
        or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) then
      return true
    end
    return false
  end

  local function matchesResolved(party, rows)
    if type(party) ~= "table" or type(rows) ~= "table"
        or #party ~= #rows or #party < 1 then return false end
    for index, mon in ipairs(party) do
      local row = rows[index]
      if type(mon) ~= "table" or type(row) ~= "table"
          or mon.species ~= row.species
          or tonumber(mon.level) ~= tonumber(row.level) then return false end
    end
    return true
  end

  -- Clear API for ordinary story and Gym lanes. Callers with a dedicated
  -- battle can invoke this directly; the event adapter below uses the same
  -- pure planner and exact target transaction.
  function A.applyStoryBattle(battle)
    if A.storyExcluded(battle) or not A.isAdaptive() then return false, "classic" end
    local context = battle.ascendantDifficultyContext
    if type(context) ~= "table"
        or not matchesResolved(battle.enemyParty, context.adjustedParty) then
      return false, "invalid_context"
    end
    local targets, report = A.planAdjusted(context.adjustedParty,
      battle.game and battle.game.save and battle.game.save.party, {
        selection = A.currentSelection(),
        difficultyName = context.difficulty,
        pokemon = battle.game and battle.game.data
          and battle.game.data.pokemon,
        maxLevel = battle.ascendantStoryLevelCeiling
          or context.maxLevel or context.ceiling,
      })
    if not targets or report.mode ~= "adaptive" then
      return false, report and report.reason or "classic"
    end
    local applied, why = A.applyBattleTargets(battle.game, battle, targets, {
      preserveAuthoredMoves = battle.ascendantStoryGymDifficulty ~= nil
        or battle.ascendantStoryPreserveAuthoredMoves == true
        or battle.preserveAuthoredMoves == true
        or context.preserveAuthoredMoves == true,
    })
    if not applied then return false, why end
    battle.ascendantAdaptiveTrainerLevels = report
    return true, report
  end

  mod.events:on("save.created", function()
    state(true, false)
  end, 120)
  mod.events:on("save.loaded", function()
    -- A slot created before this state marker existed keeps its exact classic
    -- levels until the player deliberately revisits Difficulty or Adaptive.
    state(true, true)
  end, 120)
  mod.events:on("mod.options_changed", function(ev)
    if type(ev) ~= "table" or (ev.mod and ev.mod ~= mod.id) then return end
    local saved = state(true, true)
    if ev.key == A.OPTION_KEY then
      saved.explicit, saved.legacyHold = true, false
    elseif ev.key == "difficulty" and saved.legacyHold
        and A.normalizeSelection(mod.options:get(A.OPTION_KEY)) == "auto" then
      -- Reselecting Difficulty is an explicit opt-in to AUTO for an old slot.
      -- Manual Adaptive choices are never rewritten by Difficulty changes.
      saved.legacyHold = false
    end
  end, 120)
  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    A.applyStoryBattle(battle)
  end, -100)

  return A
end
