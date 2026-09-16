-- kasc.rival.scripted-events/v1
--
-- Exact-once orchestration for curated double/trio scenes. The Card requests a
-- challenge through an adapter but never constructs a battle or reward.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "scripted rival events require data")
  local agenda = assert(opts.agenda, "scripted rival events require agenda")
  local challenge = assert(opts.challenge,
    "scripted rival events require optional challenge adapter")
  local support = opts.supportLog

  local E = {
    CARD_ID="rival.scripted-events",
    OWNER="kasc.rival.scripted-events/v1",
    VERSION="1.0.0",
    SAVE_KEY="life_of_rival_segmented",
    SAVE_SCHEMA="kasc.life-of-rival.save/v1",
    active=nil,
  }
  local SAFE_NODES = {
    PRE_TRIGGER=true, ACTORS_AVAILABLE=true,
    PLAYER_CHALLENGE_PENDING=true, POST_CHALLENGE=true, RESOLVED=true,
  }
  local OUTCOMES = {
    DECLINED=true, PLAYER_WIN=true, PLAYER_LOSS=true, CONTROLLED_ABORT=true,
  }
  local eventSequence, repeats = 0, {}

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function safeId(value)
    return type(value) == "string" and #value >= 3 and #value <= 64
      and value:match("^[A-Z0-9_]+$") ~= nil
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

  local function emit(code, active, fields)
    if not (support and type(support.write) == "function") then return false end
    fields = type(fields) == "table" and fields or {}
    local eventId = active and active.definition.eventId or fields.eventId
    local key = table.concat({ code, eventId or "", fields.outcome or "" }, "|")
    repeats[key] = (repeats[key] or 0) + 1
    if repeats[key] ~= 1 and repeats[key] % 10 ~= 0 then return false end
    eventSequence = eventSequence + 1
    local event = {
      schema="kasc.life-of-rival.safe-event/v1",
      cardId=E.CARD_ID, cardVersion=E.VERSION, eventCode=code,
      cadence=repeats[key] >= 10 and "THROTTLED_AGGREGATE" or "TRANSITION",
      sequence=eventSequence, repeatCount=repeats[key] >= 10 and 10 or 1,
      agendaId=active and active.definition.agendaId or nil,
      mapId=active and active.definition.mapId or nil,
      actorIds=active and { "RED", "BLUE" } or nil,
    }
    if fields.reason == "LOAD_RESTORE" then event.reasonCode = "LOAD_RESTORE"
    elseif fields.reason == "MAP_EXIT" then event.reasonCode = "MAP_EXIT"
    elseif fields.reason then event.reasonCode = "OPTIONAL_OWNER_ERROR" end
    if OUTCOMES[fields.outcome] then event.outcomeCode = fields.outcome end
    return support.write("kasc.life-of-rival.safe-event", event)
  end

  local function savedRoot()
    if not (mod.save and type(mod.save.get) == "function") then return nil end
    local ok, value = pcall(mod.save.get, mod.save, E.SAVE_KEY)
    if not ok or type(value) ~= "table" or value.schema ~= E.SAVE_SCHEMA
        or type(value.v1) ~= "table" or value.v1.enabled ~= true
        or type(value.v1.scripted) ~= "table" then return nil end
    local root = copy(value)
    local scripted = root.v1.scripted
    local completed, seen = {}, {}
    for _, id in ipairs(type(scripted.completedEventIds) == "table"
        and scripted.completedEventIds or {}) do
      if safeId(id) and not seen[id] then
        completed[#completed + 1], seen[id] = id, true
      end
    end
    scripted.completedEventIds = completed
    local resume = scripted.safeResume
    if resume ~= nil and (type(resume) ~= "table" or not safeId(resume.eventId)
        or not SAFE_NODES[resume.safeNode]
        or (resume.exactOnceCommitted ~= true
          and resume.exactOnceCommitted ~= false)) then
      scripted.safeResume = nil
    end
    return root
  end

  local function persist(root)
    if not (root and mod.save and type(mod.save.set) == "function") then
      return false
    end
    local ok, result = pcall(mod.save.set, mod.save, E.SAVE_KEY, root)
    return ok and result ~= false
  end

  local function completed(root, id)
    for _, value in ipairs(root.v1.scripted.completedEventIds) do
      if value == id then return true end
    end
    return false
  end

  local function saveNode(active, node, committed)
    local root = savedRoot()
    if not root or not SAFE_NODES[node] then return false end
    root.v1.scripted.safeResume = {
      eventId=active.definition.eventId, safeNode=node,
      exactOnceCommitted=committed == true,
    }
    return persist(root)
  end

  local function clearNode()
    local root = savedRoot()
    if not root then return false end
    root.v1.scripted.safeResume = nil
    return persist(root)
  end

  local function storyEligible(game, definition)
    if type(opts.storyEligible) ~= "function" then return false end
    local ok, value = pcall(opts.storyEligible, game,
      copy(definition.storyRequirements), definition.eventId)
    return ok and value == true
  end

  local function agendaMatches(definition)
    if type(agenda.context) ~= "function" then return false end
    local ok, context = pcall(agenda.context)
    return ok and type(context) == "table"
      and context.agendaId == definition.agendaId
      and context.mapId == definition.mapId
      and context.actorSet == "RED_BLUE"
  end

  function E.available(game)
    if not optionEnabled() then return {} end
    local root = savedRoot()
    if not root then return {} end
    local out = {}
    for _, definition in ipairs(data.all()) do
      if agendaMatches(definition) and storyEligible(game, definition)
          and (not definition.exactOnce
            or not completed(root, definition.eventId)) then
        out[#out + 1] = definition.eventId
      end
    end
    return out
  end

  function E.start(game, eventId)
    if E.active or not optionEnabled() then return false end
    local definition = data.get(eventId)
    local root = savedRoot()
    if not (definition and root and agendaMatches(definition)
        and storyEligible(game, definition)
        and (not definition.exactOnce or not completed(root, eventId))) then
      return false
    end
    local active = { game=game, definition=definition,
      node="PRE_TRIGGER", outcome=nil }
    E.active = active
    if not saveNode(active, "PRE_TRIGGER", false) then
      E.active = nil
      return false
    end
    emit("SCRIPTED_EVENT_STARTED", active)
    return true
  end

  function E.actorsAvailable()
    local active = E.active
    if not active or active.node ~= "PRE_TRIGGER" then return false end
    active.node = "ACTORS_AVAILABLE"
    return saveNode(active, active.node, false)
  end

  function E.dialoguePhases(stage)
    local active = E.active
    local phases = active and active.definition.dialogue[stage]
    return type(phases) == "table" and copy(phases) or nil
  end

  function E.interactionWindows()
    if not E.active or type(agenda.interactionWindow) ~= "function" then
      return nil
    end
    return {
      RED=agenda.interactionWindow("RED"),
      BLUE=agenda.interactionWindow("BLUE"),
    }
  end

  function E.offerChallenge()
    local active = E.active
    if not (active and active.node == "ACTORS_AVAILABLE"
        and active.definition.kind == "TRIO"
        and (active.definition.challenger == "RED"
          or active.definition.challenger == "BLUE")) then return nil end
    active.node = "PLAYER_CHALLENGE_PENDING"
    if not saveNode(active, active.node, false) then return nil end
    local request = {
      schema="rival.optional-challenge-request/v1",
      eventId=active.definition.eventId,
      agendaId=active.definition.agendaId,
      challenger=active.definition.challenger,
      observer=active.definition.observer,
      defaultNo=true,
      rewardSuppressed=true,
    }
    emit("CHALLENGE_OFFERED", active)
    if type(challenge.request) ~= "function" then
      E.controlledAbort("OPTIONAL_OWNER_ERROR")
      return nil
    end
    local ok, accepted = pcall(challenge.request, copy(request))
    if not ok or accepted == false then
      E.controlledAbort("OPTIONAL_OWNER_ERROR")
      return nil
    end
    return request
  end

  function E.challengeResult(outcome)
    local active = E.active
    if not (active and active.node == "PLAYER_CHALLENGE_PENDING"
        and OUTCOMES[outcome]) then return false end
    active.outcome, active.node = outcome, "POST_CHALLENGE"
    if not saveNode(active, active.node, false) then return false end
    emit("CHALLENGE_RESULT", active, { outcome=outcome })
    return true
  end

  function E.resolveVisible()
    local active = E.active
    if not active or (active.node ~= "ACTORS_AVAILABLE"
        and active.node ~= "POST_CHALLENGE"
        and active.node ~= "RESOLVED") then return false end
    if active.node ~= "RESOLVED" then
      active.node = "RESOLVED"
      if not saveNode(active, "RESOLVED", false) then return false end
    end
    local definition = active.definition
    if definition.exactOnce then
      local root = savedRoot()
      if not root then return false end
      if not completed(root, definition.eventId) then
        root.v1.scripted.completedEventIds[#root.v1.scripted.completedEventIds + 1]
          = definition.eventId
      end
      root.v1.scripted.safeResume = {
        eventId=definition.eventId, safeNode="RESOLVED",
        exactOnceCommitted=true,
      }
      if not persist(root) then return false end
    end
    emit("SCRIPTED_EVENT_COMMITTED", active,
      { outcome=active.outcome or "COMPLETED" })
    return true
  end

  function E.finishDeparture()
    local active = E.active
    if not active or active.node ~= "RESOLVED" then return false end
    local root = savedRoot()
    if active.definition.exactOnce
        and (not root or not completed(root, active.definition.eventId)) then
      return false
    end
    if not clearNode() then return false end
    E.active = nil
    return true
  end

  function E.controlledAbort(reason)
    local active = E.active
    if not active then return false end
    emit("CONTROLLED_ABORT", active, {
      reason=reason or "OPTIONAL_OWNER_ERROR", outcome="CONTROLLED_ABORT",
    })
    clearNode()
    E.active = nil
    return true
  end

  function E.restore(game)
    if E.active or not optionEnabled() then return false end
    local root = savedRoot()
    local resume = root and root.v1.scripted.safeResume
    if not resume then return false end
    local definition = data.get(resume.eventId)
    if not (definition and agendaMatches(definition)
        and storyEligible(game, definition)) then
      clearNode()
      return false
    end
    local isCommitted = completed(root, definition.eventId)
    if definition.exactOnce and isCommitted then
      resume.safeNode, resume.exactOnceCommitted = "RESOLVED", true
    elseif resume.exactOnceCommitted then
      clearNode()
      return false
    end
    local active = { game=game, definition=definition,
      node=resume.safeNode, outcome=nil }
    E.active = active
    if resume.safeNode == "PLAYER_CHALLENGE_PENDING" then
      if type(challenge.restore) ~= "function" then
        return E.controlledAbort("OPTIONAL_OWNER_ERROR")
      end
      local ok, outcome = pcall(challenge.restore, definition.eventId)
      if not ok or not OUTCOMES[outcome] then
        return E.controlledAbort("OPTIONAL_OWNER_ERROR")
      end
      active.outcome, active.node = outcome, "POST_CHALLENGE"
      if not saveNode(active, active.node, false) then
        return E.controlledAbort("OPTIONAL_OWNER_ERROR")
      end
    end
    emit("RESTORE_SAFE_NODE", active, { reason="LOAD_RESTORE" })
    return true
  end

  function E.onMapLeaving(mapId)
    local active = E.active
    if not active or active.definition.mapId ~= mapId then return false end
    -- No exact-once ID is committed on an invisible abort. A not-yet-resolved
    -- targeted event remains eligible for a later clean attempt.
    return E.controlledAbort("MAP_EXIT")
  end

  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      schema="kasc.life-of-rival.card-runtime/v1",
      cardId=E.CARD_ID, version=E.VERSION, owner=E.OWNER,
      active=optionEnabled(), dependencyStatus="ready",
      providerStatus="active", buildReceiptId="rival-scripted-events-66",
      rollbackReceiptId="KASC_66_LIFE_OF_RIVAL_SEGMENT_ROLLBACK",
    })
  end

  return E
end
