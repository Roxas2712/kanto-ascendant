-- Crash-safe persistence adapter for the cross-edition Legacy Vault.
--
-- The engine owns the shared namespace and portable export directory. This
-- module only names three data keys inside that bound capability. Classification
-- is read-only; repair and promotion happen solely through explicit methods.

return function(opts)
  opts = opts or {}
  local Serializer = assert(opts.serializer,
    "Legacy Bank Store needs the engine SaveSerializer")
  local sha256 = assert(opts.sha256, "Legacy Bank Store needs SHA-256")
  local Vault = assert(opts.vault, "Legacy Bank Store needs the vault model")
  local now = opts.now or os.time

  local S = {
    VERSION = 1,
    KIND = "kanto-ascendant.legacy-bank-generation",
    KEYS = {
      main = "legacy-bank/v1/main",
      backup = "legacy-bank/v1/backup",
      staging = "legacy-bank/v1/staging",
    },
  }
  local allowedStates = { committed = true, prepared = true }
  local envelopeKeys = {
    kind = true, version = true, state = true, serial = true,
    createdAt = true, reason = true, vaultSha256 = true, vault = true,
  }

  local function copy(value)
    if value == nil then return nil end
    return assert(Serializer.decode(assert(Serializer.encode(value))))
  end

  local function digest(value)
    local ok, body = pcall(Serializer.encode, value)
    if not ok then return nil end
    return sha256(body)
  end

  local function integer(value)
    value = tonumber(value)
    return value and value >= 0 and value == math.floor(value) and value or nil
  end

  local function exactKeys(value, allowed)
    if type(value) ~= "table" then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
  end

  local function validateEnvelope(raw)
    if not exactKeys(raw, envelopeKeys) then return nil, "invalid_shape" end
    if raw.kind ~= S.KIND or raw.version ~= S.VERSION then
      return nil, "invalid_generation"
    end
    if not allowedStates[raw.state] then return nil, "invalid_state" end
    if not integer(raw.serial) then return nil, "invalid_serial" end
    local vault, vaultErr = Vault.normalize(raw.vault)
    if not vault then return nil, vaultErr end
    if raw.vaultSha256 ~= digest(vault) then return nil, "checksum_mismatch" end
    local out = copy(raw)
    out.vault = vault
    return out
  end

  local function requireShared(shared)
    for _, method in ipairs({ "read", "write", "delete",
        "exportPackage", "importPackage" }) do
      if type(shared and shared[method]) ~= "function" then
        return nil, "shared_storage_capability_missing"
      end
    end
    return shared
  end

  function S.new(shared)
    local valid, err = requireShared(shared)
    if not valid then return nil, err end
    local store = { shared = valid }

    local function readSlot(name)
      local key = S.KEYS[name]
      local raw, code = valid:read(key)
      if raw == nil then
        return { name = name, key = key, status = "absent", code = code }
      end
      local envelope, envelopeErr = validateEnvelope(raw)
      if not envelope then
        return { name = name, key = key, status = "invalid",
          reason = envelopeErr }
      end
      return { name = name, key = key, status = "valid",
        state = envelope.state, serial = envelope.serial,
        vaultSha256 = envelope.vaultSha256, envelope = envelope }
    end

    function store:classify()
      local report = {
        kind = "legacy_bank_generation_classification",
        main = readSlot("main"),
        backup = readSlot("backup"),
        staging = readSlot("staging"),
      }
      if report.main.status == "valid"
          and report.main.state == "committed" then
        report.authoritative = { source = "main", serial = report.main.serial }
      elseif report.backup.status == "valid"
          and report.backup.state == "committed" then
        report.recovery = { source = "backup", serial = report.backup.serial }
      else
        report.recovery = { source = nil, reason = "no_confirmed_generation" }
      end
      return report
    end

    function store:load()
      local report = self:classify()
      if report.authoritative then
        local candidate = report[report.authoritative.source]
        return copy(candidate.envelope.vault), {
          source = report.authoritative.source,
          serial = candidate.serial,
          vaultSha256 = candidate.vaultSha256,
          classification = report,
        }
      end
      local allAbsent = report.main.status == "absent"
        and report.backup.status == "absent"
        and report.staging.status == "absent"
      return nil, allAbsent and "vault_not_found"
        or report.recovery and report.recovery.reason or "vault_not_found", report
    end

    local function writeVerified(key, envelope)
      local written, writeCode, writeMessage = valid:write(key, envelope)
      if not written then return nil, writeCode, writeMessage end
      local readback = valid:read(key)
      local verified, verifyErr = validateEnvelope(readback)
      if not verified or digest(verified) ~= digest(envelope) then
        return nil, "readback_failed", verifyErr
      end
      return verified
    end

    function store:commit(vault, metadata)
      metadata = metadata or {}
      local normalized, normalizeErr = Vault.normalize(vault)
      if not normalized then return nil, normalizeErr end
      local report = self:classify()
      local maximum = 0
      for _, name in ipairs({ "main", "backup", "staging" }) do
        maximum = math.max(maximum, report[name].serial or 0)
      end
      local serial = maximum + 1
      local envelope = {
        kind = S.KIND,
        version = S.VERSION,
        state = "prepared",
        serial = serial,
        createdAt = now(),
        reason = type(metadata.reason) == "string" and metadata.reason or nil,
        vaultSha256 = assert(digest(normalized)),
        vault = copy(normalized),
      }
      local staged, stageCode = writeVerified(S.KEYS.staging, envelope)
      if not staged then return nil, "staging_write_failed", stageCode end

      if report.main.status == "valid"
          and report.main.state == "committed" then
        local backedUp, backupCode = writeVerified(S.KEYS.backup,
          report.main.envelope)
        if not backedUp then return nil, "backup_write_failed", backupCode end
      end

      local committed = copy(envelope)
      committed.state = "committed"
      local main, mainCode = writeVerified(S.KEYS.main, committed)
      if not main then return nil, "main_write_failed", mainCode end
      valid:delete(S.KEYS.staging)
      return {
        kind = "legacy_bank_commit_receipt",
        serial = serial,
        vaultId = normalized.vaultId,
        vaultSha256 = committed.vaultSha256,
        createdAt = committed.createdAt,
      }
    end

    function store:recover(report)
      report = report or self:classify()
      if report.authoritative then
        return { source = "main", serial = report.main.serial,
          status = "already_healthy" }
      end
      local source = report.recovery and report.recovery.source
      local candidate = source and report[source]
      if not candidate or candidate.status ~= "valid"
          or candidate.state ~= "committed" then
        return nil, "no_confirmed_generation"
      end
      local restored, restoreCode = writeVerified(S.KEYS.main,
        candidate.envelope)
      if not restored then return nil, "recovery_write_failed", restoreCode end
      valid:delete(S.KEYS.staging)
      return { source = source, serial = candidate.serial,
        vaultSha256 = candidate.vaultSha256, status = "recovered" }
    end

    function store:export(name, vault, context)
      local package, packageErr = Vault.exportPackage(vault, context)
      if not package then return nil, packageErr end
      local written, code, receipt = valid:exportPackage(name, package)
      if not written then return nil, code, receipt end
      receipt = copy(receipt or {})
      receipt.packageSha256 = package.manifest.payloadSha256
      receipt.vaultId = package.manifest.vaultId
      return receipt
    end

    function store:previewImport(name, vault)
      local package, code, message = valid:importPackage(name)
      if not package then return nil, code, message end
      return Vault.previewImport(vault, package)
    end

    function store:listPackages()
      if type(valid.listPackages) ~= "function" then
        return nil, "package_listing_unavailable"
      end
      local rows, code, message = valid:listPackages()
      if type(rows) ~= "table" then return nil, code, message end
      local out, seen = {}, {}
      for _, row in ipairs(rows) do
        local name = type(row) == "string" and row
          or type(row) == "table" and row.name or nil
        if type(name) == "string" and name ~= "" and not seen[name] then
          seen[name] = true
          out[#out + 1] = name
        end
      end
      table.sort(out)
      return out
    end

    return store
  end

  return S
end
