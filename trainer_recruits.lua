-- Deterministic, class-appropriate party growth for field-trainer rematches.
-- Pools name evolutionary families rather than fixed final forms: a recruit
-- follows its normal level evolutions as the trainer's projected level rises.

local POOLS = {}

local function assign(pool, ...)
  for i = 1, select("#", ...) do
    POOLS[select(i, ...)] = pool
  end
end

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
assign({ "MAGIKARP", "GOLDEEN", "POLIWAG", "TENTACOOL", "SHELLDER", "KRABBY",
         "HORSEA" },
  "OPP_FISHER")
assign({ "HORSEA", "TENTACOOL", "STARYU", "SHELLDER", "GOLDEEN", "POLIWAG",
         "PSYDUCK" },
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
  "OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3",
  "OPP_COOLTRAINER_M", "OPP_COOLTRAINER_F")
assign({ "BULBASAUR", "CHARMANDER", "SQUIRTLE", "PIKACHU", "EEVEE", "TAUROS",
         "LAPRAS" },
  "OPP_PROF_OAK")
assign({ "RHYHORN", "TAUROS", "KANGASKHAN", "SCYTHER", "PINSIR", "LAPRAS" },
  "OPP_CHIEF")
assign({ "RHYHORN", "NIDORAN_M", "NIDORAN_F", "SANDSHREW", "DIGLETT",
         "KANGASKHAN" },
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

local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  CELEBI = true,
}

local function copySlot(slot)
  local out = {}
  for key, value in pairs(slot) do out[key] = value end
  return out
end

local function hash(value)
  local n = 5381
  value = tostring(value or "")
  for i = 1, #value do
    n = (n * 33 + value:byte(i)) % 2147483647
  end
  return n
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
  if method == "FRIENDSHIP" then return depth == 1 and 25 or 45 end
  if method == "ITEM" or method == "TRADE" then
    return depth == 1 and 36 or 52
  end
  return depth == 1 and 30 or 48
end

