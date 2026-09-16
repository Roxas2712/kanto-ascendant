-- Isolated post-RC2 NG+ World Rank tournament controller.
--
-- This module owns deterministic registration/rank state and pure team/level
-- contracts. Engine presentation, NPC materialization and exact-once archive
-- delivery are injected by main.lua and never become save authority here.

return function(mod, opts)
  opts = opts or {}
  local T = {
    CARD_ID = "KASC-67-WORLD-RANK-TOURNAMENT",
    OWNER = "kasc.tournament.world-rank/v1",
    OPTION_KEY = "grand_tournament",
    version = 1,
    saveKey = "ngplus_world_rank",
    readOnly = false,
  }
  local data = assert(opts.data, "ngplus tournament data is required")

  local function clamp(value, minimum, maximum)
    value = math.floor(tonumber(value) or minimum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
  end

  local function hash(value)
    local h = 2166136261
    value = tostring(value or "")
    for index = 1, #value do
      h = (h * 16777619 + value:byte(index)) % 2147483647
    end
    return h
  end

  local function safeText(value)
    value = tostring(value or "")
    value = value:gsub("[|\r\n]", "_")
    return value ~= "" and value or "unknown"
  end

  local function call(authority, ...)
    if type(authority) ~= "function" then return nil end
    local ok, value = pcall(authority, ...)
    if ok then return value end
    return nil
  end

  local function optionEnabled()
    if type(opts.enabled) == "function" then
      local ok, value = pcall(opts.enabled)
      return ok and value ~= false
    end
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, T.OPTION_KEY)
      return not ok or value ~= false
    end
    return true
  end

  function T.enabled()
    return optionEnabled()
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, entry in pairs(value) do
      result[copy(key, seen)] = copy(entry, seen)
    end
    return result
  end

  local function journeyState(game)
    local journey = opts.journey
    if not (journey and type(journey.state) == "function") then return nil end
    return call(journey.state, game and game.save) or call(journey.state)
  end

  local function ownerFor(game)
    local journey = journeyState(game) or {}
    local edition = call(opts.edition, game) or "unknown"
    local profile = call(opts.profile, game) or "unknown"
    local cycle = tonumber(journey.cycle or journey.targetCycle) or 0
    local runId = journey.runId or journey.activeRunId
    if type(runId) ~= "string" or runId == "" then return nil end
    return table.concat({ safeText(edition), safeText(profile),
      tostring(math.floor(cycle)), safeText(runId) }, "|")
  end

  local function legacyWorldRank(game)
    local value = call(opts.legacyState, game)
    return type(value) == "table" and value or {}
  end

  local function pendingPresentation(state, formatId, field)
    for _, receipt in pairs(type(state.pending) == "table"
        and state.pending or {}) do
      if type(receipt) == "table" and receipt.formatId == formatId
          and type(receipt[field]) == "string" and receipt[field] ~= "" then
        return true
      end
    end
    return false
  end

  local function formatRecord(formatId, persistent)
    persistent = type(persistent) == "table" and persistent or {}
    local history = type(persistent.formats) == "table"
      and persistent.formats[formatId] or nil
    history = type(history) == "table" and history or {}
    return {
      attempts = 0,
      championships = math.max(0,
        math.floor(tonumber(history.championships) or 0)),
      bestRank = clamp(tonumber(history.bestRank) or data.initialRank,
        data.championRank, data.initialRank),
      wins = 0,
      losses = 0,
      availableAt = 0,
      titleReserved = history.titleClaimed == true
        or pendingPresentation(persistent, formatId, "titleId"),
      cardReserved = history.cardClaimed == true
        or pendingPresentation(persistent, formatId, "cardId"),
      titleGranted = history.titleClaimed == true,
      cardGranted = history.cardClaimed == true,
    }
  end

  local function hallCount(game)
    local count = call(opts.hallCount, game)
    if count == nil then
      local hall = game and game.save and game.save.hallOfFame
      count = type(hall) == "table" and #hall or 0
    end
    return math.max(0, math.floor(tonumber(count) or 0))
  end

  local function fresh(owner, game)
    local persistent = legacyWorldRank(game)
    local inheritedUnlock = persistent.unlocked == true
      or call(opts.legacyUnlocked, game) == true
    local s = {
      version = T.version,
      owner = owner,
      steps = 0,
      invitation = {
        unlocked = inheritedUnlock,
        shown = inheritedUnlock,
        leagueQualified = inheritedUnlock,
        baselineHallCount = hallCount(game),
      },
      formats = {},
      active = nil,
      resolved = {},
      notices = {},
      lifecycleSeen = {},
      rewardQueue = {},
      rewardClaims = {},
      lastRewardClaim = nil,
    }
    for _, row in ipairs(data.formats) do
      s.formats[row.id] = formatRecord(row.id, persistent)
    end
    return s
  end

  local function persist(s)
    if T.readOnly then return false end
    mod.save:set(T.saveKey, s)
    return true
  end

  local function normalize(s, owner, game)
    if type(s) ~= "table" then return fresh(owner, game), true end
    local version = tonumber(s.version)
    if version and version > T.version then
      T.readOnly = true
      return s, false
    end
    if version ~= T.version or s.owner ~= owner then
      return fresh(owner, game), true
    end
    s.steps = math.max(0, math.floor(tonumber(s.steps) or 0))
    s.invitation = type(s.invitation) == "table" and s.invitation or {}
    s.invitation.baselineHallCount = math.max(0,
      math.floor(tonumber(s.invitation.baselineHallCount) or hallCount(game)))
    s.invitation.leagueQualified = s.invitation.leagueQualified == true
      or s.invitation.unlocked == true
    s.formats = type(s.formats) == "table" and s.formats or {}
    s.resolved = type(s.resolved) == "table" and s.resolved or {}
    s.notices = type(s.notices) == "table" and s.notices or {}
    s.lifecycleSeen = type(s.lifecycleSeen) == "table"
      and s.lifecycleSeen or {}
    s.rewardQueue = type(s.rewardQueue) == "table" and s.rewardQueue or {}
    s.rewardClaims = type(s.rewardClaims) == "table" and s.rewardClaims or {}
    if type(s.active) == "table" then
      local active, opponent = s.active, s.active.opponent
      local valid = data.byId[active.formatId]
        and type(active.token) == "string" and active.token ~= ""
        and tonumber(active.attemptSerial) and tonumber(active.encounterSerial)
        and tonumber(active.rank) and tonumber(active.inactivityAt)
        and type(opponent) == "table"
        and type(opponent.class) == "string" and opponent.class ~= ""
        and type(opponent.displayName) == "string"
          and opponent.displayName ~= ""
        and type(opponent.locationId) == "string"
          and opponent.locationId ~= ""
        and type(opponent.mapId) == "string" and opponent.mapId ~= ""
      if not valid then
        s.active = nil
      else
        active.attemptSerial = math.max(1,
          math.floor(tonumber(active.attemptSerial)))
        active.encounterSerial = math.max(1,
          math.floor(tonumber(active.encounterSerial)))
        active.rank = clamp(active.rank, data.championRank, data.initialRank)
        active.totalWins = math.max(0,
          math.floor(tonumber(active.totalWins) or 0))
        active.inactivityAt = math.max(0,
          math.min(s.steps, math.floor(tonumber(active.inactivityAt))))
        active.hint = clamp(active.hint, 0, 2)
        active.hintShown = clamp(active.hintShown, 0, active.hint)
        active.rotationIndex = math.max(0,
          math.floor(tonumber(active.rotationIndex) or 0))
        if type(active.previousLocationId) ~= "string" then
          active.previousLocationId = nil
        end
      end
    elseif s.active ~= nil then
      s.active = nil
    end
    local claims = {}
    for id, claimed in pairs(s.rewardClaims) do
      if type(id) == "string" and id ~= "" and claimed == true then
        claims[id] = true
      end
    end
    s.rewardClaims = claims
    local seen = {}
    for id, acknowledged in pairs(s.lifecycleSeen) do
      if type(id) == "string" and id ~= "" and acknowledged == true then
        seen[id] = true
      end
    end
    s.lifecycleSeen = seen
    local queue, queued = {}, {}
    for _, reward in ipairs(s.rewardQueue) do
      if type(reward) == "table" and type(reward.id) == "string"
          and reward.id ~= "" and type(reward.formatId) == "string"
          and data.byId[reward.formatId] and type(reward.owner) == "string"
          and reward.owner == owner and type(reward.completionToken) == "string"
          and reward.completionToken ~= "" and not claims[reward.id]
          and not queued[reward.id] then
        queue[#queue + 1] = copy(reward)
        queued[reward.id] = true
      end
    end
    s.rewardQueue = queue
    local notices, noticed = {}, {}
    for _, notice in ipairs(s.notices) do
      if type(notice) == "table" and type(notice.id) == "string"
          and notice.id ~= "" and notice.owner == owner
          and type(notice.kind) == "string" and not seen[notice.id]
          and not noticed[notice.id] then
        notices[#notices + 1] = copy(notice)
        noticed[notice.id] = true
      end
    end
    s.notices = notices
    local lastClaim = s.lastRewardClaim
    if type(lastClaim) ~= "table" or lastClaim.owner ~= owner
        or type(lastClaim.id) ~= "string" or lastClaim.id == ""
        or type(lastClaim.formatId) ~= "string"
        or not data.byId[lastClaim.formatId] then
      s.lastRewardClaim = nil
    end
    local persistent = legacyWorldRank(game)
    local function claimedFor(formatId, field)
      for _, receipt in pairs(type(persistent.claimed) == "table"
          and persistent.claimed or {}) do
        if type(receipt) == "table" and receipt.formatId == formatId
            and receipt[field] ~= nil then return true end
      end
      local marker = "|" .. formatId .. "|"
      for id in pairs(claims) do
        if id:find(marker, 1, true) then return true end
      end
      return false
    end
    local function queuedFor(formatId, field)
      for _, receipt in ipairs(queue) do
        if receipt.formatId == formatId and receipt[field] ~= nil then
          return true
        end
      end
      return false
    end
    for _, row in ipairs(data.formats) do
      local record = s.formats[row.id]
      if type(record) ~= "table" then
        s.formats[row.id] = formatRecord(row.id, persistent)
      else
        record.attempts = math.max(0, math.floor(tonumber(record.attempts) or 0))
        record.championships = math.max(0,
          math.floor(tonumber(record.championships) or 0))
        record.bestRank = clamp(record.bestRank, 1, data.initialRank)
        record.wins = math.max(0, math.floor(tonumber(record.wins) or 0))
        record.losses = math.max(0, math.floor(tonumber(record.losses) or 0))
        record.availableAt = math.max(0,
          math.floor(tonumber(record.availableAt) or 0))
        local history = type(persistent.formats) == "table"
          and persistent.formats[row.id] or nil
        history = type(history) == "table" and history or {}
        record.championships = math.max(record.championships,
          math.max(0, math.floor(tonumber(history.championships) or 0)))
        record.bestRank = math.min(record.bestRank,
          clamp(tonumber(history.bestRank) or data.initialRank,
            data.championRank, data.initialRank))
        record.titleGranted = history.titleClaimed == true
          or claimedFor(row.id, "titleId")
        record.cardGranted = history.cardClaimed == true
          or claimedFor(row.id, "cardId")
        record.titleReserved = record.titleGranted
          or pendingPresentation(persistent, row.id, "titleId")
          or queuedFor(row.id, "titleId")
        record.cardReserved = record.cardGranted
          or pendingPresentation(persistent, row.id, "cardId")
          or queuedFor(row.id, "cardId")
      end
    end
    return s, false
  end

  function T.eligible(game)
    if not optionEnabled() then return false end
    local journey = opts.journey
    if journey and type(journey.isActive) == "function"
        and call(journey.isActive, game and game.save) ~= true
        and call(journey.isActive, game) ~= true then return false end
    if not ownerFor(game) then return false end
    return true
  end

  function T.state(game)
    if not optionEnabled() then return nil end
    local owner = ownerFor(game)
    if not owner then return nil end
    local raw = mod.save:get(T.saveKey)
    local s, changed = normalize(raw, owner, game)
    if changed then persist(s) end
    return s
  end

  local function tr(row)
    if type(row) ~= "table" then return tostring(row or "") end
    local i18n = opts.i18n
    if i18n and type(i18n.text) == "function" then
      local value = call(i18n.text, row.en, row.de)
      if type(value) == "string" and value ~= "" then return value end
    end
    return row.en
  end

  local function languageFor(game)
    return call(opts.language, game) == "de" and "de" or "en"
  end

  local function renderLifecycle(game, id, values)
    if type(data.renderDialogue) ~= "function" then return nil end
    local text = call(data.renderDialogue, id, languageFor(game), values)
    return type(text) == "string" and text ~= "" and text or nil
  end

  local function queueLifecycle(s, kind, sourceId, values)
    local decision = data.dialogueLifecycleDisposition
      and data.dialogueLifecycleDisposition[kind]
    if not (type(decision) == "table" and type(sourceId) == "string"
        and sourceId ~= "") then return false end
    local id = sourceId .. "|dialogue|" .. kind
    if s.lifecycleSeen[id] == true then return true end
    for _, notice in ipairs(s.notices) do
      if notice.id == id then return true end
    end
    s.notices[#s.notices + 1] = {
      id = id,
      owner = s.owner,
      kind = kind,
      values = copy(type(values) == "table" and values or {}),
    }
    return true
  end

  local function classAuthorized(classId, game)
    if type(opts.opponentAuthority) ~= "function" then return true end
    local proof = call(opts.opponentAuthority, classId, game)
    return proof == true or type(proof) == "table"
  end

  local function authorizedOpponents(row, game)
    local result = {}
    for _, classId in ipairs(row.opponentClasses or {}) do
      if classAuthorized(classId, game) then result[#result + 1] = classId end
    end
    return result
  end

  local function authorizedChampions(row, game)
    local result = {}
    for _, classId in ipairs(row.championCandidates
        or (row.champion and { row.champion }) or {}) do
      if classAuthorized(classId, game) then result[#result + 1] = classId end
    end
    return result
  end

  local function formatAuthorized(row, game)
    if type(row) ~= "table" then return false end
    if type(opts.formatAuthority) == "function" then
      local report = call(opts.formatAuthority, game, row.id)
      return type(report) == "table" and report.available == true
    end
    return #authorizedChampions(row, game) > 0
      and #authorizedOpponents(row, game)
        >= math.max(1, tonumber(row.minimumAuthorizedOpponents) or 1)
  end

  local function opponentFor(s, active, game)
    local row = data.byId[active.formatId]
    local champion = active.rank <= 2
    local class
    if type(opts.opponentClass) == "function" then
      class = call(opts.opponentClass, game, active.formatId,
        active.rank, active.token)
      if type(class) ~= "string" or class == "" then return nil end
    elseif champion then
      local candidates = authorizedChampions(row, game)
      if #candidates == 0 then return nil end
      class = candidates[hash(active.token .. ":champion") % #candidates + 1]
    else
      local candidates = authorizedOpponents(row, game)
      if #candidates == 0 then return nil end
      class = candidates[hash(active.token .. ":class") % #candidates + 1]
    end
    local name = data.opponentNames[
      hash(active.token .. ":name") % #data.opponentNames + 1]
    local locations = {}
    for _, candidate in ipairs(data.locations or {}) do
      if candidate.id ~= active.previousLocationId then
        locations[#locations + 1] = candidate
      end
    end
    if #locations == 0 then locations = data.locations or {} end
    if #locations == 0 then return nil end
    local location = locations[
      hash(active.token .. ":location") % #locations + 1]
    local language = call(opts.language, game)
    if language ~= "de" then language = "en" end
    local label = type(data.trainerClassLabel) == "function"
      and call(data.trainerClassLabel, class, language) or nil
    if type(label) ~= "string" or label == "" then return nil end
    local named = type(data.trainerDisplayName) == "function"
      and call(data.trainerDisplayName, class, language) or nil
    if type(named) ~= "string" or named == "" then named = nil end
    return {
      class = class,
      name = named or tr(name),
      className = label,
      displayName = named
        or (label .. " " .. tr(name)),
      locationId = location.id,
      mapId = location.mapId,
      location = tr(location.label),
      cells = location.cells,
      champion = champion,
    }
  end

  local function assignment(s, game)
    local active = s.active
    active.encounterSerial = (active.encounterSerial or 0) + 1
    active.token = table.concat({ s.owner, active.formatId,
      tostring(active.attemptSerial), tostring(active.encounterSerial) }, "|")
    active.opponent = opponentFor(s, active, game)
    return active.token
  end

  local function trainerCardLifecycle(s, game, formatId, confirmed)
    local format = data.byId[formatId]
    local record = s.formats[formatId]
    if not (format and record) then return nil end
    local kind, values
    if confirmed == true then
      local active = s.active
      if not (active and active.formatId == formatId and active.opponent) then
        return nil
      end
      kind = "registrationConfirmed"
      values = {
        TOURNAMENT = tr(format.name),
        RANK = active.rank,
        OPPONENT = active.opponent.displayName,
        LOCATION = active.opponent.location,
      }
    elseif s.active then
      local activeFormat = data.byId[s.active.formatId]
      kind = "registrationLocked"
      values = {
        TOURNAMENT = activeFormat and tr(activeFormat.name)
          or s.active.formatId,
      }
    else
      local remaining = math.max(0, record.availableAt - s.steps)
      if remaining > 0 then
        kind = "formatCoolingDown"
        values = { TOURNAMENT = tr(format.name), STEPS = remaining }
      elseif s.invitation.unlocked ~= true then
        return nil
      elseif not formatAuthorized(format, game) then
        kind = "formatAuthorityUnavailable"
        values = { TOURNAMENT = tr(format.name) }
      else
        kind = "registrationOpen"
        values = { TOURNAMENT = tr(format.name), RULE = tr(format.ruleText) }
      end
    end
    local text = renderLifecycle(game, kind, values)
    if not text then return nil end
    return { id = kind, kind = kind, text = text, values = values }
  end

  local function registrationRows(s, game)
    local rows = {}
    for _, formatRow in ipairs(data.formats) do
      local record = s.formats[formatRow.id]
      local authorityAvailable = formatAuthorized(formatRow, game)
      local lifecycle = trainerCardLifecycle(s, game, formatRow.id, false)
      rows[#rows + 1] = {
        id = formatRow.id,
        name = tr(formatRow.name),
        rule = tr(formatRow.ruleText),
        available = s.invitation.unlocked == true and not s.active
          and s.steps >= record.availableAt
          and authorityAvailable,
        authorityAvailable = authorityAvailable,
        returnsIn = math.max(0, record.availableAt - s.steps),
        bestRank = record.bestRank,
        championships = record.championships,
        lifecycleId = lifecycle and lifecycle.id or nil,
        lifecycleText = lifecycle and lifecycle.text or nil,
      }
    end
    return rows
  end

  function T.worldRankModel(game)
    local s = T.state(game)
    if not s or T.readOnly then
      return { eligible = false, readOnly = T.readOnly == true, formats = {} }
    end
    local model = {
      eligible = T.eligible(game),
      unlocked = s.invitation.unlocked == true,
      active = s.active ~= nil,
      formats = registrationRows(s, game),
      steps = s.steps,
      owner = s.owner,
    }
    local rewards = T.pendingRewards and T.pendingRewards(game) or {}
    local rewardModel = call(opts.rewardPendingModel, game, copy(rewards))
    rewardModel = type(rewardModel) == "table" and rewardModel or {
      pending = #rewards > 0,
      pendingCount = #rewards,
      text = #rewards > 0 and tr({
        en = "A sealed World Rank prize is waiting for delivery.",
        de = "Ein versiegelter Weltrang-Preis wartet auf Zustellung.",
      }) or nil,
    }
    model.pendingPrize = rewardModel.pending == true or #rewards > 0
    model.pendingPrizeText = rewardModel.text
    model.pendingReward = rewardModel
    local active = s.active
    if active then
      local row = data.byId[active.formatId]
      model.formatId = active.formatId
      model.tournament = tr(row.name)
      model.rule = tr(row.ruleText)
      model.rank = active.rank
      model.attemptWins = active.totalWins
      model.encounterToken = active.token
      model.opponent = active.opponent and active.opponent.displayName
      model.opponentClass = active.opponent and active.opponent.class
      model.location = active.opponent and active.opponent.location
      model.locationId = active.opponent and active.opponent.locationId
      model.mapId = active.opponent and active.opponent.mapId
      model.spawnAuthority = active.opponent and table.concat({
        active.token, "spawn", active.opponent.locationId or "none",
      }, "|") or nil
      model.remainingSteps = math.max(0,
        data.timing.expire - (s.steps - active.inactivityAt))
      model.hint = active.hint or 0
    end
    return model
  end

  function T.available(game, formatId)
    local s = T.state(game)
    local record = s and s.formats[formatId]
    local row = data.byId[formatId]
    return s and s.invitation.unlocked == true and not s.active
      and record and row and s.steps >= record.availableAt
      and formatAuthorized(row, game) or false
  end

  function T.trainerCardPresentation(game, formatId, intent)
    local s = T.state(game)
    if not (s and not T.readOnly) then return nil, "unavailable" end
    local presentation = trainerCardLifecycle(s, game, formatId,
      intent == "confirmed")
    if not presentation then return nil, "unavailable" end
    presentation.owner = s.owner
    if intent == "confirmed" and s.active
        and s.active.formatId == formatId then
      -- This is the exact durable notice queued by register().  Presentation
      -- adapters can lease and acknowledge this id instead of rendering an
      -- unrelated immediate copy and then replaying the queued notice.
      presentation.id = s.active.token .. "|dialogue|registrationConfirmed"
    end
    return copy(presentation)
  end

  function T.register(game, formatId)
    local s = T.state(game)
    if not (s and T.eligible(game) and data.byId[formatId]
        and T.available(game, formatId) and not T.readOnly) then
      return nil, "unavailable"
    end
    local record = s.formats[formatId]
    record.attempts = record.attempts + 1
    s.active = {
      formatId = formatId,
      attemptSerial = record.attempts,
      rank = data.initialRank,
      totalWins = 0,
      encounterSerial = 0,
      inactivityAt = s.steps,
      rotationIndex = 0,
      hint = 0,
      hintShown = 0,
    }
    local token = assignment(s, game)
    local confirmation = trainerCardLifecycle(s, game, formatId, true)
    if confirmation then
      queueLifecycle(s, "registrationConfirmed", token,
        confirmation.values)
    end
    persist(s)
    return token, T.worldRankModel(game)
  end

  function T.assign(game)
    local s = T.state(game)
    if not (s and s.active and not T.readOnly) then return nil end
    local token = assignment(s, game)
    persist(s)
    return token
  end

  local function finishAttempt(s, reason, rank)
    local active = s.active
    if not active then return nil end
    local record = s.formats[active.formatId]
    local cooldownSpan = data.timing.reentryMax - data.timing.reentryMin + 1
    local cooldown = data.timing.reentryMin
      + hash(active.token .. ":return:" .. reason) % cooldownSpan
    record.availableAt = s.steps + cooldown
    record.lastResult = reason
    record.lastRank = rank or active.rank
    local result = {
      formatId = active.formatId,
      rank = rank or active.rank,
      ended = true,
      reason = reason,
      availableAt = record.availableAt,
      cooldown = cooldown,
    }
    if reason == "timeout" then
      local row = data.byId[active.formatId]
      local opponent = active.opponent or {}
      s.notices[#s.notices + 1] = {
        id = active.token .. "|timeout",
        owner = s.owner,
        kind = "expired",
        token = active.token,
        formatId = active.formatId,
        tournament = row and tr(row.name) or active.formatId,
        champion = opponent.displayName or opponent.name or "CHAMPION",
        class = opponent.class,
        opponent = opponent.displayName or opponent.name,
        location = opponent.location,
        rank = rank or active.rank,
      }
    end
    s.active = nil
    return result
  end

  function T.resolve(game, token, result)
    local s = T.state(game)
    local active = s and s.active
    if not (active and token == active.token and not s.resolved[token]
        and (result == "win" or result == "loss") and not T.readOnly) then
      return nil
    end
    s.resolved[token] = result
    local record = s.formats[active.formatId]
    local delta = hash(token .. ":" .. result) % 3 + 1
    local resolution = { formatId = active.formatId, result = result, delta = delta }
    local resolvedOpponent = copy(active.opponent or {})
    local function queueResult(rank)
      local format = data.byId[active.formatId]
      local id = token .. "|result|" .. result
      s.notices[#s.notices + 1] = {
        id = id,
        owner = s.owner,
        kind = result == "win" and "playerWin" or "playerLoss",
        token = token,
        formatId = active.formatId,
        class = resolvedOpponent.class,
        opponent = resolvedOpponent.displayName or resolvedOpponent.name,
        tournament = format and tr(format.name) or active.formatId,
        champion = resolvedOpponent.displayName or resolvedOpponent.name,
        rank = rank,
      }
      return id
    end
    if result == "win" then
      -- Rank gains may reach the finalist slot, never award a championship
      -- for an ordinary assignment. Bind completion to the sealed opponent,
      -- including saves made before this gate existed.
      local championWin = active.rank <= 2
        and resolvedOpponent.champion == true
      active.rank = math.max(championWin and data.championRank or 2,
        active.rank - delta)
      active.totalWins = active.totalWins + 1
      record.wins = record.wins + 1
      record.bestRank = math.min(record.bestRank, active.rank)
      resolution.rank = active.rank
      if active.rank == data.championRank then
        record.championships = record.championships + 1
        resolution.champion = true
        resolution.rewardId = token .. "|champion"
        resolution.cash = active.formatId == "gold"
          and data.rewards.goldChampionCash or data.rewards.championCash
        resolution.ball = data.rewards.championBallItem
        resolution.ballCount = data.rewards.championBallCount
        if active.formatId == "gold" then
          resolution.goldJackpotCandidate =
            hash(token .. ":gold-jackpot") % 100
              < data.rewards.goldShinyJackpotPercent
          resolution.shinyDue = resolution.goldJackpotCandidate == true
        else
          resolution.shinyDue = true
        end
        local reward = {
          version = 1,
          id = resolution.rewardId,
          owner = s.owner,
          formatId = active.formatId,
          token = token,
          completionToken = token,
          cash = resolution.cash,
          ball = resolution.ball,
          ballCount = resolution.ballCount,
          shinyDue = resolution.shinyDue == true,
          goldJackpotCandidate = resolution.goldJackpotCandidate == true,
        }
        if not record.titleGranted and not record.titleReserved then
          record.titleReserved = true
          reward.titleId = data.byId[active.formatId].championTitle.id
          resolution.titleId = reward.titleId
        end
        if not record.cardGranted and not record.cardReserved then
          record.cardReserved = true
          reward.cardId = data.byId[active.formatId].championCardId
          resolution.cardId = reward.cardId
        end
        s.rewardQueue[#s.rewardQueue + 1] = reward
        resolution.reward = copy(reward)
        queueLifecycle(s, "champion", token, {
          CHAMPION = resolvedOpponent.displayName or resolvedOpponent.name,
        })
        resolution.departureNoticeId = token .. "|dialogue|champion"
        if reward.titleId and reward.cardId then
          queueLifecycle(s, "rewardSummary", reward.id, {
            CASH = reward.cash,
            BALL_COUNT = reward.ballCount,
            BALL = tostring(reward.ball):gsub("_", " "),
          })
        end
        local ended = finishAttempt(s, "champion", active.rank)
        for key, value in pairs(ended) do resolution[key] = value end
      else
        resolution.departureNoticeId = queueResult(active.rank)
        active.inactivityAt = s.steps
        active.rotationIndex = 0
        active.hint = 0
        active.hintShown = 0
        active.previousLocationId = resolvedOpponent.locationId
        assignment(s, game)
        resolution.nextToken = active.token
      end
    else
      local worsened = active.rank + delta
      record.losses = record.losses + 1
      resolution.rank = worsened
      resolution.departureNoticeId = queueResult(worsened)
      if worsened > data.initialRank then
        local format = data.byId[active.formatId]
        queueLifecycle(s, "eliminated", token, {
          TOURNAMENT = format and tr(format.name) or active.formatId,
          RANK = worsened,
        })
        local ended = finishAttempt(s, "eliminated", worsened)
        for key, value in pairs(ended) do resolution[key] = value end
      else
        active.rank = worsened
        active.inactivityAt = s.steps
        active.rotationIndex = 0
        active.hint = 0
        active.hintShown = 0
        active.previousLocationId = resolvedOpponent.locationId
        assignment(s, game)
        resolution.nextToken = active.token
      end
    end
    persist(s)
    return resolution
  end

  function T.pendingRewards(game)
    local s = T.state(game)
    return copy(s and s.rewardQueue or {})
  end

  function T.markRewardClaimed(game, rewardId, grants)
    local s = T.state(game)
    if not (s and type(rewardId) == "string" and rewardId ~= ""
        and type(grants) == "table" and grants.committed == true
        and not T.readOnly) then return false, "invalid acknowledgement" end
    if s.rewardClaims[rewardId] == true then return true end
    local index, reward
    for current, row in ipairs(s.rewardQueue) do
      if row.id == rewardId then index, reward = current, row; break end
    end
    if not reward then return false, "reward is not pending" end
    if reward.titleId and grants.title ~= true then
      return false, "title grant is incomplete"
    end
    if reward.cardId and grants.card ~= true then
      return false, "card grant is incomplete"
    end
    local record = s.formats[reward.formatId]
    if not record then return false, "reward format is unavailable" end
    if reward.titleId then
      record.titleReserved = true
      record.titleGranted = true
    end
    if reward.cardId then
      record.cardReserved = true
      record.cardGranted = true
    end
    table.remove(s.rewardQueue, index)
    s.rewardClaims[rewardId] = true
    s.lastRewardClaim = {
      id = rewardId,
      owner = s.owner,
      formatId = reward.formatId,
      goldJackpotCandidate = reward.goldJackpotCandidate == true,
    }
    persist(s)
    return true
  end

  function T.lastRewardClaim(game)
    local s = T.state(game)
    return copy(s and s.lastRewardClaim or nil)
  end

  function T.recordLifecycle(game, kind, sourceId, values)
    local allowed = kind == "opponentAuthorityMissing"
      or kind == "goldNoJackpot" or kind == "goldJackpot"
      or kind == "rewardPending"
      or kind == "rewardDelivered"
    local s = T.state(game)
    if not (allowed and s and not T.readOnly) then return false end
    local queued = queueLifecycle(s, kind, sourceId, values)
    if queued then persist(s) end
    return queued
  end

  local function presentationValues(row)
    local values = {
      TOURNAMENT = row.tournament,
      RULE = row.rule,
      RANK = row.rank,
      OPPONENT = row.opponent,
      LOCATION = row.location,
      CHAMPION = row.champion,
      STEPS = row.steps,
    }
    for key, value in pairs(type(row.values) == "table" and row.values or {}) do
      values[key] = copy(value)
    end
    return values
  end

  function T.pendingPresentation(game)
    local s = T.state(game)
    if not s or T.readOnly then return nil end
    if s.invitation.pendingCall == true and s.invitation.shown ~= true then
      return {
        id = s.owner .. "|oak-invite",
        owner = s.owner,
        kind = "oakInvite",
        values = {},
      }
    end
    local active = s.active
    if active and (tonumber(active.hintShown) or 0)
        < (tonumber(active.hint) or 0) then
      local level = (tonumber(active.hintShown) or 0) + 1
      local opponent = active.opponent or {}
      local format = data.byId[active.formatId]
      return {
        id = active.token .. "|hint|" .. tostring(level),
        owner = s.owner,
        kind = level == 1 and "hint1" or "hint2",
        level = level,
        token = active.token,
        values = presentationValues({
          tournament = format and tr(format.name) or active.formatId,
          rule = format and tr(format.ruleText) or "",
          rank = active.rank,
          opponent = opponent.displayName,
          location = opponent.location,
        }),
      }
    end
    local notice = s.notices[1]
    if notice then
      local result = copy(notice)
      result.values = presentationValues(result)
      return result
    end
    return nil
  end

  function T.presentationText(game, receipt)
    if type(receipt) ~= "table" or type(receipt.kind) ~= "string" then
      return nil
    end
    local language = call(opts.language, game)
    if language ~= "de" then language = "en" end
    if (receipt.kind == "playerWin" or receipt.kind == "playerLoss")
        and type(data.renderOpponentDialogue) == "function" then
      local text = data.renderOpponentDialogue(receipt.class, receipt.kind,
        language, type(receipt.values) == "table" and receipt.values or {})
      if type(text) == "string" and text ~= "" then return text end
      local alias = receipt.kind == "playerWin" and "victory" or "defeat"
      return type(data.renderDialogue) == "function"
        and data.renderDialogue(alias, language,
          type(receipt.values) == "table" and receipt.values or {}) or nil
    end
    if type(data.renderDialogue) == "function" then
      return data.renderDialogue(receipt.kind, language,
        type(receipt.values) == "table" and receipt.values or {})
    end
    local row = data.dialogue and data.dialogue[receipt.kind]
    return row and row[language] or nil
  end

  function T.ackPresentation(game, id)
    local s = T.state(game)
    if not (s and type(id) == "string" and id ~= "" and not T.readOnly) then
      return false
    end
    if id == s.owner .. "|oak-invite" and s.invitation.pendingCall == true then
      s.invitation.pendingCall = nil
      s.invitation.shown = true
      persist(s)
      return true
    end
    local active = s.active
    if active then
      local level = (tonumber(active.hintShown) or 0) + 1
      if id ~= active.token .. "|hint|" .. tostring(level) then level = nil end
      if level and level == (tonumber(active.hintShown) or 0) + 1
          and level <= (tonumber(active.hint) or 0) then
        active.hintShown = level
        persist(s)
        return true
      end
    end
    for index, notice in ipairs(s.notices) do
      if notice.id == id then
        table.remove(s.notices, index)
        s.lifecycleSeen[id] = true
        persist(s)
        return true
      end
    end
    return false
  end

  local function rotate(s, game)
    local active = s.active
    local shift = hash(active.token .. ":field") % 3 - 1
    active.rank = clamp(active.rank + shift,
      data.championRank, data.initialRank)
    active.rotationIndex = active.rotationIndex + 1
    active.previousLocationId = active.opponent
      and active.opponent.locationId or active.previousLocationId
    assignment(s, game)
  end

  function T.advance(game, absoluteSteps)
    local s = T.state(game)
    if not (s and not T.readOnly) then return T.worldRankModel(game) end
    if absoluteSteps == nil then s.steps = s.steps + 1
    else s.steps = math.max(s.steps, math.floor(tonumber(absoluteSteps) or s.steps)) end

    if T.eligible(game) and not s.invitation.leagueQualified
        and hallCount(game) > s.invitation.baselineHallCount then
      s.invitation.leagueQualified = true
      s.invitation.hallTicket = hallCount(game)
      s.invitation.qualifiedAt = s.steps
      local span = data.timing.invitationMax - data.timing.invitationMin + 1
      s.invitation.due = s.steps + data.timing.invitationMin
        + hash(s.owner .. ":league:" .. s.invitation.hallTicket) % span
    end
    if T.eligible(game) and s.invitation.leagueQualified
        and not s.invitation.unlocked and s.invitation.due
        and s.steps >= s.invitation.due then
      if call(opts.markLegacyUnlocked, game, s.owner) == true then
        s.invitation.unlocked = true
        s.invitation.pendingCall = true
      end
    end

    local active = s.active
    if active then
      local idle = s.steps - active.inactivityAt
      if idle >= data.timing.expire then
        finishAttempt(s, "timeout", active.rank)
      else
        if idle >= data.timing.hint2 then active.hint = 2
        elseif idle >= data.timing.rotate then active.hint = 1 end
        while s.active and active.rotationIndex < #data.timing.rotations
            and idle >= data.timing.rotations[active.rotationIndex + 1] do
          rotate(s, game)
        end
      end
    end
    persist(s)
    return T.worldRankModel(game)
  end

  local function speciesDefinition(game, species)
    local provided = call(opts.speciesDefinition, game, species)
    if type(provided) == "table" then return provided end
    local gameData = game and game.data
    -- Gen1Recomp's authoritative battle definitions live in data.pokemon.
    -- data.species may also exist in a live imported client, but it is a
    -- different registry and need not carry canonical Dex/type fields. Keep
    -- it only as the compact-test/older-host fallback.
    local pokemon = gameData and gameData.pokemon
    if type(pokemon) == "table" and type(pokemon[species]) == "table" then
      return pokemon[species]
    end
    local fallback = gameData and gameData.species
    if type(fallback) == "table" and type(fallback[species]) == "table" then
      return fallback[species]
    end
  end

  local function definitionTypes(def)
    local result = {}
    local function add(value)
      value = tostring(value or ""):upper()
      if value == "PSYCHIC_TYPE" then value = "PSYCHIC" end
      if value ~= "" then result[value] = true end
    end
    for _, value in ipairs(type(def.types) == "table" and def.types or {}) do
      add(value)
    end
    for _, key in ipairs({ "type", "type1", "type2" }) do
      if type(def[key]) == "string" then add(def[key]) end
    end
    return result
  end

  -- Extended-species providers may retain their real National Dex number in
  -- sourceDex while using the Gen-I runtime slot in dex.  The tournament is
  -- generation-profile scoped, so immutable National/source authority wins
  -- over a patched runtime slot.
  local function canonicalDex(def)
    for _, key in ipairs({ "nationalDex", "sourceDex", "dexNumber", "dex" }) do
      local value = tonumber(type(def) == "table" and def[key])
      if value and value == math.floor(value) and value > 0 then return value end
    end
  end

  local function generationAllowed(def)
    if type(def) ~= "table" then return false end
    if def.originGeneration ~= nil then
      local generation = tonumber(def.originGeneration)
      if not generation or generation ~= math.floor(generation)
          or generation < 1 or generation > (opts.generationRules
            and opts.generationRules.speciesAvailable and 9 or 3) then return false end
    end
    if def.regionalForm ~= nil and def.regionalForm ~= false
        and tostring(def.regionalForm) ~= "" then return false end
    return true
  end

  local function partyFor(game)
    local party = game and game.save and game.save.party
      or game and game.party or {}
    return type(party) == "table" and party or {}
  end

  local function ownedGiftBattleCompatible(game, mon)
    local rules = opts.generationRules
    if not (type(rules) == "table"
        and type(rules.ownedGiftBattleCompatible) == "function") then
      return false
    end
    local ok, compatible = pcall(
      rules.ownedGiftBattleCompatible, game, mon)
    return ok and compatible == true
  end

  function T.validateTeam(game, formatId)
    local row = data.byId[formatId]
    if not row then return false, "format" end
    local party = partyFor(game)
    if #party < 1 or #party > 6 then return false, "size" end
    local allowed = {}
    for _, typeId in ipairs(row.allowedTypes) do allowed[typeId] = true end
    for _, mon in ipairs(party) do
      if type(mon) ~= "table" or type(mon.species) ~= "string"
          or mon.species == "" or mon.isEgg == true
          or tonumber(mon.hp) ~= nil and tonumber(mon.hp) <= 0 then
        return false, "member"
      end
      if row.noItems and (mon.item or mon.heldItem or mon.held_item) then
        return false, "item"
      end
      local def = speciesDefinition(game, mon.species)
      local dex = canonicalDex(def)
      local eventGift = ownedGiftBattleCompatible(game, mon)
      local profileAllowed = not opts.generationRules
        or not opts.generationRules.speciesAvailable
        or opts.generationRules.speciesAvailable(game,mon.species,def)==true
      if not eventGift and (not profileAllowed or not generationAllowed(def)
          or not dex or dex < 1 or dex > (opts.generationRules
            and opts.generationRules.speciesAvailable and 1025 or 386)) then
        return false, "species"
      end
      local types, matches = definitionTypes(def), false
      for typeId in pairs(allowed) do if types[typeId] then matches = true end end
      if row.johtoOnly then
        matches = (dex and dex >= 152 and dex <= 251) or matches
      end
      if not matches then return false, "type" end
      if type(mon.moves) == "table" then
        for _, move in ipairs(mon.moves) do
          local id = type(move) == "table" and move.id or move
          if type(id) ~= "string" or id == "" then return false, "move" end
        end
      end
    end
    return true
  end

  function T.scaledLevels(game, rank, seed, requestedSize)
    local strongest, count = 1, 0
    for _, mon in ipairs(partyFor(game)) do
      if type(mon) == "table" and mon.isEgg ~= true
          and (tonumber(mon.hp) == nil or tonumber(mon.hp) > 0) then
        strongest = math.max(strongest, clamp(mon.level, 1, 100))
        count = count + 1
      end
    end
    count = clamp(requestedSize or count, 1, 6)
    rank = clamp(rank, data.championRank, data.initialRank)
    local gap = math.floor(((rank - 1) / (data.initialRank - 1)) * 8 + 0.5)
    local levels = {}
    for index = 1, count do
      local jitter = hash(tostring(seed) .. ":level:" .. index) % 3 - 1
      local bonus = rank <= 3 and hash(tostring(seed) .. ":top:" .. index) % 3 or 0
      levels[index] = clamp(strongest - gap + jitter + bonus, 1, 100)
    end
    return levels
  end

  function T.install(game)
    T.game = game
    if optionEnabled() then T.state(game) end
    if T._installed then return true end
    T._installed = true
    mod.events:on("world.stepped", function(event)
      local live = event and event.game or T.game
      local link = live and (live.linkSession
        or live.linkNet and live.linkNet.closed ~= true)
      if live and not link then T.advance(live) end
    end)
    mod.events:on("save.loading", function()
      T.game = nil
      T.readOnly = false
    end)
    mod.events:on("save.created", function(event)
      T.game = event and event.game or T.game
      T.readOnly = false
      if T.game then T.state(T.game) end
    end)
    mod.events:on("save.loaded", function(event)
      T.game = event and event.game or T.game
      T.readOnly = false
      if T.game and optionEnabled() then T.state(T.game) end
    end)
    mod.events:on("mod.options_changed", function(event)
      if event and event.mod == mod.id and event.key == T.OPTION_KEY
          and event.value ~= false and T.game then T.state(T.game) end
    end)
    return true
  end

  if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
    opts.supportLog.registerSegment({
      segmentId=T.CARD_ID, cardId=T.CARD_ID, version="1.0.0",
      schema="kasc.optional-feature-card/v1", owner=T.OWNER,
      active=optionEnabled(), dependencyStatus="local-reviewed",
      providerStatus=optionEnabled() and "runtime-loaded" or "cold-disabled",
      buildReceiptId="ngplus_tournament_data.lua",
      rollbackReceiptId="revert-card-commit",
    })
  end

  T.data = data
  T.hash = hash
  return T
end
