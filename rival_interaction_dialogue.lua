-- kasc.rival.interaction-dialogue/v1
--
-- Context-bound selection and interaction buffering. Text rendering, movement,
-- battles and save ownership remain outside this Card.

return function(mod, opts)
  opts = opts or {}
  local agenda = assert(opts.agenda, "rival interaction requires agenda adapter")
  local packs = assert(opts.packs, "rival interaction requires voice packs")
  local localization = opts.localization
  local support = opts.supportLog

  local D = {
    CARD_ID="rival.interaction-dialogue",
    OWNER="kasc.rival.interaction-dialogue/v1",
    VERSION="1.0.0",
    SAVE_KEY="life_of_rival_segmented",
    SAVE_SCHEMA="kasc.life-of-rival.save/v1",
    buffered={ RED=nil, BLUE=nil },
    active={ RED=nil, BLUE=nil },
    activeOwner=nil,
  }
  local ACTORS = { RED=true, BLUE=true }
  local PHASES = {
    ARRIVAL=true, FIRST_TALK=true, REPEAT_TALK=true, INTERRUPTED=true,
    PRE_CHALLENGE=true, POST_WIN=true, POST_LOSS=true, POST_ABORT=true,
    FAREWELL=true, DUEL_AFTER=true,
  }
  local rowsById, pools = {}, {}
  local eventSequence, repeats = 0, {}

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
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

  local function validLine(row)
    return type(row) == "table" and ACTORS[row.actor] and PHASES[row.phase]
      and type(row.id) == "string"
      and row.id:match("^" .. row.actor:lower() .. "%.[a-z0-9_.-]+$")
      and type(row.agendaId) == "string"
      and row.agendaId:match("^[A-Z0-9_]+$")
      and type(row.localeKeys) == "table"
      and type(row.localeKeys.en) == "string"
      and type(row.localeKeys.de) == "string"
      and type(row.antiRepeat) == "table"
      and row.antiRepeat.scope == "ACTOR_AGENDA_PHASE"
      and row.antiRepeat.historySize == 4
      and type(row.antiRepeat.fallbackId) == "string"
  end

  for actor, pack in pairs(packs) do
    assert(ACTORS[actor] and type(pack) == "table"
      and pack.actor == actor and type(pack.rows) == "table",
      "invalid rival dialogue pack")
    for _, source in ipairs(pack.rows) do
      assert(validLine(source) and source.actor == actor,
        "invalid rival dialogue line")
      assert(not rowsById[source.id], "duplicate rival dialogue id")
      local row = copy(source)
      rowsById[row.id] = row
      pools[actor] = pools[actor] or {}
      pools[actor][row.agendaId] = pools[actor][row.agendaId] or {}
      pools[actor][row.agendaId][row.phase] =
        pools[actor][row.agendaId][row.phase] or {}
      table.insert(pools[actor][row.agendaId][row.phase], row)
    end
  end
  for _, row in pairs(rowsById) do
    local fallback = rowsById[row.antiRepeat.fallbackId]
    assert(fallback and fallback.actor == row.actor
      and fallback.agendaId == row.agendaId and fallback.phase == row.phase,
      "rival dialogue fallback must stay in actor/agenda/phase")
  end

  local function emit(code, actor, context)
    if not (support and type(support.write) == "function") then return false end
    context = type(context) == "table" and context or {}
    local key = table.concat({ code, actor or "", context.agendaId or "",
      context.phase or "" }, "|")
    repeats[key] = (repeats[key] or 0) + 1
    if repeats[key] ~= 1 and repeats[key] % 10 ~= 0 then return false end
    eventSequence = eventSequence + 1
    return support.write("kasc.life-of-rival.safe-event", {
      schema="kasc.life-of-rival.safe-event/v1",
      cardId=D.CARD_ID, cardVersion=D.VERSION, eventCode=code,
      cadence=repeats[key] >= 10 and "THROTTLED_AGGREGATE" or "TRANSITION",
      sequence=eventSequence, repeatCount=repeats[key] >= 10 and 10 or 1,
      agendaId=context.agendaId,
      actorIds=ACTORS[actor] and { actor } or nil,
    })
  end

  local function savedRoot()
    if not (mod.save and type(mod.save.get) == "function") then return nil end
    local ok, value = pcall(mod.save.get, mod.save, D.SAVE_KEY)
    if not ok or type(value) ~= "table" or value.schema ~= D.SAVE_SCHEMA
        or type(value.v1) ~= "table" or value.v1.enabled ~= true
        or type(value.v1.dialogue) ~= "table"
        or type(value.v1.dialogue.antiRepeat) ~= "table" then return nil end
    return copy(value)
  end

  local function cleanHistory(actor, value)
    local out, seen = {}, {}
    for _, id in ipairs(type(value) == "table" and value or {}) do
      if type(id) == "string" and id:match("^" .. actor:lower()
          .. "%.[a-z0-9_.-]+$") and rowsById[id] and not seen[id] then
        out[#out + 1], seen[id] = id, true
      end
    end
    while #out > 4 do table.remove(out, 1) end
    return out
  end

  local function history(actor)
    local root = savedRoot()
    local values = root and root.v1.dialogue.antiRepeat[actor]
    return cleanHistory(actor, values), root
  end

  local function remember(actor, id)
    local prior, root = history(actor)
    if not root then return false end
    for index = #prior, 1, -1 do
      if prior[index] == id then table.remove(prior, index) end
    end
    prior[#prior + 1] = id
    while #prior > 4 do table.remove(prior, 1) end
    root.v1.dialogue.antiRepeat[actor] = prior
    if not (mod.save and type(mod.save.set) == "function") then return false end
    local ok, result = pcall(mod.save.set, mod.save, D.SAVE_KEY, root)
    return ok and result ~= false
  end

  local function localized(pack, row, locale)
    locale = locale == "de" and "de" or "en"
    local key = row.localeKeys[locale]
    local text
    if localization and type(localization.lookup) == "function" then
      local ok, value = pcall(localization.lookup, locale, key)
      text = ok and value or nil
    end
    if type(text) ~= "string" and type(pack.lookup) == "function" then
      local ok, value = pcall(pack.lookup, locale, key)
      text = ok and value or nil
    end
    return type(text) == "string" and text ~= "" and text or nil, key
  end

  local function choose(actor, agendaId, phase, locale, seed)
    local pool = pools[actor] and pools[actor][agendaId]
      and pools[actor][agendaId][phase]
    if type(pool) ~= "table" or #pool == 0 then return nil end
    local recent = history(actor)
    local blocked = {}
    for _, id in ipairs(recent) do blocked[id] = true end
    local start = (math.floor(tonumber(seed) or 0) % #pool) + 1
    local selected
    for offset = 0, #pool - 1 do
      local row = pool[((start + offset - 1) % #pool) + 1]
      if not blocked[row.id] then selected = row break end
    end
    selected = selected or pool[start]
    local pack = packs[actor]
    local text, key = localized(pack, selected, locale)
    if not text then
      local fallback = rowsById[selected.antiRepeat.fallbackId]
      text, key = localized(pack, fallback, locale)
      selected = text and fallback or nil
    end
    if not selected or not text then return nil end
    return {
      schema="rival.dialogue-selection/v1",
      id=selected.id, actor=actor, agendaId=agendaId, phase=phase,
      locale=locale == "de" and "de" or "en",
      localeKey=key, text=text,
    }
  end

  function D.reviewRows()
    local out = {}
    for _, row in pairs(rowsById) do out[#out + 1] = copy(row) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
  end

  function D.select(actor, agendaId, phase, locale, seed)
    if not optionEnabled() or not ACTORS[actor] or not PHASES[phase] then
      return nil
    end
    return choose(actor, agendaId, phase, locale, seed)
  end

  function D.begin(actor, phase, locale, seed)
    if not optionEnabled() or not ACTORS[actor] or D.activeOwner then
      return nil, "UNAVAILABLE"
    end
    local window = agenda.interactionWindow(actor)
    if not window then return nil, "UNAVAILABLE" end
    if window.shortUninterruptible == true then
      if not D.buffered[actor] then
        D.buffered[actor] = { actor=actor, phase=phase, locale=locale, seed=seed,
          agendaId=window.agendaId }
        emit("INTERACTION_BUFFERED", actor, D.buffered[actor])
      end
      return nil, "BUFFERED"
    end
    if window.talkable ~= true then return nil, "UNAVAILABLE" end
    local selection = choose(actor, window.agendaId, phase, locale, seed)
    if not selection then return nil, "NO_LOCALIZED_LINE" end
    local pause = agenda.pauseForInteraction(actor)
    if not pause then return nil, "PAUSE_FAILED" end
    D.active[actor] = { selection=selection, pause=pause }
    D.activeOwner = actor
    emit("INTERACTION_STARTED", actor, selection)
    return copy(selection), "STARTED"
  end

  function D.flush(actor)
    if not ACTORS[actor] then return nil, "UNAVAILABLE" end
    local buffered = D.buffered[actor]
    if not buffered then return nil, "EMPTY" end
    if D.activeOwner then return nil, "UNAVAILABLE" end
    D.buffered[actor] = nil
    return D.begin(actor, buffered.phase, buffered.locale, buffered.seed)
  end

  function D.resolve(actor, outcome)
    local current = ACTORS[actor] and D.active[actor] or nil
    if not current then return false end
    if not remember(actor, current.selection.id) then return false end
    local resolution = outcome == "CHALLENGE" and "CHALLENGE"
      or (outcome == "RESOLVE" and "RESOLVE" or "RESUME")
    local resumed = agenda.resumeFromInteraction(current.pause, resolution)
    if resumed == false then return false end
    D.active[actor] = nil
    D.activeOwner = nil
    emit("INTERACTION_RESOLVED", actor, current.selection)
    return true
  end

  function D.clearTransient()
    D.buffered, D.active = { RED=nil, BLUE=nil }, { RED=nil, BLUE=nil }
    D.activeOwner = nil
    return true
  end

  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      schema="kasc.life-of-rival.card-runtime/v1",
      cardId=D.CARD_ID, version=D.VERSION, owner=D.OWNER,
      active=optionEnabled(), dependencyStatus="ready",
      providerStatus="active", buildReceiptId="rival-dialogue-runtime-66",
      rollbackReceiptId="KASC_66_LIFE_OF_RIVAL_SEGMENT_ROLLBACK",
    })
  end

  return D
end
