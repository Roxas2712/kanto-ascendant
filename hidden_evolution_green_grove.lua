-- Package D-GREEN.  This file is intentionally self-contained: the host may
-- load it after the shared antechamber/tileset exists, but it patches neither
-- architecture nor the RED/BLUE routes.
return function(mod, opts)
  opts = opts or {}
  local G = {}
  local voxelRenderer = opts.voxelRenderer
  local questionUi = opts.questionUi
  G.COMMON_ANTECHAMBER = opts.commonAntechamberId or "KA_HIDDEN_EVOLUTION_COMMON_ANTECHAMBER"
  G.IDS = { threshold="KA_HEVO_GREEN_THRESHOLD", grove="KA_HEVO_GREEN_GROVE",
    mist="KA_HEVO_GREEN_MIST", shrine="KA_HEVO_GREEN_RAYQUAZA_SHRINE" }
  G.SHARED_SEALED_ANTECHAMBER = opts.sharedSealedAntechamberId
    or "KA_HEVO_SHARED_SEALED_ANTECHAMBER"
  G.INDEX = { [G.IDS.threshold]=1950, [G.IDS.grove]=1951,
    [G.IDS.mist]=1952, [G.IDS.shrine]=1953 }
  -- The third permanent, disjoint evolution tranche.  RED owns the five
  -- electro/magma/fossil species; this set is deliberately nature-only.
  G.UNLOCKS = { "LEAFEON", "TANGROWTH", "YANMEGA", "TOGEKISS", "AMBIPOM", "MISMAGIUS", "HONCHKROW" }
  G.MEGA_STONE = "SCEPTILITE"
  G.seed = 0x47524545 -- "GREE", never RED/BLUE's path seed
  -- Native Pokemon Red / Viridian Forest metatiles.  These are zero-based
  -- block IDs from the engine's imported ROM tileset table; no Crystal bridge,
  -- wallpaper or positional voxel approximation is involved.  Collision is
  -- deliberately validated again in register() because the pretty-looking
  -- native block 0 is actually solid, while several dense-looking grass
  -- blocks are walkable.
  local W,H = 30,20
  local WALL,FLOOR,PLAIN,GRASS,WATER,WARP,GREEN_ROOT = 2,27,46,47,45,25,99
  -- Viridian's native stump family (0x34..0x3b plus 0x48/49/4c/4d) contains
  -- the original 2x2 collision silhouettes: a hedge can leave a single
  -- north/south/east/west cell, a one-cell straight lane, or a one-cell
  -- corner open.  They are how the Gen-I map itself makes genuinely narrow
  -- paths; using only fully-open block 27 would always make a corridor two
  -- player cells wide.
  local SHAPED_BY_MASK = {
    -- Native stump family used by VIRIDIAN_FOREST itself.  Unlike blocks
    -- 4..15, these shapes expose ordinary ground rather than tall grass.
    [1]=77,[2]=76,[3]=53,[4]=73,[5]=59,[7]=52,
    [8]=72,[10]=55,[11]=54,[12]=57,[13]=56,[14]=58,
  }
  local MASK_BY_SHAPED = {}
  for mask,block in pairs(SHAPED_BY_MASK) do MASK_BY_SHAPED[block]=mask end
  local GATE_PATH = 57 -- native OO/## silhouette: one cell high, two long
  G.FOREST_BLOCKS = { WALL=WALL, FLOOR=FLOOR, PLAIN=PLAIN, GRASS=GRASS,
    WATER=WATER, WARP=WARP, GREEN_ROOT=GREEN_ROOT, GATE_PATH=GATE_PATH }
  G.FOREST_SHAPED_BLOCKS = MASK_BY_SHAPED
  local CHECKPOINT_ORDER = { [G.IDS.threshold]=1, [G.IDS.grove]=2,
    [G.IDS.mist]=3, [G.IDS.shrine]=4 }
  local SIGHT_FLAGS = { "KA_HEVO_GREEN_SIGHT_1", "KA_HEVO_GREEN_SIGHT_2",
    "KA_HEVO_GREEN_SIGHT_3", "KA_HEVO_GREEN_SIGHT_4", "KA_HEVO_GREEN_SIGHT_5" }
  G.FOG_EDGE_SCREEN_PIXELS = 2
  -- Post-composite GREEN fog is a visibility mask, not a translucent colour
  -- grade.  These exact neutral-gray bytes replace the scene completely at
  -- and beyond the authored radius in both native 2D and DRAMALESS.  Keeping
  -- this as a public immutable-by-convention contract also lets the focused
  -- renderer gate compare real PNG pixels instead of trusting a receipt.
  G.FOG_OUTER_COLOR = {30/255,30/255,30/255}
  G.FOG_OUTER_ALPHA = 1
  G.FOG_OUTER_PIXEL_TOLERANCE = 2/255
  local function tr(en,de) return opts.i18n and opts.i18n.text and opts.i18n.text(en,de) or en end
  local HASH_MOD=2147483647
  local function stableHash(value)
    local hash=5381;value=tostring(value or "")
    for i=1,#value do hash=(hash*33+value:byte(i))%HASH_MOD end
    return hash>0 and hash or 1
  end

  -- Explicit facts, never position-in-a-list.  GASTLY #092 and DITTO #132
  -- are deliberately retained as regression sentinels.
  local kanto = {{"BULBASAUR",1},{"CHARMANDER",4},{"SQUIRTLE",7},{"CATERPIE",10},{"WEEDLE",13},{"PIDGEY",16},{"RATTATA",19},{"SPEAROW",21},{"EKANS",23},{"PIKACHU",25},{"SANDSHREW",27},{"NIDORAN_F",29},{"NIDORAN_M",32},{"CLEFAIRY",35},{"VULPIX",37},{"JIGGLYPUFF",39},{"ZUBAT",41},{"ODDISH",43},{"PARAS",46},{"VENONAT",48},{"DIGLETT",50},{"MEOWTH",52},{"PSYDUCK",54},{"MANKEY",56},{"GROWLITHE",58},{"POLIWAG",60},{"ABRA",63},{"MACHOP",66},{"BELLSPROUT",69},{"TENTACOOL",72},{"GEODUDE",74},{"PONYTA",77},{"SLOWPOKE",79},{"MAGNEMITE",81},{"FARFETCHD",83},{"DODUO",84},{"SEEL",86},{"GRIMER",88},{"SHELLDER",90},{"GASTLY",92},{"ONIX",95},{"DROWZEE",96},{"KRABBY",98},{"VOLTORB",100},{"EXEGGCUTE",102},{"CUBONE",104},{"KOFFING",109},{"RHYHORN",111},{"CHANSEY",113},{"TANGELA",114},{"HORSEA",116},{"GOLDEEN",118},{"STARYU",120},{"SCYTHER",123},{"PINSIR",127},{"TAUROS",128},{"MAGIKARP",129},{"LAPRAS",131},{"DITTO",132},{"EEVEE",133}}
  local johto = {{"CHIKORITA",152},{"CYNDAQUIL",155},{"TOTODILE",158},{"SENTRET",161},{"HOOTHOOT",163},{"LEDYBA",165},{"SPINARAK",167},{"CHINCHOU",170},{"PICHU",172},{"CLEFFA",173},{"IGGLYBUFF",174},{"TOGEPI",175},{"NATU",177},{"MAREEP",179},{"MARILL",183},{"SUDOWOODO",185},{"HOPPIP",187},{"AIPOM",190},{"SUNKERN",191},{"YANMA",193},{"WOOPER",194},{"MURKROW",198},{"MISDREAVUS",200},{"UNOWN",201},{"WOBBUFFET",202},{"GIRAFARIG",203},{"PINECO",204},{"DUNSPARCE",206},{"GLIGAR",207},{"SNUBBULL",209},{"QWILFISH",211},{"SHUCKLE",213},{"HERACROSS",214},{"SNEASEL",215},{"TEDDIURSA",216},{"SLUGMA",218},{"SWINUB",220},{"CORSOLA",222},{"REMORAID",223},{"DELIBIRD",225},{"MANTINE",226},{"SKARMORY",227},{"HOUNDOUR",228},{"PHANPY",231},{"STANTLER",234},{"SMEARGLE",235},{"TYROGUE",236},{"SMOOCHUM",238},{"ELEKID",239},{"MAGBY",240},{"MILTANK",241},{"RAIKOU",243},{"ENTEI",244},{"SUICUNE",245},{"LARVITAR",246},{"LUGIA",249},{"HO_OH",250},{"CELEBI",251},{"BAYLEEF",153},{"QUILAVA",156}}
  G.questions = {}
  -- 120 localized, unique Kanto/Johto number or Yes/No prompts. The number
  -- is intentionally a Pokédex fact, so it is independently answerable.
  for i,row in ipairs(kanto) do local id,dex=row[1],row[2]; G.questions[#G.questions+1] = {
    id="K"..i, species=id, region="KANTO",category="LEGACY",legacy=true,
    kind="number", answer=dex, offered=dex,
    en="Kanto Dex number for "..id.."?", de="Kanto-Dexnummer von "..id.."?" } end
  for i,row in ipairs(johto) do local id,dex=row[1],row[2]; local claimed=(i%2==1) and dex or dex+1; G.questions[#G.questions+1] = {
    id="J"..i, species=id, region="JOHTO",category="LEGACY",legacy=true,
    kind="yesno", answer=(claimed==dex), claimed=claimed,
    en="Is "..id.." National Dex #"..claimed.."?", de="Ist "..id.." im Nationaldex Nr. "..claimed.."?" } end
  assert(#G.questions == 120, "GREEN needs exactly 120 questions")
  G.LEGACY_QUESTION_COUNT=120
  local newQuestions={
    {"KA_GREEN_X_KANTO_001","KANTO","Is PIKACHU National Dex #025?","Ist PIKACHU im Nationaldex Nr. 025?",true},
    {"KA_GREEN_X_KANTO_002","KANTO","Is BULBASAUR National Dex #001?","Ist BULBASAUR im Nationaldex Nr. 001?",true},
    {"KA_GREEN_X_KANTO_003","KANTO","Does MISTY lead the CERULEAN Gym?","Leitet MISTY die Arena von CERULEAN?",true},
    {"KA_GREEN_X_KANTO_004","KANTO","Is PALLET TOWN in KANTO?","Liegt PALLET TOWN in KANTO?",true},
    {"KA_GREEN_X_KANTO_005","KANTO","Is ARTICUNO one of Kanto's legendary birds?","Ist ARTICUNO einer von Kantos legendaeren Voegeln?",true},
    {"KA_GREEN_X_KANTO_006","KANTO","Is CHARMANDER a WATER-type Pokemon?","Ist CHARMANDER ein WASSER-Pokemon?",false},
    {"KA_GREEN_X_KANTO_007","KANTO","Does BROCK lead the CERULEAN Gym?","Leitet BROCK die Arena von CERULEAN?",false},
    {"KA_GREEN_X_KANTO_008","KANTO","Is LAVENDER TOWN in JOHTO?","Liegt LAVENDER TOWN in JOHTO?",false},
    {"KA_GREEN_X_KANTO_009","KANTO","Is MEWTWO National Dex #151?","Ist MEWTWO im Nationaldex Nr. 151?",false},
    {"KA_GREEN_X_KANTO_010","KANTO","Does SQUIRTLE evolve into CHARMELEON?","Entwickelt sich SQUIRTLE zu CHARMELEON?",false},

    {"KA_GREEN_X_JOHTO_001","JOHTO","Is CHIKORITA National Dex #152?","Ist CHIKORITA im Nationaldex Nr. 152?",true},
    {"KA_GREEN_X_JOHTO_002","JOHTO","Is CYNDAQUIL a FIRE-type Pokemon?","Ist CYNDAQUIL ein FEUER-Pokemon?",true},
    {"KA_GREEN_X_JOHTO_003","JOHTO","Is TOTODILE a WATER-type Pokemon?","Ist TOTODILE ein WASSER-Pokemon?",true},
    {"KA_GREEN_X_JOHTO_004","JOHTO","Does FALKNER lead the VIOLET Gym?","Leitet FALKNER die Arena von VIOLET?",true},
    {"KA_GREEN_X_JOHTO_005","JOHTO","Is the BURNED TOWER in ECRUTEAK?","Steht der BURNED TOWER in ECRUTEAK?",true},
    {"KA_GREEN_X_JOHTO_006","JOHTO","Does LUGIA rest in TIN TOWER?","Ruht LUGIA im TIN TOWER?",false},
    {"KA_GREEN_X_JOHTO_007","JOHTO","Does WHITNEY lead the AZALEA Gym?","Leitet WHITNEY die Arena von AZALEA?",false},
    {"KA_GREEN_X_JOHTO_008","JOHTO","Is MAREEP a GRASS-type Pokemon?","Ist MAREEP ein PFLANZEN-Pokemon?",false},
    {"KA_GREEN_X_JOHTO_009","JOHTO","Is HO-OH a WATER-type Pokemon?","Ist HO-OH ein WASSER-Pokemon?",false},
    {"KA_GREEN_X_JOHTO_010","JOHTO","Is BLACKTHORN CITY in KANTO?","Liegt BLACKTHORN CITY in KANTO?",false},

    {"KA_GREEN_X_GENERAL_001","GENERAL","Are FIRE moves effective against GRASS Pokemon?","Sind FEUER-Attacken effektiv gegen PFLANZEN-Pokemon?",true},
    {"KA_GREEN_X_GENERAL_002","GENERAL","Are WATER moves effective against FIRE Pokemon?","Sind WASSER-Attacken effektiv gegen FEUER-Pokemon?",true},
    {"KA_GREEN_X_GENERAL_003","GENERAL","Are GROUND Pokemon immune to ELECTRIC moves?","Sind BODEN-Pokemon immun gegen ELEKTRO-Attacken?",true},
    {"KA_GREEN_X_GENERAL_004","GENERAL","Can a full party contain six Pokemon?","Kann ein volles Team sechs Pokemon enthalten?",true},
    {"KA_GREEN_X_GENERAL_005","GENERAL","Are POKE BALLS used to catch Pokemon?","Werden POKE BALLS zum Fangen von Pokemon benutzt?",true},
    {"KA_GREEN_X_GENERAL_006","GENERAL","Are GRASS moves effective against FIRE Pokemon?","Sind PFLANZEN-Attacken effektiv gegen FEUER-Pokemon?",false},
    {"KA_GREEN_X_GENERAL_007","GENERAL","Does a POTION revive a fainted Pokemon?","Belebt ein TRANK ein besiegtes Pokemon wieder?",false},
    {"KA_GREEN_X_GENERAL_008","GENERAL","Does every Pokemon have exactly one type?","Hat jedes Pokemon genau einen Typ?",false},
    {"KA_GREEN_X_GENERAL_009","GENERAL","Does a critical hit always miss?","Geht ein Volltreffer immer daneben?",false},
    {"KA_GREEN_X_GENERAL_010","GENERAL","Can a fainted Pokemon battle normally without healing?","Kann ein besiegtes Pokemon ohne Heilung normal kaempfen?",false},

    {"KA_GREEN_X_SINNOH_001","SINNOH","Is TURTWIG Sinnoh's GRASS starter?","Ist TURTWIG Sinnohs PFLANZEN-Starter?",true},
    {"KA_GREEN_X_SINNOH_002","SINNOH","Is CHIMCHAR Sinnoh's FIRE starter?","Ist CHIMCHAR Sinnohs FEUER-Starter?",true},
    {"KA_GREEN_X_SINNOH_003","SINNOH","Is PIPLUP Sinnoh's WATER starter?","Ist PIPLUP Sinnohs WASSER-Starter?",true},
    {"KA_GREEN_X_SINNOH_004","SINNOH","Does ROARK lead the OREBURGH Gym?","Leitet ROARK die Arena von OREBURGH?",true},
    {"KA_GREEN_X_SINNOH_005","SINNOH","Is DIALGA associated with time?","Ist DIALGA mit der Zeit verbunden?",true},
    {"KA_GREEN_X_SINNOH_006","SINNOH","Does GARDENIA lead the SUNYSHORE Gym?","Leitet GARDENIA die Arena von SUNYSHORE?",false},
    {"KA_GREEN_X_SINNOH_007","SINNOH","Is PALKIA a pure FIRE-type Pokemon?","Ist PALKIA ein reines FEUER-Pokemon?",false},
    {"KA_GREEN_X_SINNOH_008","SINNOH","Is TWINLEAF TOWN in KANTO?","Liegt TWINLEAF TOWN in KANTO?",false},
    {"KA_GREEN_X_SINNOH_009","SINNOH","Is UXIE a JOHTO starter Pokemon?","Ist UXIE ein JOHTO-Starter?",false},
    {"KA_GREEN_X_SINNOH_010","SINNOH","Does VOLKNER lead the ETERNA Gym?","Leitet VOLKNER die Arena von ETERNA?",false},
  }
  for _,q in ipairs(newQuestions) do
    G.questions[#G.questions+1]={id=q[1],category=q[2],region=q[2],
      kind="yesno",en=q[3],de=q[4],answer=q[5]}
  end
  assert(#G.questions==160,"GREEN expanded catalogue needs 160 questions")

  local function character(source)
    local game=source and source.save and source or nil; local save=game and game.save or source or {}
    local value=opts.activeCharacter and opts.activeCharacter(game or {save=save})
    value=value or (mod.exports and mod.exports.extendedCharacters
      and mod.exports.extendedCharacters.getPlayerCharacter
      and mod.exports.extendedCharacters.getPlayerCharacter())
      or (save.hevo_run and save.hevo_run.character)
      or (save.extended_characters and save.extended_characters.player_character)
    return tostring(value or ""):upper()
  end
  function G.isGreen(source) return character(source)=="GREEN" end
  local function saveState(save,key,create)
    if mod.save and mod.save.get and mod.save.set then
      local value=mod.save:get(key)
      if type(value)~="table" and create then value={};mod.save:set(key,value) end
      return value
    end
    save[key]=type(save[key])=="table" and save[key] or (create and {} or nil)
    return save[key]
  end
  local function freshGreenState()
    return { asked={}, sight=0, rootgate=false, canopy=false,
      completed=false, checkpoint=G.IDS.threshold, checkpointRank=1,
      pending={},questionCursor=0,questionCycle=1 }
  end
  local function runState(save, create)
    local run=saveState(save,"hevo_run",create);if not run then return nil end
    run.hidden_evolution_story_campaign=type(run.hidden_evolution_story_campaign)=="table"
      and run.hidden_evolution_story_campaign or {}
    local campaign=run.hidden_evolution_story_campaign
    local token=tostring(run.cycle or run.id or 0)..":"..character(save)
    if campaign.greenToken~=token then
      campaign.greenToken=token;campaign.green=freshGreenState()
      save.flags=save.flags or {}
      for _,flag in ipairs(SIGHT_FLAGS) do save.flags[flag]=false end
    end
    campaign.green=campaign.green or freshGreenState()
    campaign.green.asked=campaign.green.asked or {}
    campaign.green.pending=type(campaign.green.pending)=="table"
      and campaign.green.pending or {}
    campaign.green.questionCursor=math.max(0,
      math.floor(tonumber(campaign.green.questionCursor) or 0))
    campaign.green.questionCycle=math.max(1,
      math.floor(tonumber(campaign.green.questionCycle) or 1))
    if type(campaign.green.questionSeed)~="number" then
      local meta=type(save)=="table" and type(save.meta)=="table" and save.meta or {}
      local identity=table.concat({tostring(meta.playthroughId or ""),
        tostring(run.runId or ""),tostring(run.id or ""),
        tostring(run.cycle or 0)},"|")
      campaign.green.questionSeed=stableHash("GREEN|"..identity)
    end
    campaign.green.checkpoint=campaign.green.checkpoint or G.IDS.threshold
    campaign.green.checkpointRank=campaign.green.checkpointRank
      or CHECKPOINT_ORDER[campaign.green.checkpoint] or 1
    -- The dungeon adapter persists its authoritative seal inside the same
    -- write that commits the GREEN reward.  G.complete sets this local view
    -- immediately afterwards, so reconstruct it from that seal when a
    -- power-cycle lands in between and keep the final SCEPTILITE chance live.
    local dungeon=type(run.dungeonLegacy)=="table" and run.dungeonLegacy
    local seals=dungeon and type(dungeon.seals)=="table" and dungeon.seals
    if seals and seals.GREEN==true then campaign.green.completed=true end
    return campaign.green,run
  end
  local function shuffled(seed)
    local a={}; for i=1,#G.questions do a[i]=i end
    seed=math.floor(tonumber(seed) or 1)%HASH_MOD;if seed<=0 then seed=1 end
    for i=#a,2,-1 do seed=(seed*48271)%HASH_MOD; local j=seed%i+1; a[i],a[j]=a[j],a[i] end
    return a
  end
  local function balancedBooleanSlots(count,seed)
    assert(count%2==0,"GREEN numeric answer slots need an even count")
    local slots={}
    for i=1,count do slots[i]=i<=count/2 end
    seed=math.floor(tonumber(seed) or 1)%HASH_MOD;if seed<=0 then seed=1 end
    for i=#slots,2,-1 do
      seed=(seed*48271)%HASH_MOD
      local j=seed%i+1
      slots[i],slots[j]=slots[j],slots[i]
    end
    return slots
  end
  local function questionById(id)
    for _,q in ipairs(G.questions) do if q.id==id then return q end end
  end
  local function presentedQuestion(q,answerFirst)
    local out={};for key,value in pairs(q) do out[key]=value end
    out.answerFirst=answerFirst==true
    return out
  end
  function G.questionFor(save, statue)
    statue=tonumber(statue)
    if not statue or statue<1 or statue>5 then return nil,"statue" end
    local s=assert(runState(save,true))
    local pending=s.pending[statue]
    local pendingId=type(pending)=="table" and pending.id or pending
    local pendingQuestion=questionById(pendingId)
    if pendingQuestion and not s.asked[pendingQuestion.id] then
      local answerFirst
      if type(pending)=="table" then
        answerFirst=pending.answerFirst
      else
        answerFirst=(s.questionSeed+s.questionCursor)%2==0
      end
      return presentedQuestion(pendingQuestion,answerFirst)
    end
    s.pending[statue]=nil
    local reserved={}
    for _,row in pairs(s.pending) do
      local id=type(row)=="table" and row.id or row
      if id then reserved[id]=true end
    end
    local order=shuffled(s.questionSeed+s.questionCycle*104729)
    local numericOrder={}
    for _,index in ipairs(order) do
      local candidate=G.questions[index]
      if candidate.kind=="number" then
        numericOrder[#numericOrder+1]=candidate.id
      end
    end
    -- Assign the 60 numeric prompts to a separately shuffled 30/30 slot bank.
    -- That preserves exact full-cycle balance without the former A/B/A/B tell.
    local slotOrder=balancedBooleanSlots(#numericOrder,
      s.questionSeed+s.questionCycle*130363)
    local numericSlots={}
    for rank,id in ipairs(numericOrder) do numericSlots[id]=slotOrder[rank] end
    for offset=0,#order-1 do
      local q=G.questions[order[(s.questionCursor+offset)%#order+1]]
      if not s.asked[q.id] and not reserved[q.id] then
        local answerFirst
        if q.kind=="number" then
          answerFirst=numericSlots[q.id]
        else
          answerFirst=(s.questionSeed+s.questionCycle+s.questionCursor)%2==0
        end
        s.pending[statue]={id=q.id,answerFirst=answerFirst}
        return presentedQuestion(q,answerFirst)
      end
    end
    s.asked={};s.pending={};s.questionCursor=0
    s.questionCycle=s.questionCycle+1
    local q=G.questionFor(save,statue)
    return q,"new_cycle"
  end
  function G.answer(save, statue, value, questionId)
    statue=tonumber(statue)
    local s=assert(runState(save,true))
    if statue<=s.sight then return false,"already" end
    if statue~=s.sight+1 then return false,"order" end
    local q=G.questionFor(save,statue)
    if not q then return false,"pool exhausted" end
    if questionId~=nil and q.id~=questionId then return false,"stale" end
    -- A displayed prompt is consumed on either response. A wrong answer has
    -- clear feedback and a fresh question next time, never a repeat/softlock.
    s.asked[q.id]=true
    s.pending[statue]=nil;s.questionCursor=s.questionCursor+1
    if value ~= q.answer then return false,"wrong",q end
    s.sight=statue
    save.flags=save.flags or {};save.flags[SIGHT_FLAGS[statue]]=true
    return true,"correct",q
  end
  function G.visibility(save) local s=assert(runState(save,true)); return 3 + s.sight * 2 end
  -- Ask the running Overworld controller instead of reimplementing HM
  -- ownership. partyKnows() checks the vanilla party and then Ascendant's
  -- fieldmove.eligibility hook. The explicit badge gate keeps this honest
  -- even if another hook supplies a synthetic user. Nothing is consumed.
  function G.cutEligibility(save,ow)
    local s=assert(runState(save,true))
    if s.sight<2 then return nil,"statues" end
    if not (save.inventory and save.inventory.CASCADEBADGE) then
      return nil,"badge"
    end
    if not (ow and type(ow.partyKnows)=="function") then return nil,"cut" end
    local user=ow:partyKnows("CUT")
    if not user then return nil,"cut" end
    return user,"eligible"
  end
  function G.canCut(save,ow) return G.cutEligibility(save,ow)~=nil end
  function G.rootgateOpen(save) local s=assert(runState(save,true));return s.rootgate==true end
  function G.openRootgate(save,ow)
    local s=assert(runState(save,true));if s.rootgate then return true,"already" end
    local _,why=G.cutEligibility(save,ow);if why~="eligible" then return false,why end
    s.rootgate=true;return true,"opened"
  end
  function G.canopyOpen(save) local s=assert(runState(save,true));return s.canopy==true end
  function G.openCanopy(save)
    local s=assert(runState(save,true));if s.sight<5 then return false,"statues" end
    s.canopy=true;return true
  end
  function G.checkpoint(save,mapId)
    local s=assert(runState(save,true));local rank=CHECKPOINT_ORDER[mapId]
    if rank and rank>s.checkpointRank then s.checkpoint,s.checkpointRank=mapId,rank end
    return s.checkpoint
  end
  function G.progress(save)
    local s=assert(runState(save,true))
    return { sight=s.sight, rootgate=s.rootgate==true, canopy=s.canopy==true,
      completed=s.completed==true, checkpoint=s.checkpoint,
      questions=(function()local n=0;for _ in pairs(s.asked)do n=n+1 end;return n end)() }
  end
  -- Read-only route summary for the shared seal.  The three optional floor
  -- lights and the hidden SCEPTILITE cache are presentation/secrets, not
  -- missing prerequisites, and therefore never appear here.
  function G.completionProgress(save)
    local run
    if mod.save and type(mod.save.get)=="function" then
      run=mod.save:get("hevo_run")
    elseif type(save)=="table" then
      run=save.hevo_run
    end
    local campaign=type(run)=="table"
      and type(run.hidden_evolution_story_campaign)=="table"
      and run.hidden_evolution_story_campaign or nil
    local token=type(run)=="table"
      and tostring(run.cycle or run.id or 0)..":"..character(save) or nil
    local s=campaign and campaign.greenToken==token
      and type(campaign.green)=="table" and campaign.green or {}
    return {
      statues=math.max(0,math.min(5,math.floor(tonumber(s.sight) or 0))),
      total=5,
      rootgate=s.rootgate==true,
      canopy=s.canopy==true,
    }
  end
  function G.complete(game)
    local save=game and game.save
    if not (save and G.isGreen(game)) then return false,"character" end
    local s=assert(runState(save,true))
    -- As on RED, this local completion marker existed before dungeonLegacy's
    -- authoritative seal.  Let the adapter re-run its character/Beyond gate
    -- for an older marker-only save; an existing seal remains idempotently
    -- rejected as `claimed` by that same adapter.
    if s.sight < 5 then return false,"statues" end
    local adapter=opts.legacyDungeonAdapter
    if not (adapter and adapter.finalize) then return false,"adapter" end
    local questions={};for id in pairs(s.asked or {}) do questions[#questions+1]=id end;table.sort(questions)
    local ok,why=adapter.finalize(game,{character="GREEN",questionIds=questions})
    if not ok then return false,why end
    s.completed=true
    return true
  end
  function G.claimMega(game)
    if not G.isGreen(game) then return false,"character" end
    local adapter=opts.legacyDungeonAdapter
    if not (adapter and type(adapter.claimSecret)=="function") then return false,"secret-api" end
    return adapter.claimSecret(game,{character="GREEN",stone=G.MEGA_STONE,
      secret="KA_GREEN_SCEPTILITE_SECRET"})
  end

  -- Each floor owns a distinct forward tree door.  Keeping this table beside
  -- the cell compiler makes the rendered FOREST block and map warp one source
  -- of truth, and gives the story coordinator the real final door.
  local FORWARD_WARPS = {
    [G.IDS.threshold]={x=55,y=5},
    [G.IDS.grove]={x=53,y=3},
    [G.IDS.mist]={x=57,y=9},
    [G.IDS.shrine]={x=51,y=3},
  }
  G.FORWARD_WARPS=FORWARD_WARPS
  G.END_WARP=FORWARD_WARPS[G.IDS.shrine]

  local function cellCanvas()
    local CW,CH=W*2,H*2
    local cells={}
    local function cell(x,y)
      assert(x>=0 and x<CW and y>=0 and y<CH,
        ("GREEN cell outside map: %d,%d"):format(x,y))
      cells[x+y*CW+1]=true
    end
    local function h(x1,x2,y)
      if x2<x1 then x1,x2=x2,x1 end
      for x=x1,x2 do cell(x,y) end
    end
    local function v(x,y1,y2)
      if y2<y1 then y1,y2=y2,y1 end
      for y=y1,y2 do cell(x,y) end
    end
    local function path(points)
      for i=1,#points-1 do
        local a,b=points[i],points[i+1]
        assert(a[1]==b[1] or a[2]==b[2],"GREEN path segment is diagonal")
        if a[2]==b[2] then h(a[1],b[1],a[2]) else v(a[1],a[2],b[2]) end
      end
      if #points==1 then cell(points[1][1],points[1][2]) end
    end
    local function pocket(bx,by)
      h(bx*2,bx*2+1,by*2);h(bx*2,bx*2+1,by*2+1)
    end
    local function compile(marks,water,gates,exitCell)
      local blocks={}
      for by=0,H-1 do for bx=0,W-1 do
        local x,y=bx*2,by*2
        local mask=(cells[x+y*CW+1] and 1 or 0)
          +(cells[x+1+y*CW+1] and 2 or 0)
          +(cells[x+(y+1)*CW+1] and 4 or 0)
          +(cells[x+1+(y+1)*CW+1] and 8 or 0)
        local block=mask==0 and WALL or mask==15 and FLOOR
          or SHAPED_BY_MASK[mask]
        assert(block,("GREEN unsupported diagonal cell mask %d at block %d,%d")
          :format(mask,bx,by))
        blocks[bx+by*W+1]=block
      end end
      for _,row in ipairs(marks or {}) do
        local index=row[1]+row[2]*W+1
        assert(blocks[index]==FLOOR,"GREEN landmark must occupy a 2x2 pocket")
        blocks[index]=row[3] or PLAIN
      end
      for _,row in ipairs(water or {}) do
        local index=row[1]+row[2]*W+1
        assert(blocks[index]==WALL,"GREEN water must replace a closed pocket")
        blocks[index]=WATER
      end
      for _,row in ipairs(gates or {}) do
        local index=row[1]+row[2]*W+1
        assert(blocks[index]==GATE_PATH,"GREEN gate must close a one-cell lane")
        blocks[index]=GREEN_ROOT
      end
      -- FOREST block 25 is the native tree door.  Its bottom-right cell owns
      -- the warp trigger; the authored terminal routes retain a cardinal
      -- approach from below or from the right.
      assert(exitCell and exitCell.x%2==1 and exitCell.y%2==1,
        "GREEN forward door must use a bottom-right FOREST cell")
      blocks[1+18*W+1]=WARP
      blocks[math.floor(exitCell.x/2)+math.floor(exitCell.y/2)*W+1]=WARP
      return blocks
    end
    return cell,path,pocket,compile
  end

  -- Four cell-authored woodland floors.  The long spines are exactly one
  -- player cell wide.  Brief 2x2 clearings carry distinct native ground
  -- marks, while apparent wrong branches curl back to a remembered junction
  -- or end at explicit feedback.
  local function thresholdLayout()
    local _,path,pocket,compile=cellCanvas()
    path{{3,37},{3,38},{5,38},{5,35},{3,35},{3,33},{11,33},
      {11,29},{7,29},{7,23},{17,23},{17,17},{27,17},{27,11},
      {37,11},{37,5},{49,5},{49,7},{57,7},{57,5},{55,5}}
    path{{7,33},{7,29},{11,29}}
    path{{11,23},{11,19},{17,19},{17,17}}
    path{{27,17},{31,17},{31,13},{37,13},{37,11}}
    path{{41,5},{41,9},{47,9},{47,5}}
    path{{9,33},{9,35}};path{{9,29},{15,29},{15,31}}
    path{{29,17},{29,15}}
    -- The retired (57,3) tree door is plain trail now.  Keeping its short
    -- approach prevents a 6.5.2 save at the former exit from resuming inside
    -- a hedge; only the new (55,5) block compiles as a door.
    path{{57,7},{57,3}}
    -- Threshold lights occupy three independent lower, middle and upper
    -- forest faults.  Each leaves the traversal trail exactly once and ends
    -- before a solid hedge rather than sitting on the route itself.
    path{{7,29},{2,29}}
    path{{26,17},{26,22}}
    path{{37,5},{32,5}}
    pocket(5,16);pocket(8,9);pocket(18,5)
    return compile({{5,16,GRASS},{8,9,PLAIN},{18,5,GRASS}},nil,nil,
      FORWARD_WARPS[G.IDS.threshold])
  end
  local function groveLayout()
    local _,path,pocket,compile=cellCanvas()
    path{{3,37},{3,38},{5,38},{5,35},{3,35},{13,35},{13,29},
      {7,29},{7,23},{23,23}}
    -- Moon Pool ring: either bank returns to the same two trail mouths.
    path{{23,23},{23,17},{33,17},{33,27},{23,27},{23,23}}
    path{{33,21},{43,21},{43,13},{51,13},{51,7},{57,7},{57,3},{53,3}}
    path{{7,35},{7,31},{13,31},{13,29}}
    path{{7,23},{11,23},{11,27},{23,27}}
    path{{43,21},{47,21},{47,17},{43,17},{43,13}}
    path{{47,13},{47,9},{51,9},{51,7}}
    path{{7,31},{9,31}};path{{7,29},{5,29}}
    path{{31,27},{31,25}};path{{43,19},{35,19}}
    -- Both ordered statues sit well beyond their own remembered fork.  The
    -- old short statue spur remains as an explicit false landmark, so moving
    -- the solver cannot silently erase a decision/dead-end.
    path{{13,35},{21,35}}
    path{{47,17},{55,17}}
    -- Three light faults leave widely separated trail junctions and stop in
    -- closed forest.  They are optional out-and-back discoveries, never
    -- markers placed directly on the traversal spine.
    path{{13,29},{18,29}}
    path{{33,23},{38,23}}
    path{{47,11},{42,11}}
    -- Long false veins end at visible native seed pods. They are genuine
    -- one-cell detours with explicit return feedback, never silent traps.
    path{{11,23},{11,19},{7,19}}
    path{{23,17},{23,13},{19,13}}
    path{{33,17},{33,13},{37,13}}
    path{{43,15},{39,15},{39,11}}
    path{{33,27},{33,31},{29,31}}
    pocket(6,17);pocket(11,11);pocket(21,8)
    return compile({{6,17,GRASS},{11,11,PLAIN},{21,8,GRASS}},
      {{13,10},{14,10},{13,11},{14,11}},nil,
      FORWARD_WARPS[G.IDS.grove])
  end
  local function mistLayout()
    local _,path,pocket,compile=cellCanvas()
    path{{3,37},{3,38},{5,38},{5,35},{3,35},{3,33},{11,33},
      {11,27},{19,27},{19,21},{25,21},{37,21},{37,15},
      {47,15},{47,13},{51,13},{51,7},{55,7},{55,11},{57,11},{57,9}}
    -- Pre-root return loops cannot cross the closed block at 12,10.
    path{{7,33},{7,29},{11,29}};path{{11,27},{15,27},{15,31},{11,31}}
    path{{7,31},{7,29}};path{{7,33},{7,35}}
    path{{21,21},{21,23},{22,23}}
    -- Deep-mist loops and the three-pronged secret leaf all reconnect behind
    -- the same one-cell root crossing.
    path{{29,21},{29,17},{35,17},{35,21}}
    path{{37,15},{31,15},{31,11},{39,11},{39,15}}
    path{{47,15},{43,15},{43,11},{47,11},{47,13}}
    path{{31,15},{19,15},{13,15}}
    path{{25,15},{25,11},{31,11}}
    path{{19,15},{19,19}}
    path{{51,7},{53,7},{53,5}}
    -- Remote solver/decoy tracks are long enough to hide their fork in the
    -- opening fog, while still giving a safe, readable way back.
    path{{11,27},{7,27},{7,25},{5,25}}
    -- Statue 5 turns south into a long, isolated lower-grove cul-de-sac.
    -- Its former western endpoint sat only two geometric cells below the
    -- living-root interaction, so the relic leaked through that wall even
    -- though reaching it required a detour.  This arm keeps the same honest
    -- post-CUT fork while placing the relic well outside every foreign fog
    -- aperture and leaving a substantial return to the canopy.
    path{{29,21},{29,31},{35,31},{35,35},{39,35}}
    path{{31,11},{31,7},{27,7}}
    -- The three ordered solvers are genuine side-arm destinations rather
    -- than objects on the traversal spine.  Statue 3 occupies the extended
    -- western arm, far from Statue 5, so even the widest solved fog aperture
    -- cannot reveal two relic silhouettes at once.
    -- Statue 5 deliberately curls twenty-four cells off the post-CUT junction,
    -- leaving the remaining mist and the whole shrine to navigate after the
    -- last answer.
    path{{11,33},{19,33}}
    path{{37,21},{45,21}}
    -- Preserve the complete old north-east exit arm as a warpfree dead end.
    -- These exact cells were legal save positions before the door moved to
    -- (57,9), and reconnect to the current route at (55,7).
    path{{51,7},{57,7},{57,3}}
    -- Lower-west, central and far-east light faults occupy three unused
    -- sectors of the mist map.  Each returns through exactly one remembered
    -- junction and remains independent of every quiz/decoy branch.
    path{{7,30},{2,30}}
    path{{27,21},{27,26}}
    path{{51,13},{56,13}}
    -- Re-home the displaced husk decoy in a separate six-cell false branch.
    path{{51,13},{51,19}}
    pocket(5,16);pocket(14,10);pocket(21,7)
    return compile({{5,16,GRASS},{14,10,PLAIN},{21,7,GRASS}},nil,
      {{12,10},{27,3}},FORWARD_WARPS[G.IDS.mist])
  end
  local function shrineLayout()
    local _,path,pocket,compile=cellCanvas()
    path{{3,37},{3,38},{5,38},{5,35},{3,35},{13,35},{13,29},
      {7,29},{7,23},{19,23},{19,17},{29,17},{29,21},{37,21},
      {37,13},{47,13},{47,7},{57,7},{57,3},{51,3}}
    path{{7,35},{7,31},{13,31},{13,29}}
    path{{7,23},{11,23},{11,27},{19,27},{19,23}}
    path{{19,17},{23,17},{23,21},{29,21}}
    path{{37,21},{41,21},{41,17},{37,17},{37,13}}
    path{{47,13},{43,13},{43,9},{47,9},{47,7}}
    path{{11,27},{9,27}};path{{31,21},{31,23}}
    path{{43,13},{43,11},{45,11}}
    pocket(6,17);pocket(11,10);pocket(20,8)
    return compile({{6,17,GRASS},{11,10,PLAIN},{20,8,GRASS}},{{16,12}},
      {{27,3}},FORWARD_WARPS[G.IDS.shrine])
  end
  local function layoutHash(blocks)
    local h=17;for _,b in ipairs(blocks)do h=(h*131+b+7)%65521 end;return ("green-%04x"):format(h)
  end
  local function def(id,blocks,warps,objects)
    local labels={ [G.IDS.threshold]={"MIST THRESHOLD","NEBEL-SCHWELLE"},[G.IDS.grove]={"ROOT GROVE","WURZELHAIN"},[G.IDS.mist]={"VEILED GROVE","VERHÜLLTER HAIN"},[G.IDS.shrine]={"RAYQUAZA SHRINE","RAYQUAZA-SCHREIN"} }
    local label=labels[id] or {"VERDANT CAVERN","GRÜNE HÖHLE"}
    return { id=id,index=G.INDEX[id],label=tr(label[1],label[2]),tileset="FOREST",width=W,height=H,
      blocks=blocks,borderBlock=WALL,warps=warps,objects=objects or {},signs={},connections={},
      layoutHash=layoutHash(blocks),voxelMode="FULL",outdoor=false,
      sourceTileset="FOREST",theme="g1_forest",generation=1 }
  end
  local function object(index,name,x,y,text,sprite)
    local statue=tostring(name):find("KA_GREEN_STATUE_",1,true)==1
    return {index=index,name=name,x=x,y=y,
      sprite=sprite or (statue and "SPRITE_KA_HEVO_QUIZ_STATUE"
        or "SPRITE_KA_EVOLUTION_RELIC"),
      semanticRole=statue and "quiz_statue" or nil,
      movement="STAY",range="NONE",text=text}
  end
  local function anchor(index,name,x,y,text)
    local row=object(index,name,x,y,text,"SPRITE_KA_HEVO_FISSURE_ANCHOR")
    row.renderMode="none";row.passable=true
    return row
  end
  G.layouts = {
    [G.IDS.threshold]=def(G.IDS.threshold,thresholdLayout(),
      {{x=3,y=37,destMap=G.COMMON_ANTECHAMBER,destWarp=1},{x=55,y=5,destMap=G.IDS.grove,destWarp=1}},
      {object(1,"KA_GREEN_LANDMARK_THRESHOLD",9,35,"TEXT_KA_GREEN_LANDMARK_THRESHOLD","SPRITE_POKE_BALL"),
       object(2,"KA_GREEN_RESET_THRESHOLD",15,31,"TEXT_KA_GREEN_RESET","SPRITE_POKE_BALL"),
       anchor(3,"KA_GREEN_SHORTCUT",29,15,"TEXT_KA_GREEN_SHORTCUT")}),
    [G.IDS.grove]=def(G.IDS.grove,groveLayout(),
      {{x=3,y=37,destMap=G.IDS.threshold,destWarp=2},{x=53,y=3,destMap=G.IDS.mist,destWarp=1}},
      {object(1,"KA_GREEN_STATUE_1",21,35,"TEXT_KA_GREEN_STATUE_1"),
       object(2,"KA_GREEN_STATUE_2",55,17,"TEXT_KA_GREEN_STATUE_2"),
       object(3,"KA_GREEN_MOON_POOL",31,25,"TEXT_KA_GREEN_MOON_POOL","SPRITE_POKE_BALL"),
       object(4,"KA_GREEN_RESET_GROVE",5,29,"TEXT_KA_GREEN_RESET","SPRITE_POKE_BALL"),
       object(5,"KA_GREEN_DECOY_GROVE_SPORE",7,19,"TEXT_KA_GREEN_DECOY_SPORE","SPRITE_POKE_BALL"),
       object(6,"KA_GREEN_DECOY_GROVE_HUSK",19,13,"TEXT_KA_GREEN_DECOY_HUSK","SPRITE_POKE_BALL"),
       object(7,"KA_GREEN_DECOY_GROVE_DEW",37,13,"TEXT_KA_GREEN_DECOY_DEW","SPRITE_POKE_BALL"),
       object(8,"KA_GREEN_DECOY_GROVE_THORN",39,11,"TEXT_KA_GREEN_DECOY_THORN","SPRITE_POKE_BALL"),
       object(9,"KA_GREEN_DECOY_GROVE_BRAMBLE",29,31,"TEXT_KA_GREEN_DECOY_THORN","SPRITE_POKE_BALL"),
       object(10,"KA_GREEN_DECOY_GROVE_MOSS",35,19,"TEXT_KA_GREEN_DECOY_HUSK","SPRITE_POKE_BALL")}),
    [G.IDS.mist]=def(G.IDS.mist,mistLayout(),
      {{x=3,y=37,destMap=G.IDS.grove,destWarp=2},{x=57,y=9,destMap=G.IDS.shrine,destWarp=1}},
      {object(1,"KA_GREEN_STATUE_3",5,25,"TEXT_KA_GREEN_STATUE_3"),
       object(2,"KA_GREEN_STATUE_4",45,21,"TEXT_KA_GREEN_STATUE_4"),
       object(3,"KA_GREEN_STATUE_5",39,35,"TEXT_KA_GREEN_STATUE_5"),
       anchor(4,"KA_GREEN_INTERNAL_CUT",22,23,"TEXT_KA_GREEN_INTERNAL_CUT"),
       object(5,"KA_GREEN_SECRET_HINT",19,19,"TEXT_KA_GREEN_SECRET_HINT","SPRITE_POKE_BALL"),
       object(6,"KA_GREEN_SCEPTILITE_SECRET",13,15,"TEXT_KA_GREEN_SCEPTILITE","SPRITE_POKE_BALL"),
       anchor(7,"KA_GREEN_CANOPY_GATE",53,5,"TEXT_KA_GREEN_CANOPY_GATE"),
       object(8,"KA_GREEN_RESET_MIST",7,35,"TEXT_KA_GREEN_RESET","SPRITE_POKE_BALL"),
       object(9,"KA_GREEN_DECOY_MIST_SPORE",19,33,"TEXT_KA_GREEN_DECOY_SPORE","SPRITE_POKE_BALL"),
       object(10,"KA_GREEN_DECOY_MIST_HUSK",51,19,"TEXT_KA_GREEN_DECOY_HUSK","SPRITE_POKE_BALL"),
       object(11,"KA_GREEN_DECOY_MIST_DEW",27,7,"TEXT_KA_GREEN_DECOY_DEW","SPRITE_POKE_BALL")}),
    [G.IDS.shrine]=def(G.IDS.shrine,shrineLayout(),
      {{x=3,y=37,destMap=G.IDS.mist,destWarp=2},{x=51,y=3,destMap=G.SHARED_SEALED_ANTECHAMBER,destWarp=1}},
      {object(1,"KA_GREEN_RESEARCH_CACHE",31,23,"TEXT_KA_GREEN_COMPLETE","SPRITE_POKE_BALL"),
       object(2,"KA_GREEN_RAYQUAZA_SEAL",45,11,"TEXT_KA_GREEN_RAYQUAZA_SEAL","SPRITE_POKE_BALL"),
       object(3,"KA_GREEN_RESET_SHRINE",9,27,"TEXT_KA_GREEN_RESET","SPRITE_POKE_BALL")}),
  }
  G.graph={ [G.COMMON_ANTECHAMBER]={G.IDS.threshold}, [G.IDS.threshold]={G.COMMON_ANTECHAMBER,G.IDS.grove}, [G.IDS.grove]={G.IDS.threshold,G.IDS.mist}, [G.IDS.mist]={G.IDS.grove,G.IDS.shrine}, [G.IDS.shrine]={G.IDS.mist,G.SHARED_SEALED_ANTECHAMBER}, [G.SHARED_SEALED_ANTECHAMBER]={G.IDS.shrine} }
  G.ENTRY_CELL={x=3,y=35}
  G.WARP_CELLS={entrance={x=3,y=37},exitByMap=FORWARD_WARPS}
  function G.isConnected(a,b)
    local q,seen,i={a},{[a]=true},1
    while q[i] do
      for _,n in ipairs(G.graph[q[i]] or {}) do
        if n==b then return true end
        if not seen[n] then seen[n]=true;q[#q+1]=n end
      end
      i=i+1
    end
    return false
  end
  function G.blockAt(id,x,y) local d=G.layouts[id];return d and d.blocks[x+y*W+1] end
  local function maskForBlock(block,openGates)
    if block==GREEN_ROOT then return openGates and MASK_BY_SHAPED[GATE_PATH] or 0 end
    if block==FLOOR or block==PLAIN or block==GRASS then return 15 end
    if block==WARP then return 8 end
    return MASK_BY_SHAPED[block] or 0
  end
  function G.cellIsOpen(id,x,y,openGates)
    local d=G.layouts[id]
    if not d or x<0 or x>=W*2 or y<0 or y>=H*2 then return false end
    local block=d.blocks[math.floor(x/2)+math.floor(y/2)*W+1]
    local bitValue=({1,2,4,8})[(x%2)+1+(y%2)*2]
    return math.floor(maskForBlock(block,openGates)/bitValue)%2==1
  end
  function G.isCollisionSafe(id,x,y,save)
    local b=G.blockAt(id,x,y)
    if b==GREEN_ROOT then
      if id==G.IDS.mist and x==12 and y==10 then return save and G.rootgateOpen(save) or false end
      if id==G.IDS.mist and x==27 and y==3 then return save and G.canopyOpen(save) or false end
      if id==G.IDS.shrine and x==27 and y==3 then
        local s=save and runState(save,true);return s and s.completed==true or false
      end
      return false
    end
    return b==FLOOR or b==PLAIN or b==GRASS or b==WARP
      or MASK_BY_SHAPED[b]~=nil
  end
  function G.topologyMetrics(id)
    assert(G.layouts[id]);local nodes,edges,dead,decisions={},0,0,0
    local function open(x,y) return G.cellIsOpen(id,x,y,true) end
    for y=0,H*2-1 do for x=0,W*2-1 do if open(x,y) then
      local key=x..":"..y;nodes[key]=true;local degree=0
      for _,q in ipairs({{x+1,y},{x-1,y},{x,y+1},{x,y-1}})do if open(q[1],q[2])then degree=degree+1;if q[1]>x or q[2]>y then edges=edges+1 end end end
      if degree==1 then dead=dead+1 end
      if degree>=3 then decisions=decisions+1 end
    end end end
    local exit=assert(FORWARD_WARPS[id]);local start,goal={3,37},{exit.x,exit.y};local q,dist,i={{start[1],start[2]}},{[start[1]..":"..start[2]]=0},1
    while q[i] do local x,y=q[i][1],q[i][2];if x==goal[1] and y==goal[2]then break end;for _,p in ipairs({{x+1,y},{x-1,y},{x,y+1},{x,y-1}})do local k=p[1]..":"..p[2];if open(p[1],p[2])and dist[k]==nil then dist[k]=dist[x..":"..y]+1;q[#q+1]=p end end;i=i+1 end
    return {nodes=(function()local n=0;for _ in pairs(nodes)do n=n+1 end;return n end)(),loops=edges-(function()local n=0;for _ in pairs(nodes)do n=n+1 end;return n end)()+1,deadends=dead,decisions=decisions,pathLength=dist[goal[1]..":"..goal[2]]}
  end
  local function feedback(game, message, done)
    if opts.showText then opts.showText(game,message,done); return true end
    game.stack:push(require("src.render.TextBox").new(game,message,done)); return true
  end
  function G.answerValue(values,index)
    if type(index)=="number" then return values[index] end
    if index then return values[1] end
    return values[2]
  end
  function G.presentQuestion(game, ow, statue, done)
    local state=assert(runState(game.save,true))
    if statue<=state.sight then
      feedback(game,tr("This statue is awake. Its light will not fade.","Diese Statue ist erwacht. Ihr Licht vergeht nicht."),done)
      return false,"already"
    end
    if statue~=state.sight+1 then
      feedback(game,tr("A dim leaf points back to the previous statue.","Ein mattes Blatt weist zur vorherigen Statue zurück."),done)
      return false,"order"
    end
    local q=G.questionFor(game.save,statue); if not q then if done then done() end;return false,"pool exhausted" end
    local spec={ question=q, defaultNo=true, values={}, labels={} }
    local prompt=tr(q.en,q.de)
    if q.kind=="number" then
      local distractor=q.answer==1 and 2 or (q.answer%2==0 and q.answer-1 or q.answer+1)
      local answerFirst=q.answerFirst==true
      spec.values=answerFirst and {q.answer,distractor} or {distractor,q.answer}
      spec.labels={"A "..string.format("%03d",spec.values[1]),"B "..string.format("%03d",spec.values[2])}
      spec.prompt=prompt
    else
      spec.values={true,false};spec.labels={tr("YES","JA"),tr("NO","NEIN")};spec.prompt=prompt
    end
    spec.yesValue,spec.noValue=spec.values[1],spec.values[2]
    local finished=false
    local function finish()
      if finished then return end
      finished=true
      if done then done() end
    end
    local function chosen(index)
      -- Do not use Lua's `a and false or b` idiom here: the legitimate NO
      -- value is boolean false and would fall through to values[1] (YES).
      local value=G.answerValue(spec.values,index)
      local ok,reason=G.answer(game.save,statue,value,q.id)
      local message=ok and tr("The leaf statue records this memory.","Die Blattstatue bewahrt diese Erinnerung.")
        or tr("Wrong. The leaf-mark stays dark. A new question awaits.","Falsch. Das Blattzeichen bleibt dunkel. Eine neue Frage wartet.")
      feedback(game,message,finish)
      return ok,reason
    end
    local rows={}
    for index,label in ipairs(spec.labels) do
      rows[index]={label=label,value=index}
    end
    local shown,screen=pcall(function()
      if not (questionUi and type(questionUi.showQuestionText)=="function") then
        return false,"question-ui"
      end
      return questionUi.showQuestionText(game,spec.prompt,function()
        if not (questionUi and type(questionUi.openQuestionMenu)=="function") then
          finish();return
        end
        local opened,menu=pcall(questionUi.openQuestionMenu,game,
          "RAYQUAZA-TEST "..statue.."/5",
          spec.prompt,rows,{
            defaultIndex=2,
            seconds=20,
            onTimeout=function()
              local correctIndex
              for index,value in ipairs(spec.values) do
                if value==q.answer then correctIndex=index;break end
              end
              chosen(correctIndex==1 and 2 or 1)
            end,
            onChoose=function(row)
              if type(row)~="table" or type(row.value)~="number"
                  or row.value%1~=0 or row.value<1 or row.value>#rows then
                finish();return
              end
              chosen(row.value)
            end,
          })
        if not opened or type(menu)~="table" then finish() end
      end,opts.showText)
    end)
    if not shown or screen==false then finish() end
    return true,q
  end
  local Blackout={};Blackout.__index=Blackout;Blackout.isOpaque=true
  function Blackout.new(game,done,text) return setmetatable({game=game,done=done,text=text},Blackout) end
  function Blackout:update() if self.game.input and (self.game.input:wasPressed("a") or self.game.input:wasPressed("b")) then self.game.stack:pop();if self.done then self.done() end end end
  function Blackout:draw() love.graphics.setColor(0,0,0,1);love.graphics.rectangle("fill",0,0,160,144);love.graphics.setColor(1,1,1,1);require("src.render.Font").draw(self.text,20,64) end
  function G.rayquazaTeaser(game,done)
    local blackText=tr("...RAYQUAZA CALLS...","...RAYQUAZA RUFT...")
    local function black() if opts.blackout then return opts.blackout(game,{color="black",teaser="RAYQUAZA",text=blackText},done) end;game.stack:push(Blackout.new(game,done,blackText));return true end
    return feedback(game,tr("The sealed door drinks every light.\nA cry coils through the black...","Die versiegelte Tür trinkt jedes Licht.\nEin Ruf windet sich durch die Schwärze..."),black)
  end
  -- Verify the exact native Viridian Forest roles used by the authored maps.
  -- This fails closed when an engine/data update changes collision semantics;
  -- it never appends blocks or rewrites the shared tileset at load time.
  function G.validateForest(forest)
    if type(forest)~="table" or type(forest.blocks)~="table" then
      return false,"FOREST tileset is unavailable"
    end
    local walkable={};for _,tile in ipairs(forest.walkable or {})do walkable[tile]=true end
    local function collisionTiles(blockId)
      local row=forest.blocks[blockId+1]
      if type(row)~="table" or #row<16 then return nil end
      return {row[5],row[7],row[13],row[15]}
    end
    local function all(blockId,predicate)
      local cells=collisionTiles(blockId);if not cells then return false end
      for _,tile in ipairs(cells)do if not predicate(tile) then return false end end
      return true
    end
    for _,blockId in ipairs({FLOOR,PLAIN,GRASS})do
      if not all(blockId,function(tile)return walkable[tile]==true end) then
        return false,("FOREST block %d is no longer fully walkable"):format(blockId)
      end
    end
    for blockId,expected in pairs(MASK_BY_SHAPED) do
      local cells=collisionTiles(blockId);local actual=0
      if not cells then return false,("FOREST shaped block %d is unavailable"):format(blockId) end
      for index,tile in ipairs(cells) do
        if walkable[tile] then actual=actual+({1,2,4,8})[index] end
      end
      if actual~=expected then
        return false,("FOREST shaped block %d changed mask %d -> %d")
          :format(blockId,expected,actual)
      end
    end
    for _,blockId in ipairs({WALL,GREEN_ROOT})do
      if not all(blockId,function(tile)return not walkable[tile] end) then
        return false,("FOREST block %d is no longer fully solid"):format(blockId)
      end
    end
    if not all(WATER,function(tile)return tile==20 end) then
      return false,"FOREST block 45 is no longer native water"
    end
    local door=collisionTiles(WARP)
    if not door or walkable[door[4]]~=true or door[4]~=58
        or walkable[door[1]] or walkable[door[2]] or walkable[door[3]] then
      return false,"FOREST block 25 is no longer the one-cell Viridian tree door"
    end
    local hasWarp=false;for _,tile in ipairs(forest.warpTiles or {})do if tile==58 then hasWarp=true end end
    local hasDoor=false;for _,tile in ipairs(forest.doorTiles or {})do if tile==58 then hasDoor=true end end
    if not (hasWarp or hasDoor) then return false,"FOREST door tile 58 is not warp-active" end
    return true
  end
  -- Slow under-canopy wisps supplement (not replace) the save-driven radial
  -- fog.  They are two continuous, screen-wide sine envelopes in the final
  -- shader: no Bayer/checker cells, integer stepping or object-local samples
  -- can form a dotted aura around a player, follower, statue or item.
  function G.fogMotionProfile(time,sight)
    time=tonumber(time) or 0
    sight=math.max(0,math.min(5,tonumber(sight) or 0))
    return {
      time=time,
      alpha=math.max(0.025,0.085-sight*0.011),
      phaseA=time*0.24,
      phaseB=time*0.17,
      lowFrequency=true,
    }
  end
  -- The sight core must still feel like Rock Tunnel: visible silhouettes,
  -- not full-bright actors with a white halo. Native 2D receives a dark,
  -- desaturated world veil after the radial fog; Voxel folds the same inner
  -- opacity into its radial shader. Statue stages lower it monotonically.
  function G.fogInnerOpacity(sight)
    sight=math.max(0,math.min(5,tonumber(sight) or 0))
    -- The core is not a clear spotlight: at sight 0 even the player and a
    -- directly adjacent statue remain muted silhouettes.  Each solved statue
    -- then lowers the inner veil in a deliberately modest permanent step.
    return ({0.72,0.62,0.54,0.44,0.32,0.18})[sight+1]
  end
  function G.fogPresentation(sight,mode)
    sight=math.max(0,math.min(5,tonumber(sight) or 0))
    if mode=="2d" then
      return {
        veilAlpha=G.fogInnerOpacity(sight),
        motionAlpha=G.fogMotionProfile(0,sight).alpha,
        veil={0.07,0.10,0.08},
        outerColor=G.FOG_OUTER_COLOR,outerAlpha=G.FOG_OUTER_ALPHA,
        shades={{0.44,0.52,0.48},{0.56,0.63,0.59}},
      }
    end
    return {
      veilAlpha=0,motionAlpha=G.fogMotionProfile(0,sight).alpha,
      veil={0.07,0.10,0.08},
      outerColor=G.FOG_OUTER_COLOR,outerAlpha=G.FOG_OUTER_ALPHA,
      shades={{0.52,0.60,0.55},{0.42,0.51,0.46}},
    }
  end
  local function fogProfile(game,mapId)
    local defs=game and game.data and game.data.field and game.data.field.mapAtmospheres
    local def=defs and defs[mapId]
    if not (def and def.effect=="fog") then return nil end
    if type(G.floorSightProfile)=="function" then
      local floorProfile=G.floorSightProfile(game.save,mapId)
      if floorProfile then
        return {radius=floorProfile.radius,opacity=G.FOG_OUTER_ALPHA,
          intensity=tonumber(def.intensity) or 0.5,
          innerOpacity=floorProfile.innerOpacity,
          sight=floorProfile.floorStage or 0,
          floorStage=floorProfile.floorStage,
          spatiallyUnbounded=floorProfile.spatiallyUnbounded==true}
      end
    end
    local radius=tonumber(def.visibility) or 2
    for _,reveal in ipairs(def.revealFlags or {}) do
      if game.save.flags and game.save.flags[reveal.flag] then
        radius=tonumber(reveal.radius) or radius
      end
    end
    local sight=G.progress(game.save).sight
    return {radius=radius,opacity=G.FOG_OUTER_ALPHA,
      intensity=tonumber(def.intensity) or 0.5,
      innerOpacity=G.fogInnerOpacity(sight),sight=sight}
  end

  local function fogExteriorSamples(clipX,clipY,clipX2,clipY2,
      centerX,centerY,radiusPixels)
    -- Stay inside the world scissor (rather than the letterbox/UI) and well
    -- outside the <=2 px analytic boundary.  Corners plus edge midpoints
    -- sample unrelated terrain regions, which makes any residual scene alpha
    -- or sprite-bound hole immediately observable in the captured PNG.
    local inset=math.max(4,G.FOG_EDGE_SCREEN_PIXELS+2)
    local left,right=clipX+inset,clipX2-inset
    local top,bottom=clipY+inset,clipY2-inset
    local candidates={}
    -- A 5x5 inset grid retains enough independent corner/edge points even at
    -- sight 5, where the six-cell aperture nearly reaches the short side of
    -- the 1024x768 framebuffer.  The distance filter below still guarantees
    -- every retained point is in the constant exterior, never the feather.
    for yi=0,4 do for xi=0,4 do
      candidates[#candidates+1]={
        left+(right-left)*xi/4,top+(bottom-top)*yi/4}
    end end
    local result={}
    local safeRadius=radiusPixels+G.FOG_EDGE_SCREEN_PIXELS+2
    for _,point in ipairs(candidates) do
      local dx,dy=point[1]-centerX,point[2]-centerY
      if dx*dx+dy*dy>=safeRadius*safeRadius then
        result[#result+1]={x=point[1],y=point[2]}
      end
    end
    return result
  end
  -- DRAMALESS renders into an antialiased scene canvas whose projected
  -- player card is not centred on its ground anchor.  Resolve the same
  -- public camera, lean, ground-height and AA modules the upright pass uses,
  -- then project the visible 16x16 card midpoint into final canvas pixels.
  function G.voxelUprightMidpoint(px,py,ground,lean,blend)
    px,py=tonumber(px) or 0,tonumber(py) or 0
    ground,lean=tonumber(ground) or 0,tonumber(lean) or 0
    blend=math.max(0,math.min(1,tonumber(blend) or 0))
    local theta=(lean-math.pi/2)*(1-blend)
    return px+8,ground+8*math.cos(theta),py+8+8*math.sin(theta)
  end
  local voxelTools
  local function voxelPlayerScreenPoint(game,ow)
    if voxelTools==false then return nil end
    if voxelTools==nil then
      local projector=voxelRenderer
        and voxelRenderer.module(game,"Voxel3D")
      local aa=voxelRenderer and voxelRenderer.module(game,"AntiAlias")
      local scene=voxelRenderer and voxelRenderer.module(game,"VoxelScene")
      local state=voxelRenderer and voxelRenderer.module(game,"VoxelState")
      local first=voxelRenderer and voxelRenderer.module(game,"FirstPerson")
      if not (projector and type(projector.project)=="function")
          or not (scene and type(scene.groundAt)=="function") then
        voxelTools=false;return nil
      end
      voxelTools={projector=projector,aa=aa,scene=scene,state=state,first=first}
    end
    local cellX=ow.player.cellX or math.floor((ow.player.px+8)/16)
    local cellY=ow.player.cellY or math.floor((ow.player.py+8)/16)
    local ground=0
    local groundOk,value=pcall(voxelTools.scene.groundAt,ow.map,cellX,cellY)
    if groundOk and tonumber(value) then ground=tonumber(value) end
    local lean=voxelTools.scene.spriteLean
      or (voxelTools.state and voxelTools.state.angle) or 0
    local blend=0
    if voxelTools.first and type(voxelTools.first.cardBlend)=="function" then
      local blendOk,amount=pcall(voxelTools.first.cardBlend)
      if blendOk and tonumber(amount) then blend=tonumber(amount) end
    end
    local wx,wy,wz=G.voxelUprightMidpoint(ow.player.px,ow.player.py,
      ground,lean,blend)
    local x,y=voxelTools.projector.project(wx,wy,wz)
    if not (x and y) then return nil end
    local factor=voxelTools.aa and voxelTools.aa.factor
      and voxelTools.aa.factor() or 1
    if not factor or factor<=0 then factor=1 end
    return x/factor,y/factor,{wx=wx,wy=wy,wz=wz,ground=ground,
      lean=lean,blend=blend}
  end
  local function drawFinalFogOverlay(ctx,game,ow)
    ow=ow or (game and game.overworld)
    local mapId=ow and ow.map and ow.map.id
    if not (ow and G.layouts[mapId]) then return false end
    local profile=fogProfile(game,mapId);if not profile then return false end
    local pipeline=ctx.pipeline==true
    local worldX=pipeline and 0 or (tonumber(ctx.worldX) or 0)
    local worldY=pipeline and 0 or (tonumber(ctx.worldY) or 0)
    local worldWidth=pipeline and (tonumber(ctx.width) or 160)
      or (tonumber(ctx.worldWidth) or 160)*(tonumber(ctx.scaleX) or 1)
    local worldHeight=pipeline and (tonumber(ctx.height) or 144)
      or (tonumber(ctx.worldHeight) or 144)*(tonumber(ctx.scaleY) or 1)
    local sx,sy=tonumber(ctx.scaleX) or 1,tonumber(ctx.scaleY) or 1
    local scale=math.max(1,math.min(sx,sy))
    local centerX,centerY,upright
    if pipeline then
      centerX,centerY,upright=voxelPlayerScreenPoint(game,ow)
      -- Never put the hole at the generic pipeline centre or the feet/ground
      -- projection: both sit below the visible upright player's midpoint.
      if not (centerX and centerY) then return false end
    else
      centerX,centerY=ctx.worldToScreen(
        ow.player.px-ow.camera.x+8,ow.player.py-ow.camera.y+12)
    end
    if G._twoDFogShader==nil and love.graphics.newShader then
      local made,shader=pcall(love.graphics.newShader,[[
        extern vec2 fogCenter;
        extern number fogRadius;
        extern number fogInnerOpacity;
        extern vec3 fogOuterColor;
        extern number fogTime;
        extern number fogMotionAlpha;
        extern number fogPixelScale;
        extern number fogEdgePixels;
        vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
          // Interior and exterior are homogeneous visibility regions.  Only
          // the <=2-screen-pixel boundary changes their base alpha, so native
          // FOREST stipple cannot be exposed as a wide circular raster halo.
          number edge = smoothstep(fogRadius - fogEdgePixels,
                                   fogRadius,
                                   distance(screen, fogCenter));
          // Broad continuous bands move slowly through the whole world pass.
          // Sine + smoothstep deliberately avoids fract(), Bayer/checker
          // thresholds and per-sprite sampling, so actors cannot acquire a
          // dotted or gridded edge while remaining dim under the same fog.
          vec2 logical = screen / max(fogPixelScale, 1.0);
          number bandA = sin(logical.y * 0.045
            + sin(logical.x * 0.018 + fogTime * 0.08) * 0.9
            - fogTime * 0.24);
          number bandB = sin(logical.x * 0.024
            - logical.y * 0.014 + fogTime * 0.17);
          number haze = smoothstep(0.15, 1.0,
                                   bandA * 0.66 + bandB * 0.34);
          number motion = haze * fogMotionAlpha * (1.0 - edge);
          number innerAlpha = min(0.94, fogInnerOpacity + motion);
          // At fogRadius (not one pixel beyond it), this becomes a fully
          // opaque constant gray.  No wall, tree, actor or item colour can
          // influence an exterior output pixel.
          vec4 innerFog = vec4(0.07, 0.10, 0.08, innerAlpha);
          return mix(innerFog, vec4(fogOuterColor, 1.0), edge);
        }
      ]])
      G._twoDFogShader=made and shader or false
    end
    local sight=profile.sight
    local presentation=G.fogPresentation(sight,pipeline and "voxel" or "2d")
    local now=love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    local motion=G.fogMotionProfile(now,sight)
    local clipX,clipY=math.max(0,worldX),math.max(0,worldY)
    local clipX2=math.min(tonumber(ctx.width) or worldX+worldWidth,worldX+worldWidth)
    local clipY2=math.min(tonumber(ctx.height) or worldY+worldHeight,worldY+worldHeight)
    love.graphics.push("all")
    if clipX2>clipX and clipY2>clipY then
      love.graphics.setScissor(clipX,clipY,clipX2-clipX,clipY2-clipY)
      love.graphics.translate(worldX,worldY)
      love.graphics.setBlendMode("alpha","alphamultiply")
      local shader=G._twoDFogShader
      if shader then
        shader:send("fogCenter",{centerX,centerY})
        shader:send("fogRadius",profile.radius*16*scale)
        shader:send("fogInnerOpacity",profile.innerOpacity)
        shader:send("fogOuterColor",G.FOG_OUTER_COLOR)
        shader:send("fogTime",motion.time)
        shader:send("fogMotionAlpha",motion.alpha)
        shader:send("fogPixelScale",scale)
        shader:send("fogEdgePixels",G.FOG_EDGE_SCREEN_PIXELS)
        love.graphics.setShader(shader);love.graphics.setColor(1,1,1,1)
      else
        -- Shader compilation failure is fail-closed: it may hide too much,
        -- but can never leak the maze. Focused renderer QA rejects this path.
        love.graphics.setColor(G.FOG_OUTER_COLOR[1],G.FOG_OUTER_COLOR[2],
          G.FOG_OUTER_COLOR[3],G.FOG_OUTER_ALPHA)
      end
      love.graphics.rectangle("fill",0,0,worldWidth,worldHeight)
      if shader then love.graphics.setShader() end
    end
    love.graphics.pop()
    local radiusPixels=profile.radius*16*scale
    local gammaCorrect=love.graphics.isGammaCorrect
      and love.graphics.isGammaCorrect() or false
    local evidence={contract="OPAQUE_OUTER_V1",mapId=mapId,
      radius=profile.radius,radiusPixels=radiusPixels,
      exteriorStartPixels=radiusPixels,opacity=profile.opacity,
      innerOpacity=profile.innerOpacity,sight=sight,postComposite=true,
      edgePixels=G.FOG_EDGE_SCREEN_PIXELS,
      outerOpaque=true,outerAlpha=G.FOG_OUTER_ALPHA,
      outerSceneWeight=0,motionExteriorWeight=0,textureSampled=false,
      outerColor={G.FOG_OUTER_COLOR[1],G.FOG_OUTER_COLOR[2],
        G.FOG_OUTER_COLOR[3]},
      outerTolerance=G.FOG_OUTER_PIXEL_TOLERANCE,
      outerSamples=fogExteriorSamples(clipX,clipY,clipX2,clipY2,
        centerX,centerY,radiusPixels),
      frameWidth=tonumber(ctx.width),frameHeight=tonumber(ctx.height),
      worldRect={x=clipX,y=clipY,width=clipX2-clipX,height=clipY2-clipY},
      center={x=centerX,y=centerY},coordinateSpace="LOVE_SCREEN_UNITS_TOP_LEFT",
      dpiX=tonumber(ctx.dpiX) or 1,dpiY=tonumber(ctx.dpiY) or 1,
      shaderActive=G._twoDFogShader and true or false,
      shaderCompiled=G._twoDFogShader and true or false,
      fallback=not G._twoDFogShader,blendMode="alpha/alphamultiply",
      gammaCorrect=gammaCorrect,
      projection=pipeline and "DRAMALESS_UPRIGHT_MIDPOINT" or "FLAT_PLAYER",
      upright=pipeline and upright or nil}
    if pipeline then G._voxelFogEvidence=evidence else G._twoDFogEvidence=evidence end
    return true
  end
  local function installFogWisps(game)
    if not (love and love.graphics and love.graphics.rectangle) then return end
    local OverworldState=require("src.world.OverworldController")
    if not rawget(OverworldState,"_kaGreenFogWrapped") then
      OverworldState._kaGreenFogWrapped=true
      OverworldState._kaGreenFogBase=OverworldState.drawAtmosphere
      OverworldState.drawAtmosphere=function(self,vw,vh)
        local owns=OverworldState._kaGreenFogOwnsAtmosphere
        if owns and owns(self) then return end
        local base=OverworldState._kaGreenFogBase
        if type(base)=="function" then base(self,vw,vh) end
      end
    end
    OverworldState._kaGreenFogOwnsAtmosphere=function(ow)
      if not (ow.map and G.layouts[ow.map.id] and game and game.save) then
        return false
      end
      local renderer=game.renderer
      if not (renderer and type(renderer.queueWorldPostOverlay)=="function") then
        return false
      end
      renderer:queueWorldPostOverlay(function(ctx)
        drawFinalFogOverlay(ctx,game,ow)
      end)
      return true
    end
  end
  function G.register()
    local forest=assert(mod.content.tilesets:get("FOREST"),"native FOREST tileset missing")
    local valid,why=G.validateForest(forest);assert(valid,why)
    for _,id in ipairs({G.IDS.threshold,G.IDS.grove,G.IDS.mist,G.IDS.shrine}) do mod.content.maps:register(id,G.layouts[id]);mod.content.map_songs:register(id,"Music_KA_DeepEvolution") end
    if mod.content.field and mod.content.field.patch then mod.content.field:patch("mapAtmospheres",{
      -- Radius is measured in player cells by the live world-pass shader.
      -- The first view is intentionally close and dense; permanent statue
      -- flags open it in modest, readable stages rather than clearing a whole
      -- gameplay screen after one answer.  The same overlay is drawn after
      -- both the native 2D and DRAMALESS world pipelines.
      [G.IDS.threshold]={effect="fog",intensity=0.99,visibility=1,opacity=1,revealFlags={{flag=SIGHT_FLAGS[1],radius=2,opacity=1},{flag=SIGHT_FLAGS[2],radius=3,opacity=1},{flag=SIGHT_FLAGS[3],radius=4,opacity=1},{flag=SIGHT_FLAGS[4],radius=5,opacity=1},{flag=SIGHT_FLAGS[5],radius=6,opacity=1}}},
      [G.IDS.grove]={effect="fog",intensity=1.00,visibility=1,opacity=1,revealFlags={{flag=SIGHT_FLAGS[1],radius=2,opacity=1},{flag=SIGHT_FLAGS[2],radius=3,opacity=1},{flag=SIGHT_FLAGS[3],radius=4,opacity=1},{flag=SIGHT_FLAGS[4],radius=5,opacity=1},{flag=SIGHT_FLAGS[5],radius=6,opacity=1}}},
      [G.IDS.mist]={effect="fog",intensity=1.00,visibility=1,opacity=1,revealFlags={{flag=SIGHT_FLAGS[1],radius=2,opacity=1},{flag=SIGHT_FLAGS[2],radius=3,opacity=1},{flag=SIGHT_FLAGS[3],radius=4,opacity=1},{flag=SIGHT_FLAGS[4],radius=5,opacity=1},{flag=SIGHT_FLAGS[5],radius=6,opacity=1}}},
      [G.IDS.shrine]={effect="fog",intensity=0.99,visibility=1,opacity=1,revealFlags={{flag=SIGHT_FLAGS[1],radius=2,opacity=1},{flag=SIGHT_FLAGS[2],radius=3,opacity=1},{flag=SIGHT_FLAGS[3],radius=4,opacity=1},{flag=SIGHT_FLAGS[4],radius=5,opacity=1},{flag=SIGHT_FLAGS[5],radius=6,opacity=1}}},
    }) end
    local text={
      TEXT_KA_GREEN_LANDMARK_THRESHOLD={"Wake the five leaf statues in order. A wrong answer changes the question; the memories open the grove gates. Three floor lights control sight on each trial floor.","Wecke die fünf Blattstatuen der Reihe nach. Nach einer falschen Antwort wechselt die Frage; die Erinnerungen öffnen die Tore des Hains. Drei Etagen-Lichtsteine steuern die Sicht jeder Prüfungsetage."},
      TEXT_KA_GREEN_INTERNAL_CUT={"LIVING ROOTS: two leaf lights, the Cascade Badge and a real CUT field user are required. CUT is not consumed.","LEBENDE WURZELN: Zwei Blattlichter, der Quellorden und ein echter ZERSCHNEIDER-Feldnutzer sind nötig. Die VM wird nicht verbraucht."},
      TEXT_KA_GREEN_SECRET_HINT={"Three leaf tips point west. The middle vein ends where the mist sounds hollow.","Drei Blattspitzen weisen nach Westen. Die Mittelader endet dort, wo der Nebel hohl klingt."},
      TEXT_KA_GREEN_SCEPTILITE={"The three-pronged leaf opens around a hidden stone.","Das dreizackige Blatt öffnet sich um einen verborgenen Stein."},
      TEXT_KA_GREEN_CANOPY_GATE={"The high canopy bears five unlit leaf marks.","Das hohe Kronendach trägt fünf dunkle Blattzeichen."},
      TEXT_KA_GREEN_MOON_POOL={"MOON POOL. Its shore curves toward the next leaf statue.","MONDTEICH. Sein Ufer biegt sich zur nächsten Blattstatue."},
      TEXT_KA_GREEN_DECOY_SPORE={"A pale spore pod marks a false vein. Retrace the narrow trail to the last fork.","Eine blasse Sporenknospe markiert eine falsche Ader. Folge dem schmalen Pfad zurück zur letzten Gabelung."},
      TEXT_KA_GREEN_DECOY_HUSK={"An empty seed husk. This trail ends here; the living route lies behind you.","Eine leere Samenhülse. Diese Spur endet hier; der lebende Weg liegt hinter dir."},
      TEXT_KA_GREEN_DECOY_DEW={"Black dew beads on a dead branch. Turn back and remember this landmark.","Schwarzer Tau liegt auf einem toten Zweig. Kehre um und merke dir dieses Zeichen."},
      TEXT_KA_GREEN_DECOY_THORN={"A hooked thorn points back through the mist. No required path continues here.","Ein Hakendorn weist durch den Nebel zurück. Hier führt kein Pflichtweg weiter."},
      TEXT_KA_GREEN_RESET={"ROOT MARK: return to this area's entrance. Statue light, questions and finds remain.","WURZELMARKE: Kehre zum Eingang dieses Areals zurück. Statuenlicht, Fragen und Funde bleiben."},
      TEXT_KA_GREEN_SHORTCUT={"A woven root remembers the Rayquaza Shrine after this path is complete.","Eine geflochtene Wurzel erinnert sich nach Abschluss an den Rayquaza-Schrein."},
      TEXT_KA_GREEN_COMPLETE={"The Green research cache unlocks its evolution records.","Der grüne Forschungsspeicher gibt seine Evolutionsdaten frei."},
      TEXT_KA_GREEN_RAYQUAZA_SEAL={"A black door remains sealed. RAYQUAZA calls once from beyond.","Eine schwarze Tür bleibt versiegelt. RAYQUAZA ruft einmal von jenseits."}}
    for i=1,5 do text["TEXT_KA_GREEN_STATUE_"..i]={"MIST STATUE "..i..": answer its Green-path question.","NEBELSTATUE "..i..": Beantworte ihre GREEN-Frage."} end
    for id,value in pairs(text) do mod.content.text:register(id,tr(value[1],value[2])) end
    mod.content.text_pointers:patch("???",(function()local t={};for id in pairs(text) do t[id]={text=id}end;return t end)())
    local function statue(game,ow,npc,done) return G.presentQuestion(game,ow,tonumber(npc.def.name:match("(%d+)$")),done) end
    local function rootcut(game,ow,_,done)
      ow=ow or (mod.world and mod.world.overworld and mod.world:overworld())
      local ok,why=G.openRootgate(game.save,ow)
      if ok and mod.world and mod.world.replaceBlock then mod.world:replaceBlock(12,10,GATE_PATH) end
      local message
      if ok then
        message=why=="already"
          and tr("The cut roots remain parted.","Die geschnittenen Wurzeln bleiben geteilt.")
          or tr("CUT parts the roots into a narrow path. Nothing is consumed.","ZERSCHNEIDER teilt die Wurzeln zu einem schmalen Pfad. Nichts wird verbraucht.")
      elseif why=="statues" then
        message=tr("Two leaf statues must shine before these roots can be cut.","Zwei Blattstatuen müssen leuchten, bevor diese Wurzeln geschnitten werden können.")
      elseif why=="badge" then
        message=tr("The roots resist. The Cascade Badge is required to use CUT here.","Die Wurzeln widerstehen. Für ZERSCHNEIDER wird hier der Quellorden benötigt.")
      else
        message=tr("The roots resist. A Pokémon or Field Kit able to use CUT here is required.","Die Wurzeln widerstehen. Ein Pokémon oder Feldset, das hier ZERSCHNEIDER einsetzen kann, wird benötigt.")
      end
      feedback(game,message,done)
      return ok,why
    end
    local function canopy(game,_,_,done)
      local ok,why=G.openCanopy(game.save)
      if ok and mod.world and mod.world.replaceBlock then mod.world:replaceBlock(27,3,GATE_PATH) end
      feedback(game,ok and tr("Five leaves shine. The high canopy folds aside.","Fünf Blätter leuchten. Das hohe Kronendach weicht.") or tr("The canopy needs all five leaf lights.","Das Kronendach braucht alle fünf Blattlichter."),done)
      return ok,why
    end
    local function reset(game,_,npc,done)
      local current=mod.world and mod.world.current and mod.world:current()
      local ow=mod.world and mod.world.overworld and mod.world:overworld()
      local mapId=(current and (current.mapId or current.id))
        or (ow and ow.map and (ow.map.id or (ow.map.def and ow.map.def.id)))
        or (npc and npc.mapId)
      return feedback(game,tr("Returning to this area's entrance. Progress remains.","Rückkehr zum Eingang dieses Areals. Der Fortschritt bleibt."),function()
        if mod.world and mod.world.warpTo and mapId then mod.world:warpTo(mapId,3,35,"up",{onDone=done}) elseif done then done() end
      end)
    end
    local function shortcut(game,_,_,done)
      local s=assert(runState(game.save,true))
      if not s.completed then return feedback(game,tr("The woven root is still asleep.","Die geflochtene Wurzel schläft noch."),done),"locked" end
      return feedback(game,tr("The remembered root leads to Rayquaza's shrine.","Die erinnernde Wurzel führt zu Rayquazas Schrein."),function()
        if mod.world and mod.world.warpTo then mod.world:warpTo(G.IDS.shrine,3,35,"up",{onDone=done}) elseif done then done() end
      end)
    end
    local talks={
      TEXT_KA_GREEN_LANDMARK_THRESHOLD=function(game,_,_,done)return feedback(game,tr("Wake statues 1 to 5 in order. A wrong answer brings a fresh question; the memories open the grove gates. The three floor lights control local sight.","Wecke die Statuen 1 bis 5 der Reihe nach. Eine falsche Antwort bringt eine neue Frage; die Erinnerungen öffnen die Tore des Hains. Die drei Etagen-Lichtsteine steuern die lokale Sicht."),done)end,
      TEXT_KA_GREEN_STATUE_1=statue,TEXT_KA_GREEN_STATUE_2=statue,TEXT_KA_GREEN_STATUE_3=statue,TEXT_KA_GREEN_STATUE_4=statue,TEXT_KA_GREEN_STATUE_5=statue,
      TEXT_KA_GREEN_INTERNAL_CUT=rootcut,TEXT_KA_GREEN_CANOPY_GATE=canopy,
      TEXT_KA_GREEN_SECRET_HINT=function(game,_,_,done)return feedback(game,tr("Three leaf tips point west. The hollow mist keeps the middle vein.","Drei Blattspitzen weisen nach Westen. Der hohle Nebel birgt die Mittelader."),done)end,
      TEXT_KA_GREEN_MOON_POOL=function(game,_,_,done)return feedback(game,tr("The Moon Pool's eastern shore bends toward the second statue.","Das Ostufer des Mondteichs biegt zur zweiten Statue."),done)end,
      TEXT_KA_GREEN_DECOY_SPORE=function(game,_,_,done)return feedback(game,tr("A pale spore pod marks a false vein. Retrace the narrow trail to the last fork.","Eine blasse Sporenknospe markiert eine falsche Ader. Folge dem schmalen Pfad zurück zur letzten Gabelung."),done)end,
      TEXT_KA_GREEN_DECOY_HUSK=function(game,_,_,done)return feedback(game,tr("An empty seed husk. This trail ends here; the living route lies behind you.","Eine leere Samenhülse. Diese Spur endet hier; der lebende Weg liegt hinter dir."),done)end,
      TEXT_KA_GREEN_DECOY_DEW=function(game,_,_,done)return feedback(game,tr("Black dew beads on a dead branch. Turn back and remember this landmark.","Schwarzer Tau liegt auf einem toten Zweig. Kehre um und merke dir dieses Zeichen."),done)end,
      TEXT_KA_GREEN_DECOY_THORN=function(game,_,_,done)return feedback(game,tr("A hooked thorn points back through the mist. No required path continues here.","Ein Hakendorn weist durch den Nebel zurück. Hier führt kein Pflichtweg weiter."),done)end,
      TEXT_KA_GREEN_RESET=reset,TEXT_KA_GREEN_SHORTCUT=shortcut,
      TEXT_KA_GREEN_SCEPTILITE=function(game,_,_,done)
        local ok,why=G.claimMega(game)
        local message=ok and tr("You found SCEPTILITE -- GEWALDRONIT! The stone is secured permanently.","Du findest GEWALDRONIT! Der Stein ist dauerhaft gesichert.")
          or (why=="claimed" and tr("The leaf hollow is empty. SCEPTILITE is already secured.","Die Blatthöhle ist leer. GEWALDRONIT ist bereits gesichert.")
          or tr("The stone waits safely until your Stone Case can receive it.","Der Stein wartet sicher, bis dein Steinkoffer ihn aufnehmen kann."))
        feedback(game,message,done);return ok,why
      end,
      TEXT_KA_GREEN_COMPLETE=function(game,_,_,done)
        local ok,why=G.complete(game)
        if ok and mod.world and mod.world.replaceBlock then mod.world:replaceBlock(27,3,GATE_PATH) end
        local message=ok and tr("The Green research records are permanent. A path opens toward the black door.","Die grünen Forschungsdaten bleiben erhalten. Ein Pfad zur schwarzen Tür öffnet sich.")
          or (why=="claimed" and tr("The Green records are already part of your legacy.","Die grünen Daten gehören bereits zu deinem Vermächtnis.")
          or tr("All five leaf statues must shine before the archive answers.","Alle fünf Blattstatuen müssen leuchten, bevor das Archiv antwortet."))
        feedback(game,message,done);return ok,why
      end,
      TEXT_KA_GREEN_RAYQUAZA_SEAL=function(game,_,_,done)
        if type(G.finalizeEndSeal)=="function" then
          local ok,why,stoneStatus=G.finalizeEndSeal(game)
          if not ok then
            local blocked=opts.legacyDungeonAdapter
              and opts.legacyDungeonAdapter.failureText
              and opts.legacyDungeonAdapter.failureText(why)
            if blocked then return feedback(game,blocked,done) end
            return feedback(game,tr("The unfinished grove keeps the final glint closed.",
              "Der unvollendete Hain hält den letzten Schimmer verschlossen."),done)
          end
          if stoneStatus=="granted" then
            return feedback(game,tr(
              "A final leaf-glint opens in the seal. SCEPTILITE is secured. RAYQUAZA calls beyond the black door.",
              "Ein letzter Blattschimmer öffnet sich im Siegel. GEWALDRONIT ist gesichert. Hinter der schwarzen Tür ruft RAYQUAZA."),done)
          end
          if stoneStatus=="claimed" then
            return feedback(game,tr(
              "The completed green seal gleams steadily. SCEPTILITE is already secured. RAYQUAZA calls beyond the black door.",
              "Das vollendete grüne Siegel leuchtet stetig. GEWALDRONIT ist bereits gesichert. Hinter der schwarzen Tür ruft RAYQUAZA."),done)
          end
          return G.rayquazaTeaser(game,done)
        end
        local s=assert(runState(game.save,true))
        if s.completed then
          local ok,why=G.claimMega(game)
          if ok then
            return feedback(game,tr(
              "A final leaf-glint opens in the seal. SCEPTILITE is secured. RAYQUAZA calls beyond the black door.",
              "Ein letzter Blattschimmer öffnet sich im Siegel. GEWALDRONIT ist gesichert. Hinter der schwarzen Tür ruft RAYQUAZA."),done)
          end
          if why~="claimed" then
            return feedback(game,tr("The unfinished grove keeps the final glint closed.",
              "Der unvollendete Hain hält den letzten Schimmer verschlossen."),done)
          end
        end
        return G.rayquazaTeaser(game,done)
      end,
    }
    for _,id in pairs(G.IDS) do mod.content.map_scripts:register(id,{priority=1950,talk=talks}) end
  end
  function G.install(game)
    installFogWisps(game)
    mod.events:on("map.entered",function(ev)
      if not (ev and G.layouts[ev.mapId]) then return end
      G.checkpoint(game.save,ev.mapId)
      if ev.mapId==G.IDS.mist and mod.world and mod.world.replaceBlock then
        mod.world:replaceBlock(12,10,G.rootgateOpen(game.save) and GATE_PATH or GREEN_ROOT)
        mod.world:replaceBlock(27,3,G.canopyOpen(game.save) and GATE_PATH or GREEN_ROOT)
      elseif ev.mapId==G.IDS.shrine and mod.world and mod.world.replaceBlock then
        local s=assert(runState(game.save,true));mod.world:replaceBlock(27,3,s.completed and GATE_PATH or GREEN_ROOT)
      end
    end)
  end
  return G
end
