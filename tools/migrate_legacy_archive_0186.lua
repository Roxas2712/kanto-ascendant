-- Offline companion for pre-0.1.86 Kanto Ascendant Legacy archives.
--
-- This is intentionally NOT mod code. It runs only while the app is stopped,
-- defaults to a read-only plan, and writes only after --apply plus the launch
-- wrapper's --app-stopped-confirmed token. The old archive is never changed or
-- deleted. All data is parsed by the engine's data-only SaveSerializer.

local Tool = {}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function validSegment(value)
  return type(value) == "string" and value ~= ""
    and value:match("^[%w_-]+$") ~= nil
end

local function editionSuffix(edition)
  return ({ red = "", blue = "_blue", yellow = "_yellow" })[edition]
end

local function archiveRelative(edition)
  return "kanto_ascendant/legacy/" .. edition .. ".lua"
end

local function encodePath(path)
  return tostring(path or ""):gsub("[^%w_-]", function(char)
    return "_" .. tostring(string.byte(char)) .. "_"
  end)
end

function Tool.storageKey(edition)
  return "legacy_lineage/files/" .. encodePath(archiveRelative(edition))
end

function Tool.targetRelative(edition, playthroughId)
  return table.concat({
    "mod_storage", edition, playthroughId, "kanto_ascendant",
    Tool.storageKey(edition) .. ".lua",
  }, "/")
end

function Tool.editionTargetRelative(edition)
  return table.concat({
    "mod_storage_edition", edition, "kanto_ascendant",
    "legacy/archive.lua",
  }, "/")
end

function Tool.allocationWitnessRelative(edition, scope)
  return "legacy_migration_state/stock_0186_" .. edition .. "_"
    .. scope .. ".lua"
end

local function dirname(path)
  return tostring(path):match("^(.*)/[^/]+$")
end

local function basename(path)
  return tostring(path):match("([^/]+)$") or tostring(path)
end

local function safeRelative(path)
  if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/"
      or path:find("\\", 1, true) or path:match("^[A-Za-z]:") then
    return false
  end
  for segment in path:gmatch("[^/]+") do
    if segment == ".." or segment == "." or segment == "" then return false end
  end
  return true
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function Tool.hostFs(root)
  assert(type(root) == "string" and root ~= "", "data root is required")
  local function full(path)
    assert(safeRelative(path), "unsafe relative path: " .. tostring(path))
    return root:gsub("/$", "") .. "/" .. path
  end
  local function mkdir(path)
    local dir = dirname(path)
    if not dir then return true end
    local ok = os.execute("/bin/mkdir -p " .. shellQuote(full(dir)))
    return ok == true or ok == 0
  end
  return {
    getInfo = function(path)
      local handle = io.open(full(path), "rb")
      if not handle then return nil end
      local size = handle:seek("end")
      handle:close()
      return { type = "file", size = size }
    end,
    read = function(path)
      local handle, err = io.open(full(path), "rb")
      if not handle then return nil, err end
      local body = handle:read("*a")
      handle:close()
      return body
    end,
    write = function(path, body)
      if not mkdir(path) then return false, "could not create parent directory" end
      local handle, err = io.open(full(path), "wb")
      if not handle then return false, err end
      local ok, writeErr = handle:write(body)
      local closeOk, closeErr = handle:close()
      if not ok then return false, writeErr end
      if closeOk == nil then return false, closeErr end
      return true
    end,
    remove = function(path)
      local ok, err = os.remove(full(path))
      if ok or err == nil then return true end
      return false, err
    end,
    createDirectory = function(path)
      local ok = os.execute("/bin/mkdir -p " .. shellQuote(full(path)))
      return ok == true or ok == 0
    end,
    fullPath = full,
  }
end

local function decode(serializer, body, label)
  if type(body) ~= "string" then return nil, label .. " is missing" end
  local value, err = serializer.decode(body)
  if not value then return nil, label .. " is invalid: " .. tostring(err) end
  return value
end

local function readDecoded(fs, serializer, path, label)
  local body, readErr = fs.read(path)
  if not body then return nil, nil, label .. " cannot be read: " .. tostring(readErr) end
  local value, decodeErr = decode(serializer, body, label)
  if not value then return nil, nil, decodeErr end
  return value, body
