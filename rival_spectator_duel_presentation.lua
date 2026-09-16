-- kasc.rival.spectator-duel-presentation/v1
--
-- A deterministic visual exchange, never a second battle simulator. Exact
-- team snapshots are copied on entry and no save or live battle value is read
-- again until this transient presentation is released.

return function(mod, opts)
  opts = opts or {}
  local snapshotProvider = assert(opts.snapshots,
    "spectator duel requires team snapshot provider")
  local commandPacks = assert(opts.commands,
    "spectator duel requires actor commands")
  local agenda = assert(opts.agenda, "spectator duel requires agenda adapter")
  local support = opts.supportLog
  local vasc = opts.semanticPresentation
  local fallback = opts.localFallback

  local P = {
    CARD_ID="rival.spectator-duel-presentation",
    OWNER="kasc.rival.spectator-duel-presentation/v1",
    VERSION="1.0.0",
    active=nil,
  }
  local pair = opts.actorPair or { "RED", "BLUE" }
  local known = { RED=true, BLUE=true, GREEN=true }
  assert(type(pair)=="table" and #pair==2 and known[pair[1]]
    and known[pair[2]] and pair[1]~=pair[2],"invalid spectator actor pair")
  pair = {pair[1],pair[2]}
  local ACTORS = { [pair[1]]=true, [pair[2]]=true }
  local function opponent(actor)return actor==pair[1] and pair[2] or pair[1]end
  local SEMANTICS = { HEAL=true, PROTECT=true, BOOST=true, CHARGE=true,
    DODGE=true, MELEE=true, RANGED=true, MULTIPHASE=true }
  local PHASES = { BEFORE_ACTION=true, ADVANTAGE=true, COUNTER=true,
    RECOVERY=true, AFTER_ACTION=true }
  local RESULTS = { [pair[1].."_ADVANTAGE"]=true, [pair[2].."_ADVANTAGE"]=true, DRAW=true,
    CONTROLLED_ABORT=true }
  local eventSequence, repeats = 0, {}

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function stableHash(value, salt)
    local h = 104729 + math.max(0, math.floor(tonumber(salt) or 0))
    value = tostring(value or "")
    for index = 1, #value do
      h = (h * 131 + value:byte(index) + index) % 2147483647
    end
    return h
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
    if not (support and type(support.write) == "function") then return false end
    fields = type(fields) == "table" and fields or {}
    local active = P.active
    local key = table.concat({ code, fields.actor or "",
      fields.reason or "", tostring(fields.actionIndex or "") }, "|")
    repeats[key] = (repeats[key] or 0) + 1
    if repeats[key] ~= 1 and repeats[key] % 10 ~= 0 then return false end
    eventSequence = eventSequence + 1
    local event = {
      schema="kasc.life-of-rival.safe-event/v1",
      cardId=P.CARD_ID, cardVersion=P.VERSION, eventCode=code,
      cadence=repeats[key] >= 10 and "THROTTLED_AGGREGATE" or "TRANSITION",
      sequence=eventSequence, repeatCount=repeats[key] >= 10 and 10 or 1,
      agendaId=active and active.sceneId or nil,
      actorIds=fields.actor and { fields.actor } or { pair[1], pair[2] },
    }
    if fields.reason == "MISSING_PRESENTATION" then
      event.reasonCode = "MISSING_PRESENTATION"
    elseif fields.reason == "INVALID_SNAPSHOT" then
      event.reasonCode = "INVALID_SNAPSHOT"
    elseif fields.reason == "MAP_EXIT" then event.reasonCode = "MAP_EXIT"
    elseif fields.reason then event.reasonCode = "OPTIONAL_OWNER_ERROR" end
    if RESULTS[fields.outcome] then event.outcomeCode = fields.outcome end
    return support.write("kasc.life-of-rival.safe-event", event)
  end

  local function exactInteger(value, minimum, maximum)
    return type(value) == "number" and value == math.floor(value)
      and value >= minimum and (not maximum or value <= maximum)
  end

  local function validId(value, pattern, minimum, maximum)
    return type(value) == "string" and #value >= minimum and #value <= maximum
      and value:match(pattern) ~= nil
  end

  local function closed(value, allowed)
    if type(value) ~= "table" then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
  end

  local function validateSnapshot(source, actor, sceneId, opportunity)
    if not closed(source, { schema=true, snapshotId=true, sceneId=true,
        actor=true, source=true, storyStateDigest=true, ruleSetId=true,
        capturedAtOpportunity=true, pokemon=true, moves=true,
        outcomePlan=true })
        or source.schema ~= "rival.team-move-snapshot/v1"
        or not validId(source.snapshotId, "^[A-Z0-9_:-]+$", 8, 96)
        or source.sceneId ~= sceneId or source.actor ~= actor
        or source.source ~= "ACTIVE_STORY_TEAM"
        or not validId(source.storyStateDigest, "^[a-f0-9]+$", 64, 64)
        or not validId(source.ruleSetId, "^[A-Z0-9_.:-]+$", 2, 64)
        or source.capturedAtOpportunity ~= opportunity
        or not closed(source.pokemon, { speciesId=true, teamSlot=true,
          level=true, presentation=true, initialHpBand=true })
        or not validId(source.pokemon.speciesId, "^[A-Z0-9_]+$", 2, 48)
        or not exactInteger(source.pokemon.teamSlot, 1, 6)
        or not exactInteger(source.pokemon.level, 1, 100)
        or not closed(source.pokemon.presentation, { variant=true,
          mirrored=true, facesOpponent=true })
        or (source.pokemon.presentation.variant ~= "FRONT"
          and source.pokemon.presentation.variant ~= "WILD")
        or type(source.pokemon.presentation.mirrored) ~= "boolean"
        or source.pokemon.presentation.facesOpponent ~= true
        or not ({ FULL=true, HIGH=true, MID=true, LOW=true })[
          source.pokemon.initialHpBand]
        or type(source.moves) ~= "table" or #source.moves < 1
        or #source.moves > 4
        or not closed(source.outcomePlan, { seed=true, resultCode=true,
          actionCount=true })
        or not exactInteger(source.outcomePlan.seed, 0)
        or not RESULTS[source.outcomePlan.resultCode]
        or not exactInteger(source.outcomePlan.actionCount, 4, 8) then
      return nil
    end
    local slots, ids = {}, {}
    for _, move in ipairs(source.moves) do
      if not closed(move, { slot=true, moveId=true, semanticClass=true,
          legalAtSnapshot=true, source=true, animationId=true })
          or not exactInteger(move.slot, 1, 4)
          or slots[move.slot]
          or not validId(move.moveId, "^[A-Z0-9_]+$", 2, 48)
          or ids[move.moveId] or not SEMANTICS[move.semanticClass]
          or move.legalAtSnapshot ~= true
          or move.source ~= "SNAPSHOT_MOVESET"
          or (move.animationId ~= nil
            and not validId(move.animationId, "^[A-Z0-9_.:-]+$", 2, 96)) then
        return nil
      end
      slots[move.slot], ids[move.moveId] = true, true
    end
    return copy(source)
  end

  local function capture(actor, sceneId, opportunity)
    if type(snapshotProvider.capture) ~= "function" then return nil end
    local ok, source = pcall(snapshotProvider.capture, actor, sceneId,
      opportunity)
    return ok and validateSnapshot(source, actor, sceneId, opportunity) or nil
  end

  local function targeting(actor, semantic)
    local other = opponent(actor)
    if semantic == "HEAL" or semantic == "PROTECT" or semantic == "BOOST"
        or semantic == "DODGE" then
      return actor, actor
    elseif semantic == "CHARGE" or semantic == "MULTIPHASE" then
      return actor, other
    end
    return actor, other
  end

  local function actionPlan(red, blue)
    local plan = red.outcomePlan
    if blue.storyStateDigest ~= red.storyStateDigest
        or blue.ruleSetId ~= red.ruleSetId
        or blue.outcomePlan.seed ~= plan.seed
        or blue.outcomePlan.resultCode ~= plan.resultCode
        or blue.outcomePlan.actionCount ~= plan.actionCount then return nil end
    local actions = {}
    local used = { [pair[1]]=0, [pair[2]]=0 }
    local first = stableHash(red.snapshotId .. blue.snapshotId, plan.seed) % 2 == 0
      and pair[1] or pair[2]
    for index = 1, plan.actionCount do
      local actor = index % 2 == 1 and first
        or opponent(first)
      local snapshot = actor == pair[1] and red or blue
      used[actor] = used[actor] + 1
      local move = snapshot.moves[((plan.seed + used[actor] - 1)
        % #snapshot.moves) + 1]
      local origin, impact = targeting(actor, move.semanticClass)
      actions[#actions + 1] = {
        schema="rival.spectator-action/v1", actionIndex=index,
        actor=actor, targetActor=opponent(actor),
        snapshotId=snapshot.snapshotId, moveId=move.moveId,
        semanticClass=move.semanticClass, animationId=move.animationId,
        delaySeconds=4 + stableHash(move.moveId, plan.seed + index) % 4,
        originTarget=origin, impactTarget=impact,
      }
    end
    return actions
  end

  local function agendaReady(sceneId)
    if type(agenda.context) ~= "function" then return false end
    local ok, context = pcall(agenda.context)
    return ok and type(context) == "table" and context.actorSet == table.concat(pair,"_")
      and context.agendaId == sceneId
  end

  function P.start(sceneId, opportunity)
    if P.active or not optionEnabled() or not agendaReady(sceneId)
        or not exactInteger(opportunity, 1) then return false end
    local red = capture(pair[1], sceneId, opportunity)
    local blue = capture(pair[2], sceneId, opportunity)
    if not red or not blue or red.snapshotId == blue.snapshotId then
      emit("CONTROLLED_ABORT", { reason="INVALID_SNAPSHOT",
        outcome="CONTROLLED_ABORT" })
      return false
    end
    local actions = actionPlan(red, blue)
    if not actions then
      emit("CONTROLLED_ABORT", { reason="INVALID_SNAPSHOT",
        outcome="CONTROLLED_ABORT" })
      return false
    end
    P.active = {
      sceneId=sceneId, opportunity=opportunity,
      snapshots={ [pair[1]]=red, [pair[2]]=blue }, actions=actions,
      cursor=1, remaining=actions[1].delaySeconds,
      presenting=false, paused=false, activeTalk=nil,
      buffered={}, history={ [pair[1]]={}, [pair[2]]={} },
      resolved=false, result=red.outcomePlan.resultCode,
    }
    emit("SPECTATOR_DUEL_STARTED")
    return true
  end

  function P.snapshot(actor)
    return P.active and ACTORS[actor]
      and copy(P.active.snapshots[actor]) or nil
  end

  function P.plan()
    return P.active and copy(P.active.actions) or nil
  end

  function P.progress()
    local a=P.active
    return a and {cursor=a.cursor,resolved=a.resolved,remaining=a.remaining}or nil
  end
  function P.restoreProgress(row)
    local a=P.active
    if not a or a.presenting or a.activeTalk or a.cursor~=1
        or type(row)~='table' or not exactInteger(row.cursor,1,#a.actions+1)
        or type(row.resolved)~='boolean' or row.resolved~=(row.cursor==#a.actions+1)
        or type(row.remaining)~='number' or row.remaining~=row.remaining
        or row.remaining<0 or row.remaining>7
        or row.resolved and row.remaining~=0 then return false end
    a.cursor,a.resolved,a.remaining=row.cursor,row.resolved,row.remaining
    return true
  end

  function P.tick(seconds)
    local active = P.active
    if not active or active.resolved or active.presenting or active.paused then
      return nil
    end
    seconds = math.max(0, math.min(1, tonumber(seconds) or 0))
    active.remaining = math.max(0, active.remaining - seconds)
    if active.remaining > 0 then return nil end
    local action = active.actions[active.cursor]
    if not action then return nil end
    active.presenting = true
    local presented = false
    if vasc and type(vasc.present) == "function" then
      local ok, value = pcall(vasc.present, copy(action))
      presented = ok and value == true
    end
    if not presented then
      emit("PRESENTATION_FALLBACK", { actor=action.actor,
        actionIndex=action.actionIndex, reason="MISSING_PRESENTATION" })
      if fallback and type(fallback.present) == "function" then
        local ok, value = pcall(fallback.present, copy(action))
        presented = ok and value == true
      end
    end
    if not presented then
      P.abort("MISSING_PRESENTATION")
      return nil
    end
    emit("SPECTATOR_ACTION", { actor=action.actor,
      actionIndex=action.actionIndex })
    return copy(action)
  end

  function P.finishAction()
    local active = P.active
    if not active or not active.presenting then return false end
    active.presenting = false
    active.cursor = active.cursor + 1
    local nextAction = active.actions[active.cursor]
    if nextAction then
      active.remaining = nextAction.delaySeconds
    else
      active.resolved = true
      active.remaining = 0
      emit("SPECTATOR_DUEL_RESOLVED", { outcome=active.result })
    end
    return true
  end

  local function findMove(snapshot, moveId)
    for _, move in ipairs(snapshot.moves) do
      if move.moveId == moveId then return move end
    end
    return nil
  end

  local function substitute(text, pokemon, move)
    return text:gsub("{POKEMON}", pokemon):gsub("{MOVE}", move)
  end

  local function localizedName(kind, id, locale)
    if opts.localization and type(opts.localization.name) == "function" then
      local ok, value = pcall(opts.localization.name, kind, id, locale)
      if ok and type(value) == "string" and value ~= "" then return value end
    end
    return id:gsub("_", " ")
  end

  local function commandFor(actor, phase, locale, action)
    local active = P.active
    local snapshot = active and active.snapshots[actor]
    local move = snapshot and action and action.actor == actor
      and findMove(snapshot, action.moveId) or nil
    local pack = commandPacks[actor]
    if not (snapshot and move and pack and type(pack.make) == "function") then
      return nil
    end
    local key = table.concat({ phase, move.semanticClass }, ":")
    local history = active.history[actor]
    local variant = history[key] == 1 and 2 or 1
    local command, text = pack.make(snapshot, move, phase, variant)
    history[key] = variant
    locale = locale == "de" and "de" or "en"
    local raw = text and text[locale]
    if type(raw) ~= "string" then return nil end
    local resolved = substitute(raw,
      localizedName("pokemon", snapshot.pokemon.speciesId, locale),
      localizedName("move", move.moveId, locale))
    return { command=copy(command), locale=locale, text=resolved }
  end

  function P.talk(actor, phase, locale)
    local active = P.active
    if not (active and ACTORS[actor] and PHASES[phase]) then
      return nil, "UNAVAILABLE"
    end
    if active.presenting then
      if not active.buffered[actor] then
        active.buffered[actor] = { phase=phase, locale=locale }
        emit("INTERACTION_BUFFERED", { actor=actor })
      end
      return nil, "BUFFERED"
    end
    if active.activeTalk then return nil, "UNAVAILABLE" end
    local action = active.actions[math.min(active.cursor, #active.actions)]
    local result = commandFor(actor, phase, locale, action)
    if not result then
      -- When the next planned action belongs to the other trainer, select the
      -- nearest action that actually references this actor's legal snapshot.
      for distance = 1, #active.actions do
        local before = active.actions[math.max(1, active.cursor - distance)]
        local after = active.actions[math.min(#active.actions,
          active.cursor + distance)]
        result = commandFor(actor, phase, locale,
          before.actor == actor and before or after)
        if result then break end
      end
    end
    if not result then return nil, "NO_LEGAL_COMMAND" end
    active.activeTalk, active.paused = actor, true
    return result, "STARTED"
  end

  function P.finishTalk(actor)
    local active = P.active
    if not active or active.activeTalk ~= actor then return false end
    active.activeTalk, active.paused = nil, false
    return true
  end

  function P.flushTalk(actor)
    local active = P.active
    if not (active and ACTORS[actor] and active.buffered[actor]) then
      return nil, "EMPTY"
    end
    if active.presenting or active.activeTalk then return nil, "UNAVAILABLE" end
    local row = active.buffered[actor]
    active.buffered[actor] = nil
    return P.talk(actor, row.phase, row.locale)
  end

  function P.finishScene(reason)
    local active = P.active
    if not active or not active.resolved then return false end
    if type(agenda.resolveSpectator) == "function" then
      local ok, value = pcall(agenda.resolveSpectator,
        active.result, reason or "COMPLETED")
      if not ok or value == false then return false end
    end
    P.active = nil
    return true
  end

  function P.abort(reason)
    local active = P.active
    if not active then return false end
    emit("CONTROLLED_ABORT", { reason=reason or "OPTIONAL_OWNER_ERROR",
      outcome="CONTROLLED_ABORT" })
    if type(agenda.resolveSpectator) == "function" then
      pcall(agenda.resolveSpectator, "CONTROLLED_ABORT", reason)
    end
    P.active = nil
    return true
  end

  function P.onMapLeaving()
    local active = P.active
    if not active then return false end
    -- The precomputed outcome closes the presentation once it is no longer
    -- visible. No snapshot/action survives and return cannot duplicate it.
    active.resolved = true
    emit("SPECTATOR_DUEL_RESOLVED", {
      reason="MAP_EXIT", outcome=active.result,
    })
    return P.finishScene("MAP_EXIT")
  end

  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      schema="kasc.life-of-rival.card-runtime/v1",
      cardId=P.CARD_ID, version=P.VERSION, owner=P.OWNER,
      active=optionEnabled(), dependencyStatus="ready",
      providerStatus=vasc and "optional-provider" or "local-fallback",
      buildReceiptId="rival-spectator-duel-66",
      rollbackReceiptId="KASC_66_LIFE_OF_RIVAL_SEGMENT_ROLLBACK",
    })
  end

  return P
end
