-- KASC 6.7 optional Moltres volcano relocation card.
--
-- The three authored maps come verbatim from the user's Map Studio project.
-- Runtime-owned objects turn those rooms into a multi-floor expedition based
-- on the lavados_vulkan reference mod: heat protection, two ruby drill loads,
-- four rock blockages, a Magmar guard and a bounded lava-current sequence.
-- Puzzle state is current-playthrough state. Persistent Dex/catch receipts do
-- not unlock this route in a later NG+ run.

return function(mod, opts)
  opts = opts or {}
  local postgame = assert(opts.postgame, "postgame authority missing")
  local runEvents = opts.runEvents
  local geometry = assert(opts.geometry, "Hoenn editor geometry missing")
  local volcanoTileset = opts.volcanoTileset or "CAVERN"

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  local V = {
    SAVE_KEY = "hoenn_moltres_volcano_67", STATE_VERSION = 4,
    PUZZLE_VERSION = 4, CARD_ID = "KASC-66-MOLTRES-VOLCANO",
    OWNER = "kasc.hoenn-moltres-volcano/v4",
    SOURCE_PROJECT_SHA256 = geometry.SOURCE_PROJECT_SHA256,
    REFERENCE_SHA256 = {
      dataQuest = "3f7d0ec5b63f8d82cf6cd8ecdb4ec9c8d188826fddf07624344875e5e645efa5",
      dataMaps = "3aabdf2a7d19d827f537d318a3f1b35a1608c8ab0810a09d7ab23f6d083ff6bd",
      volcano = "912492eedc510554127c15355d29b02d985d667233922d985f1a14c11511b986",
    },
    ENTRY_MAP = "KA_MOLTRES_VOLCANO_BASE", ENTRY_INDEX = 1989,
    ASCENT_MAP = "KA_MOLTRES_VOLCANO_ASCENT", ASCENT_INDEX = 1990,
    MAP = "KA_MOLTRES_VOLCANO", INDEX = 1983, LEVEL = 80,
    CINNABAR = "CINNABAR_ISLAND",
    CINNABAR_TEXT = "TEXT_CINNABARISLAND_GAMBLER",
    MANSION = "POKEMON_MANSION_B1F",
    MANSION_TEXT = "TEXT_POKEMONMANSIONB1F_SCIENTIST",
    MOLTRES_TEXT = "TEXT_KA_MOLTRES_VOLCANO",
    RETURN_TEXT = "TEXT_KA_MOLTRES_VOLCANO_RETURN",
    PROSPECTOR_TEXT = "TEXT_KA_MOLTRES_HEAT_RESEARCHER",
    BASE_DRILL_TEXT = "TEXT_KA_MOLTRES_BASE_DRILL",
    LOWER_DRILL_TEXT = "TEXT_KA_MOLTRES_ASCENT_LOWER_DRILL",
    GUARDIAN_TEXT = "TEXT_KA_MOLTRES_MAGMAR_GUARD",
    UPPER_DRILL_TEXT = "TEXT_KA_MOLTRES_ASCENT_UPPER_DRILL",
    SUMMIT_DRILL_TEXT = "TEXT_KA_MOLTRES_SUMMIT_DRILL",
    BASE_RUBY_TEXTS = {}, ASCENT_RUBY_TEXTS = {}, CURRENT_TEXTS = {},
    PASSAGE_TEXTS = {
      "TEXT_KA_MOLTRES_BASE_UP", "TEXT_KA_MOLTRES_ASCENT_DOWN",
      "TEXT_KA_MOLTRES_ASCENT_UP", "TEXT_KA_MOLTRES_SUMMIT_DOWN",
    },
    PASSAGE_NAMES = {
      "KA_MOLTRES_BASE_UP", "KA_MOLTRES_ASCENT_DOWN",
      "KA_MOLTRES_ASCENT_UP", "KA_MOLTRES_SUMMIT_DOWN",
    },
    NATIVE_MAP = "VICTORY_ROAD_2F",
    NATIVE_OBJECT = "VICTORYROAD2F_MOLTRES",
    RETURN = {map="CINNABAR_ISLAND",x=14,y=7,facing="down"},
    ENTRY = {x=10,y=18,facing="up"}, registered = false,
  }
  V.LEVELS = {V.ENTRY_MAP, V.ASCENT_MAP, V.MAP}
  -- Native cave encounters, independently catchable. These ordinary battles
  -- never call the Magmar-guardian or legendary completion callbacks.
  V.FIRE_POOLS = {
    [V.ENTRY_MAP] = {rate=18,slots={
      {species="MAGMAR",level=48},{species="MAGMAR",level=50},
      {species="RAPIDASH",level=50},{species="NINETALES",level=50},
      {species="ARCANINE",level=52},{species="FLAREON",level=52},
      {species="MAGMAR",level=54},{species="RAPIDASH",level=54},
      {species="NINETALES",level=55},{species="ARCANINE",level=56},
    }},
    [V.ASCENT_MAP] = {rate=14,slots={
      {species="MAGMAR",level=54},{species="RAPIDASH",level=56},
      {species="NINETALES",level=56},{species="FLAREON",level=56},
      {species="ARCANINE",level=58},{species="MAGMAR",level=58},
      {species="ARCANINE",level=60},{species="RAPIDASH",level=60},
      {species="NINETALES",level=60},{species="FLAREON",level=62},
    }},
    -- The final narrow perch is a quiet legendary encounter, not a random
    -- battle every few steps while interacting with its last seal.
    [V.MAP] = {rate=0,slots={}},
  }
  V.BASE_RUBY_NAMES, V.ASCENT_RUBY_NAMES, V.CURRENT_NAMES = {}, {}, {}
  for index=1,3 do
    V.BASE_RUBY_NAMES[index] = "KA_MOLTRES_BASE_RUBY_" .. index
    V.ASCENT_RUBY_NAMES[index] = "KA_MOLTRES_ASCENT_RUBY_" .. index
    V.CURRENT_NAMES[index] = "KA_MOLTRES_CURRENT_" .. index
    V.BASE_RUBY_TEXTS[index] = "TEXT_" .. V.BASE_RUBY_NAMES[index]
    V.ASCENT_RUBY_TEXTS[index] = "TEXT_" .. V.ASCENT_RUBY_NAMES[index]
    V.CURRENT_TEXTS[index] = "TEXT_" .. V.CURRENT_NAMES[index]
  end
  local function numbered(prefix, count)
    local out = {}; for index=1,count do out[index] = prefix .. index end
    return out
  end
  V.BASE_BLOCK_NAMES = numbered("KA_MOLTRES_BASE_BLOCK_", 12)
  V.LOWER_BLOCK_NAMES = numbered("KA_MOLTRES_ASCENT_LOWER_BLOCK_", 12)
  V.UPPER_BLOCK_NAMES = numbered("KA_MOLTRES_ASCENT_UPPER_BLOCK_", 12)
  V.SUMMIT_BLOCK_NAMES = numbered("KA_MOLTRES_SUMMIT_BLOCK_", 6)
  -- Compatibility aliases for existing consumers; the gate is now drill 4.
  V.GATE_NAMES, V.GATE_NAME, V.GATE_TEXT = V.SUMMIT_BLOCK_NAMES,
    V.SUMMIT_BLOCK_NAMES[1], V.SUMMIT_DRILL_TEXT

  local activeGame, mapScripts, originalCinnabar, originalMansion
  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function state()
    local raw = mod.save:get(V.SAVE_KEY)
    local out = type(raw) == "table" and copy(raw) or {}
    out.version = V.STATE_VERSION
    out.caught = type(out.caught) == "table" and out.caught or nil
    mod.save:set(V.SAVE_KEY, out); return out
  end
  local function persist(value)
    value.version = V.STATE_VERSION; mod.save:set(V.SAVE_KEY, value); return value
  end
  local function option(game)
    local bucket = game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket.hoenn_moltres_volcano ~= nil then
      return bucket.hoenn_moltres_volcano ~= false
    end
    local value = mod.options and mod.options.get
      and mod.options:get("hoenn_moltres_volcano")
    return value ~= false
  end
  local function eventComplete(value)
    if runEvents and type(runEvents.completed) == "function" then
      return runEvents.completed(value, "MOLTRES")
    end
    local save = value and (value.save or value)
    local events = save and save.kaHoennEndgameRunEvents67
    return type(events) == "table" and type(events.completed) == "table"
      and type(events.completed.MOLTRES) == "table" or false
  end
  V.eventComplete = eventComplete

  local function runProgress(value)
    if runEvents and type(runEvents.progress) == "function" then
      local found = runEvents.progress(value, "MOLTRES", nil)
      if type(found) == "table" then return found end
    end
    local save = value and (value.save or value)
    if not save then return {} end
    save.kaHoennEndgameRunEvents67 = save.kaHoennEndgameRunEvents67
      or {version=1,completed={},progress={}}
    local events = save.kaHoennEndgameRunEvents67
    events.progress = type(events.progress) == "table" and events.progress or {}
    events.progress.MOLTRES = type(events.progress.MOLTRES) == "table"
      and events.progress.MOLTRES or {}
    return events.progress.MOLTRES
  end
  local function setRunProgress(value, progress)
    if runEvents and type(runEvents.setProgress) == "function" then
      return runEvents.setProgress(value, "MOLTRES", progress)
    end
    local save = value and (value.save or value)
    if not save then return false, "save" end
    runProgress(save)
    save.kaHoennEndgameRunEvents67.progress.MOLTRES = copy(progress)
    return true
  end
  local function boolArray(value)
    local out = {}; value = type(value) == "table" and value or {}
    for index=1,3 do out[index] = value[index] == true end
    return out
  end
  local function allThree(value)
    return value[1] == true and value[2] == true and value[3] == true
  end
  local function countTrue(value)
    local total=0;for index=1,3 do if value[index]then total=total+1 end end
    return total
  end
  local function normalisePuzzle(value)
    local old = runProgress(value)
    local rumor, trail = old.rumor == true, old.trail == true
    -- V3's short seal teaser never counts as this physical V4 route.
    if tonumber(old.puzzleVersion) ~= V.PUZZLE_VERSION then old = {} end
    local p = {
      puzzleVersion=V.PUZZLE_VERSION,rumor=rumor,trail=trail,
      heatProtection=old.heatProtection==true,
      baseRubies=boolArray(old.baseRubies),ascentRubies=boolArray(old.ascentRubies),
      baseDrilled=old.baseDrilled==true,lowerPlugCleared=old.lowerPlugCleared==true,
      guardianDefeated=old.guardianDefeated==true,
      currentStep=math.max(0,math.min(3,math.floor(tonumber(old.currentStep)or 0))),
      currentSolved=old.currentSolved==true,upperPlugCleared=old.upperPlugCleared==true,
      summitUnlocked=old.summitUnlocked==true,
      blastCount=math.max(0,math.min(4,math.floor(tonumber(old.blastCount)or 0))),
      mistakes=math.max(0,math.floor(tonumber(old.mistakes)or 0)),
    }
    -- Reject copied/corrupt late flags; every stage needs its current-run chain.
    p.baseDrilled=p.baseDrilled and p.heatProtection and allThree(p.baseRubies)
    p.lowerPlugCleared=p.lowerPlugCleared and p.baseDrilled and allThree(p.ascentRubies)
    p.guardianDefeated=p.guardianDefeated and p.lowerPlugCleared
    p.currentSolved=p.currentSolved and p.guardianDefeated
    if p.currentSolved then p.currentStep=3 end
    p.upperPlugCleared=p.upperPlugCleared and p.currentSolved
    p.summitUnlocked=p.summitUnlocked and p.upperPlugCleared
    if p.summitUnlocked then p.blastCount=4
    elseif p.upperPlugCleared then p.blastCount=math.min(3,p.blastCount)
    elseif p.lowerPlugCleared then p.blastCount=math.min(2,p.blastCount)
    elseif p.baseDrilled then p.blastCount=math.min(1,p.blastCount)
    else p.blastCount=0 end
    setRunProgress(value,p);return p
  end
  function V.puzzleState(value)return copy(normalisePuzzle(value))end
  function V.puzzleSolved(value)
    return eventComplete(value)or normalisePuzzle(value).summitUnlocked==true
  end
  function V.available(game)
    return option(game)and postgame.hasHallOfFame(game and game.save)
      and postgame.legendSetting("MOLTRES")=="apex"
  end
  function V.stage(game)
    if eventComplete(game)then return"completed"end
    local p=normalisePuzzle(game)
    if p.trail then return"volcano"elseif p.rumor then return"mansion"end
    return"rumor"
  end

  local function show(game,text,done,boxOpts)
    game.stack:push(require("src.render.TextBox").new(game,text,done,boxOpts));return true
  end
  local function writeSave(game)
    return not game or type(game.writeSave)~="function"or game:writeSave()
  end
  local function warp(game,mapId,point)
    if mod.world and type(mod.world.warpTo)=="function"then
      local ok=mod.world:warpTo(mapId,point.x,point.y,point.facing)
      if ok then return true end
    end
    local ow=game and game.overworld
    if not(ow and type(ow.startWarpTo)=="function")then return false end
    ow:startWarpTo(mapId,point.x,point.y,point.facing);return true
  end
  function V.enter(game)
    local regirockDone=type(opts.regirockComplete)=="function"
      and opts.regirockComplete(game)or false
    if not(V.available(game)and(not eventComplete(game)or not regirockDone))then
      return false,"unavailable"
    end
    writeSave(game);return warp(game,V.ENTRY_MAP,V.ENTRY)
  end
  function V.openExpedition(game)
    if not V.available(game)then return false,"unavailable"end
    local p=normalisePuzzle(game);p.rumor=true;p.trail=true
    setRunProgress(game,p);writeSave(game);return V.enter(game)
  end
  function V.leave(game)return warp(game,V.RETURN.map,V.RETURN)end
  local function fallback(handler,game,ow,npc,done)
    if type(handler)=="function"then return handler(game,ow,npc,done)end
    if done then done()end;return false
  end
  function V.cinnabarTalk(game,ow,npc,done)
    if not V.available(game)then return fallback(originalCinnabar,game,ow,npc,done)end
    local stage=V.stage(game)
    if stage=="completed"then return show(game,tr("The ash above Cinnabar is calm again.",
      "Die Asche über Zinnober ist wieder still."),done)
    elseif stage=="rumor"then
      local p=normalisePuzzle(game);p.rumor=true;setRunProgress(game,p);writeSave(game)
      return show(game,tr(
        "A strange ember fell near the old MANSION. A scientist went below to examine it.",
        "Beim alten HAUS ist seltsame Glut niedergegangen. Ein Forscher untersucht sie im Keller."),done)
    elseif stage=="mansion"then return show(game,tr(
      "The scientist in the MANSION basement still has the ember.",
      "Der Forscher im Keller des alten HAUSES hat die Glut noch."),done)end
    return show(game,tr("The ember points into Cinnabar's crater. Join the expedition now?",
      "Die Glut weist in Zinnobers Krater. Jetzt an der Expedition teilnehmen?"),nil,
      {defaultNo=true,choice=function(yes)
        if yes then V.enter(game)elseif done then done()end
      end})
  end
  function V.mansionTalk(game,ow,npc,done)
    if not V.available(game)or V.stage(game)~="mansion"then
      return fallback(originalMansion,game,ow,npc,done)
    end
    local p=normalisePuzzle(game);p.trail=true;setRunProgress(game,p)
    writeSave(game);V.syncVisibility(game)
    return show(game,tr(
      "SCIENTIST: This ash is fresh. MOLTRES left Victory Road for Cinnabar's crater. Meet my colleague on the lower expedition route.",
      "FORSCHER: Die Asche ist frisch. LAVADOS zog von der Siegesstraße in Zinnobers Krater. Mein Kollege wartet unten an der Expeditionsroute."),done)
  end

  local function stored(save,mon)
    for _,candidate in ipairs(save and save.party or{})do if candidate==mon then return true end end
    for _,box in ipairs(save and save.boxes or{})do
      for _,candidate in ipairs(box)do if candidate==mon then return true end end
    end
    return false
  end
  function V.recordCatch(game,mon)
    if not(game and game.save and stored(game.save,mon))then return false,"not-stored"end
    local receipt={map=V.MAP,level=tonumber(mon.level)or V.LEVEL,
      battleResult="caught",captured=true}
    local marked,why
    if runEvents and type(runEvents.mark)=="function"then
      marked,why=runEvents.mark(game,"MOLTRES",receipt)
    else
      game.save.kaHoennEndgameRunEvents67=game.save.kaHoennEndgameRunEvents67
        or{version=1,completed={},progress={}}
      local completed=game.save.kaHoennEndgameRunEvents67.completed
      if completed.MOLTRES then marked,why=false,"recorded"
      else completed.MOLTRES=receipt;marked=true end
    end
    if not marked and why~="recorded"then return false,why end
    local s=state();if not s.caught then s.caught=copy(receipt);persist(s)end
    writeSave(game);V.syncVisibility(game);return marked,receipt
  end
  function V.recordCompletion(game,result,mon)
    if result=="caught"then return V.recordCatch(game,mon)end
    if result~="win"then return false,"unfinished"end
    local receipt={map=V.MAP,level=V.LEVEL,battleResult="win",captured=false}
    local marked,why
    if runEvents and type(runEvents.mark)=="function"then
      marked,why=runEvents.mark(game,"MOLTRES",receipt)
    else
      game.save.kaHoennEndgameRunEvents67=game.save.kaHoennEndgameRunEvents67
        or{version=1,completed={},progress={}}
      local completed=game.save.kaHoennEndgameRunEvents67.completed
      if completed.MOLTRES then marked,why=false,"recorded"
      else completed.MOLTRES=receipt;marked=true end
    end
    if not marked and why~="recorded"then return false,why end
    writeSave(game);V.syncVisibility(game);return marked,receipt
  end

  local function setObjectVisible(value,mapId,name,visible)
    local save=value and(value.save or value);if not save then return false end
    save.objectToggles=save.objectToggles or{}
    save.objectToggles[mapId]=save.objectToggles[mapId]or{}
    save.objectToggles[mapId][name]=visible==true;return true
  end
  local function setGroup(value,mapId,names,visible)
    for _,name in ipairs(names)do setObjectVisible(value,mapId,name,visible)end
  end
  local function hideLive(ow,mapId,names)
    if not(ow and type(ow.queueScript)=="function")then return end
    local rows={};for _,name in ipairs(names)do rows[#rows+1]={"hide_object",mapId,name}end
    if #rows>0 then ow:queueScript(rows)end
  end
  function V.syncPuzzleVisibility(game)
    local p=normalisePuzzle(game)
    local active=V.available(game)
    local completed=eventComplete(game)
    local puzzleActive=active and not completed
    for index,name in ipairs(V.BASE_RUBY_NAMES)do
      setObjectVisible(game,V.ENTRY_MAP,name,puzzleActive and not p.baseRubies[index]
        and not p.baseDrilled)
    end
    for index,name in ipairs(V.ASCENT_RUBY_NAMES)do
      setObjectVisible(game,V.ASCENT_MAP,name,puzzleActive and not p.ascentRubies[index]
        and not p.lowerPlugCleared)
    end
    setObjectVisible(game,V.ENTRY_MAP,"KA_MOLTRES_HEAT_RESEARCHER",active)
    setGroup(game,V.ENTRY_MAP,V.BASE_BLOCK_NAMES,
      not active or puzzleActive and not p.baseDrilled)
    setGroup(game,V.ASCENT_MAP,V.LOWER_BLOCK_NAMES,
      not active or puzzleActive and not p.lowerPlugCleared)
    setObjectVisible(game,V.ASCENT_MAP,"KA_MOLTRES_MAGMAR_GUARD",
      puzzleActive and not p.guardianDefeated)
    setGroup(game,V.ASCENT_MAP,V.CURRENT_NAMES,puzzleActive and not p.currentSolved)
    setGroup(game,V.ASCENT_MAP,V.UPPER_BLOCK_NAMES,
      not active or puzzleActive and not p.upperPlugCleared)
    setGroup(game,V.MAP,V.SUMMIT_BLOCK_NAMES,
      not active or puzzleActive and not p.summitUnlocked)
    setObjectVisible(game,V.MAP,"KA_MOLTRES_VOLCANO",
      puzzleActive)
    return p.summitUnlocked
  end

  function V.scientistTalk(game,done)
    if not V.available(game)then return show(game,tr(
      "This expedition is currently inactive.",
      "Diese Expedition ist gerade nicht aktiv."),done)end
    local p=normalisePuzzle(game)
    if not p.heatProtection then
      p.heatProtection=true;setRunProgress(game,p);writeSave(game)
      return show(game,tr(
        "SCIENTIST: The upper vents will burn you. Take this heat shield and collect three red drill stones.",
        "FORSCHER: Oben verbrennst du dir die Schuhe. Nimm diesen Hitzeschutz und such drei rote Bohrsteine."),done)
    end
    local message
    if not p.baseDrilled then message=tr(
      "Three red stones power the drill at the first blockage.",
      "Drei rote Steine treiben den Bohrer an der ersten Blockade an.")
    elseif not p.lowerPlugCleared then message=tr(
      "The ascent has a second set of stones. Do not leave one behind.",
      "Am Aufstieg liegt ein zweiter Satz Steine. Lass keinen zurück.")
    else message=tr("Beyond the guard, read the vent arrows before touching them.",
      "Hinter dem Wächter zeigen Pfeile die Reihenfolge der Schlote.")end
    return show(game,"FORSCHER: "..message,done)
  end
  function V.collectRuby(game,floor,index,ow)
    if not V.available(game)then return false,"inactive"end
    index=math.floor(tonumber(index)or 0)
    local p=normalisePuzzle(game);local rubies,names,mapId
    if floor=="base"then rubies,names,mapId=p.baseRubies,V.BASE_RUBY_NAMES,V.ENTRY_MAP
    elseif floor=="ascent"then rubies,names,mapId=p.ascentRubies,V.ASCENT_RUBY_NAMES,V.ASCENT_MAP
    else return false,"floor"end
    if index<1 or index>3 then return false,"ruby"end
    if not p.heatProtection then return false,"heat"end
    if rubies[index]then return false,"collected"end
    rubies[index]=true;setRunProgress(game,p);setObjectVisible(game,mapId,names[index],false)
    hideLive(ow,mapId,{names[index]});writeSave(game);return true,countTrue(rubies)
  end
  function V.rubyTalk(game,floor,index,ow,done)
    local ok,why=V.collectRuby(game,floor,index,ow)
    if ok then return show(game,tr(("Red drill stone secured (%d/3)."):format(why),
      ("Roter Bohrstein gesichert (%d/3)."):format(why)),done)end
    if why=="heat"then return show(game,tr(
      "The stone is too hot. Find the expedition scientist first.",
      "Der Stein ist zu heiß. Such zuerst den Forscher der Expedition."),done)end
    if why=="inactive"then return show(game,tr(
      "This expedition is currently inactive.",
      "Diese Expedition ist gerade nicht aktiv."),done)end
    return show(game,tr("The empty socket is still warm.",
      "Die leere Fassung ist noch warm."),done)
  end

  local BLOCK_STAGE={
    base={field="baseDrilled",prerequisite=function(p)
      return p.heatProtection and allThree(p.baseRubies)end,blast=1},
    lower={field="lowerPlugCleared",prerequisite=function(p)
      return p.baseDrilled and allThree(p.ascentRubies)end,blast=2},
    upper={field="upperPlugCleared",prerequisite=function(p)
      return p.lowerPlugCleared and p.guardianDefeated and p.currentSolved end,blast=3},
    summit={field="summitUnlocked",prerequisite=function(p)
      return p.upperPlugCleared end,blast=4},
  }
  BLOCK_STAGE.base.map,BLOCK_STAGE.base.names=V.ENTRY_MAP,V.BASE_BLOCK_NAMES
  BLOCK_STAGE.lower.map,BLOCK_STAGE.lower.names=V.ASCENT_MAP,V.LOWER_BLOCK_NAMES
  BLOCK_STAGE.upper.map,BLOCK_STAGE.upper.names=V.ASCENT_MAP,V.UPPER_BLOCK_NAMES
  BLOCK_STAGE.summit.map,BLOCK_STAGE.summit.names=V.MAP,V.SUMMIT_BLOCK_NAMES
  function V.clearBlockage(game,stage,ow)
    if not V.available(game)then return false,"inactive"end
    local row=BLOCK_STAGE[stage];if not row then return false,"stage"end
    local p=normalisePuzzle(game)
    if p[row.field]then return false,"cleared"end
    if not row.prerequisite(p)then return false,"locked"end
    p[row.field]=true;p.blastCount=math.max(p.blastCount,row.blast)
    setRunProgress(game,p);setGroup(game,row.map,row.names,false)
    hideLive(ow,row.map,row.names);writeSave(game);return true,"complete"
  end
  local function blockageHint(stage,p)
    if stage=="base"then
      if not p.heatProtection then return tr("The drill controls are too hot to touch.",
        "Die Steuerung des Bohrers ist zu heiß.")end
      return tr(("The drill needs three red stones (%d/3)."):format(countTrue(p.baseRubies)),
        ("Der Bohrer braucht drei rote Steine (%d/3)."):format(countTrue(p.baseRubies)))
    elseif stage=="lower"then return tr(
      ("The second drill load is incomplete (%d/3)."):format(countTrue(p.ascentRubies)),
      ("Die zweite Bohrladung ist unvollständig (%d/3)."):format(countTrue(p.ascentRubies)))
    elseif stage=="upper"then
      if not p.guardianDefeated then return tr("MAGMAR is guarding the controls.",
        "MAGMAR bewacht die Steuerung.")end
      return tr("The three lava vents are not aligned.",
        "Die drei Lavaschlote sind noch nicht ausgerichtet.")
    end
    return tr("The lower route is not secure yet.","Der untere Weg ist noch nicht gesichert.")
  end
  function V.blockageTalk(game,stage,ow,done)
    if not V.available(game)then return show(game,tr(
      "This expedition is currently inactive.",
      "Diese Expedition ist gerade nicht aktiv."),done)end
    local row=BLOCK_STAGE[stage];local p=normalisePuzzle(game)
    if not row then if done then done()end;return false end
    if p[row.field]then return show(game,tr("The drilled passage is clear.",
      "Der freigebohrte Weg ist offen."),done)end
    if not row.prerequisite(p)then return show(game,blockageHint(stage,p),done)end
    return show(game,tr("The drill is ready. Clear this rock blockage?",
      "Der Bohrer ist bereit. Diese Felsblockade sprengen?"),nil,
      {defaultNo=true,choice=function(yes)
        if not yes then if done then done()end;return end
        local ok=V.clearBlockage(game,stage,ow)
        return show(game,ok and tr("The blockage collapses. The way is clear!",
          "Die Blockade stürzt ein. Der Weg ist frei!")or tr(
          "The drill does not start.","Der Bohrer springt nicht an."),done)
      end})
  end

  function V.recordGuardian(game,result)
    if result~="win"and result~="caught"then return false,"unfinished"end
    local p=normalisePuzzle(game)
    if not p.lowerPlugCleared then return false,"locked"end
    if p.guardianDefeated then return false,"recorded"end
    p.guardianDefeated=true;setRunProgress(game,p)
    setObjectVisible(game,V.ASCENT_MAP,"KA_MOLTRES_MAGMAR_GUARD",false)
    writeSave(game);return true
  end
  function V.guardianTalk(game,ow,npc,done)
    if not V.available(game)then return show(game,tr(
      "This expedition is currently inactive.",
      "Diese Expedition ist gerade nicht aktiv."),done)end
    local p=normalisePuzzle(game)
    if p.guardianDefeated then return show(game,tr("Only cooling footprints remain.",
      "Nur abkühlende Spuren sind geblieben."),done)end
    if not p.lowerPlugCleared then return show(game,tr(
      "A hot growl echoes beyond the lower blockage.",
      "Hinter der unteren Blockade hallt ein heißes Knurren."),done)end
    local function start()
      local BattleState=opts.battleState or require("src.battle.BattleState")
      local battle=BattleState.newWild(game,"MAGMAR",55,{
        encounterSource="moltres_volcano_guard",randomizerProtected=true})
      battle.kaMoltresVolcanoGuard=true
      battle.onFinish=function(result)
        if V.recordGuardian(game,result)then
          hideLive(ow,V.ASCENT_MAP,{"KA_MOLTRES_MAGMAR_GUARD"})
        end
        V.syncPuzzleVisibility(game)
        if ow and type(ow.afterBattle)=="function"then ow:afterBattle(result,battle)end
        if done then done()end
      end
      if ow and type(ow.pushBattle)=="function"then ow:pushBattle(battle)
      elseif done then done()end
    end
    return show(game,tr("MAGMAR blocks the vent controls!",
      "MAGMAR versperrt die Steuerung der Schlote!"),start)
  end
  local CURRENT_ORDER={1,2,3}
  local CURRENT_LABELS={{"EAST","OST"},{"SOUTH","SÜD"},{"WEST","WEST"}}
  function V.activateCurrent(game,index,ow)
    if not V.available(game)then return false,"inactive"end
    index=math.floor(tonumber(index)or 0)
    if index<1 or index>3 then return false,"current"end
    local p=normalisePuzzle(game)
    if not p.guardianDefeated then return false,"guardian"end
    if p.currentSolved then return false,"solved"end
    if index~=CURRENT_ORDER[p.currentStep+1]then
      p.currentStep=0;p.mistakes=p.mistakes+1;setRunProgress(game,p);writeSave(game)
      return false,"reset"
    end
    p.currentStep=p.currentStep+1
    if p.currentStep==#CURRENT_ORDER then
      p.currentSolved=true;setGroup(game,V.ASCENT_MAP,V.CURRENT_NAMES,false)
      hideLive(ow,V.ASCENT_MAP,V.CURRENT_NAMES)
    end
    setRunProgress(game,p);writeSave(game)
    return true,p.currentSolved and"complete"or"correct"
  end
  function V.currentTalk(game,index,ow,done)
    if not V.available(game)then return show(game,tr(
      "This expedition is currently inactive.",
      "Diese Expedition ist gerade nicht aktiv."),done)end
    local p=normalisePuzzle(game)
    if not p.guardianDefeated then return show(game,tr(
      "MAGMAR's heat drives the vent back.","MAGMARs Hitze drückt den Schlot zurück."),done)end
    if p.currentSolved then return show(game,tr("The lava channel is stable.",
      "Der Lavakanal ist stabil."),done)end
    local label=CURRENT_LABELS[index]
    return show(game,tr(("Turn the %s vent?"):format(label[1]),
      ("Den Schlot %s drehen?"):format(label[2])),nil,{defaultNo=true,
        choice=function(yes)
          if not yes then if done then done()end;return end
          local _,why=V.activateCurrent(game,index,ow)
          local text=why=="reset"and tr(
            "The current bucks. All three vents return to their old position.",
            "Die Strömung schlägt um. Alle drei Schlote springen zurück.")
            or why=="complete"and tr(
              "The lava flows east, south, then west. The upper drill receives power.",
              "Die Lava fließt nach Ost, Süd und West. Der obere Bohrer hat Strom.")
            or tr("The current follows the arrow.","Die Strömung folgt dem Pfeil.")
          return show(game,text,done)
        end})
  end

  function V.challenge(game,ow,npc,done)
    if not V.available(game)then return show(game,tr(
      "This expedition is currently inactive.",
      "Diese Expedition ist gerade nicht aktiv."),done)end
    if eventComplete(game)then return show(game,tr("Only warm ash remains.",
      "Nur warme Asche ist geblieben."),done)end
    if not V.puzzleSolved(game)then return show(game,tr(
      "The final rock wall still seals the crater.",
      "Die letzte Felswand versperrt noch den Krater."),done)end
    local function start()
      local BattleState=opts.battleState or require("src.battle.BattleState")
      local battle=BattleState.newWild(game,"MOLTRES",V.LEVEL,{
        encounterSource="moltres_volcano",randomizerProtected=true})
      battle.kaMoltresVolcano=true
      battle.onFinish=function(result)
        V.recordCompletion(game,result,battle.enemy and battle.enemy.mon)
        V.syncPuzzleVisibility(game)
        if ow and type(ow.afterBattle)=="function"then ow:afterBattle(result,battle)end
        if done then done()end
      end
      if ow and type(ow.pushBattle)=="function"then ow:pushBattle(battle)
      elseif done then done()end
    end
    return show(game,tr("MOLTRES erupts from the crater!",
      "LAVADOS schießt aus dem Krater!"),start)
  end
  function V.syncVisibility(game)
    game=game or activeGame;local save=game and game.save;if not save then return false end
    save.objectToggles=save.objectToggles or{}
    save.objectToggles[V.NATIVE_MAP]=save.objectToggles[V.NATIVE_MAP]or{}
    local toggles=save.objectToggles[V.NATIVE_MAP]
    -- The generic postgame controller owns native Moltres when the volcano
    -- is inactive. Clearing its explicit true/false here makes every nested
    -- map.entered repair it and reload Victory Road again until stack overflow.
    -- Only claim visibility while relocation is active; postgame restores the
    -- native policy on map/save/option changes when relocation is disabled.
    if V.available(game) then toggles[V.NATIVE_OBJECT]=false end
    V.syncPuzzleVisibility(game);return true
  end

  local function addObject(objects,name,sprite,x,y,text,range)
    objects[#objects+1]={index=#objects+1,name=name,sprite=sprite,x=x,y=y,
      movement="STAY",range=range or"NONE",text=text,passable=false}
  end
  local function addWall(objects,names,y,text,x0)
    for index,name in ipairs(names)do
      addObject(objects,name,"SPRITE_BOULDER",(x0 or 3)+index,y,text)
    end
  end
  local function baseObjects()
    local rows={}
    addObject(rows,"KA_MOLTRES_VOLCANO_RETURN","SPRITE_GAMBLER",10,19,V.RETURN_TEXT,"UP")
    -- Hidden on the lower-left approach, never beside Lavados.
    addObject(rows,"KA_MOLTRES_HEAT_RESEARCHER","SPRITE_SCIENTIST",5,18,V.PROSPECTOR_TEXT,"RIGHT")
    local cells={{5,15},{10,11},{14,15}}
    for i,cell in ipairs(cells)do addObject(rows,V.BASE_RUBY_NAMES[i],
      "SPRITE_POKE_BALL",cell[1],cell[2],V.BASE_RUBY_TEXTS[i])end
    addWall(rows,V.BASE_BLOCK_NAMES,6,V.BASE_DRILL_TEXT,3)
    addObject(rows,V.PASSAGE_NAMES[1],"SPRITE_BOULDER",10,4,V.PASSAGE_TEXTS[1])
    return rows
  end
  local function ascentObjects()
    local rows={}
    addObject(rows,V.PASSAGE_NAMES[2],"SPRITE_BOULDER",10,19,V.PASSAGE_TEXTS[2])
    local rubies={{5,16},{10,16},{14,16}}
    for i,cell in ipairs(rubies)do addObject(rows,V.ASCENT_RUBY_NAMES[i],
      "SPRITE_POKE_BALL",cell[1],cell[2],V.ASCENT_RUBY_TEXTS[i])end
    addWall(rows,V.LOWER_BLOCK_NAMES,13,V.LOWER_DRILL_TEXT,3)
    addObject(rows,"KA_MOLTRES_MAGMAR_GUARD","SPRITE_MONSTER",10,10,V.GUARDIAN_TEXT,"DOWN")
    local currents={{5,9},{10,8},{14,9}}
    for i,cell in ipairs(currents)do addObject(rows,V.CURRENT_NAMES[i],
      "SPRITE_POKE_BALL",cell[1],cell[2],V.CURRENT_TEXTS[i])end
    addWall(rows,V.UPPER_BLOCK_NAMES,6,V.UPPER_DRILL_TEXT,3)
    addObject(rows,V.PASSAGE_NAMES[3],"SPRITE_BOULDER",10,4,V.PASSAGE_TEXTS[3])
    return rows
  end
  local function summitObjects()
    local rows={}
    addObject(rows,"KA_MOLTRES_VOLCANO","SPRITE_BIRD",8,4,V.MOLTRES_TEXT,"DOWN")
    addWall(rows,V.SUMMIT_BLOCK_NAMES,5,V.SUMMIT_DRILL_TEXT,4)
    addObject(rows,V.PASSAGE_NAMES[4],"SPRITE_BOULDER",8,15,V.PASSAGE_TEXTS[4])
    return rows
  end
  local function registerText(textId,text)
    mod.content.text:register(textId,text)
    mod.content.text_pointers:patch("???",{[textId]={text=textId}})
  end
  function V.register()
    if V.registered then return false,"already-registered"end
    local tilesets=mod.content.tilesets
    if tilesets and type(tilesets.get)=="function"and not tilesets:get(volcanoTileset)then
      V.registered,V.skipped=true,"missing-volcano-tileset";return true,V.skipped
    end
    local rows={
      {id=V.ENTRY_MAP,index=V.ENTRY_INDEX,objects=baseObjects(),
        label={en="VOLCANIC ISLAND · BASE",de="VULKANINSEL · FUSS"}},
      {id=V.ASCENT_MAP,index=V.ASCENT_INDEX,objects=ascentObjects(),
        label={en="VOLCANIC ISLAND · ASCENT",de="VULKANINSEL · AUFSTIEG"}},
      {id=V.MAP,index=V.INDEX,objects=summitObjects(),
        label={en="CINNABAR CRATER · SUMMIT",de="ZINNOBER-KRATER · GIPFEL"}},
    }
    local reserved={}
    for _,row in ipairs(rows)do
      local source=assert(geometry.map(row.id),"missing editor map "..row.id)
      assert(source.index==row.index,"editor map index changed "..row.id)
      assert(not mod.content.maps:get(row.id),"duplicate Moltres volcano map "..row.id)
      assert(not reserved[row.index],"duplicate Moltres volcano index")
      reserved[row.index]=true;row.source=source
    end
    for id,definition in mod.content.maps:each()do
      assert(not(definition and reserved[definition.index]),
        "duplicate Moltres volcano index "..tostring(id))
    end
    for _,row in ipairs(rows)do local source=row.source
      -- Transitions are visible native staircase tiles, not misleading rocks.
      -- Walking onto the far stair row triggers the gated transition below.
      local objects={}
      for _,object in ipairs(row.objects)do
        local passage=false
        for _,name in ipairs(V.PASSAGE_NAMES)do
          if object.name==name then passage=true;break end
        end
        if not passage then
          object.index=#objects+1;objects[#objects+1]=object
        end
      end
      mod.content.maps:register(row.id,{id=row.id,index=row.index,
        label=tr(row.label.en,row.label.de),
        tileset=volcanoTileset,width=source.width,height=source.height,borderBlock=125,
        blocks=source.blocks,warps={},signs={},connections={},outdoor=false,
        voxelMode="FULL",voxelRevision=source.voxelRevision,voxelSurround="volcano",
        voxelAuthority="2D_BLOCKS",
        kaExplorationRevisionSha256=geometry.EXPLORATION_REVISION_SHA256,
        kaCard=V.CARD_ID,kaOwner=V.OWNER,
        kaSourceProjectSha256=V.SOURCE_PROJECT_SHA256,objects=objects})
      local pool=V.FIRE_POOLS[row.id];local slots={}
      for i,slot in ipairs(pool.slots)do
        slots[i]={species=slot.species,level=slot.level}
      end
      mod.content.encounters:register(row.id,{grass={rate=pool.rate,slots=slots}})
      if mod.content.map_songs then mod.content.map_songs:register(row.id,"Music_Dungeon1")end
    end
    registerText(V.MOLTRES_TEXT,"MOLTRES is waiting.")
    registerText(V.RETURN_TEXT,"Return to Cinnabar Island?")
    registerText(V.PROSPECTOR_TEXT,"The expedition scientist checks the vents.")
    registerText(V.BASE_DRILL_TEXT,"The first drill blockage.")
    registerText(V.LOWER_DRILL_TEXT,"The second drill blockage.")
    registerText(V.GUARDIAN_TEXT,"MAGMAR guards the vent controls.")
    registerText(V.UPPER_DRILL_TEXT,"The upper drill blockage.")
    registerText(V.SUMMIT_DRILL_TEXT,"The final crater blockage.")
    for index=1,3 do
      registerText(V.BASE_RUBY_TEXTS[index],"A red drill stone.")
      registerText(V.ASCENT_RUBY_TEXTS[index],"A red drill stone.")
      registerText(V.CURRENT_TEXTS[index],"A directional lava vent.")
    end
    for index,textId in ipairs(V.PASSAGE_TEXTS)do
      registerText(textId,("Volcanic passage %d."):format(index))
    end

    local baseTalk={
      [V.RETURN_TEXT]=function(game,_,_,done)
        return show(game,tr("Return to CINNABAR ISLAND?","Zurück zur ZINNOBERINSEL?"),nil,
          {defaultNo=true,choice=function(yes)
            if yes then V.leave(game)elseif done then done()end
          end})
      end,
      [V.PROSPECTOR_TEXT]=function(game,_,_,done)return V.scientistTalk(game,done)end,
      [V.BASE_DRILL_TEXT]=function(game,ow,_,done)return V.blockageTalk(game,"base",ow,done)end,
    }
    for index,textId in ipairs(V.BASE_RUBY_TEXTS)do local i=index
      baseTalk[textId]=function(game,ow,_,done)return V.rubyTalk(game,"base",i,ow,done)end
    end
    local ascentTalk={
      [V.LOWER_DRILL_TEXT]=function(game,ow,_,done)return V.blockageTalk(game,"lower",ow,done)end,
      [V.GUARDIAN_TEXT]=function(game,ow,npc,done)return V.guardianTalk(game,ow,npc,done)end,
      [V.UPPER_DRILL_TEXT]=function(game,ow,_,done)return V.blockageTalk(game,"upper",ow,done)end,
    }
    for index,textId in ipairs(V.ASCENT_RUBY_TEXTS)do local i=index
      ascentTalk[textId]=function(game,ow,_,done)return V.rubyTalk(game,"ascent",i,ow,done)end
    end
    for index,textId in ipairs(V.CURRENT_TEXTS)do local i=index
      ascentTalk[textId]=function(game,ow,_,done)return V.currentTalk(game,i,ow,done)end
    end
    local summitTalk={
      [V.MOLTRES_TEXT]=function(game,ow,npc,done)return V.challenge(game,ow,npc,done)end,
      [V.SUMMIT_DRILL_TEXT]=function(game,ow,_,done)return V.blockageTalk(game,"summit",ow,done)end,
    }
    local passageRows={
      {source=V.ENTRY_MAP,x=10,y=4,map=V.ASCENT_MAP,point={x=10,y=18,facing="up"},up=true,
        ready=function(p)return p.baseDrilled end,
        locked=tr("The first blockage still seals the stairs.","Die erste Blockade versperrt noch die Treppe.")},
      {source=V.ASCENT_MAP,x=10,y=19,map=V.ENTRY_MAP,point={x=10,y=5,facing="down"},up=false,ready=function()return true end},
      {source=V.ASCENT_MAP,x=10,y=4,map=V.MAP,point={x=8,y=14,facing="up"},up=true,
        ready=function(p)return p.upperPlugCleared end,
        locked=tr("The upper blockage still seals the summit.","Die obere Blockade versperrt noch den Gipfel.")},
      {source=V.MAP,x=8,y=15,map=V.ASCENT_MAP,point={x=10,y=5,facing="down"},up=false,ready=function()return true end},
    }
    local function stairStep(game,ow,x,y)
      -- Both cells across the stair are usable. Arrival is on the adjacent
      -- landing row, so standing still cannot send the player back upstairs.
      for _,row in ipairs(passageRows)do
        if ow and ow.map and ow.map.id==row.source and y==row.y
          and (x==row.x or x==row.x+1)then
          if row.up and not V.available(game)then return show(game,tr(
            "This expedition is currently inactive. Go back down.",
            "Diese Expedition ist gerade nicht aktiv. Geh wieder nach unten."))end
          if not row.ready(normalisePuzzle(game))then return show(game,row.locked)end
          return warp(game,row.map,row.point)
        end
      end
      return false
    end
    mod.content.map_scripts:register(V.ENTRY_MAP,{priority=3390,
      onEnter=function(game)V.syncPuzzleVisibility(game)end,onStep=stairStep,talk=baseTalk})
    mod.content.map_scripts:register(V.ASCENT_MAP,{priority=3390,
      onEnter=function(game)V.syncPuzzleVisibility(game)end,onStep=stairStep,talk=ascentTalk})
    mod.content.map_scripts:register(V.MAP,{priority=3390,
      onEnter=function(game)V.syncPuzzleVisibility(game)end,onStep=stairStep,talk=summitTalk})
    V.registered=true;return true
  end

  function V.secureSave(save)
    local player=save and save.player;local onLevel=false
    if type(player)=="table"then for _,mapId in ipairs(V.LEVELS)do
      if player.map==mapId then onLevel=true break end end end
    if not onLevel then return false end
    player.map,player.x,player.y,player.facing=V.RETURN.map,V.RETURN.x,V.RETURN.y,V.RETURN.facing
    player.surfing=false;return true
  end
  function V.install(game,deps)
    activeGame=game or activeGame;deps=deps or{}
    opts.battleState=deps.battleState or opts.battleState
    mapScripts=deps.mapScripts or mapScripts or require("data.scripts.init")
    state();if activeGame then V.syncVisibility(activeGame)end;return true
  end
  if mod.events and type(mod.events.on)=="function"then
    mod.events:on("save.writing",function(ev)
      V.secureSave(ev and ev.save or activeGame and activeGame.save)
    end,4210)
    for _,event in ipairs({"save.loaded","game.ready","map.entered"})do
      mod.events:on(event,function(ev)
        local game=ev and ev.game or activeGame
        if game then V.install(game,{mapScripts=mapScripts})end
      end,4210)
    end
  end
  return V
end
