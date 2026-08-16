-- Package B-RED.  This is a standalone dungeon graph; it neither imports nor
-- aliases any of the older Nexus/Stone/Frost/Air maps.
return function(mod, opts)
  opts=opts or {}
  local M={}
  local voxelRenderer=opts.voxelRenderer
  local questionUi=opts.questionUi
  M.COMMON_ANTECHAMBER=opts.commonAntechamberId or "KA_HIDDEN_EVOLUTION_COMMON_ANTECHAMBER"
  M.IDS={upper="KA_HEVO_RED_UPPER",abyss="KA_HEVO_RED_ABYSS",recovery="KA_HEVO_RED_RECOVERY",lower="KA_HEVO_RED_LOWER",shrine="KA_HEVO_RED_SHRINE"}
  M.END_WARP={x=39,y=5}
  M.UNLOCKS={"RHYPERIOR","MAGMORTAR","LICKILICKY","MAMOSWINE","GLISCOR"}
  M.MEGA_STONE="BLAZIKENITE"
  -- RED deliberately stays on the shipped Gen-I CAVERN atlas.  Apart from
  -- looking like an authored Kanto dungeon this also means flat rendering,
  -- native collision/holes and DRAMALESS all consume the same source data.
  -- Block ids below are ROM CAVERN metatiles, never private wallpaper tiles.
  local W,H=24,18
  local V,F,R,WARP,WATER=3,25,125,124,118
  -- CAVERN tile $22 is the native hole.  These four blocks place it in the
  -- requested collision-cell quadrant (TL/TR/BL/BR respectively).
  local HOLE_TL,HOLE_TR,HOLE_BL,HOLE_BR=119,120,104,105
  -- Fully walkable native accents.  They are placed by hand as landmarks;
  -- broad procedural floor-noise was the reason the rejected map read as a
  -- repeating carpet.
  local EMBER,DAIS,BRIDGE=21,108,91
  -- Native CAVERN block 29 exposes only its upper collision row (tile $05),
  -- while block 43 is the matching down-to-east corner.  Together they make
  -- a genuine one-cell ledge without custom tiles or voxel geometry.
  local NARROW_EAST,NARROW_EAST_JOIN=29,43
  -- CAVERN's real Surf boundary uses collision tile $20.  Blocks 60 and 39
  -- provide the canonical $05 -> $18 -> $20 shore transition; a plain floor
  -- ($05) touching water is deliberately blocked by Gen-I elevation rules.
  local FLOOR_TO_SHORE,SHORE_STEP=60,39
  -- Block 40 supplies the native $18 -> $20 elevation transition used by a
  -- recessed abyss statue.  Without that intermediate step, CAVERN correctly
  -- rejects a direct $05 -> $20 climb even though both cells look open.
  local BASALT_STEP=40
  -- Collision masks of shipped CAVERN blocks, expressed as TL/TR/BL/BR
  -- walk cells.  The RED maps are authored on the original 16 px movement
  -- grid and compiled back to these blocks.  That gives us actual one-cell
  -- passages in both renderers instead of drawing a narrow-looking wall over
  -- a two-cell collision carpet.
  local PATH_BLOCK={
    [0]=R,   [1]=53, [2]=52, [3]=29,
    [4]=66,  [5]=22, [6]=F,  [7]=44,
    [8]=64,  [9]=F,  [10]=23,[11]=43,
    [12]=57,[13]=F, [14]=F, [15]=F,
  }
  local WALK_MASK={
    [3]=0,[21]=15,[22]=5,[23]=10,[25]=15,[29]=3,[39]=15,[40]=15,
    [43]=11,[44]=7,[52]=2,[53]=1,[57]=12,[60]=15,[64]=8,[66]=4,[91]=15,
    [104]=15,[105]=15,[118]=0,[119]=15,[120]=15,[124]=15,[125]=0,
  }
  M.TILESET="CAVERN"
  M.LOWER_SHORE_TILE=32
  local SIGHT_PROFILE={
    -- Sight 0 is intentionally almost total blackness: only the player's
    -- immediate cell and the next taught landmark are readable.  The first
    -- two answers widen that core conservatively, so RED remains a genuine
    -- orientation trial instead of becoming a normal lit cave after one
    -- statue.  Later stages grow more generously to reward mastery.
    -- Keep the world outside the aperture completely opaque, but do not
    -- tint the aperture itself so heavily that it disappears on the native
    -- CAVERN palette.  The keyhole must be readable before the first answer;
    -- the puzzle restricts *area*, not the player's ability to identify the
    -- one cell and forward beam which remain visible.
    [0]={radius=1.9,opacity=1.0,innerOpacity=0.32},
    [1]={radius=2.75,opacity=1.0,innerOpacity=0.28},
    [2]={radius=3.8,opacity=1.0,innerOpacity=0.24},
    [3]={radius=5.2,opacity=1.0,innerOpacity=0.20},
    [4]={radius=7.1,opacity=1.0,innerOpacity=0.16},
    [5]={radius=9.5,opacity=0.90,innerOpacity=0.12},
  }
  function M.sightProfile(level,completed)
    if completed then
      return {
        radius=14.0,opacity=0.22,innerOpacity=0.10,
        coreRadius=1.05,coneSlope=0.48,featherPx=2.0,
      }
    end
    level=math.max(0,math.min(5,tonumber(level) or 0))
    local row=SIGHT_PROFILE[level]
    return {
      radius=row.radius,opacity=row.opacity,innerOpacity=row.innerOpacity,
      -- A small omni-directional core keeps the player readable.  Everything
      -- beyond it is a facing-aware tunnel beam, not a circular tint.
      coreRadius=0.85,coneSlope=0.34,featherPx=2.0,
    }
  end
  function M.activeSightProfile(save,mapId,level,completed)
    if type(M.floorSightProfile)=="function" then
      local floorProfile=M.floorSightProfile(save,mapId)
      if floorProfile then return floorProfile end
    end
    return M.sightProfile(level,completed)
  end
  -- Window-resolution post-composite mask.  The visible core and tunnel beam
  -- have a uniform interior and a fully black exterior.  Only the final two
  -- physical screen pixels are analytically antialiased; a broad alpha band
  -- would expose native CAVERN stipple as an apparent aura around actors.
  local SIGHT_SHADER=[[
    extern vec2 sightCenter;
    extern vec2 sightFacing;
    extern number sightRadius;
    extern number sightCoreRadius;
    extern number sightConeSlope;
    extern number sightInnerOpacity;
    extern number sightOpacity;
    extern number sightFeatherPx;
    vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
      vec2 delta=screen-sightCenter;
      vec2 facing=normalize(sightFacing);
      number distanceFromPlayer=length(delta);
      number forward=dot(delta,facing);
      number lateral=abs(dot(delta,vec2(-facing.y,facing.x)));

      number coreSigned=distanceFromPlayer-sightCoreRadius*1.80;
      number coneWidth=sightCoreRadius*0.62
        + max(forward,0.0)*sightConeSlope;
      number coneSigned=max(lateral-coneWidth,
        max(-forward,forward-sightRadius));
      number apertureSigned=min(coreSigned,coneSigned);
      number edge=smoothstep(-min(sightFeatherPx,2.0),0.0,
        apertureSigned);
      number darkness=mix(sightInnerOpacity,sightOpacity,edge);
      return vec4(0.0,0.0,0.0,darkness);
    }
  ]]
  M.sightShaderSource=SIGHT_SHADER
  local text={
    TEXT_KA_RED_STATUE_1={"The first basalt memory is still dark.","Die erste Basalterinnerung liegt noch im Dunkeln."},
    TEXT_KA_RED_STATUE_2={"The second basalt memory is still dark.","Die zweite Basalterinnerung liegt noch im Dunkeln."},
    TEXT_KA_RED_STATUE_3={"The third basalt memory is still dark.","Die dritte Basalterinnerung liegt noch im Dunkeln."},
    TEXT_KA_RED_STATUE_4={"The fourth basalt memory is still dark.","Die vierte Basalterinnerung liegt noch im Dunkeln."},
    TEXT_KA_RED_STATUE_5={"The fifth basalt memory is still dark.","Die fünfte Basalterinnerung liegt noch im Dunkeln."},
    TEXT_KA_RED_GROUDON={"Black stone drinks the light. A deep GROUDON roar answers beyond it.","Schwarzer Stein trinkt das Licht. Dahinter antwortet ein tiefes GROUDON-Brüllen."},
    TEXT_KA_RED_COMPLETE={"Five red memories join. The chamber remains black.","Fünf rote Erinnerungen verbinden sich. Die Kammer bleibt schwarz."},
    TEXT_KA_RED_EMBER_HINT={"Three fallen stones point below. Follow the ember rune, not the ladder.","Drei gefallene Steine weisen hinab. Folge der Glutrune, nicht der Leiter."},
    TEXT_KA_RED_BLAZIKENITE={"A warm stone answers the red seal. You found BLAZIKENITE!","Ein warmer Stein antwortet dem roten Siegel. Du findest LOHGOCKNIT!"},
    TEXT_KA_RED_BLAZIKENITE_EMPTY={"The ember-shaped hollow is empty.","Die glutförmige Mulde ist leer."},
    TEXT_KA_RED_RESET={"RESET RUNE: return to the last refuge? This resets loose boulders, never lit statues.","RESET-RUNE: Zur letzten Zuflucht zurück? Lose Felsen werden zurückgesetzt, erleuchtete Statuen nie."},
    TEXT_KA_RED_RETREAT={"The return mark leads back to the threshold. Your lit statues remain.","Das Rückkehrzeichen führt zur Schwelle. Erleuchtete Statuen bleiben erhalten."},
    TEXT_KA_RED_WRONG={"The answer fades. The statue offers a different memory.","Die Antwort verblasst. Die Statue bietet eine andere Erinnerung an."},
    TEXT_KA_RED_RIGHT={"Correct. The basalt records this memory.","Richtig. Der Basalt bewahrt diese Erinnerung."},
    TEXT_KA_RED_LIT={"This statue is already lit. Its question will not return this journey.","Diese Statue leuchtet bereits. Ihre Frage kehrt in dieser Reise nicht zurück."},
    TEXT_KA_RED_STRENGTH={"Three basalt weights must reach their sockets. STRENGTH moves them; the reset rune restores mistakes.","Drei Basaltgewichte müssen ihre Fassungen erreichen. STÄRKE bewegt sie; die Reset-Rune behebt Fehler."},
    TEXT_KA_RED_FALLEN={"A basalt weight rests firmly in its socket. Its ember-line points deeper.","Ein Basaltgewicht ruht fest in seiner Fassung. Seine Glutlinie weist tiefer."},
    TEXT_KA_RED_SURF={"The lower fault is flooded. SURF crosses the black current; FLASH cannot wake this stone.","Die untere Spalte ist geflutet. SURFER quert die schwarze Strömung; BLITZ weckt diesen Stein nicht."},
    TEXT_KA_RED_FALL={"The cracked rim is a real drop. A fall reaches the ember refuge; its ladders always lead back.","Der rissige Rand ist ein echter Sturz. Unten liegt die Glut-Zuflucht; ihre Leitern führen immer zurück."},
    TEXT_KA_RED_GATE={"The shrine rejects an unfinished pattern: five statues, three weights.","Der Schrein weist ein unvollständiges Muster ab: fünf Statuen, drei Gewichte."},
    TEXT_KA_RED_AFTER={"Something waits beyond this door... a new adventure.","Etwas wartet hinter dieser Tür ... ein neues Abenteuer."},
  }
  -- Fifty authored Kanto/Johto facts produce one true and one plausible false
  -- statement each.  The resulting 100-question pool is RED-only, run-local
  -- and deterministic; a wrong answer consumes the question but never resets
  -- an already lit statue.
  local facts={
    {"PIKACHU","ELECTRIC","WATER","PIKACHU","ELEKTRO","WASSER"},{"CHARIZARD","FIRE","WATER","GLURAK","FEUER","WASSER"},
    {"BLASTOISE","WATER","FIRE","TURTOK","WASSER","FEUER"},{"VENUSAUR","GRASS","ICE","BISAFLOR","PFLANZE","EIS"},
    {"GENGAR","GHOST","FIGHTING","GENGAR","GEIST","KAMPF"},{"ONIX","ROCK","WATER","ONIX","GESTEIN","WASSER"},
    {"ESPEON","PSYCHIC","DARK","PSIANA","PSYCHO","UNLICHT"},{"UMBREON","DARK","PSYCHIC","NACHTARA","UNLICHT","PSYCHO"},
    {"SCIZOR","BUG","FIRE","SCHEROX","KAEFER","FEUER"},{"PILOSWINE","ICE","ELECTRIC","KEIFEL","EIS","ELEKTRO"},
  }
  local places={
    {"PALLET TOWN","KANTO","JOHTO","ALABASTIA","KANTO","JOHTO"},{"PEWTER CITY","KANTO","JOHTO","MARMORIA CITY","KANTO","JOHTO"},
    {"CERULEAN CITY","KANTO","JOHTO","AZURIA CITY","KANTO","JOHTO"},{"CELADON CITY","KANTO","JOHTO","PRISMANIA CITY","KANTO","JOHTO"},
    {"VIOLET CITY","JOHTO","KANTO","VIOLA CITY","JOHTO","KANTO"},{"AZALEA TOWN","JOHTO","KANTO","AZALEA CITY","JOHTO","KANTO"},
    {"GOLDENROD CITY","JOHTO","KANTO","DUKATIA CITY","JOHTO","KANTO"},{"ECRUTEAK CITY","JOHTO","KANTO","TEAK CITY","JOHTO","KANTO"},
    {"OLIVINE CITY","JOHTO","KANTO","OLIVIANA CITY","JOHTO","KANTO"},{"BLACKTHORN CITY","JOHTO","KANTO","EBENHOLZ CITY","JOHTO","KANTO"},
  }
  local leaders={
    {"BROCK","PEWTER","CERULEAN","ROCKO","MARMORIA","AZURIA"},{"MISTY","CERULEAN","CELADON","MISTY","AZURIA","PRISMANIA"},
    {"LT. SURGE","VERMILION","FUCHSIA","MAJOR BOB","ORANIA","FUCHSANIA"},{"ERIKA","CELADON","SAFFRON","ERIKA","PRISMANIA","SAFFRONIA"},
    {"KOGA","FUCHSIA","PEWTER","KOGA","FUCHSANIA","MARMORIA"},{"FALKNER","VIOLET","AZALEA","FALK","VIOLA","AZALEA"},
    {"BUGSY","AZALEA","GOLDENROD","KAI","AZALEA","DUKATIA"},{"WHITNEY","GOLDENROD","ECRUTEAK","BIANKA","DUKATIA","TEAK"},
    {"MORTY","ECRUTEAK","OLIVINE","JENS","TEAK","OLIVIANA"},{"CLAIR","BLACKTHORN","MAHOGANY","SANDRA","EBENHOLZ","MAHAGONIA"},
  }
  local evolutions={
    {"BULBASAUR","IVYSAUR","CHARMELEON","BISASAM","BISAKNOSP","GLUTEXO"},{"CHARMANDER","CHARMELEON","WARTORTLE","GLUMANDA","GLUTEXO","SCHILLOK"},
    {"SQUIRTLE","WARTORTLE","IVYSAUR","SCHIGGY","SCHILLOK","BISAKNOSP"},{"PICHU","PIKACHU","RAICHU","PICHU","PIKACHU","RAICHU"},
    {"CLEFFA","CLEFAIRY","CLEFABLE","PII","PIEPPI","PIXI"},{"IGGLYBUFF","JIGGLYPUFF","WIGGLYTUFF","FLUFFELUFF","PUMMELUFF","KNUDDELUFF"},
    {"TOGEPI","TOGETIC","TOGEKISS","TOGEPI","TOGETIC","TOGEKISS"},{"ONIX","STEELIX","GOLEM","ONIX","STAHLLOS","GEOWAZ"},
    {"SCYTHER","SCIZOR","PINSIR","SICHLOR","SCHEROX","PINSIR"},{"EEVEE","ESPEON","UMBREON","EVOLI","PSIANA","NACHTARA"},
  }
  local landmarks={
    {"TIN TOWER","ECRUTEAK","GOLDENROD","ZINNTURM","TEAK","DUKATIA"},{"BURNED TOWER","ECRUTEAK","OLIVINE","TURMRUINE","TEAK","OLIVIANA"},
    {"RADIO TOWER","GOLDENROD","VIOLET","RADIOTURM","DUKATIA","VIOLA"},{"LAKE OF RAGE","JOHTO","KANTO","SEE DES ZORNS","JOHTO","KANTO"},
    {"SILPH CO.","SAFFRON","CELADON","SILPH CO.","SAFFRONIA","PRISMANIA"},{"POKEMON TOWER","LAVENDER","FUCHSIA","POKEMON-TURM","LAVANDIA","FUCHSANIA"},
    {"SAFARI ZONE","FUCHSIA","VERMILION","SAFARI-ZONE","FUCHSANIA","ORANIA"},{"SPROUT TOWER","VIOLET","AZALEA","KNOFENSA-TURM","VIOLA","AZALEA"},
    {"LIGHTHOUSE","OLIVINE","MAHOGANY","LEUCHTTURM","OLIVIANA","MAHAGONIA"},{"DRAGON'S DEN","BLACKTHORN","ECRUTEAK","DRACHENHOEHLE","EBENHOLZ","TEAK"},
  }
  M.questions={}
  local function addQuestion(en,de,answer)
    local id=string.format("KA_RED_Q_%03d",#M.questions+1)
    M.questions[#M.questions+1]={id=id,en=en,de=de,answer=answer,
      category="LEGACY",legacy=true}
  end
  for _,r in ipairs(facts) do
    addQuestion("Is "..r[1].." a "..r[2].."-type Pokemon?","Ist "..r[4].." ein "..r[5].."-Pokemon?",true)
    addQuestion("Is "..r[1].." a "..r[3].."-type Pokemon?","Ist "..r[4].." ein "..r[6].."-Pokemon?",false)
  end
  for _,r in ipairs(places) do
    addQuestion("Is "..r[1].." in "..r[2].."?","Liegt "..r[4].." in "..r[5].."?",true)
    addQuestion("Is "..r[1].." in "..r[3].."?","Liegt "..r[4].." in "..r[6].."?",false)
  end
  for _,r in ipairs(leaders) do
    addQuestion("Does "..r[1].." lead the "..r[2].." Gym?","Leitet "..r[4].." die Arena von "..r[5].."?",true)
    addQuestion("Does "..r[1].." lead the "..r[3].." Gym?","Leitet "..r[4].." die Arena von "..r[6].."?",false)
  end
  for _,r in ipairs(evolutions) do
    addQuestion("Does "..r[1].." evolve into "..r[2].."?","Entwickelt sich "..r[4].." zu "..r[5].."?",true)
    addQuestion("Does "..r[1].." evolve into "..r[3].."?","Entwickelt sich "..r[4].." zu "..r[6].."?",false)
  end
  for _,r in ipairs(landmarks) do
    addQuestion("Is "..r[1].." tied to "..r[2].."?","Gehoert "..r[4].." zu "..r[5].."?",true)
    addQuestion("Is "..r[1].." tied to "..r[3].."?","Gehoert "..r[4].." zu "..r[6].."?",false)
  end
  -- The first 100 IDs above shipped before the multi-region catalogue.  Never
  -- insert into or reinterpret that prefix: pending questions in an RC save
  -- point at those exact IDs.  New records use semantic IDs and an explicit
  -- category, with five true and five false statements per category.
  assert(#M.questions==100,"RED legacy question prefix changed")
  M.LEGACY_QUESTION_COUNT=100
  local newQuestions={
    {"KA_RED_X_KANTO_001","KANTO","Is PIKACHU National Dex #025?","Ist PIKACHU im Nationaldex Nr. 025?",true},
    {"KA_RED_X_KANTO_002","KANTO","Is BULBASAUR National Dex #001?","Ist BULBASAUR im Nationaldex Nr. 001?",true},
    {"KA_RED_X_KANTO_003","KANTO","Does MISTY lead the CERULEAN Gym?","Leitet MISTY die Arena von CERULEAN?",true},
    {"KA_RED_X_KANTO_004","KANTO","Is PALLET TOWN in KANTO?","Liegt PALLET TOWN in KANTO?",true},
    {"KA_RED_X_KANTO_005","KANTO","Is ARTICUNO one of Kanto's legendary birds?","Ist ARTICUNO einer von Kantos legendaeren Voegeln?",true},
    {"KA_RED_X_KANTO_006","KANTO","Is CHARMANDER a WATER-type Pokemon?","Ist CHARMANDER ein WASSER-Pokemon?",false},
    {"KA_RED_X_KANTO_007","KANTO","Does BROCK lead the CERULEAN Gym?","Leitet BROCK die Arena von CERULEAN?",false},
    {"KA_RED_X_KANTO_008","KANTO","Is LAVENDER TOWN in JOHTO?","Liegt LAVENDER TOWN in JOHTO?",false},
    {"KA_RED_X_KANTO_009","KANTO","Is MEWTWO National Dex #151?","Ist MEWTWO im Nationaldex Nr. 151?",false},
    {"KA_RED_X_KANTO_010","KANTO","Does SQUIRTLE evolve into CHARMELEON?","Entwickelt sich SQUIRTLE zu CHARMELEON?",false},

    {"KA_RED_X_JOHTO_001","JOHTO","Is CHIKORITA National Dex #152?","Ist CHIKORITA im Nationaldex Nr. 152?",true},
    {"KA_RED_X_JOHTO_002","JOHTO","Is CYNDAQUIL a FIRE-type Pokemon?","Ist CYNDAQUIL ein FEUER-Pokemon?",true},
    {"KA_RED_X_JOHTO_003","JOHTO","Is TOTODILE a WATER-type Pokemon?","Ist TOTODILE ein WASSER-Pokemon?",true},
    {"KA_RED_X_JOHTO_004","JOHTO","Does FALKNER lead the VIOLET Gym?","Leitet FALKNER die Arena von VIOLET?",true},
    {"KA_RED_X_JOHTO_005","JOHTO","Is the BURNED TOWER in ECRUTEAK?","Steht der BURNED TOWER in ECRUTEAK?",true},
    {"KA_RED_X_JOHTO_006","JOHTO","Does LUGIA rest in TIN TOWER?","Ruht LUGIA im TIN TOWER?",false},
    {"KA_RED_X_JOHTO_007","JOHTO","Does WHITNEY lead the AZALEA Gym?","Leitet WHITNEY die Arena von AZALEA?",false},
    {"KA_RED_X_JOHTO_008","JOHTO","Is MAREEP a GRASS-type Pokemon?","Ist MAREEP ein PFLANZEN-Pokemon?",false},
    {"KA_RED_X_JOHTO_009","JOHTO","Is HO-OH a WATER-type Pokemon?","Ist HO-OH ein WASSER-Pokemon?",false},
    {"KA_RED_X_JOHTO_010","JOHTO","Is BLACKTHORN CITY in KANTO?","Liegt BLACKTHORN CITY in KANTO?",false},

    {"KA_RED_X_GENERAL_001","GENERAL","Are FIRE moves effective against GRASS Pokemon?","Sind FEUER-Attacken effektiv gegen PFLANZEN-Pokemon?",true},
    {"KA_RED_X_GENERAL_002","GENERAL","Are WATER moves effective against FIRE Pokemon?","Sind WASSER-Attacken effektiv gegen FEUER-Pokemon?",true},
    {"KA_RED_X_GENERAL_003","GENERAL","Are GROUND Pokemon immune to ELECTRIC moves?","Sind BODEN-Pokemon immun gegen ELEKTRO-Attacken?",true},
    {"KA_RED_X_GENERAL_004","GENERAL","Can a full party contain six Pokemon?","Kann ein volles Team sechs Pokemon enthalten?",true},
    {"KA_RED_X_GENERAL_005","GENERAL","Are POKE BALLS used to catch Pokemon?","Werden POKE BALLS zum Fangen von Pokemon benutzt?",true},
    {"KA_RED_X_GENERAL_006","GENERAL","Are GRASS moves effective against FIRE Pokemon?","Sind PFLANZEN-Attacken effektiv gegen FEUER-Pokemon?",false},
    {"KA_RED_X_GENERAL_007","GENERAL","Does a POTION revive a fainted Pokemon?","Belebt ein TRANK ein besiegtes Pokemon wieder?",false},
    {"KA_RED_X_GENERAL_008","GENERAL","Does every Pokemon have exactly one type?","Hat jedes Pokemon genau einen Typ?",false},
    {"KA_RED_X_GENERAL_009","GENERAL","Does a critical hit always miss?","Geht ein Volltreffer immer daneben?",false},
    {"KA_RED_X_GENERAL_010","GENERAL","Can a fainted Pokemon battle normally without healing?","Kann ein besiegtes Pokemon ohne Heilung normal kaempfen?",false},

    {"KA_RED_X_SINNOH_001","SINNOH","Is TURTWIG Sinnoh's GRASS starter?","Ist TURTWIG Sinnohs PFLANZEN-Starter?",true},
    {"KA_RED_X_SINNOH_002","SINNOH","Is CHIMCHAR Sinnoh's FIRE starter?","Ist CHIMCHAR Sinnohs FEUER-Starter?",true},
    {"KA_RED_X_SINNOH_003","SINNOH","Is PIPLUP Sinnoh's WATER starter?","Ist PIPLUP Sinnohs WASSER-Starter?",true},
    {"KA_RED_X_SINNOH_004","SINNOH","Does ROARK lead the OREBURGH Gym?","Leitet ROARK die Arena von OREBURGH?",true},
    {"KA_RED_X_SINNOH_005","SINNOH","Is DIALGA associated with time?","Ist DIALGA mit der Zeit verbunden?",true},
    {"KA_RED_X_SINNOH_006","SINNOH","Does GARDENIA lead the SUNYSHORE Gym?","Leitet GARDENIA die Arena von SUNYSHORE?",false},
    {"KA_RED_X_SINNOH_007","SINNOH","Is PALKIA a pure FIRE-type Pokemon?","Ist PALKIA ein reines FEUER-Pokemon?",false},
    {"KA_RED_X_SINNOH_008","SINNOH","Is TWINLEAF TOWN in KANTO?","Liegt TWINLEAF TOWN in KANTO?",false},
    {"KA_RED_X_SINNOH_009","SINNOH","Is UXIE a JOHTO starter Pokemon?","Ist UXIE ein JOHTO-Starter?",false},
    {"KA_RED_X_SINNOH_010","SINNOH","Does VOLKNER lead the ETERNA Gym?","Leitet VOLKNER die Arena von ETERNA?",false},
  }
  for _,q in ipairs(newQuestions) do
    M.questions[#M.questions+1]={id=q[1],category=q[2],en=q[3],de=q[4],answer=q[5]}
  end
  assert(#M.questions==140,"RED expanded catalogue needs 140 questions")
  local order={KA_RED_STATUE_1=1,KA_RED_STATUE_2=2,KA_RED_STATUE_3=3,KA_RED_STATUE_4=4,KA_RED_STATUE_5=5}
  local function tr(pair) return opts.i18n and opts.i18n.text and opts.i18n.text(pair[1],pair[2]) or pair[1] end
  -- WorldAPI:toggleObject reloads the active map.  Calling it unconditionally
  -- from map.entered therefore re-enters the same handler forever.  Keep the
  -- public API (and its renderer refresh), but only when persistence actually
  -- changes.  This also makes reward/secret removal safe on the live floor.
  local function setObjectVisible(game,mapId,name,visible)
    local save=game and game.save
    if not save then return false,"save" end
    save.objectToggles=save.objectToggles or {}
    save.objectToggles[mapId]=save.objectToggles[mapId] or {}
    local wanted=visible and true or false
    if save.objectToggles[mapId][name]==wanted then return false,"unchanged" end
    if mod.world and mod.world.toggleObject then
      return mod.world:toggleObject(mapId,name,wanted)
    end
    save.objectToggles[mapId][name]=wanted
    return true
  end
  local function room(fill)
    -- Start with real rock, then cut narrow authored corridors from it.
    -- Explicit V cells are reserved for readable fissures inside a room.
    local a={}; for i=1,W*H do a[i]=fill or R end
    local function put(x,y,b)
      assert(x>=0 and y>=0 and x<W and y<H,"RED block outside map")
      a[x+y*W+1]=b or F
    end
    for x=0,W-1 do put(x,0,R);put(x,H-1,R) end
    for y=0,H-1 do put(0,y,R);put(W-1,y,R) end
    return a,put
  end
  local function cellRoom()
    local open={}
    local function key(x,y) return x..","..y end
    local function carve(x,y)
      assert(x>0 and y>0 and x<W*2-1 and y<H*2-1,
        "RED path cell outside the authored interior")
      open[key(x,y)]=true
    end
    local function line(x1,y1,x2,y2)
      assert(x1==x2 or y1==y2,"RED path segments must be orthogonal")
      local dx=x2==x1 and 0 or (x2>x1 and 1 or -1)
      local dy=y2==y1 and 0 or (y2>y1 and 1 or -1)
      local x,y=x1,y1
      while true do
        carve(x,y)
        if x==x2 and y==y2 then break end
        x,y=x+dx,y+dy
      end
    end
    local function route(points)
      for i=1,#points-1 do
        line(points[i][1],points[i][2],points[i+1][1],points[i+1][2])
      end
    end
    local function bay(cx,cy,rx,ry)
      rx,ry=rx or 1,ry or 1
      for y=cy-ry,cy+ry do for x=cx-rx,cx+rx do carve(x,y) end end
    end
    local function cross(cx,cy)
      carve(cx,cy);carve(cx-1,cy);carve(cx+1,cy)
      carve(cx,cy-1);carve(cx,cy+1)
    end
    local function compile()
      local blocks={}
      for by=0,H-1 do
        for bx=0,W-1 do
          local mask=0
          if open[key(bx*2,by*2)] then mask=mask+1 end
          if open[key(bx*2+1,by*2)] then mask=mask+2 end
          if open[key(bx*2,by*2+1)] then mask=mask+4 end
          if open[key(bx*2+1,by*2+1)] then mask=mask+8 end
          blocks[by*W+bx+1]=assert(PATH_BLOCK[mask],
            "RED has no native CAVERN block for path mask "..mask)
        end
      end
      return blocks
    end
    return {carve=carve,line=line,route=route,bay=bay,cross=cross,
      compile=compile,open=open}
  end
  local function writer(a)
    return function(x,y,b)
      assert(x>=0 and y>=0 and x<W and y<H,"RED block outside map")
      a[x+y*W+1]=b or F
    end
  end
  local function accent(a,p,x,y,b)
    local index=x+y*W+1
    if a[index]==F then p(x,y,b or EMBER) end
  end
  local function rect(p,x1,y1,x2,y2,b)
    for y=y1,y2 do for x=x1,x2 do p(x,y,b or F) end end
  end
  local function cells(p,list,b) for _,q in ipairs(list) do p(q[1],q[2],b or q[3]) end end
  local function pad(p,x,y)
    assert(x%2==1 and y%2==1,"RED warp pads use the lower-right CAVERN cell")
    p(math.floor(x/2),math.floor(y/2),WARP)
  end
  local function hole(p,x,y)
    local bx,by=math.floor(x/2),math.floor(y/2)
    local block=(x%2==0 and y%2==0) and HOLE_TL
      or (x%2==1 and y%2==0) and HOLE_TR
      or (x%2==0 and y%2==1) and HOLE_BL or HOLE_BR
    p(bx,by,block)
  end
  local labels={
    [M.IDS.upper]={"BASALT APPROACH","BASALT-PFAD"},[M.IDS.abyss]={"BASALT ABYSS","BASALT-ABGRUND"},
    [M.IDS.recovery]={"EMBER REFUGE","GLUT-ZUFLUCHT"},[M.IDS.lower]={"BASALT DEPTHS","BASALT-TIEFE"},
    [M.IDS.shrine]={"GROUDON SHRINE","GROUDON-SCHREIN"},
  }
  local function def(id,index,blocks,warps,objects)
    return {id=id,index=index,label=tr(labels[id] or {"BASALT CAVERN","BASALT-HÖHLE"}),tileset=M.TILESET,
      voxelMode="FULL",voxelRevision=4,
      outdoor=false,width=W,height=H,blocks=blocks,borderBlock=R,warps=warps,objects=objects or {},signs={},connections={}}
  end
  local named,byId={},{}
  do
    local c=cellRoom()
    -- The three Strength lanes stay on the exact proven coordinates.  Their
    -- connectors now double back through thin basalt fissures instead of
    -- occupying one broad diagonal carpet.
    c.route({{3,33},{11,33},{11,31},{7,31},{7,29},{19,29},
      {19,27},{21,27},{21,19},{23,19},{23,23},{29,23},
      {29,19},{30,19},{30,17},{37,17},{37,23},{43,23},
      {43,15},{39,15},{39,9},{45,9},{45,3}})
    -- Optional, telegraphed fall pockets never occupy the only corridor.
    c.route({{23,23},{17,23},{17,21},{11,21},{11,22},{12,22}})
    c.route({{29,21},{25,21},{25,18},{26,18}})
    c.route({{39,15},{35,15},{35,12},{36,12}})
    -- Both memory statues are deliberately available before STRENGTH.  This
    -- narrow survey loop passes north of A and east of B without crossing a
    -- live object cell; the boulders still retain their exact teaching lanes.
    c.route({{9,31},{9,27},{19,27},{23,27},{23,21},{26,21}})
    -- The memories themselves are not road signs.  Each sits at the blind
    -- end of a long, turning side fault: the player must deliberately leave
    -- the survey loop, remember the last junction and then retrace it.  The
    -- old near-path pockets remain as honest decoys rather than solver marks.
    c.route({{9,27},{9,26},{5,26},{5,22},{9,22},{9,18},
      {5,18},{5,14},{13,14},{13,10},{3,10},{3,6}})
    c.route({{23,19},{23,14},{29,14},{29,10},{25,10},
      {25,6},{35,6},{35,2},{29,2},{29,4}})
    -- Solved sockets use native $20/$22 cells.  The bypasses let the player
    -- leave each teaching lane after its boulder disappears without crossing
    -- the intentionally blocked $05/$20 elevation seam.
    c.route({{17,29},{17,27},{19,27}})
    c.route({{21,21},{23,21},{23,19}})
    c.route({{35,17},{35,19},{37,19},{37,23}})
    -- Two small reconnecting routes create genuine decisions without
    -- bypassing a boulder or shortening the intended progression.
    c.route({{23,23},{23,26},{27,26},{27,23}})
    c.route({{39,15},{39,19},{43,19},{43,15}})
    -- The first floor light is no longer handed out beside the entry stair.
    -- This blind fault leaves the first real junction and ends in untouched
    -- basalt, so reaching the relic requires an honest out-and-back detour.
    c.route({{11,33},{16,33}})
    c.route({{39,12},{44,12}})
    -- Floor light UPPER #2 is a tangible relic at (20,18).  This single
    -- dead-rock carve enlarges its existing side pocket to four reachable
    -- free neighbors without joining another route or bypassing a boulder.
    c.carve(19,19)
    c.bay(5,33,1,1)
    for _,q in ipairs({{11,31},{7,29},{27,21},{25,23}}) do
      c.cross(q[1],q[2])
    end
    local a=c.compile();local p=writer(a)
    hole(p,12,22);hole(p,26,18);hole(p,36,12)
    hole(p,19,29);hole(p,21,19);hole(p,37,17)
    -- Keep the tablet on the bottom-row ledge; its optional upper approach
    -- had merged two nearby turns into a ten-cell-wide raster strip.
    p(13,10,57);p(12,11,57)
    pad(p,3,33);pad(p,45,3)
    -- Transparent talk anchors are never pixel hunts: the native stone dais
    -- at the Strength lesson and ember rune at RESET communicate the exact
    -- interactive block without creating a second statue sprite.
    p(5,15,DAIS);p(2,16,EMBER)
    accent(a,p,3,16);accent(a,p,13,10);accent(a,p,20,9)
    named.upper=def(M.IDS.upper,1930,a,{
      {x=3,y=33,destMap=M.COMMON_ANTECHAMBER,destWarp=1},
      {x=45,y=3,destMap=M.IDS.abyss,destWarp=1},
      {x=12,y=22,destMap=M.IDS.recovery,destWarp=3},
      {x=26,y=18,destMap=M.IDS.recovery,destWarp=4},
      {x=36,y=12,destMap=M.IDS.recovery,destWarp=5},
    },{
      {index=1,name="KA_RED_BOULDER_A",sprite="SPRITE_BOULDER",x=13,y=29,pushable=true,movement="STAY",range="NONE",text="TEXT_KA_RED_STRENGTH"},
      {index=2,name="KA_RED_BOULDER_B",sprite="SPRITE_BOULDER",x=21,y=25,pushable=true,movement="STAY",range="NONE",text="TEXT_KA_RED_STRENGTH"},
      {index=3,name="KA_RED_BOULDER_C",sprite="SPRITE_BOULDER",x=31,y=17,pushable=true,movement="STAY",range="NONE",text="TEXT_KA_RED_STRENGTH"},
      {index=4,name="KA_RED_STATUE_1",sprite="SPRITE_KA_HEVO_QUIZ_STATUE",semanticRole="quiz_statue",x=3,y=6,movement="STAY",range="NONE",text="TEXT_KA_RED_STATUE_1"},
      {index=5,name="KA_RED_STATUE_2",sprite="SPRITE_KA_HEVO_QUIZ_STATUE",semanticRole="quiz_statue",x=29,y=4,movement="STAY",range="NONE",text="TEXT_KA_RED_STATUE_2"},
      {index=6,name="KA_RED_STRENGTH_TABLET",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=false,x=11,y=31,movement="STAY",range="NONE",text="TEXT_KA_RED_STRENGTH"},
      {index=7,name="KA_RED_FALL_TABLET",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=false,x=25,y=23,movement="STAY",range="NONE",text="TEXT_KA_RED_FALL"},
      {index=8,name="KA_RED_RESET_UPPER",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=true,x=5,y=33,movement="STAY",range="NONE",text="TEXT_KA_RED_RESET"},
    })
  end
  do
    local c=cellRoom()
    -- A switchback rim forces orientation by landmarks rather than a single
    -- visible north-east diagonal.  Two equal-length loops let players skirt
    -- danger while every fall remains an optional, recoverable choice.
    c.route({{3,33},{15,33},{15,27},{7,27},{7,21},{21,21},
      {21,25},{25,25},{25,17},{33,17},{33,21},{41,21},
      {41,13},{35,13},{35,7},{41,7},{41,3},{45,3}})
    c.route({{21,21},{25,21},{25,25}})
    c.route({{33,17},{41,17},{41,21}})
    c.route({{21,23},{15,23}})
    -- The fourth statue is carved into the same native block as its fall.
    -- Reach its upper face through a real $18 basalt step from the east.
    c.route({{29,17},{31,17},{31,13},{30,13}})
    c.route({{7,27},{7,24},{10,24}})
    c.route({{21,21},{21,19},{17,19},{17,20},{18,20}})
    c.route({{35,13},{35,11},{37,11},{37,10},{38,10}})
    -- Two independent memory faults leave the traversal rim at real
    -- junctions and wind into dead rock.  Their cul-de-sacs are long enough
    -- that the solution cannot be read from the main route or one camera
    -- pan; returning to the rim is part of the orientation test.
    c.route({{7,21},{7,16},{13,16},{13,12},{7,12},
      {7,8},{17,8},{17,4},{11,4}})
    c.route({{35,7},{35,2},{29,2},{29,6},{23,6},{23,10},{27,10}})
    -- These three light faults each have one mouth on the traversal rim and
    -- consume otherwise closed west, centre and upper basalt.  None joins a
    -- fall, memory fault or alternate rim segment.
    c.route({{15,27},{20,27}})
    c.route({{25,19},{30,19}})
    c.route({{35,7},{30,7}})
    -- A 6.5.2 save may resume on either upper cell of the retired stair
    -- block.  Keep that exact bay as ordinary floor connected to the old
    -- approach; only the new stair at (41,5) remains a warp graphic.
    c.line(44,2,45,2)
    for _,q in ipairs({{5,31},{15,23},{37,11}}) do
      c.bay(q[1],q[2],1,1)
    end
    local a=c.compile();local p=writer(a)
    local falls={{10,24},{18,20},{28,14},{38,10}}
    for _,q in ipairs(falls) do hole(p,q[1],q[2]) end
    p(14,6,BASALT_STEP)
    pad(p,3,33);pad(p,41,5)
    p(2,15,EMBER)
    accent(a,p,3,16);accent(a,p,7,11);accent(a,p,18,5)
    named.abyss=def(M.IDS.abyss,1931,a,{
      {x=3,y=33,destMap=M.IDS.upper,destWarp=2},{x=41,y=5,destMap=M.IDS.lower,destWarp=1},
      {x=10,y=24,destMap=M.IDS.recovery,destWarp=3},{x=18,y=20,destMap=M.IDS.recovery,destWarp=4},
      {x=28,y=14,destMap=M.IDS.recovery,destWarp=5},{x=38,y=10,destMap=M.IDS.recovery,destWarp=6},
    },{
      {index=1,name="KA_RED_STATUE_3",sprite="SPRITE_KA_HEVO_QUIZ_STATUE",semanticRole="quiz_statue",x=11,y=4,movement="STAY",range="NONE",text="TEXT_KA_RED_STATUE_3"},
      {index=2,name="KA_RED_STATUE_4",sprite="SPRITE_KA_HEVO_QUIZ_STATUE",semanticRole="quiz_statue",x=27,y=10,movement="STAY",range="NONE",text="TEXT_KA_RED_STATUE_4"},
      {index=3,name="KA_RED_EMBER_HINT",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=true,x=37,y=11,movement="STAY",range="NONE",text="TEXT_KA_RED_EMBER_HINT"},
      {index=4,name="KA_RED_RESET_ABYSS",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=true,x=5,y=31,movement="STAY",range="NONE",text="TEXT_KA_RED_RESET"},
    })
  end
  do -- Every deliberate fall lands in a broad, recoverable refuge.
    local c=cellRoom()
    -- Four compact landing bays connect through one-cell refuge crevices.
    -- The Mega stone sits beyond a hinted spur with a symmetric decoy, so it
    -- is discoverable without looking like a reward pasted onto the route.
    c.route({{3,33},{13,33},{13,29},{7,29},{7,25},{21,25},
      {21,29},{27,29},{27,19},{35,19},{35,23},{41,23},
      {41,13},{35,13},{35,7},{45,7},{45,3}})
    c.route({{7,25},{7,21},{21,21},{21,25}})
    c.route({{35,19},{41,19},{41,23}})
    c.route({{11,27},{11,25}})
    c.route({{19,23},{19,25}})
    c.route({{29,17},{29,19}})
    c.route({{37,13},{41,13}})
    c.route({{27,19},{27,15},{27,9},{33,9}})
    c.route({{27,9},{21,9}})
    -- Preserve the complete walkable part of the former (45,3) ladder block
    -- as a warpfree refuge for saves made before the exit moved downward.
    c.line(44,2,45,2);c.carve(44,3)
    for _,q in ipairs({{5,31},{11,27},{19,23},{29,17},{37,13},
        {27,15},{33,9},{21,9}}) do c.bay(q[1],q[2],1,1) end
    local a=c.compile();local p=writer(a)
    pad(p,3,33);pad(p,45,5)
    -- Four real ladder/rune pads receive the authored falls and provide the
    -- player's physical recovery route; map-def warps without a warp tile
    -- are inert in the shipped engine.
    pad(p,11,27);pad(p,19,23);pad(p,29,17);pad(p,37,13)
    p(2,15,EMBER)
    accent(a,p,3,16);accent(a,p,13,7);accent(a,p,16,4)
    named.recovery=def(M.IDS.recovery,1932,a,{
      {x=3,y=33,destMap=M.IDS.abyss,destWarp=1},{x=45,y=5,destMap=M.IDS.lower,destWarp=1},
      {x=11,y=27,destMap=M.IDS.abyss,destWarp=3},{x=19,y=23,destMap=M.IDS.abyss,destWarp=4},
      {x=29,y=17,destMap=M.IDS.abyss,destWarp=5},{x=37,y=13,destMap=M.IDS.abyss,destWarp=6},
    },{
      {index=1,name="KA_RED_BLAZIKENITE_SECRET",sprite="SPRITE_POKE_BALL",x=33,y=9,movement="STAY",range="NONE",text="TEXT_KA_RED_BLAZIKENITE"},
      {index=2,name="KA_RED_SECRET_HINT",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=true,x=27,y=15,movement="STAY",range="NONE",text="TEXT_KA_RED_EMBER_HINT"},
      {index=3,name="KA_RED_RESET_REFUGE",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=true,x=5,y=31,movement="STAY",range="NONE",text="TEXT_KA_RED_RESET"},
    })
  end
  do
    local c=cellRoom()
    -- The banks are real one-cell switchbacks; the proven native shoreline
    -- and straight emergency Surf lane remain byte-for-byte at their exact
    -- coordinates.  Small islands give safe turns without becoming halls.
    c.route({{3,33},{11,33},{11,29},{5,29},{5,25},{13,25},
      {13,31},{17,31},{17,25}})
    c.route({{13,25},{13,24}})
    c.route({{5,29},{5,31}})
    c.route({{11,33},{16,33}})
    c.route({{31,15},{31,11},{41,11},{41,15},
      {45,15},{45,9},{39,9},{39,5},{43,5},{43,7},{45,7},{45,3}})
    c.route({{35,11},{35,15},{37,15}})
    c.route({{35,13},{39,13},{41,13}})
    -- Statue five is a genuine optional expedition off the far Surf bank,
    -- not a marker on the exit road.  Its switchbacks consume the unused
    -- dry basalt above the lake and end in a single approach cell; returning
    -- from it still leaves the remainder of LOWER plus the whole ceremonial
    -- SHRINE before the sealed chamber.
    c.route({{31,11},{31,10},{27,10},{27,6},{21,6},{21,2},
      {13,2},{13,6},{19,6},{19,12},{11,12},{11,6},{5,6}})
    -- LOWER uses three single-mouth light faults across its two banks.  They
    -- sit outside the Surf shore and the long Statue-five expedition, and
    -- each ends in unused basalt.
    c.route({{31,15},{26,15}})
    c.route({{39,9},{34,9}})
    -- Retired-exit compatibility: these were dry cells in 6.5.2.  They form
    -- two tiny dead ends off the current switchback instead of loading an old
    -- save inside rock; neither dead end owns a ladder or warp.
    c.line(44,2,45,2);c.carve(44,3);c.carve(42,6)
    for _,q in ipairs({{5,31},{11,25},{37,15},{39,13}}) do
      c.cross(q[1],q[2])
    end
    local a=c.compile();local p=writer(a)
    rect(p,5,8,19,11,WATER)
    p(7,9,F);p(8,9,F);p(11,9,F);p(12,9,F)
    -- A one-cell basalt ledge now reaches an actual southern shoreline.
    -- Previously x=30,y=22 was already water, so the nominal Surf route was
    -- impossible from normal input even though a water-inclusive BFS passed.
    p(8,12,NARROW_EAST_JOIN)
    for x=9,13 do p(x,12,NARROW_EAST) end
    -- Southern shore: step down through $18, then onto the $20 ledge at
    -- (31,24).  Northern shore mirrors it at (31,17) and reconnects through
    -- the small dry switchback above, so landing can never strand the player.
    p(14,12,FLOOR_TO_SHORE);p(15,12,SHORE_STEP)
    p(15,8,SHORE_STEP);p(15,7,FLOOR_TO_SHORE);p(16,7,F)
    pad(p,3,33);pad(p,39,7)
    p(2,15,EMBER)
    accent(a,p,3,16);accent(a,p,12,9);accent(a,p,19,6)
    named.lower=def(M.IDS.lower,1933,a,{
      {x=3,y=33,destMap=M.IDS.abyss,destWarp=2},{x=39,y=7,destMap=M.IDS.shrine,destWarp=1},
    },{
      {index=1,name="KA_RED_FALLEN_A",sprite="SPRITE_BOULDER",x=11,y=25,hidden=true,movement="STAY",range="NONE",text="TEXT_KA_RED_FALLEN"},
      {index=2,name="KA_RED_FALLEN_B",sprite="SPRITE_BOULDER",x=25,y=19,hidden=true,movement="STAY",range="NONE",text="TEXT_KA_RED_FALLEN"},
      {index=3,name="KA_RED_FALLEN_C",sprite="SPRITE_BOULDER",x=37,y=15,hidden=true,movement="STAY",range="NONE",text="TEXT_KA_RED_FALLEN"},
      {index=4,name="KA_RED_STATUE_5",sprite="SPRITE_KA_HEVO_QUIZ_STATUE",semanticRole="quiz_statue",x=5,y=6,movement="STAY",range="NONE",text="TEXT_KA_RED_STATUE_5"},
      {index=5,name="KA_RED_SURF_TABLET",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=false,x=13,y=23,movement="STAY",range="NONE",text="TEXT_KA_RED_SURF"},
      {index=6,name="KA_RED_RESET_LOWER",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=true,x=5,y=31,movement="STAY",range="NONE",text="TEXT_KA_RED_RESET"},
    })
    -- $20 is a walkable native CAVERN ledge.  On this map alone it is also
    -- the explicit shore between the shipped $14 water and dry $05 floor.
    named.lower.shoreTiles={32}
  end
  do
    local c=cellRoom()
    -- A true one-cell ceremonial spiral doubles back before a two-way loop
    -- around the central fault.  Small relic bays punctuate the path without
    -- reopening the rejected screen-wide floor.
    c.route({{3,33},{15,33},{15,29},{9,29},{9,25},{17,25},
      {17,29},{25,29},{25,23},{21,23},{21,21},{21,13},
      {29,13},{31,13},{31,7},{31,3},{39,3},{39,7},{45,7},{45,3}})
    c.route({{21,21},{29,21},{29,13}})
    c.route({{31,13},{35,13},{35,11},{39,11},{39,7}})
    -- The old top-right stair block remains a plain connected bay so a
    -- pre-upgrade save beside (45,3) can always walk back to the spiral.
    c.line(44,2,45,2);c.carve(44,3)
    for _,q in ipairs({{7,29},{31,13},{35,11}}) do
      c.bay(q[1],q[2],1,1)
    end
    local a=c.compile();local p=writer(a)
    rect(p,11,8,13,9,V); cells(p,{{12,9}},BRIDGE)
    pad(p,3,33);pad(p,39,5)
    -- The seal is read from a native carved dais; the retreat command from
    -- an ember rune.  Both remain visible world geometry in flat and Voxel
    -- while their metadata anchors stay transparent/passable.
    p(17,5,DAIS);p(3,14,EMBER)
    accent(a,p,3,16);accent(a,p,15,6);accent(a,p,19,3)
    named.shrine=def(M.IDS.shrine,1934,a,{
      {x=3,y=33,destMap=M.IDS.lower,destWarp=2},
      {x=39,y=5,destMap="KA_HEVO_SHARED_SEALED_ANTECHAMBER",destWarp=1},
    },{
      {index=1,name="KA_RED_RESEARCH_CACHE",sprite="SPRITE_POKE_BALL",x=31,y=13,movement="STAY",range="NONE",text="TEXT_KA_RED_COMPLETE"},
      {index=2,name="KA_RED_GROUDON_SEAL",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=false,x=35,y=11,movement="STAY",range="NONE",text="TEXT_KA_RED_GROUDON"},
      {index=3,name="KA_RED_RETREAT_MARK",sprite="SPRITE_KA_HEVO_FISSURE_ANCHOR",renderMode="none",passable=true,x=7,y=29,movement="STAY",range="NONE",text="TEXT_KA_RED_RETREAT"},
    })
  end
  for _,d in pairs(named) do byId[d.id]=d end; M.layouts=named;M.byId=byId
  -- Stock 0.1.86 only reads shoreTiles from the tileset record.  LOWER must
  -- remain an exact native CAVERN map, so cloning or globally patching that
  -- tileset would change elevation/field-move authority for unrelated caves.
  -- Instead, teach only the live LOWER Map instance that native tile $20 is
  -- its local Surf shore.  Newer engines already consume def.shoreTiles;
  -- this idempotent seam therefore behaves identically on both runtimes.
  function M.applyRuntimeShore(map)
    if not (map and map.id==M.IDS.lower) then return false,"map" end
    if not (map.def and map.def.tileset==M.TILESET
        and map.tileset and map.tileset.id==M.TILESET) then
      return false,"tileset"
    end
    if type(map.waterTiles)~="table" then return false,"water-tiles" end
    map.waterTiles[M.LOWER_SHORE_TILE]=true
    return true
  end
  M.graph={[M.COMMON_ANTECHAMBER]={M.IDS.upper},[M.IDS.upper]={M.COMMON_ANTECHAMBER,M.IDS.abyss},[M.IDS.abyss]={M.IDS.upper,M.IDS.lower,M.IDS.recovery},[M.IDS.recovery]={M.IDS.abyss,M.IDS.lower},[M.IDS.lower]={M.IDS.abyss,M.IDS.recovery,M.IDS.shrine},[M.IDS.shrine]={M.IDS.lower}}
  function M.isConnected(from,to) local q,seen,head={from},{[from]=true},1;while q[head] do for _,n in ipairs(M.graph[q[head]] or {}) do if n==to then return true end;if not seen[n] then seen[n]=true;q[#q+1]=n end end;head=head+1 end;return false end
  local function saveState(save,key,create)
    if mod.save and mod.save.get and mod.save.set then
      local value=mod.save:get(key)
      if type(value)~="table" and create then value={};mod.save:set(key,value) end
      return value
    end
    if type(save[key])~="table" and create then save[key]={} end
    return save[key]
  end
  function M.run(save,create)
    local root=saveState(save,"hevo_run",create)
    if not root then return nil end
    root.red=type(root.red)=="table" and root.red or {}
    -- adapter.finalize writes the authoritative per-run seal before this
    -- path callback sets its presentation marker.  A power-cycle in that
    -- narrow interval must still leave the carved final seal usable as the
    -- promised last-chance BLAZIKENITE claim.
    local dungeon=type(root.dungeonLegacy)=="table" and root.dungeonLegacy
    local seals=dungeon and type(dungeon.seals)=="table" and dungeon.seals
    if seals and seals.RED==true then root.red.completed=true end
    return root.red
  end
  function M.activeCharacter(game)
    local function resolved(value)
      if value==nil then return nil,false end
      value=type(value)=="string" and value:upper() or nil
      return ({RED=true,BLUE=true,GREEN=true})[value] and value or nil,true
    end
    -- Resolve the active slot's unnormalized record before any public
    -- presentation helper. extendedCharacters intentionally maps unknown or
    -- absent values to RED; that is useful for art, but must never authorize
    -- Red's final seal/cache for a FUTURE/YELLOW or half-loaded save.
    local save=type(game and game.save)=="table" and game.save or nil
    local modData=save and type(save.modData)=="table" and save.modData
    local extended,present
    if type(modData)=="table" then
      local rawBucket=modData[mod.id]
      if rawBucket~=nil and type(rawBucket)~="table" then return nil end
      local bucket=type(rawBucket)=="table" and rawBucket or nil
      extended=bucket and bucket.extended_characters or nil
      present=extended~=nil
    elseif mod.save and type(mod.save.get)=="function" then
      extended=mod.save:get("extended_characters")
      present=extended~=nil
    end
    if present then
      if type(extended)~="table" then return nil end
      local value,authoritative=resolved(extended.player_character)
      if authoritative then return value end
      return nil
    end
    if type(opts.activeCharacter)=="function" then
      local value,authoritative=resolved(opts.activeCharacter(game))
      if authoritative then return value end
    end
    if opts.characters and type(opts.characters.getPlayerCharacter)=="function" then
      local value,authoritative=resolved(opts.characters.getPlayerCharacter())
      if authoritative then return value end
    end
    -- Official pre-6.5 saves have no character bucket: Red was their sole
    -- playable identity.  Match the researcher, fissure and dungeon adapter
    -- migration rule so BLITZ-style saves cannot finish the seal yet have a
    -- silently dead cache/last-chance Mega-stone interaction.
    return game and game.save and "RED" or nil
  end
  function M.isRed(game) return M.activeCharacter(game)=="RED" end
  local function questionById(id)
    for _,q in ipairs(M.questions) do if q.id==id then return q end end
  end
  local HASH_MOD=2147483647
  local function stableHash(value)
    local hash=5381
    value=tostring(value or "")
    for i=1,#value do hash=(hash*33+value:byte(i))%HASH_MOD end
    return hash>0 and hash or 1
  end
  local function shuffled(indices,seed)
    local out={};for i,index in ipairs(indices) do out[i]=index end
    seed=math.floor(tonumber(seed) or 1)%HASH_MOD;if seed<=0 then seed=1 end
    for i=#out,2,-1 do
      seed=(seed*48271)%HASH_MOD
      local j=seed%i+1
      out[i],out[j]=out[j],out[i]
    end
    return out
  end
  local function questionIdentity(save)
    local root=mod.save and mod.save.get and mod.save:get("hevo_run")
      or (type(save)=="table" and save.hevo_run) or {}
    local meta=type(save)=="table" and type(save.meta)=="table" and save.meta or {}
    return table.concat({tostring(meta.playthroughId or ""),
      tostring(root.runId or ""),tostring(root.id or ""),
      tostring(root.cycle or 0)},"|")
  end
  local function questionOrder(save,run)
    if type(run.questionSeed)~="number" then
      run.questionSeed=stableHash("RED|"..questionIdentity(save))
    end
    run.questionCycle=math.max(1,math.floor(tonumber(run.questionCycle) or 1))
    -- Shuffle the complete, already-balanced catalogue as one bank.  This
    -- keeps the full-cycle 70/70 YES/NO contract without exposing the former
    -- perfectly alternating answer pattern to a player.
    local indices={}
    for index=1,#M.questions do indices[index]=index end
    return shuffled(indices,run.questionSeed+run.questionCycle*104729)
  end
  function M.questionForStatue(save,name)
    local run=M.run(save,true)
    if order[name]~=(run.sight or 0)+1 then return nil,"order" end
    run.asked=run.asked or {};run.pending=run.pending or {}
    local pending=questionById(run.pending[name])
    if pending and not run.asked[pending.id] then return pending end
    local sequence=questionOrder(save,run)
    local cursor=math.max(0,math.floor(tonumber(run.questionCursor) or 0))
    for offset=0,#sequence-1 do
      local q=M.questions[sequence[(cursor+offset)%#sequence+1]]
      if not run.asked[q.id] then run.pending[name]=q.id;return q end
    end
    -- A truly exhausted bank starts a new deterministic permutation.  Only
    -- consumed questions reset; solved statues and visibility never do.
    run.asked={};run.pending={};run.questionCursor=0
    run.questionCycle=(run.questionCycle or 1)+1
    sequence=questionOrder(save,run)
    local q=M.questions[sequence[1]]
    if q then run.pending[name]=q.id;return q,"new_cycle" end
    return nil,"exhausted"
  end
  function M.answerStatue(save,name,questionId,yes)
    local run=M.run(save,true)
    if order[name]~=(run.sight or 0)+1 then return false,"order" end
    local q=questionById(questionId)
    if not q or run.pending[name]~=questionId or run.asked[questionId] then return false,"unknown" end
    run.asked[questionId]=true;run.pending[name]=nil;run.questionCursor=(run.questionCursor or 0)+1
    if yes~=q.answer then return false,"wrong" end
    run.sight=order[name];run.statues=run.statues or {};run.statues[name]=true
    return true,run.sight
  end
  function M.setBoulder(save,name)
    local run=M.run(save,true);run.boulders=run.boulders or {};if not ({A=true,B=true,C=true})[name] then return false,"unknown" end;run.boulders[name]=true;return true
  end
  function M.resetUpper(save)
    local run=M.run(save,true);run.boulders={};run.resetCount=(run.resetCount or 0)+1
    return true,run.resetCount
  end
  function M.canCrossLower(save) local b=M.run(save,true).boulders or {};return b.A and b.B end
  function M.canEnterShrine(save) local run=M.run(save,true);return run.sight==5 and M.canCrossLower(save) and run.boulders and run.boulders.C end
  -- Read-only summary for the shared final seal.  Only route requirements
  -- belong here: optional floor-light discoveries and the hidden Mega cache
  -- deliberately stay out of the completion report.
  function M.completionProgress(save)
    local root
    if mod.save and type(mod.save.get)=="function" then
      root=mod.save:get("hevo_run")
    elseif type(save)=="table" then
      root=save.hevo_run
    end
    local run=type(root)=="table" and type(root.red)=="table"
      and root.red or {}
    local b=type(run.boulders)=="table" and run.boulders or {}
    return {
      statues=math.max(0,math.min(5,math.floor(tonumber(run.sight) or 0))),
      total=5,
      boulders={A=b.A==true,B=b.B==true,C=b.C==true},
    }
  end
  function M.complete(game)
    local save=game and game.save
    if not save then return false,"game" end
    if not M.canEnterShrine(save) then return false,"gate" end
    local adapter=opts.legacyDungeonAdapter
    if not (adapter and adapter.finalize) then return false,"adapter" end
    local run=M.run(save,true)
    -- `completed` predates the dungeonLegacy seal authority.  An interrupted
    -- older save can therefore own this marker without the seal that the RGB
    -- end-room door requires.  Do not let the presentation marker short-cut
    -- recovery: the adapter below must re-authorize character, Beyond Kanto
    -- and the exact puzzle gates before it can backfill the durable seal.
    local questions={};for id in pairs(run.asked or {}) do questions[#questions+1]=id end;table.sort(questions)
    local ok,why=adapter.finalize(game,{character="RED",questionIds=questions})
    if not ok then return false,why end
    run.completed=true
    return true,"granted"
  end
  function M.claimMega(game)
    if not M.isRed(game) then return false,"character" end
    local adapter=opts.legacyDungeonAdapter
    if not (adapter and type(adapter.claimSecret)=="function") then return false,"secret-api" end
    return adapter.claimSecret(game,{character="RED",stone=M.MEGA_STONE,
      secret="KA_RED_BLAZIKENITE_SECRET"})
  end
  function M.blockAt(id,x,y) local d=byId[id];return d and d.blocks[x+y*W+1] end
  function M.isCollisionSafe(id,x,y)
    local b=M.blockAt(id,x,y)
    return b~=nil and b~=R and b~=V and b~=WATER
  end
  function M.isWalkCell(id,x,y)
    if x<0 or y<0 or x>=W*2 or y>=H*2 then return false end
    local block=M.blockAt(id,math.floor(x/2),math.floor(y/2))
    local mask=WALK_MASK[block]
    if mask==nil then return false end
    local bit=(y%2)*2+(x%2)
    return math.floor(mask/(2^bit))%2==1
  end
  function M.pathLength(id,sx,sy,tx,ty)
    local q,seen,head={{sx,sy,0}},{[sx..","..sy]=true},1
    while q[head] do
      local x,y,n=q[head][1],q[head][2],q[head][3];if x==tx and y==ty then return n end
      for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do local nx,ny=x+d[1],y+d[2];local k=nx..","..ny;if not seen[k] and M.isCollisionSafe(id,nx,ny) then seen[k]=true;q[#q+1]={nx,ny,n+1} end end
      head=head+1
    end
    return nil
  end
  function M.metrics()
    local out={}
    for id in pairs(byId) do
      local open,narrow,branches,edges=0,0,0,0
      local maxWide=0
      for y=0,H*2-1 do
        local wide=0
        for x=0,W*2-1 do
          if M.isWalkCell(id,x,y) and M.isWalkCell(id,x,y+1) then
            wide=wide+1;maxWide=math.max(maxWide,wide)
          else wide=0 end
          if M.isWalkCell(id,x,y) then
            open=open+1;local n=0
            local north,south=M.isWalkCell(id,x,y-1),M.isWalkCell(id,x,y+1)
            local west,east=M.isWalkCell(id,x-1,y),M.isWalkCell(id,x+1,y)
            if north then n=n+1 end;if south then n=n+1 end
            if west then n=n+1 end;if east then n=n+1 end
            edges=edges+n
            if (not north and not south) or (not west and not east) then
              narrow=narrow+1
            end
            if n>=3 then branches=branches+1 end
          end
        end
      end
      for x=0,W*2-1 do
        local wide=0
        for y=0,H*2-1 do
          if M.isWalkCell(id,x,y) and M.isWalkCell(id,x+1,y) then
            wide=wide+1;maxWide=math.max(maxWide,wide)
          else wide=0 end
        end
      end
      out[id]={cells=open,branches=branches,loops=edges/2-open+1,
        narrow=narrow,narrowRatio=open>0 and narrow/open or 0,maxWide=maxWide}
    end
    return out
  end
  function M.register()
    assert(not mod.content.tilesets.get or mod.content.tilesets:get("CAVERN"),
      "RED trial requires the shipped Gen-I CAVERN tileset")
    if mod.content.field and mod.content.field.patch then
      mod.content.field:patch("darkMaps",{maps={__append={
        M.IDS.upper,M.IDS.abyss,M.IDS.recovery,M.IDS.lower,M.IDS.shrine,
      }}})
    end
    for id,pair in pairs(text) do mod.content.text:register(id,tr(pair)) end
    for _,q in ipairs(M.questions) do mod.content.text:register(q.id,tr({q.en,q.de})) end
    local ptr={};for id in pairs(text) do ptr[id]={text=id} end
    mod.content.text_pointers:patch("???",ptr)
    for _,d in pairs(named) do
      mod.content.maps:register(d.id,d)
      mod.content.map_songs:register(d.id,"Music_KA_DeepEvolution")
      if mod.content.encounters then mod.content.encounters:register(d.id,{grass={rate=0,slots={}}}) end
    end
    local function show(game,message,done,options)
      game.stack:push(require("src.render.TextBox").new(game,message,done,options));return true
    end
    local function statueTalk(game,ow,npc,done)
      local q,why=M.questionForStatue(game.save,npc.def.name)
      if not q then
        local run=M.run(game.save,true)
        if run.statues and run.statues[npc.def.name] then return show(game,tr(text.TEXT_KA_RED_LIT),done) end
        if done then done() end;return false,why
      end
      local finished=false
      local function finish()
        if finished then return end
        finished=true
        if done then done() end
      end
      local prompt=tr({q.en,q.de})
      local statueIndex=assert(order[npc.def.name],"RED statue rank missing")
      local rows={{label=tr({"YES","JA"}),value=true},
        {label=tr({"NO","NEIN"}),value=false}}
      local function answer(value)
        local ok,level=M.answerStatue(game.save,npc.def.name,q.id,value)
        if ok then
          game.save.flags=game.save.flags or {};game.save.flags["KA_HEVO_RED_SIGHT_"..level]=true
          if ow then
            local mapId=ow and ow.map and ow.map.id
            local profile=M.activeSightProfile(game.save,mapId,level,false)
            ow.visionRadius=profile.radius
            ow.kaHevoRedSight=profile
          end
        end
        show(game,tr(ok and text.TEXT_KA_RED_RIGHT or text.TEXT_KA_RED_WRONG),finish)
      end
      local shown,screen=pcall(function()
        if not (questionUi and type(questionUi.showQuestionText)=="function") then
          return false,"question-ui"
        end
        return questionUi.showQuestionText(game,prompt,function()
        if not (questionUi and type(questionUi.openQuestionMenu)=="function") then
          finish();return
        end
        local opened,menu=pcall(questionUi.openQuestionMenu,game,
          "GROUDON-TEST "..statueIndex.."/5",
          prompt,rows,{
            defaultIndex=2,
            seconds=20,
            onTimeout=function()answer(not q.answer)end,
            onChoose=function(row)
              if type(row)~="table" or type(row.value)~="boolean" then
                finish();return
              end
              answer(row.value)
            end,
          })
        if not opened or type(menu)~="table" then finish() end
        end,opts.showText)
      end)
      if not shown or screen==false then finish() end
      return true,q.id
    end
    local function resetTalk(game,ow,npc,done)
      return show(game,tr(text.TEXT_KA_RED_RESET),done,{choice=function(yes)
        if not yes then return end
        M.resetUpper(game.save)
        if mod.world and mod.world.toggleObject then
          for _,name in ipairs({"KA_RED_BOULDER_A","KA_RED_BOULDER_B","KA_RED_BOULDER_C"}) do
            setObjectVisible(game,M.IDS.upper,name,true)
          end
          for _,name in ipairs({"KA_RED_FALLEN_A","KA_RED_FALLEN_B","KA_RED_FALLEN_C"}) do
            setObjectVisible(game,M.IDS.lower,name,false)
          end
        end
        if mod.world and mod.world.warpTo then mod.world:warpTo(M.IDS.upper,3,33,"up") end
      end,defaultNo=true})
    end
    local function retreatTalk(game,ow,npc,done)
      return show(game,tr(text.TEXT_KA_RED_RETREAT),done,{choice=function(yes)
        if yes and mod.world and mod.world.warpTo then mod.world:warpTo(M.IDS.upper,3,33,"down") end
      end,defaultNo=true})
    end
    local function plain(key)
      return function(game,ow,npc,done) return show(game,tr(text[key]),done) end
    end
    local talks={
      TEXT_KA_RED_STATUE_1=statueTalk,TEXT_KA_RED_STATUE_2=statueTalk,
      TEXT_KA_RED_STATUE_3=statueTalk,TEXT_KA_RED_STATUE_4=statueTalk,TEXT_KA_RED_STATUE_5=statueTalk,
      TEXT_KA_RED_COMPLETE=function(game,ow,npc,done)
        if not M.isRed(game) then return false,"character" end
        local ok,why=M.complete(game)
        if ok then
          if ow then
            local mapId=ow and ow.map and ow.map.id
            local profile=M.activeSightProfile(game.save,mapId,5,true)
            ow.visionRadius=profile.radius
            ow.kaHevoRedSight=profile
          end
          if mod.world and mod.world.toggleObject then
            setObjectVisible(game,M.IDS.shrine,"KA_RED_RESEARCH_CACHE",false)
          end
          return show(game,tr(text.TEXT_KA_RED_AFTER),done)
        end
        return show(game,tr(why=="gate" and text.TEXT_KA_RED_GATE or text.TEXT_KA_RED_COMPLETE),done)
      end,
      TEXT_KA_RED_EMBER_HINT=plain("TEXT_KA_RED_EMBER_HINT"),
      TEXT_KA_RED_STRENGTH=plain("TEXT_KA_RED_STRENGTH"),
      TEXT_KA_RED_FALLEN=plain("TEXT_KA_RED_FALLEN"),
      TEXT_KA_RED_SURF=plain("TEXT_KA_RED_SURF"),
      TEXT_KA_RED_FALL=plain("TEXT_KA_RED_FALL"),
      TEXT_KA_RED_RESET=resetTalk,TEXT_KA_RED_RETREAT=retreatTalk,
      TEXT_KA_RED_BLAZIKENITE=function(game,ow,npc,done)
        local ok,why=M.claimMega(game)
        if ok then
          if mod.world and mod.world.toggleObject then
            setObjectVisible(game,M.IDS.recovery,"KA_RED_BLAZIKENITE_SECRET",false)
          end
          return show(game,tr(text.TEXT_KA_RED_BLAZIKENITE),done)
        end
        return show(game,tr(why=="claimed" and text.TEXT_KA_RED_BLAZIKENITE_EMPTY or text.TEXT_KA_RED_GATE),done)
      end,
      TEXT_KA_RED_GROUDON=function(game,ow,npc,done)
        if type(M.finalizeEndSeal)=="function" then
          local ok,why,stoneStatus=M.finalizeEndSeal(game)
          if not ok then
            local blocked=opts.legacyDungeonAdapter
              and opts.legacyDungeonAdapter.failureText
              and opts.legacyDungeonAdapter.failureText(why)
            if blocked then return show(game,blocked,done) end
            return show(game,tr(text.TEXT_KA_RED_GATE),done)
          end
          if stoneStatus=="granted" then
            return show(game,tr({
              "A final ember breaks from the red seal. BLAZIKENITE is secured. GROUDON calls beyond the black door.",
              "Eine letzte Glut bricht aus dem roten Siegel. LOHGOCKNIT ist gesichert. Hinter der schwarzen Tür ruft GROUDON.",
            }),done)
          end
          if stoneStatus=="claimed" then
            return show(game,tr({
              "The completed red seal burns steadily. BLAZIKENITE is already secured. GROUDON calls beyond the black door.",
              "Das vollendete rote Siegel glüht stetig. LOHGOCKNIT ist bereits gesichert. Hinter der schwarzen Tür ruft GROUDON.",
            }),done)
          end
          return show(game,tr(text.TEXT_KA_RED_GROUDON),done)
        end
        local run=M.run(game.save,true)
        if run.completed then
          local ok,why=M.claimMega(game)
          if ok then
            if mod.world and mod.world.toggleObject then
              setObjectVisible(game,M.IDS.recovery,"KA_RED_BLAZIKENITE_SECRET",false)
            end
            return show(game,tr({
              "A final ember breaks from the red seal. BLAZIKENITE is secured. GROUDON calls beyond the black door.",
              "Eine letzte Glut bricht aus dem roten Siegel. LOHGOCKNIT ist gesichert. Hinter der schwarzen Tür ruft GROUDON.",
            }),done)
          end
          if why~="claimed" then
            return show(game,tr(text.TEXT_KA_RED_GATE),done)
          end
        end
        return show(game,tr(text.TEXT_KA_RED_GROUDON),done)
      end,
    }
    for _,d in pairs(named) do mod.content.map_scripts:register(d.id,{priority=1450,talk=talks}) end
  end

  local BOULDER_GOALS={["19,29"]="A",["21,19"]="B",["37,17"]="C"}
  local BOULDER_OBJECTS={A="KA_RED_BOULDER_A",B="KA_RED_BOULDER_B",C="KA_RED_BOULDER_C"}
  local FALLEN_OBJECTS={A="KA_RED_FALLEN_A",B="KA_RED_FALLEN_B",C="KA_RED_FALLEN_C"}
  function M.install(game)
    -- RED's sight mask is a world-pass overlay, so it works over both flat
    -- maps and DRAMALESS without touching menus/dialogue.  A prior
    -- visionRadius field had no engine consumer; this narrow wrapper makes
    -- the authored five-stage light progression real while leaving every
    -- non-RED map byte-for-byte on the original draw path.
    local voxelTools
    local function voxelScreenPoint(wx,wz)
      if voxelTools==false then return nil end
      if voxelTools==nil then
        local projector=voxelRenderer
          and voxelRenderer.module(game,"Voxel3D")
        local aa=voxelRenderer and voxelRenderer.module(game,"AntiAlias")
        if not (projector and type(projector.project)=="function") then
          voxelTools=false;return nil
        end
        voxelTools={projector=projector,aa=aa}
      end
      local x,y=voxelTools.projector.project(wx,0,wz)
      if not (x and y) then return nil end
      local factor=voxelTools.aa and voxelTools.aa.factor
        and voxelTools.aa.factor() or 1
      if not factor or factor<=0 then factor=1 end
      return x/factor,y/factor
    end
    local OverworldState=require("src.world.OverworldController")
    if not rawget(OverworldState,"_kaHevoRedSightWrapped") then
      local original=OverworldState.drawAtmosphere
      OverworldState.drawAtmosphere=function(ow,vw,vh)
        if type(original)=="function" then original(ow,vw,vh) end
        local sight=ow.kaHevoRedSight
        -- Imported/manual test saves can construct their OverworldState
        -- after both save.loaded and the authored map.entered callback.  Do
        -- not allow that lifecycle ordering to produce even one permanently
        -- bright RED floor: the final atmosphere pass can recover the
        -- authoritative profile directly from the live map and save.
        local liveMapId=ow.map and ow.map.id
        if not sight and M.byId[liveMapId] then
          local run=M.run(game.save,true)
          sight=M.activeSightProfile(game.save,liveMapId,run.sight or 0,
            run.completed==true)
          ow.visionRadius=sight.radius
          ow.kaHevoRedSight=sight
        end
        if not sight or not (love and love.graphics) then return end
        local px=ow.player.px-ow.camera.x+8
        local py=ow.player.py-ow.camera.y+12
        if ow.kaHevoRedSightShader==nil and love.graphics.newShader then
          local ok,shader=pcall(love.graphics.newShader,SIGHT_SHADER)
          if not ok and mod.log and type(mod.log.warn)=="function" then
            mod.log:warn("RED sight shader unavailable: %s",tostring(shader))
          end
          ow.kaHevoRedSightShader=ok and shader or false
        end
        local shader=ow.kaHevoRedSightShader
        local directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
        local facing=directions[ow.player.facing] or directions.down
        local function drawMask(cx,cy,fx,fy,scale,width,height)
          love.graphics.push("all")
          if shader then
            shader:send("sightCenter",{cx,cy});shader:send("sightFacing",{fx,fy})
            shader:send("sightRadius",sight.radius*16*scale)
            shader:send("sightCoreRadius",(sight.coreRadius or 0.85)*16*scale)
            shader:send("sightConeSlope",sight.coneSlope or 0.34)
            shader:send("sightInnerOpacity",sight.innerOpacity or 0.62)
            shader:send("sightFeatherPx",math.max(0.5,math.min(2.0,
              tonumber(sight.featherPx) or 2.0)))
            shader:send("sightOpacity",sight.opacity);love.graphics.setShader(shader)
            love.graphics.setColor(1,1,1,1)
            love.graphics.rectangle("fill",0,0,width,height)
          else
            -- Shader failure must never degrade into a uniform red/black
            -- wash. Build the same keyhole union with LÖVE's stencil API:
            -- an omni-directional core plus the facing tunnel beam. This
            -- path has a hard pixel edge by design, but preserves gameplay.
            local core=(sight.coreRadius or 0.85)*16*scale*1.80
            local radius=sight.radius*16*scale
            local length=math.sqrt(fx*fx+fy*fy)
            if length<=0 then fx,fy,length=0,1,1 end
            fx,fy=fx/length,fy/length
            local pxn,pyn=-fy,fx
            local base=(sight.coreRadius or 0.85)*16*scale*0.62
            local tip=base+radius*(sight.coneSlope or 0.34)
            love.graphics.stencil(function()
              love.graphics.circle("fill",cx,cy,core)
              love.graphics.polygon("fill",
                cx+pxn*base,cy+pyn*base,
                cx+fx*radius+pxn*tip,cy+fy*radius+pyn*tip,
                cx+fx*radius-pxn*tip,cy+fy*radius-pyn*tip,
                cx-pxn*base,cy-pyn*base)
            end,"replace",1)
            love.graphics.setStencilTest("notequal",1)
            love.graphics.setColor(0,0,0,sight.opacity)
            love.graphics.rectangle("fill",0,0,width,height)
            love.graphics.setStencilTest("equal",1)
            love.graphics.setColor(0,0,0,sight.innerOpacity or 0.62)
            love.graphics.rectangle("fill",0,0,width,height)
            love.graphics.setStencilTest()
          end
          love.graphics.pop()
        end
        -- Atmosphere used to draw directly into worldCanvas.  Renderer then
        -- replayed OBP actors and Voxel's upright billboards over it, leaving
        -- the bright player/statue/item rectangles the visual gate caught.
        -- Queue the same authored mask for the final WORLD composite instead:
        -- all actors are now shaded with the cave, while dialogue/UI stays
        -- crisp because Renderer drains this queue before its UI blit.
        local Game=require("src.core.Game")
        local renderer=Game and Game.renderer
        if renderer and renderer.queueWorldPostOverlay then
          renderer:queueWorldPostOverlay(function(ctx)
            local scale=((ctx.scaleX or 1)+(ctx.scaleY or 1))*0.5
            local cx,cy,fx,fy
            if ctx.pipeline then
              cx,cy=voxelScreenPoint(ow.player.px+8,ow.player.py+16)
              if cx and cy then
                local ax,ay=voxelScreenPoint(
                  ow.player.px+8+facing[1]*16,
                  ow.player.py+16+facing[2]*16)
                if ax and ay then
                  fx,fy=ax-cx,ay-cy
                  local length=math.sqrt(fx*fx+fy*fy)
                  if length>0 then fx,fy=fx/length,fy/length end
                end
              end
              cx,cy=cx or ctx.centerX or ctx.width*0.5,
                cy or ctx.centerY or ctx.height*0.52
              fx,fy=fx or facing[1],fy or facing[2]
            else
              cx,cy=ctx.worldToScreen(px,py)
              local ax,ay=ctx.worldToScreen(px+facing[1]*16,py+facing[2]*16)
              fx,fy=ax-cx,ay-cy
              local length=math.sqrt(fx*fx+fy*fy)
              if length>0 then fx,fy=fx/length,fy/length else fx,fy=facing[1],facing[2] end
            end
            drawMask(cx,cy,fx,fy,scale,ctx.width,ctx.height)
          end)
        else
          -- Compatibility fallback for an older executable.  It retains a
          -- playable dark cave, but current 6.5 ships the post-overlay hook
          -- above so actors never bypass the mask.
          drawMask(px,py,facing[1],facing[2],1,vw,vh)
        end
      end
      rawset(OverworldState,"_kaHevoRedSightWrapped",true)
    end
    local function eventMapId(ev)
      local ow=mod.world and mod.world.overworld and mod.world:overworld()
      return ev and (ev.mapId or ev.map and ev.map.id)
        or ow and ow.map and ow.map.id
        or game.save and game.save.player and game.save.player.map
    end
    local function refreshShore(ev)
      local mapId=eventMapId(ev)
      if mapId~=M.IDS.lower then return false,"map" end
      local ow=mod.world and mod.world.overworld and mod.world:overworld()
      local map=ev and ev.map or ow and ow.map
      if not (map and map.id==mapId) then return false,"runtime-map" end
      return M.applyRuntimeShore(map)
    end
    local function refreshSight(ev)
      local mapId=eventMapId(ev)
      local ow=mod.world and mod.world.overworld and mod.world:overworld()
      if not ow then return false end
      if not M.byId[mapId] then
        ow.kaHevoRedSight=nil
        return false
      end
      local run=M.run(game.save,true)
      local profile=M.activeSightProfile(game.save,mapId,run.sight or 0,
        run.completed==true)
      ow.visionRadius=profile.radius
      ow.kaHevoRedSight=profile
      return true
    end
    mod.events:on("map.entered",function(ev)
      if not ev then return end
      local mapId=eventMapId(ev)
      refreshShore(ev)
      local run=M.run(game.save,true)
      if M.byId[mapId] then
        run.checkpoint=mapId
        game.save.flags=game.save.flags or {}
        for level=1,(run.sight or 0) do game.save.flags["KA_HEVO_RED_SIGHT_"..level]=true end
        refreshSight(ev)
      else
        refreshSight(ev)
      end
      if mapId==M.IDS.recovery then run.recovered=true end
      if (mapId==M.IDS.upper or mapId==M.IDS.lower)
          and mod.world and mod.world.toggleObject then
        local solved=run.boulders or {}
        for _,name in ipairs({"A","B","C"}) do
          setObjectVisible(game,M.IDS.upper,BOULDER_OBJECTS[name],not solved[name])
          setObjectVisible(game,M.IDS.lower,FALLEN_OBJECTS[name],solved[name] and true or false)
        end
      end
      if mapId==M.IDS.shrine and not M.canEnterShrine(game.save) and mod.world and mod.world.warpTo then
        mod.world:warpTo(M.IDS.lower,43,5,"down")
      end
      local adapter=opts.legacyDungeonAdapter
      if mapId==M.IDS.recovery and adapter and adapter.hasSecret and adapter.hasSecret(game.save,"RED")
          and mod.world and mod.world.toggleObject then
        setObjectVisible(game,M.IDS.recovery,"KA_RED_BLAZIKENITE_SECRET",false)
      end
      if mapId==M.IDS.shrine and run.completed and mod.world and mod.world.toggleObject then
        setObjectVisible(game,M.IDS.shrine,"KA_RED_RESEARCH_CACHE",false)
      end
    end)
    -- Save swaps and engine-level map reloads can rebuild OverworldState
    -- without emitting a second authored map transition.  Re-attach the
    -- mask and LOWER's instance-local shore to that fresh state.  Hot import
    -- can install over an already-live map, so repair that instance now too.
    local function refreshRuntime(ev)
      refreshShore(ev)
      return refreshSight(ev)
    end
    refreshShore()
    mod.events:on("save.loaded",refreshRuntime,1800)
    mod.events:on("map.reloaded",refreshRuntime,1800)
    mod.events:on("world.boulder_moved",function(ev)
      if not (ev and ev.mapId==M.IDS.upper) then return end
      local name=BOULDER_GOALS[ev.x..","..ev.y]
      if not name then return end
      M.setBoulder(game.save,name)
      if mod.world and mod.world.toggleObject then
        setObjectVisible(game,M.IDS.upper,BOULDER_OBJECTS[name],false)
        setObjectVisible(game,M.IDS.lower,FALLEN_OBJECTS[name],true)
      end
    end)
  end
  M.solutionCells={
    upper={{1,16},{4,14},{6,12},{10,10},{15,8},{19,5},{22,1}},
    abyss={{1,16},{5,13},{6,11},{10,8},{15,5},{20,4},{22,1}},
    recovery={{1,16},{5,13},{10,10},{14,8},{18,5},{22,1}},
    lower={{1,16},{6,12},{7,9},{12,9},{16,8},{19,6},{22,1}},
    shrine={{1,16},{6,13},{8,10},{14,7},{19,4},{22,1}},
  }
  return M
end
