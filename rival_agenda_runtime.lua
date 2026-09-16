-- kasc.rival.agenda-runtime/v1
--
-- Optional-scene state machine. This Card never calculates a path, owns a map,
-- renders dialogue or starts a battle. It drives symbolic goals through narrow
-- lease/lifecycle adapters and persists only reviewed safe nodes.

return function(mod, opts)
  opts = opts or {}
  local catalog = assert(opts.catalog, "rival agenda runtime requires catalog")
  local reservations = assert(opts.reservations,
    "rival agenda runtime requires reservation adapter")
  local leases = assert(opts.leases,
    "rival agenda runtime requires optional NPC lease adapter")
  local lifecycle = assert(opts.mapLifecycle,
    "rival agenda runtime requires map lifecycle adapter")
  local support = opts.supportLog

  local A = {
    CARD_ID = "rival.agenda-runtime",
    OWNER = "kasc.rival.agenda-runtime/v1",
    VERSION = "1.0.0",
    SAVE_KEY = "life_of_rival_segmented",
    SAVE_SCHEMA = "kasc.life-of-rival.save/v1",
    active = nil,
    readOnly = false,
  }

  local STATES = {
    ELIGIBILITY_CHECK=true, ABSENT=true, RESERVED=true, ARRIVING=true,
    TRAVELLING_TO_GOAL=true, PERFORMING_AGENDA=true,
    AVAILABLE_FOR_TALK=true, CHALLENGE_OFFERED=true, BATTLE=true,
    RESOLVED=true, DEPARTING=true, COOLDOWN=true,
  }
  local SAFE_NODES = {
    RESERVED=true, PERFORMING_AGENDA=true, AVAILABLE_FOR_TALK=true,
    RESOLVED=true, DEPARTING=true,
  }
  local TRANSITIONS = {
    ELIGIBILITY_CHECK={ ABSENT=true, RESERVED=true },
    RESERVED={ ARRIVING=true },
    ARRIVING={ TRAVELLING_TO_GOAL=true, DEPARTING=true },
    TRAVELLING_TO_GOAL={ PERFORMING_AGENDA=true, AVAILABLE_FOR_TALK=true,
      DEPARTING=true },
    PERFORMING_AGENDA={ AVAILABLE_FOR_TALK=true, DEPARTING=true },
    AVAILABLE_FOR_TALK={ PERFORMING_AGENDA=true, CHALLENGE_OFFERED=true,
      RESOLVED=true, DEPARTING=true },
    CHALLENGE_OFFERED={ BATTLE=true, AVAILABLE_FOR_TALK=true, RESOLVED=true,
      DEPARTING=true },
    BATTLE={ RESOLVED=true, DEPARTING=true },
    RESOLVED={ DEPARTING=true },
    DEPARTING={ COOLDOWN=true },
  }
  local MOVEMENT_STATES = { ARRIVING=true, TRAVELLING_TO_GOAL=true,
    DEPARTING=true }
  local EVENT_CODES = {
    STATE_TRANSITION=true, ROUTE_BLOCKED=true, ROUTE_REPLAN=true,
    SAFE_STANDPOINT=true, CONTROLLED_DEPARTURE=true,
    RESTORE_SAFE_NODE=true, CONTROLLED_ABORT=true,
  }
  local eventSequence, repeats = 0, {}

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function safeId(value, minimum)
    return type(value) == "string" and #value >= (minimum or 2)
      and #value <= 64 and value:match("^[A-Z0-9_]+$") ~= nil
  end

  local function optionEnabled()
    if type(opts.enabled) == "function" then
      local ok, value = pcall(opts.enabled)
      return ok and value == true
    end
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options,
        "life_of_rival_segmented")
      return ok and value == true
    end
    return false
  end

  local function emit(code, fields)
    if not EVENT_CODES[code]
        or not (support and type(support.write) == "function") then
      return false
    end
    fields = type(fields) == "table" and fields or {}
    local event = {
      schema="kasc.life-of-rival.safe-event/v1",
      cardId=A.CARD_ID, cardVersion=A.VERSION, eventCode=code,
      cadence="TRANSITION", repeatCount=1,
    }
    event.agendaId = safeId(fields.agendaId, 3) and fields.agendaId or nil
    event.mapId = safeId(fields.mapId, 2) and fields.mapId or nil
    event.actorIds = fields.actorSet == "RED_BLUE" and { "RED", "BLUE" }
      or ((fields.actorSet == "RED" or fields.actorSet == "BLUE")
        and { fields.actorSet } or nil)
    event.fromState = STATES[fields.fromState] and fields.fromState or nil
    event.toState = STATES[fields.toState] and fields.toState or nil
    event.reasonCode = fields.reason == "ROUTE_BLOCKED" and "ROUTE_BLOCKED"
      or (fields.reason == "REPLAN_LIMIT" and "REPLAN_LIMIT"
      or (fields.reason == "MAP_EXIT" and "MAP_EXIT"
      or (fields.reason == "LOAD_RESTORE" and "LOAD_RESTORE"
      or (fields.reason == "OPTIONAL_OWNER_ERROR"
        and "OPTIONAL_OWNER_ERROR" or nil))))
    event.outcomeCode = fields.outcome == "COMPLETED" and "COMPLETED"
      or (fields.outcome == "CONTROLLED_ABORT" and "CONTROLLED_ABORT" or nil)
    local key = table.concat({ code, event.agendaId or "", event.mapId or "",
      event.fromState or "", event.toState or "", event.reasonCode or "" }, "|")
    repeats[key] = (repeats[key] or 0) + 1
    if repeats[key] ~= 1 and repeats[key] % 10 ~= 0 then return false end
    if repeats[key] >= 10 then
      event.cadence, event.repeatCount = "THROTTLED_AGGREGATE", 10
    end
    eventSequence = eventSequence + 1
    event.sequence = eventSequence
    return support.write("kasc.life-of-rival.safe-event", event)
  end

  local function savedRoot()
    if not (mod.save and type(mod.save.get) == "function") then return nil end
    local ok, value = pcall(mod.save.get, mod.save, A.SAVE_KEY)
    return ok and value or nil
  end

  local function normalizedRoot()
    local raw = savedRoot()
    if type(raw) ~= "table" or raw.schema ~= A.SAVE_SCHEMA
        or type(raw.v1) ~= "table" then
      A.readOnly = raw ~= nil
      return nil
    end
    A.readOnly = false
    local root = copy(raw)
    if root.v1.enabled ~= true or type(root.v1.agenda) ~= "table" then
      return nil
    end
    local resume = root.v1.agenda.safeResume
    if resume ~= nil and (type(resume) ~= "table"
        or not safeId(resume.agendaId, 3)
        or not SAFE_NODES[resume.safeNode]
        or type(resume.resolutionSeed) ~= "number"
        or resume.resolutionSeed < 0
        or resume.resolutionSeed ~= math.floor(resume.resolutionSeed)) then
      root.v1.agenda.safeResume = nil
    end
    return root
  end

  local function persist(root)
    if A.readOnly or not (mod.save and type(mod.save.set) == "function") then
      return false
    end
    local ok, result = pcall(mod.save.set, mod.save, A.SAVE_KEY, root)
    return ok and result ~= false
  end

  local function persistNode(active, node)
    if not SAFE_NODES[node] then return false end
    local root = normalizedRoot()
    if not root then return false end
    root.v1.agenda.safeResume = {
      agendaId=active.agenda.agendaId,
      safeNode=node,
      resolutionSeed=active.resolutionSeed,
    }
    return persist(root)
  end

  local function clearNode()
    local root = normalizedRoot()
    if not root then return false end
    root.v1.agenda.safeResume = nil
    return persist(root)
  end

  local function currentMap(game)
    if type(lifecycle.currentMapId) ~= "function" then return nil end
    local ok, value = pcall(lifecycle.currentMapId, game)
    return ok and safeId(value, 2) and value or nil
  end

  local function validReservation(value)
    return type(value) == "table" and value.schema == "rival.reservation/v1"
      and type(value.reservationId) == "string"
      and safeId(value.agendaId, 3) and safeId(value.mapId, 2)
      and (value.actorSet == "RED" or value.actorSet == "BLUE"
        or value.actorSet == "RED_BLUE")
      and value.nextSafeMapOnly == true
  end

  local function transition(active, nextState, goalId)
    if not (active and TRANSITIONS[active.state]
        and TRANSITIONS[active.state][nextState]) then
      return false, "INVALID_TRANSITION"
    end
    if MOVEMENT_STATES[nextState] and not safeId(goalId, 2) then
      return false, "MISSING_GOAL"
    end
    local previous = active.state
    active.state, active.goalId = nextState, goalId
    emit("STATE_TRANSITION", { agendaId=active.agenda.agendaId,
      mapId=active.mapId, actorSet=active.agenda.actorSet,
      fromState=previous, toState=nextState })
    return true
  end

  local function release(active)
    if active and active.lease and type(leases.release) == "function" then
      pcall(leases.release, active.lease)
    end
    if A.active == active then A.active = nil end
  end

  local function resolveReservation(active, outcome)
    if type(reservations.resolve) ~= "function" then return false end
    local ok, value = pcall(reservations.resolve, active.reservation,
      outcome or "COMPLETED")
    return ok and value ~= false
  end

  local function controlledAbort(active, reason)
    if not active then return false end
    emit("CONTROLLED_ABORT", { agendaId=active.agenda.agendaId,
      mapId=active.mapId, actorSet=active.agenda.actorSet,
      reason=reason or "OPTIONAL_OWNER_ERROR", outcome="CONTROLLED_ABORT" })
    resolveReservation(active, "CONTROLLED_ABORT")
    clearNode()
    release(active)
    return true
  end

  local function callLease(active, method, endpoint)
    local fn = leases[method]
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, active.lease, copy(endpoint), {
      agendaId=active.agenda.agendaId,
      actorSet=active.agenda.actorSet,
      mapId=active.mapId,
    })
    return ok and value ~= false
  end

  function A.schedulerCandidates(game, mapId)
    if not optionEnabled() then return {} end
    local ok, rows = pcall(catalog.schedulerCandidates, game, mapId)
    return ok and type(rows) == "table" and rows or {}
  end

  function A.context()
    local active = A.active
    if not active then return nil end
    return copy({
      schema="rival.agenda-context/v1",
      agendaId=active.agenda.agendaId,
      interactionSetId=active.agenda.interactionSetId,
      actorSet=active.agenda.actorSet,
      mapId=active.mapId,
      state=active.state,
      goalId=active.goalId,
      talkable=active.state == "AVAILABLE_FOR_TALK",
      result=active.result,
    })
  end

  function A.interactionWindow(actor)
    local active = A.active
    if not active or (actor ~= "RED" and actor ~= "BLUE") then return nil end
    local allowed = active.agenda.actorSet == actor
      or active.agenda.actorSet == "RED_BLUE"
    if not allowed then return nil end
    return {
      schema="rival.interaction-window/v1",
      actor=actor, agendaId=active.agenda.agendaId,
      state=active.state,
      talkable=active.state == "AVAILABLE_FOR_TALK",
      shortUninterruptible=active.shortUninterruptible == true,
    }
  end

  function A.start(game, reservation)
    if A.active or not optionEnabled() or not validReservation(reservation)
        or currentMap(game) ~= reservation.mapId then return false end
    local agenda = catalog.get(reservation.agendaId)
    if not (agenda and agenda.actorSet == reservation.actorSet
        and agenda.eligibleMapIds[1] == reservation.mapId) then return false end
    local active = {
      game=game, reservation=copy(reservation), agenda=agenda,
      mapId=reservation.mapId, state="ELIGIBILITY_CHECK",
      resolutionSeed=reservation.opportunityOrdinal or 0,
      replanCount=0, result=nil, shortUninterruptible=false,
    }
    A.active = active
    transition(active, "RESERVED")
    if not persistNode(active, "RESERVED") then
      A.active = nil
      return false
    end
    if type(leases.acquire) ~= "function" then
      return controlledAbort(active, "OPTIONAL_OWNER_ERROR")
    end
    local ok, lease = pcall(leases.acquire, game, copy(agenda),
      copy(reservation))
    if not ok or lease == nil or lease == false then
      return controlledAbort(active, "OPTIONAL_OWNER_ERROR")
    end
    active.lease = lease
    transition(active, "ARRIVING", agenda.arrival.pointId)
    if not callLease(active, "arrive", agenda.arrival) then
      return A.routeBlocked("ARRIVAL")
    end
    return true
  end

  function A.claimAndStart(game)
    if not optionEnabled() or type(reservations.claim) ~= "function" then
      return false
    end
    local mapId = currentMap(game)
    local ok, reservation = pcall(reservations.claim, mapId)
    return ok and A.start(game, reservation) or false
  end

  function A.arrived()
    local active = A.active
    if not active or active.state ~= "ARRIVING" then return false end
    local goal = active.agenda.goals[1]
    transition(active, "TRAVELLING_TO_GOAL", goal.goalId)
    if not callLease(active, "travel", goal) then
      return A.routeBlocked("GOAL")
    end
    return true
  end

  function A.goalReached()
    local active = A.active
    if not active or active.state ~= "TRAVELLING_TO_GOAL" then return false end
    transition(active, "PERFORMING_AGENDA")
    active.goalId = active.agenda.goals[1].goalId
    if not persistNode(active, "PERFORMING_AGENDA") then
      return controlledAbort(active, "OPTIONAL_OWNER_ERROR")
    end
    return true
  end

  function A.setShortUninterruptible(value)
    if not A.active then return false end
    A.active.shortUninterruptible = value == true
    return true
  end

  function A.agendaPerformed()
    local active = A.active
    if not active or active.state ~= "PERFORMING_AGENDA" then return false end
    transition(active, "AVAILABLE_FOR_TALK")
    return persistNode(active, "AVAILABLE_FOR_TALK")
  end

  function A.pauseForInteraction(actor)
    local window = A.interactionWindow(actor)
    if not (window and window.talkable) then return nil end
    A.active.pausedBy = actor
    return {
      schema="rival.agenda-pause-token/v1",
      agendaId=A.active.agenda.agendaId,
      actor=actor,
      sequence=A.active.resolutionSeed,
    }
  end

  function A.resumeFromInteraction(token, resolution)
    local active = A.active
    if not (active and type(token) == "table"
        and token.schema == "rival.agenda-pause-token/v1"
        and token.agendaId == active.agenda.agendaId
        and token.actor == active.pausedBy) then return false end
    active.pausedBy = nil
    if resolution == "CHALLENGE" then
      return transition(active, "CHALLENGE_OFFERED")
    elseif resolution == "RESOLVE" then
      return A.resolve("COMPLETED")
    end
    return true
  end

  function A.challengeAccepted()
    local active = A.active
    return active and active.state == "CHALLENGE_OFFERED"
      and transition(active, "BATTLE") or false
  end

  function A.challengeDeclined()
    local active = A.active
    if not active or active.state ~= "CHALLENGE_OFFERED" then return false end
    transition(active, "AVAILABLE_FOR_TALK")
    return persistNode(active, "AVAILABLE_FOR_TALK")
  end

  function A.battleFinished(result)
    local active = A.active
    if not active or active.state ~= "BATTLE" then return false end
    active.result = result == "PLAYER_WIN" and "PLAYER_WIN"
      or (result == "PLAYER_LOSS" and "PLAYER_LOSS" or "CONTROLLED_ABORT")
    transition(active, "RESOLVED")
    return persistNode(active, "RESOLVED")
  end

  function A.resolve(outcome)
    local active = A.active
    if not active then return false end
    if active.state == "AVAILABLE_FOR_TALK"
        or active.state == "CHALLENGE_OFFERED" then
      transition(active, "RESOLVED")
    elseif active.state ~= "RESOLVED" then return false end
    active.result = outcome or active.result or "COMPLETED"
    if not persistNode(active, "RESOLVED") then
      return controlledAbort(active, "OPTIONAL_OWNER_ERROR")
    end
    return true
  end

  function A.depart()
    local active = A.active
    if not active or active.state ~= "RESOLVED" then return false end
    transition(active, "DEPARTING", active.agenda.departure.pointId)
    persistNode(active, "DEPARTING")
    emit("CONTROLLED_DEPARTURE", { agendaId=active.agenda.agendaId,
      mapId=active.mapId, actorSet=active.agenda.actorSet })
    if not callLease(active, "depart", active.agenda.departure) then
      return A.routeBlocked("DEPARTURE")
    end
    return true
  end

  function A.departed()
    local active = A.active
    if not active or active.state ~= "DEPARTING" then return false end
    transition(active, "COOLDOWN")
    local resolved = resolveReservation(active, active.result or "COMPLETED")
    local cleared = clearNode()
    release(active)
    return resolved and cleared
  end

  function A.routeBlocked(stage)
    local active = A.active
    if not active or not MOVEMENT_STATES[active.state] then return false end
    active.replanCount = active.replanCount + 1
    emit("ROUTE_BLOCKED", { agendaId=active.agenda.agendaId,
      mapId=active.mapId, actorSet=active.agenda.actorSet,
      reason="ROUTE_BLOCKED" })
    if active.replanCount <= 2 and type(leases.replan) == "function" then
      local ok, replanned = pcall(leases.replan, active.lease,
        active.goalId, active.replanCount, stage)
      if ok and replanned ~= false then
        emit("ROUTE_REPLAN", { agendaId=active.agenda.agendaId,
          mapId=active.mapId, actorSet=active.agenda.actorSet })
        return true
      end
    end
    if active.state ~= "DEPARTING" and type(leases.safeStandpoint) == "function" then
      local standpoint = active.agenda.goals[1].safeStandpointId
      local ok, placed = pcall(leases.safeStandpoint, active.lease, standpoint)
      if ok and placed == true then
        local previous = active.state
        active.state, active.goalId = "AVAILABLE_FOR_TALK", nil
        emit("SAFE_STANDPOINT", { agendaId=active.agenda.agendaId,
          mapId=active.mapId, actorSet=active.agenda.actorSet,
          fromState=previous, toState="AVAILABLE_FOR_TALK",
          reason="REPLAN_LIMIT" })
        return persistNode(active, "AVAILABLE_FOR_TALK")
      end
    end
    return controlledAbort(active, "REPLAN_LIMIT")
  end

  function A.onMapLeaving(mapId)
    local active = A.active
    if not active or active.mapId ~= mapId then return false end
    -- Once the map is leaving, the actor is no longer presented. Releasing a
    -- lease here is not a visible teleport and cannot block the destination.
    return controlledAbort(active, "MAP_EXIT")
  end

  function A.restore(game)
    if A.active or not optionEnabled() then return false end
    local root = normalizedRoot()
    local resume = root and root.v1.agenda.safeResume
    if not resume then return false end
    local mapId = currentMap(game)
    local agenda = catalog.get(resume.agendaId)
    local reservation = type(reservations.claim) == "function"
      and reservations.claim(mapId) or nil
    if not (agenda and validReservation(reservation)
        and reservation.agendaId == resume.agendaId
        and reservation.mapId == mapId) then
      clearNode()
      return false
    end
    local active = {
      game=game, reservation=copy(reservation), agenda=agenda, mapId=mapId,
      state="ELIGIBILITY_CHECK", resolutionSeed=resume.resolutionSeed,
      replanCount=0, result=nil,
    }
    A.active = active
    if type(leases.acquire) ~= "function" then
      return controlledAbort(active, "OPTIONAL_OWNER_ERROR")
    end
    local ok, lease = pcall(leases.acquire, game, copy(agenda),
      copy(reservation))
    if not ok or not lease then return controlledAbort(active,
      "OPTIONAL_OWNER_ERROR") end
    active.lease = lease
    active.state = resume.safeNode
    if resume.safeNode == "RESERVED" then
      active.state = "RESERVED"
      transition(active, "ARRIVING", agenda.arrival.pointId)
      if not callLease(active, "arrive", agenda.arrival) then
        return A.routeBlocked("ARRIVAL")
      end
    elseif resume.safeNode == "PERFORMING_AGENDA"
        or resume.safeNode == "AVAILABLE_FOR_TALK" then
      local goal = agenda.goals[1]
      local okStand, placed = false, false
      if type(leases.safeStandpoint) == "function" then
        okStand, placed = pcall(leases.safeStandpoint, lease,
          goal.safeStandpointId)
      end
      placed = okStand and placed
      if placed ~= true then return controlledAbort(active,
        "OPTIONAL_OWNER_ERROR") end
      active.goalId = resume.safeNode == "PERFORMING_AGENDA"
        and goal.goalId or nil
    elseif resume.safeNode == "RESOLVED" then
      active.state = "RESOLVED"
    elseif resume.safeNode == "DEPARTING" then
      active.state, active.goalId = "DEPARTING", agenda.departure.pointId
      if not callLease(active, "depart", agenda.departure) then
        return controlledAbort(active, "OPTIONAL_OWNER_ERROR")
      end
    end
    emit("RESTORE_SAFE_NODE", { agendaId=agenda.agendaId, mapId=mapId,
      actorSet=agenda.actorSet, reason="LOAD_RESTORE",
      toState=active.state })
    return true
  end

  function A.shutdown()
    if not A.active then return true end
    return controlledAbort(A.active, "OPTIONAL_OWNER_ERROR")
  end

  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      schema="kasc.life-of-rival.card-runtime/v1",
      cardId=A.CARD_ID, version=A.VERSION, owner=A.OWNER,
      active=optionEnabled(), dependencyStatus="ready",
      providerStatus="active", buildReceiptId="rival-agenda-runtime-66",
      rollbackReceiptId="KASC_66_LIFE_OF_RIVAL_SEGMENT_ROLLBACK",
    })
  end

  return A
end
