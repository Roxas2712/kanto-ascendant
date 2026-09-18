-- Kanto Ascendant 6.6 selected offline Gift Code segment.
--
-- Runtime authority is a public SHA-256 catalog. Plaintext exists only long
-- enough to normalize and hash one player entry; it is never kept
-- in save/archive state, provenance, logs or exported controller data.

return function(mod, opts)
  opts = opts or {}
  local catalog = assert(opts.catalog, "Gift Code catalog missing")
  local eventArchive = assert(opts.eventArchive, "Event Archive missing")
  local sharedArchive = opts.sharedArchive
  local i18n = opts.i18n
  local G = {
    CARD_ID = "KASC-66-GIFT-CODE-MIGRATION",
    OWNER = "kasc.gifts.offline-digest-redemption/v1",
    OPTION_KEY = "gift_codes_enabled",
    VERSION = "1.0.0",
    game = nil,
  }

  local CATALOG_SCHEMA = "ka-offline-gift-code-catalog/v1"
  local LEDGER_VERSION = 1
  local RECEIPT_VERSION = 1
  local ATTEMPT_GUARD_VERSION = 1
  local CODE_LENGTH = 8
  local MAX_EVENT_DIGESTS = 3000
  local MAX_CAMPAIGN_DIGESTS = 102000
  local ATTEMPT_INTERVAL_SECONDS = 2
  local FAILURE_WINDOW_SECONDS = 10 * 60
  local FAILURE_LIMIT = 5
  local COOLDOWN_SECONDS = 15 * 60
  -- Eight symbols provide 31^8 possible values. Ambiguous 0/O and 1/I/L are
  -- excluded; the persistent attempt guard below is part of this shorter-code
  -- security boundary.
  local ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
  local values = {}
  for index = 1, #ALPHABET do
    values[ALPHABET:sub(index, index)] = index - 1
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do
      out[copy(key, seen)] = copy(item, seen)
    end
    return out
  end

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  local function enabled()
    if type(opts.enabled) == "function" then
      local ok, value = pcall(opts.enabled)
      return ok and value ~= false
    end
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, G.OPTION_KEY)
      return not ok or value ~= false
    end
    return true
  end

  function G.enabled()
    return enabled()
  end

  if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
    opts.supportLog.registerSegment({
      segmentId = G.CARD_ID, cardId = G.CARD_ID, version = G.VERSION,
      schema = "kasc.optional-feature-card/v1", owner = G.OWNER,
      active = enabled(), dependencyStatus = "local-reviewed",
      providerStatus = enabled() and "runtime-loaded" or "cold-disabled",
      buildReceiptId = "docs/GIFT_CODE_MIGRATION_66.md",
      rollbackReceiptId = "revert-card-commit",
    })
  end

  local function localized(value)
    if type(value) ~= "table" then return value end
    if i18n and i18n.isGerman and i18n.isGerman() then
      return value.de or value.en
    end
    return value.en or value.de
  end

  local function digestShape(value)
    return type(value) == "string" and #value == 64
      and value:match("^[0-9a-f]+$") ~= nil
  end

  local function identifier(value)
    return type(value) == "string" and #value >= 1 and #value <= 96
      and value:match("^[a-z0-9][a-z0-9_.-]*$") ~= nil
  end

  function G.normalize(raw)
    if type(raw) ~= "string" then return nil, "type" end
    local chars = {}
    raw = raw:upper()
    for index = 1, #raw do
      local char = raw:sub(index, index)
      if values[char] ~= nil then
        chars[#chars + 1] = char
      elseif char == "-" or char == "_" or char:match("%s") then
        -- Display separators and pasted whitespace are presentation only.
      else
        return nil, "characters"
      end
    end
    local normalized = table.concat(chars)
    if #normalized ~= CODE_LENGTH then return nil, "length" end
    return normalized
  end

  function G.format(normalized)
    if type(normalized) ~= "string" then return "" end
    local groups = {}
    local index = 1
    while #normalized - index + 1 > 5 do
      groups[#groups + 1] = normalized:sub(index, index + 3)
      index = index + 4
    end
    groups[#groups + 1] = normalized:sub(index)
    return table.concat(groups, "-")
  end

  local function defaultSha256(body)
    if not (love and love.data and type(love.data.hash) == "function"
        and type(love.data.encode) == "function") then
      return nil, "SHA-256 is unavailable"
    end
    local ok, digest = pcall(love.data.hash, "sha256", body)
    if not ok then return nil, "SHA-256 is unavailable" end
    if type(digest) == "userdata" and digest.getString then
      digest = digest:getString()
    end
    local encoded, hex = pcall(love.data.encode, "string", "hex", digest)
    if not encoded or type(hex) ~= "string" then
      return nil, "SHA-256 encoding is unavailable"
    end
    hex = hex:lower()
    if not digestShape(hex) then return nil, "invalid SHA-256 result" end
    return hex
  end
  local sha256 = opts.sha256 or defaultSha256
  local now = opts.now or function() return os.time() end

  local function sameReceipt(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for _, key in ipairs({ "digest", "campaignId", "buildId", "eventId",
        "profileId" }) do
      if left[key] ~= right[key] then return false end
    end
    return true
  end

  local function validReceipt(value, digest)
    return type(value) == "table"
      and value.version == RECEIPT_VERSION
      and digestShape(value.digest)
      and (digest == nil or value.digest == digest)
      and identifier(value.campaignId)
      and type(value.buildId) == "string" and #value.buildId > 0
      and #value.buildId <= 128
      and identifier(value.eventId)
      and identifier(value.profileId)
  end

  local function publicReceipt(value, digest)
    if not validReceipt(value, digest) then return nil end
    return {
      version = RECEIPT_VERSION,
      digest = value.digest,
      campaignId = value.campaignId,
      buildId = value.buildId,
      eventId = value.eventId,
      profileId = value.profileId,
    }
  end

  local digestIndex = {}
  local activeCampaigns = 0
  local catalogValid, catalogProblem = true, nil

  local function reject(reason)
    catalogValid, catalogProblem = false, reason
    digestIndex, activeCampaigns = {}, 0
    return false
  end

  local function validateCatalog()
    if type(catalog) ~= "table" or catalog.schema ~= CATALOG_SCHEMA
        or catalog.version ~= 1 or type(catalog.campaigns) ~= "table" then
      return reject("unsupported Gift Code catalog schema")
    end
    local seenCampaigns = {}
    for _, campaign in ipairs(catalog.campaigns) do
      if type(campaign) ~= "table" or campaign.version ~= 1
          or not identifier(campaign.id)
          or type(campaign.buildId) ~= "string" or #campaign.buildId == 0
          or #campaign.buildId > 128
          or type(campaign.events) ~= "table" or #campaign.events == 0 then
        return reject("invalid Gift Code campaign record")
      end
      if seenCampaigns[campaign.id] then
        return reject("duplicate Gift Code campaign id")
      end
      seenCampaigns[campaign.id] = true
      if campaign.testOnly == true and opts.allowTestFixtures ~= true then
        return reject("test-only Gift Code campaign in shipping catalog")
      end
      if campaign.status ~= "active" and campaign.status ~= "disabled" then
        return reject("invalid Gift Code campaign status")
      end
      local campaignDigests, seenEvents = 0, {}
      for _, event in ipairs(campaign.events) do
        if type(event) ~= "table" or event.version ~= 1
            or not identifier(event.id) or not identifier(event.profileId)
            or type(event.digests) ~= "table"
            or #event.digests < 1 or #event.digests > MAX_EVENT_DIGESTS
            or not eventArchive.profile(event.profileId) then
          return reject("invalid Gift Code event record")
        end
        if seenEvents[event.id] then return reject("duplicate Gift Code event id") end
        seenEvents[event.id] = true
        for _, digest in ipairs(event.digests) do
          if not digestShape(digest) or digestIndex[digest] then
            return reject("invalid or duplicate Gift Code digest")
          end
          campaignDigests = campaignDigests + 1
          if campaign.status == "active" then
            digestIndex[digest] = {
              version = RECEIPT_VERSION,
              digest = digest,
              campaignId = campaign.id,
              buildId = campaign.buildId,
              eventId = event.id,
              profileId = event.profileId,
            }
          end
        end
      end
      local fixtureAllowed = campaign.testOnly == true
        and opts.allowTestFixtures == true
      if not fixtureAllowed and (campaignDigests < 1
          or campaignDigests > MAX_CAMPAIGN_DIGESTS) then
        return reject("Gift Code campaign digest count is outside the runtime limit")
      end
      if campaign.status == "active" then activeCampaigns = activeCampaigns + 1 end
    end
    return true
  end
  validateCatalog()

  local function timestamp(value)
    return type(value) == "number" and value == value and value >= 0
      and value == math.floor(value) and value <= 9999999999
  end

  local function freshAttemptGuard()
    return {
      version = ATTEMPT_GUARD_VERSION,
      failures = 0,
      windowStart = 0,
      lastAttemptAt = 0,
      cooldownUntil = 0,
    }
  end

  local function normalizeAttemptGuard(value)
    if value == nil then return freshAttemptGuard() end
    if type(value) ~= "table" or value.version ~= ATTEMPT_GUARD_VERSION
        or not timestamp(value.failures) or value.failures > FAILURE_LIMIT
        or not timestamp(value.windowStart)
        or not timestamp(value.lastAttemptAt)
        or not timestamp(value.cooldownUntil) then
      return nil, "corrupt Gift Code attempt guard"
    end
    return {
      version = ATTEMPT_GUARD_VERSION,
      failures = value.failures,
      windowStart = value.windowStart,
      lastAttemptAt = value.lastAttemptAt,
      cooldownUntil = value.cooldownUntil,
    }
  end

  local function normalizeLedger(value)
    if value == nil then
      return { version = LEDGER_VERSION, claimed = {}, pending = {},
        unsynced = {}, attemptGuard = freshAttemptGuard() }
    end
    if type(value) ~= "table" or value.version ~= LEDGER_VERSION
        or type(value.claimed) ~= "table" then
      return nil, "unsupported Gift Code ledger"
    end
    local guard, guardErr = normalizeAttemptGuard(value.attemptGuard)
    if not guard then return nil, guardErr end
    local normalized = { version = LEDGER_VERSION, claimed = {}, pending = {},
      unsynced = {}, attemptGuard = guard }
    local pending = type(value.pending) == "table" and value.pending or {}
    local unsynced = type(value.unsynced) == "table" and value.unsynced or {}
    for index, bucket in ipairs({ value.claimed, pending, unsynced }) do
      local destination = ({ normalized.claimed, normalized.pending,
        normalized.unsynced })[index]
      for digest, receipt in pairs(bucket) do
        local clean = publicReceipt(receipt, digest)
        if not digestShape(digest) or not clean then
          return nil, "corrupt Gift Code ledger"
        end
        destination[digest] = clean
      end
    end
    if value.pendingReceipt ~= nil then
      local pendingDigest = type(value.pendingReceipt) == "table"
        and value.pendingReceipt.digest or nil
      normalized.pendingReceipt = publicReceipt(value.pendingReceipt,
        pendingDigest)
      if not normalized.pendingReceipt then
        return nil, "corrupt pending Gift Code"
      end
    end
    return normalized
  end

  local function localState()
    local root = eventArchive.state()
    if type(root) ~= "table" then return nil, nil, "Event Archive is unavailable" end
    local ledger, err = normalizeLedger(root.giftCodes)
    if not ledger then return nil, nil, err end
    -- Save-local pending is intentionally singular. Multiple accepted codes
    -- cannot accumulate behind a full Team and PC.
    if next(ledger.pending) then
      local first
      for digest, receipt in pairs(ledger.pending) do
        if first then return nil, nil, "multiple pending Gift Codes" end
        first = { digest = digest, receipt = receipt }
      end
      ledger.pendingReceipt = first.receipt
      ledger.pending = nil
    elseif ledger.pendingReceipt ~= nil then
      if not validReceipt(ledger.pendingReceipt) then
        return nil, nil, "corrupt pending Gift Code"
      end
      ledger.pending = nil
    else
      ledger.pending = nil
    end
    root.giftCodes = ledger
    return root, ledger
  end

  local function persistLocal(root, game)
    local ok, result = pcall(eventArchive.persist, root)
    if not ok or result == false then return false end
    -- Redemption is a transaction, not ordinary deferred mod state. Flush the
    -- pending/claimed journal together with the current Party/PC snapshot so a
    -- hard reload can only observe the state before or after each boundary.
    if not (game and type(game.writeSave) == "function") then return false end
    local saved, saveResult = pcall(game.writeSave, game)
    return saved and saveResult ~= false
  end

  local function sharedEnabled()
    if type(sharedArchive) ~= "table" then return false end
    if type(sharedArchive.storageHasArchive) ~= "function" then return true end
    local ok, available = pcall(sharedArchive.storageHasArchive)
    if not ok then return nil, "shared archive availability check failed" end
    return available == true
  end

  local function sharedState()
    local enabled, enabledErr = sharedEnabled()
    if enabled == nil then return nil, nil, enabledErr end
    if not enabled then return nil, nil, "local" end
    local ok, root, loadErr = pcall(sharedArchive.load)
    if not ok or type(root) ~= "table" or sharedArchive.readOnly == true then
      return nil, nil, loadErr or root or "shared archive unavailable"
    end
    root = copy(root)
    local ledger, err = normalizeLedger(root.giftCodes)
    if not ledger then return nil, nil, err end
    -- Shared pending is a digest map; it may contain reservations originating
    -- from different saves attached to the same archive.
    if ledger.pendingReceipt ~= nil then
      if not validReceipt(ledger.pendingReceipt) then
        return nil, nil, "corrupt shared Gift Code journal"
      end
      ledger.pending[ledger.pendingReceipt.digest] = ledger.pendingReceipt
      ledger.pendingReceipt = nil
    end
    root.giftCodes = ledger
    return root, ledger
  end

  local function writeShared(root)
    local ok, written, err = pcall(sharedArchive.write, root)
    if not ok or written ~= true then return false, err or written end
    return true
  end

  local function sharedStatus(digest)
    local root, ledger, err = sharedState()
    if not root then
      if err == "local" then return "local" end
      return nil, err
    end
    if ledger.claimed[digest] then return "claimed", ledger.claimed[digest] end
    if ledger.pending[digest] then return "pending", ledger.pending[digest] end
    return "ready"
  end

  local function reserveShared(receipt)
    local root, ledger, err = sharedState()
    if not root then
      if err == "local" then return true, "local" end
      return false, err
    end
    local claimed = ledger.claimed[receipt.digest]
    if claimed then return false, "claimed", claimed end
    local pending = ledger.pending[receipt.digest]
    if pending then
      if not sameReceipt(pending, receipt) then return false, "receipt mismatch" end
      return true, "pending", pending
    end
    ledger.pending[receipt.digest] = copy(receipt)
    local written, writeErr = writeShared(root)
    if not written then return false, writeErr end
    return true, "reserved"
  end

  local function commitShared(receipt)
    local root, ledger, err = sharedState()
    if not root then
      if err == "local" then return true, "local" end
      return false, err
    end
    local claimed = ledger.claimed[receipt.digest]
    if claimed and not sameReceipt(claimed, receipt) then
      return false, "receipt mismatch"
    end
    ledger.claimed[receipt.digest] = copy(receipt)
    ledger.pending[receipt.digest] = nil
    local written, writeErr = writeShared(root)
    if not written then return false, writeErr end
    return true, "claimed"
  end

  local function outcome(status, message)
    return { status = status, message = message }
  end

  local function disabledOutcome()
    return outcome("disabled", tr(
      "Gift Codes are disabled\nin Ascendant settings.\fExisting receipts and\nreserved gifts are retained.",
      "Geschenkcodes sind in den\nAscendant-Einstellungen aus.\fBelege und reservierte\nPreise bleiben erhalten."))
  end

  local function unavailableProfileOutcome()
    return outcome("config_error", tr(
      "This Gift Code prize\nis incomplete in this build.\fThe code was not claimed.",
      "Dieser Code-Preis ist\nin diesem Build unvollständig.\fDer Code wurde nicht eingelöst."))
  end

  local function validationMessage(reason)
    if reason == "characters" then
      return tr(
        "This Gift Code has\nunsupported characters.\fUse the code letters\nand numbers only.",
        "Dieser Geschenkcode\nhat ungültige Zeichen.\fNutze nur die Zeichen\ndes Codes.")
    elseif reason == "length" or reason == "type" then
      return tr(
        "This Gift Code has\nthe wrong length.\fEnter all 8 code\ncharacters.",
        "Dieser Geschenkcode\nhat die falsche Länge.\fGib alle 8\nCodezeichen ein.")
    end
    return tr(
      "This Gift Code could\nnot be checked.\fTry the entry again.",
      "Dieser Geschenkcode\nkonnte nicht geprüft werden.\fVersuche die Eingabe\nerneut.")
  end

  local function stateErrorOutcome()
    return outcome("state_error", tr(
      "Gift Code save data is\nunavailable.\fNothing was claimed.",
      "Die Geschenkcode-Daten\nsind nicht verfügbar.\fNichts wurde eingelöst."))
  end

  local function cooldownOutcome()
    return outcome("cooldown", tr(
      "Too many failed Gift\nCode attempts.\fWait 15 minutes before\ntrying another code.",
      "Zu viele ungültige\nGeschenkcode-Versuche.\fWarte 15 Minuten vor\ndem nächsten Versuch."))
  end

  local function currentTime()
    local ok, value = pcall(now)
    if not ok or not timestamp(value) then return nil end
    return value
  end

  local function persistAttemptGuard(root, game)
    if persistLocal(root, game) then return true end
    return false, stateErrorOutcome()
  end

  local function beginAttempt(root, ledger, game)
    local value = currentTime()
    if value == nil then
      return nil, outcome("rate_error", tr(
        "Gift Code attempt timing\nis unavailable.\fNothing was claimed.",
        "Die Zeitprüfung für\nGeschenkcodes fehlt.\fNichts wurde eingelöst."))
    end
    local guard = ledger.attemptGuard
    if guard.lastAttemptAt > value then
      -- A wall-clock rollback must not erase the failed-attempt boundary.
      guard.cooldownUntil = math.max(guard.cooldownUntil,
        guard.lastAttemptAt + COOLDOWN_SECONDS)
      local saved, saveFailure = persistAttemptGuard(root, game)
      if not saved then return nil, saveFailure end
      return nil, cooldownOutcome()
    end
    if guard.cooldownUntil > value then return nil, cooldownOutcome() end
    if guard.cooldownUntil ~= 0 then
      guard.cooldownUntil, guard.failures, guard.windowStart = 0, 0, 0
    end
    if guard.lastAttemptAt > 0
        and value - guard.lastAttemptAt < ATTEMPT_INTERVAL_SECONDS then
      return nil, outcome("rate_limited", tr(
        "Please wait before\nchecking another code.",
        "Bitte warte vor der\nnächsten Code-Prüfung."))
    end
    return value
  end

  local function recordFailedAttempt(root, ledger, game, value)
    local guard = ledger.attemptGuard
    if guard.windowStart == 0 or value < guard.windowStart
        or value - guard.windowStart >= FAILURE_WINDOW_SECONDS then
      guard.windowStart, guard.failures = value, 0
    end
    guard.lastAttemptAt = value
    guard.failures = guard.failures + 1
    local locked = guard.failures >= FAILURE_LIMIT
    if locked then guard.cooldownUntil = value + COOLDOWN_SECONDS end
    local saved, saveFailure = persistAttemptGuard(root, game)
    if not saved then return saveFailure end
    if locked then return cooldownOutcome() end
  end

  local function recordAcceptedAttempt(root, ledger, game, value)
    local guard = ledger.attemptGuard
    guard.lastAttemptAt = value
    guard.failures, guard.windowStart, guard.cooldownUntil = 0, 0, 0
    local saved, saveFailure = persistAttemptGuard(root, game)
    return saved, saveFailure
  end

  local function profileName(receipt)
    local profile = eventArchive.profile(receipt.profileId)
    -- Delivery and recovery messages must not reveal an unhatched gift's
    -- species, form or shiny status. Keep the actual profile untouched.
    if profile and profile.deliveryKind == "egg" then
      return tr("Gift Egg", "Geschenk-Ei")
    end
    return profile and (localized(profile.name) or localized(profile.short)
      or profile.species or receipt.profileId) or receipt.profileId
  end

  local function modAssetReadable(relative)
    if type(relative) ~= "string" or relative == ""
        or type(mod) ~= "table" or type(mod.read) ~= "function" then
      return false
    end
    local ok, bytes = pcall(mod.read, mod, relative)
    return ok and type(bytes) == "string" and #bytes > 0
  end

  local function profileReady(game, receipt, allowDownload)
    local function assetReady(path)
      if allowDownload and opts.spriteContent then return opts.spriteContent:hasAsset(path) end
      return modAssetReadable(path)
    end
    local profile
    if type(eventArchive.profileForGame)=='function' then
      profile=eventArchive.profileForGame(game,receipt.profileId)
    else profile=eventArchive.profile(receipt.profileId) end
    local data = game and game.data
    local species = profile and data and data.pokemon
      and data.pokemon[profile.species]
    local icons = data and data.icons
    local iconPath
    if species and type(icons) == "table" then
      local entry = icons.bySpecies and icons.bySpecies[profile.species]
        or species.icon
      if type(entry) == "table" then
        iconPath = entry.image
      elseif type(entry) == "string" and icons.icons then
        iconPath = icons.icons[entry]
      end
      if iconPath == nil and species.dex and icons.byDex and icons.icons then
        local fallback = icons.byDex[species.dex]
        iconPath = fallback and icons.icons[fallback]
      end
    end
    if type(species) ~= "table"
        or type(species.spriteFront) ~= "string" or species.spriteFront == ""
        or type(species.spriteBack) ~= "string" or species.spriteBack == ""
        or type(iconPath) ~= "string" or iconPath == ""
        or type(data.moves) ~= "table" then
      return false
    end
    if not profile then return false end
    for _, moveId in ipairs(profile.moves or {}) do
      if type(data.moves[moveId]) ~= "table" then return false end
    end
    local authority = profile.assetAuthority
    if authority then
      local prefix = type(mod.path) == "string" and mod.path .. "/" or nil
      if not prefix
          or type(authority.front) ~= "string"
          or type(authority.back) ~= "string"
          or type(authority.icon) ~= "string"
          or type(authority.follower) ~= "string"
          or (species.spriteFront ~= prefix .. authority.front
            and not (allowDownload and species.ascendantOptionalFront == prefix .. authority.front))
          or (species.spriteBack ~= prefix .. authority.back
            and not (allowDownload and species.ascendantOptionalBack == prefix .. authority.back))
          or not assetReady(authority.front)
          or not assetReady(authority.back) then
        return false
      end
      local registryIcon = authority.icon:match("^registry:([A-Z_]+)$")
      if registryIcon then
        if species.icon ~= registryIcon or type(icons.icons) ~= "table"
            or type(icons.icons[registryIcon]) ~= "string"
            or icons.icons[registryIcon] == "" then
          return false
        end
      elseif not assetReady(authority.icon) then
        return false
      elseif authority.family ~= "johto_crystal"
          and iconPath ~= prefix .. authority.icon then
        return false
      end
      local sprites = opts.followerSprites
      if not (sprites and type(sprites.definition) == "function"
          and type(sprites.coverage) == "function") then
        return false
      end
      local ok, follower = pcall(sprites.definition, game, profile.species)
      if not ok or type(follower) ~= "table" or follower.frames ~= 6
          or follower.width ~= 16 or follower.height ~= 96
          or follower.normalRelative ~= authority.follower then
        return false
      end
      local coverageOk, coverage = pcall(
        sprites.coverage, game, { profile.species }, false)
      local row = coverageOk and type(coverage) == "table" and coverage[1]
      if type(row) ~= "table" or row.relative ~= authority.follower
          or (row.readable ~= true and not (allowDownload and opts.spriteContent and opts.spriteContent:hasAsset(authority.follower))) then
        return false
      end
    end
    return true
  end

  local function deliveryMessage(receipt, destination, box, recovered, syncPending)
    local name = profileName(receipt)
    local message
    if destination == "box" then
      message = tr(
        ("Gift Code accepted!\f%s was sent to\nBOX %d."):format(name, box or 1),
        ("Geschenkcode gültig!\f%s wurde in\nBOX %d gesendet."):format(name, box or 1))
    else
      message = tr(
        ("Gift Code accepted!\f%s joined your\nPARTY."):format(name),
        ("Geschenkcode gültig!\f%s ist jetzt in\ndeinem TEAM."):format(name))
    end
    if recovered then
      message = message .. tr(
        "\fThe saved delivery\nreceipt was verified.",
        "\fDer gespeicherte\nEmpfang wurde geprüft.")
    end
    if syncPending then
      message = message .. tr(
        "\fShared Archive sync\nwill retry later.",
        "\fDer Archiv-Abgleich\nwird später wiederholt.")
    end
    return message
  end

  local function nextDeliveryBox(game)
    if type(eventArchive.nextGiftBox) ~= "function" then
      return nil, "missing box-capacity authority"
    end
    local ok, box = pcall(eventArchive.nextGiftBox, game)
    if not ok then return nil, "box-capacity authority failed" end
    if box ~= nil and (type(box) ~= "number" or box < 1
        or box ~= math.floor(box)) then
      return nil, "invalid destination box"
    end
    return box
  end

  local function noBoxOutcome(game)
    local box, err = nextDeliveryBox(game)
    if err then
      return nil, outcome("config_error", tr(
        "PC storage could not\nbe checked.\fThe code was not claimed.",
        "Der PC-Speicher konnte\nnicht geprüft werden.\fDer Code wurde nicht eingelöst."))
    end
    if box == nil then
      return nil, outcome("full", tr(
        "Every PC BOX is full.\fThe code was not claimed.\nFree a slot and enter\nthe same code again.",
        "Alle PC-BOXEN sind voll.\fDer Code wurde nicht eingelöst.\nMache einen Platz frei und\ngib denselben Code erneut ein."))
    end
    return box
  end

  local function requireSpriteContent(game, receipt)
    if not opts.spriteContent then return true end
    if opts.spriteContent.bind and not opts.spriteContent:bind(game) then
      return profileReady(game, receipt), unavailableProfileOutcome()
    end
    -- Validate species, moves and exact view/follower bindings before queuing.
    -- Allow missing bytes only when the pinned sprite index or bundled art owns them.
    if not profileReady(game, receipt, true) then return false, unavailableProfileOutcome() end
    local ready, reason = opts.spriteContent:ensure(receipt.profileId, true)
    if ready then return true end
    return false, outcome("sprites_pending", reason == "sprite_restart_required" and tr(
      "Sprites verified. Restart\nthe game, then enter the\nsame code again.\fNo prize was consumed.",
      "Sprites geprueft. Spiel\nneu starten und denselben\nCode erneut eingeben.\fKein Preis verbraucht.") or tr(
      "Sprites are downloading.\nSee Ascendant Downloads.\fThen enter this code again.\nThe code stays valid.",
      "Sprites werden geladen.\nSiehe Ascendant-Downloads.\fDanach denselben Code\neingeben. Er bleibt gueltig."))
  end

  local function reconcileUnsynced(game, root, ledger)
    local changed = false
    for digest, receipt in pairs(ledger.unsynced) do
      local committed = commitShared(receipt)
      if committed then ledger.unsynced[digest], changed = nil, true end
    end
    if changed then persistLocal(root, game) end
  end

  local function settlePending(game, root, ledger)
    local receipt = ledger.pendingReceipt
    if not receipt then
      reconcileUnsynced(game, root, ledger)
      return outcome("none", tr(
        "No reserved Gift Code\nprize is waiting.",
        "Kein reservierter\nGeschenkcode-Preis wartet."))
    end
    if not validReceipt(receipt) or not eventArchive.profile(receipt.profileId) then
      return outcome("config_error", tr(
        "This reserved gift is\nnot available in this build.\fNothing was changed.",
        "Dieses reservierte\nGeschenk fehlt in diesem Build.\fNichts wurde geändert."))
    end
    local spriteReady, spriteOutcome = requireSpriteContent(game, receipt)
    if not spriteReady then return spriteOutcome end
    if not profileReady(game, receipt) then
      return unavailableProfileOutcome()
    end

    local status, sharedReceipt = sharedStatus(receipt.digest)
    if status == nil then
      return outcome("archive_error", tr(
        "The shared Gift Code\narchive is unavailable.\fNothing was claimed.",
        "Das gemeinsame\nCode-Archiv ist nicht verfügbar.\fNichts wurde eingelöst."))
    elseif status == "claimed" then
      local mon, destination, box = eventArchive.findGiftReceipt(game, receipt.digest)
      ledger.claimed[receipt.digest] = copy(sharedReceipt or receipt)
      ledger.pendingReceipt = nil
      persistLocal(root, game)
      if mon then
        return outcome(destination or "party",
          deliveryMessage(receipt, destination or "party", box, true, false))
      end
      return outcome("claimed", tr(
        "This Gift Code was\nalready claimed in this\nsave or shared archive.",
        "Dieser Geschenkcode\nwurde in diesem Spielstand\noder Archiv schon eingelöst."))
    elseif status == "ready" then
      local reserved, reserveStatus, reservedReceipt = reserveShared(receipt)
      if not reserved then
        if reserveStatus == "claimed" then
          ledger.claimed[receipt.digest] = copy(reservedReceipt or receipt)
          ledger.pendingReceipt = nil
          persistLocal(root, game)
          return outcome("claimed", tr(
            "This Gift Code was\nalready claimed in this\nsave or shared archive.",
            "Dieser Geschenkcode\nwurde in diesem Spielstand\noder Archiv schon eingelöst."))
        end
        return outcome("archive_error", tr(
          "The shared Gift Code\narchive could not reserve\nthis prize.",
          "Das gemeinsame\nCode-Archiv konnte den\nPreis nicht reservieren."))
      end
    elseif status == "pending" and not sameReceipt(sharedReceipt, receipt) then
      return outcome("archive_error", tr(
        "The shared Gift Code\nreceipt does not match.\fNothing was claimed.",
        "Der gemeinsame\nCode-Beleg passt nicht.\fNichts wurde eingelöst."))
    end

    local mon, destination, box = eventArchive.findGiftReceipt(game, receipt.digest)
    local recovered = mon ~= nil
    if not mon then
      mon, destination, box = eventArchive.deliverGift(game, receipt.profileId,
        tr("OFFLINE GIFT CODE", "OFFLINE-GESCHENKCODE"), receipt,
        { boxOnly = true })
      if not mon and destination == "full" then
        persistLocal(root, game)
        return outcome("full", tr(
          "Every PC BOX is full.\fThe code remains reserved.\nFree a slot, then claim\nthe pending gift.",
          "Alle PC-BOXEN sind voll.\fDer Code bleibt reserviert.\nMache einen Platz frei und\nhole den Preis danach ab."))
      elseif not mon then
        return outcome("config_error", tr(
          "This Gift Code prize\ncannot be delivered.\fNothing was claimed.",
          "Dieser Geschenkcode-\nPreis kann nicht zugestellt werden.\fNichts wurde eingelöst."))
      end
    end

    ledger.claimed[receipt.digest] = copy(receipt)
    ledger.pendingReceipt = nil
    -- Persist the repair intent in the same save transaction as the Pokemon.
    -- A crash between that save and the shared-archive commit therefore leaves
    -- a durable, idempotent action instead of an orphaned shared reservation.
    ledger.unsynced[receipt.digest] = copy(receipt)
    if not persistLocal(root, game) then
      -- Keep the durable shared reservation open and restore the local pending
      -- view. If the Pokemon snapshot did reach disk, its digest receipt makes
      -- the retry idempotent; otherwise the reward is built again after load.
      ledger.claimed[receipt.digest] = nil
      ledger.pendingReceipt = copy(receipt)
      ledger.unsynced[receipt.digest] = nil
      pcall(eventArchive.persist, root)
      return outcome("pending", tr(
        "The delivery could not\nbe confirmed in the save.\fRetry the reserved gift.",
        "Die Zustellung konnte\nnicht gespeichert werden.\fVersuche den reservierten\nPreis erneut."))
    end
    local committed = commitShared(receipt)
    if committed then
      ledger.unsynced[receipt.digest] = nil
      persistLocal(root, game)
    end
    return outcome(destination or "party",
      deliveryMessage(receipt, destination or "party", box, recovered,
        not committed))
  end

  function G.redeem(game, raw)
    -- The Card gate deliberately precedes normalization, hashing and every
    -- local/shared ledger read. OFF must be observably inert and must not turn
    -- an entered value into an attempt, receipt or diagnostic side effect.
    if not enabled() then return disabledOutcome() end
    if not catalogValid then
      return outcome("unavailable", tr(
        "Gift Codes are not\navailable in this build.",
        "Geschenkcodes sind in\ndiesem Build nicht verfügbar."))
    end
    local root, ledger = localState()
    if not root then return stateErrorOutcome() end
    local attemptAt, gate = beginAttempt(root, ledger, game)
    if not attemptAt then return gate end
    local normalized, reason = G.normalize(raw)
    if not normalized then
      local guardOutcome = recordFailedAttempt(root, ledger, game, attemptAt)
      return guardOutcome or outcome(reason, validationMessage(reason))
    end
    local ok, digest = pcall(sha256, normalized)
    if not ok or not digestShape(digest) then
      return outcome("hash_error", tr(
        "Gift Code verification\nis unavailable.\fNothing was claimed.",
        "Die Code-Prüfung ist\nnicht verfügbar.\fNichts wurde eingelöst."))
    end
    digest = digest:lower()
    local receipt = digestIndex[digest]
    if not receipt then
      local guardOutcome = recordFailedAttempt(root, ledger, game, attemptAt)
      if guardOutcome then return guardOutcome end
      return outcome("unknown", tr(
        "This Gift Code is not\nknown to this event build.",
        "Dieser Geschenkcode ist\ndiesem Event-Build nicht bekannt."))
    end
    local recorded, recordFailure = recordAcceptedAttempt(
      root, ledger, game, attemptAt)
    if not recorded then return recordFailure end
    -- Resolve the complete delivery authority before touching either journal.
    -- Missing species, battle art, icon, move or follower data therefore
    -- cannot reserve or consume a valid code in an incomplete installation.
    local spriteReady, spriteOutcome = requireSpriteContent(game, receipt)
    if not spriteReady then return spriteOutcome end
    if not profileReady(game, receipt) then
      return unavailableProfileOutcome()
    end

    local localClaim = ledger.claimed[digest]
    if localClaim then
      -- If only the shared archive was rolled back, the save receipt repairs
      -- it without ever touching the reward delivery path.
      local committed = commitShared(localClaim)
      if not committed then
        ledger.unsynced[digest] = copy(localClaim)
        persistLocal(root, game)
      end
      return outcome("claimed", tr(
        "This Gift Code was\nalready claimed in this\nsave or shared archive.",
        "Dieser Geschenkcode\nwurde in diesem Spielstand\noder Archiv schon eingelöst."))
    end
    if ledger.pendingReceipt and ledger.pendingReceipt.digest ~= digest then
      return outcome("pending", tr(
        "Another Gift Code prize\nis reserved.\fClaim it before entering\na new code.",
        "Ein anderer Code-Preis\nist reserviert.\fHole ihn vor einem\nneuen Code ab."))
    end
    if ledger.pendingReceipt then return settlePending(game, root, ledger) end

    local status, sharedReceipt = sharedStatus(digest)
    if status == nil then
      return outcome("archive_error", tr(
        "The shared Gift Code\narchive is unavailable.\fNothing was claimed.",
        "Das gemeinsame\nCode-Archiv ist nicht verfügbar.\fNichts wurde eingelöst."))
    elseif status == "claimed" then
      ledger.claimed[digest] = copy(sharedReceipt or receipt)
      persistLocal(root, game)
      return outcome("claimed", tr(
        "This Gift Code was\nalready claimed in this\nsave or shared archive.",
        "Dieser Geschenkcode\nwurde in diesem Spielstand\noder Archiv schon eingelöst."))
    elseif status == "pending" then
      if not sameReceipt(sharedReceipt, receipt) then
        return outcome("archive_error", tr(
          "The shared Gift Code\nreceipt does not match.\fNothing was claimed.",
          "Der gemeinsame\nCode-Beleg passt nicht.\fNichts wurde eingelöst."))
      end
      -- Only the save that durably wrote the matching local journal may finish
      -- a shared reservation. A rolled-back or concurrent save must not adopt
      -- it and create a second Pokemon during the commit crash window.
      return outcome("pending", tr(
        "This Gift Code is\nreserved in another\nsave.\fFinish the delivery\nwith that save.",
        "Dieser Geschenkcode\nist in einem anderen\nSpielstand reserviert.\fSchließe den Empfang\ndort ab."))
    end

    -- Capacity is checked before the save-local journal and, critically,
    -- before any shared-archive reservation. A full PC therefore cannot
    -- consume, reserve or invalidate a code; entering that same code after a
    -- slot is freed follows the ordinary first-claim path.
    local _, capacityFailure = noBoxOutcome(game)
    if capacityFailure then return capacityFailure end

    ledger.pendingReceipt = copy(receipt)
    if not persistLocal(root, game) then
      ledger.pendingReceipt = nil
      pcall(eventArchive.persist, root)
    end
    if not ledger.pendingReceipt then
      return outcome("state_error", tr(
        "The Gift Code journal\ncould not be saved.\fNothing was claimed.",
        "Das Code-Journal konnte\nnicht gespeichert werden.\fNichts wurde eingelöst."))
    end
    local reserved, reserveStatus, reservedReceipt = reserveShared(receipt)
    if not reserved then
      ledger.pendingReceipt = nil
      if reserveStatus == "claimed" then
        ledger.claimed[digest] = copy(reservedReceipt or receipt)
      end
      persistLocal(root, game)
      if reserveStatus == "claimed" then
        return outcome("claimed", tr(
          "This Gift Code was\nalready claimed in this\nsave or shared archive.",
          "Dieser Geschenkcode\nwurde in diesem Spielstand\noder Archiv schon eingelöst."))
      end
      return outcome("archive_error", tr(
        "The shared Gift Code\narchive could not reserve\nthis prize.",
        "Das gemeinsame\nCode-Archiv konnte den\nPreis nicht reservieren."))
    end
    return settlePending(game, root, ledger)
  end

  function G.claimPending(game)
    if not enabled() then return disabledOutcome() end
    local root, ledger = localState()
    if not root then
      return outcome("state_error", tr(
        "Gift Code save data is\nunavailable.",
        "Die Geschenkcode-Daten\nsind nicht verfügbar."))
    end
    return settlePending(game, root, ledger)
  end

  function G.reconcile(game)
    if not enabled() then return false, "disabled" end
    local root, ledger = localState()
    if not root then return false end
    reconcileUnsynced(game, root, ledger)
    local receipt = ledger.pendingReceipt
    if not (receipt and game) then return true end
    local mon = eventArchive.findGiftReceipt(game, receipt.digest)
    if mon then
      settlePending(game, root, ledger)
    end
    return true
  end

  local INPUT_TITLE_EN = "GIFT CODE"
  local INPUT_TITLE_DE = "GESCHENKCODE"

  function G.inputTitle()
    return tr(INPUT_TITLE_EN, INPUT_TITLE_DE)
  end
  function G.inputGrid()
    return {
      { "2", "3", "4", "5", "6", "7", "8", "9" },
      { "A", "B", "C", "D", "E", "F", "G", "H" },
      { "J", "K", "M", "N", "P", "Q", "R", "S" },
      { "T", "U", "V", "W", "X", "Y", "Z" },
      { "ED" },
    }
  end

  local function showOutcome(game, result)
    game.stack:push(require("src.render.TextBox").new(game, result.message))
  end

  function G.openInput(game)
    if not enabled() then return disabledOutcome() end
    local Screens = require("src.ui.Screens")
    return Screens.push(game, "NamingScreen", {
      title = G.inputTitle(), maxLen = CODE_LENGTH,
      onDone = function(raw)
        showOutcome(game, G.redeem(game, raw))
      end,
    })
  end

  local function pendingReceipt()
    local _, ledger = localState()
    return ledger and ledger.pendingReceipt or nil
  end

  if mod.content and mod.content.screens then
    mod.content.screens:register("KantoGiftCodes", {
      new = function(game)
        local rows = {}
        if not enabled() then
          return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
            tr("GIFT CODES", "GESCHENKCODES"), rows, {})
        end
        if activeCampaigns > 0 then
          rows[#rows + 1] = { label = tr("ENTER CODE", "CODE EINGEBEN"),
            value = "enter" }
        end
        if pendingReceipt() then
          rows[#rows + 1] = { label = tr("CLAIM RESERVED", "PREIS ABHOLEN"),
            right = tr("WAITING", "WARTET"), value = "pending" }
        end
        return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
          tr("GIFT CODES", "GESCHENKCODES"), rows, {
            onChoose = function(item)
              if not item then return end
              if item.value == "enter" then G.openInput(game)
              elseif item.value == "pending" then
                showOutcome(game, G.claimPending(game))
              end
            end,
          })
      end,
    })
  end

  mod.hooks:wrap("ui.naming.grid", function(nextGrid, base, context)
    local out = nextGrid(base, context)
    if context and context.maxLen == CODE_LENGTH
        and (context.title == INPUT_TITLE_EN or context.title == INPUT_TITLE_DE) then
      return G.inputGrid()
    end
    return out
  end, 900)

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" or not enabled()
        or (activeCampaigns == 0 and not pendingReceipt()) then
      return out
    end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("GIFT CODE", "GESCHENKCODE"),
      right = pendingReceipt() and tr("WAITING", "WARTET") or nil,
      ascendantMenu = true,
      ascendantLabel = tr("GIFT CODES", "GESCHENKCODES"),
      ascendantOrder = 51,
      ascendantKey = "gift_codes",
      onSelect = function() mod.ui.push(game, "KantoGiftCodes") end,
    })
  end, 260)

  mod.events:on("save.loaded", function(ev)
    G.game = ev and ev.game or (mod.world and mod.world.game)
    if enabled() then G.reconcile(G.game) end
  end)

  mod.events:on("mod.options_changed", function(ev)
    if ev and ev.mod == mod.id and ev.key == G.OPTION_KEY
        and ev.value ~= false and G.game then
      G.reconcile(G.game)
    end
  end)

  function G.install(game)
    G.game = game or G.game
    if not enabled() then return false, "disabled" end
    return G.reconcile(G.game)
  end
  function G.catalogReady() return catalogValid end
  function G.catalogError() return catalogProblem end
  function G.hasCampaigns() return catalogValid and activeCampaigns > 0 end
  function G.state()
    if not enabled() then return nil end
    local _, ledger = localState()
    return ledger and copy(ledger) or nil
  end
  G.codeLength = CODE_LENGTH
  G.alphabet = ALPHABET
  G.catalogSchema = CATALOG_SCHEMA
  G.attemptPolicy = {
    intervalSeconds = ATTEMPT_INTERVAL_SECONDS,
    failureWindowSeconds = FAILURE_WINDOW_SECONDS,
    failureLimit = FAILURE_LIMIT,
    cooldownSeconds = COOLDOWN_SECONDS,
  }
  return G
end
