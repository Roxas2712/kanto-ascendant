-- Rematch 2.0 mastery progression.
--
-- Level 100 is an absolute ceiling.  Continued trainer history improves the
-- legal Gen-I stat inputs and increasingly coherent movesets instead.  This
-- module is deliberately data-driven and pure apart from Stats.calc so it can
-- be audited without running the battle AI.

local M = {}

local MAX_LEVEL = 100
local MAX_DV = 15
local MAX_STAT_EXP = 65535
local STAT_KEYS = { "attack", "defense", "speed", "special" }

local JOHTO_MOVE_IDS = {
  CRUNCH = true, METAL_CLAW = true, IRON_TAIL = true,
  SHADOW_BALL = true, FLAME_WHEEL = true, GIGA_DRAIN = true,
  SLUDGE_BOMB = true, SPARK = true, POWDER_SNOW = true,
  SACRED_FIRE = true, AEROBLAST = true,
}

-- These attacks can exist in the merged registry and a species compatibility
-- list before the owning save has earned their extended-move authority.
-- Registration and tmhm membership are therefore necessary but not
-- sufficient legal sources for trainer mastery.
local EXTENDED_MOVE_IDS = {
  OVERHEAT = true,
  FRENZY_PLANT = true, BLAST_BURN = true, HYDRO_CANNON = true,
}

local RECOVERY = {
  RECOVER = true, REST = true, SOFTBOILED = true,
}
local SETUP = {
  ACID_ARMOR = true, AGILITY = true, AMNESIA = true, BARRIER = true,
  DEFENSE_CURL = true, DOUBLE_TEAM = true, FOCUS_ENERGY = true,
  GROWTH = true, HARDEN = true, MEDITATE = true, MINIMIZE = true,
  REFLECT = true, LIGHT_SCREEN = true, SHARPEN = true,
  SWORDS_DANCE = true, WITHDRAW = true,
}
local STATUS = {
  CONFUSE_RAY = true, GLARE = true, HYPNOSIS = true, LEECH_SEED = true,
  LOVELY_KISS = true, POISONPOWDER = true, SING = true,
  SLEEP_POWDER = true, SPORE = true, STUN_SPORE = true,
  SUPERSONIC = true, THUNDER_WAVE = true, TOXIC = true,
}
local UTILITY = {
  DISABLE = true, HAZE = true, MIST = true, ROAR = true,
  SAND_ATTACK = true, SCREECH = true, SMOKESCREEN = true,
  SUBSTITUTE = true, TAIL_WHIP = true, TELEPORT = true,
}
local TACTICAL_KEEP = {
  MINIMIZE = true, RECOVER = true, REST = true, SOFTBOILED = true,
  SWORDS_DANCE = true, AMNESIA = true, SLEEP_POWDER = true,
  SPORE = true, THUNDER_WAVE = true, TOXIC = true,
}

local SPECIAL_TYPES = {
  FIRE = true, WATER = true, GRASS = true, ELECTRIC = true,
  ICE = true, PSYCHIC = true, PSYCHIC_TYPE = true, DRAGON = true,
  DARK = true,
}

local function integer(value, fallback, lo, hi)
  value = math.floor(tonumber(value) or fallback)
  return math.max(lo, math.min(hi, value))
end

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, tonumber(value) or lo))
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = copy(child) end
  return out
end

local function stableFraction(text)
  text = tostring(text or "")
  local hash = 0
  for i = 1, #text do
    -- Small operands stay exactly representable in Lua's number type on
    -- every supported runtime, so save-to-save quality is deterministic.
    hash = (hash * 131 + text:byte(i)) % 1000003
  end
  return (hash % 1001) / 1000
end

