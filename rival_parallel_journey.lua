-- Kanto Ascendant 6.7: persistent journeys for the selected rival and the
-- third Red/Blue/Green character.
--
-- This layer is deliberately additive to life_of_rival.lua.  The earlier
-- rare-meeting transaction remains the introduction/rumor authority.  Once
-- that introduction is durably complete, authored work scenes can place one
-- or both companions.  Each actor owns an independent receipt, activity
-- count, legal team stage and battle result.

return function(mod, opts)
  opts = opts or {}
  local base = assert(opts.base, "parallel rival journey requires Life of a Rival")
  local characters = assert(opts.characters,
    "parallel rival journey requires extended characters")
  local postgame = assert(opts.postgame,
    "parallel rival journey requires the postgame battle seam")
  local spawnSafety = assert(opts.spawnSafety,
    "parallel rival journey requires shared spawn safety")
  local data = assert(opts.data, "parallel rival journey requires authored data")
  assert(data.schemaVersion == 1 and type(data.scenes) == "table"
    and type(data.personaLeads) == "table",
    "parallel rival journey data schema drifted")

  local J = {
    SAVE_KEY = "rival_parallel_journey",
    STATE_VERSION = 1,
    TEXT = "TEXT_KA_RIVAL_PARALLEL_JOURNEY",
    SCENES = data.scenes,
    active = nil,
    game = nil,
    readOnly = false,
    futureVersion = nil,
  }

  local CHARACTER_IDS = { RED = true, BLUE = true, GREEN = true }
  local sceneById, maps = {}, {}
  for _, scene in ipairs(data.scenes) do
    assert(type(scene.id) == "string" and not sceneById[scene.id],
      "parallel rival journey scene ID drifted")
    assert(type(scene.mapId) == "string" and type(scene.minRank) == "number"
      and type(scene.actors) == "table" and #scene.actors >= 1
      and #scene.actors <= 2, "parallel rival journey scene shape drifted")
    local roles = {}
    for _, row in ipairs(scene.actors) do
      assert((row.role == "rival" or row.role == "third")
        and not roles[row.role] and type(row.activity) == "string"
        and type(row.tone) == "string"
        and type(row.en) == "string" and type(row.de) == "string",
        "parallel rival journey actor row drifted")
      for actor in pairs(CHARACTER_IDS) do
        local lead = data.personaLeads[actor]
          and data.personaLeads[actor][row.tone]
        assert(type(lead) == "table" and type(lead.en) == "string"
          and type(lead.de) == "string",
          "parallel rival journey persona lead drifted")
      end
      roles[row.role] = true
      assert(row.movement == nil or (row.movement == "WALK"
        and (row.roamRange == "LEFT_RIGHT" or row.roamRange == "UP_DOWN")),
        "parallel rival journey movement boundary drifted")
    end
    assert(scene.shared == nil or (type(scene.shared.en) == "string"
      and type(scene.shared.de) == "string"),
      "parallel rival journey shared copy drifted")
    sceneById[scene.id], maps[scene.mapId] = scene, true
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function integer(value, default, maximum)
    value = math.floor(tonumber(value) or default or 0)
    value = math.max(0, value)
    if maximum then value = math.min(maximum, value) end
    return value
  end

  local function clamp(value, low, high)
    value = math.floor(tonumber(value) or low)
    return math.max(low, math.min(high, value))
  end

  local function tr(en, de)
    local i18n = opts.i18n
    if i18n and type(i18n.text) == "function" then
      local ok, value = pcall(i18n.text, en, de)
      if ok and type(value) == "string" then return value end
    end
    return en
  end

  local function displayName(actor)
    if type(characters.displayName) == "function" then
      local ok, value = pcall(characters.displayName, actor)
      if ok and type(value) == "string" and value ~= "" then return value end
    end
    return actor
  end

  local function replacements(game, roles)
    local playerName = game and game.save and (game.save.playerName
      or game.save.name) or roles.player
    return {
      PLAYER = tostring(playerName or roles.player),
      RIVAL = displayName(roles.rival),
      THIRD = displayName(roles.third),
    }
  end

  local function substitute(text, values)
    text = tostring(text or "")
    for key, value in pairs(values or {}) do
      text = text:gsub("{" .. key .. "}", function() return tostring(value) end)
    end
    return text
  end

  local function savedState()
    if not (mod.save and type(mod.save.get) == "function") then return nil end
    local ok, value = pcall(mod.save.get, mod.save, J.SAVE_KEY)
    return ok and value or nil
  end

  local function persist(state)
    if not (state and not J.readOnly and mod.save
        and type(mod.save.set) == "function") then return false end
    local ok, result = pcall(mod.save.set, mod.save, J.SAVE_KEY, state)
    return ok and result ~= false
  end

  local function cleanHistory(value)
    local out, seen = {}, {}
    for _, id in ipairs(type(value) == "table" and value or {}) do
      if type(id) == "string" and sceneById[id] and not seen[id] then
        seen[id] = true
        out[#out + 1] = id
      end
    end
    while #out > 16 do table.remove(out, 1) end
    return out
  end

  local function normalizeActor(value)
    value = type(value) == "table" and value or {}
    local actor = {
      activities = integer(value.activities), talks = integer(value.talks),
      battles = integer(value.battles), wins = integer(value.wins),
      losses = integer(value.losses), declines = integer(value.declines),
      interrupted = integer(value.interrupted),
      teamStage = clamp(value.teamStage or 1, 1, 6),
      chapter = clamp(value.chapter or value.teamStage or 1, 1, 6),
      history = cleanHistory(value.history),
      lastSceneId = sceneById[value.lastSceneId] and value.lastSceneId or nil,
      lastActivity = type(value.lastActivity) == "string"
        and value.lastActivity or nil,
      lastMapId = maps[value.lastMapId] and value.lastMapId or nil,
      lastResult = type(value.lastResult) == "string" and value.lastResult or nil,
    }
    return actor
  end

  local function normalizePendingActor(value)
    if type(value) ~= "table" or not CHARACTER_IDS[value.actor]
        or (value.role ~= "rival" and value.role ~= "third")
        or type(value.token) ~= "string" or type(value.activity) ~= "string"
        or type(value.text) ~= "string" then return nil end
    local row = copy(value)
    row.talked = row.talked == true
    row.finished = row.finished == true
    row.repeatTalks = math.min(1000000, integer(row.repeatTalks))
    row.battleStarted = row.battleStarted == true
    row.battleOffered = row.battleOffered == true
      and type(row.battlePlan) == "table"
    row.activityCommitted = row.activityCommitted == true
    row.spawnCounted = row.spawnCounted == true
    row.movement = row.movement == "WALK" and "WALK" or "STAY"
    row.range = type(row.range) == "string" and row.range or "DOWN"
    row.roamRange = (row.roamRange == "LEFT_RIGHT"
      or row.roamRange == "UP_DOWN") and row.roamRange or "ANY_DIR"
    row.tone = type(row.tone) == "string" and row.tone or "route"
    return row
  end

  local function normalizePending(value)
    if type(value) ~= "table" or type(value.token) ~= "string"
        or not sceneById[value.sceneId] or not maps[value.mapId]
        or type(value.actors) ~= "table" then return nil end
    local pending = copy(value)
    local actors, seen = {}, {}
    for _, raw in ipairs(value.actors) do
      local row = normalizePendingActor(raw)
      if row and not seen[row.actor] then
        seen[row.actor] = true
        actors[#actors + 1] = row
      end
    end
    if #actors < 1 or #actors > 2 then return nil end
    pending.actors = actors
    pending.sharedShown = pending.sharedShown == true
    if type(pending.sharedText) ~= "string" then pending.sharedText = nil end
    return pending
  end

  local function normalize(raw)
    if type(raw) ~= "table" then return nil end
    local version = integer(raw.version, 1)
    if version > J.STATE_VERSION then
      J.readOnly, J.futureVersion = true, version
      return nil
    end
    J.readOnly, J.futureVersion = false, nil
    raw.version = J.STATE_VERSION
    raw.nextToken = math.max(1, integer(raw.nextToken, 1))
    raw.actors = type(raw.actors) == "table" and raw.actors or {}
    for actor in pairs(CHARACTER_IDS) do
      raw.actors[actor] = normalizeActor(raw.actors[actor])
    end
    local completed = {}
    for id, value in pairs(type(raw.completedScenes) == "table"
        and raw.completedScenes or {}) do
      if sceneById[id] and value == true then completed[id] = true end
    end
    raw.completedScenes = completed
    raw.pending = normalizePending(raw.pending)
    return raw
  end

  function J.newState()
    local state = {
      version = J.STATE_VERSION, nextToken = 1,
      actors = {}, completedScenes = {}, pending = nil,
    }
    for actor in pairs(CHARACTER_IDS) do state.actors[actor] = normalizeActor() end
    return state
  end

  function J.state(create)
    if not (mod.save and type(mod.save.get) == "function"
        and type(mod.save.set) == "function") then return nil end
    local raw = savedState()
    if type(raw) ~= "table" then
      if create == false then return nil end
      raw = J.newState()
    end
    local state = normalize(raw)
    if state and not J.readOnly and not persist(state) then return nil end
    return state
  end

  function J.actorJourney(state, actor)
    if not (type(state) == "table" and CHARACTER_IDS[actor]) then return nil end
    state.actors = type(state.actors) == "table" and state.actors or {}
    state.actors[actor] = normalizeActor(state.actors[actor])
    return state.actors[actor]
  end

  function J.sceneContract()
    return copy(data.scenes)
  end

  function J.personaContract()
    return copy(data.personaLeads)
  end

  function J.progressRank(game)
    if not (base and type(base.progressContext) == "function") then return 0 end
    local ok, context = pcall(base.progressContext, game)
    if not (ok and type(context) == "table") then return 0 end
    if context.phase and context.phase ~= "ngplus" then return 6 end
    local badges = integer(context.badges)
    if badges >= 8 then return 5 end
    if badges >= 6 then return 4 end
    if badges >= 4 then return 3 end
    if badges >= 2 then return 2 end
    return 1
  end

  local function roleActor(roles, role)
    local actor = roles and roles[role]
    return CHARACTER_IDS[actor] and actor or nil
  end

  local function takeToken(state, prefix)
    local serial = math.max(1, integer(state.nextToken, 1))
    state.nextToken = serial + 1
    return "rival-journey:" .. tostring(prefix or "scene") .. ":" .. serial
  end

  function J.buildJourneyBattlePlan(game, actor, actorState)
    if not (CHARACTER_IDS[actor] and type(base.buildBattlePlan) == "function") then
      return nil
    end
    local stage = clamp(actorState and actorState.teamStage or 1, 1, 6)
    local desired = stage <= 2 and 2 or stage <= 4 and 3 or 4
    local penalty = math.max(0, 6 - stage)
    -- Life of a Rival owns its actor-strength floor in its own save bucket.
    -- Never pass the parallel-journey state here: buildBattlePlan persists the
    -- supplied table, and sharing it would alias both save keys.  The next
    -- Life normalization would then erase our differently shaped `pending`
    -- transaction precisely when the first authored battle scene is entered.
    local baseState = type(base.state) == "function" and base.state(true) or nil
    local ok, plan = pcall(base.buildBattlePlan, game, actor, baseState, {
      teamSize=desired, levelPenalty=penalty,
      source="rival_parallel_journey",
    })
    if not (ok and type(plan) == "table" and type(plan.team) == "table"
        and #plan.team > 0) then return nil end
    desired = math.min(desired, #plan.team)
    if desired < 1 then return nil end
    local team = {}
    for index = 1, desired do
      local row = copy(plan.team[index])
      if type(row) ~= "table" or type(row.species) ~= "string" then return nil end
      team[index] = row
    end
    plan = copy(plan)
    plan.actor, plan.team = actor, team
    plan.journeyStage = stage
    plan.journeySource = "rival_parallel_journey"
    return plan
  end

  local function baseReady(game, mapId)
    if base.active then return false end
    if type(base.eligible) ~= "function" or not base.eligible(game) then return false end
    if type(base.mapEligible) ~= "function" or not base.mapEligible(game, mapId) then
      return false
    end
    if type(base.contextSafe) == "function" and not base.contextSafe(game, true) then
      return false
    end
    local roles = type(base.characterRoles) == "function"
      and base.characterRoles(game) or nil
    if not (roles and CHARACTER_IDS[roles.rival] and CHARACTER_IDS[roles.third]) then
      return false
    end
    local baseState = type(base.state) == "function" and base.state(false) or nil
    if type(base.hasThirdIntroduction) ~= "function"
        or not base.hasThirdIntroduction(baseState, roles.third) then return false end
    return true, roles
  end

  local function pendingMatchesRoles(pending, roles)
    if not (pending and roles) then return false end
    local seen = {}
    for _, row in ipairs(pending.actors or {}) do
      local expected = roleActor(roles, row.role)
      if not expected or row.actor ~= expected or seen[row.role] then return false end
      seen[row.role] = true
    end
    return true
  end

  local function preparedActor(game, state, roles, scene, definition, values)
    local actor = roleActor(roles, definition.role)
    if not actor then return nil end
    local actorState = J.actorJourney(state, actor)
    local plan = definition.battle
      and J.buildJourneyBattlePlan(game, actor, actorState) or nil
    local lead = data.personaLeads[actor][definition.tone]
    local bodyEn = substitute(definition.en, values)
      :gsub("^[^:]+:%s*", "", 1)
    local bodyDe = substitute(definition.de, values)
      :gsub("^[^:]+:%s*", "", 1)
    local en = substitute(lead.en, values) .. "\f" .. bodyEn
    local de = substitute(lead.de, values) .. "\f" .. bodyDe
    return {
      token = takeToken(state, actor:lower()), actor = actor,
      role = definition.role, sceneId = scene.id,
      activity = definition.activity, tone = definition.tone,
      range = definition.range or "DOWN",
      movement = definition.movement == "WALK" and "WALK" or "STAY",
      roamRange = definition.roamRange,
      en = en, de = de, text = tr(en, de),
      journeyStage = actorState.teamStage,
      battleOffered = plan ~= nil, battlePlan = plan,
      talked = false, finished = false, battleStarted = false,
      activityCommitted = false, spawnCounted = false,
    }
  end

  local recoverReceivedRows

  local function retireOtherVisit(game, state, mapId)
    if not (state and state.pending and state.pending.mapId ~= mapId) then
      return false
    end
    -- Finish only work already received. Unspoken rows remain eligible for a
    -- later scene, but must not carry a previous stay's duo/offer roll onto
    -- another visit or block every other authored route in the meantime.
    recoverReceivedRows(state, game)
    state.pending = nil
    persist(state)
    if J.active then J.cleanup(J.active) end
    return true
  end

  function J.prepareScene(game, state, mapId)
    state = state or J.state(true)
    -- A completed activity is not a departure. Keep its visit until the
    -- player actually leaves the map, including save/reload on that map.
    retireOtherVisit(game, state, mapId)
    if not (state and not state.pending and maps[mapId]) then return nil end
    local ready, roles = baseReady(game, mapId)
    if not ready then return nil end
    -- Authored errands may decorate a visit, never replace the shared
    -- 70/20/10 presence decision with their own fixed duo composition.
    local visit
    if type(base.prepareVisit) == "function" then
      visit = base.prepareVisit(game, base.state(true), mapId)
      if not visit or visit.mode == "none" or visit.duel then return nil end
    end
    local rank = J.progressRank(game)
    local values = replacements(game, roles)
    for _, scene in ipairs(data.scenes) do
      local matches = not visit or #scene.actors == #visit.actors
      local visitors = {}
      for _, entry in ipairs(visit and visit.actors or {}) do visitors[entry.actor]=entry end
      if visit then
        for _, definition in ipairs(scene.actors) do
          if not visitors[roleActor(roles,definition.role)] then matches=false end
        end
      end
      if matches and scene.mapId == mapId and scene.minRank <= rank
          and state.completedScenes[scene.id] ~= true then
        local rows = {}
        for _, definition in ipairs(scene.actors) do
          local row = preparedActor(game, state, roles, scene, definition, values)
          if not row then return nil end
          local entry = visitors[row.actor]
          row.rareHint=visit and copy(visit.rareHint) or nil
          if entry and not entry.battleOffered then
            row.battleOffered, row.battlePlan = false, nil
            -- An authored battle invitation is not appropriate on a visit
            -- whose persistent offer roll says there is no challenge.
            if definition.battle and entry.dialogue then
              row.en, row.de = entry.dialogue.en, entry.dialogue.de
              row.text = entry.dialogue.text or tr(row.en,row.de)
            end
          end
          rows[#rows + 1] = row
        end
        local pending = {
          token = takeToken(state, scene.id), sceneId = scene.id,
          mapId = mapId, minRank = scene.minRank, actors = rows,
          sharedText = scene.shared and tr(substitute(scene.shared.en, values),
            substitute(scene.shared.de, values)) or nil,
          sharedShown = false,
          visitToken = visit and visit.token or nil,
        }
        state.pending = pending
        if not persist(state) then state.pending = nil; return nil end
        return pending
      end
    end
    return nil
  end

  function J.isBusy()
    if J.active then return true end
    local state = savedState()
    local pending = type(state) == "table" and state.pending or nil
    if type(pending) ~= "table" then return false end
    local currentMap = J.game and J.game.overworld and J.game.overworld.map
      and J.game.overworld.map.id
    return currentMap == nil or currentMap == pending.mapId
  end

  local function mapCall(map, name, ...)
    local method = map and map[name]
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, map, ...)
    return ok and value or nil
  end

  local function occupied(ow, x, y)
    if ow and type(ow.npcAtCell) == "function" then
      local ok, value = pcall(ow.npcAtCell, ow, x, y)
      if ok and value then return true end
    end
    for _, bucket in ipairs({ ow and ow.npcs, ow and ow.entities }) do
      for _, row in pairs(type(bucket) == "table" and bucket or {}) do
        local raw = row and (row.npc or row)
        if raw and (raw.cellX == x or raw.x == x)
            and (raw.cellY == y or raw.y == y) then return true end
      end
    end
    return false
  end

  local function safeCell(game, ow, x, y)
    local map = ow and ow.map
    if not map or mapCall(map, "inBounds", x, y) == false
        or mapCall(map, "isWalkableCell", x, y) ~= true
        or mapCall(map, "warpAtCell", x, y) ~= nil
        or mapCall(map, "signAtCell", x, y) ~= nil
        or mapCall(map, "isWarpTileCell", x, y) == true
        or occupied(ow, x, y) then return false end
    if type(spawnSafety.isSafeCell) ~= "function" then return false end
    local ok, allowed = pcall(spawnSafety.isSafeCell,
      game, ow, map, x, y, { source = "rival_parallel_journey" })
    return ok and allowed == true
  end

  function J.findSceneCells(game, ow, count)
    count = clamp(count, 1, 2)
    local player, map = ow and ow.player, ow and ow.map
    local startX = player and tonumber(player.cellX or player.x)
    local startY = player and tonumber(player.cellY or player.y)
    if not (map and startX and startY) then return nil end
    startX, startY = math.floor(startX), math.floor(startY)
    local directions = { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }
    local queue, head, seen, cells = { { startX, startY, 0 } }, 1, {}, {}
    seen[startX .. ":" .. startY] = true
    while head <= #queue and #cells < count do
      local row = queue[head]; head = head + 1
      local x, y, distance = row[1], row[2], row[3]
      local separated = true
      for _, cell in ipairs(cells) do
        if math.abs(x-cell.x)+math.abs(y-cell.y)<6 then separated=false end
      end
      -- Parallel errands are independent visits, not an adjacent staged
      -- duel. Defer in cramped maps instead of stacking both by the player.
      if separated and distance >= 3 and distance <= 8 and safeCell(game, ow, x, y) then
        cells[#cells + 1] = { x = x, y = y }
      end
      if distance < 8 then
        for _, direction in ipairs(directions) do
          local nx, ny = x + direction[1], y + direction[2]
          local key = nx .. ":" .. ny
          if not seen[key] and mapCall(map, "inBounds", nx, ny) ~= false
              and mapCall(map, "isWalkableCell", nx, ny) == true then
            seen[key] = true
            queue[#queue + 1] = { nx, ny, distance + 1 }
          end
        end
      end
    end
    return #cells == count and cells or nil
  end

  local function fieldSprite(actor)
    if type(characters.getCharacterSprite) ~= "function" then return nil end
    local ok, visual = pcall(characters.getCharacterSprite, actor, "overworld")
    return ok and type(visual) == "table" and type(visual.sprite) == "string"
      and visual.sprite or nil
  end

  local function removeActiveRow(active, activeRow)
    if not (active and activeRow) then return false end
    if activeRow.npcId and mod.world and type(mod.world.removeNpc) == "function" then
      pcall(mod.world.removeNpc, mod.world, activeRow.npcId)
    end
    local raw = activeRow.npc and (activeRow.npc.npc or activeRow.npc)
    if raw then raw.frozen = false end
    active.byNpc[activeRow.npcId] = nil
    active.byToken[activeRow.token] = nil
    return true
  end

  function J.cleanup(active)
    active = active or J.active
    if not active then return false end
    local rows = {}
    for _, row in pairs(active.byToken or {}) do rows[#rows + 1] = row end
    for _, row in ipairs(rows) do removeActiveRow(active, row) end
    if J.active == active then J.active = nil end
    return true
  end

  local rememberScene

  recoverReceivedRows = function(state, game)
    local changed = false
    for _, row in ipairs(state and state.pending and state.pending.actors or {}) do
      if not row.finished and (row.battleStarted or row.talked) then
        local actorState = J.actorJourney(state, row.actor)
        local result
        if row.battleStarted then
          result = "interrupted"
          actorState.interrupted = integer(actorState.interrupted) + 1
        elseif row.battleOffered then
          -- The textbox push is the durable receipt. A reload while its
          -- default-No choice is still open retires it as a decline instead
          -- of replaying the offer and potentially starting two battles.
          result = "decline"
          actorState.declines = integer(actorState.declines) + 1
        else
          result = "talk"
        end
        actorState.lastResult = result
        if not row.activityCommitted then
          row.activityCommitted = true
          actorState.activities = integer(actorState.activities) + 1
          actorState.lastSceneId = state.pending.sceneId
          actorState.lastActivity = row.activity
          actorState.lastMapId = state.pending.mapId
          if rememberScene then rememberScene(actorState, state.pending.sceneId) end
          local rank = J.progressRank(game)
          actorState.teamStage = math.max(actorState.teamStage, math.min(rank,
            clamp(1 + math.floor(actorState.activities / 2), 1, 6)))
          actorState.chapter = actorState.teamStage
        end
        row.finished, row.result, row.battleStarted = true, result, false
        changed = true
      end
    end
    local complete = state and state.pending ~= nil
    for _, row in ipairs(state and state.pending and state.pending.actors or {}) do
      if not row.finished then complete = false; break end
    end
    if complete and not state.pending.completed then
      -- The last actor receipt may have persisted just before the shared
      -- conclusion callback. A reload must finalize that fully received scene
      -- instead of leaving a permanent zero-row busy state or replaying text.
      state.completedScenes[state.pending.sceneId] = true
      state.pending.completed = true
      changed = true
    end
    if changed then persist(state) end
    return changed
  end

  function J.trySpawn(game)
    game = game or J.game
    if J.active and J.active.game ~= game then J.cleanup(J.active) end
    if J.active or base.active then return false end
    local ow = game and game.overworld
    local mapId = ow and ow.map and ow.map.id
    local state = J.state(true)
    if not (state and state.pending and state.pending.mapId == mapId) then return false end
    local ready, roles = baseReady(game, mapId)
    if not ready then return false end
    if not pendingMatchesRoles(state.pending, roles) then
      -- Character/Legacy identity changed after the scene was frozen.  Never
      -- materialize stale actors; the uncompleted authored scene may be
      -- prepared again under the newly verified matrix.
      state.pending = nil
      persist(state)
      return false
    end
    recoverReceivedRows(state, game)
    if not state.pending then return false end
    local rows = {}
    for _, row in ipairs(state.pending.actors) do
      rows[#rows + 1] = row
    end
    if #rows == 0 then return false end
    local cells = J.findSceneCells(game, ow, #rows)
    if not cells then return false end
    local created = {}
    for index, row in ipairs(rows) do
      local sprite = fieldSprite(row.actor)
      if not (sprite and mod.world and type(mod.world.spawnNpc) == "function") then
        for _, id in ipairs(created) do pcall(mod.world.removeNpc, mod.world, id) end
        return false
      end
      local ok, id = pcall(mod.world.spawnNpc, mod.world, mapId, {
        name = "KA_PARALLEL_JOURNEY_" .. row.actor,
        sprite = sprite, movement = row.movement,
        range = row.movement == "WALK" and row.roamRange or row.range,
        -- Walking companions are nonblocking ambient actors.  Collision still
        -- keeps them off warps and other entities, while passability prevents
        -- their independent errands from closing a mandatory player path.
        passable = row.movement == "WALK",
        text = J.TEXT, x = cells[index].x, y = cells[index].y,
      })
      if not (ok and id) then
        for _, createdId in ipairs(created) do
          pcall(mod.world.removeNpc, mod.world, createdId)
        end
        return false
      end
      created[#created + 1] = id
    end
    local active = {
      game = game, save = game.save, ow = ow, mapId = mapId,
      sceneToken = state.pending.token, byNpc = {}, byToken = {},
    }
    for index, row in ipairs(rows) do
      local id, handle = created[index], nil
      if type(mod.world.npc) == "function" then
        local found, value = pcall(mod.world.npc, mod.world, mapId, id)
        handle = found and value or nil
      end
      if not handle then
        for _, createdId in ipairs(created) do
          pcall(mod.world.removeNpc, mod.world, createdId)
        end
        return false
      end
      handle.ascendantCharacter = row.actor
      handle.ascendantJourneyActivity = row.activity
      local raw = handle.npc or handle
      raw.ascendantCharacter = row.actor
      raw.ascendantJourneyActivity = row.activity
      -- Engine 0.1.90 does not copy the mod definition's passable extension
      -- into NPC.new. Bridge it after obtaining the live handle so ambient
      -- walkers cannot close a mandatory player path on the pinned runtime.
      local passable = row.movement == "WALK"
      handle.passable, raw.passable = passable, passable
      local activeRow = { token = row.token, actor = row.actor, role = row.role,
        npcId = id, npc = handle, definition = row, talking = false }
      active.byNpc[id], active.byToken[row.token] = activeRow, activeRow
      row.spawnCounted = true
    end
    if not persist(state) then
      for _, id in ipairs(created) do pcall(mod.world.removeNpc, mod.world, id) end
      return false
    end
    J.active = active
    return true
  end

  local function TextBox(game, text, done, boxOpts)
    if type(opts.textBox) == "function" then
      return opts.textBox(game, text, done, boxOpts)
    end
    local ok, module = pcall(require, "src.render.TextBox")
    if not (ok and module and type(module.new) == "function") then return nil end
    return module.new(game, text, done, boxOpts)
  end

  local function pushText(game, text, done, boxOpts)
    local box = TextBox(game, text, done, boxOpts)
    if not (box and game and game.stack and type(game.stack.push) == "function") then
      return false
    end
    local ok = pcall(game.stack.push, game.stack, box)
    return ok
  end

  local function findPendingRow(state, token)
    for _, row in ipairs(state and state.pending and state.pending.actors or {}) do
      if row.token == token then return row end
    end
    return nil
  end

  rememberScene = function(actorState, sceneId)
    local history = actorState.history
    for index = #history, 1, -1 do
      if history[index] == sceneId then table.remove(history, index) end
    end
    history[#history + 1] = sceneId
    while #history > 16 do table.remove(history, 1) end
  end

  local function commitTalk(state, row)
    if row.talked then return true end
    local actorState = J.actorJourney(state, row.actor)
    row.talked = true
    actorState.talks = integer(actorState.talks) + 1
    if persist(state) then return true end
    row.talked = false
    actorState.talks = math.max(0, integer(actorState.talks) - 1)
    return false
  end

  local function allFinished(pending)
    for _, row in ipairs(pending and pending.actors or {}) do
      if not row.finished then return false end
    end
    return true
  end

  local function finalizeScene(active, state, done)
    local pending = state and state.pending
    if not (pending and pending.token == active.sceneToken) then
      J.cleanup(active); if done then done() end; return false
    end
    state.completedScenes[pending.sceneId] = true
    pending.completed = true
    persist(state)
    if done then done() end
    return true
  end

  local function finishActor(active, row, result, done)
    local state = J.state(true)
    local pendingRow = state and findPendingRow(state, row.token)
    if not (state and pendingRow and state.pending.token == active.sceneToken) then
      if done then done() end; return false
    end
    local raw = row.npc and (row.npc.npc or row.npc)
    row.talking = false
    if raw then raw.frozen = false end
    -- Late/duplicate callbacks and subsequent conversations cannot award
    -- another activity or battle. Presence is independent of this receipt.
    if pendingRow.finished then if done then done() end;return true end
    local actorState = J.actorJourney(state, pendingRow.actor)
    if result == "win" or result == "lose" then
      actorState.battles = integer(actorState.battles) + 1
      if result == "win" then actorState.wins = integer(actorState.wins) + 1
      else actorState.losses = integer(actorState.losses) + 1 end
    elseif result == "decline" then
      actorState.declines = integer(actorState.declines) + 1
    end
    if not pendingRow.activityCommitted then
      pendingRow.activityCommitted = true
      actorState.activities = integer(actorState.activities) + 1
      actorState.lastSceneId = state.pending.sceneId
      actorState.lastActivity = pendingRow.activity
      actorState.lastMapId = state.pending.mapId
      actorState.lastResult = result
      rememberScene(actorState, state.pending.sceneId)
      local rank = J.progressRank(active.game)
      actorState.teamStage = math.max(actorState.teamStage, math.min(rank,
        clamp(1 + math.floor(actorState.activities / 2), 1, 6)))
      actorState.chapter = actorState.teamStage
    end
    pendingRow.finished, pendingRow.result = true, result
    pendingRow.battleStarted = false
    persist(state)
    if not allFinished(state.pending) then
      if done then done() end
      return true
    end
    if state.pending.sharedText and not state.pending.sharedShown then
      state.pending.sharedShown = true
      persist(state)
      local shown = pushText(active.game, state.pending.sharedText, function()
        finalizeScene(active, J.state(true), done)
      end)
      if shown then return true end
    end
    return finalizeScene(active, state, done)
  end

  local function portrait(actor)
    if type(characters.getCharacterSprite) ~= "function" then return nil, false end
    local ok, visual = pcall(characters.getCharacterSprite, actor, "rivalPortrait")
    if not (ok and type(visual) == "table" and type(visual.path) == "string") then
      return nil, false
    end
    local path = visual.path
    if path:sub(1, 5) ~= "save/" and mod.path then path = mod.path .. "/" .. path end
    return path, visual.trueColor ~= false
  end

  local function makeActorBattle(game, plan, actor, context)
    local trainer = game and game.data and game.data.trainers
      and game.data.trainers[plan.class]
    if type(trainer) ~= "table" then
      return pcall(postgame.newForcedBattle, game, plan.class,
        copy(plan.team), nil, context)
    end
    -- Engine 0.1.90 freezes trainerPic and introText inside newTrainer. Apply
    -- the actor presentation only for that synchronous construction window,
    -- then restore the shared trainer registry before returning.
    local oldName, oldPic, oldMoney = trainer.name, trainer.pic,
      trainer.baseMoney
    local pic = portrait(actor)
    trainer.name = displayName(actor)
    if pic then trainer.pic = pic end
    trainer.baseMoney = 0
    local ok, battle = pcall(postgame.newForcedBattle, game, plan.class,
      copy(plan.team), nil, context)
    trainer.name, trainer.pic, trainer.baseMoney = oldName, oldPic, oldMoney
    return ok, battle
  end

  local function startBattle(active, activeRow, pendingRow, done)
    if J.active ~= active or active.save ~= active.game.save
        or not active.ow.map or active.ow.map.id ~= active.mapId then return false end
    local plan = pendingRow.battlePlan
    if not (type(plan) == "table" and type(plan.team) == "table"
        and #plan.team > 0) then return finishActor(active, activeRow, "decline", done) end
    local state = J.state(true)
    local durable = state and findPendingRow(state, activeRow.token)
    if not durable or durable.finished or durable.battleStarted then return false end
    if type(base.progressBattlePlan) == "function" then
      local progressed = base.progressBattlePlan(active.game, plan,
        activeRow.actor, "PARALLEL_" .. tostring(
          pendingRow.journeyStage or "UNKNOWN"))
      if not progressed then
        return finishActor(active, activeRow, "decline", done)
      end
      plan = progressed
      durable.battlePlan = copy(plan)
    end
    durable.battleStarted = true
    if not persist(state) then durable.battleStarted = false; return false end
    local ok, battle = makeActorBattle(active.game, plan, activeRow.actor, {
        kind = "rival_parallel_journey", actor = activeRow.actor,
        key = activeRow.actor, token = activeRow.token,
        source = "rival_parallel_journey", suppressRewards = true,
      })
    if not (ok and battle and not battle.dead) then
      durable.battleStarted = false; persist(state)
      return finishActor(active, activeRow, "decline", done)
    end
    battle.ascendantLifeRival = true
    battle.ascendantParallelJourney = true
    battle.ascendantLifeRivalCharacter = activeRow.actor
    battle.ascendantLifeRivalToken = activeRow.token
    battle.rematch, battle.rematchRewardSuppressed = true, true
    battle.ascendantNoBonusReward = true
    battle.ascendantForcedSource = "rival_parallel_journey"
    local pic, trueColor = portrait(activeRow.actor)
    local original = battle.trainer or {}
    battle.trainer = setmetatable({
      name = displayName(activeRow.actor), pic = pic or original.pic,
      trueColor = pic and trueColor or original.trueColor,
      ascendantCharacter = activeRow.actor,
      -- Engine 0.1.90 does not consume the reward-suppression metadata; its
      -- native trainer prize is derived directly from this field.
      baseMoney = 0,
    }, { __index = original })
    local money = tonumber(active.game.save and active.game.save.money) or 0
    local finishCalled = false
    battle.onFinish = function(result)
      if finishCalled then return end
      finishCalled = true
      if active.ow and type(active.ow.afterBattle) == "function" then
        pcall(active.ow.afterBattle, active.ow, result, battle)
      end
      local outcome = result == "win" and "win" or "lose"
      if outcome == "lose" and active.game.save then active.game.save.money = money end
      finishActor(active, activeRow, outcome, done)
    end
    if not (active.ow and type(active.ow.pushBattle) == "function") then
      return finishActor(active, activeRow, "decline", done)
    end
    local pushed, accepted = pcall(active.ow.pushBattle, active.ow, battle)
    if not pushed or accepted == false then
      return finishActor(active, activeRow, "decline", done)
    end
    return true
  end

  function J.handleTalk(game, ow, npc, done)
    local active = J.active
    if not (active and active.game == game and active.ow == ow and npc
        and active.mapId == ow.map.id) then return false end
    local id = npc.id
    local activeRow = id and active.byNpc[id] or nil
    if not activeRow then
      for _, candidate in pairs(active.byNpc) do
        if npc == candidate.npc or npc == (candidate.npc.npc or candidate.npc) then
          activeRow = candidate; break
        end
      end
    end
    if not activeRow or activeRow.talking then return false end
    local state = J.state(true)
    local pendingRow = state and findPendingRow(state, activeRow.token)
    if not (pendingRow and (pendingRow.finished or not pendingRow.battleStarted)) then
      return false
    end
    activeRow.talking = true
    local raw = activeRow.npc.npc or activeRow.npc
    raw.frozen = true
    if type(raw.facePlayer) == "function" then pcall(raw.facePlayer, raw, ow.player) end
    if pendingRow.finished then
      local repeatCount = integer(pendingRow.repeatTalks) + 1
      if type(base.followupDialogue) == "function" then
        local follow = base.followupDialogue(game, pendingRow.actor,
          active.mapId, repeatCount,pendingRow.rareHint)
        if follow then
          local function released()return finishActor(active, activeRow, "talk", done)end
          local shown = pushText(game, follow.text, released)
          if shown then pendingRow.repeatTalks = repeatCount; persist(state)
          else released() end
          return shown
        end
      end
      pendingRow.repeatTalks = repeatCount
      persist(state)
      -- No repeated challenge or progression reward. Full route/roamer
      -- editorial remains separate; these acknowledgements make no invented
      -- encounter claims while retaining each character's voice.
      local lines = {
        BLUE = {
          {"I'm not done here yet.\nYou can go on ahead.", "Ich bin noch nicht fertig.\nGeh du ruhig schon vor."},
          {"Don't get too comfortable.\nI'll catch up with you.", "Werd nicht zu selbstsicher.\nIch hole dich noch ein."},
        },
        RED = {
          {"A little more practice.\nThen I'll move on.", "Noch ein wenig üben.\nDann ziehe ich weiter."},
          {"That gave me an idea.\nI'll try it out first.", "Das bringt mich auf etwas.\nIch probiere es erst aus."},
        },
        GREEN = {
          {"I'm taking my time here.\nNo need to rush.", "Ich lasse mir hier Zeit.\nNur keine Eile."},
          {"I'll see you on the road.\nI'm not falling behind.", "Wir sehen uns unterwegs.\nIch bleibe nicht zurück."},
        },
      }
      local choices = lines[pendingRow.actor]
      local line = choices[(pendingRow.repeatTalks - 1) % #choices + 1]
      local function released()return finishActor(active, activeRow, "talk", done)end
      if not pushText(game, tr(line[1],line[2]), released) then released() end
      return true
    end
    if not pendingRow.battleOffered then
      local shown = pushText(game, pendingRow.text, function()
        finishActor(active, activeRow, "talk", done)
      end)
      if shown then commitTalk(state, pendingRow)
      else finishActor(active, activeRow, "talk", done) end
      return true
    end
    local prompt = tr("Battle before I continue?", "Kampf, bevor ich weiterziehe?")
    local shown = pushText(game, pendingRow.text .. "\f" .. prompt, nil, {
      defaultNo = true,
      choice = function(yes)
        if yes then return startBattle(active, activeRow, pendingRow, done) end
        return finishActor(active, activeRow, "decline", done)
      end,
    })
    if shown then commitTalk(state, pendingRow)
    else finishActor(active, activeRow, "talk", done) end
    return true
  end

  function J.onMapEntered(game, mapId)
    if J.active and (J.active.game ~= game or J.active.mapId ~= mapId
        or J.active.ow ~= (game and game.overworld)) then
      J.cleanup(J.active)
    end
    local state = J.state(true)
    if not state then return false end
    retireOtherVisit(game, state, mapId)
    if not maps[mapId] then return false end
    if state.pending and state.pending.mapId ~= mapId then return false end
    if state.pending then return true end
    return J.prepareScene(game, state, mapId) ~= nil
  end

  if mod.content and mod.content.map_scripts
      and type(mod.content.map_scripts.register) == "function" then
    for mapId in pairs(maps) do
      mod.content.map_scripts:register(mapId, {
        priority = 2840,
        talk = { [J.TEXT] = function(game, ow, npc, done)
          return J.handleTalk(game, ow, npc, done)
        end },
      })
    end
  end

  local function rememberGame(event)
    if J.active then J.cleanup(J.active) end
    J.game = event and event.game or J.game
    if J.game and type(base.eligible) == "function" and base.eligible(J.game) then
      J.state(true)
    end
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function(event)
      J.game = event and event.game or J.game
    end, 1040)
    mod.events:on("save.loaded", rememberGame, 1040)
    mod.events:on("save.created", rememberGame, 1040)
    mod.events:on("map.entered", function(event)
      local game = event and event.game or J.game
      local mapId = event and (event.mapId or event.map and event.map.id)
      J.onMapEntered(game, mapId)
    end, 2840)
    mod.events:on("world.stepped", function(event)
      local game = event and event.game or J.game
      if J.active or base.active then return end
      local mapId = event and event.mapId or game and game.overworld
        and game.overworld.map and game.overworld.map.id
      if not maps[mapId] then return end
      local state = J.state(true)
      if not state then return end
      if not state.pending then J.prepareScene(game, state, mapId) end
      if J.state(false) and J.state(false).pending then J.trySpawn(game) end
    end, 4540)
  end

  if type(base.bindParallelJourney) == "function" then
    assert(base.bindParallelJourney(J) ~= false,
      "Life of a Rival rejected parallel journey coordination")
  end

  return J
end
