-- KASC-67-DIFFICULTY-TEAM-CONTRACTS
--
-- One read-only authority separates the five trainer lanes which used to be
-- inferred independently by Gym, rival, adaptive and rematch code.  It does
-- not build teams.  Producers submit their finished plan here before they
-- replace an official roster; invalid optional plans fail closed to the
-- caller's classic roster.

return function(mod, opts)
  opts = opts or {}
  local C = {
    CARD_ID = "KASC-67-DIFFICULTY-TEAM-CONTRACTS",
    OWNER = "kasc.difficulty.team-contracts/v1",
    VERSION = "1.0.0",
  }

  local RIVAL = {
    OPP_RIVAL1=true, OPP_RIVAL2=true, OPP_RIVAL3=true,
  }
  local BADGES = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }
  local LANES = {
    gym = {
      owner="story_gym_difficulty", authoredSpecies=true,
      adaptive=true, lossRelief=false, money="native", caps={4,6,6},
    },
    story_rival = {
      owner="rival_teams", authoredSpecies=true,
      adaptive=true, lossRelief=false, money="native", caps={4,6,6},
    },
    required = {
      owner="native-story", authoredSpecies=false,
      adaptive=true, lossRelief=false, money="native", caps={4,6,6},
    },
    expert_rematch = {
      owner="trainer-rematch", authoredSpecies=true,
      adaptive=true, lossRelief=false, money="none", caps={4,6,6},
    },
    surprise = {
      owner="legacy-wanderers", authoredSpecies=false,
      adaptive=false, lossRelief=true, money="none", caps={4,4,4},
    },
  }

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function owner(save)
    local modData = type(save and save.modData) == "table" and save.modData
      or {}
    return type(modData[mod.id]) == "table" and modData[mod.id] or {}
  end

  local function edition(game, override)
    local value = override or game and game.save and game.save.version
      or "unknown"
    value = tostring(value):lower()
    if value == "red" or value == "blue" or value == "yellow" then
      return value
    end
    return "unknown"
  end

  local function badgeCount(save)
    local inventory = type(save and save.inventory) == "table"
      and save.inventory or {}
    local count = 0
    for _, id in ipairs(BADGES) do if inventory[id] then count = count + 1 end end
    return count
  end

  local function phase(save, override)
    if override == "early" or override == "middle" or override == "endgame"
        then return override end
    local hall = type(save and save.hallOfFame) == "table"
      and #save.hallOfFame > 0
    local champion = save and save.flags
      and save.flags.EVENT_BEAT_CHAMPION_RIVAL == true
    if hall or champion then return "endgame" end
    return badgeCount(save) <= 2 and "early"
      or badgeCount(save) <= 6 and "middle" or "endgame"
  end

  local function runMode(save, override)
    if override then return override end
    local root = owner(save)
    local rules = type(root.run_rules) == "table" and root.run_rules or {}
    local randomizer = type(rules.randomizer) == "table"
      and rules.randomizer or {}
    local nuzlocke = type(rules.nuzlocke) == "table" and rules.nuzlocke or {}
    if rules.locked == true and randomizer.enabled == true
        and randomizer.trainers ~= false then return "randomizer" end
    if rules.locked == true and nuzlocke.mode
        and nuzlocke.mode ~= "off" then return "nuzlocke" end
    local legacy = type(root.legacy_journey) == "table"
      and root.legacy_journey or {}
    if legacy.active == true or legacy.runId ~= nil then return "legacy" end
    return "normal"
  end

  function C.context(game, overrides)
    overrides = overrides or {}
    local save = game and game.save or overrides.save or {}
    local currentPhase = phase(save, overrides.phase)
    return {
      edition=edition(game, overrides.edition),
      runMode=runMode(save, overrides.runMode),
      phase=currentPhase,
      phaseIndex=currentPhase == "early" and 1
        or currentPhase == "middle" and 2 or 3,
      badges=badgeCount(save),
    }
  end

  function C.classify(battle)
    if type(battle) ~= "table" or battle.kind ~= "trainer" then return nil end
    if battle.ascendantLegacyWanderer or battle.surpriseTrainer
        or battle.ascendantLossRelief then return "surprise" end
    if battle.rematch or battle.rematchTrainerKey or battle.expertRematch then
      return "expert_rematch"
    end
    if battle.ascendantStoryGym or battle.ascendantStoryGymClass then
      return "gym"
    end
    if RIVAL[battle.oppClass] then return "story_rival" end
    return "required"
  end

  function C.contract(lane, game, overrides)
    local base = LANES[lane]
    if not base then return nil, "unknown_lane" end
    local context = C.context(game, overrides)
    local row = copy(base)
    row.lane, row.context = lane, context
    row.maxTeam = row.caps[context.phaseIndex]
    row.authoredSpecies = row.authoredSpecies
      and context.runMode ~= "randomizer"
    row.randomizerOwnsSpecies = context.runMode == "randomizer"
    row.nuzlockeNeutral = context.runMode == "nuzlocke"
    return row
  end

  local function speciesAllowed(game, species)
    local rules = opts.generationRules
    if not (game and game.data and game.data.pokemon) then return true end
    local def = game.data.pokemon[species]
    if type(def) ~= "table" then return false, "missing_species" end
    if rules and type(rules.speciesAvailable) == "function" then
      local ok, allowed = pcall(rules.speciesAvailable, game, species, def)
      if not ok or allowed ~= true then return false, "generation_locked" end
    end
    return true
  end

  local function movesAllowed(game, mon)
    local rules = opts.generationRules
    if not (rules and type(rules.moveAvailable) == "function"
        and game and game.data) then return true end
    local resolved = type(rules.resolve) == "function" and rules.resolve(game)
    local epoch = resolved and tonumber(resolved.activeEpoch) or 1
    for index, value in ipairs(type(mon.moves) == "table" and mon.moves or {}) do
      local id = type(value) == "table" and (value.id or value.move) or value
      local called, available = pcall(rules.moveAvailable,
        id, epoch, game.data)
      if type(id) ~= "string" or not called or available ~= true then
        return false, "generation_locked_move:" .. tostring(index)
      end
    end
    return true
  end

  function C.validatePlan(lane, game, party, overrides)
    local contract, why = C.contract(lane, game, overrides)
    if not contract then return false, why end
    if type(party) ~= "table" or #party < 1 or #party > contract.maxTeam then
      return false, "team_size", contract
    end
    for index, mon in ipairs(party) do
      local level = type(mon) == "table" and tonumber(mon.level)
      local species = type(mon) == "table" and mon.species
      if type(species) ~= "string" or species == "" or not level
          or level ~= math.floor(level) or level < 1 or level > 100 then
        return false, "invalid_slot:" .. tostring(index), contract
      end
      local allowed, speciesWhy = speciesAllowed(game, species)
      if not allowed then
        return false, speciesWhy .. ":" .. tostring(index), contract
      end
      local legalMoves, moveWhy = movesAllowed(game, mon)
      if not legalMoves then
        return false, moveWhy .. ":" .. tostring(index), contract
      end
    end
    return true, {
      cardId=C.CARD_ID, owner=C.OWNER, version=C.VERSION,
      lane=lane, edition=contract.context.edition,
      runMode=contract.context.runMode, phase=contract.context.phase,
      maxTeam=contract.maxTeam,
      randomizerOwnsSpecies=contract.randomizerOwnsSpecies,
      nuzlockeNeutral=contract.nuzlockeNeutral,
      adaptive=contract.adaptive, lossRelief=contract.lossRelief,
    }
  end

  function C.attach(battle)
    local lane = C.classify(battle)
    if not lane then return false, "not_trainer" end
    local ok, receipt, contract = C.validatePlan(lane, battle.game,
      battle.enemyParty, battle.ascendantTeamContractContext)
    if ok then
      battle.ascendantTeamContract = receipt
    else
      battle.ascendantTeamContractViolation = receipt
      battle.ascendantTeamContract = {
        cardId=C.CARD_ID, owner=C.OWNER, version=C.VERSION,
        lane=lane, compliant=false, reason=receipt,
        edition=contract and contract.context.edition or "unknown",
        runMode=contract and contract.context.runMode or "unknown",
        phase=contract and contract.context.phase or "unknown",
      }
    end
    return ok, receipt
  end

  function C.allowAdaptive(battle)
    local lane = C.classify(battle)
    local row = lane and LANES[lane]
    return row and row.adaptive == true or false, lane
  end

  if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
    opts.supportLog.registerSegment({
      segmentId=C.CARD_ID, cardId=C.CARD_ID, version=C.VERSION,
      schema="kasc.team-contract-card/v1", owner=C.OWNER,
      -- This Card is an always-on safety/governance boundary. The existing
      -- SCHWIERIGKEITS-TEAMS option still owns only the authored Gym additions;
      -- disabling those additions must not disable validation receipts for
      -- native rivals, mandatory trainers or rematches.
      active=true,
      dependencyStatus="local-reviewed", providerStatus="runtime-loaded",
      buildReceiptId="docs/DIFFICULTY_TEAM_CONTRACTS_67.md",
      rollbackReceiptId="revert-contract-card-commit",
      pureData=true,
    })
  end
  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("battle.started", function(ev)
      C.attach(ev and ev.battle)
    end, -800)
  end

  C.lanes = copy(LANES)
  C.rivalClasses = copy(RIVAL)
  return C
end
