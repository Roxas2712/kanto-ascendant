-- Kanto Ascendant 6.7: crash-safe local-Box custody for Rocket raids.
--
-- This controller never reads or mutates the Shared Vault, Legacy Bank,
-- Party, Day Care or transfer surfaces.  It writes a durable prepared intent
-- before removing any eligible local-Box Pokemon and retains the complete
-- physical records until an exact-once return has been saved.

return function(mod, opts)
  opts = opts or {}
  local C = {
    schema = "kanto-ascendant-rocket-custody/v1",
    version = 1,
    stateKey = "rocket_recovery_custody_67",
    maxTargets = 6,
    maxHeld = 18,
    boxCapacity = 20,
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

  local function integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) then return nil end
    if minimum and value < minimum then return nil end
    if maximum and value > maximum then return nil end
    return value
  end

  local function emptyState()
    return {
      schema = C.schema, version = C.version, status = "empty",
      sequence = 0, targets = {}, pending = nil,
    }
  end

  local VALID_STATUS = {
    empty = true, prepared = true, held = true,
    return_prepared = true, recovery_pending = true, complete = true,
  }

  local function normalize(raw)
    if type(raw) ~= "table" or raw.schema ~= C.schema
        or raw.version ~= C.version then return emptyState() end
    local out = copy(raw)
    if not VALID_STATUS[out.status] then return emptyState() end
    out.sequence = integer(out.sequence, 0) or 0
    out.targets = type(out.targets) == "table" and out.targets or {}
    out.pending = type(out.pending) == "table" and out.pending or nil
    return out
  end

  local function state(create)
    local raw = mod.save:get(C.stateKey)
    local root = normalize(raw)
    if create ~= false and (type(raw) ~= "table"
        or raw.schema ~= C.schema or raw.version ~= C.version) then
      mod.save:set(C.stateKey, root)
    end
    return root
  end

  local function saveState(root)
    mod.save:set(C.stateKey, root)
    return root
  end

  local function flush(game)
    if not (game and type(game.writeSave) == "function") then return true end
    local ok, result = pcall(game.writeSave, game)
    return ok and result ~= false
  end

  local function boxes(game)
    local save = game and game.save
    if type(save) ~= "table" or type(save.boxes) ~= "table" then
      return nil, "local_boxes_unavailable"
    end
    for boxIndex, box in ipairs(save.boxes) do
      if type(box) ~= "table" or #box > C.boxCapacity then
        return nil, "local_boxes_invalid:" .. tostring(boxIndex)
      end
    end
    return save.boxes
  end

  local function itemId(mon)
    return type(mon) == "table" and (mon.heldItem or mon.item) or nil
  end

  local function hasMail(mon)
    if type(mon) ~= "table" then return false end
    if mon.mail ~= nil or mon.mailData ~= nil or mon.heldMail ~= nil then
      return true
    end
    local item = itemId(mon)
    return type(item) == "string" and item:upper():find("MAIL", 1, true) ~= nil
  end

  function C.eligible(mon)
    if type(mon) ~= "table" or type(mon.species) ~= "string"
        or mon.species == "" then return false, "invalid" end
    if mon.isEgg == true or mon.egg == true then return false, "egg" end
    if hasMail(mon) then return false, "mail" end
    if mon.__kaLegacyId ~= nil or mon.legacyImported == true
        or mon.legacyLease ~= nil then return false, "legacy" end
    if mon.questBound == true or mon.storyBound == true or mon.locked == true
        or mon.custody ~= nil or mon.__kaRocketCustodyId ~= nil then
      return false, "protected"
    end
    return true
  end

  local function stable(value, seen)
    local kind = type(value)
    if kind == "nil" then return "n" end
    if kind == "boolean" then return value and "t" or "f" end
    if kind == "number" or kind == "string" then
      return kind:sub(1, 1) .. tostring(value):gsub("([\\|:{}])", "\\%1")
    end
    if kind ~= "table" then return "x" .. kind end
    seen = seen or {}
    if seen[value] then return "cycle" end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do
      if key ~= "__kaRocketCustodyId" then keys[#keys + 1] = key end
    end
    table.sort(keys, function(left, right)
      return tostring(left) < tostring(right)
    end)
    local out = { "{" }
    for _, key in ipairs(keys) do
      out[#out + 1] = stable(key, seen) .. ":" .. stable(value[key], seen)
    end
    out[#out + 1] = "}"
    seen[value] = nil
    return table.concat(out, "|")
  end

  function C.fingerprint(mon)
    if type(mon) ~= "table" then return nil end
    return stable(mon)
  end

  function C.plan(game, maximum)
    local allBoxes, reason = boxes(game)
    if not allBoxes then return nil, reason end
    maximum = integer(maximum, 1, C.maxTargets) or C.maxTargets
    local rows = {}
    for boxIndex, box in ipairs(allBoxes) do
      for slotIndex, mon in ipairs(box) do
        local ok = C.eligible(mon)
        if ok then
          rows[#rows + 1] = {
            box = boxIndex, slot = slotIndex, mon = mon,
            level = integer(mon.level, 1) or 1,
            fingerprint = C.fingerprint(mon),
          }
        end
      end
    end
    table.sort(rows, function(left, right)
      if left.level ~= right.level then return left.level > right.level end
      if left.box ~= right.box then return left.box < right.box end
      return left.slot < right.slot
    end)
    while #rows > maximum do table.remove(rows) end
    if #rows == 0 then return nil, "eligible_box_pokemon_absent" end
    return rows
  end

  local function marker(sequence, ordinal, row)
    return ("KA67-RKT-%08d-%02d-%02d-%02d"):format(
      sequence, ordinal, row.box, row.slot)
  end

  function C.prepare(game, maximum)
    local root = state()
    if root.status == "prepared" then return true, copy(root) end
    if root.status == "held" or root.status == "return_prepared"
        or root.status == "recovery_pending" then
      return false, "custody_already_active"
    end
    local plan, reason = C.plan(game, maximum)
    if not plan then return false, reason end
    local before = copy(root)
    root.sequence = root.sequence + 1
    root.status, root.targets = "prepared", {}
    root.pending = { action = "hold", sequence = root.sequence }
    local marked = {}
    for ordinal, row in ipairs(plan) do
      local id = marker(root.sequence, ordinal, row)
      row.mon.__kaRocketCustodyId = id
      marked[#marked + 1] = row.mon
      root.targets[#root.targets + 1] = {
        id = id, source = { box = row.box, slot = row.slot },
        fingerprint = row.fingerprint, pokemon = copy(row.mon),
      }
    end
    saveState(root)
    if not flush(game) then
      for _, mon in ipairs(marked) do mon.__kaRocketCustodyId = nil end
      saveState(before)
      return false, "prepare_save_failed"
    end
    return true, copy(root)
  end

  function C.prepareAdditional(game, maximum)
    local root = state()
    if root.status ~= "held" then return false, "custody_not_held" end
    local available = C.maxHeld - #root.targets
    if available <= 0 then return false, "custody_limit_reached" end
    maximum = math.min(integer(maximum, 1, C.maxTargets) or C.maxTargets,
      available)
    local plan, reason = C.plan(game, maximum)
    if not plan then return false, reason end
    local previousCount = #root.targets
    root.sequence = root.sequence + 1
    root.status = "prepared"
    root.pending = {
      action = "stack", sequence = root.sequence,
      previousCount = previousCount,
    }
    local marked = {}
    for ordinal, row in ipairs(plan) do
      local id = marker(root.sequence, ordinal, row)
      row.mon.__kaRocketCustodyId = id
      marked[#marked + 1] = row.mon
      root.targets[#root.targets + 1] = {
        id = id, source = { box = row.box, slot = row.slot },
        fingerprint = row.fingerprint, pokemon = copy(row.mon),
      }
    end
    saveState(root)
    if not flush(game) then
      for _, mon in ipairs(marked) do mon.__kaRocketCustodyId = nil end
      while #root.targets > previousCount do table.remove(root.targets) end
      root.status, root.pending = "held", nil
      saveState(root)
      return false, "stack_prepare_save_failed"
    end
    return true, copy(root)
  end

  local function findMarker(allBoxes, id)
    for boxIndex, box in ipairs(allBoxes or {}) do
      for slotIndex, mon in ipairs(box) do
        if type(mon) == "table" and mon.__kaRocketCustodyId == id then
          return boxIndex, slotIndex, mon
        end
      end
    end
  end

  local function restoreRemoved(allBoxes, removed)
    table.sort(removed, function(left, right)
      if left.box ~= right.box then return left.box < right.box end
      return left.slot < right.slot
    end)
    for _, row in ipairs(removed) do
      local box = allBoxes[row.box]
      local slot = math.max(1, math.min(row.slot, #box + 1))
      table.insert(box, slot, row.mon)
    end
  end

  function C.commitHold(game)
    local root = state()
    if root.status == "held" then return true, copy(root) end
    if root.status ~= "prepared" or not (root.pending
        and (root.pending.action == "hold" or root.pending.action == "stack")) then
      return false, "hold_not_prepared"
    end
    local pendingAction = root.pending.action
    local previousCount = integer(root.pending.previousCount, 0) or 0
    local allBoxes, reason = boxes(game)
    if not allBoxes then return false, reason end
    local removals = {}
    for _, target in ipairs(root.targets) do
      local boxIndex, slotIndex, mon = findMarker(allBoxes, target.id)
      if boxIndex then
        removals[#removals + 1] = {
          box = boxIndex, slot = slotIndex, mon = mon,
        }
      end
    end
    table.sort(removals, function(left, right)
      if left.box ~= right.box then return left.box > right.box end
      return left.slot > right.slot
    end)
    for _, row in ipairs(removals) do table.remove(allBoxes[row.box], row.slot) end
    root.status, root.pending = "held", nil
    saveState(root)
    if not flush(game) then
      restoreRemoved(allBoxes, removals)
      if pendingAction == "stack" then
        while #root.targets > previousCount do table.remove(root.targets) end
        root.status, root.pending = "held", nil
      else
        root.status = "prepared"
        root.pending = { action = "hold", sequence = root.sequence }
      end
      saveState(root)
      return false, "hold_save_failed"
    end
    return true, copy(root)
  end

  function C.begin(game, maximum)
    local ok, result = C.prepare(game, maximum)
    if not ok then return false, result end
    return C.commitHold(game)
  end


  function C.stackLoss(game, maximum)
    local ok, result = C.prepareAdditional(game, maximum)
    if not ok then return false, result end
    return C.commitHold(game)
  end

  local function freeSlots(allBoxes)
    local count = 0
    for _, box in ipairs(allBoxes) do
      count = count + math.max(0, C.boxCapacity - #box)
    end
    return count
  end

  local function stripMarker(mon)
    mon = copy(mon)
    mon.__kaRocketCustodyId = nil
    return mon
  end

  function C.release(game, reason)
    local root = state()
    if root.status == "complete" or root.status == "empty" then
      return true, { returned = 0, status = root.status }
    end
    if root.status == "prepared" then
      local held, holdReason = C.commitHold(game)
      if not held then return false, holdReason end
      root = state()
    end
    if root.status ~= "held" and root.status ~= "recovery_pending"
        and root.status ~= "return_prepared" then
      return false, "custody_not_releasable"
    end
    local allBoxes, boxReason = boxes(game)
    if not allBoxes then return false, boxReason end
    if freeSlots(allBoxes) < #root.targets then
      root.status = "recovery_pending"
      root.pending = { action = "return", reason = reason or "capacity" }
      saveState(root)
      flush(game)
      return false, "local_boxes_full"
    end
    local heldTargets = copy(root.targets)
    root.status = "return_prepared"
    root.pending = { action = "return", reason = reason or "raid" }
    saveState(root)
    if not flush(game) then
      root.status, root.pending = "held", nil
      saveState(root)
      return false, "return_prepare_save_failed"
    end
    local inserted = {}
    for _, target in ipairs(root.targets) do
      -- A prepared-hold reload may still contain the marked physical record.
      -- Never add a second copy when reconciliation reaches return first.
      local existingBox = findMarker(allBoxes, target.id)
      if not existingBox then
        local destination
        local preferred = allBoxes[target.source.box]
        if preferred and #preferred < C.boxCapacity then destination = preferred end
        if not destination then
          for _, box in ipairs(allBoxes) do
            if #box < C.boxCapacity then destination = box break end
          end
        end
        local mon = stripMarker(target.pokemon)
        destination[#destination + 1] = mon
        inserted[#inserted + 1] = { box = destination, mon = mon }
      end
    end
    -- A return may reconcile a still-present prepared record instead of
    -- inserting a copy. Strip every transaction marker before the final
    -- durable write so a crash cannot leave a physically returned Pokemon
    -- looking as if Rocket still owns it.
    for _, box in ipairs(allBoxes) do
      for _, mon in ipairs(box) do
        if type(mon) == "table" and mon.__kaRocketCustodyId then
          mon.__kaRocketCustodyId = nil
        end
      end
    end
    root.status, root.pending = "complete", nil
    root.lastReturnReason = reason or "raid"
    root.returned = #root.targets
    root.targets = {}
    saveState(root)
    if not flush(game) then
      for index = #inserted, 1, -1 do
        local row = inserted[index]
        for slot = #row.box, 1, -1 do
          if row.box[slot] == row.mon then table.remove(row.box, slot) break end
        end
      end
      root.status = "held"
      root.pending = nil
      root.targets = heldTargets
      saveState(root)
      return false, "return_save_failed"
    end
    return true, { returned = root.returned, status = root.status }
  end

  function C.reconcile(game)
    local root = state()
    if root.status == "prepared" then return C.commitHold(game) end
    if root.status == "return_prepared" or root.status == "recovery_pending" then
      return C.release(game, root.pending and root.pending.reason or "reconcile")
    end
    return true, copy(root)
  end

  function C.active()
    local status = state(false).status
    return status == "prepared" or status == "held"
      or status == "return_prepared" or status == "recovery_pending"
  end

  function C.status()
    return copy(state(false))
  end

  return C
end
