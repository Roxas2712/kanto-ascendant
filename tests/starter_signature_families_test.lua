-- Exact TECH-001 cardinality and optional-provider regression coverage.
-- This constructs field_tech.lua without the rest of Ascendant so absence,
-- partial content and an independently named Hoenn provider remain testable.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local makeFieldTech = assert(loadfile(root .. "/field_tech.lua"))()
local checks = 0

local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local ORDER = { "FRENZY_PLANT", "BLAST_BURN", "HYDRO_CANNON" }
local BASE = {
  FRENZY_PLANT = {
    "BULBASAUR", "IVYSAUR", "VENUSAUR",
    "CHIKORITA", "BAYLEEF", "MEGANIUM",
  },
  BLAST_BURN = {
    "CHARMANDER", "CHARMELEON", "CHARIZARD",
    "CYNDAQUIL", "QUILAVA", "TYPHLOSION",
  },
  HYDRO_CANNON = {
    "SQUIRTLE", "WARTORTLE", "BLASTOISE",
    "TOTODILE", "CROCONAW", "FERALIGATR",
  },
}
local HOENN = {
  FRENZY_PLANT = { "TREECKO", "GROVYLE", "SCEPTILE" },
  BLAST_BURN = { "TORCHIC", "COMBUSKEN", "BLAZIKEN" },
  HYDRO_CANNON = { "MUDKIP", "MARSHTOMP", "SWAMPERT" },
}
local HOENN_DEX = {
  TREECKO = 252, GROVYLE = 253, SCEPTILE = 254,
  TORCHIC = 255, COMBUSKEN = 256, BLAZIKEN = 257,
  MUDKIP = 258, MARSHTOMP = 259, SWAMPERT = 260,
}

local function speciesTable(includeHoenn)
  local values = {}
  for _, moveId in ipairs(ORDER) do
    for _, species in ipairs(BASE[moveId]) do
      values[species] = { id = species, tmhm = { "TACKLE" } }
    end
  end
  if includeHoenn then
    for species, dex in pairs(HOENN_DEX) do
      values[species] = { id = species, dex = dex, tmhm = { "TACKLE" } }
    end
  end
  return values
end

local function registry(values)
  return {
    get = function(_, id) return values[id] end,
    register = function(_, id, value)
      assert(values[id] == nil, "duplicate fixture content " .. id)
      values[id] = value
      return value
    end,
    patch = function(_, id, partial)
      local value = assert(values[id], "patch target missing: " .. id)
      for key, replacement in pairs(partial) do value[key] = replacement end
      return value
    end,
  }
end

local function fixture(values, providers)
  local save = {}
  local mod = {
    hooks = { wrap = function() end },
    content = {
      moves = registry({}), items = registry({}), pokemon = registry(values),
    },
    save = {
      get = function(_, key) return save[key] end,
      set = function(_, key, value) save[key] = value end,
    },
    ui = {},
  }
  return makeFieldTech(mod, { starterFamilyProviders = providers or {} })
end

local function hasMove(def, moveId)
  for _, id in ipairs(def and def.tmhm or {}) do
    if id == moveId then return true end
  end
  return false
end

