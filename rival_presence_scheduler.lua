-- kasc.rival.presence-scheduler/v1
--
-- Deterministic, save-backed opportunity scheduler. This Card never spawns an
-- NPC: it owns only eligibility time, cooldowns, ABSENT decisions and durable
-- reservations consumed by rival_agenda_runtime.lua.

return function(mod, opts)
  opts = opts or {}
  local balance = assert(opts.balance,
    "rival presence scheduler requires reviewed balance")
  local support = opts.supportLog

  local S = {
    CARD_ID = "rival.presence-scheduler",
    OWNER = "kasc.rival.presence-scheduler/v1",
    VERSION = "1.0.0",
    SAVE_KEY = "life_of_rival_segmented",
    SAVE_SCHEMA = "kasc.life-of-rival.save/v1",
    OPTION_KEY = "life_of_rival_segmented",
    readOnly = false,
    futureSchema = nil,
  }

  local agendaProvider = opts.agendas
  local disabledLogged = false
  local eventSequence, eventRepeats = 0, {}
  local safeId

  local function integer(value, fallback, maximum)
    value = math.floor(tonumber(value) or fallback or 0)
    value = math.max(0, value)
    if maximum then value = math.min(maximum, value) end
    return value
  end

  local function exactInteger(value, minimum, maximum)
    return type(value) == "number" and value == math.floor(value)
      and value >= (minimum or 0)
      and (maximum == nil or value <= maximum)
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  -- Deliberately uses only exact, non-private identifiers. The hash is not a
  -- security primitive; it is a stable cross-reload decision source.
  local function stableHash(value, salt)
    local h = 104729 + integer(salt)
    value = tostring(value or "")
    for index = 1, #value do
      h = (h * 131 + value:byte(index) + index) % 2147483647
    end
    return h
  end

  local function digest(value)
    local parts = {}
    for index = 1, 8 do
      parts[index] = ("%08x"):format(stableHash(value, index * 7919))
    end
    return table.concat(parts)
  end

  local EVENT_REASONS = {
    ELIGIBLE="ELIGIBLE", FEATURE_DISABLED="FEATURE_DISABLED",
    MAP_INELIGIBLE="MAP_INELIGIBLE", MAP_INVALID="MAP_INELIGIBLE",
    MENU_ACTIVE="MAP_INELIGIBLE", AFK="MAP_INELIGIBLE",
    DOOR_LOOP="MAP_INELIGIBLE", STORY_BLOCKED="STORY_BLOCKED",
    QUEST_COLLISION="QUEST_BLOCKED", BATTLE_ACTIVE="BATTLE_BLOCKED",
    GLOBAL_COOLDOWN="GLOBAL_COOLDOWN",
    LOCATION_COOLDOWN="LOCATION_COOLDOWN",
    AGENDA_COOLDOWN="AGENDA_COOLDOWN", DENSITY_CAP="DENSITY_CAP",
    NO_VALID_AGENDA="NO_VALID_AGENDA", WEIGHT_MISS="WEIGHT_MISS",
    PITY_THRESHOLD="PITY_THRESHOLD",
    OPTIONAL_OWNER_ERROR="OPTIONAL_OWNER_ERROR",
  }

  local function actors(value)
    if value == "RED" or value == "BLUE" then return { value } end
    if value == "RED_BLUE" then return { "RED", "BLUE" } end
    return nil
  end

  local function emit(code, fields)
    if not (support and type(support.write) == "function") then return false end
    fields = type(fields) == "table" and fields or {}
    local event = {
      schema="kasc.life-of-rival.safe-event/v1",
      cardId=S.CARD_ID,
      cardVersion=S.VERSION,
      eventCode=code,
      cadence=fields.cadence == "TRANSITION" and "TRANSITION" or "DECISION",
      repeatCount=1,
    }
    event.reasonCode = EVENT_REASONS[fields.reason]
    event.mapId = safeId(fields.mapId, 2) and fields.mapId or nil
    event.agendaId = safeId(fields.sceneId, 3) and fields.sceneId or nil
    event.actorIds = actors(fields.target)
    if fields.status == "absent" then event.outcomeCode = "ABSENT"
    elseif fields.status == "reserved" then event.outcomeCode = "RESERVED"
    elseif fields.result == "COMPLETED" then event.outcomeCode = "COMPLETED"
    elseif fields.result == "CONTROLLED_ABORT" then
      event.outcomeCode = "CONTROLLED_ABORT"
    end
    event.cooldownCategory = (fields.cooldownCategory == "GLOBAL"
      or fields.cooldownCategory == "SPECTATOR_DUEL")
      and fields.cooldownCategory or nil

    local actorKey = event.actorIds and table.concat(event.actorIds, "+") or ""
    local repeatKey = table.concat({ code, event.reasonCode or "",
      event.mapId or "", event.agendaId or "", actorKey,
      event.outcomeCode or "", event.cooldownCategory or "" }, "|")
    local repeatCount = (eventRepeats[repeatKey] or 0) + 1
    eventRepeats[repeatKey] = repeatCount
    if repeatCount ~= 1 and repeatCount % 10 ~= 0 then return false end
    if repeatCount >= 10 then
      event.cadence, event.repeatCount = "THROTTLED_AGGREGATE", 10
    end
    eventSequence = eventSequence + 1
    event.sequence = eventSequence
    return support.write("kasc.life-of-rival.safe-event", event)
  end

  local function optionEnabled()
    if type(opts.enabled) == "function" then
      local ok, value = pcall(opts.enabled)
      return ok and value == true
    end
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, S.OPTION_KEY)
      return ok and value == true
    end
    return false
  end

  safeId = function(value, minimum)
    return type(value) == "string" and #value >= (minimum or 1)
      and #value <= 64
      and value:match("^[A-Z0-9_]+$") ~= nil
  end

  local ELIGIBILITY_REASONS = {
    ELIGIBLE=true, FEATURE_DISABLED=true, MAP_INELIGIBLE=true,
    MAP_INVALID=true, MENU_ACTIVE=true, AFK=true, BATTLE_ACTIVE=true,
    DOOR_LOOP=true, STORY_BLOCKED=true, QUEST_COLLISION=true,
    OPTIONAL_OWNER_ERROR=true,
  }

  local function eligible(game, mapId)
    if not optionEnabled() then
      if not disabledLogged then
        disabledLogged = true
        emit("ELIGIBILITY_EVALUATED", {
          status="absent", reason="FEATURE_DISABLED", mapId=mapId,
        })
      end
      return false, "FEATURE_DISABLED"
    end
    disabledLogged = false
    if type(opts.eligible) ~= "function" then return true, "ELIGIBLE" end
    local ok, value, reason = pcall(opts.eligible, game, mapId)
    if not ok or value ~= true then
      reason = type(reason) == "string" and reason or "MAP_INELIGIBLE"
      return false, ELIGIBILITY_REASONS[reason]
        and reason or "MAP_INELIGIBLE"
    end
    return true, "ELIGIBLE"
  end

  local function freshState()
    return {
      schema = S.SAVE_SCHEMA,
      v1 = {
        enabled = true,
        scheduler = {
          opportunityCount = 0,
          failedEligibleOpportunities = 0,
          eligibleExplorationSeconds = 0,
          eligibleMapTransitionsSinceEncounter = 0,
          lastResolvedOpportunity = 0,
          lastResolvedAt = 0,
          lastEncounterType = "NONE",
          lastAgendaId = nil,
          lastEligibleMapId = nil,
          previousEligibleMapId = nil,
          nextOpportunityAt = 1200,
          ambientAppearanceClocks = {},
          cooldowns = {
            globalUntil = 0,
            locationUntil = {},
            agendaUntil = {},
            spectatorDuelUntil = 0,
          },
          reserved = nil,
        },
        agenda = { safeResume = nil },
        dialogue = { antiRepeat = { RED = {}, BLUE = {} } },
        scripted = { completedEventIds = {}, safeResume = nil },
      },
    }
  end

  local ENCOUNTER_TYPES = {
    NONE=true, SINGLE_RED=true, SINGLE_BLUE=true, DOUBLE=true,
    TRIO=true, SPECTATOR_DUEL=true,
  }

  local function cleanClockMap(value, minimumIdLength)
    local out = {}
    for key, clock in pairs(type(value) == "table" and value or {}) do
      if safeId(key, minimumIdLength) then
        out[key] = integer(clock)
      end
    end
    return out
  end

  local RESERVATION_FIELDS = {
    schema=true, reservationId=true, opportunityOrdinal=true, agendaId=true,
    actorSet=true, mapId=true, eligibilityDigest=true,
    eligibleExplorationSecond=true, failedOpportunityCount=true, pity=true,
    nextSafeMapOnly=true, appearanceClass=true,
  }

  local function normalizedReservation(value)
    if type(value) ~= "table" then return nil end
    for key in pairs(value) do
      if not RESERVATION_FIELDS[key] then return nil end
    end
    if value.schema ~= "rival.reservation/v1"
        or type(value.reservationId) ~= "string"
        or #value.reservationId < 8 or #value.reservationId > 96
        or not value.reservationId:match("^[A-Z0-9_:-]+$")
        or not exactInteger(value.opportunityOrdinal, 1)
        or not safeId(value.agendaId, 3)
        or not safeId(value.mapId, 2)
        or type(value.eligibilityDigest) ~= "string"
        or #value.eligibilityDigest ~= 64
        or not value.eligibilityDigest:match("^[a-f0-9]+$")
        or not exactInteger(value.eligibleExplorationSecond, 0)
        or not exactInteger(value.failedOpportunityCount, 0,
          balance.pity.maxFailedEligibleOpportunities)
        or (value.pity ~= true and value.pity ~= false)
        or value.nextSafeMapOnly ~= true
        or (value.appearanceClass ~= "AMBIENT"
          and value.appearanceClass ~= "SPECTATOR_DUEL")
        or (value.actorSet ~= "RED" and value.actorSet ~= "BLUE"
          and value.actorSet ~= "RED_BLUE")
        or (value.pity == true and value.actorSet == "RED_BLUE")
        or (value.appearanceClass == "SPECTATOR_DUEL"
          and value.actorSet ~= "RED_BLUE") then
      return nil
    end
    local out = {}
    for key in pairs(RESERVATION_FIELDS) do out[key] = value[key] end
    return out
  end

  local function normalize(root)
    if type(root) ~= "table" or root.schema ~= S.SAVE_SCHEMA
        or type(root.v1) ~= "table" then
      S.readOnly = type(root) == "table"
      S.futureSchema = type(root) == "table" and root.schema or nil
      return nil
    end
    S.readOnly, S.futureSchema = false, nil
    local v1 = root.v1
    -- Missing or malformed enablement is fail-closed. A supported state is
    -- created with this flag set only after the external master option has
    -- explicitly returned true.
    v1.enabled = v1.enabled == true
    local scheduler = type(v1.scheduler) == "table"
      and v1.scheduler or freshState().v1.scheduler
    v1.scheduler = scheduler
    for _, key in ipairs({ "opportunityCount", "failedEligibleOpportunities",
      "eligibleExplorationSeconds", "eligibleMapTransitionsSinceEncounter",
      "lastResolvedOpportunity", "lastResolvedAt", "nextOpportunityAt" }) do
      scheduler[key] = integer(scheduler[key])
    end
    scheduler.failedEligibleOpportunities = math.min(
      balance.pity.maxFailedEligibleOpportunities,
      scheduler.failedEligibleOpportunities)
    scheduler.lastEncounterType = ENCOUNTER_TYPES[scheduler.lastEncounterType]
      and scheduler.lastEncounterType or "NONE"
    scheduler.lastAgendaId = safeId(scheduler.lastAgendaId, 3)
      and scheduler.lastAgendaId or nil
    scheduler.lastEligibleMapId = safeId(scheduler.lastEligibleMapId, 2)
      and scheduler.lastEligibleMapId or nil
    scheduler.previousEligibleMapId =
      safeId(scheduler.previousEligibleMapId, 2)
      and scheduler.previousEligibleMapId or nil
    local recent = {}
    for _, clock in ipairs(type(scheduler.ambientAppearanceClocks) == "table"
        and scheduler.ambientAppearanceClocks or {}) do
      recent[#recent + 1] = integer(clock)
    end
    table.sort(recent)
    while #recent > balance.density.maxAmbientAppearances do
      table.remove(recent, 1)
    end
    scheduler.ambientAppearanceClocks = recent
    scheduler.cooldowns = type(scheduler.cooldowns) == "table"
      and scheduler.cooldowns or {}
    scheduler.cooldowns.globalUntil = integer(scheduler.cooldowns.globalUntil)
    scheduler.cooldowns.spectatorDuelUntil = integer(
      scheduler.cooldowns.spectatorDuelUntil)
    scheduler.cooldowns.locationUntil = cleanClockMap(
      scheduler.cooldowns.locationUntil, 2)
    scheduler.cooldowns.agendaUntil = cleanClockMap(
      scheduler.cooldowns.agendaUntil, 3)
    scheduler.reserved = normalizedReservation(scheduler.reserved)
    v1.agenda = type(v1.agenda) == "table" and v1.agenda
      or { safeResume=nil }
    v1.dialogue = type(v1.dialogue) == "table" and v1.dialogue
      or { antiRepeat={ RED={}, BLUE={} } }
    v1.dialogue.antiRepeat = type(v1.dialogue.antiRepeat) == "table"
      and v1.dialogue.antiRepeat or { RED={}, BLUE={} }
    v1.dialogue.antiRepeat.RED = type(v1.dialogue.antiRepeat.RED) == "table"
      and v1.dialogue.antiRepeat.RED or {}
    v1.dialogue.antiRepeat.BLUE = type(v1.dialogue.antiRepeat.BLUE) == "table"
      and v1.dialogue.antiRepeat.BLUE or {}
    v1.scripted = type(v1.scripted) == "table" and v1.scripted
      or { completedEventIds={}, safeResume=nil }
    v1.scripted.completedEventIds =
      type(v1.scripted.completedEventIds) == "table"
      and v1.scripted.completedEventIds or {}
    return root
  end

  local function savedState()
    if not (mod.save and type(mod.save.get) == "function") then return nil end
    local ok, value = pcall(mod.save.get, mod.save, S.SAVE_KEY)
    return ok and value or nil
  end

  local function persist(root)
    if S.readOnly or not (mod.save and type(mod.save.set) == "function") then
      return false
    end
    local ok, result = pcall(mod.save.set, mod.save, S.SAVE_KEY, root)
    return ok and result ~= false
  end

  function S.state(create)
    local raw = savedState()
    if raw == nil then
      if create == false or not optionEnabled() then return nil end
      raw = freshState()
    else
      -- Save providers may return a live table. Work on a detached copy so a
      -- failed persist cannot mutate durable state by aliasing.
      raw = copy(raw)
    end
    local root = normalize(raw)
    return root
  end

  function S.setAgendaProvider(provider)
    if type(provider) ~= "function" then return false end
    agendaProvider = provider
    return true
  end

  local function nowOf(root)
    return root.v1.scheduler.eligibleExplorationSeconds
  end

  function S.observe(game, mapId, seconds)
    if not safeId(mapId, 2) then return false end
    local ok = eligible(game, mapId)
    if not ok then return false end
    seconds = math.max(0, math.min(2, tonumber(seconds) or 1))
    if seconds <= 0 then return false end
    local root = S.state(true)
    if not root then return false end
    local scheduler = root.v1.scheduler
    scheduler.eligibleExplorationSeconds = integer(
      scheduler.eligibleExplorationSeconds + seconds)
    return persist(root)
  end

  local function filteredCandidates(rows, scheduler, mapId, now)
    local out = {}
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
      local id = type(row) == "table" and row.agendaId
      local actorSet = row and row.actorSet
      local appearanceClass = row and row.appearanceClass
      if row and row.schema == "rival.scheduler-candidate/v1"
          and safeId(id, 3)
          and (actorSet == "RED" or actorSet == "BLUE"
            or actorSet == "RED_BLUE")
          and (appearanceClass == "AMBIENT"
            or appearanceClass == "SPECTATOR_DUEL")
          and not (appearanceClass == "SPECTATOR_DUEL"
            and actorSet ~= "RED_BLUE")
          and (row.curatedForPity == true
            or row.curatedForPity == false)
          and exactInteger(row.weightBasisPoints, 1, 10000)
          and row.mapId == mapId
          and scheduler.lastAgendaId ~= id
          and integer(scheduler.cooldowns.locationUntil[mapId]) <= now
          and integer(scheduler.cooldowns.agendaUntil[id]) <= now
          and (appearanceClass ~= "SPECTATOR_DUEL"
            or scheduler.cooldowns.spectatorDuelUntil <= now) then
        out[#out + 1] = row
      end
    end
    return out
  end

  local function densityFull(scheduler, now)
    local recent = {}
    for _, clock in ipairs(scheduler.ambientAppearanceClocks) do
      if now - clock < balance.density.rollingWindowSeconds then
        recent[#recent + 1] = clock
      end
    end
    scheduler.ambientAppearanceClocks = recent
    return #recent >= balance.density.maxAmbientAppearances
  end

  local function chooseWeighted(rows, seed)
    local total = 0
    for _, row in ipairs(rows) do total = total + math.max(1,
      integer(row.weightBasisPoints, 1)) end
    if total <= 0 then return nil end
    local roll = stableHash(seed, total) % total
    for _, row in ipairs(rows) do
      roll = roll - math.max(1, integer(row.weightBasisPoints, 1))
      if roll < 0 then return row end
    end
    return rows[#rows]
  end

  local function reserve(root, row, mapId, pity)
    local scheduler = root.v1.scheduler
    local ordinal = scheduler.opportunityCount
    local id = ("RIVAL:%06d:%s"):format(ordinal, row.agendaId)
    local reservation = {
      schema = "rival.reservation/v1",
      reservationId = id,
      opportunityOrdinal = ordinal,
      agendaId = row.agendaId,
      actorSet = row.actorSet,
      mapId = mapId,
      eligibilityDigest = digest(table.concat({ id, mapId, row.actorSet }, ":")),
      eligibleExplorationSecond = scheduler.eligibleExplorationSeconds,
      failedOpportunityCount = scheduler.failedEligibleOpportunities,
      pity = pity == true,
      nextSafeMapOnly = true,
      appearanceClass = row.appearanceClass,
    }
    scheduler.reserved = reservation
    return reservation
  end

  function S.onMapEntered(game, mapId)
    if not safeId(mapId, 2) then
      emit("ELIGIBILITY_EVALUATED", {
        status="absent", reason="MAP_INVALID",
      })
      return nil, "MAP_INVALID"
    end
    local isEligible, reason = eligible(game, mapId)
    emit("ELIGIBILITY_EVALUATED", {
      status=isEligible and "eligible" or "absent", reason=reason,
      mapId=mapId,
    })
    if not isEligible then return nil, reason end
    if type(agendaProvider) ~= "function" then
      emit("ABSENT_SELECTED", { status="absent",
        reason="OPTIONAL_OWNER_ERROR", mapId=mapId })
      return nil, "OPTIONAL_OWNER_ERROR"
    end
    local existing = S.state(false)
    if S.readOnly then return nil, "SAVE_UNAVAILABLE" end
    local okProvider, rows = pcall(agendaProvider, game, mapId, existing)
    if not okProvider then
      emit("ABSENT_SELECTED", { status="absent",
        reason="OPTIONAL_OWNER_ERROR", mapId=mapId })
      return nil, "OPTIONAL_OWNER_ERROR"
    end
    local root = S.state(true)
    if not root then return nil, "SAVE_UNAVAILABLE" end
    local scheduler, now = root.v1.scheduler, nowOf(root)
    if scheduler.reserved then return copy(scheduler.reserved), "RESERVED" end

    -- A-B-A door loops do not advance the map-transition gate.
    if scheduler.lastEligibleMapId ~= mapId then
      if scheduler.previousEligibleMapId ~= mapId then
        scheduler.eligibleMapTransitionsSinceEncounter = integer(
          scheduler.eligibleMapTransitionsSinceEncounter) + 1
      end
      scheduler.previousEligibleMapId = scheduler.lastEligibleMapId
      scheduler.lastEligibleMapId = mapId
    end

    if scheduler.cooldowns.globalUntil > now then
      if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
      return nil, "GLOBAL_COOLDOWN"
    end
    if scheduler.eligibleMapTransitionsSinceEncounter
        < balance.postEncounterGuard.minEligibleMapTransitions then
      if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
      return nil, "MAP_TRANSITION_GUARD"
    end
    if now < scheduler.nextOpportunityAt then
      if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
      return nil, "TIME_GUARD"
    end
    if densityFull(scheduler, now) then
      scheduler.nextOpportunityAt = now + balance.opportunity.intervalSeconds
      if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
      emit("ABSENT_SELECTED", { status="absent", reason="DENSITY_CAP",
        mapId=mapId })
      return nil, "DENSITY_CAP"
    end
    local candidates = filteredCandidates(rows, scheduler, mapId, now)
    if #candidates == 0 then
      -- Provider/eligibility failures must not consume an opportunity.
      if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
      emit("ABSENT_SELECTED", { status="absent", reason="NO_VALID_AGENDA",
        mapId=mapId })
      return nil, "NO_VALID_AGENDA"
    end

    local sinceEncounter = now - integer(scheduler.lastResolvedAt)
    local pity = scheduler.failedEligibleOpportunities
        >= balance.pity.maxFailedEligibleOpportunities
      or sinceEncounter >= balance.pity.maxEligibleExplorationSeconds
    if pity then
      local curatedSingles = {}
      for _, row in ipairs(candidates) do
        if row.curatedForPity == true and row.actorSet ~= "RED_BLUE" then
          curatedSingles[#curatedSingles + 1] = row
        end
      end
      candidates = curatedSingles
      if #candidates == 0 then
        if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
        emit("ABSENT_SELECTED", { status="absent",
          reason="NO_VALID_AGENDA", mapId=mapId })
        return nil, "NO_VALID_AGENDA"
      end
    end
    scheduler.opportunityCount = scheduler.opportunityCount + 1
    local ordinal = scheduler.opportunityCount
    local chance = math.min(balance.opportunity.maximumBasisPoints,
      balance.opportunity.initialBasisPoints
        + scheduler.failedEligibleOpportunities
          * balance.opportunity.failedIncrementBasisPoints)
    local roll = stableHash(mapId .. ":" .. tostring(now), ordinal) % 10000
    if not pity and roll >= chance then
      scheduler.failedEligibleOpportunities = math.min(
        balance.pity.maxFailedEligibleOpportunities,
        scheduler.failedEligibleOpportunities + 1)
      scheduler.nextOpportunityAt = math.min(
        now + balance.opportunity.intervalSeconds,
        integer(scheduler.lastResolvedAt)
          + balance.pity.maxEligibleExplorationSeconds)
      if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
      emit("ABSENT_SELECTED", { status="absent", reason="WEIGHT_MISS",
        mapId=mapId, count=scheduler.failedEligibleOpportunities })
      return nil, "WEIGHT_MISS"
    end

    local singles, doubles = {}, {}
    for _, row in ipairs(candidates) do
      if row.actorSet == "RED_BLUE" then doubles[#doubles + 1] = row
      else singles[#singles + 1] = row end
    end
    local wantDouble = not pity and #doubles > 0
      and stableHash(mapId .. ":double", ordinal) % 10000
        < balance.doubleAppearanceBasisPoints
    local pool = wantDouble and doubles or singles
    if #pool == 0 then pool = candidates end
    local row = chooseWeighted(pool, mapId .. ":" .. tostring(ordinal))
    if pity and row and row.actorSet == "RED_BLUE" then
      row = singles[1]
    end
    if not row then
      scheduler.nextOpportunityAt = now + balance.opportunity.intervalSeconds
      if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
      return nil, "NO_VALID_AGENDA"
    end
    local reservation = reserve(root, row, mapId, pity)
    if not persist(root) then return nil, "SAVE_UNAVAILABLE" end
    if pity then
      emit("PITY_RESERVED", { status="reserved", reason="PITY_THRESHOLD",
        mapId=mapId, sceneId=row.agendaId, target=row.actorSet })
    else
      emit("AGENDA_RESERVED", { status="reserved", reason="ELIGIBLE",
        mapId=mapId, sceneId=row.agendaId, target=row.actorSet })
    end
    return copy(reservation), pity and "PITY_RESERVED" or "RESERVED"
  end

  function S.claim(mapId)
    local root = S.state(false)
    local reservation = root and root.v1.scheduler.reserved
    if not (reservation and reservation.mapId == mapId) then return nil end
    return copy(reservation)
  end

  function S.resolve(reservation, outcome)
    local root = S.state(false)
    local scheduler = root and root.v1.scheduler
    if not (scheduler and scheduler.reserved and reservation
        and scheduler.reserved.reservationId == reservation.reservationId) then
      return false, "STALE_RESERVATION"
    end
    local now = nowOf(root)
    local appearanceClass = scheduler.reserved.appearanceClass
    local agendaId, mapId = scheduler.reserved.agendaId,
      scheduler.reserved.mapId
    scheduler.lastResolvedOpportunity = scheduler.opportunityCount
    scheduler.lastResolvedAt = now
    scheduler.lastAgendaId = agendaId
    scheduler.lastEncounterType = appearanceClass == "SPECTATOR_DUEL"
        and "SPECTATOR_DUEL"
      or (scheduler.reserved.actorSet == "RED_BLUE" and "DOUBLE"
        or "SINGLE_" .. scheduler.reserved.actorSet)
    scheduler.failedEligibleOpportunities = 0
    scheduler.eligibleMapTransitionsSinceEncounter = 0
    scheduler.nextOpportunityAt = now + balance.postEncounterGuard.minSeconds
      + stableHash(agendaId, scheduler.opportunityCount)
        % (balance.postEncounterGuard.maxSeconds
          - balance.postEncounterGuard.minSeconds + 1)
    scheduler.cooldowns.globalUntil = scheduler.nextOpportunityAt
    scheduler.cooldowns.locationUntil[mapId] = now
      + balance.cooldowns.locationMinSeconds
      + stableHash(mapId, scheduler.opportunityCount)
        % (balance.cooldowns.locationMaxSeconds
          - balance.cooldowns.locationMinSeconds + 1)
    scheduler.cooldowns.agendaUntil[agendaId] =
      scheduler.cooldowns.locationUntil[mapId]
    if appearanceClass == "SPECTATOR_DUEL" then
      scheduler.cooldowns.spectatorDuelUntil = now
        + balance.cooldowns.spectatorDuelSeconds
    end
    scheduler.ambientAppearanceClocks[#scheduler.ambientAppearanceClocks + 1]
      = now
    while #scheduler.ambientAppearanceClocks
        > balance.density.maxAmbientAppearances do
      table.remove(scheduler.ambientAppearanceClocks, 1)
    end
    scheduler.reserved = nil
    if not persist(root) then return false, "SAVE_UNAVAILABLE" end
    emit("COOLDOWN_SET", { status="active", result=outcome or "COMPLETED",
      mapId=mapId, sceneId=agendaId,
      cooldownCategory=appearanceClass == "SPECTATOR_DUEL"
        and "SPECTATOR_DUEL" or "GLOBAL" })
    return true
  end

  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      cardId=S.CARD_ID, version=S.VERSION,
      schema="kasc.life-of-rival.card-runtime/v1", owner=S.OWNER,
      active=optionEnabled(), dependencyStatus="ready",
      providerStatus="active", buildReceiptId="rival-presence-runtime-66",
      rollbackReceiptId="KASC_66_LIFE_OF_RIVAL_SEGMENT_ROLLBACK",
    })
  end

  return S
end
