-- Save-local Story Level Cap controller.
--
-- The engine owns experience arithmetic.  This module owns only policy:
-- which mandatory opponent is next, which real team that opponent will use,
-- and which optional stable-id override applies.  A missing or future state
-- always reads as OFF and is never normalized as a side effect.

return function(mod, opts)
  opts = opts or {}
  local C = {
    STATE_KEY = "story_level_cap",
    SCHEMA_VERSION = 1,
  }

  local storyGym = opts.storyGym
  local difficulty = opts.difficulty
  local adaptive = opts.adaptiveTrainerLevels
  local rivalTeams = opts.rivalTeams
  local postgame = opts.postgame
  local postgameData = opts.postgameData or {}
  local gameVersion = opts.gameVersion
  local rivalIdentity = opts.rivalIdentity
  local currentGame = mod.game
  local inBattle = false
  local activeBattleCap

  local MODES = { off = true, story = true, custom = true }

  local function present(value)
    return value == true or (tonumber(value) or 0) > 0
  end

  local function hasItem(save, id)
    return present(save and save.inventory and save.inventory[id])
      or present(save and save.pcItems and save.pcItems[id])
  end

  local function hasFlag(save, id)
    return save and save.flags and save.flags[id] == true or false
  end

  local function hasReceipt(save, item, flag)
    return hasItem(save, item) or (flag and hasFlag(save, flag)) or false
  end

  local SEVEN_BADGES = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE",
  }

  local function hasSevenBadges(save)
    for _, badge in ipairs(SEVEN_BADGES) do
      if not hasItem(save, badge) then return false end
    end
    return true
  end

  local GYMS = {
    { id = "gym:brock", key = "brock", label = "BROCK",
      class = "OPP_BROCK", party = 1, badge = "BOULDERBADGE",
      open = function() return true end },
    { id = "gym:misty", key = "misty", label = "MISTY",
      class = "OPP_MISTY", party = 1, badge = "CASCADEBADGE",
      open = function(save) return hasItem(save, "BOULDERBADGE") end },
    { id = "gym:surge", key = "surge", label = "LT.SURGE",
      class = "OPP_LT_SURGE", party = 1, badge = "THUNDERBADGE",
      open = function(save)
        return hasItem(save, "CASCADEBADGE")
          and hasReceipt(save, "HM_CUT", "EVENT_GOT_HM01")
      end },
    { id = "gym:erika", key = "erika", label = "ERIKA",
      class = "OPP_ERIKA", party = 1, badge = "RAINBOWBADGE",
      open = function(save)
        return hasItem(save, "CASCADEBADGE")
          and hasReceipt(save, "HM_CUT", "EVENT_GOT_HM01")
      end },
    { id = "gym:koga", key = "koga", label = "KOGA",
      class = "OPP_KOGA", party = 1, badge = "SOULBADGE",
      open = function(save)
        return hasReceipt(save, "BICYCLE", "EVENT_GOT_BICYCLE")
          or hasReceipt(save, "POKE_FLUTE", "EVENT_GOT_POKE_FLUTE")
      end },
    { id = "gym:sabrina", key = "sabrina", label = "SABRINA",
      class = "OPP_SABRINA", party = 1, badge = "MARSHBADGE",
      open = function(save)
        return (save.flags or {}).EVENT_BEAT_SILPH_CO_GIOVANNI == true
      end },
    { id = "gym:blaine", key = "blaine", label = "BLAINE",
      class = "OPP_BLAINE", party = 1, badge = "VOLCANOBADGE",
      open = function(save)
        return hasItem(save, "SOULBADGE") and hasItem(save, "SECRET_KEY")
      end },
    { id = "gym:giovanni", key = "giovanni", label = "GIOVANNI",
      class = "OPP_GIOVANNI", party = 3, badge = "EARTHBADGE",
      open = function(save) return hasSevenBadges(save) end },
  }

  local LEAGUE = {
    { id = "league:lorelei", key = "lorelei", label = "LORELEI",
      class = "OPP_LORELEI", party = 1,
      won = "EVENT_BEAT_LORELEIS_ROOM_TRAINER_0" },
    { id = "league:bruno", key = "bruno", label = "BRUNO",
      class = "OPP_BRUNO", party = 1,
      won = "EVENT_BEAT_BRUNOS_ROOM_TRAINER_0" },
    { id = "league:agatha", key = "agatha", label = "AGATHA",
      class = "OPP_AGATHA", party = 1,
      won = "EVENT_BEAT_AGATHAS_ROOM_TRAINER_0" },
    { id = "league:lance", key = "lance", label = "LANCE",
      class = "OPP_LANCE", party = 1, won = "EVENT_BEAT_LANCE" },
    { id = "league:champion", key = "champion", label = "GARY",
      class = "OPP_RIVAL3", party = 1,
      won = "EVENT_BEAT_CHAMPION_RIVAL_THIS_RUN", champion = true },
  }

  local function clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = clone(child) end
    return out
  end

  local function rawState()
    local raw = mod.save:get(C.STATE_KEY)
    if type(raw) ~= "table" then return nil, false end
    local version = tonumber(raw.version)
    if version and version > C.SCHEMA_VERSION then return raw, true end
    if version ~= C.SCHEMA_VERSION then return nil, false end
    return raw, false
  end

  local function readableState()
    local raw, future = rawState()
    if future then return nil, true end
    if not raw then
      return { version = C.SCHEMA_VERSION, mode = "off", overrides = {} }, false
    end
    local mode = MODES[raw.mode] and raw.mode or "off"
    local overrides = {}
    if type(raw.overrides) == "table" then
      for id, value in pairs(raw.overrides) do
        value = tonumber(value)
        if type(id) == "string" and value and value == math.floor(value)
            and value >= 1 and value <= 100 then
          overrides[id] = value
        end
      end
    end
    return { version = C.SCHEMA_VERSION, mode = mode, overrides = overrides }, false
  end

  local function persist(state)
    mod.save:set(C.STATE_KEY, {
      version = C.SCHEMA_VERSION,
      mode = state.mode,
      overrides = clone(state.overrides),
    })
  end

  local function badgeCount(game)
    local save = game and game.save or {}
    local bag = save.inventory or {}
    local count = 0
    for _, row in ipairs(GYMS) do
      if present(bag[row.badge]) then count = count + 1 end
    end
    return count
  end

  local function hasHallOfFame(save)
    if postgame and type(postgame.hasHallOfFame) == "function" then
      local ok, result = pcall(postgame.hasHallOfFame, save)
      if ok then return result == true end
    end
    return save and ((type(save.hallOfFame) == "table"
      and #save.hallOfFame > 0)
      or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL == true)) or false
  end

  local function edition(game)
    if gameVersion and type(gameVersion.get) == "function" then
      local ok, value = pcall(gameVersion.get)
      if ok and (value == "red" or value == "blue" or value == "yellow") then
        return value
      end
    end
    local value = game and game.save and game.save.version
    if value == "blue" or value == "yellow" then return value end
    return "red"
  end

  local function difficultyName()
    local ok, value = pcall(function()
      return mod.options and mod.options.get
        and mod.options:get("difficulty") or "standard"
    end)
    return ok and type(value) == "string" and value or "standard"
  end

  local function liveParty(game, class, partyIndex)
    local trainers = game and game.data and game.data.trainers
    local trainer = trainers and trainers[class]
    local parties = trainer and trainer.parties
    local party = parties and parties[partyIndex]
    return type(party) == "table" and clone(party) or nil
  end

  local function adjustedParty(game, party)
    if type(party) ~= "table" then return nil end
    if difficulty and type(difficulty.adjustParty) == "function" then
      local ok, adjusted = pcall(difficulty.adjustParty, party, badgeCount(game))
      if ok and type(adjusted) == "table" then return adjusted end
    end
    return party
  end

  local function adaptiveParty(game, party, ceiling)
    -- STORY is progression-bound; feeding the player-scaled opponent back
    -- into its EXP cap would let that cap rise with the player forever.
    local state, future = readableState()
    if not future and state.mode == "story" then return party end
    if type(party) ~= "table" or not (adaptive
        and type(adaptive.planAdjusted) == "function"
        and type(adaptive.currentSelection) == "function") then
      return party
    end
    local okSelection, selection = pcall(adaptive.currentSelection)
    if not okSelection or selection == nil then return party end
    local ok, planned = pcall(adaptive.planAdjusted,
      party, game and game.save and game.save.party or {}, {
        selection = selection,
        difficultyName = difficultyName(),
        pokemon = game and game.data and game.data.pokemon,
        maxLevel = ceiling or 100,
      })
    return ok and type(planned) == "table" and planned or party
  end

  local function maxLevel(party)
    local level
    for _, mon in ipairs(type(party) == "table" and party or {}) do
      local value = tonumber(type(mon) == "table" and mon.level)
      if value and value == math.floor(value) and value >= 1 then
        level = math.max(level or 1, math.min(100, value))
      end
    end
    return level
  end

  local function championPartyIndex(game)
    local save = game.save or {}
    if edition(game) == "yellow" then
      return math.max(1, math.min(3,
        math.floor(tonumber(save.rivalStarter) or 1)))
    end
    local gameFlags = save.flags or {}
    local mappings = game.data and game.data.field
      and game.data.field.starterCounterpicks
    if type(mappings) == "table" then
      for flag, offset in pairs(mappings) do
        if gameFlags[flag] then
          return 1 + math.max(0, math.floor(tonumber(offset) or 0))
        end
      end
    end
    if gameFlags.EVENT_CHOSE_SQUIRTLE then return 2 end
    if gameFlags.EVENT_CHOSE_BULBASAUR then return 3 end
    return 1
  end

  local function teamForGym(game, def)
    local party = liveParty(game, def.class, def.party)
    local authority = storyGym and storyGym.authored
      and storyGym.authored[def.class]
    if party and storyGym and type(storyGym.plan) == "function" then
      local ok, planned, plannedAuthority = pcall(storyGym.plan,
        edition(game), difficultyName(), def.class, party)
      if ok and type(planned) == "table" then party = planned end
      if ok and type(plannedAuthority) == "table" then
        authority = plannedAuthority
      end
    end
    party = adjustedParty(game, party)
    return adaptiveParty(game, party,
      authority and tonumber(authority.ceiling))
  end

  local function teamForLeague(game, def)
    local partyIndex = def.champion and championPartyIndex(game) or def.party
    local party = liveParty(game, def.class, partyIndex)
    if def.champion and party and rivalTeams
        and type(rivalTeams.resolve) == "function" then
      local identity = "BLUE"
      if type(rivalIdentity) == "function" then
        local ok, value = pcall(rivalIdentity)
        if ok and (value == "RED" or value == "GREEN" or value == "BLUE") then
          identity = value
        end
      end
      local ok, resolved = pcall(
        rivalTeams.resolve, identity, def.class, partyIndex, party,
        edition(game) == "yellow")
      if ok and type(resolved) == "table" then party = resolved end
    end
    party = adjustedParty(game, party)
    return adaptiveParty(game, party, 100), partyIndex
  end

  local function stageWithTeam(def, kind, party, partyIndex)
    if type(party) ~= "table" then return nil end
    local level = maxLevel(party)
    if not level then return nil end
    local out = clone(def)
    out.kind = kind
    out.party = partyIndex or def.party
    out.team = party
    out.level = level
    out.open = nil
    out.won = nil
    return out
  end

  local function gymStage(game, def)
    return stageWithTeam(def, "gym", teamForGym(game, def), def.party)
  end

  local function leagueStage(game, def)
    local party, partyIndex = teamForLeague(game, def)
    local out = stageWithTeam(def, "league", party, partyIndex)
    if out and def.champion then
      local rival = game.save and game.save.player and game.save.player.rival
      if type(rival) == "string" and rival ~= "" then out.label = rival:upper() end
    end
    return out
  end

  local function masterDefs()
    local out = {}
    for _, gym in ipairs(postgameData.gyms or {}) do
      out[#out + 1] = {
        id = "master:" .. tostring(gym.key), key = gym.key,
        label = gym.name or tostring(gym.key):upper(), class = gym.class,
        party = 1, source = gym,
      }
    end
    return out
  end

  local function masterStage(game, def)
    local team = def.source and clone(def.source.master)
    -- Dedicated Master-Circuit battles normalize back to postgame_data after
    -- the generic trainer hook. Ordinary Difficulty/Adaptive composition is
    -- therefore deliberately not applied here.
    return stageWithTeam(def, "master", team, 1)
  end

  local function progression(game)
    game = game or currentGame
    if not (game and game.save) then return nil, {}, nil end
    local bag = type(game.save.inventory) == "table" and game.save.inventory or {}
    local gameFlags = type(game.save.flags) == "table" and game.save.flags or {}
    local count = badgeCount(game)

    if hasHallOfFame(game.save) then
      local state = postgame and type(postgame.state) == "function"
        and postgame.state(false) or nil
      local wins = type(state) == "table"
        and type(state.masterWins) == "table" and state.masterWins or {}
      local defs = masterDefs()
      for index, def in ipairs(defs) do
        if not wins[def.key] then return masterStage(game, def), defs, index end
      end
      return nil, defs, nil
    end

    if count < #GYMS then
      for index, def in ipairs(GYMS) do
        if not present(bag[def.badge]) and def.open(game.save, count) then
          return gymStage(game, def), GYMS, index
        end
      end
      -- A damaged or externally imported save may lack the route flags that
      -- explain its badges.  Do not invent an open fight for that save.
      return nil, GYMS, nil
    end

    for index, def in ipairs(LEAGUE) do
      if not gameFlags[def.won] then
        return leagueStage(game, def), LEAGUE, index
      end
    end
    return nil, LEAGUE, nil
  end

  local function materialize(game, def)
    if not def then return nil end
    if def.id:sub(1, 4) == "gym:" then return gymStage(game, def) end
    if def.id:sub(1, 7) == "league:" then return leagueStage(game, def) end
    return masterStage(game, def)
  end

  function C.mode()
    local state, future = readableState()
    return future and "off" or state.mode
  end

  function C.currentStage(game)
    return progression(game)
  end

  function C.upcomingStage(game)
    game = game or currentGame
    local _, defs, index = progression(game)
    if not (game and index) then return nil end
    if defs == GYMS then
      local bag = type(game.save.inventory) == "table"
        and game.save.inventory or {}
      for nextIndex = index + 1, #defs do
        local def = defs[nextIndex]
        if not present(bag[def.badge]) then
          return materialize(game, def)
        end
      end
    elseif defs == LEAGUE then
      local gameFlags = type(game.save.flags) == "table"
        and game.save.flags or {}
      for nextIndex = index + 1, #defs do
        local def = defs[nextIndex]
        if not gameFlags[def.won] then return materialize(game, def) end
      end
    else
      local state = postgame and type(postgame.state) == "function"
        and postgame.state(false) or nil
      local wins = type(state) == "table"
        and type(state.masterWins) == "table" and state.masterWins or {}
      for nextIndex = index + 1, #defs do
        if not wins[defs[nextIndex].key] then
          return materialize(game, defs[nextIndex])
        end
      end
    end
    return nil
  end

  function C.levelForStage(stage)
    if type(stage) ~= "table" then return nil end
    local out = clone(stage)
    local state, future = readableState()
    if not future and state.mode == "custom" and state.overrides[out.id] then
      out.derivedLevel = out.level
      out.level = state.overrides[out.id]
      out.custom = true
    end
    return out
  end

  function C.effective(game)
    if inBattle and activeBattleCap then return clone(activeBattleCap) end
    local state, future = readableState()
    if future or state.mode == "off" then return nil end
    return C.levelForStage(C.currentStage(game or currentGame))
  end

  function C.summary(game)
    local cap = C.effective(game or currentGame)
    if not cap then
      return C.mode() == "off" and "CAP: OFF" or "CAP: NONE"
    end
    return ("CAP: %s · LV%d"):format(cap.label, cap.level)
  end

  function C.setMode(mode)
    if inBattle or not MODES[mode] then return false end
    local state, future = readableState()
    if future then return false end
    state.mode = mode
    persist(state)
    return true
  end

  function C.setOverride(id, level)
    if inBattle or type(id) ~= "string" then return false end
    level = tonumber(level)
    if not level or level ~= math.floor(level) or level < 1 or level > 100 then
      return false
    end
    local state, future = readableState()
    if future then return false end
    state.overrides[id] = level
    persist(state)
    return true
  end

  function C.resetOverride(id)
    if inBattle or type(id) ~= "string" then return false end
    local state, future = readableState()
    if future then return false end
    state.overrides[id] = nil
    persist(state)
    return true
  end

  function C.resetAll()
    if inBattle then return false end
    local state, future = readableState()
    if future then return false end
    state.overrides = {}
    persist(state)
    return true
  end

  function C.canEdit()
    local _, future = readableState()
    return not inBattle and not future
  end

  function C.isFutureState()
    local _, future = rawState()
    return future
  end

  -- Newer engine builds retain exp.gain but may not implement
  -- pokemon.level_cap. Clamp the final award, after reward multipliers.
  mod.hooks:wrap("exp.gain", function(nextGain, context)
    local gained = nextGain(context)
    if C.mode() ~= "story" then return gained end
    local game = context and context.game or currentGame
    local mon = context and context.mon
    local cap = C.effective(game)
    if not (cap and mon) then return gained end
    if (tonumber(mon.level) or 0) >= cap.level then return 0 end
    local data = context and context.data or game and game.data
    local def = data and data.pokemon and data.pokemon[mon.species]
    if not def then return gained end
    local Growth = require("src.pokemon.Growth")
    local limit = Growth.expForLevel(def.growthRate, cap.level, data.growth_rates)
    return math.max(0, math.min(tonumber(gained) or 0,
      limit - (tonumber(mon.exp) or 0)))
  end, 10000)

  local function installCandyGuard()
    local ok, effects = pcall(require, "src.inventory.ItemEffects")
    if not (ok and type(effects.use) == "function") then return end
    local key = "__ascendantStoryCapCandy"
    local holder = rawget(effects, key)
    if not holder then
      holder = { use = effects.use }
      effects.use = function(data, save, item, target, battle, ...)
        if item == "RARE_CANDY" and target and holder.blocked(save, target) then
          return "failed", { require("src.core.RomText")(data,
            "_ItemUseNoEffectText", "It won't have\nany effect.") }
        end
        return holder.use(data, save, item, target, battle, ...)
      end
      rawset(effects, key, holder)
    end
    holder.blocked = function(save, mon)
      if C.mode() ~= "story" or not currentGame or currentGame.save ~= save then
        return false
      end
      local Runtime = require("src.mods.Runtime")
      if not Runtime.wantsHook("pokemon.level_cap") then return false end
      local cap = C.effective(currentGame)
      return cap and (tonumber(mon.level) or 0) >= cap.level or false
    end
  end

  local function rememberGame(ev)
    currentGame = ev and ev.game or currentGame or mod.game
    inBattle = false
    activeBattleCap = nil
    installCandyGuard()
  end
  mod.events:on("game.ready", rememberGame, 170)
  mod.events:on("save.loaded", rememberGame, 170)
  mod.events:on("battle.started", function()
    inBattle = true
    activeBattleCap = nil
  end, 1000)
  -- Freeze the progression cap after Difficulty (170) and Gym metadata
  -- (180), but BEFORE Adaptive (-100) reads the opponent ceiling. Never
  -- derive the player cap from the already scaled enemy party.
  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    local game = battle and battle.game or currentGame
    activeBattleCap = C.effective(game)
    if not (activeBattleCap and C.mode() == "story" and battle
        and battle.kind == "trainer"
        and battle.oppClass == activeBattleCap.class
        and tonumber(battle.partyIndex) == tonumber(activeBattleCap.party)
        and (activeBattleCap.kind ~= "master"
          or battle.postgameGym == activeBattleCap.key)) then
      return
    end
    local ceiling = tonumber(battle.ascendantStoryLevelCeiling)
    battle.ascendantStoryLevelCeiling = math.min(ceiling or 100,
      activeBattleCap.level)
  end, 0)
  mod.events:on("battle.ended", function()
    inBattle = false
    activeBattleCap = nil
  end, -1000)

  mod.hooks:wrap("pokemon.level_cap", function(nextCap, context)
    local downstream = nextCap(context)
    local own = C.effective(context and context.game or currentGame)
    own = own and tonumber(own.level) or nil
    downstream = tonumber(downstream)
    if own and downstream then return math.min(own, downstream) end
    return own or downstream
  end, 100)

  C.gyms = clone(GYMS)
  C.league = clone(LEAGUE)
  return C
end