local function evolvedForLevel(pokemon, species, level)
  local seen = {}
  local depth = 1
  while pokemon[species] and not seen[species] do
    seen[species] = true
    local choices = {}
    for _, evolution in ipairs(pokemon[species].evolutions or {}) do
      local target = evolutionTarget(evolution)
      if target and pokemon[target]
          and level >= evolutionThreshold(evolution, depth) then
        choices[#choices + 1] = target
      end
    end
    table.sort(choices)
    local nextSpecies = choices[1]
    if not nextSpecies then break end
    species = nextSpecies
    depth = depth + 1
  end
  return species
end

local function familyRoots(pokemon)
  local parents = {}
  for species, def in pairs(pokemon or {}) do
    for _, row in ipairs(def.evolutions or {}) do
      local target = evolutionTarget(row)
      if target and pokemon[target] then
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
  return root
end

local function teamTypes(pokemon, team)
  local out = {}
  for _, slot in ipairs(team or {}) do
    local def = pokemon[slot.species]
    for _, typeId in ipairs(def and def.types or {}) do out[typeId] = true end
  end
  return out
end

local function sharesType(pokemon, species, wanted)
  local def = pokemon[species]
  for _, typeId in ipairs(def and def.types or {}) do
    if wanted[typeId] then return true end
  end
  return false
end

local function fallbackPool(pokemon)
  local out = {}
  for species, def in pairs(pokemon or {}) do
    local dex = tonumber(def.dex)
    if not LEGENDARY[species] and (not dex or dex <= 151) then
      out[#out + 1] = species
    end
  end
  table.sort(out)
  return out
end

local R = { pools = POOLS }
local johto = { order = {}, eligible = function() return false end }

function R.configureJohto(order, eligible)
  johto.order = type(order) == "table" and order or {}
  johto.eligible = type(eligible) == "function"
    and eligible or function() return false end
end

local function mergedTypes(pokemon, team, classId)
  local out = teamTypes(pokemon, team)
  for _, species in ipairs(POOLS[classId] or {}) do
    local evolved = evolvedForLevel(pokemon, species, 100)
    for _, typeId in ipairs(pokemon[evolved] and pokemon[evolved].types or {}) do
      out[typeId] = true
    end
  end
  return out
end

local function eligibleJohtoFamilies(pokemon, wantedTypes)
  local out, represented = {}, {}
  local rootFor = familyRoots(pokemon)
  for _, species in ipairs(johto.order) do
    local def = pokemon[species]
    local dex = def and tonumber(def.dex)
    local root = def and rootFor(species)
    if dex and dex > 151 and dex <= 251 and not LEGENDARY[species]
        and root and not represented[root] and johto.eligible(species)
        and (next(wantedTypes) == nil
          or sharesType(pokemon, species, wantedTypes)) then
      represented[root] = true
      out[#out + 1] = species
    end
  end
  return out
end

function R.eligibleJohtoFamilies(data, team, classId)
  local pokemon = data and data.pokemon or {}
  return eligibleJohtoFamilies(pokemon, mergedTypes(pokemon, team, classId))
end

-- A new family joins after every second earned growth tier:
-- progress 0 -> 0, 1/2 -> 1, 3/4 -> 2, and so on, up to six total slots.
function R.expand(data, team, classId, trainerKey, progress, levelBoost, enabled,
    options)
  if enabled == false or type(team) ~= "table" or #team >= 6 then return team end
  options = options or {}
  progress = math.max(0, math.floor(tonumber(progress) or 0))
  local wanted = math.min(6 - #team, math.floor((progress + 1) / 2))
  if wanted <= 0 then return team end

  local pokemon = data and data.pokemon or {}
  local baseLevel, levelCount = 0, 0
  for _, slot in ipairs(team) do
    if tonumber(slot.level) then
      baseLevel = baseLevel + slot.level
      levelCount = levelCount + 1
    end
  end
  baseLevel = levelCount > 0 and math.max(1,
    math.floor(baseLevel / levelCount + 0.5)) or 1
  local targetLevel = math.min(100,
    baseLevel + math.max(0, math.floor(tonumber(levelBoost) or 0)))
  local types = mergedTypes(pokemon, team, classId)
  local rootFor = familyRoots(pokemon)
  local used = {}
  for _, slot in ipairs(team) do
    used[rootFor(slot.species)] = true
  end

  local source = {}
  for _, family in ipairs(POOLS[classId] or fallbackPool(pokemon)) do
    source[#source + 1] = family
  end
  for _, family in ipairs(eligibleJohtoFamilies(pokemon, types)) do
    source[#source + 1] = family
  end
  local candidates = {}
  local start = #source > 0
    and (hash(tostring(trainerKey) .. ":" .. tostring(classId)) % #source) + 1
    or 1
  for pass = 1, 2 do
    for offset = 0, #source - 1 do
      local family = source[((start + offset - 1) % #source) + 1]
      local species = evolvedForLevel(pokemon, family, targetLevel)
      local familyRoot = rootFor(species)
      if pokemon[species] and not LEGENDARY[species] and not used[familyRoot]
          and (pass == 2 or sharesType(pokemon, species, types)) then
        candidates[#candidates + 1] = {
          family = family, species = species, root = familyRoot,
        }
        used[familyRoot] = true
      end
    end
  end

  if #candidates == 0 then return team end
  local out = {}
  for i, slot in ipairs(team) do out[i] = copySlot(slot) end
  local selections = type(options.selections) == "table"
    and options.selections or nil
  local chosen = {}
  for recruit = 1, math.min(wanted, #candidates) do
    local slotIndex = #team + recruit
    local remembered = selections
      and (selections[slotIndex] or selections[tostring(slotIndex)])
    local picked
    if remembered then
      for _, candidate in ipairs(candidates) do
        if candidate.family == remembered and not chosen[candidate.root] then
          picked = candidate
          break
        end
      end
    end
    if not picked then
      for _, candidate in ipairs(candidates) do
        if not chosen[candidate.root] then picked = candidate break end
      end
    end
    if not picked then break end
    chosen[picked.root] = true
    if selections then selections[slotIndex] = picked.family end
    out[#out + 1] = { species = picked.species, level = baseLevel,
      recruited = true }
  end
  return out
end

return R
