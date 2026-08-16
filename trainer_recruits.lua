-- Rematch 2.0 species progression for ordinary field trainers.
--
-- Original roster slots keep their family identity and evolve through the
-- live Pokemon registry. Additional slots are generated when a battle is
-- prepared; only their short anti-repeat history (plus original evolution
-- progress) is persisted. This keeps saves small while allowing class pools
-- to follow newly registered species without a migration.

local POOLS = {}

local function assign(pool, ...)
  for i = 1, select("#", ...) do POOLS[select(i, ...)] = pool end
end

-- Authored seeds remain useful exceptions and make old saves recognizable.
-- The complete pool is expanded from registry types below.
assign({ "RATTATA", "SPEAROW", "EKANS", "SANDSHREW", "NIDORAN_M", "MANKEY" },
  "OPP_YOUNGSTER")
assign({ "CATERPIE", "WEEDLE", "PARAS", "VENONAT", "SCYTHER", "PINSIR" },
  "OPP_BUG_CATCHER")
assign({ "CLEFAIRY", "JIGGLYPUFF", "NIDORAN_F", "VULPIX", "MEOWTH", "EEVEE" },
  "OPP_LASS")
assign({ "MACHOP", "TENTACOOL", "SHELLDER", "KRABBY", "POLIWAG", "SLOWPOKE" },
  "OPP_SAILOR")
assign({ "SANDSHREW", "MANKEY", "GROWLITHE", "POLIWAG", "EXEGGCUTE", "DODUO" },
  "OPP_JR_TRAINER_M")
assign({ "PIKACHU", "CLEFAIRY", "BELLSPROUT", "GOLDEEN", "VULPIX", "CUBONE" },
  "OPP_JR_TRAINER_F")
assign({ "CUBONE", "SLOWPOKE", "RHYHORN", "LICKITUNG", "KANGASKHAN", "DITTO" },
  "OPP_POKEMANIAC")
assign({ "MAGNEMITE", "VOLTORB", "GRIMER", "KOFFING", "PORYGON", "DITTO" },
  "OPP_SUPER_NERD", "OPP_SCIENTIST")
assign({ "GEODUDE", "ONIX", "MACHOP", "RHYHORN", "CUBONE", "SANDSHREW" },
  "OPP_HIKER")
assign({ "KOFFING", "GRIMER", "MACHOP", "MANKEY", "EKANS", "MAGNEMITE" },
  "OPP_BIKER", "OPP_CUE_BALL")
assign({ "GROWLITHE", "VULPIX", "KOFFING", "MAGMAR", "CHARMANDER", "PONYTA" },
  "OPP_BURGLAR")
assign({ "MAGNEMITE", "VOLTORB", "PIKACHU", "ELECTABUZZ", "PORYGON" },
  "OPP_ENGINEER")
assign({ "DROWZEE", "MR_MIME", "VOLTORB", "KOFFING", "CUBONE", "EXEGGCUTE" },
  "OPP_UNUSED_JUGGLER", "OPP_JUGGLER")
assign({ "MAGIKARP", "GOLDEEN", "POLIWAG", "TENTACOOL", "SHELLDER", "KRABBY", "HORSEA" },
  "OPP_FISHER")
assign({ "HORSEA", "TENTACOOL", "STARYU", "SHELLDER", "GOLDEEN", "POLIWAG", "PSYDUCK" },
  "OPP_SWIMMER")
assign({ "POLIWAG", "GROWLITHE", "VOLTORB", "VULPIX", "DODUO", "RHYHORN" },
  "OPP_GAMBLER")
assign({ "CLEFAIRY", "JIGGLYPUFF", "VULPIX", "MEOWTH", "EEVEE", "SEEL" },
  "OPP_BEAUTY")
assign({ "ABRA", "DROWZEE", "SLOWPOKE", "EXEGGCUTE", "MR_MIME", "JYNX" },
  "OPP_PSYCHIC_TR", "OPP_SABRINA")
assign({ "PIKACHU", "MAGNEMITE", "VOLTORB", "ELECTABUZZ", "KOFFING" },
  "OPP_ROCKER", "OPP_LT_SURGE")
assign({ "EKANS", "SANDSHREW", "RHYHORN", "TAUROS", "KANGASKHAN", "ONIX" },
  "OPP_TAMER")
