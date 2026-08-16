-- E-SHARED/STORY: post-Hall-of-Fame, character-routed field researchers.
--
-- The researchers are runtime NPCs rather than permanent map patches.  This
-- keeps them absent before the Hall of Fame and lets each correct three-way
-- deduction set the only new entrance authority used by Package A.
return function(mod, opts)
  opts = opts or {}

  local M = { registered = false, installed = false, game = nil }
  M.RUN_STATE = "hidden_evolution_story_campaign"
  M.STATE_VERSION = 3
  M.RETRY_STEPS = 250
  M.FLAG_PREFIX = "KA_HEVO_FISSURE_DISCOVERED_"

  -- Each preferred cell and its bounded fallback list were audited against
  -- native collision, warps and base objects. Researchers never search beyond
  -- that list; their city placement remains part of the clue contract.
  M.HINTS = {
    RED = {
      map = "CELADON_CITY", text = "TEXT_KA_HEVO_PROFESSOR_RED",
      object = "KA_HEVO_PROFESSOR_RED", professor = "Professor Aster",
      x = 38, y = 22, sprite = "SPRITE_SCIENTIST",
      cells = { {38,22}, {37,22}, {39,22}, {38,23}, {37,23}, {39,23} },
      riddle = {
        en = "ASTER: GROUDON'S\nheat split rock.\fThe scar lies on\nthe road from\fVIRIDIAN toward\nINDIGO PLATEAU,\fbefore the gate.\nWhere is it?",
        de = "ASTER: GROUDONS\nHitze riss Fels.\fDer Riss liegt auf\ndem Weg von\fVERTANIA zum\nINDIGO-PLATEAU,\fnoch vor dem Tor.\nWo liegt er?",
      },
      question = {
        en = "WHERE IS THE SCAR?",
        de = "WO LIEGT DER RISS?",
      },
      choices = {
        { value = "league", en = "VIRIDIAN WEST", de = "WESTL. VERTANIA" },
        { value = "moon", en = "MT MOON ROAD", de = "MONDBERG-WEG" },
        { value = "seafoam", en = "SEAFOAM CLIFF", de = "SEESCHAUM-KLIPPE" },
      },
      correct = "league",
      wrong = {
        en = "ASTER: Not quite.\fCome back when you\nare ready...",
        de = "ASTER: Nicht ganz.\fKomm wieder, wenn\ndu bereit bist ...",
      },
      cooldown = {
        en = "ASTER: Come back\nlater.",
        de = "ASTER: Komm\nspäter wieder.",
      },
      retry = {
        en = "ASTER: Would you\nlike to try the\friddle again?",
        de = "ASTER: Willst du\nes noch einmal\fversuchen?",
      },
      solved = {
        en = "ASTER: Correct.\fFissure opened.\fFrom Viridian to\nthe Plateau.\fFirst bare wall\npast the city.",
        de = "ASTER: Richtig.\fRiss geöffnet.\fVon Vertania zum\nPlateau.\fErste kahle Wand\nnach der Stadt.",
      },
      dismissal = {
        en = "ASTER: This basalt\nis not for you.",
        de = "ASTER: Basalt\nkennt andre Wege.",
      },
    },
    GREEN = {
      map = "PEWTER_CITY", text = "TEXT_KA_HEVO_PROFESSOR_GREEN",
      object = "KA_HEVO_PROFESSOR_GREEN", professor = "Professor Linden",
      x = 8, y = 3, sprite = "SPRITE_SCIENTIST",
      cells = { {8,3}, {7,3}, {8,4}, {7,4}, {6,3} },
      riddle = {
        en = "LINDEN: RAYQUAZA\nwind marked stone\fbetween PEWTER\nand MT MOON.\fNorth wall holds\nthe scar.\fWhere is it?",
        de = "LINDEN: RAYQUAZAS\nWind ritzte Fels\fzwischen MARMORIA\nund MONDBERG.\fNordwand trägt\nden Riss.\fWo liegt er?",
      },
      question = {
        en = "WHERE IS THE SCAR?",
        de = "WO LIEGT DER RISS?",
      },
      choices = {
        { value = "moon", en = "MOON APPROACH", de = "MONDBERG-WEG" },
        { value = "rock", en = "ROCK TUNNEL", de = "FELSTUNNEL" },
        { value = "victory", en = "VICTORY SLOPE", de = "SIEGESSTRASSE" },
      },
      correct = "moon",
      wrong = {
        en = "LINDEN: Not quite.\fCome back when you\nare ready...",
        de = "LINDEN: Nicht ganz.\fKomm wieder, wenn\ndu bereit bist ...",
      },
      cooldown = {
        en = "LINDEN: Come back\nlater.",
        de = "LINDEN: Komm\nspäter wieder.",
      },
      retry = {
        en = "LINDEN: Would you\nlike to try the\friddle again?",
        de = "LINDEN: Willst du\nes noch einmal\fversuchen?",
      },
      solved = {
        en = "LINDEN: Correct.\fFissure opened.\fFrom Pewter toward\nMt. Moon.\fThe long wall has\nthe living scar.",
        de = "LINDEN: Richtig.\fRiss geöffnet.\fVon Marmoria zum\nMondberg.\fLange Wand trägt\ndie grüne Narbe.",
      },
      dismissal = {
        en = "LINDEN: The roots\nshun your steps.",
        de = "LINDEN: Wurzeln\nmeiden deinen Weg.",
      },
    },
    BLUE = {
      map = "CINNABAR_ISLAND", text = "TEXT_KA_HEVO_PROFESSOR_BLUE",
      object = "KA_HEVO_PROFESSOR_BLUE", professor = "Professor Nera",
      x = 6, y = 11, sprite = "SPRITE_SCIENTIST",
      cells = { {6,11}, {5,11}, {7,11}, {6,10}, {5,10}, {7,10} },
      riddle = {
        en = "NERA: KYOGRE'S\ntide marked rock\fnorth of CERULEAN,\fbeyond the NUGGET\nBRIDGE.\fThere water meets\na long rock wall.\fWhere is it?",
        de = "NERA: KYOGRES Flut\nzeichnete den Fels\fnördlich von AZURIA,\fhinter der\nNUGGETBRÜCKE.\fDort trifft Wasser\nauf langen Fels.\fWo liegt er?",
      },
      question = {
        en = "WHERE IS THE SCAR?",
        de = "WO LIEGT DER RISS?",
      },
      choices = {
        { value = "nugget", en = "NUGGET HEADWATER", de = "NUGGET-QUELLEN" },
        { value = "seafoam", en = "SEAFOAM CHANNEL", de = "SEESCHAUM-KANAL" },
        { value = "cape", en = "CAPE SHORE", de = "KAP-UFER" },
      },
      correct = "nugget",
      wrong = {
        en = "NERA: Not quite.\fCome back when you\nare ready...",
        de = "NERA: Nicht ganz.\fKomm wieder, wenn\ndu bereit bist ...",
      },
      cooldown = {
        en = "NERA: Come back\nlater.",
        de = "NERA: Komm\nspäter wieder.",
      },
      retry = {
        en = "NERA: Would you\nlike to try the\friddle again?",
        de = "NERA: Willst du\nes noch einmal\fversuchen?",
      },
      solved = {
        en = "NERA: Correct.\fFissure opened.\fPast Nugget Bridge\nnear Cerulean.\fLong rock wall\nwhere water rises.",
        de = "NERA: Richtig.\fRiss geöffnet.\fHinter der\nNuggetbrücke.\fLange Felswand,\nwo Wasser steigt.",
      },
      dismissal = {
        en = "NERA: This current\nis not your wake.",
        de = "NERA: Der Strom\nfolgt andrer Spur.",
      },
    },
  }

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  local function slotIdentity(game)
    -- The save-local raw record is the authority.  In production the public
    -- character helper deliberately normalizes an absent or future value to
    -- RED for presentation; consulting it first would therefore let a
    -- partially loaded FUTURE/YELLOW slot inherit Aster and Red's cooldown.
    local save = type(game and game.save) == "table" and game.save or nil
    local modData = save and type(save.modData) == "table" and save.modData
    if type(modData) == "table" then
      local rawBucket = modData[mod.id]
      if rawBucket ~= nil and type(rawBucket) ~= "table" then
        return rawBucket, true
      end
      local bucket = type(rawBucket) == "table" and rawBucket or nil
      local state = bucket and bucket.extended_characters or nil
      return state, state ~= nil
    end
    local state = mod.save and type(mod.save.get) == "function"
      and mod.save:get("extended_characters") or nil
    return state, state ~= nil
  end

  local function character(game)
    local function resolved(value)
      if value == nil then return nil, false end
      value = type(value) == "string" and value:upper() or nil
      return value and M.HINTS[value] and value or nil, true
    end
    local extended, present = slotIdentity(game)
    if present then
      if type(extended) ~= "table" then return nil end
      local value, authoritative = resolved(extended.player_character)
      if authoritative then return value end
      -- A present but incomplete/future identity record is not a legacy Red
      -- save. Fail closed while save authority is in transition.
      return nil
    end
    if type(opts.activeCharacter) == "function" then
      local value, authoritative = resolved(opts.activeCharacter(game))
      if authoritative then return value end
    end
    if opts.characters and opts.characters.getPlayerCharacter then
      local value, authoritative = resolved(
        opts.characters.getPlayerCharacter())
      if authoritative then return value end
    end
    -- A pre-6.5 save has no extended-character record because Red was the
    -- only player. Treat that exact absence as Red after Hall of Fame; without
    -- this migration every researcher spawned but all three rejected a
    -- legitimate legacy Champion as the "wrong" character.
    return game and game.save and "RED" or nil
  end

  local function hasHall(game)
    local save = game and game.save
    if opts.postgame and type(opts.postgame.hasHallOfFame) == "function" then
      return opts.postgame.hasHallOfFame(save) == true
    end
    if type(opts.hasHallOfFame) == "function" then
      return opts.hasHallOfFame(save) == true
    end
    -- Stand-alone QA fallback mirrors postgame.hasHallOfFame exactly.  The
    -- Authority wiring above always consumes that exported function itself.
    return save and ((type(save.hallOfFame) == "table"
        and #save.hallOfFame > 0)
      or (type(save.flags) == "table"
        and save.flags.EVENT_BEAT_CHAMPION_RIVAL == true)) or false
  end

  local function campaign(create)
    local s = mod.save and mod.save:get(M.RUN_STATE)
    if type(s) ~= "table" and create ~= false then
      s = { version = M.STATE_VERSION, hints = {}, discovery = {},
        researcherRetry = {} }
    end
    if type(s) == "table" then
      s.version = math.max(tonumber(s.version) or 0, M.STATE_VERSION)
      s.hints = type(s.hints) == "table" and s.hints or {}
      s.discovery = type(s.discovery) == "table" and s.discovery or {}
      s.researcherRetry = type(s.researcherRetry) == "table"
        and s.researcherRetry or {}
    end
    return s
  end

  local function persistCampaign(s, game, flush)
    if mod.save and mod.save.set then mod.save:set(M.RUN_STATE, s) end
    -- A failed deduction is a gate transition, not disposable menu state.
    -- Persist its zero-step receipt immediately so reloading cannot erase the
    -- cooldown. The 250th physical step is flushed too; intermediate counts
    -- remain ordinary slot data and are included in every normal save.
    if flush and game and type(game.writeSave) == "function" then
      game:writeSave()
    end
    return s
  end

  local function retryRecord(key)
    local s = campaign(false)
    local row = s and s.researcherRetry[key]
    -- A future/partially written truthy row must fail closed instead of
    -- silently restoring unlimited quiz attempts.  `true` was used by one
    -- development build, so normalize it to a fresh zero-step cooldown.
    if row == true then
      row = { version = 1, failed = true, steps = 0, attempts = 1 }
      s.researcherRetry[key] = row
      persistCampaign(s, nil, false)
    end
    if type(row) ~= "table" or row.failed ~= true then return nil end
    row.steps = math.max(0, math.min(M.RETRY_STEPS,
      math.floor(tonumber(row.steps) or 0)))
    return row, s
  end

  local function startRetry(key, game)
    local s = campaign(true)
    local old = s.researcherRetry[key]
    s.researcherRetry[key] = {
      version = 1, failed = true, steps = 0,
      attempts = math.max(0,
        math.floor(tonumber(old and old.attempts) or 0)) + 1,
    }
    persistCampaign(s, game, true)
    return s.researcherRetry[key]
  end

  local function advanceRetries(game)
    local s = campaign(false)
    if not s then return false end
    -- Count only the active save's matching protagonist. Presentation/debug
    -- character switches must never work off another researcher's penalty.
    local key = character(game)
    local row = key and s.researcherRetry[key]
    if row == true then
      row = { version = 1, failed = true, steps = 0, attempts = 1 }
      s.researcherRetry[key] = row
    end
    if type(row) == "table" and row.failed == true then
      local before = math.max(0, math.floor(tonumber(row.steps) or 0))
      if before < M.RETRY_STEPS then
        row.steps = before + 1
        persistCampaign(s, game, row.steps == M.RETRY_STEPS)
        return true
      end
    end
    return false
  end

  function M.retryProgress(key)
    local row = retryRecord(key)
    if not row then return nil end
    return row.steps, M.RETRY_STEPS, row.attempts
  end

  local function discovered(key, game)
    local flags = game and game.save and game.save.flags
    -- Package A consumes this exact save flag.  The campaign table below is
    -- an audit record only, never a second authority that could say "solved"
    -- while the physical entrance still says "closed".
    return type(flags) == "table" and flags[M.FLAG_PREFIX .. key] == true
  end

  local function markDiscovered(key, game)
    local s = campaign(true)
    s.discovery[key], s.hints[key] = true, true
    s.researcherRetry[key] = nil
    persistCampaign(s, game, false)
    if game and game.save then
      game.save.flags = type(game.save.flags) == "table"
        and game.save.flags or {}
      game.save.flags[M.FLAG_PREFIX .. key] = true
    end
    if mod.world and mod.world.setFlag then
      mod.world:setFlag(M.FLAG_PREFIX .. key, true)
    end
    if game and type(game.writeSave) == "function" then game:writeSave() end
    return true
  end

  M.hasHallOfFame = hasHall
  M.discovered = discovered
  M.markDiscovered = markDiscovered

  local function show(game, text, done, options)
    if type(opts.showText) == "function" then
      return opts.showText(game, text, done, options)
    end
    game.stack:push(require("src.render.TextBox").new(game, text, done,
      options))
    return true
  end

  local function finishNpc(npc, done)
    if npc then npc.frozen = false end
    if type(done) == "function" then done() end
  end

  local function rowsFor(hint)
    local rows = {}
    for _, choice in ipairs(hint.choices) do
      rows[#rows + 1] = {
        value = choice.value,
        label = tr(choice.en, choice.de),
      }
    end
    return rows
  end

  local function openQuiz(key, game, npc, done)
    local hint = M.HINTS[key]
    local menu
    local function close(candidate)
      candidate = candidate or menu
      if candidate and type(candidate.close) == "function" then candidate:close() end
    end
    local function choose(item, candidate)
      close(candidate)
      local value = type(item) == "table" and item.value or item
      if value == hint.correct then
        markDiscovered(key, game)
        return show(game, tr(hint.solved.en, hint.solved.de), function()
          finishNpc(npc, done)
        end)
      end
      startRetry(key, game)
      return show(game, tr(hint.wrong.en, hint.wrong.de), function()
        finishNpc(npc, done)
      end)
    end
    local function cancel(candidate)
      close(candidate)
      finishNpc(npc, done)
    end
    local menuOpts = { messageBox = true, onChoose = choose, onCancel = cancel }
    if type(opts.openMenu) == "function" then
      return opts.openMenu(game, tr(hint.question.en, hint.question.de),
        rowsFor(hint), menuOpts)
    end
    local Menu = mod.ui and (mod.ui.KantoListMenu or mod.ui.ListMenu)
    if not (Menu and type(Menu.new) == "function") then
      finishNpc(npc, done)
      return false, "menu unavailable"
    end
    menu = Menu.new(game, tr(hint.question.en, hint.question.de),
      rowsFor(hint), menuOpts)
    game.stack:push(menu)
    return true
  end

  local function beginRiddle(key, game, npc, done)
    local hint = M.HINTS[key]
    return show(game, tr(hint.riddle.en, hint.riddle.de), function()
      openQuiz(key, game, npc, done)
    end)
  end

  local function offerRetry(key, game, npc, done)
    local hint = M.HINTS[key]
    return show(game, tr(hint.retry.en, hint.retry.de), nil, {
      defaultNo = true,
      choice = function(yes)
        if not yes then finishNpc(npc, done); return false, "cancelled" end
        return beginRiddle(key, game, npc, done)
      end,
    })
  end

  function M.talk(key, game, ow, npc, done)
    local active, hint = character(game), M.HINTS[key]
    if not hint then return false, "unknown researcher" end
    if npc then
      npc.frozen = true
      if type(npc.facePlayer) == "function" then
        npc:facePlayer(ow and ow.player)
      end
    end
    if active ~= key then
      return show(game, tr(hint.dismissal.en, hint.dismissal.de), function()
        finishNpc(npc, done)
      end)
    end
    if discovered(key, game) then
      return show(game, tr(hint.solved.en, hint.solved.de), function()
        finishNpc(npc, done)
      end)
    end
    local retry = retryRecord(key)
    if retry and retry.steps < M.RETRY_STEPS then
      return show(game, tr(hint.cooldown.en, hint.cooldown.de), function()
        finishNpc(npc, done)
      end)
    end
    if retry then return offerRetry(key, game, npc, done) end
    return beginRiddle(key, game, npc, done)
  end

  local function runtimeObjectIds(game, hint)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[hint.map]
    for _, object in ipairs(map and map.objects or {}) do
      if object.runtime and object.owner == mod.id
          and object.name == hint.object then
        out[#out + 1] = hint.map .. "_obj_" .. tostring(object.index)
      end
    end
    return out
  end

  local function currentNpc(ow, hint)
    for _, npc in ipairs(ow and ow.npcs or {}) do
      if npc.def and npc.def.name == hint.object then return npc end
    end
  end

  local function removeRuntime(game, hint)
    local ids = runtimeObjectIds(game, hint)
    if mod.world and mod.world.removeNpc then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
    end
    -- Runtime definitions live in the process-wide merged map catalog.  At
    -- title/new-save boundaries WorldAPI can briefly have no overworld and
    -- therefore cannot remove them.  Delete only this mod's owned definitions
    -- as a fail-closed fallback; the next map build then cannot instantiate a
    -- researcher inherited from the previous slot.
    local map = game and game.data and game.data.maps
      and game.data.maps[hint.map]
    for index = #(map and map.objects or {}), 1, -1 do
      local object = map.objects[index]
      if object.runtime and object.owner == mod.id
          and object.name == hint.object then
        table.remove(map.objects, index)
      end
    end
  end

  local function hintForMap(mapId)
    for key, hint in pairs(M.HINTS) do
      if hint.map == mapId then return key, hint end
    end
  end

  local function currentMapId(game)
    local ow = mod.world and mod.world.overworld and mod.world:overworld()
    return ow and ow.map and ow.map.id
      or game and game.overworld and game.overworld.map
        and game.overworld.map.id or nil
  end

  local function shouldSpawn(key, game)
    return hasHall(game) and character(game) == key
  end

  M.shouldSpawn = shouldSpawn

  function M.clearResearchers(game)
    game = game or M.game
    for _, hint in pairs(M.HINTS) do removeRuntime(game, hint) end
    return true
  end

  function M.refresh(game, mapId)
    M.game = game or M.game
    game = game or M.game
    if not (game and mod.world) then return false end
    mapId = mapId or currentMapId(game)
    local key, hint = hintForMap(mapId)
    if not hint then return false end
    if not hasHall(game) then
      removeRuntime(game, hint)
      return false, "pre-hall"
    end
    if character(game) ~= key then
      removeRuntime(game, hint)
      return false, "character"
    end
    local ow = mod.world.overworld and mod.world:overworld()
    if not (ow and ow.map and ow.map.id == hint.map) then return false end
    local ids = runtimeObjectIds(game, hint)
    local live = currentNpc(ow, hint)
    if #ids == 1 and live then return true end
    -- Reconcile duplicate definitions and map-reload ghosts to exactly one
    -- visible scientist before selecting a safe authored cell.
    removeRuntime(game, hint)
    local spawnX, spawnY
    for _, cell in ipairs(hint.cells or { { hint.x, hint.y } }) do
      local x, y = cell[1], cell[2]
      local free = ow.map:inBounds(x, y)
        and ow.map:isWalkableCell(x, y)
        and not ow.map:warpAtCell(x, y)
        and not ow:npcAtCell(x, y)
        and not (ow.player and ow.player.cellX == x
          and ow.player.cellY == y)
      if free then spawnX, spawnY = x, y break end
    end
    if not spawnX then
      if mod.log and mod.log.warn then
        mod.log:warn("HEVO researcher cells occupied: %s", hint.map)
      end
      return false, "occupied"
    end
    if not mod.world.spawnNpc then return false, "spawn unavailable" end
    return mod.world:spawnNpc(hint.map, {
      name = hint.object, sprite = hint.sprite,
      movement = "STAY", range = "DOWN", text = hint.text,
      x = spawnX, y = spawnY,
    }) ~= nil
  end

  function M.refreshAll(game, mapId)
    M.game = game or M.game
    game = game or M.game
    mapId = mapId or currentMapId(game)
    local activeKey = hintForMap(mapId)
    for key, hint in pairs(M.HINTS) do
      if key ~= activeKey or not shouldSpawn(key, game) then
        removeRuntime(game, hint)
      end
    end
    if activeKey then return M.refresh(game, mapId) end
    return false, "not a researcher city"
  end

  function M.register()
    if M.registered then return false, "already registered" end
    for key, hint in pairs(M.HINTS) do
      mod.content.text:register(hint.text, tr(hint.riddle.en, hint.riddle.de))
      mod.content.text_pointers:patch("???", {
        [hint.text] = { text = hint.text },
      })
      mod.content.map_scripts:register(hint.map, {
        priority = 2760,
        talk = {
          [hint.text] = function(game, ow, npc, done)
            return M.talk(key, game, ow, npc, done)
          end,
        },
      })
    end
    M.registered = true
    return true
  end

  function M.install(game)
    if M.installed then return false, "already installed" end
    M.installed, M.game = true, game or M.game
    mod.events:on("save.loading", function()
      -- Do not let the outgoing slot's process-wide runtime definitions reach
      -- Continue/New Game while identity and Hall state are in transition.
      M.clearResearchers(M.game)
    end, 4000)
    mod.events:on("save.loaded", function(ev)
      local active = ev and ev.game or M.game
      M.clearResearchers(active)
      M.refreshAll(active, currentMapId(active))
    end, 4000)
    mod.events:on("save.created", function(ev)
      local active = ev and ev.game or M.game
      M.clearResearchers(active)
      M.refreshAll(active, currentMapId(active))
    end, 4000)
    mod.events:on("map.entered", function(ev)
      local active = ev and ev.game or M.game
      local mapId = ev and (ev.mapId or ev.map and ev.map.id)
      M.refreshAll(active, mapId)
    end)
    -- Renderers and map-mod stacks may rebuild the live NPC pool after the
    -- first map-enter event. Reconcile once more on that public boundary.
    mod.events:on("map.reloaded", function(ev)
      local active = ev and ev.game or M.game
      local mapId = ev and (ev.mapId or ev.map and ev.map.id)
      M.refreshAll(active, mapId)
    end)
    -- If a staged Wilds actor occupies the first audited cell during map
    -- entry, retry on the next ordinary field step instead of leaving the
    -- scientist absent for the entire visit.
    mod.events:on("world.stepped", function(ev)
      local active = ev and ev.game or M.game
      local mapId = ev and (ev.mapId or ev.map and ev.map.id)
      advanceRetries(active)
      if hintForMap(mapId) then M.refreshAll(active, mapId) end
    end)
    M.clearResearchers(M.game)
    return true
  end

  return M
end
