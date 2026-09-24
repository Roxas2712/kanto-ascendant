-- KASC 6.7 optional Hoenn research sanctums card.
--
-- The rooms use the authorized revision of the user's Map-Studio base. Each room
-- has an R/S-inspired physical seal before its encounter: Regirock uses a
-- four-step route plus STRENGTH, Regice requires two minutes of complete
-- stillness, and Registeel requires FLY from the central mark. Puzzle state
-- belongs to the current playthrough authority; Dex/Legacy catches never
-- open a seal in a later NG+ run.

return function(mod, opts)
  opts = opts or {}
  local dex = assert(opts.dex, "Hoenn Dex authority missing")
  local rules = opts.generationRules
  local fieldAccess = opts.fieldAccess
  local runEvents = opts.runEvents
  local postgame = opts.postgame
  local geometry = assert(opts.geometry, "Hoenn editor geometry missing")
  local fieldTech = opts.fieldTech

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  local S = {
    SAVE_KEY = "hoenn_research_sanctums_67",
    STATE_VERSION = 2,
    CARD_ID = "KASC-66-REGI-SANCTUMS",
    OWNER = "kasc.hoenn-regi-sanctum-puzzles/v2",
    SOURCE_PROJECT_SHA256 = geometry.SOURCE_PROJECT_SHA256,
    ENTRY = { x=8, y=11, facing="up" },
    VIGIL_SECONDS = 120,
    registered = false,
  }

  S.rows = {
    { species="REGIROCK", map="KA_HOENN_DESERT_RUINS", index=1980,
      label={en="DESERT RUINS",de="WÜSTENRUINE"}, level=40,
      text="TEXT_KA_HOENN_REGIROCK", object="KA_HOENN_REGIROCK",
      sourceMap="KA_MOLTRES_VOLCANO_ASCENT",
      -- The fallback stays below the scientist in the new hidden branch.
      fallbackReturn={map="KA_MOLTRES_VOLCANO_ASCENT",x=3,y=4,facing="up"},
      puzzle={kind="route", move="STRENGTH",
        steps={"right","right","down","down"},
        start={x=8,y=9}, finish={x=10,y=11}, action={x=11,y=11}} },
    { species="REGICE", map="KA_HOENN_ISLAND_CAVE", index=1981,
      label={en="ISLAND CAVE",de="INSELHÖHLE"}, level=40,
      text="TEXT_KA_HOENN_REGICE", object="KA_HOENN_REGICE",
      sourceMap="SEAFOAM_ISLANDS_B4F",
      fallbackReturn={map="SEAFOAM_ISLANDS_B4F",x=14,y=3,facing="down"},
      puzzle={kind="vigil", start={x=8,y=9}} },
    { species="REGISTEEL", map="KA_HOENN_ANCIENT_TOMB", index=1982,
      label={en="ANCIENT TOMB",de="ALTES GRAB"}, level=40,
      text="TEXT_KA_HOENN_REGISTEEL", object="KA_HOENN_REGISTEEL",
      sourceMap="VICTORY_ROAD_2F",
      fallbackReturn={map="VICTORY_ROAD_2F",x=14,y=3,facing="down"},
      puzzle={kind="center", move="FLY", start={x=8,y=9}} },
  }

  S.byMap, S.bySpecies = {}, {}
  for _, row in ipairs(S.rows) do
    row.inscriptionText = "TEXT_" .. row.map .. "_INSCRIPTION"
    row.actionText = "TEXT_" .. row.map .. "_ACTION"
    row.returnText = "TEXT_" .. row.map .. "_RETURN"
    row.gateNames = {}
    for index=1,8 do row.gateNames[index] = row.object .. "_SEAL_" .. index end
    S.byMap[row.map], S.bySpecies[row.species] = row, row
  end

  local activeGame, mapScripts
  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function state()
    local raw = mod.save:get(S.SAVE_KEY)
    local out = type(raw) == "table" and copy(raw) or {}
    out.version = S.STATE_VERSION
    out.caught = type(out.caught) == "table" and out.caught or {}
    for species, receipt in pairs(out.caught) do
      if not S.bySpecies[species] or type(receipt) ~= "table" then
        out.caught[species] = nil
      end
    end
    mod.save:set(S.SAVE_KEY, out)
    return out
  end

  local function persist(value)
    value.version = S.STATE_VERSION;mod.save:set(S.SAVE_KEY, value);return value
  end

  local function option(game)
    local bucket = game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket.hoenn_regi_sanctums ~= nil then
      return bucket.hoenn_regi_sanctums ~= false
    end
    local value = mod.options and mod.options.get
      and mod.options:get("hoenn_regi_sanctums")
    return value ~= false
  end

  local function generationReady(game)
    return not rules or type(rules.shouldUseEpoch) ~= "function"
      or rules.shouldUseEpoch(game, 3, false) == true
  end

  function S.available(game)
    return option(game) and generationReady(game)
      and (not postgame or postgame.hasHallOfFame(game and game.save))
      and (not fieldAccess or type(fieldAccess.hasDex) ~= "function"
        or fieldAccess.hasDex(game) == true)
  end

  local function eventComplete(game, species)
    if runEvents and type(runEvents.completed) == "function" then
      return runEvents.completed(game, species)
    end
    local save = game and (game.save or game)
    local events = save and save.kaHoennEndgameRunEvents67
    return type(events) == "table" and type(events.completed) == "table"
      and type(events.completed[species]) == "table" or false
  end
  S.eventComplete = eventComplete

  function S.next(game)
    for _, row in ipairs(S.rows) do
      if not eventComplete(game, row.species) then return row end
    end
  end

  local function progressKey(row) return "REGI_PUZZLE_" .. row.species end

  local function rawProgress(value, row)
    if runEvents and type(runEvents.progress) == "function" then
      local found = runEvents.progress(value, progressKey(row), nil)
      if type(found) == "table" then return found end
    end
    local save = value and (value.save or value)
    local events = save and save.kaHoennEndgameRunEvents67
    local progress = type(events) == "table" and events.progress or nil
    local found = type(progress) == "table" and progress[progressKey(row)] or nil
    return type(found) == "table" and found or nil
  end

  local function setProgress(value, row, puzzle)
    if runEvents and type(runEvents.setProgress) == "function" then
      return runEvents.setProgress(value, progressKey(row), puzzle)
    end
    local save = value and (value.save or value)
    if not save then return false, "save" end
    save.kaHoennEndgameRunEvents67 = save.kaHoennEndgameRunEvents67
      or {version=1,completed={},progress={}}
    local events = save.kaHoennEndgameRunEvents67
    events.progress = type(events.progress) == "table" and events.progress or {}
    events.progress[progressKey(row)] = puzzle
    return true
  end

  local function puzzleState(value, row)
    row = type(row) == "table" and row or S.bySpecies[row]
    if not row then return nil end
    local p = copy(rawProgress(value, row) or {})
    p.version = 2;p.solved = p.solved == true;p.armed = p.armed == true
    p.pathReady = p.pathReady == true
    p.cursor = math.max(0, math.floor(tonumber(p.cursor) or 0))
    p.mistakes = math.max(0, math.floor(tonumber(p.mistakes) or 0))
    if p.solved then p.armed, p.pathReady = false, true end
    setProgress(value, row, p);return p
  end
  S.puzzleState = function(value,row)return copy(puzzleState(value,row))end

  function S.accessLight(value, species)
    local row = S.bySpecies[species]
    local p = row and rawProgress(value, row)
    return row ~= nil and (eventComplete(value, species) or p ~= nil and p.solved == true)
  end

  function S.puzzleSolved(value, row)
    row = type(row) == "table" and row or S.bySpecies[row]
    return row and (eventComplete(value,row.species)
      or puzzleState(value,row).solved == true) or false
  end

  local function show(game, text, done, boxOpts)
    game.stack:push(require("src.render.TextBox").new(game,text,done,boxOpts));return true
  end

  local function warp(game, mapId, point)
    if mod.world and type(mod.world.warpTo) == "function" then
      local ok = mod.world:warpTo(mapId,point.x,point.y,point.facing)
      if ok then return true end
    end
    local ow = game and game.overworld
    if not (ow and type(ow.startWarpTo) == "function") then return false end
    ow:startWarpTo(mapId,point.x,point.y,point.facing);return true
  end

  local function writeSave(game)
    return not game or type(game.writeSave) ~= "function" or game:writeSave()
  end

  local function copyPoint(point)
    return {map=point.map,x=point.x,y=point.y,facing=point.facing or "down"}
  end

  local function returnKey(row) return "RETURN_" .. row.species end

  local function returnPoint(game, row)
    if runEvents and type(runEvents.progress) == "function" then
      local value = runEvents.progress(game,returnKey(row),nil)
      if type(value)=="table"and value.map==row.sourceMap then return copyPoint(value)end
    end
    local save = game and (game.save or game)
    local events = save and save.kaHoennEndgameRunEvents67
    local progress = type(events)=="table"and events.progress or nil
    local value = type(progress)=="table"and progress[returnKey(row)]or nil
    return type(value)=="table"and value.map==row.sourceMap
      and copyPoint(value)or copyPoint(row.fallbackReturn)
  end

  local function resetAttempt(value,row)
    local p=puzzleState(value,row)
    if p and not p.solved then
      p.armed=false;p.cursor=0;p.pathReady=false
      p.vigilStartedAt=nil;p.lastX=nil;p.lastY=nil
      setProgress(value,row,p)
    end
  end

  function S.enter(game, row, origin)
    row = type(row)=="table"and row or S.bySpecies[row]
    if not(row and S.available(game)and not eventComplete(game,row.species))then
      return false,"unavailable"
    end
    resetAttempt(game,row)
    local player=origin or game and game.overworld and game.overworld.player
    local point={map=row.sourceMap,
      x=tonumber(player and(player.cellX or player.x))or row.fallbackReturn.x,
      y=tonumber(player and(player.cellY or player.y))or row.fallbackReturn.y,
      facing=player and player.facing or row.fallbackReturn.facing}
    if runEvents and type(runEvents.setProgress)=="function"then
      runEvents.setProgress(game,returnKey(row),point)
    else
      local save=game.save
      save.kaHoennEndgameRunEvents67=save.kaHoennEndgameRunEvents67
        or{version=1,completed={},progress={}}
      local events=save.kaHoennEndgameRunEvents67
      events.progress=type(events.progress)=="table"and events.progress or{}
      events.progress[returnKey(row)]=point
    end
    writeSave(game);return warp(game,row.map,S.ENTRY),row.map
  end

  function S.leave(game,row)
    row=type(row)=="table"and row or S.bySpecies[row]
      or S.byMap[game and game.save and game.save.player and game.save.player.map]
    if not row then return false,"map"end
    resetAttempt(game,row);local point=returnPoint(game,row)
    return warp(game,point.map,point)
  end

  local function clock(game)
    if type(opts.clock)=="function"then
      local ok,value=pcall(opts.clock,game)
      if ok then return math.max(0,tonumber(value)or 0)end
    end
    return math.max(0,tonumber(game and game.save and game.save.playTime)or 0)
  end

  local function cell(ow)
    local player=ow and ow.player
    return tonumber(player and(player.cellX or player.x)),
      tonumber(player and(player.cellY or player.y))
  end

  local function onStart(row,ow)
    local x,y=cell(ow);local start=row.puzzle.start
    return x==start.x and y==start.y
  end

  function S.beginPuzzle(game,row,ow)
    row=type(row)=="table"and row or S.bySpecies[row]
    if not row then return false,"row"end
    if not S.available(game)then return false,"inactive"end
    if S.puzzleSolved(game,row)then return false,"solved"end
    if not onStart(row,ow)then return false,"start"end
    local p=puzzleState(game,row);local x,y=cell(ow)
    p.armed=true;p.cursor=0;p.pathReady=false;p.lastX=x;p.lastY=y
    if row.puzzle.kind=="vigil"then p.vigilStartedAt=clock(game)end
    -- The attempt remains live-memory state. A disk write from inside the
    -- sanctum intentionally runs secureSave(), which returns the save to the
    -- host wall and resets an unfinished attempt; auto-saving here would
    -- therefore cancel the puzzle in the same frame that arms it.
    setProgress(game,row,p);return true
  end

  local STEP={up={0,-1},down={0,1},left={-1,0},right={1,0}}

  function S.onStep(game,row,ow,x,y)
    row=type(row)=="table"and row or S.bySpecies[row]
    -- The marked southern passage is an exit, not an invisible sign the
    -- player must stop one cell before. It also works after the seal/catch.
    if row and x==8 and y==13 then return S.leave(game,row.species) end
    if not row or not S.available(game)or S.puzzleSolved(game,row)then return false end
    local p=puzzleState(game,row)
    if row.puzzle.kind=="vigil"then
      if p.armed then
        p.armed=false;p.vigilStartedAt=nil;p.mistakes=p.mistakes+1
        p.lastX=nil;p.lastY=nil;setProgress(game,row,p)
        return true,"vigil-reset"
      end
      return false
    end
    if row.puzzle.kind~="route"or not p.armed then return false end
    x=tonumber(x);y=tonumber(y)
    if not(x and y and p.lastX and p.lastY)then return false end
    local wanted=row.puzzle.steps[p.cursor+1];local delta=STEP[wanted]
    if not delta or x-p.lastX~=delta[1]or y-p.lastY~=delta[2]then
      p.armed=false;p.cursor=0;p.pathReady=false;p.mistakes=p.mistakes+1
      p.lastX=nil;p.lastY=nil;setProgress(game,row,p)
      return true,"route-reset"
    end
    p.cursor=p.cursor+1;p.lastX=x;p.lastY=y
    if p.cursor==#row.puzzle.steps then p.armed=false;p.pathReady=true end
    setProgress(game,row,p)
    return true,p.pathReady and"route-complete"or"route-step"
  end

  local function knowsMove(game,moveId)
    if type(opts.fieldMoveAvailable)=="function"then
      local ok,value=pcall(opts.fieldMoveAvailable,game,moveId)
      if ok then return value==true end
    end
    if fieldTech and type(fieldTech.available)=="function"
        and fieldTech.available(game and game.save,moveId)then return true end
    for _,mon in ipairs(game and game.save and game.save.party or{})do
      for _,move in ipairs(mon.moves or{})do
        local id=type(move)=="table"and(move.id or move.move)or move
        if id==moveId then return true end
      end
    end
    return false
  end

  local function setObjectVisible(game,mapId,name,visible)
    local save=game and(game.save or game);if not save then return false end
    save.objectToggles=save.objectToggles or{}
    save.objectToggles[mapId]=save.objectToggles[mapId]or{}
    save.objectToggles[mapId][name]=visible==true;return true
  end

  local function hideLive(ow,row)
    if not(ow and type(ow.queueScript)=="function")then return end
    local script={}
    for _,name in ipairs(row.gateNames)do script[#script+1]={"hide_object",row.map,name}end
    ow:queueScript(script)
  end

  function S.syncPuzzleVisibility(game,row)
    row=type(row)=="table"and row or S.bySpecies[row]
    if not row then return false end
    local active=S.available(game);local solved=S.puzzleSolved(game,row)
    for _,name in ipairs(row.gateNames)do
      setObjectVisible(game,row.map,name,not active or not solved)
    end
    setObjectVisible(game,row.map,row.object,
      active and not eventComplete(game,row.species))
    if row.puzzle.kind=="route"then
      setObjectVisible(game,row.map,row.object.."_TECHNIQUE",active and not solved)
    end
    return solved
  end

  local function solvePuzzle(game,row,ow)
    local p=puzzleState(game,row);p.solved=true;p.armed=false
    p.pathReady=true;p.vigilStartedAt=nil
    setProgress(game,row,p);S.syncPuzzleVisibility(game,row);hideLive(ow,row)
    writeSave(game);return true
  end

  function S.update(game)
    local ow = game and game.overworld
    local row = ow and ow.map and S.byMap[ow.map.id]
    if not row or row.puzzle.kind ~= "vigil" or ow.transitioning
        or not ow.player or ow.player.moving or not game.stack
        or game.stack:top() ~= ow then return false end
    local p = puzzleState(game, row)
    local started = tonumber(p.vigilStartedAt)
    if not p.armed or p.solved or not started
        or not onStart(row, ow) or not S.available(game) then return false end
    if clock(game) - started < S.VIGIL_SECONDS then return false end
    solvePuzzle(game, row, ow)
    show(game, tr("Two silent minutes pass. The frozen wall opens.",
      "Zwei stille Minuten vergehen. Die Eiswand öffnet sich."))
    return true
  end

  function S.useTechnique(game,row,moveId,ow)
    row=type(row)=="table"and row or S.bySpecies[row]
    if not row or row.puzzle.move~=moveId then return false,"move"end
    if not S.available(game)then return false,"inactive"end
    local p=puzzleState(game,row);local x,y=cell(ow)
    if row.puzzle.kind=="route"then
      local finish=row.puzzle.finish
      if not(p.pathReady and x==finish.x and y==finish.y)then return false,"route"end
    elseif row.puzzle.kind=="center"then
      local start=row.puzzle.start
      if not(p.armed and x==start.x and y==start.y)then return false,"center"end
    else return false,"kind"end
    if not knowsMove(game,moveId)then return false,"locked"end
    return solvePuzzle(game,row,ow),"complete"
  end

  function S.inscriptionTalk(game,row,ow,done)
    row=type(row)=="table"and row or S.bySpecies[row]
    if not S.available(game)then return show(game,tr(
      "This sanctum is currently inactive.",
      "Dieses Heiligtum ist gerade nicht aktiv."),done)end
    if S.puzzleSolved(game,row)then return show(game,tr(
      "The ancient writing has gone quiet.","Die alte Schrift ist verstummt."),done)end
    local p=puzzleState(game,row)
    if row.puzzle.kind=="vigil"and p.armed then
      local elapsed=clock(game)-(tonumber(p.vigilStartedAt)or clock(game))
      if elapsed>=S.VIGIL_SECONDS then
        solvePuzzle(game,row,ow)
        return show(game,tr("Two silent minutes pass. The frozen wall opens.",
          "Zwei stille Minuten vergehen. Die Eiswand öffnet sich."),done)
      end
      local left=math.max(1,math.ceil(S.VIGIL_SECONDS-elapsed))
      return show(game,tr(
        ("The frost is still listening. Remain still for %d seconds."):format(left),
        ("Der Frost lauscht noch. Bleib noch %d Sekunden reglos."):format(left)),done)
    end
    local ok,why=S.beginPuzzle(game,row,ow)
    if not ok and why=="start"then return show(game,tr(
      "Stand on the middle mark before reading the inscription.",
      "Stell dich auf das mittlere Zeichen und lies dann die Schrift."),done)end
    local messages={
      REGIROCK=tr("The dots read: TWO RIGHT, TWO DOWN. Then call on STRENGTH.",
        "Die Punkte bedeuten: Zwei Schritte nach rechts, dann zwei nach unten. Setz dort STÄRKE ein."),
      REGICE=tr("The dots read: Remain completely still for two minutes.",
        "Die Punkte bedeuten: Warte hier zwei Minuten, ohne dich zu bewegen."),
      REGISTEEL=tr("The dots read: From the middle, open the sky with FLY.",
        "Die Punkte bedeuten: Stell dich in die Mitte und setz FLIEGEN ein."),
    }
    return show(game,messages[row.species],done)
  end

  function S.techniqueTalk(game,row,ow,done)
    row=type(row)=="table"and row or S.bySpecies[row]
    if not S.available(game)then return show(game,tr(
      "This sanctum is currently inactive.",
      "Dieses Heiligtum ist gerade nicht aktiv."),done)end
    local move=row and row.puzzle.move
    if not move then if done then done()end;return false end
    local p=puzzleState(game,row)
    local ready=row.puzzle.kind=="route"and p.pathReady
      or row.puzzle.kind=="center"and p.armed and onStart(row,ow)
    if not ready then return show(game,tr(
      "The stone does not react. Follow the inscription first.",
      "Der Stein reagiert nicht. Befolge zuerst die Inschrift."),done)end
    local names={STRENGTH={"STRENGTH","STÄRKE"},FLY={"FLY","FLIEGEN"}}
    local label=names[move]or{move,move}
    return show(game,tr(("Use %s here?"):format(label[1]),
      ("Hier %s einsetzen?"):format(label[2])),nil,{defaultNo=true,
        choice=function(yes)
          if not yes then if done then done()end;return end
          local ok,why=S.useTechnique(game,row,move,ow)
          local message=ok and tr("The ancient seal breaks open!",
            "Das uralte Siegel bricht auf!")or why=="locked"and tr(
              ("No party Pokemon or FIELD KIT can use %s."):format(label[1]),
              ("Weder dein Team noch das FELD-KIT kann %s einsetzen."):format(label[2]))
            or tr("The marked position is wrong.","Du stehst nicht richtig.")
          return show(game,message,done)
        end})
  end

  local function stored(save, mon)
    for _,candidate in ipairs(save and save.party or{})do if candidate==mon then return true end end
    for _,box in ipairs(save and save.boxes or{})do
      for _,candidate in ipairs(box)do if candidate==mon then return true end end
    end
    return false
  end

  function S.recordCatch(game,row,mon)
    if not(row and game and game.save and stored(game.save,mon))then return false,"not-stored"end
    local receipt={map=row.map,level=tonumber(mon.level)or row.level,
      battleResult="caught",captured=true}
    local marked,markWhy
    if runEvents and type(runEvents.mark)=="function"then
      marked,markWhy=runEvents.mark(game,row.species,receipt)
    else
      game.save.kaHoennEndgameRunEvents67=
        game.save.kaHoennEndgameRunEvents67 or{version=1,completed={}}
      local completed=game.save.kaHoennEndgameRunEvents67.completed
      if completed[row.species]then marked,markWhy=false,"recorded"
      else completed[row.species],marked=receipt,true end
    end
    if not marked and markWhy~="recorded"then return false,markWhy end
    local value=state()
    if not value.caught[row.species]then
      value.caught[row.species]=copy(receipt);persist(value);dex.record(game,row.species)
    end
    S.syncPuzzleVisibility(game,row);writeSave(game);return marked,receipt
  end

  function S.recordCompletion(game,row,result,mon)
    if result=="caught"then return S.recordCatch(game,row,mon)end
    if result~="win"then return false,"unfinished"end
    local receipt={map=row.map,level=row.level,battleResult="win",captured=false}
    local marked,why
    if runEvents and type(runEvents.mark)=="function"then
      marked,why=runEvents.mark(game,row.species,receipt)
    else
      game.save.kaHoennEndgameRunEvents67=
        game.save.kaHoennEndgameRunEvents67 or{version=1,completed={}}
      local completed=game.save.kaHoennEndgameRunEvents67.completed
      if completed[row.species]then marked,why=false,"recorded"
      else completed[row.species]=receipt;marked=true end
    end
    if not marked and why~="recorded"then return false,why end
    S.syncPuzzleVisibility(game,row);writeSave(game);return marked,receipt
  end

  function S.challenge(game,ow,npc,done,row)
    if not S.available(game)then return show(game,tr(
      "This sanctum is currently inactive.",
      "Dieses Heiligtum ist gerade nicht aktiv."),done)end
    if eventComplete(game,row.species)then return show(game,tr(
      "Only a silent seal remains.","Nur ein stilles Siegel ist geblieben."),done)end
    if not S.puzzleSolved(game,row)then return show(game,tr(
      "The ancient wall still bars the way. Read the dotted inscription below.",
      "Die uralte Wand versperrt den Weg. Lies unten die Punktinschrift."),done)end
    local function start()
      local BattleState=opts.battleState or require("src.battle.BattleState")
      local battle=BattleState.newWild(game,row.species,row.level,{
        encounterSource="hoenn_regi_sanctum",randomizerProtected=true})
      battle.kaHoennSanctum=row.species
      battle.onFinish=function(result)
        S.recordCompletion(game,row,result,battle.enemy and battle.enemy.mon)
        if ow and type(ow.afterBattle)=="function"then ow:afterBattle(result,battle)end
        if done then done()end
      end
      if ow and type(ow.pushBattle)=="function"then ow:pushBattle(battle)
      elseif done then done()end
    end
    return show(game,tr(row.species.." answers the ancient seal!",
      row.species.." antwortet dem uralten Siegel!"),start)
  end

  local function mapObjects(row)
    local objects={
      {index=1,name=row.object,sprite="SPRITE_MONSTER",x=8,y=4,
        movement="STAY",range="DOWN",text=row.text,passable=false},
      {index=3,name=row.object.."_INSCRIPTION",sprite="SPRITE_BOULDER",x=8,y=8,
        movement="STAY",range="NONE",text=row.inscriptionText,passable=false},
    }
    if row.puzzle.kind=="route"then
      objects[#objects+1]={index=#objects+1,name=row.object.."_TECHNIQUE",
        sprite="SPRITE_BOULDER",x=row.puzzle.action.x,y=row.puzzle.action.y,
        movement="STAY",range="NONE",text=row.actionText,passable=false}
    end
    for index,name in ipairs(row.gateNames)do
      objects[#objects+1]={index=#objects+1,name=name,sprite="SPRITE_BOULDER",
        x=3+index,y=7,movement="STAY",range="NONE",
        text=row.inscriptionText,passable=false}
    end
    -- Inscriptions, technique stones and seals are fixed puzzle objects.
    -- Do not let STRENGTH push them or replace their authored dialogue.
    for i,object in ipairs(objects)do object.index=i;object.pushable=false end
    return objects
  end

  function S.register()
    if S.registered then return false,"already-registered"end
    local tilesets=mod.content.tilesets
    if tilesets and type(tilesets.get)=="function"and not tilesets:get("CAVERN")then
      S.registered,S.skipped=true,"missing-cavern";return true,S.skipped
    end
    local indexes={}
    for id,def in mod.content.maps:each()do if def and def.index then indexes[def.index]=id end end
    for _,row in ipairs(S.rows)do
      local source=assert(geometry.map(row.map),"missing editor map "..row.map)
      assert(source.index==row.index,"editor map index changed "..row.map)
      assert(not mod.content.maps:get(row.map),"duplicate sanctum map "..row.map)
      assert(not indexes[row.index],"duplicate sanctum index "..row.index)
      indexes[row.index]=row.map
      mod.content.maps:register(row.map,{
        id=row.map,index=row.index,label=tr(row.label.en,row.label.de),
        tileset="CAVERN",width=source.width,height=source.height,borderBlock=125,
        blocks=source.blocks,warps={},
        signs={{name=row.object.."_RETURN",x=8,y=13,text=row.returnText}},
        connections={},outdoor=false,
        voxelMode="FULL",voxelRevision=source.voxelRevision,
        voxelAuthority="2D_BLOCKS",
        kaExplorationRevisionSha256=geometry.EXPLORATION_REVISION_SHA256,
        kaCard=S.CARD_ID,kaOwner=S.OWNER,
        kaSourceProjectSha256=S.SOURCE_PROJECT_SHA256,objects=mapObjects(row),
      })
      mod.content.encounters:register(row.map,{grass={rate=0,slots={}}})
      if mod.content.map_songs then mod.content.map_songs:register(row.map,"Music_Dungeon1")end
      mod.content.text:register(row.text,row.species.." is waiting.")
      mod.content.text:register(row.returnText,"Return through the hidden wall?")
      mod.content.text:register(row.inscriptionText,"A dotted inscription.")
      mod.content.text:register(row.actionText,"A field-technique mark.")
      mod.content.text_pointers:patch("???",{
        [row.text]={text=row.text},[row.returnText]={text=row.returnText},
        [row.inscriptionText]={text=row.inscriptionText},
        [row.actionText]={text=row.actionText},
      })
      mod.content.map_scripts:register(row.map,{priority=3380,
        onEnter=function(game)S.syncPuzzleVisibility(game,row)end,
        onStep=function(game,ow,x,y)return S.onStep(game,row,ow,x,y)end,
        talk={
          [row.text]=function(game,ow,npc,done)return S.challenge(game,ow,npc,done,row)end,
          [row.inscriptionText]=function(game,ow,_,done)
            if row.puzzle.kind=="center"and puzzleState(game,row).armed then
              return S.techniqueTalk(game,row,ow,done)
            end
            return S.inscriptionTalk(game,row,ow,done)
          end,
          [row.actionText]=function(game,ow,_,done)return S.techniqueTalk(game,row,ow,done)end,
          [row.returnText]=function(game,_,_,done)
            return show(game,tr("Return through the hidden wall?",
              "Durch die verborgene Wand zurückkehren?"),nil,{defaultNo=true,
                choice=function(yes)if yes then S.leave(game,row)elseif done then done()end end})
          end,
        },
      })
    end
    S.registered=true;return true
  end

  function S.secureSave(save)
    local player=save and save.player
    if not(type(player)=="table"and S.byMap[player.map])then return false end
    local row=S.byMap[player.map];resetAttempt(save,row);local point=returnPoint(save,row)
    player.map,player.x,player.y,player.facing=point.map,point.x,point.y,point.facing
    player.surfing=false;return true
  end

  function S.install(game,deps)
    activeGame=game or activeGame;deps=deps or{}
    opts.battleState=deps.battleState or opts.battleState
    mapScripts=deps.mapScripts or mapScripts or require("data.scripts.init")
    state()
    if activeGame then for _,row in ipairs(S.rows)do S.syncPuzzleVisibility(activeGame,row)end end
    return true
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("core.update", function(nextUpdate, game, dt)
      local result = nextUpdate(game, dt)
      S.update(game)
      return result
    end, 3380)
  end

  if mod.events and type(mod.events.on)=="function"then
    mod.events:on("save.writing",function(ev)
      S.secureSave(ev and ev.save or activeGame and activeGame.save)
    end,4200)
    for _,event in ipairs({"save.loaded","game.ready"})do
      mod.events:on(event,function(ev)
        local game=ev and ev.game or activeGame
        if game then S.install(game,{mapScripts=mapScripts})end
      end,4200)
    end
  end

  return S
end