local function masteryBand(level, progress, wins, context)
  level = integer(level, 1, 1, MAX_LEVEL)
  progress = math.max(0, math.floor(tonumber(progress) or 0))
  wins = math.max(0, math.floor(tonumber(wins) or 0))
  local overflow = math.max(0, math.floor(tonumber(
    context and context.difficultyOverflow) or 0))
  if context and context.perfect == true and level == MAX_LEVEL then
    return 1, 1, "perfect"
  end
  if level == MAX_LEVEL and overflow > 0 then
    -- Difficulty overflow is deliberately much gentler than persistent
    -- rematch mastery: even EXTREME can only enter a 62-74% quality band.
    local bump = math.min(0.08, overflow * 0.008)
    return 0.61 + bump, 0.66 + bump, "difficulty"
  end
  if level < MAX_LEVEL then
    local phase = clamp(progress / 24, 0, 1)
    return 0.38 + phase * 0.24, 0.48 + phase * 0.25, "training"
  end
  local low, high, tier
  if wins <= 0 then low, high, tier = 0.70, 0.80, "cap"
  elseif wins <= 2 then low, high, tier = 0.75, 0.85, "bronze"
  elseif wins <= 5 then low, high, tier = 0.80, 0.90, "silver"
  elseif wins <= 9 then low, high, tier = 0.85, 0.95, "gold"
  else low, high, tier = 0.90, 1.00, "perfect" end
  if context and context.specialist then
    low, high = math.min(0.98, low + 0.025), math.min(1, high + 0.025)
  end
  if context and context.champion then
    low, high = math.min(0.99, low + 0.025), math.min(1, high + 0.025)
  end
  return low, high, tier
end

local function targetQuality(mon, context, index)
  local low, high, tier = masteryBand(mon.level, context.progress,
    context.masteryWins, context)
  local seed = table.concat({ context.key or context.kind or "trainer",
    mon.species or "?", tostring(index or 1) }, ":")
  return low + (high - low) * stableFraction(seed), tier, low, high
end

local function statExpForQuality(quality)
  -- DVs carry early mastery.  Stat EXP grows slowly at first and becomes the
  -- safe long-term progression channel near perfection.
  local fraction = clamp((quality - 0.70) / 0.30, 0, 1)
  return integer(MAX_STAT_EXP * fraction * fraction, 0, 0, MAX_STAT_EXP)
end

