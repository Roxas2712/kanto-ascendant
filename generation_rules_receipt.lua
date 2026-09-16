-- Immutable, presentation-safe rules receipts for battles, links and replays.

return function(_mod, opts)
  opts = opts or {}
  local R = { VERSION = 1 }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function canonical(value, seen)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" or kind == "number" then return tostring(value) end
    if kind == "string" then return ("%q"):format(value) end
    if kind ~= "table" then return ("<%s>"):format(kind) end
    seen = seen or {}
    if seen[value] then error("cyclic receipt") end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do
      parts[#parts + 1] = canonical(key, seen) .. ":" .. canonical(value[key], seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
  end

  local function hash(text)
    local value = 5381
    for index = 1, #text do value = (value * 33 + text:byte(index)) % 4294967296 end
    return ("%08x"):format(value)
  end

  function R.create(resolved)
    resolved = type(resolved) == "table" and resolved or {}
    local receipt = {
      schema = "kasc-generation-rules-receipt/v1",
      mode = tostring(resolved.mode or "gen1"),
      activeEpoch = math.max(1, math.floor(tonumber(resolved.activeEpoch) or 1)),
      unlockedEpoch = math.max(1,
        math.floor(tonumber(resolved.unlockedEpoch) or 1)),
      supportedEpoch = math.max(1,
        math.floor(tonumber(resolved.supportedEpoch) or 1)),
      versionGroup = tostring(resolved.versionGroup or "running-rby-rom"),
      strictQuirks = resolved.strictQuirks == true,
      projection = tostring(resolved.projection or "generation-pool-1"),
      resolverVersions = copy(resolved.resolverVersions or {
        rules = 1, evidence = 1, migration = 1, moves = 1, types = 1,
      }),
      capabilities = copy(resolved.capabilities or {}),
    }
    local hashInput = copy(receipt)
    receipt.dataHash = hash(canonical(hashInput))
    return receipt
  end

  R.CHECKPOINT_KEY = 'kasc.generation-receipt/v1'
  function R.attachBattle(battle, resolved)
    if type(battle) ~= "table" then return nil, "battle" end
    if type(battle.kascGenerationRulesReceipt) == "table" then
      return copy(battle.kascGenerationRulesReceipt), "existing"
    end
    local receipt = R.create(resolved)
    battle.kascGenerationRulesReceipt = copy(receipt)
    battle.field = battle.field or {}
    battle.field.tokens = battle.field.tokens or {}
    battle.field.tokens[R.CHECKPOINT_KEY] = copy(receipt)
    return copy(receipt), "created"
  end

  function R.restoreBattle(battle)
    local value=battle and battle.field and battle.field.tokens
      and battle.field.tokens[R.CHECKPOINT_KEY]
    if value==nil then return nil,'legacy_checkpoint_without_receipt' end
    if type(value)~='table' or value.schema~='kasc-generation-rules-receipt/v1'
        or type(value.activeEpoch)~='number' or value.activeEpoch%1~=0
        or value.activeEpoch<1 or value.activeEpoch>9 then return nil,'invalid_checkpoint_receipt' end
    local body=copy(value);body.dataHash=nil
    local ok,encoded=pcall(canonical,body)
    if not ok or hash(encoded)~=value.dataHash then return nil,'invalid_checkpoint_receipt' end
    battle.kascGenerationRulesReceipt=copy(value)
    return copy(value),'restored'
  end

  function R.readBattle(battle)
    return copy(type(battle) == "table" and battle.kascGenerationRulesReceipt
      or nil)
  end

  function R.forReplay(battle)
    local receipt = R.readBattle(battle)
    return receipt and { generationRules = receipt } or nil
  end

  function R.fingerprint(receipt)
    if type(receipt) ~= "table" then return nil end
    return hash(canonical(receipt))
  end

  function R.compatible(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
      return false, "missing_rules_receipt"
    end
    if left.dataHash ~= right.dataHash then return false, "rules_data_hash" end
    if left.mode ~= right.mode or left.activeEpoch ~= right.activeEpoch
        or left.versionGroup ~= right.versionGroup
        or left.strictQuirks ~= right.strictQuirks then
      return false, "rules_profile"
    end
    return true
  end

  -- Link peers compare effective battle rules, not how they unlocked them or
  -- whether AUTO/manual selected the same profile. Keep the complete replay
  -- receipt unchanged; only this explicit link projection omits provenance.
  function R.compatibleLink(left, right)
    local function effective(receipt)
      if type(receipt)~='table' then return nil,'missing_rules_receipt' end
      if receipt.schema~='kasc-generation-rules-receipt/v1' then
        return nil,'invalid_rules_receipt'
      end
      local body=copy(receipt);body.dataHash=nil
      local ok,encoded=pcall(canonical,body)
      if not ok or hash(encoded)~=receipt.dataHash then
        return nil,'invalid_rules_receipt'
      end
      return {schema=receipt.schema,activeEpoch=receipt.activeEpoch,
        versionGroup=receipt.versionGroup,strictQuirks=receipt.strictQuirks,
        projection=receipt.projection,resolverVersions=receipt.resolverVersions,
        capabilities=receipt.capabilities}
    end
    local a,why=effective(left);if not a then return false,why end
    local b,reason=effective(right);if not b then return false,reason end
    if canonical(a)~=canonical(b) then return false,'rules_profile' end
    return true
  end

  R.copy = copy
  R.canonical = canonical
  R.hash = hash
  return R
end
