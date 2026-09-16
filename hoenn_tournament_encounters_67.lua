-- Rare World Rank prize encounters for already caught Hoenn lineages.
-- A tournament never deposits the Pokemon: it reserves one durable shiny
-- wild battle and consumes the prize only after that battle actually ends.

return function(mod, opts)
  opts = opts or {}
  local H = {
    SAVE_KEY = "hoenn_tournament_encounters_67",
    VERSION = 1,
    DENOMINATOR = 8,
    LEVEL = 50,
  }
  local activeGame, launching

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function hash(value)
    local n = 2166136261
    value = tostring(value or "")
    for index = 1, #value do
      n = (n * 16777619 + value:byte(index)) % 2147483647
    end
    return n
  end

  local function normalize(value)
    value = type(value) == "table" and copy(value) or {}
    value.version = H.VERSION
    value.pending = type(value.pending) == "table" and value.pending or {}
    value.awarded = type(value.awarded) == "table" and value.awarded or {}
    value.completed = type(value.completed) == "table" and value.completed or {}
    local pending = {}
    for id, row in pairs(value.pending) do
      local species = type(row) == "table" and row.species
      if type(id) == "string" and id ~= "" and type(species) == "string"
          and species ~= "" and value.completed[id] ~= true then
        pending[id] = { id=id, species=species:upper(), level=H.LEVEL,
          status="pending" }
      end
    end
    value.pending = pending
    return value
  end

  local function state()
    local value = normalize(mod.save:get(H.SAVE_KEY))
    mod.save:set(H.SAVE_KEY, value)
    return value
  end

  local function writeSave(game)
    if not (game and type(game.writeSave) == "function") then return false end
    local ok, value = pcall(game.writeSave, game)
    return ok and value ~= false
  end

  local function caughtFamilies(game)
    local out = {}
    local core = opts.discoveryCore
    local stateAuthority = core and core.state
    local rows = {}
    for _, row in ipairs(opts.acquisition and opts.acquisition.traceFamilies or {}) do
      rows[#rows + 1] = row
    end
    for _, row in ipairs(opts.acquisition and opts.acquisition.starterFamilies or {}) do
      rows[#rows + 1] = row
    end
    for _, row in ipairs(rows) do
      local family = row.id
      local caught = stateAuthority and type(stateAuthority.status) == "function"
        and stateAuthority.status("hoenn", family) == "unlocked"
      if not caught and type(opts.legacyProfile) == "function" then
        local ok, profile = pcall(opts.legacyProfile)
        local receipt = ok and type(profile) == "table"
          and type(profile.hoennDiscoveryUnlocks) == "table"
          and profile.hoennDiscoveryUnlocks[family] or nil
        caught = type(receipt) == "table" and receipt.caught == true
          and receipt.unlocked == true
      end
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[family]
      local generationReady = type(opts.generationRules) ~= "table"
        or type(opts.generationRules.speciesAvailable) ~= "function"
        or opts.generationRules.speciesAvailable(game, family, def) == true
      if caught and type(def) == "table" and generationReady then
        out[#out + 1] = family
      end
    end
    table.sort(out)
    return out
  end

  function H.ordinaryRewardEligible(game, species, definition)
    local dex = tonumber(type(definition) == "table"
      and (definition.sourceDex or definition.nationalDex or definition.dex))
    -- Hoenn species are never deposited as ordinary tournament gifts. Their
    -- only tournament route is this controller's caught-lineage encounter.
    if dex and dex >= 252 and dex <= 386 then return false end
    return type(opts.generationRules) ~= "table"
      or type(opts.generationRules.speciesAvailable) ~= "function"
      or opts.generationRules.speciesAvailable(game, species, definition) == true
  end

  function H.onTournamentDelivered(game, receipt)
    if type(receipt) ~= "table" or type(receipt.id) ~= "string"
        or receipt.id == "" then return false, "invalid-receipt" end
    local value = state()
    if value.awarded[receipt.id] ~= nil or value.completed[receipt.id] == true
        or value.pending[receipt.id] ~= nil then return true, "already" end
    value.awarded[receipt.id] = false
    if hash(receipt.id .. ":hoenn-shiny-encounter") % H.DENOMINATOR ~= 0 then
      mod.save:set(H.SAVE_KEY, value)
      return true, "no-roll"
    end
    local choices, used = caughtFamilies(game), {}
    for _, species in pairs(value.awarded) do
      if type(species) == "string" then used[species] = true end
    end
    local pool = {}
    for _, species in ipairs(choices) do
      if not used[species] then pool[#pool + 1] = species end
    end
    if #pool == 0 then
      mod.save:set(H.SAVE_KEY, value)
      return true, "no-caught-family"
    end
    local species = pool[hash(receipt.id .. ":hoenn-family") % #pool + 1]
    value.awarded[receipt.id] = species
    value.pending[receipt.id] = {
      id=receipt.id, species=species, level=H.LEVEL, status="pending",
    }
    mod.save:set(H.SAVE_KEY, value)
    return true, species
  end

  local function forceShiny(game, battle, species)
    local mon = battle and battle.enemy and battle.enemy.mon
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    return type(mon) == "table" and type(opts.forceShiny) == "function"
      and opts.forceShiny(mon, def) == true
  end

  function H.pump(game)
    game = game or activeGame
    if launching or not (game and game.overworld
        and type(game.overworld.pushBattle) == "function") then return false end
    if game.linkSession or type(game.linkNet) == "table"
        and game.linkNet.closed ~= true then return false end
    local value = state()
    local ids = {}; for id in pairs(value.pending) do ids[#ids + 1] = id end
    table.sort(ids)
    local id, row = ids[1], ids[1] and value.pending[ids[1]] or nil
    if not row then return false end
    local def = game.data and game.data.pokemon and game.data.pokemon[row.species]
    if type(def) ~= "table" then return false end
    local BattleState = opts.battleState or require("src.battle.BattleState")
    local battle = BattleState.newWild(game, row.species, H.LEVEL, {
      encounterSource="world_rank_hoenn",
      randomizerProtected=true,
    })
    if not forceShiny(game, battle, row.species) then return false end
    battle.ascendantWorldRankHoennEncounter = true
    battle.worldRankHoennReceipt = id
    launching = battle
    row.status = "active"
    mod.save:set(H.SAVE_KEY, value)
    if not writeSave(game) then
      launching = nil; row.status = "pending"; mod.save:set(H.SAVE_KEY, value)
      return false
    end
    local prior = battle.onFinish
    battle.onFinish = function(result)
      if type(prior) == "function" then pcall(prior, result) end
      local current = state()
      current.pending[id] = nil
      current.completed[id] = true
      mod.save:set(H.SAVE_KEY, current)
      writeSave(game)
      launching = nil
      if game.overworld and type(game.overworld.afterBattle) == "function" then
        pcall(game.overworld.afterBattle, game.overworld, result, battle)
      end
    end
    local ok, accepted = pcall(game.overworld.pushBattle, game.overworld, battle)
    if not ok or accepted == false then
      launching = nil; row.status = "pending"; mod.save:set(H.SAVE_KEY, value)
      return false
    end
    return true
  end

  function H.status()
    local value = state()
    return copy(value)
  end

  function H.install(game)
    activeGame = game or activeGame
    if H.installed then return true end
    H.installed = true
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("world.stepped", function(ev)
        H.pump(ev and ev.game or activeGame)
      end, -75)
      mod.events:on("save.loaded", function(ev)
        activeGame, launching = ev and ev.game or activeGame, nil
        state()
      end, 4000)
      mod.events:on("save.created", function(ev)
        activeGame, launching = ev and ev.game or activeGame, nil
        state()
      end, 4000)
    end
    return true
  end

  H.hash = hash
  H.caughtFamilies = caughtFamilies
  return H
end