local function hpDv(dvs)
  return (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4
    + (dvs.speed % 2) * 2 + (dvs.special % 2)
end

local function moveClass(id, def)
  if RECOVERY[id] then return "recovery" end
  if SETUP[id] then return "setup" end
  if STATUS[id] then return "status" end
  if UTILITY[id] then return "utility" end
  if (tonumber(def and def.power) or 0) > 0 then return "damage" end
  return "utility"
end

local function roleFor(species)
  local base = species and (species.baseStats or species.stats) or {}
  local attack = tonumber(base.attack) or 0
  local special = tonumber(base.special) or 0
  local bulk = (tonumber(base.hp) or 0) + (tonumber(base.defense) or 0)
  if bulk >= attack + special and bulk >= 150 then return "bulky" end
  if attack >= special * 1.25 then return "physical" end
  if special >= attack * 1.25 then return "special" end
  return "mixed"
end

local function damageCategory(def)
  if def and (def.category == "physical" or def.category == "special") then
    return def.category
  end
  return SPECIAL_TYPES[def and def.type] and "special" or "physical"
end

local function hasType(types, wanted)
  for _, kind in ipairs(types or {}) do
    if kind == wanted
        or (kind == "PSYCHIC_TYPE" and wanted == "PSYCHIC")
        or (kind == "PSYCHIC" and wanted == "PSYCHIC_TYPE") then return true end
  end
  return false
end

local function scoreMove(id, def, species, role, teamTypes)
  local class = moveClass(id, def)
  local score
  if class == "damage" then
    local accuracy = tonumber(def.accuracy) or 100
    if accuracy <= 0 then accuracy = 100 end
    score = (tonumber(def.power) or 0) * clamp(accuracy, 1, 100) / 100
    if hasType(species and species.types, def.type) then score = score + 28 end
    local category = damageCategory(def)
    if role == category or role == "mixed" then score = score + 12 end
    if def.highCrit then score = score + 8 end
    if teamTypes and def.type and not teamTypes[def.type] then score = score + 7 end
  elseif class == "recovery" then score = role == "bulky" and 108 or 94
  elseif class == "setup" then score = role == "bulky" and 87 or 96
  elseif class == "status" then score = role == "bulky" and 103 or 91
  else score = 68 end
  if TACTICAL_KEEP[id] then score = score + 8 end
  return score, class
end

local function legalMoves(game, mon, context)
  local data = game and game.data or {}
  local species = data.pokemon and data.pokemon[mon.species]
  local legal, source = {}, {}
  local johtoUnlocked = context.johtoUnlocked == true
  local resonance = context.resonanceRules
    and context.resonanceRules[mon.species]
  local function speciesAllowsExtended(id)
    for _, moveId in ipairs(species and species.level1Moves or {}) do
      if moveId == id then return true end
    end
    for _, row in ipairs(species and species.learnset or {}) do
      if row.move == id and integer(row.level, 1, 1, 100)
          <= integer(mon.level, 1, 1, 100) then return true end
    end
    for _, moveId in ipairs(species and species.tmhm or {}) do
      if moveId == id then return true end
    end
    local rule = resonance and resonance[id]
    return johtoUnlocked and rule ~= nil
      and (not rule.level or integer(mon.level, 1, 1, 100) >= rule.level)
  end
  local function add(id, why)
    if type(id) ~= "string" or not (data.moves and data.moves[id]) then return end
    if JOHTO_MOVE_IDS[id] and not johtoUnlocked then return end
    if EXTENDED_MOVE_IDS[id] then
      if type(context.extendedMoveAllowed) ~= "function" then return end
      local ok, allowed, compatible = pcall(context.extendedMoveAllowed,
        game, mon.species, id, context)
      if not ok or allowed ~= true
          or not (speciesAllowsExtended(id) or compatible == true) then return end
    end
    if not legal[id] then legal[id], source[id] = true, why end
  end
  -- Authored trainer moves are an explicit legal source and must not be
  -- erased merely because a compact fixture lacks the complete learnset.
  for _, move in ipairs(mon.moves or {}) do add(move.id, "authored") end
  for _, id in ipairs(species and species.level1Moves or {}) do add(id, "level1") end
  for _, row in ipairs(species and species.learnset or {}) do
    if integer(row.level, 1, 1, 100) <= integer(mon.level, 1, 1, 100) then
      add(row.move, "level")
    end
  end
  for _, id in ipairs(species and species.tmhm or {}) do add(id, "tmhm") end
  -- Crown signature compatibility is owned by Field Tech rather than the
  -- Gen-I registry's tmhm projection. Try each registered extended move so
  -- that the callback can attest that exact family without making the move
  -- legal for unrelated species. OVERHEAT still needs a registry source.
  for id in pairs(EXTENDED_MOVE_IDS) do add(id, "extended") end
  if johtoUnlocked then
    for id, rule in pairs(resonance or {}) do
      if not rule.level or integer(mon.level, 1, 1, 100) >= rule.level then
        add(id, "resonance")
      end
    end
  end
  return legal, source
end

local function idsFromMoves(moves)
  local ids, seen = {}, {}
  for _, move in ipairs(moves or {}) do
    if move.id and not seen[move.id] then
      ids[#ids + 1], seen[move.id] = move.id, true
    end
  end
  return ids
end

local function setScore(ids, game, species, role, teamTypes)
  local total, types, classes = 0, {}, {}
  for _, id in ipairs(ids) do
    local def = game.data.moves[id]
    local score, class = scoreMove(id, def, species, role, teamTypes)
    total = total + score
    classes[class] = (classes[class] or 0) + 1
    if class == "damage" and def.type then
      if types[def.type] then total = total - 22 else total = total + 8 end
      types[def.type] = true
    end
  end
  if (classes.damage or 0) > 0 and ((classes.status or 0)
      + (classes.setup or 0) + (classes.recovery or 0)) > 0 then
    total = total + 14
  end
  return total
end

local function chooseMoves(game, mon, context, teamTypes)
  local species = game.data.pokemon[mon.species]
  local role = roleFor(species)
  local legal, sources = legalMoves(game, mon, context)
  local current = {}
  for _, id in ipairs(idsFromMoves(mon.moves)) do
    if legal[id] then current[#current + 1] = id end
  end
  local ranked = {}
  for id in pairs(legal) do
    local score, class = scoreMove(id, game.data.moves[id], species, role,
      teamTypes)
    ranked[#ranked + 1] = { id = id, score = score, class = class }
  end
  table.sort(ranked, function(a, b)
    return a.score == b.score and a.id < b.id or a.score > b.score
  end)

  local selected, chosen = {}, {}
  local function take(id)
    if id and legal[id] and not chosen[id] and #selected < 4 then
      selected[#selected + 1], chosen[id] = id, true
    end
  end
  -- A deliberate tactical tool survives upgrades.  This is what protects
  -- authored sets such as Clefairy + Minimize from raw-power replacement.
  for _, id in ipairs(current) do if TACTICAL_KEEP[id] then take(id) end end
  local function best(predicate)
    for _, row in ipairs(ranked) do
      if predicate(row) and not chosen[row.id] then return row.id end
    end
  end
  take(best(function(row)
    local def = game.data.moves[row.id]
    return row.class == "damage" and hasType(species.types, def.type)
  end))
  take(best(function(row)
    return row.class == "status" or row.class == "setup"
      or row.class == "recovery"
  end))
  take(best(function(row)
    local def = game.data.moves[row.id]
    return row.class == "damage" and not hasType(species.types, def.type)
  end))
  for _, row in ipairs(ranked) do take(row.id) end
  if #selected == 0 then return current, role, sources, false end

  local oldScore = setScore(current, game, species, role, teamTypes)
  local newScore = setScore(selected, game, species, role, teamTypes)
  if not context.perfect and #current > 0 and newScore + 0.001 < oldScore then
    return current, role, sources, false
  end
  local changed = #current ~= #selected
  if not changed then
    for i, id in ipairs(current) do if selected[i] ~= id then changed = true end end
  end
  return selected, role, sources, changed
end

function M.create(opts)
  opts = opts or {}
  local R = {
    maxLevel = MAX_LEVEL,
    maxDv = MAX_DV,
    maxStatExp = MAX_STAT_EXP,
    johtoMoveIds = JOHTO_MOVE_IDS,
    extendedMoveIds = EXTENDED_MOVE_IDS,
    resonanceRules = opts.resonanceRules or {},
  }

  local function johtoUnlocked(context)
    if context and context.johtoUnlocked ~= nil then
      return context.johtoUnlocked == true
    end
    return type(opts.johtoUnlocked) == "function"
      and opts.johtoUnlocked() == true or false
  end

  function R.apply(game, battle, context)
    context = copy(context or {})
    context.progress = math.max(0, math.floor(tonumber(context.progress) or 0))
    context.masteryWins = math.max(0,
      math.floor(tonumber(context.masteryWins) or 0))
    context.johtoUnlocked = johtoUnlocked(context)
    context.resonanceRules = R.resonanceRules
    context.extendedMoveAllowed = opts.extendedMoveAllowed
    local Stats = context.Stats or require("src.pokemon.Stats")
    local reports, allLevel100, teamTypes = {}, true, {}
    for _, mon in ipairs(battle and battle.enemyParty or {}) do
      local def = game.data.pokemon[mon.species]
      for _, kind in ipairs(def and def.types or {}) do teamTypes[kind] = true end
    end
    for index, mon in ipairs(battle and battle.enemyParty or {}) do
      local def = game.data.pokemon[mon.species]
      assert(type(def) == "table",
        "missing mastery species " .. tostring(mon.species))
      mon.level = integer(mon.level, 1, 1, MAX_LEVEL)
      allLevel100 = allLevel100 and mon.level == MAX_LEVEL
      local perfectMon = context.perfect == true and mon.level == MAX_LEVEL
      local quality, tier, low, high = targetQuality(mon, context, index)
      local dvs = copy(type(mon.dvs) == "table" and mon.dvs or {})
      for statIndex, stat in ipairs(STAT_KEYS) do
        local variation = (stableFraction((mon.species or "") .. stat)
          - 0.5) * 0.08
        local target = perfectMon and MAX_DV or integer(
          MAX_DV * clamp(quality + variation, 0, 1), 0, 0, MAX_DV)
        dvs[stat] = math.max(integer(dvs[stat], 0, 0, MAX_DV), target)
      end
      dvs.hp = hpDv(dvs)
      local statExp = copy(type(mon.statExp) == "table" and mon.statExp or {})
      local expTarget = perfectMon and MAX_STAT_EXP
        or statExpForQuality(quality)
      for _, stat in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
        statExp[stat] = math.max(
          integer(statExp[stat], 0, 0, MAX_STAT_EXP), expTarget)
      end
      mon.dvs, mon.statExp = dvs, statExp
      local fresh = Stats.calc(def, mon.level, dvs, statExp, mon)
      mon.stats = mon.stats or {}
      for stat, value in pairs(fresh or {}) do
        assert(type(value) == "number" and value >= 1
          and value == math.floor(value), "invalid mastery stat " .. tostring(stat))
        mon.stats[stat] = value
      end
      mon.hp = mon.stats.hp

      local moveIds, role, sources, changed = chooseMoves(
        game, mon, context, teamTypes)
      if changed and (mon.level == MAX_LEVEL or context.progress >= 3) then
        mon.moves = {}
        for _, id in ipairs(moveIds) do
          local move = game.data.moves[id]
          mon.moves[#mon.moves + 1] = { id = id, pp = move.pp or 0 }
        end
      else
        moveIds = idsFromMoves(mon.moves)
      end
      reports[index] = {
        species = mon.species, level = mon.level, tier = tier,
        quality = quality, qualityBand = { low, high },
        dvs = copy(dvs), statExp = copy(statExp), moves = copy(moveIds),
        role = role, sources = sources, movesChanged = changed,
      }
    end
    local report = {
      kind = context.kind or "field", key = context.key,
      progress = context.progress, masteryWins = context.masteryWins,
      johtoUnlocked = context.johtoUnlocked, allLevel100 = allLevel100,
      perfect = context.perfect == true and allLevel100,
      party = reports,
    }
    if battle then
      battle.rematchMastery = report
      battle.rematchMasteryTier = reports[1] and reports[1].tier or "none"
      battle.rematchAtLevelCap = allLevel100
      if battle.enemy and battle.enemy.mon then
        battle.enemy.curStats = battle.enemy.mon.stats
        battle.enemy.curMoves = battle.enemy.mon.moves
        battle.enemy.shownHP = battle.enemy.mon.hp
      end
      if battle.aiUsesFor then battle.aiUses = battle:aiUsesFor() end
    end
    return report
  end

  function R.inspect(battle)
    return copy(battle and battle.rematchMastery or nil)
  end

  R.masteryBand = masteryBand
  R.statExpForQuality = statExpForQuality
  R.roleFor = roleFor
  R.scoreMove = scoreMove
  R.legalMoves = function(game, mon, context)
    context = copy(context or {})
    context.johtoUnlocked = johtoUnlocked(context)
    context.resonanceRules = R.resonanceRules
    context.extendedMoveAllowed = opts.extendedMoveAllowed
    return legalMoves(game, mon, context)
  end
  return R
end

return M
