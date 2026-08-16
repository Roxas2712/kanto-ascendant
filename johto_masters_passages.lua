-- Separate Johto Masters passages; johto_masters.lua remains save/reward authority.
return function(mod, opts)
  opts=opts or {};local baseline=assert(opts.baseline,"Johto Masters baseline missing")
  local postgame=assert(opts.postgame,"postgame controller missing");local i18n=opts.i18n
  local music=opts.music or {battleTheme="Music_KA_GSC_RivalBattle"}
  local P={registered=false,game=nil,contentEnabled=opts.contentEnabled==true};local box
  local tileBridge=assert(opts.tilesetFactory,"Johto Masters tileset factory missing")(mod)
  local function tr(en,de)return i18n and i18n.text(en,de) or en end
  -- One distinct compact quiz room and one finale per Master.  Historical map
  -- ids and dimensions stay stable for existing saves; the bounded play space,
  -- colour accents and two-cell labelled exits are authored below.
  P.MAPS={HALL={id="KA_JOHTO_GATE_HALL",label={"Johto Masters Gate Hall","Torhalle der Johto-Meister"},index=1960,w=18,h=14,tileset="CAVERN",ground=1,wall=27},SILVER_PASSAGE={id="KA_JOHTO_SILVER_PASSAGE",label={"Silver's Signal Passage","Silvers Signalpassage"},index=1961,w=15,h=27,tileset=tileBridge.ids.radio_tower,ground=1,wall=9,trim=10,shell=9,replaceVoid=0,segments={{layout=tileBridge.layout("G2_RADIO_TOWER_1F"),stage="entry"},{layout=tileBridge.layout("G2_RADIO_TOWER_2F"),stage="switchboard"},{layout=tileBridge.layout("G2_RADIO_TOWER_3F"),stage="relay"},{layout=tileBridge.layout("G2_RADIO_TOWER_4F"),stage="frequency"},{layout=tileBridge.layout("G2_RADIO_TOWER_5F"),stage="seal"},{layout=tileBridge.layout("G2_LAV_RADIO_TOWER_1F"),stage="broadcast"},{layout=tileBridge.layout("G2_RADIO_TOWER_5F"),stage="gate"}}},SILVER_FINALE={id="KA_JOHTO_SILVER_FINALE",label={"Silver's Signal Gate","Silvers Signaltor"},index=1962,w=9,h=4,tileset=tileBridge.ids.radio_tower,ground=1,wall=11,trim=18,layout=tileBridge.layout("G2_RADIO_TOWER_5F")},KRIS_PASSAGE={id="KA_JOHTO_KRIS_PASSAGE",label={"Kris's Research Passage","Kriss Forschungspassage"},index=1963,w=10,h=27,tileset=tileBridge.ids.ruins_of_alph,ground=3,wall=1,trim=17,shell=1,replaceVoid=0,segments={{layout=tileBridge.layout("G2_RUINS_OF_ALPH_INNER_CHAMBER"),stage="archive"},{layout=tileBridge.layout("G2_RUINS_OF_ALPH_HO_OH_WORD_ROOM"),stage="word_room"}}},KRIS_FINALE={id="KA_JOHTO_KRIS_FINALE",label={"Kris's Rune Archive","Kriss Runenarchiv"},index=1964,w=10,h=14,tileset=tileBridge.ids.ruins_of_alph,ground=3,wall=1,trim=13,layout=tileBridge.layout("G2_RUINS_OF_ALPH_INNER_CHAMBER"),entryFloor=true},GOLD_PASSAGE={id="KA_JOHTO_GOLD_PASSAGE",label={"Gold's Tower Ascent","Golds Turmaufstieg"},index=1965,w=10,h=27,tileset=tileBridge.ids.tower,ground=1,wall=9,trim=24,shell=9,replaceVoid=0,segments={{layout=tileBridge.layout("G2_TIN_TOWER_8F"),stage="gate"},{layout=tileBridge.layout("G2_TIN_TOWER_4F"),stage="decision"},{layout=tileBridge.layout("G2_ECRUTEAK_TIN_TOWER_ENTRANCE"),stage="arrival"}}},GOLD_FINALE={id="KA_JOHTO_GOLD_FINALE",label={"Gold's Final Ascent","Golds letzter Aufstieg"},index=1966,w=5,h=12,tileset=tileBridge.ids.champions_room,ground=7,wall=0,trim=32,layout=tileBridge.layout("G2_LANCES_ROOM")}}
  -- These two maps deliberately exceed the camera width: a narrow source
  -- map leaves renderer edge pixels from the prior area visible in 2D/Voxel.
  P.MAPS.SILVER_PASSAGE.w,P.MAPS.SILVER_PASSAGE.entryX=15,nil
  P.MAPS.KRIS_PASSAGE.w,P.MAPS.KRIS_PASSAGE.entryX=10,nil
  P.MAPS.SILVER_PASSAGE.tileset=tileBridge.ids.silver_signal_v9
  P.MAPS.KRIS_PASSAGE.tileset=tileBridge.ids.kris_archive_v9
  -- Keep the historical map ids/dimensions for in-progress saves, but make the
  -- normal play space one bounded room at the south end of each map.  The old
  -- multi-floor segment data remains only as migration provenance; `blocks`
  -- takes the compact quiz-room branch below and never paints it.  In
  -- particular, Gold no longer repeats three complete Tin Tower stair maps.
  local quizRoomSpecs={
    SILVER_PASSAGE={floor=1,wall=11,accents={19,20,39},entryX=9,entryY=49},
    KRIS_PASSAGE={floor=51,wall=0,accents={13,4,51},entryX=9,entryY=49},
    GOLD_PASSAGE={floor=9,wall=1,accents={40,41,9},entryX=9,entryY=49},
  }
  for mapKey,spec in pairs(quizRoomSpecs) do
    local def=P.MAPS[mapKey]
    def.quizRoom=spec
    def.entryX,def.entryY=spec.entryX,spec.entryY
    def.wall=spec.wall
    def.returnWarps={
      {x=8,y=def.h*2-2,destMap=P.MAPS.HALL.id,destWarp=1},
      {x=9,y=def.h*2-2,destMap=P.MAPS.HALL.id,destWarp=1},
    }
  end
  -- The Gate Hall keeps its local Gen-II signal material.  The three final
  -- rooms deliberately switch to the real Indigo battle-room language: the
  -- checked-in Red authority layouts for Bruno, Agatha and the Champion.
  -- This gives each Master a bounded arena, a bottom double threshold, a
  -- directed centre approach and an isolated trainer focus instead of a
  -- passage fragment stretched into a finale.
  P.MAPS.HALL.tileset=tileBridge.ids.silver_signal_v9
  -- $0b is the Radio Tower source's four-quarter structural wall.  The old
  -- Hall still advertised CAVERN $1b as its border after switching tilesets,
  -- which left a collision/visual mismatch at the camera edge.
  P.MAPS.HALL.wall=11
  local arenaAuthority={
    SILVER_FINALE={source="BRUNOS_ROOM",w=5,h=6,tileset="GYM",palette="CAVE",border=3,
      entryX=4,entryY=10,bossX=5,bossY=4,
      blocks={1,1,5,1,1,8,5,5,5,10,12,18,5,19,13,12,10,5,11,12,8,7,5,12,8,13,17,5,10,13}},
    KRIS_FINALE={source="AGATHAS_ROOM",w=5,h=6,tileset="CEMETERY",palette="GRAYMON",border=0,
      entryX=4,entryY=10,bossX=5,bossY=4,
      blocks={71,71,54,71,71,103,54,54,78,101,82,78,54,101,82,101,103,54,101,101,82,75,54,101,82,103,82,54,104,104}},
    GOLD_FINALE={source="CHAMPIONS_ROOM",w=4,h=4,tileset="GYM",palette="INDIGO",border=3,
      entryX=3,entryY=6,bossX=4,bossY=3,
      blocks={73,49,50,74,75,5,5,76,75,5,5,76,82,49,50,111}},
  }
  for key,arena in pairs(arenaAuthority) do
    local def=P.MAPS[key]
    def.w,def.h,def.tileset=arena.w,arena.h,arena.tileset
    def.palette,def.wall=arena.palette,arena.border
    def.entryX,def.entryY,def.entryFacing=arena.entryX,arena.entryY,"up"
    def.bossX,def.bossY=arena.bossX,arena.bossY
    def.arenaRole,def.arenaSource,def.arenaBlocks="johto_master_battlefield",arena.source,arena.blocks
    def.returnWarps={
      {x=arena.entryX,y=arena.h*2-1,destMap="LAST_MAP",destWarp=1},
      {x=arena.entryX+1,y=arena.h*2-1,destMap="LAST_MAP",destWarp=1},
    }
    -- The old Gen-II source-room field must not bypass the arena authority.
    def.layout=nil
  end
  -- Passage identity only.  The former invisible token sequences were not
  -- readable in either renderer: five copies of the trainer acted as unnamed
  -- "markers", and several stood on wall cells.  One quiz host now owns each
  -- compact room; the only other copy is the real opponent in the separate
  -- finale map.
  local R={
    silver={passage="SILVER_PASSAGE",finale="SILVER_FINALE",class="KA_JOHTO_SILVER",sprite="SPRITE_KA_JOHTO_SILVER",name="SILVER"},
    kris={passage="KRIS_PASSAGE",finale="KRIS_FINALE",class="KA_JOHTO_KRIS",sprite="SPRITE_KA_JOHTO_KRIS",name="KRIS"},
    gold={passage="GOLD_PASSAGE",finale="GOLD_FINALE",class="KA_JOHTO_GOLD",sprite="SPRITE_KA_JOHTO_GOLD",name="GOLD"},
  }
  local QUIZ_VERSION=3
  local function bi(en,de)return {en=en,de=de}end
  local function q(id,prompt,right,wrongA,wrongB)
    return {id=id,prompt=prompt,answers={right,wrongA,wrongB}}
  end
  -- Disjoint fifteen-question banks make a duplicate question impossible
  -- inside one connected Silver -> Kris -> Gold run.  Only three are drawn
  -- per room and a saved attempt seed owns both question and answer order.
  -- A failed/abandoned attempt advances that seed before the complete run is
  -- reset, so memorising one short sequence cannot bypass the challenge.
  local QUESTIONS={
    silver={
      q("S_RADIO",bi("Which Johto city has the Radio Tower?","In welcher Johto-Stadt steht der Radioturm?"),bi("GOLDENROD CITY","DUKATIA CITY"),bi("ECRUTEAK CITY","TEAK CITY"),bi("OLIVINE CITY","OLIVIANA CITY")),
      q("S_RED",bi("Where does Trainer Red wait?","Wo wartet Trainer Rot?"),bi("MT. SILVER","SILBERBERG"),bi("MT. MOON","MONDBERG"),bi("MT. MORTAR","KESSELBERG")),
      q("S_STARTER",bi("Which starter evolves into Feraligatr?","Welcher Starter entwickelt sich zu Impergator?"),bi("TOTODILE","KARNIMANI"),bi("CHIKORITA","ENDIVIE"),bi("CYNDAQUIL","FEURIGEL")),
      q("S_SNEASEL",bi("Which type hits Sneasel four times effectively?","Welcher Typ trifft Sniebel vierfach effektiv?"),bi("FIGHTING","KAMPF"),bi("FIRE","FEUER"),bi("PSYCHIC","PSYCHO")),
      q("S_LARVITAR",bi("Which Pokémon ultimately becomes Tyranitar?","Welches Pokémon wird schließlich zu Despotar?"),bi("LARVITAR","LARVITAR"),bi("PHANPY","PHANPY"),bi("TEDDIURSA","TEDDIURSA")),
      q("S_CROBAT",bi("What must Golbat gain before it evolves?","Was braucht Golbat für seine Entwicklung?"),bi("HIGH FRIENDSHIP","HOHE FREUNDSCHAFT"),bi("A MOON STONE","EINEN MONDSTEIN"),bi("A TRADE","EINEN TAUSCH")),
      q("S_DUALTYPE",bi("What are Sneasel's two types in Johto?","Welche zwei Typen hat Sniebel in Johto?"),bi("DARK / ICE","UNLICHT / EIS"),bi("DARK / STEEL","UNLICHT / STAHL"),bi("ICE / GHOST","EIS / GEIST")),
      q("S_STEELIX",bi("Which item must Onix hold while traded to become Steelix?","Welches Item muss Onix beim Tausch tragen, um Stahlos zu werden?"),bi("METAL COAT","METALLMANTEL"),bi("LEVEL 40","LEVEL 40"),bi("SUN STONE","SONNENSTEIN")),
      q("S_GENGAR",bi("Which Pokémon must be traded to obtain Gengar?","Welches Pokémon muss für Gengar getauscht werden?"),bi("HAUNTER","ALPOLLO"),bi("MISDREAVUS","TRAUNFUGIL"),bi("GOLBAT","GOLBAT")),
      q("S_MURKROW",bi("Murkrow is Dark and which second type?","Kramurx ist Unlicht und welcher zweite Typ?"),bi("FLYING","FLUG"),bi("GHOST","GEIST"),bi("POISON","GIFT")),
      q("S_MISDREAVUS",bi("What is Misdreavus's type?","Welchen Typ hat Traunfugil?"),bi("GHOST","GEIST"),bi("DARK","UNLICHT"),bi("PSYCHIC","PSYCHO")),
      q("S_BURNED",bi("In which city is the Burned Tower?","In welcher Stadt steht die Turmruine?"),bi("ECRUTEAK CITY","TEAK CITY"),bi("MAHOGANY TOWN","MAHAGONIA CITY"),bi("BLACKTHORN CITY","EBENHOLZ CITY")),
      q("S_ROCKET",bi("Which group occupies Johto's Radio Tower?","Welche Gruppe besetzt Johtos Radioturm?"),bi("TEAM ROCKET","TEAM ROCKET"),bi("TEAM AQUA","TEAM AQUA"),bi("TEAM MAGMA","TEAM MAGMA")),
      q("S_JASMINE",bi("Which type does Jasmine specialise in?","Auf welchen Typ ist Jasmin spezialisiert?"),bi("STEEL","STAHL"),bi("ROCK","GESTEIN"),bi("ELECTRIC","ELEKTRO")),
      q("S_CLAIR",bi("Which type does Clair specialise in?","Auf welchen Typ ist Sandra spezialisiert?"),bi("DRAGON","DRACHE"),bi("WATER","WASSER"),bi("FLYING","FLUG")),
    },
    kris={
      q("K_UNOWN",bi("Where are Unown chiefly researched?","Wo werden Icognito vor allem erforscht?"),bi("RUINS OF ALPH","ALPH-RUINEN"),bi("SPROUT TOWER","KNOSPENTURM"),bi("SLOWPOKE WELL","FLEGMON-BRUNNEN")),
      q("K_KINGDRA",bi("Kingdra is Water and which second type?","Seedraking ist Wasser und welcher zweite Typ?"),bi("DRAGON","DRACHE"),bi("ICE","EIS"),bi("FLYING","FLUG")),
      q("K_TOGEPI",bi("Which Pokémon evolves into Togetic?","Welches Pokémon entwickelt sich zu Togetic?"),bi("TOGEPI","TOGEPI"),bi("CLEFFA","PII"),bi("IGGLYBUFF","FLUFFELUFF")),
      q("K_KURT",bi("Who crafts special Balls from Apricorns?","Wer fertigt besondere Bälle aus Aprikokos?"),bi("KURT","KURT"),bi("BILL","BILL"),bi("PROF. ELM","PROF. LIND")),
      q("K_ESPEON",bi("What is Espeon's primary type?","Welchen Haupttyp hat Psiana?"),bi("PSYCHIC","PSYCHO"),bi("DARK","UNLICHT"),bi("GHOST","GEIST")),
      q("K_PORYGON2",bi("Which held item enables Porygon's trade evolution?","Welches Item ermöglicht Porygons Tauschentwicklung?"),bi("UP-GRADE","UP-GRADE"),bi("METAL COAT","METALLMANTEL"),bi("KING'S ROCK","KING-STEIN")),
      q("K_SCIZOR",bi("Which item must Scyther hold while being traded?","Welches Item muss Sichlor beim Tausch tragen?"),bi("METAL COAT","METALLMANTEL"),bi("UP-GRADE","UP-GRADE"),bi("DRAGON SCALE","DRACHENHAUT")),
      q("K_BELLOSSOM",bi("Which stone evolves Gloom into Bellossom?","Welcher Stein entwickelt Duflor zu Blubella?"),bi("SUN STONE","SONNENSTEIN"),bi("LEAF STONE","BLATTSTEIN"),bi("MOON STONE","MONDSTEIN")),
      q("K_POLITOED",bi("Which item must Poliwhirl hold to evolve into Politoed by trade?","Welches Item braucht Quaputzi beim Tausch zu Quaxo?"),bi("KING'S ROCK","KING-STEIN"),bi("METAL COAT","METALLMANTEL"),bi("UP-GRADE","UP-GRADE")),
      q("K_SLOWKING",bi("Which item must Slowpoke hold to evolve into Slowking by trade?","Welches Item braucht Flegmon beim Tausch zu Laschoking?"),bi("KING'S ROCK","KING-STEIN"),bi("DRAGON SCALE","DRACHENHAUT"),bi("METAL COAT","METALLMANTEL")),
      q("K_TYROGUE",bi("At which level can Tyrogue evolve?","Auf welchem Level kann Rabauz sich entwickeln?"),bi("LEVEL 20","LEVEL 20"),bi("LEVEL 16","LEVEL 16"),bi("LEVEL 30","LEVEL 30")),
      q("K_ELEKID",bi("Which Pokémon evolves from Elekid?","Zu welchem Pokémon entwickelt sich Elekid?"),bi("ELECTABUZZ","ELEKTEK"),bi("AMPHAROS","AMPHAROS"),bi("MAGNETON","MAGNETON")),
      q("K_MAGBY",bi("Which Pokémon evolves from Magby?","Zu welchem Pokémon entwickelt sich Magby?"),bi("MAGMAR","MAGMAR"),bi("MAGCARGO","MAGCARGO"),bi("HOUNDOOM","HUNDEMON")),
      q("K_SMOOCHUM",bi("Which Pokémon evolves from Smoochum?","Zu welchem Pokémon entwickelt sich Kussilla?"),bi("JYNX","ROSSANA"),bi("DELIBIRD","BOTOGEL"),bi("PILOSWINE","KEIFEL")),
      q("K_ESPEON_TIME",bi("When does a friendly Eevee evolve into Espeon?","Wann entwickelt sich ein zutrauliches Evoli zu Psiana?"),bi("DURING THE DAY","AM TAG"),bi("DURING THE NIGHT","IN DER NACHT"),bi("WITH A SUN STONE","MIT SONNENSTEIN")),
    },
    gold={
      q("G_HOOH",bi("Which tower is associated with Ho-Oh?","Welcher Turm ist mit Ho-Oh verbunden?"),bi("TIN TOWER","ZINNTURM"),bi("RADIO TOWER","RADIOTURM"),bi("SPROUT TOWER","KNOSPENTURM")),
      q("G_LUGIA",bi("Where is Lugia said to rest?","Wo soll Lugia ruhen?"),bi("WHIRL ISLANDS","STRUDELINSELN"),bi("SEAFOAM ISLANDS","SEESCHAUMINSELN"),bi("LAKE OF RAGE","SEE DES ZORNS")),
      q("G_RAIKOU",bi("What is Raikou's type?","Welchen Typ hat Raikou?"),bi("ELECTRIC","ELEKTRO"),bi("FIRE","FEUER"),bi("WATER","WASSER")),
      q("G_ENTEI",bi("What is Entei's type?","Welchen Typ hat Entei?"),bi("FIRE","FEUER"),bi("ELECTRIC","ELEKTRO"),bi("ICE","EIS")),
      q("G_SUICUNE",bi("What is Suicune's type?","Welchen Typ hat Suicune?"),bi("WATER","WASSER"),bi("ICE","EIS"),bi("FLYING","FLUG")),
      q("G_CYNDAQUIL",bi("Which starter ultimately becomes Typhlosion?","Welcher Starter wird schließlich zu Tornupto?"),bi("CYNDAQUIL","FEURIGEL"),bi("TOTODILE","KARNIMANI"),bi("CHIKORITA","ENDIVIE")),
      q("G_RAINBOW",bi("Which key item is linked to Ho-Oh?","Welches Basis-Item ist mit Ho-Oh verbunden?"),bi("RAINBOW WING","BUNTSCHWINGE"),bi("SILVER WING","SILBERFLÜGEL"),bi("CLEAR BELL","KLARGLOCKE")),
      q("G_SILVERWING",bi("Which key item is linked to Lugia?","Welches Basis-Item ist mit Lugia verbunden?"),bi("SILVER WING","SILBERFLÜGEL"),bi("RAINBOW WING","BUNTSCHWINGE"),bi("SQUIRTBOTTLE","SCHIGGYKANNE")),
      q("G_GYARADOS",bi("Where is the red Gyarados encountered?","Wo begegnet man dem roten Garados?"),bi("LAKE OF RAGE","SEE DES ZORNS"),bi("DRAGON'S DEN","DRACHENHÖHLE"),bi("WHIRL ISLANDS","STRUDELINSELN")),
      q("G_CELEBI",bi("Which forest shrine is associated with Celebi?","Mit welchem Waldschrein ist Celebi verbunden?"),bi("ILEX FOREST","STEINEICHENWALD"),bi("VIRIDIAN FOREST","VERTANIA-WALD"),bi("NATIONAL PARK","NATIONALPARK")),
      q("G_BEASTS",bi("Where are the three legendary beasts first released?","Wo werden die drei legendären Bestien zuerst befreit?"),bi("BURNED TOWER","TURMRUINE"),bi("TIN TOWER","ZINNTURM"),bi("DRAGON'S DEN","DRACHENHÖHLE")),
      q("G_AEROBLAST",bi("Which legendary Pokémon is known for Aeroblast?","Welches legendäre Pokémon ist für Luftstoß bekannt?"),bi("LUGIA","LUGIA"),bi("HO-OH","HO-OH"),bi("SUICUNE","SUICUNE")),
      q("G_SACREDFIRE",bi("Which legendary Pokémon is known for Sacred Fire?","Welches legendäre Pokémon ist für Läuterfeuer bekannt?"),bi("HO-OH","HO-OH"),bi("ENTEI","ENTEI"),bi("MOLTRES","LAVADOS")),
      q("G_UNOWN",bi("How many letter-shaped Unown forms exist in Generation II?","Wie viele buchstabenförmige Icognito gibt es in Generation II?"),bi("26","26"),bi("24","24"),bi("28","28")),
      q("G_MASTERBALL",bi("Who awards Johto's Master Ball after all eight badges?","Wer verleiht nach allen acht Orden Johtos Meisterball?"),bi("PROF. ELM","PROF. LIND"),bi("PROF. OAK","PROF. EICH"),bi("KURT","KURT")),
    },
  }
  P.questionBanks=QUESTIONS
  -- Keep the historical map dimensions so an in-progress save cannot load
  -- outside the map after this repair. New entries land in the compact
  -- central chamber, and three explicit lobby exits replace the broken
  -- LAST_MAP-only edge which could loop back into the custom map chain.
  P.MAPS.HALL.entryX,P.MAPS.HALL.entryY=9,19
  P.MAPS.HALL.returnWarps={
    {x=8,y=21,destMap="INDIGO_PLATEAU_LOBBY",destWarp=1},
    {x=9,y=21,destMap="INDIGO_PLATEAU_LOBBY",destWarp=1},
    -- Rescue edge for saves made at the old lower-left entry.
    {x=1,y=P.MAPS.HALL.h*2-3,destMap="INDIGO_PLATEAU_LOBBY",destWarp=1},
  }
  local function state(create)
    local s=baseline.state(create);if not s then return nil end
    s.passages=type(s.passages)=="table" and s.passages or {}
    s.challengeAttempt=math.max(0,math.floor(tonumber(s.challengeAttempt) or 0))
    s.challengeResets=math.max(0,math.floor(tonumber(s.challengeResets) or 0))
    if type(s.lastChallengeReset)~="table" then s.lastChallengeReset=nil end
    for _,key in ipairs({"silver","kris","gold"}) do
      local p=s.passages[key]
      if type(p)~="table" then p={} s.passages[key]=p end
      local legacyStatus=p.status
      local normalizedStatus=legacyStatus=="rewarded" and "cleared" or legacyStatus
      p.status=({locked=true,unlocked=true,entered=true,cleared=true})[normalizedStatus]
        and normalizedStatus or "locked"
      p.rewarded=p.rewarded==true or legacyStatus=="rewarded"
      p.attempts=math.max(0,math.floor(tonumber(p.attempts) or 0))
      p.resets=math.max(0,math.floor(tonumber(p.resets) or 0))
      local runSerial=math.max(0,math.floor(tonumber(s.runSerial) or 0))
      if p.quizVersion~=QUIZ_VERSION or p.quizRunSerial~=runSerial
          or p.quizAttempt~=s.challengeAttempt then
        -- Old landmark/token receipts are intentionally not promoted.  They
        -- proved no factual answer and are the source of the unclear puzzle.
        p.quizVersion,p.quizRunSerial,p.quizAttempt=
          QUIZ_VERSION,runSerial,s.challengeAttempt
        p.quizIds,p.quizSolved=nil,{}
        p.clue,p.step,p.puzzle=false,0,false
      else
        p.quizSolved=type(p.quizSolved)=="table" and p.quizSolved or {}
        p.clue=p.clue==true
        p.step=math.max(0,math.min(3,math.floor(tonumber(p.step) or 0)))
        p.puzzle=p.puzzle==true and p.step==3
      end
    end
    return s
  end
  local function save(s,game)
    if baseline.persist then return baseline.persist(s,game or P.game) end
    mod.save:set("johto_masters",s);return true
  end
  local ORDER={"silver","kris","gold"}
  local function allCleared(s)
    if not (s and type(s.passages)=="table") then return false end
    for _,key in ipairs(ORDER) do
      if not (s.passages[key] and s.passages[key].status=="cleared") then
        return false
      end
    end
    return true
  end
  local function resetChallengeState(s,reason,key)
    s.challengeAttempt=s.challengeAttempt+1
    s.challengeResets=s.challengeResets+1
    s.lastChallengeReset={
      reason=tostring(reason or "unknown"),
      key=type(key)=="string" and key or nil,
      attempt=s.challengeAttempt,
      runSerial=math.max(0,math.floor(tonumber(s.runSerial) or 0)),
    }
    for _,routeKey in ipairs(ORDER) do
      local p=s.passages[routeKey]
      p.status=routeKey=="silver" and "unlocked" or "locked"
      p.rewarded=false;p.puzzle=false;p.clue=false;p.step=0
      p.quizVersion,p.quizRunSerial,p.quizAttempt=
        QUIZ_VERSION,s.lastChallengeReset.runSerial,s.challengeAttempt
      p.quizIds,p.quizSolved,p.quizSeed=nil,{},nil
      if routeKey==key then p.resets=p.resets+1 end
    end
    return s.lastChallengeReset
  end
  function P.resetChallenge(game,reason,key)
    local s=state()
    if not (s and s.activeRun==true) or allCleared(s) then
      return false,"inactive"
    end
    local receipt=resetChallengeState(s,reason,key)
    save(s,game)
    return true,receipt
  end
  function P.leaveChallenge(game,reason)
    return P.resetChallenge(game,reason or "area_exit")
  end
  function P.sync(game)
    local activeGame=game or P.game
    local s=baseline.syncCadence and baseline.syncCadence(activeGame) or state()
    if not s then return nil end
    if s.activeRun then
      if s.passages.silver.status=="locked" then s.passages.silver.status="unlocked" end
      if s.passages.silver.status=="cleared" and s.passages.kris.status=="locked" then s.passages.kris.status="unlocked" end
      if s.passages.kris.status=="cleared" and s.passages.gold.status=="locked" then s.passages.gold.status="unlocked" end
    end
    save(s,game);return s
  end
  function P.canEnter(game,key)if baseline.eligible and not baseline.eligible(game) then return false end;local s=P.sync(game);local p=s and s.passages[key];return s and s.activeRun==true and p and (p.status=="unlocked" or p.status=="entered" or p.status=="cleared") or false end
  function P.enter(game,key)
    if not P.canEnter(game,key) then return false,"locked" end
    local s=state();if s.passages[key].status~="cleared" then s.passages[key].status="entered" end;save(s,game)
    local m=P.MAPS[R[key].passage];return mod.world and mod.world:warpTo(m.id,m.entryX or 3,m.h*2-3,"right") or false,"no world"
  end
  function P.enterHall(game,completedExit)
    if baseline.eligible and not baseline.eligible(game) then return false,"locked" end
    local s=P.sync(game)
    if not (s and (s.activeRun or completedExit==true)) then return false,"locked" end
    local m=P.MAPS.HALL;return mod.world and mod.world:warpTo(m.id,m.entryX,m.entryY,"up") or false,"no world"
  end
  function P.hostTalk(game,ow,npc)
    if not baseline.eligible(game) then return false,"locked" end
    local s=P.sync(game)
    if npc then
      npc.frozen=true
      if npc.facePlayer and ow and ow.player then npc:facePlayer(ow.player) end
    end
    if s and s.pendingGift and baseline.deliverGift then
      local message,delivered=baseline.deliverGift(game,s)
      box(game,message,function()
        if not delivered then if npc then npc.frozen=false end;return end
        local ready=baseline.beginRun and baseline.beginRun(game)
        if ready then
          if npc then npc.frozen=false end
          P.enterHall(game)
        else
          if npc then npc.frozen=false end
          if baseline.refresh then baseline.refresh(game,ow and ow.map and ow.map.id) end
        end
      end)
      return true
    end
    local ready,reason
    if baseline.beginRun then ready,reason=baseline.beginRun(game) end
    if not ready then
      box(game,reason=="elite-four" and tr(
        "Defeat Kanto's Elite Four again. Then the Johto host will return for another shiny run.",
        "Besiege Kantos Top Vier erneut. Dann kehrt der Johto-Gastgeber für einen weiteren Shiny-Lauf zurück.") or tr(
        "The Johto arenas are not ready yet.",
        "Die Johto-Arenen sind noch nicht bereit."),function()if npc then npc.frozen=false end end)
      return true
    end
    box(game,tr(
      "Johto calls, Champion. Challenge Johto's finest Trainers. Three sealed paths await: SILVER, then KRIS, then GOLD.",
      "Johto ruft, Champion. Fordere die besten Trainer Johtos heraus. Drei versiegelte Pfade warten: SILVER, dann KRIS, dann GOLD."),
      function()if npc then npc.frozen=false end;P.enterHall(game)end)
    return true
  end
  local questionOffsets={silver=104729,kris=130363,gold=155921}
  local RNG_MOD=2147483647
  local function normalizeSeed(seed)
    seed=math.floor(tonumber(seed) or 1)%RNG_MOD
    return seed>0 and seed or 1
  end
  local function seededRandom(seed)
    local cursor=normalizeSeed(seed)
    return function(maximum)
      cursor=(cursor*48271)%RNG_MOD
      return (cursor%math.max(1,math.floor(maximum)))+1
    end
  end
  local function hashSeed(seed,value)
    seed=normalizeSeed(seed)
    for index=1,#tostring(value or "") do
      seed=(seed*131+tostring(value):byte(index))%RNG_MOD
    end
    return normalizeSeed(seed)
  end
  local function shuffledIndices(count,seed)
    local out={};for index=1,count do out[index]=index end
    local random=seededRandom(seed)
    for index=count,2,-1 do
      local other=random(index)
      out[index],out[other]=out[other],out[index]
    end
    return out
  end
  local function quizSeed(s,key)
    local seed=math.max(0,math.floor(tonumber(s.runSerial) or 0))*1000003
      +math.max(0,math.floor(tonumber(s.challengeAttempt) or 0))*9176
      +questionOffsets[key]
    return hashSeed(seed,key)
  end
  function P.quizIdsForSeed(key,seed,count)
    local pool=assert(QUESTIONS[key],"unknown quiz "..tostring(key))
    count=math.max(1,math.min(#pool,math.floor(tonumber(count) or 3)))
    local order=shuffledIndices(#pool,hashSeed(seed,key))
    local out={};for index=1,count do out[index]=pool[order[index]].id end
    return out
  end
  local function ensureQuiz(s,key)
    local p,pool=s.passages[key],assert(QUESTIONS[key],"unknown quiz "..tostring(key))
    if type(p.quizIds)=="table" and #p.quizIds==3
        and p.quizAttempt==s.challengeAttempt then return p.quizIds end
    p.quizSeed=quizSeed(s,key)
    p.quizAttempt=s.challengeAttempt
    p.quizIds=P.quizIdsForSeed(key,p.quizSeed,3)
    return p.quizIds
  end
  local function questionById(key,id)
    for _,row in ipairs(QUESTIONS[key] or {}) do if row.id==id then return row end end
  end
  function P.inspect(game,key)
    if not P.canEnter(game,key) then return false,"locked" end
    local s=state();local p=s.passages[key]
    p.clue=true;ensureQuiz(s,key);save(s,game)
    return true,p.quizIds
  end
  function P.question(game,key,station)
    if not P.canEnter(game,key) then return nil,"locked" end
    local s=state();local p=s.passages[key];ensureQuiz(s,key)
    local expected=p.step+1
    if expected>3 then return nil,"complete" end
    station=math.floor(tonumber(station) or expected)
    if station~=expected then return nil,"step" end
    if p.quizSolved[station] then return nil,"solved" end
    local row=assert(questionById(key,p.quizIds[station]),"quiz question missing")
    local answerOrder=shuffledIndices(3,hashSeed(
      (p.quizSeed or quizSeed(s,key))+station*3571,row.id))
    local choices,correct={},nil
    for index,answerIndex in ipairs(answerOrder) do
      choices[index]=row.answers[answerIndex]
      if answerIndex==1 then correct=index end
    end
    local localized={}
    for index,value in ipairs(choices) do localized[index]=tr(value.en,value.de) end
    save(s,game)
    return {id=row.id,station=station,prompt=tr(row.prompt.en,row.prompt.de),
      choices=localized,correct=correct,correctLabel=tr(row.answers[1].en,row.answers[1].de)}
  end
  function P.answer(game,key,station,questionId,choice)
    if not P.canEnter(game,key) then return false,"locked" end
    local qrow,reason=P.question(game,key,station)
    if not qrow then return false,reason end
    if qrow.id~=questionId then return false,"stale" end
    local s=state();local p=s.passages[key]
    if tonumber(choice)~=qrow.correct then
      resetChallengeState(s,"wrong_answer",key);save(s,game)
      return false,"wrong",0,qrow.correctLabel
    end
    p.quizSolved[qrow.station]=true
    local solved=0
    for index=1,3 do if p.quizSolved[index] then solved=solved+1 end end
    p.step,p.puzzle=solved,solved==3
    save(s,game)
    return true,p.puzzle and "complete" or "correct",solved,qrow.correctLabel
  end
  -- Public compatibility name retained for package drivers; the old token
  -- sequence signature is deliberately gone.
  function P.choose(game,key,station,questionId,choice)
    return P.answer(game,key,station,questionId,choice)
  end
  function P.solve(game,key)
    if not P.canEnter(game,key) then return false,"locked" end
    local s=state();if not s.passages[key].puzzle or s.passages[key].step~=3 then return false,"quiz" end
    s.passages[key].puzzle=true;save(s,game);local m=P.MAPS[R[key].finale]
    return mod.world and mod.world:warpTo(m.id,m.entryX or 3,m.entryY or m.h*2-3,m.entryFacing or "right") or true
  end
  local CHALLENGE_MAPS={}
  for _,def in pairs(P.MAPS) do CHALLENGE_MAPS[def.id]=true end
  P.challengeMaps=CHALLENGE_MAPS
  function P.isChallengeMapId(mapId)
    return type(mapId)=="string" and CHALLENGE_MAPS[mapId]==true
  end
  local function liveMapId(game)
    local ow=mod.world and mod.world.overworld and mod.world:overworld()
    return ow and ow.map and ow.map.id or P.currentMapId
      or game and game.map and game.map.id
  end
  function P.itemUseBlocked(game,battle,saveRef)
    if battle and battle.johtoPassage==true then return true end
    game=game or P.game
    if saveRef and game and game.save and saveRef~=game.save then return false end
    return P.isChallengeMapId(liveMapId(game))
  end
  function P.onMapTransition(game,fromMapId,toMapId)
    fromMapId=fromMapId or P.currentMapId
    P.currentMapId=toMapId
    if P.suppressNextExitReset and not P.isChallengeMapId(toMapId) then
      P.suppressNextExitReset=nil
      return false,"handled"
    end
    if not (P.isChallengeMapId(fromMapId)
        and not P.isChallengeMapId(toMapId)) then return false,"internal" end
    -- This event-side guard never warps.  It exists for non-standard exits,
    -- debug rescue paths and migrated LAST_MAP receipts; the explicit Hall
    -- threshold owns its own single warp after resetting the save state.
    return P.leaveChallenge(game,"area_exit")
  end
  local function itemBlockedText()
    return tr(
      "The Johto trial seals every item. Nothing was used or consumed.",
      "Die Johto-Prüfung versiegelt alle Items. Nichts wurde benutzt oder verbraucht.")
  end
  local function notifyItemBlocked(game)
    if not (game and game.stack) then return false end
    game.stack:push(require("src.render.TextBox").new(game,itemBlockedText()))
    return true
  end
  local function installItemGuard()
    local BagMenu=require("src.ui.BagMenu")
    if not BagMenu._kantoAscendantJohtoTrialWrapped then
      local originalNew=BagMenu.new
      BagMenu.new=function(menuGame,menuOpts)
        menuOpts=menuOpts or {}
        local list=originalNew(menuGame,menuOpts)
        local policy=BagMenu._kantoAscendantJohtoTrialPolicy
        if not (policy and policy.itemUseBlocked(menuGame,menuOpts.battle)) then
          return list
        end
        list.__johtoTrialItemsBlocked=true
        local blocked=function()return policy.notify(menuGame)end
        list.onChoose=blocked
        list.onSelectKey=blocked
        list.onStartKey=blocked
        return list
      end
      BagMenu._kantoAscendantJohtoTrialWrapped=true
    end
    BagMenu._kantoAscendantJohtoTrialPolicy={
      itemUseBlocked=P.itemUseBlocked,notify=notifyItemBlocked,
    }
    -- BagMenu is the normal owner, while ItemEffects is the final fail-closed
    -- boundary for Quick Select or another compatible UI that delegates
    -- directly.  Returning `failed` occurs before any effect or removal.
    local ItemEffects=require("src.inventory.ItemEffects")
    if not ItemEffects._kantoAscendantJohtoTrialWrapped then
      local originalUse=ItemEffects.use
      ItemEffects.use=function(data,saveRef,itemId,target,battle,...)
        local policy=ItemEffects._kantoAscendantJohtoTrialPolicy
        if policy and policy.itemUseBlocked(nil,battle,saveRef) then
          return "failed",{policy.text()}, {johtoTrialItemsBlocked=true}
        end
        return originalUse(data,saveRef,itemId,target,battle,...)
      end
      ItemEffects._kantoAscendantJohtoTrialWrapped=true
    end
    ItemEffects._kantoAscendantJohtoTrialPolicy={
      itemUseBlocked=P.itemUseBlocked,text=itemBlockedText,
    }
  end
  local function blocks(def)
    if def.arenaBlocks then
      local out={};for i,value in ipairs(def.arenaBlocks) do out[i]=value end
      return out
    end
    if def.id=="KA_JOHTO_GATE_HALL" then
      -- Keep the historical extent for in-map saves, but expose only one
      -- compact 14x14-cell vestibule.  Everything outside it is real Radio
      -- Tower wall, not open carpet.  The three coloured all-floor plates sit
      -- directly below the three Masters; the cyan double plate in front of
      -- the south wall is the plainly visible EXIT portal.
      local out={};for i=1,def.w*def.h do out[i]=def.wall end
      local function put(x,y,v)
        if x>=1 and x<=def.w and y>=1 and y<=def.h then
          out[(y-1)*def.w+x]=v
        end
      end
      local left,right,top,bottom=2,8,6,12
      for y=top,bottom do for x=left,right do
        put(x,y,(x==left or x==right or y==top or y==bottom) and def.wall or 1)
      end end
      -- Silver / Kris / Gold gate plates, all collision-equivalent to floor.
      put(3,8,39);put(5,8,20);put(7,8,19)
      -- A short signal trace leads from the entry to the labelled exit.
      put(5,9,19);put(5,10,20);put(5,11,39)
      -- Rescue cell retained for saves made on the prototype lower-left edge.
      put(1,13,1)
      return out
    end
    if def.quizRoom then
      -- One bounded south chamber per Master.  Retaining the old map size/id
      -- protects in-progress saves; real wall fills the unused north field so
      -- it cannot read as another arena.  Every accent below shares the
      -- source floor's four-walkable-quarter collision profile.
      local spec=def.quizRoom
      local out={};for i=1,def.w*def.h do out[i]=spec.wall end
      local function put(x,y,v)
        if x>=1 and x<=def.w and y>=1 and y<=def.h then
          out[(y-1)*def.w+x]=v
        end
      end
      local left,right,top,bottom=2,8,20,27
      for y=top,bottom do for x=left,right do
        put(x,y,(x==left or x==right or y==top or y==bottom)
          and spec.wall or spec.floor)
      end end
      -- Character-coloured dais, sparse room motif, entry guide and a visible
      -- double-cell portal in the south wall.  Gold uses only $09/$28/$29,
      -- so none of the former repeated Tin Tower stair blocks survives.
      for x=3,7 do put(x,21,spec.accents[2]) end
      put(5,22,spec.accents[3])
      put(3,24,spec.accents[1]);put(7,24,spec.accents[1])
      put(5,23,spec.accents[1]);put(5,25,spec.accents[1])
      put(5,27,spec.accents[2])
      return out
    end
    if def.segments then
      -- Use real structural blocks for the authored room shell.  The old
      -- values were generic floor blocks (checker/ice/gold) and therefore
      -- made every unused cell look like an endless carpet.  These are
      -- source tileset-native collision walls, not a renderer mask.
      local roomWall=def.id:find("SILVER_PASSAGE",1,true) and 9
        or def.id:find("KRIS_PASSAGE",1,true) and 1
        or def.id:find("GOLD_PASSAGE",1,true) and 1 or def.wall
      local voidShell=def.id:find("SILVER_PASSAGE",1,true) and 1
        or def.id:find("KRIS_PASSAGE",1,true) and 3
        or def.id:find("GOLD_PASSAGE",1,true) and 9 or def.shell
      local out={};for i=1,def.w*def.h do out[i]=roomWall end
      -- Catalog block $01 is a walkable visual void in the Tower, while the
      -- Lab's $16 is a full-screen ice/checker fill.  The connector must use
      -- a real, characteristic floor per tileset instead of either generic
      -- fallback: underground tile $01, lab tile $18, tower tile $02.
      local routeFloor=def.id:find("KRIS_PASSAGE",1,true) and 3
        or def.id:find("GOLD_PASSAGE",1,true) and 2 or def.ground
      local function put(x,y,value)if x>=1 and x<=def.w and y>=1 and y<=def.h then out[(y-1)*def.w+x]=value end end
      local offset=1;local boundaries={};local spineX=def.entryX and math.floor(def.entryX/2) or 2
      for _,segment in ipairs(def.segments) do
        local pieces=segment.pieces or {{layout=segment.layout,x=segment.x,flip=segment.flip}}
        -- Camera-wide authoring: the Radio Tower and Ruins source rooms are
        -- 9/10 blocks wide, while the actual game camera needs a 27/30-block
        -- room. Repeat only the same verified native room architecture across
        -- that width so no renderer background or previous-map pixels leak
        -- into the passage edges.
        if def.entryX and (def.id:find("SILVER_PASSAGE",1,true) or def.id:find("KRIS_PASSAGE",1,true)) and #pieces==1 then
          local source=pieces[1].layout;local tiled={}
          for left=1,def.w,source.width do tiled[#tiled+1]={layout=source,x=left,flip=(#tiled%2)==1} end
          pieces=tiled
        end
        local segmentHeight=segment.height or 0
        for _,piece in ipairs(pieces) do
          local source=piece.layout;local left=piece.x or 1;segmentHeight=math.max(segmentHeight,source.height)
          for y=1,source.height do for x=1,source.width do
            local fromX=piece.flip and source.width-x+1 or x
            local value=source.blocks[(y-1)*source.width+fromX]
            -- The Crystal catalog uses block $01 as an unpainted interior
            -- void in these source maps (not block $00).  Keeping it raw
            -- renders a flat charcoal rectangle in both renderers; replace
            -- only that documented sentinel with this passage's native wall
            -- shell, preserving every authored non-void source block.
            local void=value==def.replaceVoid or (def.replaceVoid==0 and value==1)
            put(left+x-1,offset+y-1,void and voidShell or value)
          end end
        end
        boundaries[#boundaries+1]=offset+segmentHeight-1;offset=offset+segmentHeight
      end
      -- Two adjacent native-floor blocks are an intentional door between
      -- arrival → decision → gate, rather than a painted-in filler corridor.
      for index=1,#boundaries-1 do for _,boundary in ipairs({boundaries[index],boundaries[index]+1}) do
        put(math.floor(def.w/2),boundary,routeFloor);put(math.floor(def.w/2)+1,boundary,routeFloor)
      end end
      -- Every route is entered at the lower-left return stair.  Make that
      -- landing explicit even when the historical source room ends in a
      -- decorative wall block (notably Tin Tower's threshold).
      put(spineX,def.h-2,routeFloor);put(spineX,def.h-1,routeFloor)
      -- A collision-valid stair spine joins the three retained source rooms.
      -- It remains three cells wide in-game and opens into each room at both
      -- thresholds, so it is a readable traversal route rather than a hidden
      -- teleport or a one-tile visual corridor.
      for y=2,def.h-1 do put(spineX,y,routeFloor);put(spineX+1,y,routeFloor) end
      for x=spineX,spineX+2 do put(x,5,routeFloor);put(x,6,routeFloor) end
      -- Keep the legacy left-side start cell collision-valid for old saves
      -- and the map-graph regression fixture; normal entry uses entryX.
      if def.entryX then
        for y=2,def.h-1 do put(2,y,routeFloor);put(3,y,routeFloor) end
        for x=2,spineX+2 do put(x,5,routeFloor);put(x,6,routeFloor) end
      end
      -- Preserve the authored Gen-II room composition.  The recovery path
      -- above is the only overlay; it repairs connectivity without replacing
      -- a complete passage by a procedural carpet.
      if def.id:find("SILVER_PASSAGE",1,true) then
        -- Three real Radio Tower rooms carry their own consoles, shelves
        -- and stair landmarks.  Keep the lower return edge safe.
        for x=spineX,spineX+2 do put(x,def.h-2,1);put(x,def.h-1,1) end
      elseif def.id:find("KRIS_PASSAGE",1,true) then
        -- The Inner Chamber composition supplies the archive shelves and
        -- rune islands; keep one collision-safe return bridge at its edge.
        for x=spineX,spineX+2 do put(x,def.h-2,3);put(x,def.h-1,3) end
      end
      -- Visual zoning never changes the collision lattice.  Each replacement
      -- below has the *identical four-cell collision profile* in the checked
      -- in Gen-II catalog (asserted in the passage test); only the native
      -- metatile artwork changes.  This lets the stable input route gain
      -- readable rooms without another geometry/warp rewrite.
      if def.id:find("SILVER_PASSAGE",1,true) then
        -- Three small signal stations sit on existing all-floor cells only.
        -- $13/$14/$27/$2c are all collision-equivalent to Radio Tower $01;
        -- the v9 tileset uses them as cable, lamp, console and window-edge
        -- overlay art respectively.  The path and its collision mask remain
        -- completely unchanged.
        local function station(x,y,kind)
          local i=(y-1)*def.w+x
          if out[i]==1 then out[i]=kind end
        end
        local stations={{4,4,"gate"},{6,12,"relay"},{5,20,"terminal"}}
        for _,node in ipairs(stations) do
          local x,y=node[1],node[2]
          local kind=node[3]
          if kind=="terminal" then
            station(x,y,39);station(x+1,y,39);station(x,y-1,39);station(x+1,y-1,39)
            station(x+2,y,19)
          elseif kind=="relay" then
            station(x,y,20);station(x+1,y,20);station(x+2,y,20)
            station(x+1,y-1,39);station(x+1,y+1,19)
          else
            station(x,y,44);station(x+1,y,44);station(x,y-1,44);station(x+1,y-1,44)
            station(x+2,y,20)
          end
          for cable=x-1,x+3 do station(cable,y+1,19) end
          station(x+3,y+1,20)
        end
        -- A one-block-wide cyan service trace ties the three stations
        -- together.  It is chosen only from already all-floor source cells,
        -- keeps accent coverage below seven percent, and lets the eye read
        -- entry → relay → gate without treating the whole floor as a signal
        -- pattern.
        for y=2,def.h-2 do
          local chosen
          for distance=0,def.w do
            for _,x in ipairs({5-distance,5+distance}) do
              local i=(y-1)*def.w+x
              if x>=1 and x<=def.w and out[i]==1 then chosen=x;break end
            end
            if chosen then break end
          end
          if chosen then station(chosen,y,19) end
        end
      elseif def.id:find("KRIS_PASSAGE",1,true) then
        local zones={{1,8,{[10]=11,[18]=21,[19]=22,[27]=33,[31]=34}},
          {9,16,{[10]=11,[18]=29,[19]=30,[17]=32,[32]=35}},
          {17,def.h,{[10]=11,[18]=21,[19]=22,[27]=33,[31]=49}}}
        for _,zone in ipairs(zones) do
          for y=zone[1],zone[2] do for x=1,def.w do
            local i=(y-1)*def.w+x;out[i]=zone[3][out[i]] or out[i]
          end end
        end
        -- The archive-only $33 is a calm carved-stone floor.  It replaces
        -- only already all-floor $03 cells; rune slabs stay sparse islands.
        for i,value in ipairs(out) do if value==3 then out[i]=51 end end
        -- Three small research islands remain entirely walkable: $13 is an
        -- alternate fully-floor Ruins slab.  Their two-by-two silhouette is
        -- intentionally bounded by the existing native pillar/rune artwork,
        -- leaving all proven bridge cells untouched.
        -- Put the three reading islands inside the three camera-scale archive
        -- bays (rather than at the source-map seams), so arrival and decision
        -- views each communicate a bounded destination.
        local islandShapes={
          -- Upper circular table, middle L reading desk, lower double podium.
          {{2,8},{3,8},{2,9},{3,9}},
          {{2,14},{3,14},{2,15},{2,16}},
          {{2,23},{3,23},{2,24},{3,24}},
        }
        for _,shape in ipairs(islandShapes) do
          for _,point in ipairs(shape) do
            local x,y=point[1],point[2]
            local i=(y-1)*def.w+x
            if out[i]==51 then out[i]=13 end
          end
        end
        -- One lectern/stele per sequence point, all on the same four-floor
        -- collision profile as the surrounding archive island.
        for _,point in ipairs({{2,10},{3,15},{2,25}}) do
          local x,y=point[1],point[2];local i=(y-1)*def.w+x
          if out[i]==51 then out[i]=3 end
        end
      end
      return out
    end
    if def.layout then
      local out,source= {},def.layout
      for y=1,source.height do for section=1,def.sections or 1 do
        for x=1,source.width do out[#out+1]=source.blocks[(y-1)*source.width+x] end
      end end
      if def.entryFloor then out[(def.h-2)*def.w+2]=def.ground;out[(def.h-1)*def.w+2]=def.ground end
      return out
    end
    -- Native CAVERN block language, deliberately different per Master:
    -- SILVER's cut-stone switchback, KRIS's bright crystal survey and GOLD's
    -- older ceremonial mosaic.  All chosen ground blocks retain CAVERN's
    -- real walkability; the darker blocks remain collision walls.
    local style={floor=def.ground or 1,wall=def.wall or 27,trim=def.trim}
    local out={};local function edge(x,y)return x==1 or x==def.w or y==1 or y==def.h end
    for y=1,def.h do for x=1,def.w do out[#out+1]=edge(x,y) and style.wall or style.floor end end
    local function put(x,y,kind)if x>1 and x<def.w and y>1 and y<def.h then out[(y-1)*def.w+x]=kind or style.wall end end
    if def.id:find("SILVER_PASSAGE",1,true) then for y=2,def.h-1 do if y~=4 and y~=5 and y~=11 then put(8,y) end;if y~=8 and y~=9 then put(15,y) end end
    elseif def.id:find("KRIS_PASSAGE",1,true) then for x=3,def.w-2 do if x~=5 and x~=6 then put(x,5) end;if x~=13 and x~=14 then put(x,11) end end
    elseif def.id:find("GOLD_PASSAGE",1,true) then for y=3,def.h-2 do if y~=7 and y~=8 then put(10,y) end;if y~=12 and y~=13 then put(18,y) end end;for x=11,17 do if x~=14 then put(x,9) end end
    elseif def.id:find("HALL",1,true) then for y=3,def.h-2 do if y~=6 and y~=7 then put(9,y) end end
    elseif def.id:find("FINALE",1,true) then for x=5,def.w-4 do if x%3~=0 then put(x,4) end end end
    -- Room-specific visual landmarks which also break the former tunnel
    -- silhouette without opening an invalid collision route.
    if def.id:find("SILVER_PASSAGE",1,true) then
      for x=3,6 do put(x,3,style.trim) end;for x=17,20 do put(x,13,style.trim) end
    elseif def.id:find("KRIS_PASSAGE",1,true) then
      for _,p in ipairs({{4,3},{16,3},{4,15},{16,15},{10,8}}) do put(p[1],p[2],style.trim) end
    elseif def.id:find("GOLD_PASSAGE",1,true) then
      for x=4,def.w-3,3 do put(x,4,style.trim);put(x,def.h-3,style.trim) end
    end
    out[(def.h-2)*def.w+1]=style.floor
    return out
  end
  local function object(index,name,text,x,sprite,y)return {index=index,name=name,sprite=assert(sprite,"Johto passage object needs a real sprite"),x=x or 21,y=y or 9,movement="STAY",range="DOWN",text=text}end
  local function map(def,objects,signs)
    local label=def.label or {def.id,def.id}
    -- Location banners are one line in the native UI.  These short, fully
    -- localized destination names never truncate mid-word in 2D or Voxel.
    local short={
      KA_JOHTO_GATE_HALL={"MASTERS' GATE","MEISTER-TOR"},
      KA_JOHTO_SILVER_PASSAGE={"SILVER SIGNAL","SILVER-SIGNAL"},
      KA_JOHTO_SILVER_FINALE={"SILVER GATE","SILVER-TOR"},
      KA_JOHTO_KRIS_PASSAGE={"KRIS ARCHIVE","KRIS-ARCHIV"},
      KA_JOHTO_KRIS_FINALE={"KRIS RUNES","KRIS-RUNEN"},
      KA_JOHTO_GOLD_PASSAGE={"GOLD TOWER","GOLD-TURM"},
      KA_JOHTO_GOLD_FINALE={"GOLD SUMMIT","GOLD-GIPFEL"},
    }
    label=short[def.id] or label
    return {id=def.id,index=def.index,label=tr(label[1],label[2]),tileset=def.tileset,palette=def.palette or "CAVE",width=def.w,height=def.h,borderBlock=def.wall,blocks=blocks(def),voxelMode="MAP_STUDIO",voxelRevision=2,outdoor=false,voxelSemanticOverrides={},connections={},signs=signs or {},warps=def.returnWarps or {{x=1,y=def.h*2-3,destMap="LAST_MAP",destWarp=1}},objects=objects}
  end
  box=function(game,text,done)game.stack:push(require("src.render.TextBox").new(game,text,done))end
  local questionUi=opts.questionUi or mod.exports and mod.exports.ascendantUi
  local function openList(game,title,rows,menuOpts)
    if type(opts.openMenu)=="function" then return opts.openMenu(game,title,rows,menuOpts) end
    local ui=mod.ui and (mod.ui.KantoListMenu or mod.ui.ListMenu)
    assert(ui and ui.new,"Johto quiz list UI missing")
    local menu=ui.new(game,title,rows,menuOpts)
    game.stack:push(menu);return menu
  end
  P.QUIZ_SECONDS=20
  function P.armQuizMenu(game,menu,spec)
    assert(questionUi and type(questionUi.armQuestionMenu)=="function",
      "Johto quiz question UI missing")
    spec=assert(spec,"Johto quiz menu spec missing")
    return questionUi.armQuestionMenu(game,menu,{
      title=spec.title,prompt=spec.prompt,seconds=P.QUIZ_SECONDS,
      onTimeout=spec.onTimeout,legacyJohto=true,cancelDisabled=true,
    })
  end
  local function failureText(reason)
    local detail=reason=="timeout" and tr(
      "The 20 seconds expired.","Die 20 Sekunden sind abgelaufen.")
      or reason=="cancel" and tr(
        "The answer was abandoned.","Die Antwort wurde abgebrochen.")
      or tr("The answer was wrong.","Die Antwort war falsch.")
    return tr("NOT WORTHY","NICHT WÜRDIG").."\f"..detail.."\f"..tr(
      "All three Johto trials reset. Return from Indigo Plateau and begin with Silver.",
      "Alle drei Johto-Prüfungen wurden zurückgesetzt. Kehre vom Indigo-Plateau zurück und beginne bei Silver.")
  end
  function P.rejectToIndigo(game,key,reason,alreadyReset)
    if not alreadyReset then P.resetChallenge(game,reason,key) end
    local function warp()
      P.suppressNextExitReset=true
      return mod.world and mod.world:warpTo(
        "INDIGO_PLATEAU_LOBBY",7,10,"up") or false
    end
    if game and game.stack then box(game,failureText(reason),warp)
    else warp() end
    return true
  end
  function P.startBattle(game,ow,npc,key)
    if baseline.eligible and not baseline.eligible(game) then return false,"locked" end
    local s=state();local p=s.passages[key];local r=R[key]
    if not s.activeRun or not (p.status=="entered" or p.status=="cleared") or not p.puzzle then return false,"puzzle" end
    p.attempts=p.attempts+1;save(s,game);npc.frozen=true
    local b=postgame.newForcedBattle(game,r.class,baseline.teamFor(key,p.attempts),"johto_passage",{source="johto_passage:"..key})
    local authored=baseline.trainerFor and baseline.trainerFor(key)
    local function localized(value)return type(value)=="table" and tr(value.en,value.de) or value end
    b.johtoPassage=true;b.postgameTier=nil;b.postgameForcedTier=nil;b.ascendantNoItems=true;b.noPrizeMoney=true;b.rematch=p.status=="cleared";b.enemyAIMods={1,2,3}
    -- Each Master always brings their own Johto starter as the automatic
    -- transformation target. Gold's separate Ascendant form is an explicit
    -- story battle contract, never a global opponent fallback.
    b.ascendantEnemyMegaSpecies=baseline.megaTargetFor and baseline.megaTargetFor(key) or nil
    b.ascendantEnemySecretForm=baseline.secretFormFor and baseline.secretFormFor(key) or nil
    b.trainer=setmetatable({id=r.class,name=authored and localized(authored.name) or r.name,class=r.class,baseMoney=0},{__index=b.trainer});b.introText=authored and localized(authored.intro) or nil;b.endBattleText=authored and localized(authored.win) or nil
    b.onFinish=function(result)
      npc.frozen=false
      if result~="win" then
        -- A passage defeat is a fair retry checkpoint, not an ordinary
        -- blackout to the overworld heal point.  Keep the entered/puzzle
        -- state intact, restore the actual party, then use the regular Gate
        -- Hall warp after the loss text.  This is deliberately local to the
        -- Johto passage battle context; no global blackout rule is changed.
        local Pokemon=require("src.pokemon.Pokemon")
        for _,mon in ipairs(game.save.party or {}) do Pokemon.heal(mon) end
        box(game,tr("The passage remembers your defeat. Return when ready.","Der Pfad erinnert sich deiner Niederlage. Komm bereit zurück."),function()P.enterHall(game)end)
        return
      end
      ow:afterBattle(result,b)
      -- Each completed passage is a checkpoint.  The original three-master
      -- trial restored the party between rounds; keeping that contract here
      -- means a player who wins on their final conscious Pokémon can enter
      -- the newly opened next passage without an unrelated heal detour.
      local Pokemon=require("src.pokemon.Pokemon")
      for _,mon in ipairs(game.save.party or {}) do Pokemon.heal(mon) end
      local returnHall=function()P.enterHall(game,key=="gold")end
      if key=="gold" then
        -- The run serial is the exact-once reward authority.  Commit it before
        -- the cosmetic passage receipt: a crash between the two writes may
        -- leave Gold's local seal stale, but can never strand an active 0/0
        -- run or pay the same shiny twice on resume.
        local message=baseline.completeRun(game)
        p.status="cleared";p.puzzle=false;p.rewarded=true;save(s,game);P.sync(game)
        box(game,message,returnHall)
      else
        p.status="cleared";p.puzzle=false;p.rewarded=true;save(s,game);P.sync(game)
        box(game,tr(r.name.." yields the seal. The next passage opens.",r.name.." übergibt das Siegel. Der nächste Pfad öffnet."),returnHall)
      end
    end;ow:pushBattle(b);return true
  end
  local function gate(key)return function(game)
    if not P.canEnter(game,key) then
      box(game,tr(R[key].name.." PORTAL — SEALED. Defeat the previous Johto Master first.",
        R[key].name.."-PORTAL — VERSIEGELT. Besiege zuerst den vorigen Johto-Meister."));return
    end
    box(game,tr(R[key].name.." PORTAL — OPEN. Enter the trial?",
      R[key].name.."-PORTAL — OFFEN. Prüfung betreten?"),function()P.enter(game,key)end)
  end end
  local QUIZ_COPY={
    silver={
      intro=bi(
        "SILVER'S SIGNAL TEST: Answer three questions about Johto and Silver's path. You have 20 seconds per answer. A mistake resets all three trials.",
        "SILVERS SIGNALPRÜFUNG: Beantworte drei Fragen über Johto und Silvers Weg. Du hast je 20 Sekunden. Ein Fehler setzt alle drei Prüfungen zurück."),
      title=bi("SILVER SIGNAL","SILVER-SIGNAL"),
    },
    kris={
      intro=bi(
        "KRIS'S RESEARCH TEST: Solve three questions about Johto's discoveries. You have 20 seconds per answer. A mistake resets all three trials.",
        "KRISS FORSCHUNGSPRÜFUNG: Löse drei Fragen über Johtos Entdeckungen. Du hast je 20 Sekunden. Ein Fehler setzt alle drei Prüfungen zurück."),
      title=bi("KRIS RESEARCH","KRIS-FORSCHUNG"),
    },
    gold={
      intro=bi(
        "GOLD'S CHAMPION TEST: Answer three questions about Johto's legends. You have 20 seconds per answer. A mistake resets all three trials.",
        "GOLDS CHAMPIONPRÜFUNG: Beantworte drei Fragen über Johtos Legenden. Du hast je 20 Sekunden. Ein Fehler setzt alle drei Prüfungen zurück."),
      title=bi("GOLD CHAMPION","GOLD-CHAMPION"),
    },
  }
  local function quizTalk(key)
    local function present(game)
      local s=state();local p=s and s.passages[key]
      if p and p.puzzle then
        box(game,tr("TEST 3/3 — COMPLETE. The battle portal is open.",
          "PRÜFUNG 3/3 — BESTANDEN. Das Kampfportal ist offen."),function()P.solve(game,key)end)
        return
      end
      local station=(p and p.step or 0)+1
      local question,reason=P.question(game,key,station)
      if not question then
        box(game,reason=="locked" and tr("This trial is still sealed.","Diese Prüfung ist noch versiegelt.")
          or tr("The next research station is not ready.","Die nächste Prüfstation ist noch nicht bereit."));return
      end
      box(game,tr("QUESTION ","FRAGE ")..station.."/3\n"..question.prompt,function()
        local rows={}
        for index,label in ipairs(question.choices) do rows[#rows+1]={label=label,value=index} end
        local menu=openList(game,tr(QUIZ_COPY[key].title.en,QUIZ_COPY[key].title.de).." "..station.."/3",rows,{
          pageJump=false,ascendantLayout=false,
          onChoose=function(item,menu)
            if not item then return end
            if menu then menu.johtoResolved=true end
            if menu and menu.close then menu:close() end
            local ok,result,progress,correct=P.answer(game,key,station,question.id,item.value)
            if ok and result=="complete" then
              box(game,tr("Correct. Progress: 3/3. The battle portal opens.",
                "Richtig. Fortschritt: 3/3. Das Kampfportal öffnet sich."),function()P.solve(game,key)end)
            elseif ok then
              box(game,tr("Correct. Progress: ","Richtig. Fortschritt: ")..progress.."/3.",function()present(game)end)
            else
              P.rejectToIndigo(game,key,"wrong_answer",true)
            end
          end,
        })
        P.armQuizMenu(game,menu,{
          title=tr("JOHTO TEST ","JOHTO-TEST ")..station.."/3",
          prompt=question.prompt,
          onTimeout=function()
            P.rejectToIndigo(game,key,"timeout",false)
          end,
        })
      end)
    end
    return function(game)
      if not P.canEnter(game,key) then
        box(game,tr("This trial is still sealed.","Diese Prüfung ist noch versiegelt."));return
      end
      local s=state();local first=not s.passages[key].clue
      if first then P.inspect(game,key) end
      if first then
        box(game,tr(QUIZ_COPY[key].intro.en,QUIZ_COPY[key].intro.de),function()present(game)end)
      else present(game) end
    end
  end
  function P.register()
    if P.registered then return false,"registered" end
    if not P.contentEnabled then P.registered=true;return false,"content disabled" end
    tileBridge.register()
    local root=mod.path.."/assets/johto_masters/"
    for key,r in pairs(R) do mod.content.sprites:register(r.sprite,{id=r.sprite,image=root.."field/"..key.."_walk.png",frames=6,walker=true,trueColor=true}) end
    for key,r in pairs(R) do local party={};for _,slot in ipairs(baseline.teamFor(key,1)) do party[#party+1]={species=slot.species,level=slot.level} end;local authored=baseline.trainerFor and baseline.trainerFor(key);local trainerName=authored and (type(authored.name)=="table" and tr(authored.name.en,authored.name.de) or authored.name) or r.name;local front=key=="gold" and "gold_front_color_v1.png" or key.."_front.png";mod.content.trainers:register(r.class,{id=r.class,name=trainerName,pic=root.."battle/"..front,trueColor=true,baseMoney=0,battleTheme=assert(music.battleTheme,"Johto Rival battle theme missing"),parties={party}}) end
    mod.content.maps:register(P.MAPS.HALL.id,map(P.MAPS.HALL,{
      -- Keep the historical map extent for existing saves, but stage the
      -- three visible gates inside the compact central chamber used by new
      -- entries.  The old y=9 row sat outside the entrance viewport and made
      -- the Hall feel empty and much larger than its actual gameplay space.
      object(1,"KA_JOHTO_GATE_SILVER","TEXT_KA_JOHTO_GATE_SILVER",5,R.silver.sprite,15),
      object(2,"KA_JOHTO_GATE_KRIS","TEXT_KA_JOHTO_GATE_KRIS",9,R.kris.sprite,15),
      object(3,"KA_JOHTO_GATE_GOLD","TEXT_KA_JOHTO_GATE_GOLD",13,R.gold.sprite,15),
    },{{x=10,y=22,text="TEXT_KA_JOHTO_HALL_EXIT"}}))
    local talk={
      TEXT_KA_JOHTO_GATE_SILVER=gate("silver"),
      TEXT_KA_JOHTO_GATE_KRIS=gate("kris"),
      TEXT_KA_JOHTO_GATE_GOLD=gate("gold"),
      TEXT_KA_JOHTO_HALL_EXIT=function(game)box(game,tr(
        "EXIT — INDIGO PLATEAU. Step onto the glowing double plate.",
        "AUSGANG — INDIGO-PLATEAU. Betritt die leuchtende Doppelplatte."))end,
    }
    for key,r in pairs(R) do
      local u=key:upper();local routeKey=key
      local finale=P.MAPS[r.finale]
      local boss={assert(finale.bossX,"Johto arena boss x missing"),assert(finale.bossY,"Johto arena boss y missing")}
      mod.content.maps:register(P.MAPS[r.passage].id,map(P.MAPS[r.passage],{
        object(1,"KA_JOHTO_"..u.."_QUIZ_HOST","TEXT_KA_JOHTO_"..u.."_QUIZ",9,r.sprite,42),
      },{{x=10,y=P.MAPS[r.passage].h*2-2,text="TEXT_KA_JOHTO_"..u.."_EXIT"}}))
      local master=object(1,"KA_JOHTO_"..u.."_MASTER",
        "TEXT_KA_JOHTO_"..u.."_MASTER",boss[1],r.sprite,boss[2])
      -- Do not register a second trainer-shaped "seal" object. The FULL
      -- renderer does not honour the 2D-only renderMode marker consistently,
      -- which made every Master appear twice in the arena.
      mod.content.maps:register(P.MAPS[r.finale].id,
        map(P.MAPS[r.finale],{master}))
      talk["TEXT_KA_JOHTO_"..u.."_QUIZ"]=quizTalk(routeKey)
      talk["TEXT_KA_JOHTO_"..u.."_EXIT"]=function(game)box(game,tr(
        "EXIT — GATE HALL. Step onto the glowing double plate.",
        "AUSGANG — TORHALLE. Betritt die leuchtende Doppelplatte."))end
      talk["TEXT_KA_JOHTO_"..u.."_MASTER"]=function(game,ow,npc)P.startBattle(game,ow,npc,routeKey)end
    end
    for _,def in pairs(P.MAPS) do
      local contribution={priority=2900,talk=talk}
      if def.id==P.MAPS.HALL.id then
        contribution.onStep=function(game,_,x,y)
          local central=(x==8 or x==9) and y>=21
          local oldSaveRescue=x<=1 and y>=P.MAPS.HALL.h*2-3
          if not (central or oldSaveRescue) then return false end
          -- The custom Hall floor has no native door collision byte, so an
          -- interior map-warp record alone never fires. Use the supported
          -- world warp on the exact exit cells and land one cell above the
          -- Indigo lobby's south threshold.
          P.leaveChallenge(game,"area_exit")
          P.suppressNextExitReset=true
          return mod.world and mod.world:warpTo(
            "INDIGO_PLATEAU_LOBBY",7,10,"up") or false
        end
      elseif def.quizRoom then
        contribution.onStep=function(_,_,x,y)
          if not ((x==8 or x==9) and y>=def.h*2-2) then return false end
          return mod.world and mod.world:warpTo(
            P.MAPS.HALL.id,P.MAPS.HALL.entryX,P.MAPS.HALL.entryY,"up") or false
        end
      end
      mod.content.map_scripts:register(def.id,contribution)
    end
    P.registered=true;return true
  end
  if mod.events and type(mod.events.on)=="function" then
    mod.events:on("map.entered",function(ev)
      local game=ev and ev.game or P.game
      local toMapId=ev and (ev.mapId or ev.map and ev.map.id)
      local fromMapId=ev and (ev.fromMapId or ev.previousMapId)
        or P.currentMapId
      if toMapId then P.onMapTransition(game,fromMapId,toMapId) end
    end)
  end
  function P.install(game)
    P.game=game
    local ow=mod.world and mod.world.overworld and mod.world:overworld()
    P.currentMapId=ow and ow.map and ow.map.id or P.currentMapId
    installItemGuard()
    if P.contentEnabled then P.sync(game) end
  end
  P.state=state;P.routes=R;return P
end
