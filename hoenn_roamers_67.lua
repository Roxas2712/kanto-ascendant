-- KASC 6.7 Latias/Latios persistent roaming card.
--
-- Normal Hoenn field access (Honey + Hoenn Dex, outside Legacy NG+) is the
-- only activation authority.  Each Eon Pokemon owns one durable identity:
-- route, DVs, HP, status and KO recovery all survive save/reload.

return function(mod, opts)
  opts = opts or {}
  local fieldAccess = assert(opts.fieldAccess, "Hoenn field access missing")
  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end
  local R = {
    SAVE_KEY = "hoenn_roamers_67",
    STATE_VERSION = 1,
    LEVEL = 40,
    ENCOUNTER_DENOMINATOR = 32,
    KO_RECOVERY_MAPS = 3,
    ENCOUNTER_PRIORITY = 120,
    EVENT_PRIORITY = 3950,
    order = { "LATIAS", "LATIOS" },
  }
  R.profiles = {
    LATIAS = { species="LATIAS", level=R.LEVEL },
    LATIOS = { species="LATIOS", level=R.LEVEL },
  }
  R.routes = {
    "ROUTE_1", "ROUTE_2", "ROUTE_3", "ROUTE_4", "ROUTE_5",
    "ROUTE_6", "ROUTE_7", "ROUTE_8", "ROUTE_9", "ROUTE_10",
    "ROUTE_11", "ROUTE_12", "ROUTE_13", "ROUTE_14", "ROUTE_15",
    "ROUTE_16", "ROUTE_17", "ROUTE_18", "ROUTE_22", "ROUTE_24",
    "ROUTE_25",
  }

  local activeGame, pending
  local randomInt = opts.randomInt or function(lo, hi)
    if love and love.math and love.math.random then return love.math.random(lo, hi) end
    return math.random(lo, hi)
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function normalize(raw)
    local out = type(raw) == "table" and copy(raw) or {}
    out.version = R.STATE_VERSION
    out.caught = type(out.caught) == "table" and out.caught or {}
    out.roamers = type(out.roamers) == "table" and out.roamers or {}
    for species, row in pairs(out.roamers) do
      if not R.profiles[species] or type(row) ~= "table" then
        out.roamers[species] = nil
      else
        row.map = type(row.map) == "string" and row.map or nil
        row.dvs = type(row.dvs) == "table" and row.dvs or nil
        row.hp = tonumber(row.hp) and math.max(1, math.floor(row.hp)) or nil
        row.status = row.status ~= nil and copy(row.status) or nil
        row.recovery = math.max(0, math.min(R.KO_RECOVERY_MAPS,
          math.floor(tonumber(row.recovery) or 0)))
        row.lastVisit = type(row.lastVisit) == "string" and row.lastVisit or nil
      end
    end
    return out
  end

  local function state(create)
    local raw = mod.save:get(R.SAVE_KEY)
    if type(raw) ~= "table" and create == false then return nil end
    local out = normalize(raw)
    mod.save:set(R.SAVE_KEY, out)
    return out
  end

  local function persist(out)
    out = normalize(out)
    mod.save:set(R.SAVE_KEY, out)
    return out
  end

  local function option(game, key, fallback)
    local bucket = game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket[key] ~= nil then return bucket[key] end
    local value = mod.options and mod.options.get and mod.options:get(key)
    return value == nil and fallback or value
  end

  function R.available(game)
    game = game or activeGame
    return game ~= nil and option(game, "hoenn_roamers", true) ~= false
      and fieldAccess.legendAccess(game) == true
  end

  local function owned(game, species)
    local owned = game and game.save and game.save.pokedex
      and game.save.pokedex.owned
    return owned and owned[species] == true or false
  end

  function R.observations(game,mapId)
    local out={}
    if not game or option(game,'hoenn_roamers',true)==false
        or not fieldAccess.peekLegendAccess or not fieldAccess.peekLegendAccess(game)then return out end
    local s=mod.save:get(R.SAVE_KEY)
    if type(s)~='table' or tonumber(s.version) and tonumber(s.version)>R.STATE_VERSION then return out end
    for _,species in ipairs(R.order)do
      local row=type(s.roamers)=='table' and s.roamers[species]
      if type(row)=='table' and row.map==mapId and (tonumber(row.recovery) or 0)<=0
          and not (s.caught and s.caught[species]) and not owned(game,species)then
        out[#out+1]={species=species,mapId=mapId,kind='roamer',source='hoenn_roamer'}
      end
    end
    return out
  end

  local function routePool(game)
    local out = {}
    for _, mapId in ipairs(R.routes) do
      local encounter = game and game.data and game.data.encounters
        and game.data.encounters[mapId]
      if encounter and encounter.grass then out[#out + 1] = mapId end
    end
    return out
  end

  local function chooseMap(game, avoid, occupied)
    local pool, candidates = routePool(game), {}
    for _, mapId in ipairs(pool) do
      if mapId ~= avoid and not (occupied and occupied[mapId]) then
        candidates[#candidates + 1] = mapId
      end
    end
    if #candidates == 0 then
      for _, mapId in ipairs(pool) do
        if mapId ~= avoid then candidates[#candidates + 1] = mapId end
      end
    end
    if #candidates == 0 then candidates = pool end
    if #candidates == 0 then return nil end
    return candidates[randomInt(1, #candidates)]
  end

  local function occupiedRoutes(s, except)
    local out = {}
    for species, row in pairs(s.roamers) do
      if species ~= except and type(row) == "table" and row.map then
        out[row.map] = true
      end
    end
    return out
  end

  function R.initialize(game)
    game = game or activeGame
    if not R.available(game) then return false, "unavailable" end
    local s, changed = state(true), false
    for _, species in ipairs(R.order) do
      if owned(game, species) then
        if not s.caught[species] then
          s.caught[species] = { adopted=true }
          changed = true
        end
        if s.roamers[species] then s.roamers[species], changed = nil, true end
      elseif not s.caught[species] and not s.roamers[species] then
        local map = chooseMap(game, nil, occupiedRoutes(s, species))
        if map then
          s.roamers[species] = {
            map=map, dvs=nil, hp=nil, status=nil, recovery=0, lastVisit=nil,
          }
          changed = true
        end
      end
    end
    if changed then persist(s) end
    return true, changed and "initialized" or "ready"
  end

  function R.relocate(species, game, avoid)
    game = game or activeGame
    local s = state(false)
    local row = s and s.roamers[species]
    if not row then return nil, "missing" end
    row.map = chooseMap(game, avoid or row.map, occupiedRoutes(s, species))
      or row.map
    persist(s)
    return row.map
  end

  local function stored(save, mon)
    for _, partyMon in ipairs(save and save.party or {}) do
      if partyMon == mon then return true end
    end
    for _, box in ipairs(save and save.boxes or {}) do
      for _, boxMon in ipairs(box) do if boxMon == mon then return true end end
    end
    return false
  end

  local function markCaught(game, species, mon, mapId)
    if not (game and game.save and stored(game.save, mon)) then
      return false, "not-stored"
    end
    local s = state(true)
    if not s.caught[species] then
      s.caught[species] = { map=mapId, level=tonumber(mon and mon.level) or R.LEVEL }
    end
    s.roamers[species] = nil
    persist(s)
    return true, s.caught[species]
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
      pending = nil
      local native = nextRoll(encDef, ctx)
      if not (native and ctx and ctx.terrain == "grass" and R.available(activeGame)) then
        return native
      end
      R.initialize(activeGame)
      local s = state(false)
      for _, species in ipairs(R.order) do
        local row = s and s.roamers[species]
        if row and row.recovery <= 0 and row.map == ctx.mapId
            and ctx.rng(1, R.ENCOUNTER_DENOMINATOR) == 1 then
          pending = { species=species, map=ctx.mapId, level=R.LEVEL }
          return { species=species, level=R.LEVEL, kaProtected=true,
            kaEncounterSource="hoenn_roamer" }
        end
      end
      return native
    end, R.ENCOUNTER_PRIORITY)

    mod.hooks:wrap("battle.enemy_action", function(nextAction, battle)
      if battle and battle.kaHoennRoamer
          and option(battle.game or activeGame, "hoenn_roamer_flee", true) ~= false
          and not battle.kaHoennRoamerFled then
        battle.kaHoennRoamerFled = true
        return { special="ascendantHoennRoamerFlee" }
      end
      return nextAction(battle)
    end, R.ENCOUNTER_PRIORITY)
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("battle.started", function(ev)
      local battle = ev and ev.battle
      local proposal = pending
      pending = nil
      if not (proposal and battle and battle.kind == "wild"
          and battle.enemy and battle.enemy.mon
          and battle.enemy.mon.species == proposal.species) then return end
      local s = state(false)
      local row = s and s.roamers[proposal.species]
      if not row or row.map ~= proposal.map or row.recovery > 0 then return end
      local mon = battle.enemy.mon
      if row.dvs then mon.dvs = copy(row.dvs) end
      if not row.dvs then
        row.dvs = copy(mon.dvs or {})
        persist(s)
      end
      local maximum = mon.stats and tonumber(mon.stats.hp) or tonumber(mon.hp) or 1
      mon.hp = row.hp and math.max(1, math.min(maximum, row.hp)) or maximum
      mon.status = copy(row.status)
      battle.enemy.shownHP = mon.hp
      battle.kaHoennRoamer = proposal.species
      battle.kaHoennRoamerMap = proposal.map
      mon.kaHoennRoamer = proposal.species
    end, R.EVENT_PRIORITY)

    mod.events:on("pokemon.caught", function(ev)
      local battle, mon = ev and ev.battle, ev and ev.mon
      local species = battle and battle.kaHoennRoamer
      if not (species and mon and mon.species == species) then return end
      local ok = markCaught(ev.game or battle.game, species, mon,
        battle.kaHoennRoamerMap)
      battle.kaHoennRoamerStored = ok == true
    end, R.EVENT_PRIORITY)

    mod.events:on("battle.ended", function(ev)
      local battle = ev and ev.battle
      local species = battle and battle.kaHoennRoamer
      if not species then return end
      local s = state(false)
      local row = s and s.roamers[species]
      if not row then return end
      local mon = battle.enemy and battle.enemy.mon
      if battle.kaHoennRoamerStored then
        s.roamers[species] = nil
      elseif mon then
        if (tonumber(mon.hp) or 0) <= 0 or ev.result == "win" then
          row.hp, row.status = nil, nil
          row.recovery = R.KO_RECOVERY_MAPS
          row.lastVisit = battle.kaHoennRoamerMap
        else
          row.hp, row.status = math.max(1, math.floor(mon.hp)), copy(mon.status)
          row.recovery, row.lastVisit = 0, nil
        end
        row.map = chooseMap(activeGame, row.map, occupiedRoutes(s, species))
          or row.map
      end
      persist(s)
    end, R.EVENT_PRIORITY)

    mod.events:on("map.entered", function(ev)
      if not activeGame or not R.available(activeGame) then return end
      R.initialize(activeGame)
      local mapId = ev and ev.mapId
      local s, changed = state(false), false
      for species, row in pairs(s and s.roamers or {}) do
        if row.recovery > 0 and mapId and row.lastVisit ~= mapId then
          row.recovery = row.recovery - 1
          row.lastVisit, changed = mapId, true
          if row.recovery <= 0 then row.hp, row.status = nil, nil end
        elseif row.recovery <= 0 and randomInt(1, 4) == 1 then
          row.map = chooseMap(activeGame, mapId,
            occupiedRoutes(s, species)) or row.map
          changed = true
        end
      end
      if changed then persist(s) end
    end, R.EVENT_PRIORITY)

    mod.events:on("world.stepped", function() pending = nil end,
      R.EVENT_PRIORITY)
    for _, event in ipairs({ "save.loaded", "save.created", "game.ready" }) do
      mod.events:on(event, function(ev)
        pending = nil
        activeGame = ev and ev.game or activeGame
        if activeGame then R.initialize(activeGame) end
      end, R.EVENT_PRIORITY)
    end
  end

  function R.install(game, deps)
    activeGame = game or activeGame
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    if not BattleState._kantoHoennRoamerFleeWrapped then
      BattleState._kantoHoennRoamerFleeWrapped = true
      local original = BattleState.executeAction
      BattleState.executeAction = function(self, user, target, action)
        if action and action.special == "ascendantHoennRoamerFlee" then
          if self.result then return end
          local name = self.enemy and self.enemy.name or "EON POKéMON"
          self:sayNext(tr(("%s vanished into\nthe wild!"):format(name),
            ("%s flieht in\ndie Wildnis!"):format(name)))
          self.result, self.afterQueue = "run", "finish"
          return
        end
        return original(self, user, target, action)
      end
    end
    return R.initialize(activeGame)
  end

  R.state = state
  R.persist = persist
  R.markCaught = markCaught
  return R
end