assign({ "PIDGEY", "SPEAROW", "DODUO", "FARFETCHD", "SCYTHER" },
  "OPP_BIRD_KEEPER")
assign({ "MACHOP", "MANKEY", "POLIWAG", "HITMONLEE", "HITMONCHAN" },
  "OPP_BLACKBELT", "OPP_BRUNO")
assign({ "BULBASAUR", "CHARMANDER", "SQUIRTLE", "PIKACHU", "EEVEE", "DRATINI" },
  "OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3", "OPP_COOLTRAINER_M", "OPP_COOLTRAINER_F")
assign({ "BULBASAUR", "CHARMANDER", "SQUIRTLE", "PIKACHU", "EEVEE", "TAUROS", "LAPRAS" },
  "OPP_PROF_OAK")
assign({ "RHYHORN", "TAUROS", "KANGASKHAN", "SCYTHER", "PINSIR", "LAPRAS" },
  "OPP_CHIEF")
assign({ "RHYHORN", "NIDORAN_M", "NIDORAN_F", "SANDSHREW", "DIGLETT", "KANGASKHAN" },
  "OPP_GIOVANNI")
assign({ "EKANS", "KOFFING", "RATTATA", "ZUBAT", "GRIMER", "MACHOP" },
  "OPP_ROCKET")
assign({ "GEODUDE", "ONIX", "RHYHORN", "OMANYTE", "KABUTO", "AERODACTYL" },
  "OPP_BROCK")
assign({ "STARYU", "HORSEA", "PSYDUCK", "POLIWAG", "SHELLDER", "LAPRAS" },
  "OPP_MISTY")
assign({ "ODDISH", "BELLSPROUT", "EXEGGCUTE", "PARAS", "TANGELA", "BULBASAUR" },
  "OPP_ERIKA")
assign({ "KOFFING", "GRIMER", "VENONAT", "EKANS", "ZUBAT", "TENTACOOL" },
  "OPP_KOGA")
assign({ "GROWLITHE", "VULPIX", "PONYTA", "MAGMAR", "CHARMANDER", "EEVEE" },
  "OPP_BLAINE")
assign({ "MEOWTH", "GROWLITHE", "PIKACHU", "EEVEE", "FARFETCHD", "LAPRAS" },
  "OPP_GENTLEMAN")
assign({ "SEEL", "SHELLDER", "SLOWPOKE", "JYNX", "LAPRAS", "STARYU" },
  "OPP_LORELEI")
assign({ "GASTLY", "CUBONE", "DROWZEE", "EKANS", "ZUBAT" },
  "OPP_CHANNELER", "OPP_AGATHA")
assign({ "DRATINI", "MAGIKARP", "CHARMANDER", "AERODACTYL", "HORSEA" },
  "OPP_LANCE")

local CLASS_THEMES = {
  OPP_BUG_CATCHER = { BUG = true },
  OPP_SWIMMER = { WATER = true }, OPP_FISHER = { WATER = true },
  OPP_HIKER = { ROCK = true, GROUND = true, FIGHTING = true },
  OPP_PSYCHIC_TR = { PSYCHIC_TYPE = true },
  OPP_SABRINA = { PSYCHIC_TYPE = true },
  OPP_BIRD_KEEPER = { FLYING = true },
  OPP_BLACKBELT = { FIGHTING = true }, OPP_BRUNO = { FIGHTING = true },
  OPP_ROCKER = { ELECTRIC = true }, OPP_LT_SURGE = { ELECTRIC = true },
  OPP_BROCK = { ROCK = true, GROUND = true },
  OPP_MISTY = { WATER = true }, OPP_ERIKA = { GRASS = true },
  OPP_KOGA = { POISON = true }, OPP_BLAINE = { FIRE = true },
  OPP_LORELEI = { ICE = true, WATER = true },
  OPP_AGATHA = { GHOST = true, POISON = true },
  OPP_CHANNELER = { GHOST = true, PSYCHIC_TYPE = true },
  OPP_LANCE = { DRAGON = true, FLYING = true },
}

local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  CELEBI = true,
}