end

local function listContains(list, wanted)
  for _, value in ipairs(type(list) == "table" and list or {}) do
    if value == wanted then return true end
  end
  return false
end

local function selectedSave(opts, edition, requestedSlot)
  local registry = type(opts.saveSlots) == "table" and opts.saveSlots[edition]
  if type(registry) == "table" and type(registry.list) == "table"
      and #registry.list > 0 then
    local slot = requestedSlot or registry.active or registry.list[1]
    if not validSegment(slot) or not listContains(registry.list, slot) then
      return nil, nil, "requested/active slot is not in options.saveSlots"
    end
    return "saves/" .. edition .. "/" .. slot .. ".lua", slot
  end
  if requestedSlot then
    return nil, nil, "a slot was requested but this edition uses a flat save"
  end
  return "save" .. editionSuffix(edition) .. ".lua", "legacy"
end

local function loadSaveRecovery(fs, serializer, main, label)
  label = label or "target save"
  local errors = {}
  for _, path in ipairs({ main, main .. ".tmp", main .. ".bak" }) do
    if fs.getInfo(path) then
      local value, body, err = readDecoded(fs, serializer, path,
        label .. " " .. path)
      if value then return value, body, path end
      errors[#errors + 1] = err
    end
  end
  return nil, nil, nil, #errors > 0 and table.concat(errors, "; ")
    or "target save is missing"
end

local function resolvePlaythroughId(save, opts, edition, scope)
  local stamped = type(save.meta) == "table" and save.meta.playthroughId
  if stamped ~= nil and not validSegment(stamped) then
    return nil, "save contains an invalid playthroughId"
  end
  local byEdition = type(opts.playthroughIds) == "table"
    and opts.playthroughIds[edition]
  local mapped = type(byEdition) == "table" and byEdition[scope] or nil
  if mapped ~= nil and not validSegment(mapped) then
    return nil, "options contains an invalid playthroughId mapping"
  end
  if stamped and mapped and stamped ~= mapped then
    return nil, "save stamp and engine playthroughId mapping disagree"
  end
  local result = stamped or mapped
  return result
end

local function archiveNormalizer(factory, serializer, edition)
  local nullFs = {
    getInfo = function() return nil end,
    read = function() return nil end,
    write = function() return false, "read-only" end,
    createDirectory = function() return false end,
    remove = function() return false end,
  }
  return factory({
    edition = edition,
    modId = "kanto_ascendant",
    serializer = serializer,
    fs = nullFs,
    requireRegistryValidation = false,
  })
end

local function semanticBody(serializer, normalizer, body, label)
  local raw, decodeErr = decode(serializer, body, label)
  if not raw then return nil, decodeErr end
  local normalized, normalizeErr = normalizer.normalize(copy(raw))
  if not normalized then return nil, label .. " cannot normalize: " .. tostring(normalizeErr) end
  return serializer.encode(normalized), normalized
end

local function targetCandidate(serializer, normalizer, body, label)
  local wrapper, wrapperErr = decode(serializer, body, label)
  if not wrapper then return nil, wrapperErr end
  if math.floor(tonumber(wrapper.version) or 0) ~= 1
      or type(wrapper.body) ~= "string" then
    return nil, label .. " is not a v1 mod.storage wrapper"
  end
  local semantic, semanticErr = semanticBody(
    serializer, normalizer, wrapper.body, label .. " archive")
  if not semantic then return nil, semanticErr end
  return { wrapper = wrapper, semantic = semantic }
end


local function rawTargetCandidate(serializer, normalizer, body, label)
  local semantic, semanticErr = semanticBody(serializer, normalizer, body, label)
  if not semantic then return nil, semanticErr end
  return { semantic = semantic }
end

local function exactWrite(fs, path, body)
  local ok, err = fs.write(path, body)
  if not ok then return false, tostring(err) end
  local readback, readErr = fs.read(path)
  if readback ~= body then
    return false, "readback mismatch for " .. path .. ": " .. tostring(readErr)
  end
  return true
end

local function transactionalReplace(fs, path, body)
  local staged, stageErr = exactWrite(fs, path .. ".tmp", body)
  if not staged then return false, stageErr end
  if fs.getInfo(path) then
    local previous, previousErr = fs.read(path)
    if not previous then return false, "cannot back up " .. path .. ": "
      .. tostring(previousErr) end
    local backed, backupErr = exactWrite(fs, path .. ".bak", previous)
    if not backed then return false, backupErr end
  end
  local replaced, replaceErr = exactWrite(fs, path, body)
  if not replaced then return false, replaceErr end
  if fs.remove then fs.remove(path .. ".tmp") end
  return true
end

local localIdSequence = 0
local function compatiblePlaythroughId(now)
  localIdSequence = localIdSequence + 1
  local function word(value)
    return math.floor(tonumber(value) or 0) % 4294967296
  end
  local address = tostring({}):match("0x(%x+)") or "0"
  local addressLo = tonumber(address:sub(-8), 16) or 0
  local clock = math.floor((os.clock() or 0) * 1000000)
  return ("%08x%08x%08x%08x"):format(
    word(now or os.time()), word(clock), word(addressLo), word(localIdSequence))
end

local function backupOne(fs, source, target)
  if not source then return true end
  if not fs.getInfo(source) then return true end
  local body, err = fs.read(source)
  if not body then return false, "backup read failed for " .. source .. ": " .. tostring(err) end
  return exactWrite(fs, target, body)
end

local function backupSet(fs, backupDir, sourcePath, saveMain, targetMain,
    allocationWitness)
  local rows = {
    { sourcePath, "source_" .. basename(sourcePath) },
    { sourcePath .. ".tmp", "source_" .. basename(sourcePath) .. ".tmp" },
    { sourcePath .. ".bak", "source_" .. basename(sourcePath) .. ".bak" },
    { "options.lua", "options.lua" },
    { "options.lua.tmp", "options.lua.tmp" },
    { "options.lua.bak", "options.lua.bak" },
    { targetMain, "existing_target_storage.lua" },
    { targetMain .. ".tmp", "existing_target_storage.lua.tmp" },
    { targetMain .. ".bak", "existing_target_storage.lua.bak" },
    { allocationWitness, "allocation_witness.lua" },
  }
  if saveMain then
    rows[#rows + 1] = { saveMain, "target_save.lua" }
    rows[#rows + 1] = { saveMain .. ".tmp", "target_save.lua.tmp" }
    rows[#rows + 1] = { saveMain .. ".bak", "target_save.lua.bak" }
  end
  if fs.createDirectory and not fs.createDirectory(backupDir) then
    return false, "could not create backup directory " .. backupDir
  end
  local reservation = backupDir .. "/MIGRATION_BACKUP_RESERVED"
  if fs.getInfo(reservation) then
    return false, "backup directory already exists; refusing to overwrite "
      .. backupDir
  end
  local reserved, reserveErr = exactWrite(fs, reservation,
    "Kanto Ascendant Legacy migration backup\n")
  if not reserved then return false, reserveErr end
  for _, row in ipairs(rows) do
    local ok, err = backupOne(fs, row[1], backupDir .. "/" .. row[2])
    if not ok then return false, err end
  end
  return true
end


local function allocationSlotOk(opts, edition, scope, requestedSlot)
  local registry = type(opts.saveSlots) == "table" and opts.saveSlots[edition]
  if not requestedSlot or scope ~= requestedSlot then
    return false, "--allocate-id requires an explicit --slot"
  end
  if type(registry) ~= "table" or type(registry.list) ~= "table"
      or not listContains(registry.list, requestedSlot) then
    return false, "--allocate-id target is not a registered engine slot"
  end
  if registry.active ~= requestedSlot then
    return false, "--allocate-id requires --slot to equal the engine active slot"
  end
  return true
end


local function readAllocationWitness(fs, serializer, path, edition, scope,
    sourceDigest, saveDigest)
  local present, invalid = 0, 0
  local accepted
  for _, candidatePath in ipairs({ path, path .. ".tmp", path .. ".bak" }) do
    if fs.getInfo(candidatePath) then
      present = present + 1
      local witness = readDecoded(fs, serializer, candidatePath,
        "allocation witness " .. candidatePath)
      if not witness then
        invalid = invalid + 1
      else
        local valid = witness.version == 1 and witness.edition == edition
          and witness.scope == scope and witness.sourceDigest == sourceDigest
          and witness.saveDigest == saveDigest
          and type(witness.playthroughId) == "string"
          and #witness.playthroughId == 32
          and witness.playthroughId:match("^[0-9a-f]+$") ~= nil
        if not valid then
          return nil, "allocation witness contains a conflicting valid record"
        end
        if accepted and accepted.playthroughId ~= witness.playthroughId then
          return nil, "allocation witness generations disagree on playthroughId"
        end
        accepted = witness
      end
    end
  end
  if accepted then return accepted.playthroughId, nil, accepted end
  if present > 0 and invalid > 0 then
    return nil, "allocation witness has no valid recoverable generation"
  end
  return nil
end

local function fingerprint(deps, body)
  if deps.digest then return deps.digest(body) end
  -- Exact byte equality remains the acceptance criterion. This small fallback
  -- is only a human-readable deterministic receipt for minimal test runners.
  local a, b = 2166136261, 16777619
  for i = 1, #body do
    a = (a + body:byte(i) * b) % 4294967296
    b = (b * 33 + body:byte(i)) % 4294967296
  end
  return ("%08x%08x"):format(a, b)
end

local function classifyTargetGenerations(fs, serializer, normalizer,
    targetMain, targetScope, archiveBody, allowInvalidOnlyRecovery)
  local result = { present = 0, exact = 0, invalid = 0, conflicts = 0 }
  local invalidDetails = {}
  for _, path in ipairs({ targetMain, targetMain .. ".tmp", targetMain .. ".bak" }) do
    if fs.getInfo(path) then
      result.present = result.present + 1
      local body, readErr = fs.read(path)
      local candidate, candidateErr
      if body then
        if targetScope == "edition" then
          candidate, candidateErr = rawTargetCandidate(
            serializer, normalizer, body, "existing target " .. path)
        else
          candidate, candidateErr = targetCandidate(
            serializer, normalizer, body, "existing target " .. path)
        end
      else
        candidateErr = "cannot read existing target " .. path .. ": "
          .. tostring(readErr)
      end
      if not candidate then
        result.invalid = result.invalid + 1
        invalidDetails[#invalidDetails + 1] = tostring(candidateErr)
      elseif candidate.semantic == archiveBody then
        result.exact = result.exact + 1
      else
        result.conflicts = result.conflicts + 1
      end
    end
  end
  if result.conflicts > 0 then
    return nil,
      "existing target contains a different Legacy archive; refusing overwrite"
  end
  if result.present > 0 and result.exact == 0 then
    if not (allowInvalidOnlyRecovery and result.invalid == result.present) then
      return nil, "existing target has no valid recoverable generation: "
        .. table.concat(invalidDetails, "; ")
    end
    result.authorizedInvalidRecovery = true
  end
  return result
end

function Tool.run(options, deps)
  options, deps = options or {}, deps or {}
  local edition = tostring(options.edition or "red"):lower()
  if not editionSuffix(edition) then return nil, "edition must be red, blue or yellow" end
  local targetScope = tostring(options.targetScope or "playthrough"):lower()
  if targetScope ~= "playthrough" and targetScope ~= "edition" then
    return nil, "target scope must be playthrough or edition"
  end
  if not deps.serializer or not deps.archiveFactory then
    return nil, "serializer and archive factory are required"
  end
  local fs = deps.fs or Tool.hostFs(assert(options.root, "data root is required"))
  local serializer = deps.serializer
  local normalizer = archiveNormalizer(deps.archiveFactory, serializer, edition)

  local sourcePath = options.source or archiveRelative(edition)
  if not safeRelative(sourcePath) then return nil, "source must be relative to the data root" end
  local sourceBodies, normalized, sourceReadPath, sourceErrors = {}, nil, nil, {}
  for _, path in ipairs({ sourcePath, sourcePath .. ".tmp", sourcePath .. ".bak" }) do
    if fs.getInfo(path) then
      local body, readErr = fs.read(path)
      if not body then return nil, "legacy source cannot be read: " .. tostring(readErr) end
      sourceBodies[path] = body
      if not normalized then
        local decoded, decodeErr = decode(serializer, body, "legacy source " .. path)
        if decoded then
          local candidate, normalizeErr = normalizer.normalize(copy(decoded))
          if candidate then normalized, sourceReadPath = candidate, path
          else sourceErrors[#sourceErrors + 1] = tostring(normalizeErr) end
        else
          sourceErrors[#sourceErrors + 1] = tostring(decodeErr)
        end
      end
    end
  end
  if not normalized then
    return nil, #sourceErrors > 0 and table.concat(sourceErrors, "; ")
      or "legacy source archive is missing"
  end
  local archiveBody = serializer.encode(normalized)
  local archiveDigest, archiveDigestErr = normalizer.archiveDigest(normalized)
  if not archiveDigest then
    return nil, "legacy archive digest failed: " .. tostring(archiveDigestErr)
  end

  local opts, optionsBody, optionsReadPath, save, saveBody, saveMain, saveReadPath, scope
  local playthroughId, allocationWitness, allocationRecord, allocating = nil, nil, nil, false
  local allocationWitnessRecovered = false
  if targetScope == "playthrough" then
    local optionsErr
    opts, optionsBody, optionsReadPath, optionsErr = loadSaveRecovery(
      fs, serializer, "options.lua", "options")
    if not opts then return nil, optionsErr end
    local selectErr
    saveMain, scope, selectErr = selectedSave(opts, edition, options.slot)
    if not saveMain then return nil, selectErr end
    local saveErr
    save, saveBody, saveReadPath, saveErr = loadSaveRecovery(
      fs, serializer, saveMain)
    if not save then return nil, saveErr end
    if save.version ~= nil and save.version ~= edition then
      return nil, "selected save edition does not match requested edition"
    end
    local idErr
    playthroughId, idErr = resolvePlaythroughId(save, opts, edition, scope)
    if idErr then return nil, idErr end
    allocationWitness = Tool.allocationWitnessRelative(edition, scope)
    if not playthroughId then
      if options.allocateId ~= true then
        return nil, "no stamped or engine-mapped playthroughId; use explicit "
          .. "--slot matching the active slot plus --allocate-id"
      end
      local slotOk, slotErr = allocationSlotOk(opts, edition, scope, options.slot)
      if not slotOk then return nil, slotErr end
      local saveDigest = fingerprint(deps, saveBody)
      local witnessed, witnessErr, witness = readAllocationWitness(fs,
        serializer, allocationWitness, edition, scope, archiveDigest, saveDigest)
      if witnessErr then return nil, witnessErr end
      if witnessed then
        playthroughId, allocationRecord = witnessed, witness
        allocationWitnessRecovered = true
      elseif options.apply then
        local makeId = deps.newPlaythroughId
          or function() return compatiblePlaythroughId(deps.now and deps.now()) end
        playthroughId = makeId()
        if type(playthroughId) ~= "string" or #playthroughId ~= 32
            or playthroughId:match("^[0-9a-f]+$") == nil then
          return nil, "engine-compatible playthrough id allocation failed"
        end
        allocating = true
        allocationRecord = {
          version = 1, edition = edition, scope = scope,
          playthroughId = playthroughId, sourceDigest = archiveDigest,
          saveDigest = saveDigest,
        }
      else
        allocating = true
      end
    end
  else
    scope = "edition"
  end

  local wrapperBody = targetScope == "playthrough"
    and serializer.encode({ version = 1, body = archiveBody }) or archiveBody
  local targetMain = targetScope == "edition"
    and Tool.editionTargetRelative(edition)
    or (playthroughId and Tool.targetRelative(edition, playthroughId) or nil)

  local targetState = { present = 0, exact = 0, invalid = 0, conflicts = 0 }
  if targetMain then
    local targetErr
    targetState, targetErr = classifyTargetGenerations(fs, serializer,
      normalizer, targetMain, targetScope, archiveBody,
      targetScope == "playthrough" and allocationWitnessRecovered)
    if not targetState then return nil, targetErr end
  end

  local report = {
    mode = options.apply and "apply" or "dry-run",
    edition = edition,
    targetScope = targetScope,
    scope = scope,
    playthroughId = playthroughId or (allocating and "(allocate on apply)" or nil),
    allocated = allocating,
    source = sourcePath,
    sourceReadPath = sourceReadPath,
    save = saveMain,
    saveReadPath = saveReadPath,
    optionsReadPath = optionsReadPath,
    target = targetMain or "mod_storage/<new-id>/kanto_ascendant/" .. Tool.storageKey(edition),
    archiveDigest = archiveDigest,
    wrapperDigest = fingerprint(deps, wrapperBody),
    archiveBytes = #archiveBody,
    wrapperBytes = #wrapperBody,
    alreadyMigrated = targetState.exact > 0,
  }
  if not options.apply then return report end
  if options.appStoppedConfirmed ~= true then
    return nil, "--apply requires --app-stopped-confirmed from the PID guard"
  end

  local backupStamp = options.backupStamp
    or os.date("!%Y%m%dT%H%M%SZ", deps.now and deps.now() or os.time())
  local backupDir = "legacy_migration_backups/ka_0186_" .. backupStamp
  report.backup = backupDir
  local backupOk, backupErr = backupSet(
    fs, backupDir, sourcePath, saveMain, targetMain, allocationWitness)
  if not backupOk then
    return nil, backupErr .. "; source remains untouched; remove the incomplete "
      .. backupDir .. " only after inspection"
  end

  local function checkpoint(name)
    if deps.checkpoint and deps.checkpoint(name, report) == false then
      return false, "injected stop after " .. name .. "; retry --apply; backup "
        .. backupDir
    end
    return true
  end

  -- Allocate durably before naming any target storage.  A stop after this
  -- witness but before the first target byte is written must reuse the same
  -- engine-format id on retry; otherwise each attempt could strand another
  -- undiscoverable storage scope.  The source save/options remain untouched.
  local continueOk, continueErr
  if targetScope == "playthrough" and allocationRecord then
    local witnessOk, witnessErr = transactionalReplace(fs,
      allocationWitness, serializer.encode(allocationRecord))
    if not witnessOk then
      return nil, witnessErr .. "; no target progress was stamped; retry --apply; backup "
        .. backupDir
    end
    local witnessed, verifyErr = readAllocationWitness(fs, serializer,
      allocationWitness, edition, scope, archiveDigest,
      allocationRecord.saveDigest)
    if witnessed ~= playthroughId then
      return nil, tostring(verifyErr or "allocation witness readback mismatch")
        .. "; no target progress was stamped; restore only after inspecting "
        .. backupDir
    end
    continueOk, continueErr = checkpoint("allocation_witness")
    if not continueOk then return nil, continueErr end
  end

  -- Idempotent retry/heal. Even when one verified candidate already exists,
  -- finish the exact main+backup at-rest state under the witnessed identity.
  local stagedOk, stagedErr = exactWrite(fs, targetMain .. ".tmp", wrapperBody)
  if not stagedOk then
    return nil, stagedErr .. "; retry --apply after checking backup " .. backupDir
  end
  local mainOk, mainErr = exactWrite(fs, targetMain, wrapperBody)
  if not mainOk then
    return nil, mainErr .. "; valid .tmp is retained; retry --apply; backup "
      .. backupDir
  end
  local writtenBody, writtenReadErr = fs.read(targetMain)
  if not writtenBody then
    return nil, "written target cannot be read: " .. tostring(writtenReadErr)
      .. "; retry --apply; backup " .. backupDir
  end
  local mainCandidate, candidateErr
  if targetScope == "edition" then
    mainCandidate, candidateErr = rawTargetCandidate(serializer, normalizer,
      writtenBody, "written target")
  else
    mainCandidate, candidateErr = targetCandidate(serializer, normalizer,
      writtenBody, "written target")
  end
  if not mainCandidate or mainCandidate.semantic ~= archiveBody then
    return nil, (candidateErr or "semantic target readback mismatch")
      .. "; restore only from " .. backupDir .. " after inspection"
  end
  local bakOk, bakErr = exactWrite(fs, targetMain .. ".bak", wrapperBody)
  if not bakOk then
    return nil, bakErr .. "; verified main remains; retry --apply; backup " .. backupDir
  end
  if fs.remove then fs.remove(targetMain .. ".tmp") end

  continueOk, continueErr = checkpoint("target_storage_verified")
  if not continueOk then return nil, continueErr end

  if targetScope == "playthrough" then
    local stampedSave = copy(save)
    stampedSave.meta = type(stampedSave.meta) == "table" and stampedSave.meta or {}
    stampedSave.meta.playthroughId = playthroughId
    stampedSave.modData = type(stampedSave.modData) == "table"
      and stampedSave.modData or {}
    local modBucket = type(stampedSave.modData.kanto_ascendant) == "table"
      and stampedSave.modData.kanto_ascendant or {}
    stampedSave.modData.kanto_ascendant = modBucket
    modBucket.legacy_storage_binding = {
      version = 1,
      scope = "playthrough",
      playthroughId = playthroughId,
      archiveDigest = archiveDigest,
    }
    local saveOk, saveWriteErr = transactionalReplace(fs, saveMain,
      serializer.encode(stampedSave))
    if not saveOk then
      return nil, saveWriteErr .. "; target storage is verified; retry --apply; backup "
        .. backupDir
    end
    continueOk, continueErr = checkpoint("save_stamp")
    if not continueOk then return nil, continueErr end

    local stampedOptions = copy(opts)
    stampedOptions.playthroughIds = type(stampedOptions.playthroughIds) == "table"
      and stampedOptions.playthroughIds or {}
    stampedOptions.playthroughIds[edition] =
      type(stampedOptions.playthroughIds[edition]) == "table"
        and stampedOptions.playthroughIds[edition] or {}
    stampedOptions.playthroughIds[edition][scope] = playthroughId
    local optionsOk, optionsWriteErr = transactionalReplace(fs, "options.lua",
      serializer.encode(stampedOptions))
    if not optionsOk then
      return nil, optionsWriteErr .. "; save is stamped and target verified; "
        .. "retry --apply; backup " .. backupDir
    end
    continueOk, continueErr = checkpoint("options_mapping")
    if not continueOk then return nil, continueErr end

    local savedCheck, _, savedErr = readDecoded(fs, serializer, saveMain,
      "stamped target save")
    local optionsCheck, _, optsErr = readDecoded(fs, serializer, "options.lua",
      "stamped options")
    local mapped = optionsCheck and optionsCheck.playthroughIds
      and optionsCheck.playthroughIds[edition]
      and optionsCheck.playthroughIds[edition][scope]
    if not savedCheck or not savedCheck.meta
        or savedCheck.meta.playthroughId ~= playthroughId
        or not savedCheck.modData
        or not savedCheck.modData.kanto_ascendant
        or not savedCheck.modData.kanto_ascendant.legacy_storage_binding
        or savedCheck.modData.kanto_ascendant.legacy_storage_binding.version ~= 1
        or savedCheck.modData.kanto_ascendant.legacy_storage_binding.scope
          ~= "playthrough"
        or savedCheck.modData.kanto_ascendant.legacy_storage_binding.playthroughId
          ~= playthroughId
        or savedCheck.modData.kanto_ascendant.legacy_storage_binding.archiveDigest
          ~= archiveDigest
        or not optionsCheck or mapped ~= playthroughId then
      return nil, tostring(savedErr or optsErr or "save/options identity readback mismatch")
        .. "; restore from " .. backupDir .. " after inspection"
    end
  end

  for path, before in pairs(sourceBodies) do
    local after = fs.read(path)
    if after ~= before then
      return nil, "source archive changed unexpectedly; restore from "
        .. backupDir .. " and stop"
    end
  end
  report.applied = true
  report.alreadyMigrated = targetState.present > 0
  return report
end

local function parseArgs(argv)
  local out = { edition = "red", apply = false }
  local index = 1
  while index <= #argv do
    local value = argv[index]
    if value == "--apply" then out.apply = true
    elseif value == "--dry-run" then out.apply = false
    elseif value == "--allocate-id" then out.allocateId = true
    elseif value == "--app-stopped-confirmed" then out.appStoppedConfirmed = true
    elseif value == "--root" or value == "--edition" or value == "--slot"
        or value == "--source" or value == "--engine" or value == "--mod-root"
        or value == "--target-scope" then
      index = index + 1
      if not argv[index] then return nil, value .. " needs a value" end
      local key = ({
        ["--root"] = "root", ["--edition"] = "edition", ["--slot"] = "slot",
        ["--source"] = "source", ["--engine"] = "engine",
        ["--mod-root"] = "modRoot",
        ["--target-scope"] = "targetScope",
      })[value]
      out[key] = argv[index]
    elseif value == "--help" or value == "-h" then out.help = true
    else return nil, "unknown argument " .. tostring(value) end
    index = index + 1
  end
  return out
end

local function usage()
  return [[
Usage: migrate_legacy_archive_0186.lua --root DATA_DIR [options]
  --edition red|blue|yellow   default: red
  --slot slotN               otherwise engine active slot / flat save
  --source RELATIVE_PATH     default: kanto_ascendant/legacy/<edition>.lua
  --target-scope playthrough|edition
                             default: playthrough; edition writes raw archive
  --allocate-id              only with explicit active --slot; apply first
                             witnesses the id, then verifies target storage,
                             then stamps save + options
  --engine ENGINE_DIR        extracted exact 0.1.86 engine source
  --mod-root MOD_DIR         Kanto Ascendant directory
  --dry-run                  default; no writes
  --apply --app-stopped-confirmed
                             explicit write mode (wrapper supplies confirmation)
]]
end

function Tool.cli(argv)
  local options, parseErr = parseArgs(argv)
  if not options then io.stderr:write("ERROR: " .. parseErr .. "\n"); return 2 end
  if options.help then io.write(usage()); return 0 end
  if not options.root then
    io.stderr:write("ERROR: --root is required\n" .. usage()); return 2
  end
  local engine = options.engine or os.getenv("GEN1RECOMP_DIR")
  local modRoot = options.modRoot or os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
  if not engine then
    io.stderr:write("ERROR: --engine or GEN1RECOMP_DIR is required\n"); return 2
  end
  package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
  local serializer = require("src.core.SaveSerializer")
  local SaveData = require("src.core.SaveData")
  local fingerprintModule = require("src.link.Fingerprint")
  local factory, loadErr = loadfile(modRoot .. "/legacy_archive.lua")
  if not factory then io.stderr:write("ERROR: " .. tostring(loadErr) .. "\n"); return 2 end
  local report, runErr = Tool.run(options, {
    serializer = serializer,
    archiveFactory = assert(factory()),
    digest = fingerprintModule.digest,
    newPlaythroughId = SaveData.newPlaythroughId,
  })
  if not report then
    io.stderr:write("MIGRATION REFUSED: " .. tostring(runErr) .. "\n")
    return 1
  end
  io.write((report.applied and "APPLIED" or report.mode:upper()) .. "\n")
  io.write("edition/scope: " .. report.edition .. "/" .. report.scope .. "\n")
  if report.playthroughId then
    io.write("playthroughId: " .. report.playthroughId .. "\n")
  end
  io.write("source: " .. report.source .. "\n")
  if report.saveReadPath then io.write("save: " .. report.saveReadPath .. "\n") end
  io.write("target: " .. report.target .. "\n")
  io.write("archive digest: " .. report.archiveDigest .. "\n")
  io.write("wrapper digest: " .. report.wrapperDigest .. "\n")
  if report.backup then io.write("backup: " .. report.backup .. "\n") end
  if not report.applied then
    io.write("No files changed. Re-run through the .command with --apply.\n")
  else
    io.write("Verified target main+backup; source archive was not changed.\n")
  end
  return 0
end

if type(arg) == "table" and type(arg[0]) == "string"
    and arg[0]:match("migrate_legacy_archive_0186%.lua$") then
  os.exit(Tool.cli(arg))
end

return Tool
