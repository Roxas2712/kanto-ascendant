-- Optional NG+ random-partner Card.
--
-- This owner rolls exactly two independent starter identities from the
-- caller-supplied, already unlocked pool.  `starter` keeps the authored
-- regional-starter contract; `global` accepts every caller-approved base
-- species. It does not create a
-- Pokemon and does not touch the save on its own: legacy_starters commits the
-- receipt, both Pokemon identities and the ordinary Oak-lab flags in one save
-- transaction.  A failed transaction therefore cannot consume a roll.

return function(mod, opts)
  opts = opts or {}
  local C = {
    CARD_ID = "KASC-66-LEGACY-RANDOM-PARTNERS",
    OWNER = "kasc.legacy-random-partners/v1",
    VERSION = "1.0.0",
    OPTION_KEY = "legacy_random_partners",
    RECEIPT_VERSION = 1,
  }
  local STARTER_BASES = {
    BULBASAUR=true, CHARMANDER=true, SQUIRTLE=true, PIKACHU=true,
    CHIKORITA=true, CYNDAQUIL=true, TOTODILE=true,
    TREECKO=true, TORCHIC=true, MUDKIP=true,
    TURTWIG=true, CHIMCHAR=true, PIPLUP=true,
    SNIVY=true, TEPIG=true, OSHAWOTT=true,
    CHESPIN=true, FENNEKIN=true, FROAKIE=true,
    ROWLET=true, LITTEN=true, POPPLIO=true,
  }
  local LEGENDARY_BASES = {
    ARTICUNO=true, ZAPDOS=true, MOLTRES=true, MEWTWO=true, MEW=true,
    RAIKOU=true, ENTEI=true, SUICUNE=true, LUGIA=true, HO_OH=true,
    CELEBI=true, REGIROCK=true, REGICE=true, REGISTEEL=true,
    LATIAS=true, LATIOS=true, KYOGRE=true, GROUDON=true, RAYQUAZA=true,
    JIRACHI=true, DEOXYS=true,
  }

  local function enabled()
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, C.OPTION_KEY)
      if ok and value == false then return false end
    end
    return true
  end

  local function random(low, high, purpose)
    local value
    if type(opts.random) == "function" then
      value = opts.random(low, high, purpose)
    elseif love and love.math and type(love.math.random) == "function" then
      value = love.math.random(low, high)
    else
      value = math.random(low, high)
    end
    value = math.floor(tonumber(value) or low)
    return math.max(low, math.min(high, value))
  end

  local function normalizedKind(kind)
    return kind == "global" and "global" or "starter"
  end

  local function lineFor(rival, species, source, kind)
    local resolver = kind == "global" and rival.lineForRandomSpecies
      or rival.lineForStarter
    if type(resolver) ~= "function" then return nil end
    return resolver(species, source)
  end

  local function pool(rows, rival, poolKind)
    poolKind = normalizedKind(poolKind)
    local out, seen = {}, {}
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
      local species = type(row) == "table" and row.id or row
      species = type(species) == "string" and species:upper() or nil
      local form = species and species:find("_MEGA", 1, true)
      local eligible = poolKind == "global" or STARTER_BASES[species]
      if species and eligible and not form and not LEGENDARY_BASES[species]
          and not seen[species]
          and rival and lineFor(rival, species, species, poolKind) then
        seen[species] = true
        out[#out + 1] = species
      end
    end
    return out
  end

  local function contains(rows, species)
    for _, value in ipairs(rows) do
      if value == species then return true end
    end
    return false
  end

  function C.enabled() return enabled() end
  C.starterBases = STARTER_BASES

  function C.prepare(rows, rival, poolKind)
    if not enabled() then return nil, "random-partner-card-disabled" end
    poolKind = normalizedKind(poolKind)
    local candidates = pool(rows, rival, poolKind)
    if #candidates == 0 then return nil, poolKind == "global"
      and "no-unlocked-global-partners" or "no-unlocked-random-starters" end
    local playerIndex = random(1, #candidates, "legacy-random-player")
    local rivalIndex = random(1, #candidates, "legacy-random-rival")
    local playerSpecies = candidates[playerIndex]
    local rivalSpecies = candidates[rivalIndex]
    local rivalLine, err = lineFor(
      rival, rivalSpecies, playerSpecies, poolKind)
    if not rivalLine then return nil, err or "random-rival-line-unavailable" end
    return {
      version = C.RECEIPT_VERSION,
      cardId = C.CARD_ID,
      poolKind = poolKind,
      playerSpecies = playerSpecies,
      rivalSpecies = rivalSpecies,
      rivalLineId = rivalLine.lineId,
      poolSize = #candidates,
      playerRoll = playerIndex,
      rivalRoll = rivalIndex,
      independent = true,
    }
  end

  function C.validate(receipt, rows, rival, expectedKind)
    if type(receipt) ~= "table"
        or receipt.version ~= C.RECEIPT_VERSION
        or receipt.cardId ~= C.CARD_ID
        or receipt.independent ~= true then
      return false, "invalid-random-partner-receipt"
    end
    local receiptKind = receipt.poolKind == nil and "starter" or receipt.poolKind
    if receiptKind ~= "starter" and receiptKind ~= "global" then
      return false, "invalid-random-partner-pool-kind"
    end
    expectedKind = normalizedKind(expectedKind or receiptKind)
    if receiptKind ~= expectedKind then
      return false, "random-partner-pool-kind-mismatch"
    end
    local candidates = pool(rows, rival, receiptKind)
    if not contains(candidates, receipt.playerSpecies)
        or not contains(candidates, receipt.rivalSpecies) then
      return false, "random-partner-outside-unlocked-pool"
    end
    local rivalLine = lineFor(rival, receipt.rivalSpecies,
      receipt.playerSpecies, receiptKind)
    if not rivalLine or rivalLine.lineId ~= receipt.rivalLineId then
      return false, "random-rival-receipt-mismatch"
    end
    if tonumber(receipt.poolSize) ~= #candidates then
      return false, "random-partner-pool-changed-before-commit"
    end
    return true
  end

  local support = opts.supportLog
  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      segmentId=C.CARD_ID, cardId=C.CARD_ID, version=C.VERSION,
      schema="kasc.optional-feature-card/v1", owner=C.OWNER,
      active=enabled(), dependencyStatus="local-reviewed",
      providerStatus=enabled() and "atomic-independent-pair"
        or "cold-disabled",
      buildReceiptId="docs/LEGACY_RANDOM_PARTNERS_67.md",
      rollbackReceiptId="select-legacy_random_partners-off",
    })
  end
  return C
end