local TWO_STAGE = {
  { 50, 50 }, { 40, 60 }, { 30, 70 }, { 20, 80 }, { 10, 90 },
}
local THREE_STAGE = {
  { 50, 30, 20 }, { 40, 30, 30 }, { 30, 30, 40 },
  { 20, 30, 50 }, { 10, 25, 65 }, { 5, 20, 75 }, { 5, 10, 85 },
}
local HISTORY_LIMIT = 3

local R = { pools = POOLS, classThemes = CLASS_THEMES }
local availability = function() return false end

local function copySlot(slot)
  local out = {}
  for key, value in pairs(slot or {}) do out[key] = value end
  return out
end

local function hash(value)
  local n = 5381
  value = tostring(value or "")
  for i = 1, #value do n = (n * 33 + value:byte(i)) % 2147483647 end
  return n
end

local function randomInt(random, lo, hi, seed)
  if hi <= lo then return lo end
  local value
  if type(random) == "function" then value = random(lo, hi) end
  value = math.floor(tonumber(value) or (lo + hash(seed) % (hi - lo + 1)))
  return math.max(lo, math.min(hi, value))
end

local function evolutionTarget(row)
  return row and (row.species or row[2])
end

local function evolutionMethod(row)
  return row and (row.method or row[1])
end

local function evolutionThreshold(row, depth)
  local method = evolutionMethod(row)
  if method == "LEVEL" then return tonumber(row.level or row[3]) or 101 end
  if method == "FRIENDSHIP" or method == "FRIENDSHIP_DAY"
      or method == "FRIENDSHIP_NIGHT" then
    return depth == 1 and 25 or 45
  end
  if method == "ITEM" or method == "TRADE" then
    return depth == 1 and 36 or 52
  end
  return depth == 1 and 30 or 48
end

