-- Exact-once NG+ World Rank champion reward delivery.
--
-- The tournament controller owns durable completion descriptors. The Legacy
-- Archive owns cross-run reservation/claim history. This module is the only
-- place that turns those two authorities into live cash, Balls, titles/cards
-- and a physical shiny Pokemon. Every physical transaction is journaled in
-- the game save before the archive claim is closed.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "World Rank reward data is required")
  local tournament = assert(opts.tournament,
    "World Rank tournament authority is required")
  local archive = assert(opts.archive, "Legacy Archive authority is required")

  local R = {
    version = 1,
    saveKey = "ngplus_world_rank_rewards",
    readOnly = false,
  }

  local RECEIPT_FIELDS = {
    "version", "id", "owner", "formatId", "completionToken", "season",
    "cash", "ball", "ballCount", "species", "goldJackpot", "titleId",
    "cardId", "rank", "equipmentItem", "equipmentQty", "equipmentEpoch",
  }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do
      out[copy(key, seen)] = copy(child, seen)
    end
    return out
  end

  -- Engine services retain aliases into SaveData (most importantly
  -- Loader.modSave == game.save.modData). A rollback must therefore restore
  -- existing table roots in place instead of replacing nested tables with
  -- deep copies and silently detaching those services from the live save.
  local function restore(target, snapshot, seen)
    seen = seen or {}
    if seen[snapshot] then return end
    seen[snapshot] = target
    for key in pairs(target) do
      if snapshot[key] == nil then target[key] = nil end
    end
    for key, value in pairs(snapshot) do
      if type(value) == "table" and type(target[key]) == "table" then
        restore(target[key], value, seen)
      else
        target[key] = copy(value)
      end
    end
  end

  local function integer(value, minimum, maximum)
    if type(value) ~= "number" or value ~= math.floor(value) then return nil end
    if minimum and value < minimum then return nil end
    if maximum and value > maximum then return nil end
    return value
  end

  local function nonempty(value, maximum)
    return type(value) == "string" and value ~= ""
      and #value <= (maximum or 512)
  end

  local function hash(value)
    local h = 2166136261
    value = tostring(value or "")
    for index = 1, #value do
      h = (h * 16777619 + value:byte(index)) % 2147483647
    end
    return h
  end

  local function sameReceipt(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for _, field in ipairs(RECEIPT_FIELDS) do
      if left[field] ~= right[field] then return false end
    end
    for key in pairs(left) do
      local known = false
      for _, field in ipairs(RECEIPT_FIELDS) do
        if key == field then known = true break end
      end
      if not known then return false end
    end
    for key in pairs(right) do
      local known = false
      for _, field in ipairs(RECEIPT_FIELDS) do
        if key == field then known = true break end
      end
      if not known then return false end
    end
    return true
  end

  local function canonicalReceipt(value)
    if type(value) ~= "table" or value.version ~= R.version
        or not nonempty(value.id, 512) or not nonempty(value.owner, 512)
        or not nonempty(value.formatId, 80)
        or not nonempty(value.completionToken, 512)
        or not integer(value.season, 1)
        or not integer(value.cash, 0, 999999)
        or not nonempty(value.ball, 80)
        or not integer(value.ballCount, 1, 999)
        or value.goldJackpot ~= true and value.goldJackpot ~= false
        or not integer(value.rank, 1, 50) then return nil end
    if value.species ~= nil and not nonempty(value.species, 80) then return nil end
    if value.formatId == "gold" then
      if (value.species ~= nil) ~= (value.goldJackpot == true) then return nil end
    elseif value.species == nil or value.goldJackpot == true then
      return nil
    end
    if value.titleId ~= nil and not nonempty(value.titleId, 80) then return nil end
    if value.cardId ~= nil and not nonempty(value.cardId, 80) then return nil end
    if value.equipmentItem~=nil or value.equipmentQty~=nil or value.equipmentEpoch~=nil then
      if not (opts.equipmentRewards and opts.equipmentRewards.validReceiptItem(
          value.equipmentItem,value.equipmentQty,value.equipmentEpoch)) then return nil end
    end
    local out = {}
    for _, field in ipairs(RECEIPT_FIELDS) do out[field] = value[field] end
    return out
  end

  local function normalizeEntry(value)
    if type(value) ~= "table" then return nil end
    if value.receipt ~= nil then
      local receipt = canonicalReceipt(value.receipt)
      if not receipt then return nil end
      return {
        receipt = receipt,
        destination = value.destination == "party" and "party"
          or value.destination == "box" and "box" or nil,
        box = integer(value.box, 1),
      }
    end
    local receipt = canonicalReceipt(value)
    return receipt and { receipt = receipt } or nil
  end

  local function freshLedger()
    return {
      version = R.version,
      pending = {}, applied = {}, claimed = {},
    }
  end

  local function normalizeLedger(value)
    if value == nil then return freshLedger() end
    if type(value) ~= "table" or value.version ~= R.version then
      return nil, "unsupported World Rank reward journal"
    end
    local out = freshLedger()
    for _, bucket in ipairs({ "pending", "applied", "claimed" }) do
      if type(value[bucket]) ~= "table" then
        return nil, "corrupt World Rank reward journal"
      end
      for id, raw in pairs(value[bucket]) do
        local entry = normalizeEntry(raw)
        if not nonempty(id, 512) or not entry or entry.receipt.id ~= id then
          return nil, "corrupt World Rank reward journal"
        end
        out[bucket][id] = entry
      end
    end
    if type(value.last) == "table" then out.last = copy(value.last) end
    return out
  end

  local function ledger()
    local value, err = normalizeLedger(mod.save:get(R.saveKey))
    if not value then
      R.readOnly = true
      return nil, err
    end
    mod.save:set(R.saveKey, value)
    return value
  end

  local function persist(value)
    if R.readOnly then return false end
    mod.save:set(R.saveKey, value)
    return true
  end

  local function writeSave(game)
    if not (game and type(game.writeSave) == "function") then return false end
    local ok, result = pcall(game.writeSave, game)
    return ok and result ~= false
  end

  local function pendingDescriptors(game)
    if type(tournament.pendingRewards) ~= "function" then
      return nil, "missing tournament reward queue authority"
    end
    local ok, rows = pcall(tournament.pendingRewards, game)
    if not ok or type(rows) ~= "table" then
      return nil, "tournament reward queue is unavailable"
    end
    return rows
  end

  local function tournamentOwner(game)
    if type(tournament.state) ~= "function" then return nil end
    local ok, state = pcall(tournament.state, game)
    return ok and type(state) == "table" and state.owner or nil
  end

  local function formatRow(id)
    return type(data.byId) == "table" and data.byId[id] or nil
  end

  local function canonicalDescriptor(game, raw)
    if type(raw) ~= "table" or raw.version ~= 1
        or not nonempty(raw.id, 512) or not nonempty(raw.owner, 512)
        or not nonempty(raw.formatId, 80)
        or not nonempty(raw.completionToken, 512)
        or type(raw.shinyDue) ~= "boolean"
        or type(raw.goldJackpotCandidate) ~= "boolean" then
      return nil, "invalid champion reward descriptor"
    end
    local row = formatRow(raw.formatId)
    if not row or tournamentOwner(game) ~= raw.owner then
      return nil, "champion reward owner/format mismatch"
    end
    local rewards = data.rewards or {}
    local expectedCash = raw.formatId == "gold"
      and rewards.goldChampionCash or rewards.championCash
    if raw.cash ~= expectedCash or raw.ball ~= rewards.championBallItem
        or raw.ballCount ~= rewards.championBallCount then
      return nil, "champion reward package mismatch"
    end
    if raw.formatId ~= "gold" and (raw.shinyDue ~= true
        or raw.goldJackpotCandidate ~= false) then
      return nil, "regular championship must carry one shiny"
    end
    if raw.formatId == "gold"
        and raw.shinyDue ~= raw.goldJackpotCandidate then
      return nil, "GOLD jackpot descriptor mismatch"
    end
    local expectedTitle = row.championTitle and row.championTitle.id
    if raw.titleId ~= nil and raw.titleId ~= expectedTitle then
      return nil, "champion title mismatch"
    end
    if raw.cardId ~= nil and raw.cardId ~= row.championCardId then
      return nil, "champion card mismatch"
    end
    return {
      version = 1, id = raw.id, owner = raw.owner,
      formatId = raw.formatId, completionToken = raw.completionToken,
      cash = raw.cash, ball = raw.ball, ballCount = raw.ballCount,
      shinyDue = raw.shinyDue,
      goldJackpotCandidate = raw.goldJackpotCandidate,
      titleId = raw.titleId, cardId = raw.cardId,
    }
  end

  local function definitionTypes(definition)
    local out = {}
    if type(definition) ~= "table" then return out end
    local function add(value)
      if type(value) ~= "string" then return end
      -- Generated R/B/Y data names the Psychic constant PSYCHIC_TYPE while
      -- authored tournament contracts use the canonical battle type PSYCHIC.
      -- Normalize the engine constant suffix at this one registry boundary.
      out[value:upper():gsub("_TYPE$", "")] = true
    end
    for _, value in ipairs(type(definition.types) == "table"
        and definition.types or {}) do
      add(value)
    end
    for _, key in ipairs({ "type", "type1", "type2" }) do
      add(definition[key])
    end
    return out
  end

  local starterFamilyBySpecies = {}
  local starterFamilies = {}
  for index, family in ipairs(type(data.starterFamilies) == "table"
      and data.starterFamilies or {}) do
    local clean = {}
    for _, species in ipairs(type(family) == "table" and family or {}) do
      if nonempty(species, 80) then
        species = species:upper()
        clean[#clean + 1] = species
        starterFamilyBySpecies[species] = index
      end
    end
    starterFamilies[index] = clean
  end

  local function discovered(game, species)
    if type(opts.discoveryAuthority) ~= "function" then return false end
    local ok, result = pcall(opts.discoveryAuthority, game, species)
    return ok and result == true
  end

  local function familyDiscovered(game, familyIndex)
    local family = starterFamilies[familyIndex] or {}
    for _, species in ipairs(family) do
      if discovered(game, species) then return true end
    end
    return false
  end

  local function speciesSource(game)
    if type(opts.speciesCatalog) == "function" then
      local ok, value = pcall(opts.speciesCatalog, game)
      if ok and type(value) == "table" then return value end
      return nil
    end
    local gameData = game and game.data
    return type(gameData) == "table"
      and (type(gameData.pokemon) == "table" and gameData.pokemon
        or type(gameData.species) == "table" and gameData.species) or nil
  end

  -- HEVO and other extended providers can map a later species onto a Gen-I
  -- runtime slot.  sourceDex/nationalDex remains the authoritative generation
  -- boundary and therefore precedes dex here, matching the roster builder.
  local function canonicalDex(definition)
    for _, key in ipairs({ "nationalDex", "sourceDex", "dexNumber", "dex" }) do
      local value = tonumber(type(definition) == "table" and definition[key])
      if value and value == math.floor(value) and value > 0 then return value end
    end
  end

  local function generationAllowed(definition)
    if type(definition) ~= "table" then return false end
    if definition.originGeneration ~= nil then
      local generation = tonumber(definition.originGeneration)
      if not generation or generation ~= math.floor(generation)
          or generation < 1 or generation > 3 then return false end
    end
    if definition.regionalForm ~= nil and definition.regionalForm ~= false
        and tostring(definition.regionalForm) ~= "" then return false end
    return true
  end

  local function catalog(game)
    local source = speciesSource(game)
    if type(source) ~= "table" then return nil, "missing species registry" end
    local dexBuckets = {}
    for species, definition in pairs(source) do
      local dex = canonicalDex(definition)
      if generationAllowed(definition) and nonempty(species, 80)
          and dex and dex == math.floor(dex)
          and dex >= 1 and dex <= 386 then
        local types = definitionTypes(definition)
        if next(types) then
          local ready = true
          if type(opts.speciesReady) == "function" then
            local ok, result = pcall(opts.speciesReady, game, species, definition)
            ready = ok and result == true
          end
          if ready then
            dexBuckets[dex] = dexBuckets[dex] or {}
            dexBuckets[dex][#dexBuckets[dex] + 1] = {
              species = species, dex = dex, types = types,
              family = starterFamilyBySpecies[species:upper()],
            }
          end
        end
      end
    end
    local rows = {}
    for _, bucket in pairs(dexBuckets) do
      -- Conflicting duplicate Dex definitions are not guessed.
      if #bucket == 1 then rows[#rows + 1] = bucket[1] end
    end
    table.sort(rows, function(left, right)
      if left.dex ~= right.dex then return left.dex < right.dex end
      return left.species < right.species
    end)
    if #rows == 0 then return nil, "no registered Gen I-III reward species" end
    return rows
  end

  local function usedSpecies(state)
    local used = {}
    for species, value in pairs(type(state.delivered) == "table"
        and state.delivered or {}) do
      if value == true then used[species] = true end
    end
    for _, receipt in pairs(type(state.pending) == "table"
        and state.pending or {}) do
      if type(receipt) == "table" and nonempty(receipt.species, 80) then
        used[receipt.species] = true
      end
    end
    return used
  end

  local function matchesTheme(row, descriptor)
    if descriptor.formatId == "gold" then return true end
    local format = formatRow(descriptor.formatId)
    for _, typeId in ipairs(format and format.rewardTypes or {}) do
      if row.types[tostring(typeId):upper()] then return true end
    end
    return false
  end

  local function jackpotAlreadyReserved(state, id)
    if state.goldJackpotClaimed == true then return true end
    for pendingId, receipt in pairs(type(state.pending) == "table"
        and state.pending or {}) do
      if pendingId ~= id and type(receipt) == "table"
          and receipt.goldJackpot == true then return true end
    end
    return false
  end

  local function selectSpecies(game, descriptor, state)
    if not descriptor.shinyDue then return nil, "no_shiny" end
    if descriptor.formatId == "gold"
        and jackpotAlreadyReserved(state, descriptor.id) then
      return nil, "lifetime_sealed"
    end
    local rows, catalogErr = catalog(game)
    if not rows then return nil, "config_error", catalogErr end
    local used, choices = usedSpecies(state), {}
    local relevantUndiscoveredStarter = false
    for _, row in ipairs(rows) do
      if not used[row.species] and matchesTheme(row, descriptor) then
        local eligible = not row.family or familyDiscovered(game, row.family)
        if eligible then
          local weight = 1
          if descriptor.formatId == "gold" and row.family
              and row.dex >= 152 and row.dex <= 160 then weight = 4 end
          choices[#choices + 1] = { row = row, weight = weight }
        else
          relevantUndiscoveredStarter = true
        end
      end
    end
    if #choices == 0 then
      local complete = true
      for _, row in ipairs(rows) do
        if not (type(state.delivered) == "table"
            and state.delivered[row.species] == true) then
          complete = false
          break
        end
      end
      if complete then return nil, "season_complete" end
      if relevantUndiscoveredStarter then return nil, "discovery_wait" end
      return nil, "pool_wait"
    end
    local total = 0
    for _, choice in ipairs(choices) do total = total + choice.weight end
    local seed = table.concat({ descriptor.owner, descriptor.formatId,
      descriptor.completionToken, tostring(state.season) }, "|")
    local roll = hash(seed) % total + 1
    for _, choice in ipairs(choices) do
      roll = roll - choice.weight
      if roll <= 0 then return choice.row.species end
    end
    return choices[#choices].row.species
  end

  local function historyFor(state, formatId)
    local formats = type(state.formats) == "table" and state.formats or {}
    return type(formats[formatId]) == "table" and formats[formatId] or {}
  end

  local function pendingPresentation(state, descriptor, field)
    for id, receipt in pairs(type(state.pending) == "table"
        and state.pending or {}) do
      if id ~= descriptor.id and type(receipt) == "table"
          and receipt.formatId == descriptor.formatId
          and receipt[field] ~= nil then return true end
    end
    return false
  end

  local function buildReceipt(game, descriptor, state)
    local species, reason, detail = selectSpecies(game, descriptor, state)
    if reason == "config_error" then return nil, reason, detail end
    if reason == "discovery_wait" or reason == "pool_wait"
        or reason == "season_complete" then
      return nil, reason
    end
    local history = historyFor(state, descriptor.formatId)
    local format = formatRow(descriptor.formatId) or {}
    -- Descriptor presentation fields are a useful frozen controller witness,
    -- but old same-owner `titleGranted/cardGranted` booleans are not durable
    -- authority. The Archive's claimed/pending history decides whether the
    -- fixed authored presentation is still owed.
    local titleId = type(format.championTitle) == "table"
      and format.championTitle.id or descriptor.titleId
    if history.titleClaimed == true
        or pendingPresentation(state, descriptor, "titleId") then titleId = nil end
    local cardId = format.championCardId or descriptor.cardId
    if history.cardClaimed == true
        or pendingPresentation(state, descriptor, "cardId") then cardId = nil end
    local equipment, equipmentEpoch
    if opts.equipmentRewards and opts.generationRules then
      local resolved=opts.generationRules.resolve(game)
      equipmentEpoch=resolved and resolved.activeEpoch or 1
      equipment=opts.equipmentRewards.pick(game.data,{activeEpoch=equipmentEpoch},
        'tournament:'..descriptor.owner..':'..descriptor.completionToken..':'..descriptor.formatId)
    end
    return canonicalReceipt({
      version = R.version,
      id = descriptor.id,
      owner = descriptor.owner,
      formatId = descriptor.formatId,
      completionToken = descriptor.completionToken,
      season = state.season,
      cash = descriptor.cash,
      ball = descriptor.ball,
      ballCount = descriptor.ballCount,
      species = species,
      goldJackpot = descriptor.formatId == "gold" and species ~= nil,
      titleId = titleId,
      cardId = cardId,
      rank = 1,
      equipmentItem=equipment and equipment.item or nil,
      equipmentQty=equipment and equipment.qty or nil,
      equipmentEpoch=equipment and equipmentEpoch or nil,
    })
  end

  local function receiptMatchesDescriptor(receipt, descriptor)
    return type(receipt) == "table"
      and receipt.id == descriptor.id
      and receipt.owner == descriptor.owner
      and receipt.formatId == descriptor.formatId
      and receipt.completionToken == descriptor.completionToken
      and receipt.cash == descriptor.cash
      and receipt.ball == descriptor.ball
      and receipt.ballCount == descriptor.ballCount
  end

  local function pendingReceiptMatchesDescriptor(receipt, descriptor, state)
    if not receiptMatchesDescriptor(receipt, descriptor) then return false end
    if descriptor.formatId ~= "gold" then return true end
    local jackpotOwed = descriptor.goldJackpotCandidate == true
      and not jackpotAlreadyReserved(state, descriptor.id)
    return receipt.goldJackpot == jackpotOwed
      and (receipt.species ~= nil) == jackpotOwed
  end

  local function archiveState()
    if type(archive.worldRankState) ~= "function" then
      return nil, "missing Legacy reward state authority"
    end
    if archive.readOnly == true then
      return nil, archive.readOnlyReason or "Legacy archive is read-only"
    end
    local ok, state, err = pcall(archive.worldRankState)
    if not ok or type(state) ~= "table" then
      return nil, err or state or "Legacy reward state unavailable"
    end
    state.pending = type(state.pending) == "table" and state.pending or {}
    state.claimed = type(state.claimed) == "table" and state.claimed or {}
    state.delivered = type(state.delivered) == "table" and state.delivered or {}
    state.formats = type(state.formats) == "table" and state.formats or {}
    state.season = integer(state.season, 1) or 1
    return state
  end

  local function markerFor(receipt)
    return {
      version = 1,
      kind = "world_rank_reward",
      rewardId = receipt.id,
      owner = receipt.owner,
      formatId = receipt.formatId,
      season = receipt.season,
      species = receipt.species,
    }
  end

  local function markerMatches(marker, receipt)
    return type(marker) == "table" and marker.version == 1
      and marker.kind == "world_rank_reward"
      and marker.rewardId == receipt.id
      and marker.owner == receipt.owner
      and marker.formatId == receipt.formatId
      and marker.season == receipt.season
      and marker.species == receipt.species
  end

  local function scanReceipt(game, receipt)
    if not receipt.species then return nil end
    local foreign
    local function inspect(mon, destination, box)
      local marker = type(mon) == "table" and type(mon.extra) == "table"
        and mon.extra.kanto_ascendant or nil
      if type(marker) == "table" and marker.rewardId == receipt.id then
        if markerMatches(marker, receipt) then
          return mon, destination, box
        end
        foreign = true
      end
    end
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      local found, destination, box = inspect(mon, "party")
      if found then return found, destination, box end
    end
    for boxIndex, boxRows in ipairs(game and game.save and game.save.boxes or {}) do
      for _, mon in ipairs(boxRows) do
        local found, destination, box = inspect(mon, "box", boxIndex)
        if found then return found, destination, box end
      end
    end
    return nil, foreign and "foreign" or nil
  end

  local function createPokemon(game, species)
    if type(opts.createPokemon) == "function" then
      return opts.createPokemon(game, species)
    end
    local Pokemon = require("src.pokemon.Pokemon")
    return Pokemon.new(game.data, species, 50)
  end

  local function forceShiny(game, mon, species)
    local definition = speciesSource(game)
    definition = type(definition) == "table" and definition[species] or nil
    if type(opts.forceShiny) == "function" then
      return opts.forceShiny(mon, definition) == true
    end
    return false
  end

  local function isShiny(mon)
    if type(opts.isShiny) == "function" then
      return opts.isShiny(mon) == true
    end
    if type(mon) ~= "table" then return false end
    if mon.shiny == true then return true end
    local dvs = mon.dvs
    if type(dvs) ~= "table" then return false end
    local attack = { [2] = true, [3] = true, [6] = true, [7] = true,
      [10] = true, [11] = true, [14] = true, [15] = true }
    return dvs.defense == 10 and dvs.speed == 10 and dvs.special == 10
      and attack[dvs.attack] == true
  end

  local function stampOT(game, mon)
    if type(opts.stampOT) == "function" then
      -- The engine's native stamper is a void function; explicit `false` is
      -- the injected failure signal, while nil is a successful void return.
      return opts.stampOT(game, mon) ~= false
    end
    local ok, BattleState = pcall(require, "src.battle.BattleState")
    if ok and BattleState and type(BattleState.stampOT) == "function" then
      return BattleState.stampOT(game.save, mon) ~= false
    end
    return false
  end

  local function giveItem(game, item, count)
    if type(opts.giveItem) == "function" then
      return opts.giveItem(game, item, count) == true
    end
    return require("src.inventory.Bag").add(game.save, item, count, game.data)
      == true
  end

  local function storePokemon(game, mon)
    if type(opts.storePokemon) == "function" then
      return opts.storePokemon(game, mon)
    end
    local Party = require("src.pokemon.Party")
    if Party.add(game.save.party, mon) then return "party" end
    local box = require("src.pokemon.Boxes").deposit(game.save, mon)
    if box then return "box", box end
    return nil, "full"
  end

  local function markOwned(game, species)
    local pokedex = game.save.pokedex
    if type(pokedex) ~= "table" then return end
    pokedex.seen = type(pokedex.seen) == "table" and pokedex.seen or {}
    pokedex.owned = type(pokedex.owned) == "table" and pokedex.owned or {}
    pokedex.seen[species], pokedex.owned[species] = true, true
  end

  local function reserveLocal(game, journal, receipt)
    local existing = journal.pending[receipt.id]
    if existing and not sameReceipt(existing.receipt, receipt) then
      return false, "local receipt mismatch"
    end
    if existing then return true end
    local before = copy(journal)
    journal.pending[receipt.id] = { receipt = copy(receipt) }
    journal.last = {
      id = receipt.id, formatId = receipt.formatId,
      species = receipt.species, status = "reserved",
    }
    persist(journal)
    if writeSave(game) then return true end
    restore(journal, before)
    persist(journal)
    return false, "save_failed"
  end

  local function applyPhysical(game, journal, receipt)
    local saveBefore, journalBefore = copy(game.save), copy(journal)
    game.save.money = math.min(999999,
      math.max(0, tonumber(game.save.money) or 0) + receipt.cash)
    local itemOk, itemResult = pcall(giveItem, game, receipt.ball,
      receipt.ballCount)
    if not itemOk or itemResult ~= true then
      restore(game.save, saveBefore)
      return nil, "bag_full"
    end

    if receipt.equipmentItem then
      local extraOk,extraResult=pcall(giveItem,game,receipt.equipmentItem,receipt.equipmentQty)
      if not extraOk or extraResult~=true then
        restore(game.save,saveBefore)
        return nil,'bag_full'
      end
    end

    local destination, box
    if receipt.species then
      local made, mon = pcall(createPokemon, game, receipt.species)
      if not made or type(mon) ~= "table" then
        restore(game.save, saveBefore)
        return nil, "config_error"
      end
      local shinyOk, shiny = pcall(forceShiny, game, mon, receipt.species)
      local verified, shinyVerified = pcall(isShiny, mon)
      if not shinyOk or shiny ~= true or not verified or shinyVerified ~= true then
        restore(game.save, saveBefore)
        return nil, "config_error"
      end
      local stamped, stampResult = pcall(stampOT, game, mon)
      if not stamped or stampResult ~= true then
        restore(game.save, saveBefore)
        return nil, "config_error"
      end
      mon.extra = type(mon.extra) == "table" and mon.extra or {}
      mon.extra.kanto_ascendant = markerFor(receipt)
      local stored, first, second = pcall(storePokemon, game, mon)
      if not stored then
        restore(game.save, saveBefore)
        return nil, "config_error"
      end
      destination, box = first, second
      if destination ~= "party" and destination ~= "box" then
        restore(game.save, saveBefore)
        return nil, destination == nil and box == "full" and "full"
          or "config_error"
      end
      markOwned(game, receipt.species)
    end

    journal.pending[receipt.id] = nil
    journal.applied[receipt.id] = {
      receipt = copy(receipt), destination = destination, box = box,
    }
    journal.last = {
      id = receipt.id, formatId = receipt.formatId,
      species = receipt.species, status = "applied",
      destination = destination, box = box,
    }
    persist(journal)
    if not writeSave(game) then
      restore(game.save, saveBefore)
      restore(journal, journalBefore)
      persist(journal)
      return nil, "save_failed"
    end
    return journal.applied[receipt.id]
  end

  local function finalize(game, journal, receipt, entry)
    if type(opts.onDelivered) == "function" then
      local delivered, accepted, reason = pcall(opts.onDelivered, game, receipt)
      if not delivered or accepted ~= true then
        return false, reason or accepted or "delivery extension failed"
      end
    end
    if receipt.titleId then
      if type(opts.grantTitle) ~= "function" then
        return false, "missing title authority"
      end
      local ok, granted = pcall(opts.grantTitle, game, receipt.titleId)
      if not ok or granted ~= true then return false, "title authority failed" end
    end
    if type(tournament.markRewardClaimed) ~= "function" then
      return false, "missing tournament claim authority"
    end
    local ok, marked, markErr = pcall(tournament.markRewardClaimed,
      game, receipt.id, {
        committed = true,
        title = receipt.titleId ~= nil,
        card = receipt.cardId ~= nil,
      })
    if not ok or marked ~= true then
      return false, markErr or marked or "tournament claim failed"
    end
    journal.pending[receipt.id] = nil
    journal.applied[receipt.id] = nil
    journal.claimed[receipt.id] = entry or { receipt = copy(receipt) }
    journal.last = {
      id = receipt.id, formatId = receipt.formatId,
      species = receipt.species, status = "delivered",
      destination = entry and entry.destination,
      box = entry and entry.box,
    }
    persist(journal)
    if not writeSave(game) then
      R._needsFlush = true
      return false, "final save pending"
    end
    R._needsFlush = nil
    return true
  end

  local function isLinkActive(game)
    if type(opts.linkActive) == "function" then
      local ok, active = pcall(opts.linkActive, game)
      return not ok or active == true
    end
    -- These are the engine-owned LinkState/Tournament lifetime fields. They
    -- cover lobby, trade, battle and tournament sessions, not only a battle
    -- callback's transient `kind` value.
    return game and (game.linkSession ~= nil and game.linkSession ~= false
      or type(game.linkNet) == "table" and game.linkNet.closed ~= true) or false
  end

  local function outcome(status, extra)
    local result = { status = status }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
  end

  local function process(game, raw)
    local descriptor, descriptorErr = canonicalDescriptor(game, raw)
    if not descriptor then return outcome("config_error", { error = descriptorErr }) end
    if type(archive.validateWorldRankOwner) ~= "function" then
      return outcome("archive_error", { error = "missing owner authority" })
    end
    local ownerOk, ownerValid, ownerState = pcall(
      archive.validateWorldRankOwner, game.save, descriptor.owner)
    if not ownerOk or ownerValid ~= true then
      return outcome("archive_error", { error = ownerState or ownerValid })
    end
    local journal, journalErr = ledger()
    if not journal then return outcome("state_error", { error = journalErr }) end
    local state, stateErr = archiveState()
    if not state then return outcome("archive_error", { error = stateErr }) end

    local claimed = state.claimed[descriptor.id]
    if claimed ~= nil then
      local receipt = type(claimed) == "table" and canonicalReceipt(claimed)
        or journal.applied[descriptor.id]
          and journal.applied[descriptor.id].receipt
        or journal.claimed[descriptor.id]
          and journal.claimed[descriptor.id].receipt
      if not receipt then
        local history = historyFor(state, descriptor.formatId)
        receipt = canonicalReceipt({
          version = 1, id = descriptor.id, owner = descriptor.owner,
          formatId = descriptor.formatId,
          completionToken = descriptor.completionToken,
          season = state.season, cash = descriptor.cash,
          ball = descriptor.ball, ballCount = descriptor.ballCount,
          goldJackpot = false, rank = 1,
          titleId = history.titleClaimed and descriptor.titleId or nil,
          cardId = history.cardClaimed and descriptor.cardId or nil,
        })
      end
      if not receipt or not receiptMatchesDescriptor(receipt, descriptor) then
        return outcome("archive_error", { error = "claimed receipt mismatch" })
      end
      -- Archive history alone cannot prove that this particular save ever
      -- committed the physical package.  A split/copy of an older save may
      -- see the account-wide claimed receipt while still lacking its cash,
      -- Balls and Pokemon.  Every legitimate claim path writes the local
      -- applied journal in the same save transaction before claiming the
      -- Archive, so require that evidence before removing the controller
      -- queue or granting its presentation flags.
      local entry = journal.applied[descriptor.id]
        or journal.claimed[descriptor.id]
      if type(entry) ~= "table" or not sameReceipt(entry.receipt, receipt) then
        return outcome("state_error", {
          error = entry == nil and "claimed archive receipt lacks local delivery evidence"
            or "claimed archive receipt conflicts with local delivery evidence",
          receipt = copy(receipt),
        })
      end
      -- Re-enter the Archive's active-save boundary even for an idempotent
      -- claimed receipt. This rejects an old source save after a completed
      -- NG+ hand-off instead of finalizing it against the next run's Archive.
      if type(archive.claimWorldRankReward) ~= "function" then
        return outcome("archive_error", { error = "missing claim authority" })
      end
      local claimOk, claimResult = pcall(archive.claimWorldRankReward,
        game.save, receipt.id)
      if not claimOk or claimResult ~= true then
        return outcome("archive_error", {
          error = claimOk and claimResult or claimResult,
          receipt = copy(receipt),
        })
      end
      local done, finalizeErr = finalize(game, journal, receipt, entry)
      return outcome(done and "delivered" or "finalize_pending", {
        receipt = copy(receipt), error = finalizeErr,
      })
    end

    local receipt = state.pending[descriptor.id]
    local hadArchivePending = receipt ~= nil
    if receipt ~= nil then
      receipt = canonicalReceipt(receipt)
      if not receipt
          or not pendingReceiptMatchesDescriptor(receipt, descriptor, state) then
        return outcome("archive_error", { error = "pending receipt mismatch" })
      end
      if receipt.season ~= state.season
          or receipt.species and state.delivered[receipt.species] == true
          or receipt.goldJackpot and state.goldJackpotClaimed == true then
        return outcome("archive_error", {
          error = "pending receipt conflicts with active archive state",
        })
      end
    else
      local buildErr, detail
      receipt, buildErr, detail = buildReceipt(game, descriptor, state)
      if buildErr == "season_complete" then
        local history = historyFor(state, descriptor.formatId)
        local format = formatRow(descriptor.formatId) or {}
        local titleOwed = type(format.championTitle) == "table"
          and history.titleClaimed ~= true
          and not pendingPresentation(state, descriptor, "titleId")
        if titleOwed and type(opts.grantTitle) ~= "function" then
          return outcome("config_error", { error = "missing title authority" })
        end
        if type(archive.openWorldRankSeason) ~= "function" then
          return outcome("archive_error", { error = "missing season authority" })
        end
        -- Persist the controller descriptor before the account-wide season
        -- rollover. A failed save leaves the prior season byte-identical and
        -- therefore cannot lose a queued championship across cold reload.
        if not writeSave(game) then
          return outcome("save_failed", { error = "season precommit failed" })
        end
        local openOk, opened, openState = pcall(archive.openWorldRankSeason,
          game.save, state.season)
        if not openOk or opened ~= true then
          return outcome("archive_error", { error = openState or opened })
        end
        state = type(openState) == "table" and openState
          or archive.worldRankState()
        receipt, buildErr, detail = buildReceipt(game, descriptor, state)
      end
      if not receipt then
        return outcome(buildErr or "config_error", { error = detail })
      end
    end
    if receipt.titleId and type(opts.grantTitle) ~= "function" then
      return outcome("config_error", { error = "missing title authority",
        receipt = copy(receipt) })
    end
    if type(archive.reserveWorldRankReward) ~= "function" then
      return outcome("archive_error", { error = "missing reserve authority" })
    end
    if type(archive.validateWorldRankReward) ~= "function" then
      return outcome("archive_error", { error = "missing validation authority" })
    end
    local validateOk, validated, validationState = pcall(
      archive.validateWorldRankReward, game.save, receipt)
    if not validateOk or validated ~= true then
      return outcome("archive_error", {
        error = validationState or validated,
        receipt = copy(receipt),
      })
    end

    local archiveValidated = false
    if hadArchivePending then
      -- Existing account-wide state must authenticate this active save/run
      -- before even a local journal write. The idempotent Archive reservation
      -- is a no-write preflight when the owner and receipt still match.
      local reserveOk, reserved, reserveState = pcall(
        archive.reserveWorldRankReward, game.save, receipt)
      if not reserveOk or reserved ~= true then
        return outcome("archive_error", { error = reserveState or reserved })
      end
      archiveValidated = true
    end

    -- A locally claimed/applied journal is stronger than a physical scan. It
    -- was written in the same game-save transaction as every reward component
    -- and can therefore repair an archive copy that still shows `pending`
    -- without replaying cash, Balls or the Pokemon.
    local applied = journal.applied[receipt.id] or journal.claimed[receipt.id]
    if applied and not sameReceipt(applied.receipt, receipt) then
      return outcome("state_error", { error = "applied receipt mismatch" })
    end
    if not applied then
      local physical, physicalState = scanReceipt(game, receipt)
      if physical then
        -- A Pokemon receipt without this save's applied journal may have
        -- arrived through Link/import. It never manufactures local authority.
        return outcome("foreign_receipt", { receipt = copy(receipt) })
      elseif physicalState == "foreign" then
        return outcome("foreign_receipt", { receipt = copy(receipt) })
      end
      -- Persist the controller descriptor and this save's local reservation
      -- together before creating any account-wide Archive reservation.  If
      -- the save write fails, a cold reload may lose the just-finished battle
      -- queue, but it can never inherit an orphan Archive receipt that blocks
      -- the next Legacy hand-off forever.
      local localOk, localErr = reserveLocal(game, journal, receipt)
      if not localOk then return outcome(localErr, { receipt = copy(receipt) }) end
    end

    -- Revalidate even an existing pending receipt through the active-save
    -- Archive boundary only after the local queue/journal has reached disk.
    -- The Archive treats an identical reservation as a no-write success.
    if not archiveValidated then
      local reserveOk, reserved, reserveState = pcall(
        archive.reserveWorldRankReward, game.save, receipt)
      if not reserveOk or reserved ~= true then
        return outcome("archive_error", { error = reserveState or reserved })
      end
    end

    if not applied then
      local localErr
      applied, localErr = applyPhysical(game, journal, receipt)
      if not applied then
        journal.last = {
          id = receipt.id, formatId = receipt.formatId,
          species = receipt.species, status = localErr,
        }
        persist(journal)
        return outcome(localErr, { receipt = copy(receipt) })
      end
    end

    local claimedOk, claimState = pcall(archive.claimWorldRankReward,
      game.save, receipt.id)
    if not claimedOk or claimState ~= true then
      return outcome("archive_pending", {
        receipt = copy(receipt), error = claimedOk and claimState or claimState,
      })
    end
    local done, finalizeErr = finalize(game, journal, receipt, applied)
    return outcome(done and "delivered" or "finalize_pending", {
      receipt = copy(receipt), destination = applied.destination,
      box = applied.box, error = finalizeErr,
    })
  end

  function R.reconcile(game)
    game = game or R.game
    if not (game and game.save) then return outcome("unavailable") end
    if R._reconciling then return outcome("busy") end
    if isLinkActive(game) then return outcome("link_deferred") end
    if tournament.readOnly == true then
      return outcome("state_error", {
        error = tournament.readOnlyReason
          or "World Rank tournament state is read-only",
      })
    end
    if R._needsFlush and writeSave(game) then R._needsFlush = nil end
    local rows, rowsErr = pendingDescriptors(game)
    if not rows then return outcome("state_error", { error = rowsErr }) end
    -- The real controller discovers a future schema lazily inside state(),
    -- which pendingRewards() calls above. Re-check after that boundary so the
    -- very first reconciliation cannot consume a raw future queue.
    if tournament.readOnly == true then
      return outcome("state_error", {
        error = tournament.readOnlyReason
          or "World Rank tournament state is read-only",
      })
    end
    if #rows == 0 then return outcome("none") end
    R._reconciling = true
    local firstWait
    for _, row in ipairs(rows) do
      local ok, result = pcall(process, game, row)
      if not ok then
        R._reconciling = nil
        return outcome("config_error", { error = tostring(result) })
      end
      -- A format-local empty pool (including an undiscovered starter-only
      -- pool) is not a queue-wide failure. A later championship may deliver
      -- the last globally unseen species and thereby make this receipt
      -- eligible on the next pass. Hard state/archive/config/storage failures
      -- still stop immediately so they remain visible and retryable.
      if result.status == "pool_wait"
          or result.status == "discovery_wait" then
        firstWait = firstWait or result
      else
        R._reconciling = nil
        return result
      end
    end
    R._reconciling = nil
    return firstWait or outcome("none")
  end

  local function localized(en, de)
    local i18n = opts.i18n
    if i18n and type(i18n.text) == "function" then
      local ok, value = pcall(i18n.text, en, de)
      if ok and type(value) == "string" then return value end
    end
    return en
  end

  local function localizedValue(value)
    if type(value) ~= "table" then return tostring(value or "") end
    return localized(value.en or value[1] or "", value.de or value[2]
      or value.en or value[1] or "")
  end

  function R.status(game)
    game = game or R.game
    local rows = pendingDescriptors(game)
    rows = type(rows) == "table" and rows or {}
    local state = archiveState()
    state = type(state) == "table" and state or { pending = {}, claimed = {} }
    local journal = ledger()
    journal = type(journal) == "table" and journal or freshLedger()
    local first = rows[1]
    local receipt = first and (state.pending[first.id]
      or type(state.claimed[first.id]) == "table" and state.claimed[first.id])
      or nil
    local last = type(journal.last) == "table" and journal.last or {}
    local status = first and (last.id == first.id and last.status or
      receipt and "reserved" or "waiting") or last.status or "none"
    local model = {
      pending = #rows > 0,
      pendingCount = #rows,
      formatId = first and first.formatId or last.formatId,
      sealed = type(receipt) == "table",
      species = type(receipt) == "table" and receipt.species or nil,
      status = status,
      destination = last.destination,
      box = last.box,
    }
    local format = formatRow(model.formatId)
    model.format = format and localizedValue(format.name) or model.formatId
    if model.species then
      local source = speciesSource(game)
      local definition = type(source) == "table" and source[model.species] or nil
      local label = type(definition) == "table"
        and localizedValue(definition.name) or ""
      model.speciesLabel = label ~= "" and label or model.species
    end
    if model.destination == "box" then
      model.destinationText = localized(
        ("BOX %d"):format(model.box or 1),
        ("BOX %d"):format(model.box or 1))
    elseif model.destination == "party" then
      model.destinationText = localized("PARTY", "TEAM")
    end
    if model.pending then
      model.text = localized(
        "A sealed World Rank prize is pending. Free PARTY/BOX and BAG room; delivery retries automatically.",
        "Ein versiegelter Weltrang-Preis wartet. Schaffe Platz in TEAM/BOX und BEUTEL; die Zustellung wird automatisch erneut versucht.")
    elseif status == "delivered" then
      model.text = localized(
        "The World Rank prize was delivered and verified.",
        "Der Weltrang-Preis wurde zugestellt und bestätigt.")
    end
    model.resultText = model.text
    return model
  end

  R.pendingModel = R.status

  function R.install(game)
    R.game = game or R.game
    if R.game then R.reconcile(R.game) end
    if R._installed then return true end
    R._installed = true
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("save.loaded", function(event)
        R.game = event and event.game or R.game
        if R.game then R.reconcile(R.game) end
      end)
      mod.events:on("world.stepped", function(event)
        local live = event and event.game or R.game
        if live then R.reconcile(live) end
      end)
    end
    return true
  end

  R.copy = copy
  R.hash = hash
  return R
end