local function exactFamily(actual, expected, label)
  check(#actual == #expected, label .. " cardinality")
  for index, species in ipairs(expected) do
    check(actual[index] == species,
      label .. " stage " .. index .. " expected " .. species)
  end
end

-- The bundled registry and an approved external registry are deliberately
-- indistinguishable here: complete canonical National-Dex #252-260 content
-- yields exactly nine legal stages for every signature attack.
do
  local values = speciesTable(true)
  local tech = fixture(values)
  local status = tech.starterFamilyStatus()
  check(status.activeProvider == "registered_hoenn_252_260",
    "complete canonical Hoenn content did not activate the registry provider")
  check(status.generations == 3 and status.totalStages == 27,
    "complete Kanto/Johto/Hoenn cardinality is not 27")
  local unique = {}
  for _, moveId in ipairs(ORDER) do
    local expected = {}
    for _, species in ipairs(BASE[moveId]) do expected[#expected + 1] = species end
    for _, species in ipairs(HOENN[moveId]) do expected[#expected + 1] = species end
    exactFamily(tech.starterFamilies[moveId], expected, moveId)
    check(status.cardinality[moveId] == 9, moveId .. " status is not 9")
    for _, species in ipairs(expected) do
      check(not unique[species], "duplicate eligible stage " .. species)
      unique[species] = true
      check(hasMove(values[species], moveId),
        species .. " did not receive " .. moveId .. " TM compatibility")
    end
  end

  -- Re-resolution is transactional. If one provider stage disappears after a
  -- valid sync, every injected Hoenn compatibility row is removed; restoring
  -- the complete registry cleanly reactivates all nine stages.
  local swampert = values.SWAMPERT
  values.SWAMPERT = nil
  check(not tech.syncStarterFamilies({ pokemon = values }),
    "a formerly complete provider stayed active after losing one stage")
  status = tech.starterFamilyStatus()
  check(status.totalStages == 18 and status.activeProvider == nil,
    "provider loss did not roll back to exact base cardinality")
  for _, moveId in ipairs(ORDER) do
    for _, species in ipairs(HOENN[moveId]) do
      if values[species] then
        check(not hasMove(values[species], moveId),
          "provider loss leaked formerly injected compatibility to " .. species)
      end
    end
  end
  values.SWAMPERT = swampert
  check(tech.syncStarterFamilies({ pokemon = values }),
    "restored complete provider did not reactivate")
  status = tech.starterFamilyStatus()
  check(status.totalStages == 27
      and status.activeProvider == "registered_hoenn_252_260",
    "reactivated provider did not restore exact 27-stage status")
  for _, moveId in ipairs(ORDER) do
    for _, species in ipairs(HOENN[moveId]) do
      check(hasMove(values[species], moveId),
        "reactivated provider did not restore compatibility to " .. species)
    end
  end
end

-- A partial generation must fail closed as one unit. Eight registered Hoenn
-- stages are not treated as eight individually valid TM targets.
do
  local values = speciesTable(true)
  values.SWAMPERT = nil
  local tech = fixture(values)
  local status = tech.starterFamilyStatus()
  check(status.activeProvider == nil and status.totalStages == 18,
    "partial Hoenn registration did not fall back to 18 base stages")
  check(status.providers.registered_hoenn_252_260.status == "invalid",
    "partial canonical provider is not reported invalid")
  for _, moveId in ipairs(ORDER) do
    exactFamily(tech.starterFamilies[moveId], BASE[moveId],
      "partial/" .. moveId)
    for _, species in ipairs(HOENN[moveId]) do
      if values[species] then
        check(not hasMove(values[species], moveId),
          "partial provider leaked compatibility to " .. species)
      end
    end
  end
end

-- An explicitly approved provider may use different internal ids, but its
-- complete three-stage rows must resolve to National Dex #252-260. This is
-- the load-order-safe compatibility seam for a separate Hoenn content mod.
do
  local values = speciesTable(false)
  local foreign = {
    FRENZY_PLANT = { "EXT_TREE_1", "EXT_TREE_2", "EXT_TREE_3" },
    BLAST_BURN = { "EXT_FIRE_1", "EXT_FIRE_2", "EXT_FIRE_3" },
    HYDRO_CANNON = { "EXT_WATER_1", "EXT_WATER_2", "EXT_WATER_3" },
  }
  local dex = 252
  for _, moveId in ipairs(ORDER) do
    for _, species in ipairs(foreign[moveId]) do
      values[species] = { id = species, dex = dex, tmhm = {} }
      dex = dex + 1
    end
  end
  local tech = fixture(values)
  local called = 0
  local ok = tech.registerStarterFamilyProvider("external_hoenn", function(ctx)
    called = called + 1
    check(type(ctx.getPokemon) == "function",
      "external provider received no registry lookup")
    return { generation = "hoenn", families = foreign }
  end)
  check(ok, "complete external Hoenn provider was rejected")
  check(tech.syncStarterFamilies({ pokemon = values }),
    "complete external Hoenn provider did not activate")
  local status = tech.starterFamilyStatus()
  check(called == 1 and status.activeProvider == "external_hoenn",
    "external provider was not the active fallback")
  check(status.totalStages == 27 and status.generations == 3,
    "external provider did not yield exact 27-stage compatibility")
  for _, moveId in ipairs(ORDER) do
    local expected = {}
    for _, species in ipairs(BASE[moveId]) do expected[#expected + 1] = species end
    for _, species in ipairs(foreign[moveId]) do expected[#expected + 1] = species end
    exactFamily(tech.starterFamilies[moveId], expected,
      "external/" .. moveId)
    for _, species in ipairs(foreign[moveId]) do
      check(hasMove(values[species], moveId),
        "external stage did not gain compatibility: " .. species)
    end
  end

  local externalSwampert = values.EXT_WATER_3
  values.EXT_WATER_3 = nil
  check(not tech.syncStarterFamilies({ pokemon = values }),
    "active external provider did not fail closed after losing one stage")
  status = tech.starterFamilyStatus()
  check(status.activeProvider == nil and status.totalStages == 18,
    "external provider loss did not restore exact base cardinality")
  check(status.providers.external_hoenn.status == "invalid",
    "partial external provider has no invalid diagnostic")
  for _, moveId in ipairs(ORDER) do
    exactFamily(tech.starterFamilies[moveId], BASE[moveId],
      "external-partial/" .. moveId)
    for _, species in ipairs(foreign[moveId]) do
      if values[species] then
        check(not hasMove(values[species], moveId),
          "partial external provider leaked compatibility to " .. species)
      end
    end
  end

  values.EXT_WATER_3 = externalSwampert
  check(tech.syncStarterFamilies({ pokemon = values }),
    "complete external provider did not reactivate")
  status = tech.starterFamilyStatus()
  check(status.activeProvider == "external_hoenn"
      and status.totalStages == 27,
    "reactivated external provider did not restore 27 stages")
  for _, moveId in ipairs(ORDER) do
    for _, species in ipairs(foreign[moveId]) do
      check(hasMove(values[species], moveId),
        "reactivated external stage lacks compatibility: " .. species)
    end
  end
  local duplicate, why = tech.registerStarterFamilyProvider(
    "external_hoenn", function() return foreign end)
  check(not duplicate and why == "already registered",
    "duplicate provider id was not rejected deterministically")
end

-- Provider exceptions and wrong cardinality remain diagnostics, never boot
-- failures or partial compatibility grants.
do
  local values = speciesTable(false)
  local tech = fixture(values, {
    { id = "broken_callback", provider = function() error("boom") end },
    { id = "two_stage_hoenn", provider = function()
      return { generation = "hoenn", families = {
        FRENZY_PLANT = { "ONLY_ONE", "ONLY_TWO" },
        BLAST_BURN = {}, HYDRO_CANNON = {},
      } }
    end },
  })
  check(not tech.syncStarterFamilies({ pokemon = values }),
    "invalid providers unexpectedly activated")
  local status = tech.starterFamilyStatus()
  check(status.totalStages == 18 and status.activeProvider == nil,
    "invalid provider changed base cardinality")
  check(status.providers.broken_callback.status == "invalid"
      and status.providers.broken_callback.reason:find("provider error", 1, true),
    "provider exception has no fail-closed diagnostic")
  check(status.providers.two_stage_hoenn.status == "invalid"
      and status.providers.two_stage_hoenn.reason:find(
        "exactly three stages", 1, true),
    "wrong provider cardinality has no fail-closed diagnostic")
end

print(("starter_signature_families_test: %d checks PASS"):format(checks))