local function graphFor(pokemon)
  local parents, children = {}, {}
  for species, def in pairs(pokemon or {}) do
    children[species] = children[species] or {}
    for _, row in ipairs(def.evolutions or {}) do
      local target = evolutionTarget(row)
      if target and pokemon[target] then
        children[species][#children[species] + 1] = row
        parents[target] = parents[target] or {}
        parents[target][#parents[target] + 1] = species
      end
    end
  end
  local memo = {}
  local function root(species, visiting)
    if memo[species] then return memo[species] end
    visiting = visiting or {}
    if visiting[species] then return species end
    visiting[species] = true
    local choices = parents[species] or {}
    table.sort(choices)
    local result = choices[1] and root(choices[1], visiting) or species
    visiting[species] = nil
    memo[species] = result
    return result
  end
  return { parents = parents, children = children, root = root }
end

local function sharesType(pokemon, species, wanted)
  local def = pokemon[species]
  for _, typeId in ipairs(def and def.types or {}) do
    if wanted[typeId] then return true end
  end
  return false
end

local function themesFor(pokemon, team, classId)
  local out = {}
  for typeId in pairs(CLASS_THEMES[classId] or {}) do out[typeId] = true end
  for _, species in ipairs(POOLS[classId] or {}) do
    local def = pokemon[species]
    for _, typeId in ipairs(def and def.types or {}) do out[typeId] = true end
  end
  if next(out) == nil then
    for _, slot in ipairs(team or {}) do
      local def = pokemon[slot.species]
      for _, typeId in ipairs(def and def.types or {}) do out[typeId] = true end
    end
  end
  return out
end

function R.configureJohto(_, eligible)
  availability = type(eligible) == "function" and eligible
    or function() return false end
end

-- Registered branches are additionally filtered by live Ascendant state.
-- Kanto targets are always legal; callers decide when Johto/custom targets
-- are released through this seam.
function R.configureEvolutionAvailability(callback)
  R.evolutionAvailable = type(callback) == "function" and callback or nil
end

local function targetAvailable(pokemon, from, row, context)
  local target = evolutionTarget(row)
  if not target or not pokemon[target] then return false end
  local def = pokemon[target]
  local dex = tonumber(def.dex or def.index)
  if dex and dex <= 151 then return true end
  if dex and dex <= 251 then
    -- Elm/Ascendant release whole evolutionary families. A newly released
    -- Chikorita must be allowed to mature into Bayleef/Meganium even though
    -- those two IDs do not own separate encounter flags.
    return context and context.familyUnlocked == true
      or availability(target) == true
  end
  if context and context.original == false then
    -- Additional pool members are selected from released family roots. Do
    -- not silently turn a Kanto recruit into a gated custom final form; an
    -- original Raichu may still progress to an unlocked Gorochu generically.
    return false
  end
  if R.evolutionAvailable then
    return R.evolutionAvailable(target, from, row, context) == true
  end
  return availability(target) == true
end

local function reachableStages(pokemon, start, level, context)
  context = context or {}
  local graph = context.graph or graphFor(pokemon)
  context.familyUnlocked = context.familyUnlocked == true
    or availability(start) == true
  local stages, seen = { [0] = { start } }, {}
  local function visit(species, depth)
    local key = species .. ":" .. tostring(depth)
    if seen[key] then return end
    seen[key] = true
    for _, row in ipairs(graph.children[species] or {}) do
      local target = evolutionTarget(row)
      local nextDepth = depth + 1
      if level >= evolutionThreshold(row, nextDepth)
          and targetAvailable(pokemon, species, row, context) then
        stages[nextDepth] = stages[nextDepth] or {}
        stages[nextDepth][#stages[nextDepth] + 1] = target
        visit(target, nextDepth)
      end
    end
  end
  visit(start, 0)
  local maximum = 0
  for depth, list in pairs(stages) do
    table.sort(list)
    if #list > 0 and depth > maximum then maximum = depth end
  end
  return stages, maximum
end

function R.stageWeights(rematchNumber, maximumStage)
  rematchNumber = math.max(1, math.floor(tonumber(rematchNumber) or 1))
  if maximumStage <= 0 then return { 100 } end
  if maximumStage == 1 then
    local row = TWO_STAGE[math.min(rematchNumber, #TWO_STAGE)]
    return { row[1], row[2] }
  end
  local row = THREE_STAGE[math.min(rematchNumber, #THREE_STAGE)]
  return { row[1], row[2], row[3] }
end

local function rolledStage(rematchNumber, maximumStage, random, seed)
  local weights = R.stageWeights(rematchNumber, maximumStage)
  local roll = randomInt(random, 1, 100, seed .. ":stage")
  local bucket, running = #weights, 0
  for i, weight in ipairs(weights) do
    running = running + weight
    if roll <= running then bucket = i break end
  end
  if maximumStage <= 1 then return bucket - 1 end
  if bucket == 1 then return 0 end
  if bucket == 3 then return maximumStage end
  -- Four-stage and future lines share the middle bucket across their
  -- intermediate stages instead of being artificially capped at Gen II.
  return randomInt(random, 1, maximumStage - 1, seed .. ":middle")
end

local function evolveOriginal(pokemon, slot, slotIndex, rematchNumber,
    levelBoost, options, update)
  local start = slot.species
  local level = math.min(100, math.max(1,
    math.floor(tonumber(slot.level) or 1) + levelBoost))
  local context = { original = true, slot = slotIndex,
    rematchNumber = rematchNumber, level = level, graph = options.graph }
  local stages, maximum = reachableStages(pokemon, start, level, context)
  local selected = rolledStage(rematchNumber, maximum, options.random,
    tostring(options.seed) .. ":original:" .. tostring(slotIndex)
      .. ":" .. tostring(rematchNumber))
  local savedStages = options.originalStages or {}
  local saved = math.max(0, math.floor(tonumber(
    savedStages[slotIndex] or savedStages[tostring(slotIndex)]) or 0))
  selected = math.min(maximum, math.max(saved, selected))
  local choices = stages[selected] or stages[0]
  local savedBranches = options.originalBranches or {}
  local remembered = savedBranches[slotIndex]
    or savedBranches[tostring(slotIndex)]
  local species
  for _, candidate in ipairs(choices) do
    if candidate == remembered then species = candidate break end
  end
  species = species or choices[randomInt(options.random, 1, #choices,
    tostring(options.seed) .. ":branch:" .. tostring(slotIndex)
      .. ":" .. tostring(rematchNumber))]
  update.originalStages[slotIndex] = selected
  if selected > 0 then update.originalBranches[slotIndex] = species end
  local out = copySlot(slot)
  out.species = species
  out.origin = "original"
  out.originalSpecies = start
  out.evolutionStage = selected
  return out
end

local function familyCatalog(pokemon, graph, wanted)
  local byRoot = {}
  for species, def in pairs(pokemon or {}) do
    if not LEGENDARY[species] then
      local root = graph.root(species)
      local row = byRoot[root] or { root = root, members = {} }
      row.members[#row.members + 1] = species
      local dex = tonumber(def.dex or def.index)
      if dex and dex <= 151 then
        if not row.kantoSeed or dex < row.kantoDex then
          row.kantoSeed, row.kantoDex = species, dex
        end
      end
      if sharesType(pokemon, species, wanted) then row.thematic = true end
      byRoot[root] = row
    end
  end
  local out = {}
  for _, row in pairs(byRoot) do
    table.sort(row.members)
    local released = row.kantoSeed ~= nil
    if not released then
      for _, species in ipairs(row.members) do
        if availability(species) then released = true break end
      end
    end
    if released and row.thematic then
      row.seed = row.kantoSeed or row.root
      out[#out + 1] = row
    end
  end
  table.sort(out, function(a, b) return a.root < b.root end)
  return out
end

local function bestAdditionalSpecies(pokemon, family, level, context)
  local stages, maximum = reachableStages(pokemon, family, level, context)
  local choices = stages[maximum] or stages[0]
  return choices[1], maximum
end

local function recentPenalty(species, history)
  local previous, consecutive, older = false, 0, 0
  for index = #history, 1, -1 do
    local found = false
    for _, old in ipairs(history[index] or {}) do
      if old == species then found = true break end
    end
    if index == #history then previous = found end
    if found and index == #history - consecutive then
      consecutive = consecutive + 1
    elseif consecutive > 0 then
      -- Consecutive means literally the tail of history.
      break
    end
    if found then older = older + 1 end
  end
  if consecutive >= 2 then return 0 end
  if previous then return 10 end
  if older > 0 then return 55 end
  return 100
end

local function weightedPick(candidates, history, random, seed)
  local total = 0
  for _, candidate in ipairs(candidates) do
    candidate.weight = recentPenalty(candidate.species, history)
    total = total + candidate.weight
  end
  if total <= 0 then
    -- Tiny/exhausted pools relax the hard consecutive exclusion only after
    -- every strict candidate has been considered once.
    for _, candidate in ipairs(candidates) do
      candidate.weight = 1
      total = total + 1
    end
  end
  local roll = randomInt(random, 1, total, seed)
  local running = 0
  for _, candidate in ipairs(candidates) do
    running = running + candidate.weight
    if roll <= running then return candidate end
  end
  return candidates[#candidates]
end

function R.eligibleJohtoFamilies(data, team, classId)
  local pokemon = data and data.pokemon or {}
  local graph = graphFor(pokemon)
  local wanted = themesFor(pokemon, team, classId)
  local out = {}
  for _, family in ipairs(familyCatalog(pokemon, graph, wanted)) do
    if not family.kantoSeed then out[#out + 1] = family.seed end
  end
  return out
end

-- A new member joins after every second earned growth tier:
-- progress 0 -> 0, 1/2 -> 1, 3/4 -> 2, and so on, up to six total slots.
function R.expand(data, team, classId, trainerKey, progress, levelBoost, enabled,
    options)
  options = options or {}
  if type(team) ~= "table" then return team, nil end
  progress = math.max(0, math.floor(tonumber(progress) or 0))
  levelBoost = math.max(0, math.floor(tonumber(levelBoost) or 0))
  local rematchNumber = math.max(1, math.floor(tonumber(
    options.rematchNumber) or (progress + 1)))
  local pokemon = data and data.pokemon or {}
  local graph = graphFor(pokemon)
  options.graph = graph
  local update = { originalStages = {}, originalBranches = {},
    recent = {}, selections = {} }
  options.seed = options.seed or tostring(trainerKey) .. ":" .. tostring(classId)
  local out = {}
  for index, slot in ipairs(team) do
    out[index] = evolveOriginal(pokemon, slot, index, rematchNumber,
      levelBoost, options, update)
  end
  if enabled == false or #team >= 6 then return out, update end

  local wantedCount = math.min(6 - #team, math.floor((progress + 1) / 2))
  if wantedCount <= 0 then return out, update end
  local baseLevel, count = 0, 0
  for _, slot in ipairs(team) do
    if tonumber(slot.level) then
      baseLevel = baseLevel + slot.level
      count = count + 1
    end
  end
  baseLevel = count > 0 and math.max(1, math.floor(baseLevel / count + 0.5)) or 1
  local targetLevel = math.min(100, baseLevel + levelBoost)
  local themes = themesFor(pokemon, team, classId)
  local used = {}
  for _, slot in ipairs(team) do used[graph.root(slot.species)] = true end

  local sources, seen = {}, {}
  local function addFamily(seed)
    if not pokemon[seed] then return end
    local seedDef = pokemon[seed]
    local seedDex = tonumber(seedDef.dex or seedDef.index)
    if seedDex and seedDex > 151 and seedDex <= 251
        and not availability(seed) then return end
    if seedDex and seedDex > 251 and (not R.evolutionAvailable
        or not R.evolutionAvailable(seed, nil, nil, { pool = true })) then
      return
    end
    if seedDex and seedDex > 251 and graph.parents[seed]
        and #graph.parents[seed] > 0 then return end
    local root = graph.root(seed)
    if seen[root] or used[root] or LEGENDARY[seed] then return end
    seen[root] = true
    sources[#sources + 1] = { root = root, seed = seed }
  end
  for _, seed in ipairs(POOLS[classId] or {}) do addFamily(seed) end
  for _, row in ipairs(familyCatalog(pokemon, graph, themes)) do addFamily(row.seed) end
  if #sources == 0 then
    for species in pairs(pokemon) do addFamily(species) end
  end

  local history = type(options.recentHistory) == "table"
    and options.recentHistory or {}
  local chosen = {}
  for recruit = 1, wantedCount do
    local candidates = {}
    for _, source in ipairs(sources) do
      if not chosen[source.root] then
        local species = bestAdditionalSpecies(pokemon, source.seed, targetLevel,
          { original = false, rematchNumber = rematchNumber,
            level = targetLevel, graph = graph })
        if species and not LEGENDARY[species] then
          candidates[#candidates + 1] = {
            root = source.root, family = source.seed, species = species,
          }
        end
      end
    end
    if #candidates == 0 then break end
    local picked = weightedPick(candidates, history, options.random,
      tostring(options.seed) .. ":recruit:" .. tostring(rematchNumber)
        .. ":" .. tostring(recruit))
    chosen[picked.root] = true
    update.recent[#update.recent + 1] = picked.species
    local slotIndex = #team + recruit
    update.selections[slotIndex] = picked.family
    out[#out + 1] = { species = picked.species, level = baseLevel,
      recruited = true, origin = "additional", family = picked.family }
  end
  if not options.deferCommit and type(options.selections) == "table" then
    for index, family in pairs(update.selections) do options.selections[index] = family end
  end
  return out, update
end

function R.commit(state, update, won)
  if type(state) ~= "table" or type(update) ~= "table" then return end
  state.recruitHistory = type(state.recruitHistory) == "table"
    and state.recruitHistory or {}
  state.recruitHistory[#state.recruitHistory + 1] = update.recent or {}
  while #state.recruitHistory > HISTORY_LIMIT do table.remove(state.recruitHistory, 1) end
  state.recruitFamilies = type(state.recruitFamilies) == "table"
    and state.recruitFamilies or {}
  for index, family in pairs(update.selections or {}) do
    state.recruitFamilies[index] = family
  end
  if won then
    state.originalStages = type(state.originalStages) == "table"
      and state.originalStages or {}
    state.originalBranches = type(state.originalBranches) == "table"
      and state.originalBranches or {}
    for index, stage in pairs(update.originalStages or {}) do
      state.originalStages[index] = math.max(
        tonumber(state.originalStages[index]) or 0, tonumber(stage) or 0)
    end
    for index, species in pairs(update.originalBranches or {}) do
      if (update.originalStages[index] or 0) >=
          (state.originalStages[index] or 0) then
        state.originalBranches[index] = species
      end
    end
  end
  state.rematchProgressionVersion = math.max(2,
    math.floor(tonumber(state.rematchProgressionVersion) or 0))
end

R.evolutionThreshold = evolutionThreshold
R.reachableStages = reachableStages
R.recentPenalty = recentPenalty

return R
