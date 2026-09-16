-- Kanto Ascendant 6.7 Discovery Core: shared encounter-overlay planner.
--
-- A caller supplies one integer roll.  The same value chooses both the source
-- bucket and a row within that bucket, so classic encounters and visible
-- Wilds never need a second random draw.  Candidate rows are copied; canonical
-- Kanto/Johto/Hoenn encounter data is never patched or annotated.

local Module = {
  ROLL_MAX = 10000,
  NATIVE_MAX = 9750,
  JOHTO_MAX = 9950,
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

local function validRoll(value)
  return type(value) == "number" and value == math.floor(value)
    and value >= 1 and value <= Module.ROLL_MAX
end

local function key(value)
  return type(value) == "string" and value:upper() or nil
end

local function enabled(set, row)
  if type(set) ~= "table" or type(row) ~= "table" then return false end
  local family = key(row.family)
  local species = key(row.species)
  return family and set[family] == true
    or species and set[species] == true
    or false
end

local function habitatMatches(row, habitat)
  if type(row) ~= "table" or type(habitat) ~= "string" then return false end
  local wanted = habitat:lower()
  local habitats = row.habitats or row.habitat
  if type(habitats) == "string" then return habitats:lower() == wanted end
  if type(habitats) ~= "table" then return false end
  if habitats[wanted] == true or habitats[habitat] == true then return true end
  for _, candidate in ipairs(habitats) do
    if type(candidate) == "string" and candidate:lower() == wanted then
      return true
    end
  end
  return false
end

local function candidates(pool, predicate)
  local out = {}
  for _, row in ipairs(type(pool) == "table" and pool or {}) do
    if type(row) == "table" and row.species ~= nil
        and (not predicate or predicate(row)) then
      out[#out + 1] = copy(row)
    end
  end
  return out
end

local function requestedSource(roll)
  if roll <= Module.NATIVE_MAX then return "native" end
  if roll <= Module.JOHTO_MAX then return "johto" end
  return "hoenn"
end

local function bucketOffset(source, roll)
  if source == "johto" then return roll - Module.NATIVE_MAX - 1 end
  if source == "hoenn" then return roll - Module.JOHTO_MAX - 1 end
  return roll - 1
end

function Module.plan(args)
  args = type(args) == "table" and args or {}
  local roll = args.roll
  if not validRoll(roll) then return nil, "roll-out-of-range" end

  local native = candidates(args.nativePool)
  local johto = candidates(args.johtoPool, function(row)
    return enabled(args.johtoUnlocked, row)
  end)
  local hoenn = candidates(args.hoennPool, function(row)
    return enabled(args.hoennTraces, row)
      and habitatMatches(row, args.habitat)
  end)
  local pools = { native = native, johto = johto, hoenn = hoenn }

  local requested = requestedSource(roll)
  local source = requested
  local fallback = false
  if #pools[source] == 0 then
    if source ~= "native" and #native > 0 then
      source = "native"
      fallback = true
    else
      return nil, "native-pool-empty"
    end
  end

  local pool = pools[source]
  local offset = source == requested and bucketOffset(source, roll)
    or bucketOffset("native", roll)
  local index = (offset % #pool) + 1
  return {
    roll = roll,
    rollsUsed = 1,
    requestedSource = requested,
    source = source,
    fallback = fallback,
    encounter = copy(pool[index]),
    candidateIndex = index,
    eligibleCounts = {
      native = #native,
      johto = #johto,
      hoenn = #hoenn,
    },
  }
end

function Module.planWithRng(args, rng)
  if type(rng) ~= "function" then return nil, "rng-required" end
  local input = {}
  for field, value in pairs(type(args) == "table" and args or {}) do
    input[field] = value
  end
  input.roll = rng(1, Module.ROLL_MAX)
  return Module.plan(input)
end

Module.copy = copy
Module.requestedSource = requestedSource
Module.habitatMatches = habitatMatches
return Module
