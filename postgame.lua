-- Post-game controller:
--   Hall of Fame -> eight Master Leaders -> Apex Elite Four
--   -> legendary hunt -> level-100 Crown Circuit.

local ELITE_CLASSES = {
  OPP_LORELEI = true, OPP_BRUNO = true, OPP_AGATHA = true,
  OPP_LANCE = true, OPP_RIVAL3 = true,
}
local ELITE_FOUR = { "OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE" }
local STATIC_LEGEND_OPTIONS = {
  ARTICUNO = "legend_articuno", ZAPDOS = "legend_zapdos",
  MOLTRES = "legend_moltres", MEWTWO = "legend_mewtwo",
}
local ADDED_LEGEND_OPTIONS = {
  RAIKOU = "legend_raikou", ENTEI = "legend_entei",
  SUICUNE = "legend_suicune", LUGIA = "legend_lugia",
  HO_OH = "legend_ho_oh", CELEBI = "legend_celebi",
}
local GYM_CROWN_LEGENDS = {
  misty = "SUICUNE", surge = "RAIKOU", erika = "CELEBI",
  sabrina = "LUGIA", blaine = "ENTEI",
}
local ELITE_CROWN_LEGENDS = {
  OPP_LORELEI = { "ARTICUNO" },
  OPP_RIVAL3 = {
    "MEWTWO", "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH",
  },
}
local LEGEND_ALTERNATES = {
  ARTICUNO = {
    species = "LAPRAS",
    moves = { "BLIZZARD", "SURF", "THUNDERBOLT", "BODY_SLAM" },
  },
  MEWTWO = {
    species = "ALAKAZAM",
    moves = { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" },
  },
  RAIKOU = {
    species = "JOLTEON",
    moves = { "THUNDER", "BODY_SLAM", "REFLECT", "THUNDER_WAVE" },
  },
  ENTEI = {
    species = "ARCANINE",
    moves = { "FIRE_BLAST", "BODY_SLAM", "REFLECT", "AGILITY" },
  },
  SUICUNE = {
    species = "LAPRAS",
    moves = { "HYDRO_PUMP", "BLIZZARD", "REST", "BODY_SLAM" },
  },
  LUGIA = {
    species = "DRAGONITE",
    moves = { "HYPER_BEAM", "BLIZZARD", "THUNDER_WAVE", "AGILITY" },
  },
  HO_OH = {
    species = "MOLTRES",
    moves = { "FIRE_BLAST", "SKY_ATTACK", "REFLECT", "AGILITY" },
  },
  CELEBI = {
    species = "EXEGGUTOR",
    moves = { "PSYCHIC_M", "MEGA_DRAIN", "SLEEP_POWDER", "EXPLOSION" },
  },
}
local BEYOND_KANTO_ALTERNATES = {
  KINGDRA = {
    species = "SEADRA",
    moves = { "HYDRO_PUMP", "BLIZZARD", "SMOKESCREEN", "AGILITY" },
  },
  TYRANITAR = {
    species = "RHYDON",
    moves = { "ROCK_SLIDE", "EARTHQUAKE", "BODY_SLAM", "HYPER_BEAM" },
  },
}

local function randomInt(lo, hi)
  if love and love.math and love.math.random then return love.math.random(lo, hi) end
  return math.random(lo, hi)
end

local function hasHallOfFame(save)
  return save and ((save.hallOfFame and #save.hallOfFame > 0)
    or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) or false
end

local function owns(save, species)
  return save and save.pokedex and save.pokedex.owned
    and save.pokedex.owned[species] and true or false
end

local function allKeys(bucket, rows, keyField)
  bucket = type(bucket) == "table" and bucket or {}
  for _, row in ipairs(rows) do
    if not bucket[row[keyField]] then return false end
  end
  return true
end

return function(mod, data, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local fieldTech = opts.fieldTech
  local kantoCompletion = opts.kantoCompletion
  local gorochu = opts.gorochu
  local rematchRewards = opts.rematchRewards
  local rivalIdentity = opts.rivalIdentity
  local function currentRivalIdentity()
    if type(rivalIdentity) == "function" then
      local ok, identity = pcall(rivalIdentity)
      if ok and (identity == "RED" or identity == "GREEN") then
        return identity
      end
    end
    return "BLUE"
  end
  local function tr(english, german)
    return i18n and i18n.text(english, german) or english
  end
  local function localized(row)
    if type(row) ~= "table" then return row end
    return tr(row.en, row.de)
  end
  local legendSetting
  local function gymDialogue(gym, tier, key)
    local root = data.dialogue and data.dialogue.gyms
      and data.dialogue.gyms[gym.key]
    local row = tier and root and root[tier] or root
    local legend = tier == "crown" and GYM_CROWN_LEGENDS[gym.key]
    if key == "intro" and legend and legendSetting
        and legendSetting(legend) == "off" and row and row.introNoLegend then
      key = "introNoLegend"
    end
    return row and localized(row[key]) or nil
  end
  local function gymRestDialogue(gym, tier, steps)
    local root = data.dialogue and data.dialogue.gyms
      and data.dialogue.gyms[gym.key]
    local row = root and root[tier] and root[tier].rest
    if not row then return nil end
    steps = math.max(1, math.floor(tonumber(steps) or 1))
    if steps == 1 then return localized(row.one) end
    local many = localized(row.many)
    return many and many:format(steps) or nil
  end
  local function eliteDialogue(class, tier, key)
    local root = data.dialogue and data.dialogue.elite
      and data.dialogue.elite[class]
    local identityRows = class == "OPP_RIVAL3" and root
      and root[currentRivalIdentity()] or nil
    local row = identityRows and identityRows[tier] or root and root[tier]
    if tier == "crown" and key == "before" and row
        and row.beforeNoLegend and legendSetting then
      for _, species in ipairs(ELITE_CROWN_LEGENDS[class] or {}) do
        if legendSetting(species) == "off" then
          key = "beforeNoLegend"
          break
        end
      end
    end
    return row and localized(row[key]) or nil
  end
  local oakStoryBase = setmetatable({}, { __mode = "k" })
  local function anyLegendEnabled()
    for _, species in ipairs(data.legendOrder or {}) do
      if not legendSetting or legendSetting(species) ~= "off" then return true end
    end
    return false
  end
  local function applyStoryOakDialogue(mapId, game)
    if mapId ~= "CHAMPIONS_ROOM"
        or not (game and game.data and game.data.text) then return false end
    local label = "_ChampionsRoomOakComeWithMeText"
    local textData = game.data.text
    if oakStoryBase[textData] == nil then
      oakStoryBase[textData] = textData[label] or false
    end
    local base = oakStoryBase[textData]
    if base then textData[label] = base end
    if hasHallOfFame(game.save) then return false end
    local story = data.dialogue and data.dialogue.story
    local row = story and story[
      anyLegendEnabled() and "oakLegendEvent" or "oakNoLegendEvent"]
    local value = localized(row)
    if not value then return false end
    textData[label] = value
    return true
  end
  local controller = { game = nil, contentEnabled = opts.contentEnabled and true or false }
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  local function beyondActive(save)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(save or controller.game)
  end
  local forcedStack = {}
  local enabledTeam
  local newForcedBattle
  local pendingRoamer
  local mastery
  local bossProgress

  local function applyMastery(game, battle, context)
    if not (mastery and game and battle) or battle.postgameMasteryApplied then
      return battle and battle.rematchMastery
    end
    context = context or {}
    local wins = type(bossProgress) == "function"
      and bossProgress(context) or 0
    context.progress = math.max(0, math.floor(tonumber(wins) or 0))
    context.masteryWins = context.progress
    context.specialist = true
    context.champion = context.key == "OPP_RIVAL3"
    local report = mastery.apply(game, battle, context)
    battle.postgameMasteryApplied = true
    battle.postgameMasteryWins = context.masteryWins
    return report
  end

  local function state(create)
    local s = mod.save:get("postgame")
    if type(s) ~= "table" and create ~= false then
      s = {
        masterWins = {}, crownWins = {}, eliteApexWins = {},
        eliteCrownWins = {}, catches = {}, roamers = {}, bossRest = {},
      }
      mod.save:set("postgame", s)
    end
    if type(s) == "table" then
      s.masterWins = type(s.masterWins) == "table" and s.masterWins or {}
      s.crownWins = type(s.crownWins) == "table" and s.crownWins or {}
      s.eliteApexWins = type(s.eliteApexWins) == "table" and s.eliteApexWins or {}
      s.eliteCrownWins = type(s.eliteCrownWins) == "table" and s.eliteCrownWins or {}
      s.catches = type(s.catches) == "table" and s.catches or {}
      s.roamers = type(s.roamers) == "table" and s.roamers or {}
      s.bossRest = type(s.bossRest) == "table" and s.bossRest or {}
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("postgame", s) end
  end

  local function repairGymWinsFromHistory()
    local extension = controller.extension
    if not (extension and type(extension.state) == "function") then
      return false
    end
    local ascendantState = extension.state(false)
    local history = ascendantState and ascendantState.bossBattles
    local s = state(false)
    if type(history) ~= "table" or not s then return false end

    local changed = false
    for _, gym in ipairs(data.gyms) do
      local masterKey = "gym:" .. gym.key .. ":master"
      local crownKey = "gym:" .. gym.key .. ":crown"
      if not s.masterWins[gym.key]
          and math.max(0, tonumber(history[masterKey]) or 0) > 0 then
        s.masterWins[gym.key] = true
        changed = true
      end
      if not s.crownWins[gym.key]
          and math.max(0, tonumber(history[crownKey]) or 0) > 0 then
        s.crownWins[gym.key] = true
        changed = true
      end
    end
    if changed then persist(s) end
    return changed
  end

  local function allMaster(s)
    return allKeys(s and s.masterWins, data.gyms, "key")
  end

  local function allCrown(s)
    return allKeys(s and s.crownWins, data.gyms, "key")
  end

  local function caught(s, save, species)
    return (s and s.catches and s.catches[species]) or owns(save, species) or false
  end

  legendSetting = function(species)
    local staticKey = STATIC_LEGEND_OPTIONS[species]
    if staticKey then
      local value = mod.options:get(staticKey)
      if value == "vanilla" or value == "off" then return value end
      return "apex"
    end
    local addedKey = ADDED_LEGEND_OPTIONS[species]
    if addedKey and mod.options:get(addedKey) == false then return "off" end
    return "apex"
  end

  local function requiredCaught(s, save, list)
    for _, species in ipairs(list) do
      if legendSetting(species) ~= "off"
          and not caught(s, save, species) then return false end
    end
    return true
  end

  local function birdsCaught(s, save)
    return requiredCaught(s, save, { "ARTICUNO", "ZAPDOS", "MOLTRES" })
  end

  local function beastsCaught(s, save)
    return requiredCaught(s, save, { "RAIKOU", "ENTEI", "SUICUNE" })
  end

  local function crownUnlocked(s, save)
    return s and s.apexChampion
      and requiredCaught(s, save, { "LUGIA", "HO_OH" })
  end

  local function legendaryAvailable(species, s, save)
    if ADDED_LEGEND_OPTIONS[species] and not beyondActive(save) then
      return false
    end
    local setting = legendSetting(species)
    if setting == "off" then return false end
    if setting == "vanilla" then return true end
    if not (s and s.apexChampion) then return false end
    if data.staticLegends[species] or data.roamers[species] then return true end
    if species == "LUGIA" then return birdsCaught(s, save) end
    if species == "HO_OH" then return beastsCaught(s, save) end
    if species == "CELEBI" then return crownUnlocked(s, save) end
    return false
  end

  enabledTeam = function(team)
    if type(team) ~= "table" then return team end
    local out
    local kantoOnly = not beyondActive(controller.game and controller.game.save)
    for i, slot in ipairs(team) do
      local replacement = LEGEND_ALTERNATES[slot.species]
        or BEYOND_KANTO_ALTERNATES[slot.species]
      local def = controller.game and controller.game.data
        and controller.game.data.pokemon and controller.game.data.pokemon[slot.species]
        or data.species and data.species[slot.species]
      local beyond = def and tonumber(def.dex) and tonumber(def.dex) > 151
      if replacement and (legendSetting(slot.species) == "off"
          or kantoOnly and beyond) then
        if not out then
          out = {}
          for j = 1, i - 1 do out[j] = team[j] end
        end
        out[i] = {
          species = replacement.species,
          level = slot.level,
          moves = replacement.moves,
        }
      elseif out then
        out[i] = slot
      end
    end
    local resolved = out or team
    if gorochu and gorochu.sanitizeTrainerTeam then
      resolved = gorochu.sanitizeTrainerTeam(resolved)
    end
    return resolved
  end

  local function copyTeam(team)
    local out = {}
    for i, slot in ipairs(team or {}) do
      out[i] = {}
      for key, value in pairs(slot) do
        if type(value) == "table" then
          out[i][key] = {}
          for j, nested in ipairs(value) do out[i][key][j] = nested end
        else
          out[i][key] = value
        end
      end
    end
    return out
  end

  local function teamHasSpecies(team, species)
    if not species then return false end
    for _, slot in ipairs(team or {}) do
      if slot.species == species then return true end
    end
    return false
  end

  local function eliteMegaTarget(class, tier, team)
    local configured = data.eliteMega and data.eliteMega[class]
    local target = configured and configured[tier]
    if teamHasSpecies(team, target) then return target end
    local fallbacks = data.eliteMegaFallback
      and data.eliteMegaFallback[class]
    local fallback = fallbacks and fallbacks[tier]
    if teamHasSpecies(team, fallback) then return fallback end
    return nil
  end

  local function sourceForTier(tier)
    if tier == "master" or tier == "crown" then return "gym" end
    if tier == "johto_trial" then return "research_trial" end
    if tier == "battle_factory" or tier == "ss_anne_grand_tour" then
      return "grand_tour"
    end
    return tier or "forced"
  end

  local function samePartySignature(party, definition)
    if type(party) ~= "table" or type(definition) ~= "table"
        or #party ~= #definition then return false end
    for i, slot in ipairs(definition) do
      local mon = party[i]
      if not mon or mon.species ~= slot.species
          or tonumber(mon.level) ~= tonumber(slot.level) then
        return false
      end
    end
    return true
  end

  local function validPartyDefinition(game, party, requireRegistered)
    if type(party) ~= "table" or #party < 1 or #party > 6 then return false end
    for _, slot in ipairs(party) do
      local level = type(slot) == "table" and tonumber(slot.level)
      if type(slot) ~= "table" or type(slot.species) ~= "string"
          or not level or level ~= math.floor(level)
          or level < 1 or level > 100 then return false end
      if slot.moves ~= nil and type(slot.moves) ~= "table" then return false end
      if requireRegistered and not game.data.pokemon[slot.species] then
        return false
      end
      for _, moveId in ipairs(slot.moves or {}) do
        if type(moveId) ~= "string"
            or requireRegistered and not game.data.moves[moveId] then
          return false
        end
      end
    end
    return true
  end

  local function validConstructedParty(game, party, size)
    if type(party) ~= "table" or #party ~= size or size < 1 or size > 6 then
      return false, "wrong_size"
    end
    for _, mon in ipairs(party) do
      local level = type(mon) == "table" and tonumber(mon.level)
      if type(mon) ~= "table" or not game.data.pokemon[mon.species]
          or not level or level < 1 or level > 100 then
        return false, "invalid_pokemon"
      end
      if type(mon.moves) ~= "table" or #mon.moves > 4 then
        return false, "invalid_moves"
      end
      for _, move in ipairs(mon.moves) do
        if type(move) ~= "table" or not game.data.moves[move.id] then
          return false, "invalid_moves"
        end
      end
    end
    return true
  end

  local function authoredParty(game, intended)
    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local trainerDvs = (game.data.constants and game.data.constants.trainerDvs)
      or { hp = 8, attack = 9, defense = 8, speed = 8, special = 8 }
    local party = {}
    for _, slot in ipairs(intended) do
      local level = math.max(1, math.min(100, math.floor(slot.level)))
      local mon = Pokemon.new(game.data, slot.species, level)
      mon.dvs = trainerDvs
      mon.stats = Stats.calc(game.data.pokemon[slot.species],
        level, trainerDvs, nil, mon)
      mon.hp = mon.stats.hp
      if slot.moves then
        mon.moves = {}
        for _, moveId in ipairs(slot.moves) do
          local move = game.data.moves[moveId]
          mon.moves[#mon.moves + 1] = { id = moveId, pp = move.pp }
        end
      end
      party[#party + 1] = mon
    end
    return party
  end

  local function normalizeForcedParty(game, party, intended)
    local Stats = require("src.pokemon.Stats")
    local Growth = require("src.pokemon.Growth")
    local trainerDvs = (game.data.constants and game.data.constants.trainerDvs)
      or { hp = 8, attack = 9, defense = 8, speed = 8, special = 8 }
    for i, mon in ipairs(party) do
      local slot = intended[i]
      local level = math.max(1, math.min(100,
        math.floor(tonumber(slot.level) or 1)))
      local species = game.data.pokemon[mon.species]
      mon.level = level
      mon.dvs = mon.dvs or trainerDvs
      mon.statExp = mon.statExp or {}
      mon.exp = Growth.expForLevel(species.growthRate, level,
        game.data.growth_rates)
      mon.stats = Stats.calc(species, level, mon.dvs, mon.statExp, mon)
      mon.hp = mon.stats.hp
      for _, move in ipairs(mon.moves or {}) do
        local moveDef = game.data.moves[move.id]
        move.pp = moveDef and moveDef.pp or move.pp
      end
    end
  end

  local function finalizeForcedBattle(game, battle, intended, context)
    context = context or {}
    intended = copyTeam(enabledTeam(intended))
    if battle and battle.trainerPartyHookFallback then
      context.fallback = true
      context.fallbackReason = battle.trainerPartyHookFallbackReason
        or "invalid_hook_party"
    end
    local valid, fallbackReason = validConstructedParty(
      game, battle and battle.enemyParty, #intended)
    if valid and context.vanillaParty
        and not samePartySignature(context.vanillaParty, intended)
        and samePartySignature(battle.enemyParty, context.vanillaParty) then
      valid, fallbackReason = false, "vanilla_party"
    end
    if not valid then
      battle.enemyParty = authoredParty(game, intended)
      context.fallback = true
      context.fallbackReason = fallbackReason
    else
      context.randomized = not samePartySignature(battle.enemyParty, intended)
    end
    normalizeForcedParty(game, battle.enemyParty, intended)
    battle.enemyIndex = 1
    local BattleState = require("src.battle.BattleState")
    if BattleState.makeBattler then
      battle.enemy = BattleState.makeBattler(
        game.data, battle.enemyParty[1], false)
    else
      battle.enemy = battle.enemy or {}
      battle.enemy.mon = battle.enemyParty[1]
      battle.enemy.def = game.data.pokemon[battle.enemyParty[1].species]
      battle.enemy.name = battle.enemyParty[1].nickname
        or (battle.enemy.def and battle.enemy.def.name)
      battle.enemy.curStats = battle.enemyParty[1].stats
      battle.enemy.curTypes = battle.enemy.def and battle.enemy.def.types
      battle.enemy.curMoves = battle.enemyParty[1].moves
      battle.enemy.shownHP = battle.enemyParty[1].hp
    end
    if battle.aiUsesFor then battle.aiUses = battle:aiUsesFor() end
    if game.save and game.save.pokedex then
      game.save.pokedex.seen = game.save.pokedex.seen or {}
      game.save.pokedex.seen[battle.enemyParty[1].species] = true
    end
    battle.kind = "trainer"
    battle.rematch = true
    battle.ascendantForcedBattle = true
    battle.ascendantForcedSource = context.source
      or sourceForTier(context.tier)
    battle.postgameForcedTier = context.tier
    battle.postgameTier = context.tier
    battle.ascendantForcedFallback = context.fallback or false
    battle.ascendantForcedFallbackReason = context.fallbackReason
    battle.ascendantForcedRandomized = context.randomized or false
    battle.ascendantForcedTeamSize = #intended
    return battle
  end

  newForcedBattle = function(game, class, team, tier, context)
    local BattleState = require("src.battle.BattleState")
    local trainer = game.data.trainers and game.data.trainers[class]
    assert(trainer, "unknown trainer class " .. tostring(class))
    assert(type(trainer.parties) == "table",
      "trainer " .. tostring(class) .. " has no party registry")
    local intended = copyTeam(enabledTeam(team))
    local requireRegistered = type(BattleState.makeBattler) == "function"
    assert(validPartyDefinition(game, intended, requireRegistered),
      "invalid forced trainer party for " .. tostring(class))
    context = context or {}
    context.class = class
    context.tier = tier
    context.source = context.source or sourceForTier(tier)
    context.intended = intended
    context.vanillaParty = copyTeam(trainer.parties[1])

    local parties = trainer.parties
    context.syntheticIndex = 1
    forcedStack[#forcedStack + 1] = context

    -- Run the complete Randomizer/mod hook chain once while the authored
    -- roster is the input. Older public engines construct Pokémon
    -- immediately after the hook and can crash on an empty/invalid result,
    -- so validate here before entering BattleState.
    local Runtime = require("src.mods.Runtime")
    local resolved = Runtime.call("trainer.party",
      function(_, _, party) return party end,
      class, 1, copyTeam(intended))
    if not validPartyDefinition(game, resolved, requireRegistered)
        or #resolved ~= #intended then
      resolved = copyTeam(intended)
      context.fallback = true
      context.fallbackReason = "invalid_hook_party"
    elseif not samePartySignature(context.vanillaParty, intended)
        and samePartySignature(resolved, context.vanillaParty) then
      resolved = copyTeam(intended)
      context.fallback = true
      context.fallbackReason = "vanilla_party"
    end

    -- The hook result is already final. Construct through the engine with
    -- party 1 temporarily replaced and the trainer.party chain suspended.
    -- This is compatible with both the frozen launcher engine and newer
    -- engines that provide skipPartyHook/displayPartyIndex options.
    local originalParty = parties[1]
    parties[1] = copyTeam(resolved)
    local hookChains = Runtime.hooks and Runtime.hooks.chains
    local savedPartyChain = hookChains and hookChains["trainer.party"]
    if hookChains then hookChains["trainer.party"] = nil end
    local ok, result = xpcall(function()
      return BattleState.newTrainer(game, class, 1, {
        skipPartyHook = true,
        displayPartyIndex = 1,
      })
    end, function(err) return tostring(err) end)
    parties[1] = originalParty
    if hookChains then hookChains["trainer.party"] = savedPartyChain end
    for i = #forcedStack, 1, -1 do
      if forcedStack[i] == context then
        table.remove(forcedStack, i)
        break
      end
    end
    if not ok then error(result, 0) end
    return finalizeForcedBattle(game, result, intended, context)
  end

  local function phaseFor(s, save)
    if not hasHallOfFame(save) then return "story" end
    if not allMaster(s) then return "master_gyms" end
    if not s.apexChampion then return "apex_elite" end
    if not crownUnlocked(s, save) then return "legend_hunt" end
    if not allCrown(s) then return "crown_gyms" end
    if not s.crownChampion then return "crown_elite" end
    return "complete"
  end

  local function eliteTier(s, save)
    if not (hasHallOfFame(save) and allMaster(s)) then return nil end
    if crownUnlocked(s, save) and allCrown(s) then return "crown" end
    return "apex"
  end
  local events = opts.makeEvents and opts.makeEvents(data, {
    tr = tr,
    localized = localized,
    legendSetting = legendSetting,
    legendaryAvailable = legendaryAvailable,
    caught = caught,
    phaseFor = phaseFor,
    rivalIdentity = currentRivalIdentity,
  })

  -- The first clear adds Oak's one-time legendary-sighting story bridge.
  -- Once a circuit is active, replace the current Elite/Champion room's text
  -- immediately before its map script runs.  This preserves all original
  -- door, flag and Hall-of-Fame choreography while adding the new voices.
  local function applyEliteDialogue(mapId, game, progression)
    if not (game and game.data and game.data.text) then return false end
    local storyOakApplied = applyStoryOakDialogue(mapId, game)
    local tier = eliteTier(progression or state(), game.save)
    if not tier then return storyOakApplied end
    for class, root in pairs(data.dialogue and data.dialogue.elite or {}) do
      if root.map == mapId then
        for key, label in pairs(root.labels or {}) do
          local value = eliteDialogue(class, tier, key)
          if value then game.data.text[label] = value end
        end
        return true
      end
    end
    return false
  end

  local function syncOwned(save)
    local s = state()
    for _, species in ipairs(data.legendOrder) do
      if owns(save, species) then s.catches[species] = true end
    end
    persist(s)
    return s
  end

  local function routePool(game)
    local routes = {}
    for _, mapId in ipairs(data.roamerRoutes) do
      local enc = game and game.data and game.data.encounters
        and game.data.encounters[mapId]
      if enc and enc.grass then routes[#routes + 1] = mapId end
    end
    return routes
  end

  local function relocateRoamer(species, game, avoid)
    local s = state()
    local routes = routePool(game or controller.game)
    if #routes == 0 then return nil end
    local candidates = {}
    for _, mapId in ipairs(routes) do
      if mapId ~= avoid then candidates[#candidates + 1] = mapId end
    end
    if #candidates == 0 then candidates = routes end
    local route = candidates[randomInt(1, #candidates)]
    s.roamers[species] = route
    persist(s)
    return route
  end

  local function initRoamers(game)
    local s = state()
    if not s.apexChampion then return end
    for species in pairs(data.roamers) do
      if legendaryAvailable(species, s, game.save)
          and not caught(s, game.save, species) and not s.roamers[species] then
        relocateRoamer(species, game)
      end
    end
  end

  local function setObjectToggle(save, mapId, name, visible)
    save.objectToggles = save.objectToggles or {}
    save.objectToggles[mapId] = save.objectToggles[mapId] or {}
    local old = save.objectToggles[mapId][name]
    save.objectToggles[mapId][name] = visible and true or false
    return old ~= (visible and true or false)
  end

  -- Recover legends that old vanilla scripts hid after a KO or flee.  In
  -- this expansion only a successful capture is permanent.
  local function syncPersistentObjects(game, activeMap)
    if not game or not game.save then return end
    local s = syncOwned(game.save)
    local reloadObject
    for species, def in pairs(data.staticLegends) do
      local setting = legendSetting(species)
      local visible
      if setting == "off" then
        visible = false
      elseif setting == "vanilla" then
        visible = not owns(game.save, species)
          and not (game.save.flags and game.save.flags[def.flag])
      else
        visible = not caught(s, game.save, species)
      end
      if setObjectToggle(game.save, def.map, def.object, visible)
          and activeMap == def.map then
        reloadObject = {
          map = def.map, object = def.object, visible = visible,
        }
      end
      if setting == "apex" and game.save.flags then
        if visible then game.save.flags[def.flag] = nil
        else game.save.flags[def.flag] = true end
      end
    end
    if hasHallOfFame(game.save) then
      local changed = setObjectToggle(game.save, "VIRIDIAN_GYM",
        "VIRIDIANGYM_GIOVANNI", true)
      if changed and activeMap == "VIRIDIAN_GYM" then
        reloadObject = {
          map = "VIRIDIAN_GYM", object = "VIRIDIANGYM_GIOVANNI",
          visible = true,
        }
      end
    end
    if reloadObject and mod.world then
      -- The event fires before map scripts but after object instantiation.
      -- One seamless reload applies the repaired toggle; the second entry
      -- sees no change and therefore cannot recurse.
      mod.world:toggleObject(reloadObject.map, reloadObject.object,
        reloadObject.visible)
    end
  end

  local function removeLiveNpc(ow, npc)
    if not (ow and npc) then return end
    for _, list in ipairs({ ow.npcs or {}, ow.entities or {} }) do
      for i = #list, 1, -1 do
        if list[i] == npc then table.remove(list, i) end
      end
    end
    if ow.npcPool then ow.npcPool[npc.id] = nil end
  end

  local function markCaught(species, save)
    local s = state()
    s.catches[species] = true
    s.roamers[species] = nil
    persist(s)
    if save and save.pokedex and save.pokedex.owned then
      save.pokedex.owned[species] = true
    end
  end

  local function findSpawnCell(ow, preferred)
    local function free(x, y)
      return ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
        and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
        and not (ow.player.cellX == x and ow.player.cellY == y)
    end
    for _, cell in ipairs(preferred or {}) do
      if free(cell[1], cell[2]) then return cell[1], cell[2] end
    end
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if free(x, y) then return x, y end
      end
    end
  end

  local function findRoamerCell(ow)
    local cells = {}
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if ow.map:isGrassCell(x, y) and ow.map:isWalkableCell(x, y)
            and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
            and not (ow.player.cellX == x and ow.player.cellY == y) then
          cells[#cells + 1] = { x, y }
        end
      end
    end
    if #cells == 0 then return findSpawnCell(ow) end
    local cell = cells[randomInt(1, #cells)]
    return cell[1], cell[2]
  end

  local function runtimeObjectIdsAt(game, mapId, name)
    local out = {}
    local map = game and game.data and game.data.maps and game.data.maps[mapId]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == name then
        out[#out + 1] = mapId .. "_obj_" .. tostring(obj.index)
      end
    end
    return out
  end

  local function runtimeObjectIds(game, def)
    return runtimeObjectIdsAt(game, def.map, def.name)
  end

  local function allRuntimeObjectIds(game, name)
    local out = {}
    for mapId in pairs(game and game.data and game.data.maps or {}) do
      for _, id in ipairs(runtimeObjectIdsAt(game, mapId, name)) do
        out[#out + 1] = { id = id, map = mapId }
      end
    end
    return out
  end

  local function removeRoamerObjects(game, species)
    local def = data.roamers[species]
    if not def then return end
    for _, live in ipairs(allRuntimeObjectIds(game, def.name)) do
      mod.world:removeNpc(live.id)
    end
  end

  local function ensureSpawnedLegend(game, mapId)
    local def
    local species
    for id, row in pairs(data.spawnedLegends) do
      if row.map == mapId then species, def = id, row break end
    end
    if not def then return end
    local s = syncOwned(game.save)
    local shouldExist = legendaryAvailable(species, s, game.save)
      and not caught(s, game.save, species)
    local ids = runtimeObjectIds(game, def)
    if not shouldExist then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local x, y = findSpawnCell(ow, def.preferred)
    if not x then
      mod.log:warn("no free spawn cell for %s on %s", species, mapId)
      return
    end
    mod.world:spawnNpc(mapId, {
      name = def.name, sprite = def.sprite, movement = "STAY", range = "DOWN",
      text = def.text, pokemon = species, level = def.level, x = x, y = y,
    })
  end

  local function ensureRoamerObjects(game, mapId)
    if not controller.contentEnabled then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local s = syncOwned(game.save)
    for species, def in pairs(data.roamers) do
      local desiredMap = s.apexChampion
        and legendaryAvailable(species, s, game.save)
        and not caught(s, game.save, species) and s.roamers[species] or nil
      local currentId
      for _, live in ipairs(allRuntimeObjectIds(game, def.name)) do
        if live.map == desiredMap and not currentId then
          currentId = live.id
        else
          mod.world:removeNpc(live.id)
        end
      end
      if desiredMap == mapId and not currentId then
        local x, y = findRoamerCell(ow)
        if x then
          mod.world:spawnNpc(mapId, {
            name = def.name, sprite = def.sprite, movement = "STAY",
            range = "DOWN", text = def.text, pokemon = species,
            level = def.level, x = x, y = y,
          })
        else
          mod.log:warn("no free spawn cell for %s on %s", species, mapId)
        end
      end
    end
  end

  local function ensureHuntRival(game, mapId)
    local def = data.huntRival
    if not (events and def and controller.contentEnabled and game) then return end
    local ids = runtimeObjectIds(game, def)
    local shouldExist = events.huntRivalAvailable(state(), game.save)
    if not shouldExist then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 or mapId ~= def.map then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local x, y = findSpawnCell(ow, def.preferred)
    if not x then
      mod.log:warn("no free spawn cell for the legendary-hunt Rival")
      return
    end
    mod.world:spawnNpc(mapId, {
      name = def.name, sprite = def.sprite, movement = "STAY", range = "DOWN",
      text = def.text, trainerClass = def.class, x = x, y = y,
    })
  end

  local function bossRestRemaining(key)
    local s = state()
    local ready = tonumber(s.bossRest[key]) or 0
    local clock = tonumber(mod.save:get("step_clock", 0)) or 0
    return math.max(0, math.floor(ready - clock))
  end

  local function scheduleBossRest(key)
    local rawLo = tonumber(mod.options:get("rest_min"))
    local rawHi = tonumber(mod.options:get("rest_max"))
    if rawLo == 128 and rawHi == 256 then rawLo, rawHi = 151, 2510 end
    local lo = math.min(2510, math.max(151,
      math.floor(rawLo or 151)))
    local hi = math.min(2510, math.max(151,
      math.floor(rawHi or 2510)))
    if lo > hi then lo, hi = hi, lo end
    local s = state()
    s.bossRest[key] = (tonumber(mod.save:get("step_clock", 0)) or 0)
      + randomInt(lo, hi)
    persist(s)
  end

  local function offerGymBattle(ow, npc, gym, tier)
    local game = controller.game
    local TextBox = require("src.render.TextBox")
    local Runtime = require("src.mods.Runtime")
    local key = tier .. ":" .. gym.key
    local left = bossRestRemaining(key)
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    if left > 0 then
      local status = gymRestDialogue(gym, tier, left)
      if not status and i18n and i18n.isGerman() then
        status = ("Mein Team trainiert\nnoch.\nKomm in %d\n%s zurück."):format(
          left, left == 1 and "Schritt" or "Schritten")
      elseif not status then
        status = ("My team is still\ntraining.\nReturn in %d\nstep%s."):format(
          left, left == 1 and "" or "s")
      end
      game.stack:push(TextBox.new(game,
        status, done))
      return true
    end

    local challenge = gymDialogue(gym, tier, "intro")
    local prompt
    if i18n and i18n.isGerman() then
      prompt = tier == "crown"
        and "LEVEL 100 KRONEN-\nKampf. Annehmen?"
        or ("LEVEL %d-%d MEISTER-\nKampf. Annehmen?"):format(
          gym.master[1].level, gym.master[#gym.master].level)
    else
      local levelText = tier == "crown" and "LEVEL 100"
        or ("LEVEL %d-%d"):format(gym.master[1].level,
          gym.master[#gym.master].level)
      prompt = tier == "crown"
        and (levelText .. " CROWN\nbattle. Accept?")
        or (levelText .. " MASTER\nbattle. Accept?")
    end
    if challenge then prompt = challenge .. "\f" .. prompt end
    game.stack:push(TextBox.new(game, prompt, nil, {
      choice = function(yes)
        if not yes then
          game.stack:push(TextBox.new(game,
            gymDialogue(gym, tier, "decline")
              or tr("Train well.\nI will be here.",
                "Trainiere gut.\nIch warte hier."), done))
          return
        end
        Runtime.emit("world.trainer_engaged", {
          npc = npc, trainerClass = gym.class, partyIndex = 1,
        })
        local team = gym[tier]
        if controller.extension and controller.extension.selectBossTeam then
          team = controller.extension.selectBossTeam(team, {
            kind = "gym", key = gym.key, tier = tier,
          }, game)
        end
        local battle = newForcedBattle(game, gym.class, team, tier)
        battle.postgameTier = tier
        battle.postgameGym = gym.key
        if controller.extension and controller.extension.applyBossRules then
          controller.extension.applyBossRules(battle)
        end
        applyMastery(game, battle, {
          kind = "gym", key = gym.key, tier = tier,
        })
        battle.endBattleText = gymDialogue(gym, tier, "win")
        battle.onFinish = function(result)
          scheduleBossRest(key)
          local rewards = {}
          local function addReward(text)
            if text and text ~= "" then rewards[#rewards + 1] = text end
          end
          if result == "win" then
            local s = state()
            if tier == "master" then s.masterWins[gym.key] = true
            else s.crownWins[gym.key] = true end
            persist(s)
            if rematchRewards then
              addReward(rematchRewards.afterWin(game, battle, nil))
            end
            if fieldTech then
              addReward(fieldTech.afterBossWin(game, gym.key, tier))
            end
            if kantoCompletion then
              addReward(kantoCompletion.afterBossWin(game, gym.key, tier))
            end
          end
          local reward = #rewards > 0 and table.concat(rewards, "\f") or nil
          ow:afterBattle(result, battle)
          if reward then
            game.stack:push(TextBox.new(game, reward, done))
          else
            done()
          end
        end
        ow:pushBattle(battle)
      end,
    }))
    return true
  end

  local function showNpcMessage(ow, npc, game, text)
    if not text then return false end
    npc.frozen = true
    npc:facePlayer(ow.player)
    game.stack:push(require("src.render.TextBox").new(game, text,
      function() npc.frozen = false end))
    return true
  end

  local function offerHuntRival(ow, npc, game)
    local def = data.huntRival
    if not (events and def and events.huntRivalAvailable(state(), game.save)) then
      return false
    end
    local TextBox = require("src.render.TextBox")
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    game.stack:push(TextBox.new(game,
      events.huntRivalDialogue("before"), nil, {
        choice = function(yes)
          if not yes then
            game.stack:push(TextBox.new(game,
              events.huntRivalDialogue("decline"), done))
            return
          end
          require("src.mods.Runtime").emit("world.trainer_engaged", {
            npc = npc, trainerClass = def.class, partyIndex = 1,
          })
          local battle = newForcedBattle(game, def.class, def.team, "hunt")
          battle.postgameHuntRival = true
          battle.endBattleText = events.huntRivalDialogue("win")
          battle.onFinish = function(result)
            if result == "win" then
              local s = state()
              s.huntRivalWon = true
              persist(s)
            end
            ow:afterBattle(result, battle)
            if result == "win" then
              game.stack:push(TextBox.new(game,
                events.huntRivalDialogue("after"), function()
                  removeLiveNpc(ow, npc)
                  done()
                end))
            else
              done()
            end
          end
          ow:pushBattle(battle)
        end,
      }))
    return true
  end

  function controller.handleTalk(ow, npc, game)
    controller.game = game or controller.game
    if not (npc and npc.def and hasHallOfFame(game.save)) then return false end
    local s = state()
    if events and ow.map.id == "OAKS_LAB"
        and npc.def.name == "OAKSLAB_SCIENTIST1" then
      return showNpcMessage(ow, npc, game, events.researchLog(s, game.save))
    end
    if data.huntRival and npc.def.name == data.huntRival.name then
      return offerHuntRival(ow, npc, game)
    end
    if events then
      local reaction = events.worldReaction(
        ow.map.id, npc.def.name, s, game.save)
      if reaction then return showNpcMessage(ow, npc, game, reaction) end
    end
    local gym
    for _, candidate in ipairs(data.gyms) do
      if npc.def.trainerClass == candidate.class and ow.map.id == candidate.map then
        gym = candidate
        break
      end
    end
    if not gym then return false end
    if not allMaster(s) then
      return offerGymBattle(ow, npc, gym, "master")
    end
    if not crownUnlocked(s, game.save) then
      npc.frozen = true
      npc:facePlayer(ow.player)
      local text
      if not s.apexChampion then
        text = gymDialogue(gym, nil, "apexGate")
          or tr("All eight crests!\nThe APEX ELITE\nawaits at INDIGO.",
            "Alle acht Wappen!\nDie APEX-LIGA\nwartet am INDIGO.")
      else
        text = gymDialogue(gym, nil, "legendGate")
          or tr("The legends have\nawakened. Find\nLUGIA and HO-OH.",
            "Die Legenden sind\nerwacht. Finde\nLUGIA und HO-OH.")
      end
      game.stack:push(require("src.render.TextBox").new(game, text,
        function() npc.frozen = false end))
      return true
    end
    return offerGymBattle(ow, npc, gym, "crown")
  end

  local function showLegendTalk(game, ow, npc, done, species, level)
    local s = state()
    local setting = legendSetting(species)
    local static = data.staticLegends[species]
    if setting == "off" then
      game.stack:push(require("src.render.TextBox").new(game,
        tr("This legend is\ndisabled in the\nmod options.",
          "Diese Legende ist\nin den Mod-Optionen\nausgeschaltet."), done))
      return
    end
    if static and setting == "vanilla" then
      level = static.vanillaLevel or level
    end
    if caught(s, game.save, species) then
      game.stack:push(require("src.render.TextBox").new(game,
        tr("Only a quiet trace\nof power remains.",
          "Nur eine stille\nSpur ihrer Kraft\nist geblieben."), done))
      return
    end
    if not legendaryAvailable(species, s, game.save) then
      local text
      if not allMaster(s) then
        text = tr("A strange seal\nholds its power.\fWin all eight\nMASTER crests.",
          "Ein seltsames Siegel\nhält seine Kraft.\fErringe alle acht\nMEISTER-Wappen.")
      elseif not s.apexChampion then
        text = tr("A strange seal\nholds its power.\fDefeat the\nAPEX ELITE.",
          "Ein seltsames Siegel\nhält seine Kraft.\fBesiege die\nAPEX-LIGA.")
      else
        text = tr("Its power is near,\nbut another legend\nmust answer first.",
          "Seine Kraft ist nah,\ndoch zuerst muss\neine andere Legende\nantworten.")
      end
      game.stack:push(require("src.render.TextBox").new(game, text, done))
      return
    end

    local TextBox = require("src.render.TextBox")
    local function startBattle()
      local battle = require("src.battle.BattleState").newWild(game, species,
        level, { encounterSource = "static", randomizerProtected = true })
      battle.postgameLegend = species
      if data.roamers[species] then battle.postgameRoamer = species end
      battle.onFinish = function(result)
        if result == "caught" then
          markCaught(species, game.save)
          if static then
            setObjectToggle(game.save, static.map, static.object, false)
            if game.save.flags then game.save.flags[static.flag] = true end
            removeLiveNpc(ow, npc)
          elseif npc and npc.def and npc.def.runtime then
            mod.world:removeNpc(npc.id)
          end
        elseif data.roamers[species] and npc and npc.def
            and npc.def.runtime then
          -- The battle-ended event has moved this beast to another route.
          -- Remove its old visible body; it will be re-created on entry.
          mod.world:removeNpc(npc.id)
        elseif static and setting == "vanilla" and result == "win" then
          -- Vanilla static encounters disappear after a knockout as well
          -- as a capture. APEX mode deliberately persists until caught.
          setObjectToggle(game.save, static.map, static.object, false)
          if game.save.flags then game.save.flags[static.flag] = true end
          removeLiveNpc(ow, npc)
        end
        ow:afterBattle(result, battle)
        done()
      end
      ow:pushBattle(battle)
    end
    local function showChallenge()
      game.stack:push(TextBox.new(game,
        tr(("%s's power\nfills the air!"):format(data.species[species]
            and data.species[species].name or species),
          ("Die Kraft von %s\nerfüllt die Luft!"):format(data.species[species]
            and data.species[species].name or species)), startBattle))
    end
    local intro = events and events.legendIntro(species)
    if not intro then
      showChallenge()
      return
    end
    game.stack:push(TextBox.new(game, intro, function()
      pcall(require("src.core.Sound").playCry, game.data, species)
      local ok, Transition = pcall(require, "src.render.Transition")
      if ok and Transition and game.stack then
        game.stack:push(Transition.whiteFlash(game, 10, showChallenge))
      else
        showChallenge()
      end
    end))
  end

  local ARCHIVE_TEXT = "MOD_KANTO_ASCENDANT_CROWN_ARCHIVE"
  local function showTrophyArchive(game, done)
    local text = events and events.trophyText(
      state(), game.save, mod.save:get("trainers")) or
      tr("The archive is\nnot available.",
        "Das Archiv ist\nnicht verfügbar.")
    if controller.extension and controller.extension.archiveText then
      text = text .. controller.extension.archiveText(game)
    end
    game.stack:push(require("src.render.TextBox").new(game, text, done))
  end

  local function ensureTrophySign(game, mapId)
    if mapId ~= "HALL_OF_FAME" or not game then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local signs = ow.map.def.signs or {}
    ow.map.def.signs = signs
    local archive
    for _, sign in ipairs(signs) do
      if sign.x == 5 and sign.y == 1 then
        sign.text = ARCHIVE_TEXT
        archive = sign
        break
      end
    end
    if not archive then
      archive = { x = 5, y = 1, text = ARCHIVE_TEXT }
      signs[#signs + 1] = archive
    end
    ow.map.signAt = ow.map.signAt or {}
    ow.map.signAt[archive.y * ow.map.widthCells + archive.x] = archive
  end

  local function registerLegendTalks()
    if not controller.contentEnabled then return end
    -- The base Hall-of-Fame onEnter script normally adds two identical PC
    -- signs. Seed both here so it keeps the left return-home terminal while
    -- the right terminal remains the Crown Archive.
    mod.content.maps:patch("HALL_OF_FAME", {
      signs = {
        { x = 4, y = 1, text = "TEXT_HALLOFFAME_PC" },
        { x = 5, y = 1, text = ARCHIVE_TEXT },
      },
    })
    mod.content.map_scripts:register("HALL_OF_FAME", {
      priority = 1100,
      talk = {
        [ARCHIVE_TEXT] = function(game, _, _, done)
          showTrophyArchive(game, done)
        end,
      },
    })
    if data.huntRival then
      mod.content.map_scripts:register(data.huntRival.map, {
        priority = 1100,
        talk = {
          [data.huntRival.text] = function(game, ow, npc)
            offerHuntRival(ow, npc, game)
          end,
        },
      })
    end
    for species, def in pairs(data.staticLegends) do
      local id, row = species, def
      mod.content.map_scripts:register(row.map, {
        priority = 1000,
        talk = {
          [row.text] = function(game, ow, npc, done)
            showLegendTalk(game, ow, npc, done, id, row.level)
          end,
        },
      })
    end
    for species, def in pairs(data.spawnedLegends) do
      local id, row = species, def
      mod.content.map_scripts:register(row.map, {
        priority = 1000,
        talk = {
          [row.text] = function(game, ow, npc, done)
            showLegendTalk(game, ow, npc, done, id, row.level)
          end,
        },
      })
    end
    for _, mapId in ipairs(data.roamerRoutes) do
      local talk = {}
      for species, def in pairs(data.roamers) do
        local id, row = species, def
        talk[row.text] = function(game, ow, npc, done)
          showLegendTalk(game, ow, npc, done, id, row.level)
        end
      end
      mod.content.map_scripts:register(mapId, {
        priority = 1000,
        talk = talk,
      })
    end
  end

  registerLegendTalks()

  mod.hooks:wrap("trainer.party", function(nextParty, oppClass, partyIndex, party)
    local forced = forcedStack[#forcedStack]
    if forced and forced.class == oppClass
        and forced.syntheticIndex == partyIndex then
      forced.hookVisited = true
      return nextParty(oppClass, partyIndex, copyTeam(forced.intended))
    end
    if not ELITE_CLASSES[oppClass] or not controller.game then
      return nextParty(oppClass, partyIndex, party)
    end
    local s = state()
    local tier = eliteTier(s, controller.game.save)
    local team
    if tier == "crown" then team = enabledTeam(data.crown[oppClass])
    elseif tier == "apex" then team = enabledTeam(data.apex[oppClass]) end
    if team and controller.extension
        and controller.extension.selectBossTeam then
      team = controller.extension.selectBossTeam(team, {
        kind = "elite", key = oppClass, tier = tier,
      }, controller.game)
    end
    if team then return nextParty(oppClass, partyIndex, copyTeam(team)) end
    return nextParty(oppClass, partyIndex, party)
  end, 1000)

  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    if not (controller.contentEnabled and controller.game and ctx.terrain == "grass") then
      return nextRoll(encDef, ctx)
    end
    local s = state()
    if s.apexChampion then
      for species, roamer in pairs(data.roamers) do
        if legendaryAvailable(species, s, controller.game.save)
            and not caught(s, controller.game.save, species)
            and s.roamers[species] == ctx.mapId
            and ctx.rng(1, 32) == 1 then
          pendingRoamer = species
          return { species = species, level = roamer.level }
        end
      end
    end
    return nextRoll(encDef, ctx)
  end)

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    if pendingRoamer and battle.kind == "wild"
        and battle.enemy and battle.enemy.mon.species == pendingRoamer then
      battle.postgameRoamer = pendingRoamer
      pendingRoamer = nil
    end
    if battle.kind == "trainer" and ELITE_CLASSES[battle.oppClass]
        and controller.game then
      local tier = eliteTier(state(), controller.game.save)
      if tier then
        local team = tier == "crown" and enabledTeam(data.crown[battle.oppClass])
          or enabledTeam(data.apex[battle.oppClass])
        if team and controller.extension
            and controller.extension.selectBossTeam then
          team = controller.extension.selectBossTeam(team, {
            kind = "elite", key = battle.oppClass, tier = tier,
          }, controller.game)
        end
        if team and battle.enemyParty and battle.aiUsesFor then
          finalizeForcedBattle(controller.game, battle, team, {
            source = "elite", tier = tier,
            vanillaParty = battle.trainer and battle.trainer.parties
              and copyTeam(battle.trainer.parties[battle.partyIndex or 1]),
          })
        else
          battle.postgameTier = tier
          battle.postgameForcedTier = tier
          battle.ascendantForcedBattle = true
          battle.ascendantForcedSource = "elite"
          battle.rematch = true
        end
        battle.ascendantEnemyMegaSpecies = eliteMegaTarget(
          battle.oppClass, tier, team)
        if controller.extension and controller.extension.applyBossRules then
          controller.extension.applyBossRules(battle)
        end
        applyMastery(controller.game, battle, {
          kind = "elite", key = battle.oppClass, tier = tier,
        })
        if rematchRewards and not battle.phase8RewardWrapped then
          local previousFinish = battle.onFinish
          battle.onFinish = function(result)
            local reward
            if result == "win" then
              reward = rematchRewards.afterWin(controller.game, battle, nil)
            end
            if previousFinish then previousFinish(result) end
            if reward then
              controller.game.stack:push(
                require("src.render.TextBox").new(controller.game, reward))
            end
          end
          battle.phase8RewardWrapped = true
        end
        battle.endBattleText =
          eliteDialogue(battle.oppClass, tier, "win")
            or battle.endBattleText
      end
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    if battle.postgameRoamer and ev.result ~= "caught" then
      relocateRoamer(battle.postgameRoamer, controller.game,
        controller.game and controller.game.overworld
          and controller.game.overworld.map.id)
      removeRoamerObjects(controller.game, battle.postgameRoamer)
    end
    -- BattleState emits battle.ended before calling a battle's onFinish
    -- callback.  Record gym clears here as well so another callback wrapper
    -- cannot lose the permanent Master/Crown result.
    if ev.result == "win" and battle.postgameGym
        and (battle.postgameTier == "master"
          or battle.postgameTier == "crown") then
      local s = state()
      local wins = battle.postgameTier == "crown"
        and s.crownWins or s.masterWins
      wins[battle.postgameGym] = true
      persist(s)
    end
    if ev.result ~= "win" or not battle.postgameTier
        or not ELITE_CLASSES[battle.oppClass] then return end
    local s = state()
    local wins = battle.postgameTier == "crown"
      and s.eliteCrownWins or s.eliteApexWins
    wins[battle.oppClass] = true
    local fourWon = true
    for _, class in ipairs(ELITE_FOUR) do
      if not wins[class] then fourWon = false break end
    end
    if battle.oppClass == "OPP_RIVAL3" and fourWon then
      if battle.postgameTier == "crown" then s.crownChampion = true
      else s.apexChampion = true end
    end
    persist(s)
    if s.apexChampion then
      initRoamers(controller.game)
      syncPersistentObjects(controller.game)
    end
  end)

  mod.events:on("pokemon.caught", function(ev)
    if not (ev and ev.species) then return end
    for _, species in ipairs(data.legendOrder) do
      if species == ev.species then
        markCaught(species, ev.game and ev.game.save)
        removeRoamerObjects(controller.game or (ev.game and ev.game), species)
        return
      end
    end
  end)

  mod.events:on("map.entered", function(ev)
    if not controller.game then return end
    applyEliteDialogue(ev.mapId, controller.game)
    syncPersistentObjects(controller.game, ev.mapId)
    initRoamers(controller.game)
    ensureTrophySign(controller.game, ev.mapId)
    ensureHuntRival(controller.game, ev.mapId)
    -- Roamers are not pinned forever: changing maps gives each uncaught
    -- beast a one-in-four chance to move somewhere else.
    local s = state()
    if s.apexChampion then
      for species in pairs(data.roamers) do
        if legendaryAvailable(species, s, controller.game.save)
            and not caught(s, controller.game.save, species)
            and randomInt(1, 4) == 1 then
          relocateRoamer(species, controller.game, ev.mapId)
        end
      end
    end
    ensureSpawnedLegend(controller.game, ev.mapId)
    ensureRoamerObjects(controller.game, ev.mapId)
  end)

  mod.events:on("save.loaded", function(ev)
    if ev and ev.save then
      repairGymWinsFromHistory()
      syncOwned(ev.save)
      if controller.game then
        syncPersistentObjects(controller.game)
        initRoamers(controller.game)
        local ow = mod.world:overworld()
        local mapId = ow and ow.map and ow.map.id
        ensureTrophySign(controller.game, mapId)
        ensureHuntRival(controller.game, mapId)
      end
    end
  end)

  mod.events:on("mod.options_changed", function(ev)
    if not (ev and ev.mod == mod.id and controller.game) then return end
    local ow = mod.world:overworld()
    local mapId = ow and ow.map and ow.map.id
    if mapId then applyEliteDialogue(mapId, controller.game) end
    syncPersistentObjects(controller.game, mapId)
    initRoamers(controller.game)
    ensureTrophySign(controller.game, mapId)
    ensureHuntRival(controller.game, mapId)
    if mapId then
      ensureSpawnedLegend(controller.game, mapId)
      ensureRoamerObjects(controller.game, mapId)
    end
  end)

  mod.events:on("game.ready", function(ev)
    controller.game = ev.game
    repairGymWinsFromHistory()
    local ow = mod.world:overworld()
    local mapId = ow and ow.map and ow.map.id
    if mapId then applyEliteDialogue(mapId, ev.game) end
    syncPersistentObjects(ev.game)
    initRoamers(ev.game)
    ensureTrophySign(ev.game, mapId)
    ensureHuntRival(ev.game, mapId)
  end)

  controller.state = state
  controller.repairGymWinsFromHistory = repairGymWinsFromHistory
  controller.hasHallOfFame = hasHallOfFame
  controller.allMaster = allMaster
  controller.allCrown = allCrown
  controller.caught = caught
  controller.legendSetting = legendSetting
  controller.legendaryAvailable = legendaryAvailable
  controller.beyondActive = beyondActive
  controller.enabledTeam = enabledTeam
  controller.eliteMegaTarget = eliteMegaTarget
  controller.phaseFor = phaseFor
  controller.eliteTier = eliteTier
  controller.gymDialogue = gymDialogue
  controller.gymRestDialogue = gymRestDialogue
  controller.eliteDialogue = eliteDialogue
  controller.currentRivalIdentity = currentRivalIdentity
  controller.applyStoryOakDialogue = applyStoryOakDialogue
  controller.applyEliteDialogue = applyEliteDialogue
  controller.events = events
  controller.ensureTrophySign = ensureTrophySign
  controller.ensureHuntRival = ensureHuntRival
  controller.crownUnlocked = crownUnlocked
  controller.birdsCaught = birdsCaught
  controller.beastsCaught = beastsCaught
  controller.newForcedBattle = newForcedBattle
  controller.finalizeForcedBattle = finalizeForcedBattle
  controller.applyMastery = applyMastery
  controller.setMastery = function(value, progress)
    mastery = value
    bossProgress = progress
    return mastery ~= nil
  end
  controller.forcedConstructionDepth = function() return #forcedStack end
  return controller
end
