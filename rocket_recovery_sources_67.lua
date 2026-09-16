-- Kanto Ascendant 6.7: Rocket incident source authority and raid scaling.
--
-- Local Boxes remain the only automatic/default offer. When they contain no
-- eligible Pokemon, Legacy Bank and Party are explicit opt-in alternatives.
-- The module also emits a deterministic strength receipt across all three
-- live sources. Pokemon already held by Rocket or leased out of the Legacy
-- Bank are absent from that receipt by construction.

return function(mod, opts)
  opts = opts or {}
  local archive = opts.archive
  local localCustody = opts.localCustody
  local R = {
    schema = "kanto-ascendant-rocket-sources/v1",
    version = 1,
    stateKey = "rocket_recovery_sources_67",
    partyCapacity = 6,
    maxTargets = 6,
  }

  local BADGES = { "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE",
    "RAINBOWBADGE", "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE",
    "EARTHBADGE" }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) then return nil end
    if minimum and value < minimum then return nil end
    if maximum and value > maximum then return nil end
    return value
  end

  local function flush(game)
    if not (game and type(game.writeSave) == "function") then return true end
    local ok, result = pcall(game.writeSave, game)
    return ok and result ~= false
  end

  local function emptyState()
    return { schema = R.schema, version = R.version, status = "empty",
      sequence = 0, source = nil, targets = {}, reason = nil }
  end

  local function state(create)
    local raw = mod.save:get(R.stateKey)
    if type(raw) ~= "table" or raw.schema ~= R.schema
        or raw.version ~= R.version then
      raw = emptyState()
      if create ~= false then mod.save:set(R.stateKey, raw) end
    end
    raw.sequence = integer(raw.sequence, 0) or 0
    raw.targets = type(raw.targets) == "table" and raw.targets or {}
    return raw
  end

  local function saveState(value)
    mod.save:set(R.stateKey, value)
    return value
  end

  local function itemId(mon)
    return type(mon) == "table" and (mon.heldItem or mon.item) or nil
  end

  local function eligible(mon)
    if type(mon) ~= "table" or type(mon.species) ~= "string"
        or mon.species == "" then return false end
    if mon.isEgg == true or mon.egg == true then return false end
    local item = itemId(mon)
    if mon.mail ~= nil or mon.mailData ~= nil or mon.heldMail ~= nil
        or type(item) == "string" and item:upper():find("MAIL", 1, true) then
      return false
    end
    if mon.questBound == true or mon.storyBound == true or mon.locked == true
        or mon.custody ~= nil or mon.__kaRocketCustodyId ~= nil then
      return false
    end
    return true
  end

  local function localRows(game)
    local rows = {}
    for boxIndex, box in ipairs(game and game.save and game.save.boxes or {}) do
      if type(box) == "table" then
        for slotIndex, mon in ipairs(box) do
          if eligible(mon) and mon.__kaLegacyId == nil
              and mon.legacyImported ~= true and mon.legacyLease == nil then
            rows[#rows + 1] = { source = "box", box = boxIndex,
              slot = slotIndex, mon = mon }
          end
        end
      end
    end
    return rows
  end

  local function legacyRows(game)
    if not (archive and type(archive.availableMons) == "function") then
      return {}
    end
    local ok, rows = pcall(archive.availableMons, game and game.save)
    if not ok or type(rows) ~= "table" then return {} end
    local out = {}
    for _, row in ipairs(rows) do
      if type(row) == "table" and type(row.id) == "string"
          and row.withdrawBlocked ~= true and eligible(row.mon) then
        out[#out + 1] = { source = "legacy", id = row.id,
          slot = row.bankSlot, mon = row.mon }
      end
    end
    return out
  end

  local function partyRows(game)
    local rows = {}
    for slot, mon in ipairs(game and game.save and game.save.party or {}) do
      if eligible(mon) then rows[#rows + 1] = {
        source = "party", slot = slot, mon = mon,
      } end
    end
    return rows
  end

  function R.badgeCount(game)
    local count, save = 0, game and game.save or {}
    local inventory = type(save.inventory) == "table" and save.inventory or {}
    for _, badge in ipairs(BADGES) do
      -- Imported R/B/Y saves own badges as inventory key items. Retain the
      -- old top-level boolean as a migration/testing compatibility seam.
      local value = inventory[badge]
      if value == true or (tonumber(value) or 0) > 0
          or save[badge] == true then
        count = count + 1
      end
    end
    return count
  end

  function R.unlocked(game)
    return R.badgeCount(game) >= 8
  end

  function R.sourceChoices(game)
    local boxes, legacy, party = localRows(game), legacyRows(game), partyRows(game)
    if #boxes > 0 then
      return { { id = "box", count = #boxes, automatic = true } }
    end
    local out = {}
    if #legacy > 0 then out[#out + 1] = {
      id = "legacy", count = #legacy, explicit = true,
    } end
    if #party > 1 then out[#out + 1] = {
      id = "party", count = #party, explicit = true,
    } end
    return out
  end

  function R.defaultSource(game)
    return #localRows(game) > 0 and "box" or nil
  end

  local function healthy(mon)
    if type(mon) ~= "table" then return false end
    local hp = tonumber(mon.hp)
    if hp == nil then return true end
    return hp > 0
  end

  function R.planParty(game, maximum)
    local party = game and game.save and game.save.party
    if type(party) ~= "table" or #party <= 1 then
      return nil, "party_fallback_unavailable"
    end
    maximum = integer(maximum, 1, R.maxTargets) or R.maxTargets
    local healthyCount = 0
    for _, mon in ipairs(party) do
      if eligible(mon) and healthy(mon) then healthyCount = healthyCount + 1 end
    end
    if healthyCount == 0 then return nil, "no_usable_party_pokemon" end
    local out = {}
    for slot = #party, 1, -1 do
      local mon = party[slot]
      if eligible(mon) then
        if healthy(mon) and healthyCount <= 1 then
          -- The final usable battler is never eligible for Rocket custody.
        else
          out[#out + 1] = { source = "party", slot = slot, mon = mon }
          if healthy(mon) then healthyCount = healthyCount - 1 end
          if #out >= maximum or #party - #out <= 1 then break end
        end
      end
    end
    if #out == 0 then return nil, "party_fallback_unavailable" end
    return out
  end

  local function levelSort(left, right)
    local ll = integer(left.mon and left.mon.level, 1, 100) or 1
    local rl = integer(right.mon and right.mon.level, 1, 100) or 1
    if ll ~= rl then return ll > rl end
    if left.source ~= right.source then return left.source < right.source end
    return tostring(left.id or left.box or "") .. ":" .. tostring(left.slot or "")
      < tostring(right.id or right.box or "") .. ":" .. tostring(right.slot or "")
  end

  local function hashText(text)
    local hash = 5381
    for index = 1, #text do hash = (hash * 33 + text:byte(index)) % 4294967291 end
    return ("ka67-%08x-%d"):format(hash, #text)
  end

  function R.scaleReceipt(game)
    local rows, counts = {}, { box = 0, legacy = 0, party = 0 }
    for _, sourceRows in ipairs({ localRows(game), legacyRows(game), partyRows(game) }) do
      for _, row in ipairs(sourceRows) do
        rows[#rows + 1] = row
        counts[row.source] = counts[row.source] + 1
      end
    end
    if #rows == 0 then return nil, "strength_evidence_absent" end
    table.sort(rows, levelSort)
    local total, top = 0, math.min(6, #rows)
    local parts = {}
    for index, row in ipairs(rows) do
      local level = integer(row.mon.level, 1, 100) or 1
      if index <= top then total = total + level end
      parts[#parts + 1] = table.concat({ row.source,
        tostring(row.id or row.box or ""), tostring(row.slot or ""),
        tostring(row.mon.species), tostring(level) }, ":")
    end
    local strongest = integer(rows[1].mon.level, 1, 100) or 1
    return {
      schema = "kanto-ascendant-rocket-scale/v1", version = 1,
      strongestLevel = strongest,
      topSixAverage = math.floor(total / top + 0.5),
      recommendedLevel = math.max(50, strongest),
      anchorSpecies = rows[1].mon.species,
      sourceCounts = counts, rosterCount = #rows,
      rosterHash = hashText(table.concat(parts, "|")),
    }
  end

  local function beginLegacy(game, maximum)
    local rows = legacyRows(game)
    table.sort(rows, levelSort)
    maximum = math.min(integer(maximum, 1, R.maxTargets) or R.maxTargets, #rows)
    if maximum < 1 then return false, "legacy_fallback_unavailable" end
    local root = state()
    root.sequence, root.status, root.source = root.sequence + 1,
      "prepared", "legacy"
    root.targets = {}
    local ids = {}
    for index = 1, maximum do
      ids[index] = rows[index].id
      root.targets[index] = { id = rows[index].id,
        pokemon = copy(rows[index].mon), slot = rows[index].slot }
    end
    saveState(root)
    if not flush(game) then saveState(emptyState())
      return false, "legacy_prepare_save_failed" end
    local mons, err = archive.leaseMons(game.save, ids)
    if not mons then saveState(emptyState()); flush(game); return false, err end
    root.status = "held"
    saveState(root)
    if not flush(game) then
      archive.releaseLeases(game.save, ids)
      saveState(emptyState())
      return false, "legacy_hold_save_failed"
    end
    return true, copy(root)
  end

  local function beginParty(game, maximum)
    local plan, err = R.planParty(game, maximum)
    if not plan then return false, err end
    local root = state()
    root.sequence, root.status, root.source = root.sequence + 1,
      "prepared", "party"
    root.targets = {}
    for index, row in ipairs(plan) do
      local id = ("KA67-RKT-P-%08d-%02d"):format(root.sequence, index)
      row.mon.__kaRocketCustodyId = id
      root.targets[index] = { id = id, slot = row.slot,
        pokemon = copy(row.mon) }
    end
    saveState(root)
    if not flush(game) then
      for _, row in ipairs(plan) do row.mon.__kaRocketCustodyId = nil end
      saveState(emptyState())
      return false, "party_prepare_save_failed"
    end
    table.sort(plan, function(a, b) return a.slot > b.slot end)
    for _, row in ipairs(plan) do table.remove(game.save.party, row.slot) end
    root.status = "held"
    saveState(root)
    if not flush(game) then
      table.sort(plan, function(a, b) return a.slot < b.slot end)
      for _, row in ipairs(plan) do
        row.mon.__kaRocketCustodyId = nil
        table.insert(game.save.party,
          math.max(1, math.min(row.slot, #game.save.party + 1)), row.mon)
      end
      saveState(emptyState())
      return false, "party_hold_save_failed"
    end
    return true, copy(root)
  end

  function R.begin(game, sourceId, maximum)
    if not R.unlocked(game) then return false, "eight_badges_required" end
    local root = state()
    if root.status ~= "empty" and root.status ~= "complete" then
      return false, "source_custody_already_active"
    end
    if sourceId == "box" then
      if not localCustody then return false, "local_custody_unavailable" end
      return localCustody.begin(game, maximum)
    elseif sourceId == "legacy" then
      return beginLegacy(game, maximum)
    elseif sourceId == "party" then
      return beginParty(game, maximum)
    end
    return false, "invalid_custody_source"
  end

  local function releaseLegacy(game, root)
    local ids = {}
    for index, target in ipairs(root.targets) do ids[index] = target.id end
    local ok, err = archive.releaseLeases(game.save, ids)
    if not ok then return false, err end
    return true
  end

  local function releaseParty(game, root)
    game.save.party = type(game.save.party) == "table" and game.save.party or {}
    game.save.boxes = type(game.save.boxes) == "table" and game.save.boxes or {}
    local partyFree = math.max(0, R.partyCapacity - #game.save.party)
    local boxFree = 0
    for _, box in ipairs(game.save.boxes) do
      if type(box) == "table" then boxFree = boxFree + math.max(0, 20 - #box) end
    end
    if partyFree + boxFree < #root.targets then
      return false, "party_and_boxes_full"
    end
    table.sort(root.targets, function(a, b) return a.slot < b.slot end)
    for _, target in ipairs(root.targets) do
      local mon = copy(target.pokemon)
      mon.__kaRocketCustodyId = nil
      if #game.save.party < R.partyCapacity then
        local slot = math.max(1, math.min(target.slot, #game.save.party + 1))
        table.insert(game.save.party, slot, mon)
      else
        local destination
        for _, box in ipairs(game.save.boxes) do
          if type(box) == "table" and #box < 20 then destination = box break end
        end
        if not destination then return false, "party_and_boxes_full" end
        destination[#destination + 1] = mon
      end
    end
    return true
  end

  function R.release(game, reason)
    local root = state(false)
    if root.status == "empty" or root.status == "complete" then
      if localCustody and type(localCustody.active) == "function"
          and localCustody.active() then
        return localCustody.release(game, reason)
      end
      return true
    end
    if root.status ~= "held" then return false, "source_custody_not_releasable" end
    local ok, err
    if root.source == "legacy" then ok, err = releaseLegacy(game, root)
    elseif root.source == "party" then ok, err = releaseParty(game, root)
    else return false, "unknown_custody_source" end
    if not ok then return false, err end
    root.status, root.reason, root.targets = "complete", reason, {}
    saveState(root)
    if not flush(game) then return false, "source_release_save_failed" end
    return true
  end

  local function stackLegacy(game, maximum, root)
    local rows = legacyRows(game)
    table.sort(rows, levelSort)
    maximum = math.min(integer(maximum, 1, R.maxTargets) or 1, #rows)
    if maximum < 1 then return false, "legacy_fallback_unavailable" end
    local ids, added = {}, {}
    for index = 1, maximum do
      ids[index] = rows[index].id
      added[index] = { id = rows[index].id,
        pokemon = copy(rows[index].mon), slot = rows[index].slot }
    end
    root.status = "stack_prepared"
    root.pendingTargets = added
    saveState(root)
    if not flush(game) then
      root.status, root.pendingTargets = "held", nil
      saveState(root)
      return false, "legacy_stack_prepare_save_failed"
    end
    local mons, err = archive.leaseMons(game.save, ids)
    if not mons then
      root.status, root.pendingTargets = "held", nil
      saveState(root); flush(game)
      return false, err
    end
    for _, target in ipairs(added) do root.targets[#root.targets + 1] = target end
    root.status, root.pendingTargets = "held", nil
    saveState(root)
    if not flush(game) then
      archive.releaseLeases(game.save, ids)
      for _ = 1, #added do table.remove(root.targets) end
      saveState(root)
      return false, "legacy_stack_hold_save_failed"
    end
    return true, copy(root)
  end

  local function stackParty(game, maximum, root)
    local plan, err = R.planParty(game, maximum)
    if not plan then return false, err end
    local added = {}
    root.sequence = root.sequence + 1
    for index, row in ipairs(plan) do
      local id = ("KA67-RKT-P-%08d-%02d"):format(root.sequence, index)
      row.mon.__kaRocketCustodyId = id
      added[index] = { id = id, slot = row.slot, pokemon = copy(row.mon) }
    end
    root.status, root.pendingTargets = "stack_prepared", added
    saveState(root)
    if not flush(game) then
      for _, row in ipairs(plan) do row.mon.__kaRocketCustodyId = nil end
      root.status, root.pendingTargets = "held", nil
      saveState(root)
      return false, "party_stack_prepare_save_failed"
    end
    table.sort(plan, function(a, b) return a.slot > b.slot end)
    for _, row in ipairs(plan) do table.remove(game.save.party, row.slot) end
    for _, target in ipairs(added) do root.targets[#root.targets + 1] = target end
    root.status, root.pendingTargets = "held", nil
    saveState(root)
    if not flush(game) then
      -- The prepared receipt may already be durable while the final held
      -- receipt failed.  Restore every removed party record in original slot
      -- order and remove only this tranche from the pre-existing custody set.
      table.sort(plan, function(a, b) return a.slot < b.slot end)
      for _, row in ipairs(plan) do
        row.mon.__kaRocketCustodyId = nil
        table.insert(game.save.party,
          math.max(1, math.min(row.slot, #game.save.party + 1)), row.mon)
      end
      for _ = 1, #added do table.remove(root.targets) end
      root.status, root.pendingTargets = "held", nil
      saveState(root)
      flush(game)
      return false, "party_stack_hold_save_failed"
    end
    return true, copy(root)
  end

  function R.stackLoss(game, sourceId, maximum)
    if sourceId == "box" then
      if not localCustody or type(localCustody.stackLoss) ~= "function" then
        return false, "local_custody_unavailable"
      end
      return localCustody.stackLoss(game, maximum)
    end
    local root = state(false)
    if root.status ~= "held" or root.source ~= sourceId then
      return false, "source_custody_not_held"
    end
    if sourceId == "legacy" then return stackLegacy(game, maximum, root) end
    if sourceId == "party" then return stackParty(game, maximum, root) end
    return false, "invalid_custody_source"
  end

  function R.status()
    return copy(state(false))
  end

  R.eligible = eligible
  return R
end
