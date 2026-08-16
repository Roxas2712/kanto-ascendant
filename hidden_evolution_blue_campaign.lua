-- Package C-BLUE.  Isolated Frost campaign; deliberately does not import or
-- alter the legacy 1902--1913 dungeon or Package-A/RED controllers.
return function(mod, opts)
  opts = opts or {}
  local C = { registered = false, installed = false, game = nil }
  local voxelRenderer = opts.voxelRenderer
  local questionUi = opts.questionUi
  local ID = {
    THRESHOLD = "KA_HEVO_BLUE_FROST_THRESHOLD",
    HALL = "KA_HEVO_BLUE_FROST_HALL",
    ICE = "KA_HEVO_BLUE_GLACIER_MAZE",
    DEPTHS = "KA_HEVO_BLUE_TIDAL_DEPTHS",
    SHRINE = "KA_HEVO_BLUE_KYOGRE_SHRINE",
  }
  C.ids = ID
  local BLUE_MAPS = {}
  for _,mapId in pairs(ID) do BLUE_MAPS[mapId]=true end
  C.indices = { THRESHOLD = 1940, HALL = 1941, ICE = 1942, DEPTHS = 1943, SHRINE = 1944 }
  -- These IDs are the shared-story contract: no sector placeholder remains.
  C.contract = { entryMap = ID.THRESHOLD,
    returnMap = opts.commonAntechamberId or "KA_HEVO_TUNNEL_ALL",
    returnCell = { x=16, y=21, facing="down" },
    endMap="KA_HEVO_SHARED_SEALED_ANTECHAMBER" }
  -- The story coordinator consumes this exact visible final stair instead of
  -- installing an invisible fallback warp at the former top-row coordinate.
  C.END_WARP = { x=37, y=7 }
  C.flags = { sight = "KA_HEVO_BLUE_SIGHT", door = "KA_HEVO_BLUE_KYOGRE_DOOR" }
  C.unlocks = { "MAGNEZONE", "ELECTIVIRE", "GLACEON", "WEAVILE", "PORYGON_Z" }
  C.rewards = C.unlocks

  -- BLUE is deliberately built from the canonical Gen-I CAVERN blockset.
  -- 25 is the calm pale cave floor, 21 the visually distinct pale/glinting
  -- floor used as authored ice, 125 a complete native rock wall, 118 the
  -- engine's real water ($14), and 124 a lower-right native warp stair.  The
  -- four hole blocks put CAVERN's native $22 fall tile in one exact cell.
  -- Nothing in this package depends on a Crystal/Johto tileset or fallback.
  local FLOOR, ICE, WALL, WATER = 25, 21, 125, 118
  -- CAVERN block 41 is the native south-facing rock shelf: its two inner
  -- cells are ordinary $05 floor and its two water-facing cells are $15.
  -- That matters mechanically, not just visually: Gen-I's water tile-pair
  -- contract forbids a surfer from dismounting directly from $14 water onto
  -- $05 floor.  The $15 lip is the canonical safe transition in both
  -- directions and still joins the $05 interior without an elevation wall.
  local SOUTH_SHORE = 41
  -- A dry shelf must keep CAVERN's native floor elevation.  Block 1 looks
  -- grippy, but its $20 collision cells form a Gen-I elevation pair against
  -- the $05 floor and make an apparently open corridor impassable.  Block 25
  -- is visually dry beside glinting block 21 and remains the correct brake
  -- because only ICE is registered as a slide surface.
  local BRAKE, WARP = FLOOR, 124
  -- Canonical rock-wall transitions with exactly one traversable cell row or
  -- column.  They turn selected two-cell construction lanes into offset,
  -- organic chokepoints without custom tiles, while leaving the teaching ice
  -- lanes wide enough to read their direction.
  local NARROW_V_LEFT, NARROW_V_RIGHT = 26, 38
  local NARROW_H_TOP, NARROW_H_BOTTOM = 29, 57
  local SWITCH_BR = 108
  local HOLE_TL, HOLE_TR, HOLE_BL, HOLE_BR = 119, 120, 104, 105
  local function tr(en, de) return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en end
  local function activeCharacter(game)
    local raw
    if type(opts.activeCharacter)=="function" then raw=opts.activeCharacter(game) end
    if raw==nil then local chars=opts.characters; if chars and type(chars.getPlayerCharacter)=="function" then raw=chars.getPlayerCharacter() end end
    if raw==nil and mod.save then local chars=mod.save:get("extended_characters"); raw=type(chars)=="table" and chars.player_character or nil end
    return type(raw)=="string" and raw:upper() or nil
  end
  function C.isBlue(game) return activeCharacter(game or C.game)=="BLUE" end
  local function grid(w, h, fill)
    local b = {}; for i = 1, w * h do b[i] = fill end
    return b, function(x, y, v) b[x + y * w + 1] = v end
  end
  local function map(id, index, w, h, blocks, warps, objects)
    local labels = {
      [ID.THRESHOLD] = { "FROST THRESHOLD", "FROST-SCHWELLE" },
      [ID.HALL] = { "FROST HALL", "FROST-HALLE" }, [ID.ICE] = { "GLACIER MAZE", "GLETSCHER-LABYRINTH" },
      [ID.DEPTHS] = { "TIDAL DEPTHS", "GEZEITENTIEFE" }, [ID.SHRINE] = { "KYOGRE SHRINE", "KYOGRE-SCHREIN" },
    }
    local label = labels[id] or { "FROST CAVERN", "FROST-HÖHLE" }
    local def = {
      id=id, index=index, label=tr(label[1], label[2]), tileset="CAVERN", width=w, height=h, borderBlock=WALL,
      blocks=blocks, warps=warps or {}, objects=objects or {}, signs={}, connections={}, outdoor=false,
      -- Native CAVERN blocks use DRAMALESS' complete canonical terrain
      -- profile; MAP_STUDIO is reserved for positional imported geometry.
      voxelMode="FULL", voxelRevision=5, voxelSemanticOverrides={},
    }
    mod.content.maps:register(id, def)
    mod.content.encounters:register(id, { grass={rate=0,slots={}} })
    -- Do not rely on the song inherited from the shared approach tunnel.
    -- A save/reload or Escape-Rope-compatible re-entry may construct this map
    -- directly, and older RCs then kept playing the previous overworld route.
    -- Every BLUE floor owns the same authored dungeon score explicitly, just
    -- like the RED and GREEN campaigns.
    if mod.content.map_songs then
      mod.content.map_songs:register(id, "Music_KA_DeepEvolution")
    end
    return def
  end
  -- Questions and visibility belong to the resettable HEVO run, never to
  -- NG+ permanent data.  A fresh hevo_run therefore gets a fresh campaign.
  local HASH_MOD=2147483647
  local function stableHash(value)
    local hash=5381;value=tostring(value or "")
    for i=1,#value do hash=(hash*33+value:byte(i))%HASH_MOD end
    return hash>0 and hash or 1
  end
  local function questionIdentity(run)
    local gameSave=C.game and C.game.save or {}
    local meta=type(gameSave.meta)=="table" and gameSave.meta or {}
    return table.concat({tostring(meta.playthroughId or ""),
      tostring(run.runId or ""),tostring(run.id or ""),
      tostring(run.cycle or 0)},"|")
  end
  local function saveRun(s)
    local run = mod.save:get("hevo_run") or {}
    run.hidden_evolution_blue = s
    mod.save:set("hevo_run", run)
  end
  local function state(create)
    local run = mod.save:get("hevo_run")
    if type(run) ~= "table" and create ~= false then run = {}; mod.save:set("hevo_run", run) end
    if type(run) ~= "table" then return nil end
    local s = run.hidden_evolution_blue
    if type(s) ~= "table" and create ~= false then
      s={asked={},answered={},solved={},switches={},sight=0,cycle=1}
      run.hidden_evolution_blue=s
    end
    if type(s)=="table" then
      s.asked=type(s.asked)=="table" and s.asked or {}; s.answered=type(s.answered)=="table" and s.answered or {}
      s.solved=type(s.solved)=="table" and s.solved or {}
      s.switches=type(s.switches)=="table" and s.switches or {}
      s.pending=type(s.pending)=="table" and s.pending or {}
      s.sight=tonumber(s.sight) or 0; s.cycle=tonumber(s.cycle) or 1
      s.questionCursor=math.max(0,math.floor(tonumber(s.questionCursor) or 0))
      if type(s.questionSeed)~="number" then
        s.questionSeed=stableHash("BLUE|"..questionIdentity(run))
      end
      run.hidden_evolution_blue=s; mod.save:set("hevo_run",run)
    end
    return s
  end
  C.state = state
  -- BLUE's five statues are also the visibility progression.  Native dark
  -- maps only swap palettes and would expose the entire maze at once; this
  -- dense cone keeps the first decisions local, then grows after every
  -- solved memory.  The inner cone deliberately remains darkened: native
  -- Rock Tunnel never turns the player, NPCs or items into a full-palette
  -- spotlight with a white halo.  FLASH is deliberately ineffective inside
  -- a Hidden-Evolution trial; only a solved frost statue expands this cone.
  function C.sightProfile(level)
    level=math.max(0,math.min(5,math.floor(tonumber(level) or 0)))
    local inner=0.68-level*0.04
    -- Unexplored space is genuinely black at every stage.  Progress is
    -- communicated only by the expanding radius and the slightly brighter
    -- inner world, never by remote statues/items leaking through as markers.
    local outer=1.0
    return {
      radius=1.75+level*0.80,
      innerOpacity=inner,
      outerOpacity=outer,
      -- Screen-space antialiasing only.  This is intentionally independent
      -- of the growing world radius: a proportional alpha band makes the
      -- native cave stipple reappear as a dotted ring around actors/items.
      featherPx=2.0,
      -- Compatibility for older QA callers; the shader uses the explicit
      -- inner/outer pair below rather than treating the centre as clear.
      opacity=outer,
      level=level,
    }
  end
  function C.activeSightProfile(save,mapId,level)
    if type(C.floorSightProfile)=="function" then
      local floorProfile=C.floorSightProfile(save,mapId)
      if floorProfile then return floorProfile end
    end
    return C.sightProfile(level)
  end
  function C.refreshSight()
    local ow=mod.world and mod.world.overworld and mod.world:overworld()
    if not(ow and ow.map) then return false end
    if BLUE_MAPS[ow.map.id] then
      local s=state(false)
      ow.kaHevoBlueSight=C.activeSightProfile(C.game and C.game.save,
        ow.map.id,s and s.sight or 0)
    else
      ow.kaHevoBlueSight=nil
    end
    return true
  end
  -- Native Rock-Tunnel darkness deliberately collapses every ordinary OBJ
  -- colour to black (rOBP0 / DARK_BGP).  That reads as a silhouette on pale
  -- cave floor, but the canonical SEEL surf sheet disappears into CAVERN's
  -- mostly-black $14 water.  BLUE therefore gives the *same native sheet*
  -- one per-player presentation clone while these five maps are active.  The
  -- clone changes no art, frames, walker timing or provenance: trueColor only
  -- prevents the earlier all-black OBJ bake, after which BLUE's final world
  -- post-overlay still dims terrain and actor together without a bright box.
  --
  -- Weak player keys plus identity-checked restore make this safe across
  -- BLUE->BLUE warps, save reloads and character-presentation refreshes.  If
  -- another package replaces surfSprite after us, leaving BLUE never writes
  -- an obsolete value back over that newer owner.
  local surfPresentations=setmetatable({}, {__mode="k"})
  function C.readableSurfDefinition(source)
    assert(type(source)=="table" and source.image and source.frames,
      "BLUE readable surf requires the native SPRITE_SEEL definition")
    local clone={}
    for key,value in pairs(source) do clone[key]=value end
    clone.trueColor=true
    return clone
  end
  function C.refreshSurfPresentation(ow,mapId,game,rendererModule)
    ow=ow or (mod.world and mod.world.overworld and mod.world:overworld())
    local player=ow and ow.player
    if not player then return false,"player" end
    mapId=mapId or (ow.map and ow.map.id)
    local previous=surfPresentations[player]
    if not BLUE_MAPS[mapId] then
      if not previous then return false,"outside" end
      if player.surfSprite==previous.clone then
        player.surfSprite=previous.original
      end
      surfPresentations[player]=nil
      return true,"restored"
    end
    if previous and player.surfSprite==previous.clone then
      return true,"active"
    end

    -- A presentation owner may have refreshed the actor between BLUE floors.
    -- Treat its current renderer as the new restore target instead of leaking
    -- the stale clone or overwriting the newer presentation on exit.
    surfPresentations[player]=nil
    local original=player.surfSprite
    game=game or C.game
    local native=game and game.data and game.data.sprites
      and game.data.sprites.SPRITE_SEEL
    assert(native,"BLUE readable surf cannot resolve native SPRITE_SEEL")
    rendererModule=rendererModule or require("src.render.SpriteRenderer")
    assert(rendererModule and type(rendererModule.new)=="function",
      "BLUE readable surf requires SpriteRenderer")
    local clone=rendererModule.new(C.readableSurfDefinition(native),"player")
    surfPresentations[player]={original=original,clone=clone}
    player.surfSprite=clone
    return true,"installed"
  end
  function C.hasReadableSurfPresentation(player)
    local row=player and surfPresentations[player]
    return row~=nil and player.surfSprite==row.clone
      and row.clone and row.clone.def and row.clone.def.trueColor==true
  end
  function C.surfPresentationState(player)
    local row=player and surfPresentations[player]
    if not row then return nil end
    return {active=player.surfSprite==row.clone,
      original=row.original,clone=row.clone}
  end
  -- id|prompt|right answer|two factual distractors.  The bank is deliberately
  -- BLUE-owned, static and larger than a full failed run; `question` rotates
  -- positions deterministically so answers are not always the first choice.
  local FACTS={
    {"CERULEAN","City below Nugget Bridge?","CERULEAN","PEWTER","FUCHSIA"},{"SURF","Move for open water?","SURF","CUT","FLASH"},{"MOONSTONE","Stone found in Mt. Moon?","MOON STONE","LEAF STONE","FIRE STONE"},{"LUGIA","Guardian of Whirl Islands?","LUGIA","HO-OH","SUICUNE"},{"MISTY","Cerulean Gym Leader?","MISTY","ERIKA","SABRINA"},{"LAPRAS","Second type of Lapras?","ICE","FIRE","ROCK"},{"AZALEA","Town of Slowpoke Well?","AZALEA","VIOLET","OLIVINE"},{"ECRUTEAK","City of Burned Tower?","ECRUTEAK","GOLDENROD","MAHOGANY"},{"SUICUNE","Clear-water legendary beast?","SUICUNE","ENTEI","RAIKOU"},{"WHIRL","Islands of Lugia?","WHIRL ISLANDS","SEAFOAM","CINNABAR"},
    {"TOTODILE","Water Johto starter?","TOTODILE","CHIKORITA","CYNDAQUIL"},{"PALLET","Professor Oak's town?","PALLET TOWN","LAVENDER TOWN","OLIVINE CITY"},{"VIRIDIAN","Leader of Viridian Gym?","GIOVANNI","BROCK","FALKNER"},{"PEWTER","Leader of Pewter Gym?","BROCK","MISTY","BUGSY"},{"VERMILION","Leader of Vermilion Gym?","LT. SURGE","KOGA","CHUCK"},{"CELADON","Leader of Celadon Gym?","ERIKA","WHITNEY","CLAIR"},{"FUCHSIA","Leader of Fuchsia Gym?","KOGA","MORTY","PRYCE"},{"SAFFRON","Leader of Saffron Gym?","SABRINA","JASMINE","BLAINE"},{"CINNABAR","Leader of Cinnabar Gym?","BLAINE","GIOVANNI","FALKNER"},{"INDIGO","Kanto League location?","INDIGO PLATEAU","MT. MOON","NATIONAL PARK"},
    {"BOULDER","Brock gives which Badge?","BOULDERBADGE","CASCADEBADGE","ZEPHYRBADGE"},{"CASCADE","Misty gives which Badge?","CASCADEBADGE","THUNDERBADGE","FOGBADGE"},{"THUNDER","Lt. Surge gives which Badge?","THUNDERBADGE","RAINBOWBADGE","PLAINBADGE"},{"RAINBOW","Erika gives which Badge?","RAINBOWBADGE","SOULBADGE","MINERALBADGE"},{"SOUL","Koga gives which Badge?","SOULBADGE","MARSHBADGE","STORMBADGE"},{"MARSH","Sabrina gives which Badge?","MARSHBADGE","VOLCANOBADGE","GLACIERBADGE"},{"VOLCANO","Blaine gives which Badge?","VOLCANOBADGE","EARTHBADGE","RISINGBADGE"},{"EARTH","Giovanni gives which Badge?","EARTHBADGE","BOULDERBADGE","FOGBADGE"},{"ROCKTUNNEL","Rock Tunnel is by which Route?","ROUTE 10","ROUTE 2","ROUTE 35"},{"POWERPLANT","Power Plant is by which Route?","ROUTE 10","ROUTE 7","ROUTE 43"},
    {"SEAFOAM","Seafoam Islands are on which Route?","ROUTE 20","ROUTE 4","ROUTE 45"},{"VICTORY","Victory Road is reached from?","ROUTE 23","ROUTE 3","ROUTE 42"},{"SILPH","Silph Co. is in which city?","SAFFRON CITY","GOLDENROD CITY","VERMILION CITY"},{"SAFARI","Safari Zone is in which city?","FUCHSIA CITY","AZALEA TOWN","VIOLET CITY"},{"BIKE","Bike Shop city?","CERULEAN CITY","CELADON CITY","OLIVINE CITY"},{"SSANNE","S.S. Anne docks at?","VERMILION CITY","CIANWOOD CITY","FUCHSIA CITY"},{"FLUTE","Poké Flute wakes which Pokémon?","SNORLAX","LAPRAS","ONIX"},{"CUBONE","Cubone primary type?","GROUND","ROCK","FIGHTING"},{"GEODUDE","Geodude has which type?","ROCK","WATER","ELECTRIC"},{"GASTLY","Gastly has which type?","GHOST","PSYCHIC","DARK"},
    {"DRATINI","Dratini primary type?","DRAGON","WATER","FLYING"},{"EEVEE","Eevee primary type?","NORMAL","PSYCHIC","FAIRY"},{"GROWLITHE","Growlithe primary type?","FIRE","GROUND","ELECTRIC"},{"ODDISH","Oddish is a which type?","GRASS","BUG","ICE"},{"ABRA","Abra primary type?","PSYCHIC","GHOST","NORMAL"},{"MAGIKARP","Magikarp primary type?","WATER","DRAGON","FIGHTING"},{"DUGTRIO","Dugtrio primary type?","GROUND","ROCK","STEEL"},{"PINSIR","Pinsir primary type?","BUG","FIGHTING","ROCK"},{"SCYTHER","Scyther has which type?","FLYING","GROUND","WATER"},{"KABUTO","Kabuto has which type?","WATER","BUG","GROUND"},
    {"OMANYTE","Omanyte has which type?","WATER","ICE","GROUND"},{"AERODACTYL","Aerodactyl has which type?","FLYING","DRAGON","BUG"},{"MEW","Mew primary type?","PSYCHIC","FAIRY","NORMAL"},{"MEWTWO","Mewtwo primary type?","PSYCHIC","GHOST","DARK"},{"ZAPDOS","Zapdos has which type?","ELECTRIC","FIRE","ICE"},{"ARTICUNO","Articuno has which type?","ICE","ELECTRIC","FIRE"},{"MOLTRES","Moltres has which type?","FIRE","ICE","ELECTRIC"},{"BULBASAUR","Bulbasaur primary type?","GRASS","FIRE","WATER"},{"CHARMANDER","Charmander primary type?","FIRE","GRASS","WATER"},{"SQUIRTLE","Squirtle primary type?","WATER","FIRE","GRASS"},
    {"NEWBARK","Professor Elm's town?","NEW BARK TOWN","PALLET TOWN","MAHOGANY TOWN"},{"VIOLET","Leader of Violet Gym?","FALKNER","BROCK","BUGSY"},{"BUGSY","Leader of Azalea Gym?","BUGSY","ERIKA","MORTY"},{"WHITNEY","Leader of Goldenrod Gym?","WHITNEY","MISTY","CLAIR"},{"MORTY","Leader of Ecruteak Gym?","MORTY","KOGA","CHUCK"},{"CHUCK","Leader of Cianwood Gym?","CHUCK","LT. SURGE","PRYCE"},{"JASMINE","Leader of Olivine Gym?","JASMINE","SABRINA","ERIKA"},{"PRYCE","Leader of Mahogany Gym?","PRYCE","BLAINE","FALKNER"},{"CLAIR","Leader of Blackthorn Gym?","CLAIR","MISTY","JASMINE"},{"ZEPHYR","Falkner gives which Badge?","ZEPHYRBADGE","FOGBADGE","RAINBOWBADGE"},
    {"HIVE","Bugsy gives which Badge?","HIVEBADGE","PLAINBADGE","THUNDERBADGE"},{"PLAIN","Whitney gives which Badge?","PLAINBADGE","STORMBADGE","SOULBADGE"},{"FOG","Morty gives which Badge?","FOGBADGE","MINERALBADGE","MARSHBADGE"},{"STORM","Chuck gives which Badge?","STORMBADGE","GLACIERBADGE","CASCADEBADGE"},{"MINERAL","Jasmine gives which Badge?","MINERALBADGE","RISINGBADGE","EARTHBADGE"},{"GLACIER","Pryce gives which Badge?","GLACIERBADGE","ZEPHYRBADGE","VOLCANOBADGE"},{"RISING","Clair gives which Badge?","RISINGBADGE","HIVEBADGE","BOULDERBADGE"},{"SPROUT","Sprout Tower is in?","VIOLET CITY","AZALEA TOWN","BLACKTHORN CITY"},{"TIN","Ho-Oh rests in?","TIN TOWER","BURNED TOWER","SILPH CO."},{"LAKERAGE","Red Gyarados appears at?","LAKE OF RAGE","SEAFOAM ISLANDS","SAFARI ZONE"},
    {"RADIO","Radio Tower city?","GOLDENROD CITY","LAVENDER TOWN","FUCHSIA CITY"},{"UNOWN","Unown live in?","RUINS OF ALPH","MT. MORTAR","ROCK TUNNEL"},{"CONTEST","Bug-Catching Contest venue?","NATIONAL PARK","SAFARI ZONE","VICTORY ROAD"},{"MORTAR","Mt. Mortar is near?","ROUTE 42","ROUTE 12","ROUTE 22"},{"SILVER","Red waits atop?","MT. SILVER","MT. MOON","MT. MORTAR"},{"HOOTHOOT","Hoothoot has which type?","FLYING","WATER","FIRE"},{"MAREEP","Mareep primary type?","ELECTRIC","GRASS","ICE"},{"WOOPER","Wooper has which type?","GROUND","ROCK","POISON"},{"MISDREAVUS","Misdreavus primary type?","GHOST","DARK","PSYCHIC"},{"SNEASEL","Sneasel has which type?","ICE","FIRE","ELECTRIC"},
    {"YANMA","Yanma has which type?","FLYING","WATER","GROUND"},{"GLIGAR","Gligar has which type?","GROUND","ROCK","BUG"},{"SWINUB","Swinub has which type?","ICE","FIRE","WATER"},{"HOUNDOUR","Houndour has which type?","DARK","PSYCHIC","FAIRY"},{"LARVITAR","Larvitar has which type?","ROCK","STEEL","GROUND"},{"PORYGON2","Porygon2 primary type?","NORMAL","ELECTRIC","PSYCHIC"},{"LICKITUNG","Lickitung primary type?","NORMAL","FIGHTING","DRAGON"},{"ENTEI","Entei primary type?","FIRE","WATER","ELECTRIC"},{"RAIKOU","Raikou primary type?","ELECTRIC","FIRE","ICE"},{"HO_OH","Ho-Oh has which type?","FLYING","PSYCHIC","DRAGON"},
    {"CELEBI","Celebi has which type?","GRASS","WATER","FIRE"},{"KURT","Apricorn Ball maker?","KURT","BILL","OAK"},{"STEELIX","Steelix has which type?","STEEL","ROCK","ICE"},{"SCIZOR","Scizor has which type?","STEEL","FIRE","ELECTRIC"},{"KINGDRA","Kingdra has which type?","DRAGON","ICE","GROUND"},{"CROBAT","Crobat has which type?","FLYING","BUG","DARK"},{"POLITOED","Politoed primary type?","WATER","GRASS","FIGHTING"},{"ESPEON","Espeon primary type?","PSYCHIC","DARK","GHOST"},{"UMBREON","Umbreon primary type?","DARK","PSYCHIC","GHOST"},{"CHIKORITA","Grass Johto starter?","CHIKORITA","TOTODILE","CYNDAQUIL"},
  }
  assert(#FACTS==110,"BLUE legacy question prefix changed")
  C.LEGACY_QUESTION_COUNT=110
  -- Keyed records are appended after the immutable 110-row legacy prefix.
  -- Every answer is a generation-stable fact; localized labels retain the
  -- same semantic value and are permuted together at presentation time.
  local EXTRA_FACTS={
    {id="KA_BLUE_X_KANTO_001",category="KANTO",en="Pokemon at National Dex #025?",de="Pokemon im Nationaldex Nr. 025?",right="PIKACHU",d1="RAICHU",d2="EEVEE"},
    {id="KA_BLUE_X_KANTO_002",category="KANTO",en="Pokemon at National Dex #001?",de="Pokemon im Nationaldex Nr. 001?",right="BULBASAUR",d1="IVYSAUR",d2="CHARMANDER"},
    {id="KA_BLUE_X_KANTO_003",category="KANTO",en="Leader of Cerulean Gym?",de="Leitung der Arena von Cerulean?",right="MISTY",d1="ERIKA",d2="SABRINA"},
    {id="KA_BLUE_X_KANTO_004",category="KANTO",en="Region of Pallet Town?",de="Region von Pallet Town?",right="KANTO",d1="JOHTO",d2="SINNOH"},
    {id="KA_BLUE_X_KANTO_005",category="KANTO",en="Ice-linked Kanto legendary bird?",de="Kantos legendaerer Eisvogel?",right="ARTICUNO",d1="ZAPDOS",d2="MOLTRES"},
    {id="KA_BLUE_X_KANTO_006",category="KANTO",en="Charmander's primary type?",de="Charmanders Primaertyp?",right="FIRE",d1="WATER",d2="GRASS"},
    {id="KA_BLUE_X_KANTO_007",category="KANTO",en="Leader of Pewter Gym?",de="Leitung der Arena von Pewter?",right="BROCK",d1="MISTY",d2="KOGA"},
    {id="KA_BLUE_X_KANTO_008",category="KANTO",en="Town of Pokemon Tower?",de="Stadt des Pokemon Tower?",right="LAVENDER TOWN",d1="PALLET TOWN",d2="FUCHSIA CITY"},
    {id="KA_BLUE_X_KANTO_009",category="KANTO",en="Mewtwo's National Dex number?",de="Mewtwos Nationaldexnummer?",right="150",d1="149",d2="151"},
    {id="KA_BLUE_X_KANTO_010",category="KANTO",en="Squirtle evolves into?",de="Squirtle entwickelt sich zu?",right="WARTORTLE",d1="CHARMELEON",d2="IVYSAUR"},

    {id="KA_BLUE_X_JOHTO_001",category="JOHTO",en="Pokemon at National Dex #152?",de="Pokemon im Nationaldex Nr. 152?",right="CHIKORITA",d1="BAYLEEF",d2="CYNDAQUIL"},
    {id="KA_BLUE_X_JOHTO_002",category="JOHTO",en="Johto's Fire starter?",de="Johtos Feuer-Starter?",right="CYNDAQUIL",d1="CHIKORITA",d2="TOTODILE"},
    {id="KA_BLUE_X_JOHTO_003",category="JOHTO",en="Johto's Water starter?",de="Johtos Wasser-Starter?",right="TOTODILE",d1="CHIKORITA",d2="CYNDAQUIL"},
    {id="KA_BLUE_X_JOHTO_004",category="JOHTO",en="Leader of Violet Gym?",de="Leitung der Arena von Violet?",right="FALKNER",d1="BUGSY",d2="MORTY"},
    {id="KA_BLUE_X_JOHTO_005",category="JOHTO",en="City of the Burned Tower?",de="Stadt des Burned Tower?",right="ECRUTEAK",d1="GOLDENROD",d2="OLIVINE"},
    {id="KA_BLUE_X_JOHTO_006",category="JOHTO",en="Guardian of Whirl Islands?",de="Waechter der Whirl Islands?",right="LUGIA",d1="HO-OH",d2="SUICUNE"},
    {id="KA_BLUE_X_JOHTO_007",category="JOHTO",en="Leader of Goldenrod Gym?",de="Leitung der Arena von Goldenrod?",right="WHITNEY",d1="JASMINE",d2="CLAIR"},
    {id="KA_BLUE_X_JOHTO_008",category="JOHTO",en="Mareep's primary type?",de="Mareeps Primaertyp?",right="ELECTRIC",d1="GRASS",d2="WATER"},
    {id="KA_BLUE_X_JOHTO_009",category="JOHTO",en="Tower where Ho-Oh rests?",de="Turm, in dem Ho-Oh ruht?",right="TIN TOWER",d1="BURNED TOWER",d2="SPROUT TOWER"},
    {id="KA_BLUE_X_JOHTO_010",category="JOHTO",en="Leader of Blackthorn Gym?",de="Leitung der Arena von Blackthorn?",right="CLAIR",d1="PRYCE",d2="JASMINE"},

    {id="KA_BLUE_X_GENERAL_001",category="GENERAL",en="FIRE is effective against?",de="FEUER ist effektiv gegen?",right="GRASS",d1="WATER",d2="FIRE"},
    {id="KA_BLUE_X_GENERAL_002",category="GENERAL",en="WATER is effective against?",de="WASSER ist effektiv gegen?",right="FIRE",d1="GRASS",d2="WATER"},
    {id="KA_BLUE_X_GENERAL_003",category="GENERAL",en="Type immune to ELECTRIC moves?",de="Typ immun gegen ELEKTRO-Attacken?",right="GROUND",d1="WATER",d2="FLYING"},
    {id="KA_BLUE_X_GENERAL_004",category="GENERAL",en="Maximum Pokemon in a full party?",de="Maximale Pokemon in einem vollen Team?",right="6",d1="5",d2="7"},
    {id="KA_BLUE_X_GENERAL_005",category="GENERAL",en="Item family used to catch Pokemon?",de="Itemfamilie zum Fangen von Pokemon?",right="POKE BALL",d1="POTION",d2="ANTIDOTE"},
    {id="KA_BLUE_X_GENERAL_006",category="GENERAL",en="Item that revives a fainted Pokemon?",de="Item zur Wiederbelebung eines Pokemon?",right="REVIVE",d1="POTION",d2="ANTIDOTE"},
    {id="KA_BLUE_X_GENERAL_007",category="GENERAL",en="Item that cures poison?",de="Item gegen Vergiftung?",right="ANTIDOTE",d1="AWAKENING",d2="PARLYZ HEAL"},
    {id="KA_BLUE_X_GENERAL_008",category="GENERAL",en="Place that heals the whole party?",de="Ort, der das ganze Team heilt?",right="POKEMON CENTER",d1="POKE MART",d2="GYM"},
    {id="KA_BLUE_X_GENERAL_009",category="GENERAL",en="System that stores reserve Pokemon?",de="System zur Lagerung weiterer Pokemon?",right="PC",d1="POKEDEX",d2="TOWN MAP"},
    {id="KA_BLUE_X_GENERAL_010",category="GENERAL",en="Type effective against WATER?",de="Typ effektiv gegen WASSER?",right="ELECTRIC",d1="FIRE",d2="ROCK"},

    {id="KA_BLUE_X_SINNOH_001",category="SINNOH",en="Sinnoh's Grass starter?",de="Sinnohs Pflanzen-Starter?",right="TURTWIG",d1="CHIMCHAR",d2="PIPLUP"},
    {id="KA_BLUE_X_SINNOH_002",category="SINNOH",en="Sinnoh's Fire starter?",de="Sinnohs Feuer-Starter?",right="CHIMCHAR",d1="TURTWIG",d2="PIPLUP"},
    {id="KA_BLUE_X_SINNOH_003",category="SINNOH",en="Sinnoh's Water starter?",de="Sinnohs Wasser-Starter?",right="PIPLUP",d1="TURTWIG",d2="CHIMCHAR"},
    {id="KA_BLUE_X_SINNOH_004",category="SINNOH",en="Leader of Oreburgh Gym?",de="Leitung der Arena von Oreburgh?",right="ROARK",d1="BYRON",d2="VOLKNER"},
    {id="KA_BLUE_X_SINNOH_005",category="SINNOH",en="Leader of Eterna Gym?",de="Leitung der Arena von Eterna?",right="GARDENIA",d1="MAYLENE",d2="CANDICE"},
    {id="KA_BLUE_X_SINNOH_006",category="SINNOH",en="Leader of Veilstone Gym?",de="Leitung der Arena von Veilstone?",right="MAYLENE",d1="FANTINA",d2="GARDENIA"},
    {id="KA_BLUE_X_SINNOH_007",category="SINNOH",en="Leader of Pastoria Gym?",de="Leitung der Arena von Pastoria?",right="CRASHER WAKE",d1="ROARK",d2="BYRON"},
    {id="KA_BLUE_X_SINNOH_008",category="SINNOH",en="Leader of Sunyshore Gym?",de="Leitung der Arena von Sunyshore?",right="VOLKNER",d1="ROARK",d2="CANDICE"},
    {id="KA_BLUE_X_SINNOH_009",category="SINNOH",en="Legendary Pokemon associated with time?",de="Legendaeres Pokemon der Zeit?",right="DIALGA",d1="PALKIA",d2="GIRATINA"},
    {id="KA_BLUE_X_SINNOH_010",category="SINNOH",en="Legendary Pokemon associated with space?",de="Legendaeres Pokemon des Raums?",right="PALKIA",d1="DIALGA",d2="GIRATINA"},
  }
  for _,row in ipairs(EXTRA_FACTS) do FACTS[#FACTS+1]=row end
  local function question(row, n)
    local keyed=row.id~=nil
    local id,prompt,category=keyed and row.id or row[1],keyed and row.en or row[2],
      keyed and row.category or "LEGACY"
    local canonical=keyed and {row.right,row.d1,row.d2} or {row[3],row[4],row[5]}
    local canonicalDe=keyed and {row.rightDe or row.right,row.d1De or row.d1,row.d2De or row.d2} or nil
    local choices={canonical[1],canonical[2],canonical[3]}; local correct=(n-1)%3+1
    choices[1],choices[correct]=choices[correct],choices[1]
    local choicesDe
    if canonicalDe then
      choicesDe={canonicalDe[1],canonicalDe[2],canonicalDe[3]}
      choicesDe[1],choicesDe[correct]=choicesDe[correct],choicesDe[1]
    end
    return {id=id,prompt=prompt,promptDe=keyed and row.de or nil,
      choices=choices,choicesDe=choicesDe,correct=correct,category=category,
      legacy=not keyed,answer=canonical[1],canonical=canonical,
      canonicalDe=canonicalDe}
  end
  local QUESTIONS={}; for n,row in ipairs(FACTS) do QUESTIONS[n]=question(row,n) end
  assert(#QUESTIONS==150,"BLUE expanded catalogue needs 150 questions")
  C.questions = QUESTIONS
  local function questionById(id)
    for _,q in ipairs(QUESTIONS) do if q.id==id then return q end end
  end
  local function shuffledQuestionIndices(seed)
    local out={};for i=1,#QUESTIONS do out[i]=i end
    seed=math.floor(tonumber(seed) or 1)%HASH_MOD;if seed<=0 then seed=1 end
    for i=#out,2,-1 do
      seed=(seed*48271)%HASH_MOD
      local j=seed%i+1
      out[i],out[j]=out[j],out[i]
    end
    return out
  end
  local function balancedCorrectSlots(seed)
    assert(#QUESTIONS%3==0,"BLUE answer slots need a catalogue divisible by three")
    local slots={}
    for correct=1,3 do
      for _=1,#QUESTIONS/3 do slots[#slots+1]=correct end
    end
    seed=math.floor(tonumber(seed) or 1)%HASH_MOD;if seed<=0 then seed=1 end
    for i=#slots,2,-1 do
      seed=(seed*48271)%HASH_MOD
      local j=seed%i+1
      slots[i],slots[j]=slots[j],slots[i]
    end
    return slots
  end
  local function presentedQuestion(q,correct)
    correct=math.max(1,math.min(3,math.floor(tonumber(correct) or 1)))
    local choices={q.canonical[1],q.canonical[2],q.canonical[3]}
    choices[1],choices[correct]=choices[correct],choices[1]
    local choicesDe
    if q.canonicalDe then
      choicesDe={q.canonicalDe[1],q.canonicalDe[2],q.canonicalDe[3]}
      choicesDe[1],choicesDe[correct]=choicesDe[correct],choicesDe[1]
    end
    return {id=q.id,prompt=q.prompt,promptDe=q.promptDe,choices=choices,
      choicesDe=choicesDe,correct=correct,answer=q.answer,
      category=q.category,legacy=q.legacy}
  end
  -- They are intentionally separate map objects.  The fifth is still in the
  -- Tidal Depths: answering it is the gate that opens the Shrine approach.
  C.statues = {
    -- Every memory is deliberately off the mandatory entry-to-exit line.
    -- These cells sit at the closed end of native-rock side passages; the
    -- matching branch mouths below let QA prove that each discovery needs a
    -- real decision and several D-pad steps rather than a drive-by prompt.
    HALL = { map=ID.HALL, x=25, y=22, text="TEXT_KA_HEVO_BLUE_STATUE_HALL", sight=1 },
    ICE_NORTH = { map=ID.ICE, x=11, y=5, text="TEXT_KA_HEVO_BLUE_STATUE_ICE_NORTH", sight=2 },
    ICE_DEEP = { map=ID.ICE, x=37, y=31, text="TEXT_KA_HEVO_BLUE_STATUE_ICE_DEEP", sight=3 },
    DEPTHS_WEST = { map=ID.DEPTHS, x=3, y=19, text="TEXT_KA_HEVO_BLUE_STATUE_DEPTHS_WEST", sight=4 },
    DEPTHS_EAST = { map=ID.DEPTHS, x=47, y=9, text="TEXT_KA_HEVO_BLUE_STATUE_DEPTHS_EAST", sight=5 },
  }
  C.statueBranches = {
    HALL={map=ID.HALL,mouth={x=16,y=19},
      gate={{x=16,y=20},{x=17,y=20}},minDepth=8,turns=2},
    ICE_NORTH={map=ID.ICE,mouth={x=20,y=4},
      gate={{x=20,y=3},{x=21,y=3}},minDepth=8,turns=2},
    ICE_DEEP={map=ID.ICE,mouth={x=36,y=27},
      gate={{x=36,y=28},{x=37,y=28}},minDepth=8,turns=2},
    DEPTHS_WEST={map=ID.DEPTHS,mouth={x=10,y=22},
      gate={{x=9,y=22},{x=9,y=23}},minDepth=8,turns=2},
    DEPTHS_EAST={map=ID.DEPTHS,mouth={x=40,y=12},
      gate={{x=42,y=12},{x=42,y=13}},minDepth=10,turns=2},
  }
  function C.shrineOpen()
    local s=state()
    return s and s.sight >= 5 and s.solved.DEPTHS_EAST == true
  end
  -- Shared-seal diagnostics expose only the authored route gates.  Floor
  -- lights and the optional SWAMPERTITE cache are intentionally not part of
  -- this report or of completion authority.
  function C.completionProgress(save)
    local run
    if mod.save and type(mod.save.get)=="function" then
      run=mod.save:get("hevo_run")
    elseif type(save)=="table" then
      run=save.hevo_run
    end
    local s=type(run)=="table"
      and type(run.hidden_evolution_blue)=="table"
      and run.hidden_evolution_blue or {}
    local solved=type(s.solved)=="table" and s.solved or {}
    local switches=type(s.switches)=="table" and s.switches or {}
    return {
      statues=math.max(0,math.min(5,math.floor(tonumber(s.sight) or 0))),
      total=5,
      finalStatue=solved.DEPTHS_EAST==true,
      switches={HALL=switches.HALL==true,ICE=switches.ICE==true,
        DEPTHS=switches.DEPTHS==true},
    }
  end
  function C.nextQuestion(statue)
    local s=state(); if statue and s.solved[statue] then return nil,"solved" end
    local pending=statue and s.pending[statue]
    local pendingId=type(pending)=="table" and pending.id or pending
    local pendingQuestion=questionById(pendingId)
    if pendingQuestion and not s.asked[pendingQuestion.id] then
      return presentedQuestion(pendingQuestion,
        type(pending)=="table" and pending.correct or pendingQuestion.correct)
    end
    if statue then s.pending[statue]=nil end
    local order=shuffledQuestionIndices(s.questionSeed+s.cycle*104729)
    -- The complete cycle contains exactly 50 answers in each button, but its
    -- seeded shuffle avoids the former visible 1/2/3 rotation.  Persisting the
    -- selected slot in pending keeps save/reload stable.
    local correctSlots=balancedCorrectSlots(s.questionSeed+s.cycle*130363)
    for offset=0,#order-1 do
      local index=order[(s.questionCursor+offset)%#order+1]
      local q=QUESTIONS[index]
      if not s.asked[q.id] then
        local correct=correctSlots[s.questionCursor%#correctSlots+1]
        if statue then s.pending[statue]={id=q.id,correct=correct} end
        saveRun(s)
        return presentedQuestion(q,correct)
      end
    end
    -- Exhausting a cycle after wrong answers never strands the run: only
    -- questions repeat next cycle, while solved statues stay solved.
    s.asked={};s.pending={};s.questionCursor=0;s.cycle=s.cycle+1;saveRun(s)
    local q=C.nextQuestion(statue)
    return q,"new_cycle"
  end
  function C.answer(statue, questionId, choice)
    local s, q = state(), nil
    for _, row in ipairs(QUESTIONS) do if row.id == questionId then q=row break end end
    if not q then return false, "question" end
    if s.asked[q.id] then return false, "repeat" end
    local pending=s.pending[statue]
    local pendingId=type(pending)=="table" and pending.id or pending
    if not pendingId or pendingId~=questionId then return false,"pending" end
    local expected=type(pending)=="table" and pending.correct or q.correct
    s.asked[q.id], s.answered[q.id] = true, choice
    s.pending[statue]=nil;s.questionCursor=s.questionCursor+1
    local correct = choice == expected
    if correct and not s.solved[statue] then
      s.solved[statue]=true; s.sight=s.sight+1
      if mod.world and mod.world.setFlag then mod.world:setFlag(C.flags.sight.."_"..s.sight,true) end
      if statue == "DEPTHS_EAST" and s.sight >= 5 and mod.world and mod.world.setFlag then mod.world:setFlag(C.flags.door,true) end
    end
    saveRun(s)
    if correct then C.refreshSight() end
    return correct, correct and "sight" or "mist"
  end
  local function show(game, message, done)
    if opts.showText then return opts.showText(game,message,done) end
    game.stack:push(require("src.render.TextBox").new(game,message,done)); return true
  end
  function C.ask(statue, game, done)
    local q, why=C.nextQuestion(statue); if not q then return show(game,tr("This statue already\nshines through the ice.","Diese Statue leuchtet\nbereits durch das Eis."),done),why end
    local labels={}
    for index,label in ipairs(q.choices) do
      labels[index]=tr(label,q.choicesDe and q.choicesDe[index] or label)
    end
    local prompt=tr(q.prompt,q.promptDe or q.prompt)
    local rows={}; for i,label in ipairs(labels) do rows[#rows+1]={value=i,label=label} end
    local finished=false
    local function finish()
      if finished then return end
      finished=true
      if done then done() end
    end
    local function answer(index)
      local ok=C.answer(statue,q.id,index)
      show(game,ok and tr("The frost statue records\nthis memory.",
        "Die Froststatue bewahrt\ndiese Erinnerung.") or tr(
        "Cold mist gathers.\nThe path remains.",
        "Kalter Nebel zieht auf.\nDer Pfad bleibt offen."),finish)
    end
    local shown,screen=pcall(function()
      if not (questionUi and type(questionUi.showQuestionText)=="function") then
        return false,"question-ui"
      end
      return questionUi.showQuestionText(game,prompt,function()
      if not (questionUi and type(questionUi.openQuestionMenu)=="function") then
        finish();return
      end
      local rank=C.statues[statue] and C.statues[statue].sight
      if not rank then finish();return end
      local opened,menu=pcall(questionUi.openQuestionMenu,game,
        "KYOGRE-TEST "..rank.."/5",prompt,rows,{
          defaultIndex=1,
          seconds=20,
          onTimeout=function()answer(q.correct%#rows+1)end,
          onChoose=function(row)
            if type(row)~="table" or type(row.value)~="number"
                or row.value%1~=0 or row.value<1 or row.value>#rows then
              finish();return
            end
            answer(row.value)
          end,
        })
      if not opened or type(menu)~="table" then finish() end
      end,opts.showText)
    end)
    if not shown or screen==false then finish() end
    return true,q
  end
  local function questionIds()
    local s=state(); local ids={}; for id in pairs(s and s.asked or {}) do ids[#ids+1]=id end; table.sort(ids); return ids
  end
  function C.claimAll(game)
    if not C.isBlue(game) then return {},"character" end
    if not C.shrineOpen() then return {},"sight" end
    local adapter=opts.legacyDungeonAdapter
    if not (adapter and adapter.finalize) then return {},"adapter" end
    local ok,result=adapter.finalize(game,{character="BLUE",questionIds=questionIds()})
    if not ok then return {},result end
    local granted={}
    for _,package in ipairs(result.packages or {}) do
      for _,target in ipairs(package.targets) do granted[#granted+1]=target.target end
    end
    return granted
  end
  function C.claimSwampertite(game)
    if not C.isBlue(game) then return false,"character" end
    local adapter=opts.legacyDungeonAdapter
    if not (adapter and type(adapter.claimSecret)=="function") then return false,"secret-api" end
    return adapter.claimSecret(game,{character="BLUE",stone="SWAMPERTITE",
      secret="KA_HEVO_BLUE_SWAMPERTITE_CACHE"})
  end

  -- The glacier's intended route deliberately folds back on itself.  Each
  -- named shelf is a non-ice brake cell; the wrong branches end in visible
  -- native holes and return to START instead of creating a softlock.
  local ICE_GRAPH = {
    START={RIGHT="LOWER_BRAKE"}, LOWER_BRAKE={UP="WEST_BRAKE",RIGHT="FALL_A"},
    WEST_BRAKE={LEFT="FALL_B",UP="NORTH_BRAKE"},
    NORTH_BRAKE={RIGHT="EAST_BRAKE"}, EAST_BRAKE={DOWN="DEEP_BRAKE",RIGHT="FALL_C"},
    DEEP_BRAKE={RIGHT="STRENGTH_GATE"}, STRENGTH_GATE={RIGHT="TIDE_BRAKE"},
    TIDE_BRAKE={UP="DEPTH_GATE"}, FALL_A={RIGHT="START"}, FALL_B={RIGHT="START"},
    FALL_C={RIGHT="START"}, DEPTH_GATE={},
  }
  C.iceGraph = ICE_GRAPH
  function C.simulateIceRoute(moves)
    local at="START"; for _,dir in ipairs(moves) do at=assert(ICE_GRAPH[at][dir],"invalid ice move") end; return at
  end
  local HOLES = {
    -- Every false-line brake now places the paired fracture within the
    -- current sight-3 cone.  The player can read the dark break before
    -- committing instead of discovering an invisible remote death tile.
    ["29,28"]={map=ID.ICE,x=3,y=33}, ["30,29"]={map=ID.ICE,x=3,y=33},
    ["4,16"]={map=ID.ICE,x=3,y=33}, ["3,17"]={map=ID.ICE,x=3,y=33},
    ["41,6"]={map=ID.ICE,x=3,y=33}, ["42,7"]={map=ID.ICE,x=3,y=33},
  }
  C.holes = HOLES
  -- Validate canonical Kanto data rather than trusting numeric aliases.  The
  -- acceptance test also checks the exact hole/warp cells after registration.
  function C.validateCavern(data)
    local cave=data and data.tilesets and data.tilesets.CAVERN
    if type(cave)~="table" or type(cave.blocks)~="table" or type(cave.walkable)~="table" then return false,"missing CAVERN" end
    local walk={}; for _,tile in ipairs(cave.walkable) do walk[tile]=true end
    local function cellTiles(block)
      local row=cave.blocks[block+1]
      return row and {row[5],row[7],row[13],row[15]}
    end
    local function allWalkable(block)
      local tiles=cellTiles(block); if not tiles then return false end
      for _,tile in ipairs(tiles) do if not walk[tile] then return false end end
      return true
    end
    if not allWalkable(FLOOR) then return false,"floor is not walkable" end
    if not allWalkable(ICE) then return false,"ice is not walkable" end
    local wall=cellTiles(WALL); if not wall then return false,"wall is missing" end
    for _,tile in ipairs(wall) do if walk[tile] then return false,"wall is walkable" end end
    local water=cellTiles(WATER); if not water then return false,"water is missing" end
    for _,tile in ipairs(water) do if tile~=0x14 then return false,"water is not native CAVERN water" end end
    local shore=cellTiles(SOUTH_SHORE)
    if not shore or shore[1]~=0x05 or shore[2]~=0x05
        or shore[3]~=0x15 or shore[4]~=0x15 then
      return false,"native south shore drift"
    end
    local chokePatterns={
      {NARROW_V_LEFT,{0x05,0x17,0x05,0x17}},
      {NARROW_V_RIGHT,{0x12,0x05,0x12,0x05}},
      {NARROW_H_TOP,{0x05,0x05,0x10,0x10}},
      {NARROW_H_BOTTOM,{0x10,0x10,0x05,0x05}},
    }
    for _,spec in ipairs(chokePatterns) do
      local actual=cellTiles(spec[1]);if not actual then return false,"native choke missing" end
      for index,want in ipairs(spec[2]) do
        if actual[index]~=want then return false,"native choke drift" end
      end
    end
    local warp=cellTiles(WARP); if not warp or warp[4]~=0x1a then return false,"native stair warp drift" end
    local holes={
      {HOLE_TL,1},{HOLE_TR,2},{HOLE_BL,3},{HOLE_BR,4},
    }
    for _,spec in ipairs(holes) do
      local cells=cellTiles(spec[1]); if not cells or cells[spec[2]]~=0x22 then return false,"native hole drift" end
    end
    return true
  end
  C.validateIcePath = C.validateCavern -- compatibility surface for old QA callers
  local function makeLayouts()
    local function room(w,h,fill)
      -- Default to native rock mass rather than empty black meta-blocks.  The
      -- carved route therefore reads as a dense Kanto cavern under FLASH,
      -- while WATER remains an explicit background for the tidal floor.
      local blocks,put=grid(w,h,fill or WALL)
      for x=0,w-1 do put(x,0,WALL);put(x,h-1,WALL) end
      for y=0,h-1 do put(0,y,WALL);put(w-1,y,WALL) end
      return blocks,put
    end
    local function rect(put,x1,y1,x2,y2,block)
      for y=y1,y2 do for x=x1,x2 do put(x,y,block or FLOOR) end end
    end
    local function pad(put,x,y)
      assert(x%2==1 and y%2==1,"BLUE stair uses CAVERN block 124 lower-right cell")
      put(math.floor(x/2),math.floor(y/2),WARP)
    end
    local function hole(put,x,y)
      local block=(x%2==0 and y%2==0) and HOLE_TL
        or (x%2==1 and y%2==0) and HOLE_TR
        or (x%2==0 and y%2==1) and HOLE_BL or HOLE_BR
      put(math.floor(x/2),math.floor(y/2),block)
    end

    -- Threshold: the route deliberately folds through two return loops before
    -- reaching the stair.  The western frost pocket and eastern dry shelf are
    -- fair landmark dead ends, so darkness asks for orientation instead of a
    -- blind top-right march.  Selected native wall transitions pinch those
    -- construction lanes to one player cell and alternate their alignment,
    -- so the result no longer reads as a uniform two-cell raster.
    local threshold,pt=room(20,16)
    for _,r in ipairs({{1,13,4,14},{4,10,4,14},{1,10,8,10},
      {1,7,1,10},{1,7,5,7},{5,7,5,10},
      {8,6,8,10},{8,6,14,6},{11,3,11,6},
      {11,3,16,3},{16,3,16,5},{14,5,16,5},{14,5,14,6},
      {6,3,11,3},{6,1,6,3},{6,1,12,1},
      {3,5,3,7},{8,8,11,8}}) do rect(pt,r[1],r[2],r[3],r[4]) end
    for _,p in ipairs({{3,5},{11,8},{1,8},{15,5},{7,3},{10,1}}) do pt(p[1],p[2],ICE) end
    pt(5,8,BRAKE);pt(8,7,BRAKE);pt(11,5,BRAKE);pt(14,3,BRAKE)
    pt(4,12,NARROW_V_LEFT);pt(6,10,NARROW_H_TOP)
    pt(10,6,NARROW_H_BOTTOM);pt(11,4,NARROW_V_RIGHT)
    -- Long one-block construction lines otherwise render as uniform
    -- two-cell raster corridors.  These aligned native half-blocks create
    -- honest one-cell squeezes, with full blocks retained at every turn,
    -- junction and landmark so the route remains readable in darkness.
    pt(4,11,NARROW_V_LEFT);pt(4,13,NARROW_V_LEFT)
    pt(2,10,NARROW_H_TOP);pt(3,10,NARROW_H_TOP);pt(7,10,NARROW_H_TOP)
    pt(2,7,NARROW_H_BOTTOM);pt(3,7,NARROW_H_BOTTOM);pt(4,7,NARROW_H_BOTTOM)
    pt(5,8,NARROW_V_LEFT);pt(5,9,NARROW_V_LEFT)
    pt(9,8,NARROW_H_TOP);pt(10,8,NARROW_H_TOP)
    pt(9,6,NARROW_H_BOTTOM);pt(12,6,NARROW_H_TOP);pt(13,6,NARROW_H_TOP)
    pt(8,3,NARROW_H_TOP);pt(13,3,NARROW_H_TOP);pt(9,1,NARROW_H_BOTTOM)
    -- Threshold light faults occupy the unused western and central rock.  A
    -- third relic uses the already-authored eastern shelf, so the first cave
    -- also has lower/middle/upper light progression without road-side gifts.
    pt(3,11,NARROW_H_BOTTOM);pt(2,11,NARROW_H_BOTTOM);pt(1,11,FLOOR)
    pt(10,5,NARROW_H_TOP);pt(9,5,FLOOR)
    pad(pt,3,29);pad(pt,25,3)

    -- Hall: the first native Strength lesson.  A compact lower ring teaches
    -- the statue/reset landmarks before feeding the straight boulder groove.
    -- Beyond the rune, a second ring makes the side stair a discovered exit,
    -- not the same repeated north-east target used by every floor.
    local hall,ph=room(22,18)
    for _,r in ipairs({{1,14,5,16},{5,9,5,14},
      {2,9,10,9},{2,6,2,9},{2,6,10,6},{10,6,10,9},
      {5,12,15,12},{15,12,18,12},{18,8,18,12},{18,8,20,8},
      {13,4,18,4},{13,4,13,8},{13,8,18,8},{10,6,11,6}}) do
      rect(ph,r[1],r[2],r[3],r[4])
    end
    -- The first memory is not on the lower ring.  A bent, dry spur leaves
    -- that ring at block (7,9), turns east and ends in a small rock pocket;
    -- approaching the statue therefore means choosing and later retracing a
    -- genuine side arm before the Strength lesson continues.
    rect(ph,7,9,7,10,FLOOR);rect(ph,7,10,10,10,FLOOR)
    ph(9,10,NARROW_H_TOP)
    ph(10,11,NARROW_H_TOP);ph(11,11,NARROW_H_TOP);ph(12,11,NARROW_H_TOP)
    -- The round Strength mark stays beside the push groove but no longer
    -- touches the statue cul-de-sac at block 12,11.
    ph(14,11,SWITCH_BR);ph(15,12,WALL)
    for _,p in ipairs({{3,6},{8,9},{10,6},{13,6},{16,4},{18,10}}) do ph(p[1],p[2],ICE) end
    ph(5,9,BRAKE);ph(18,8,BRAKE);pad(ph,3,33);pad(ph,41,17)
    ph(5,13,NARROW_V_LEFT);ph(5,10,NARROW_V_RIGHT)
    ph(7,9,NARROW_H_TOP);ph(7,6,NARROW_H_BOTTOM)
    ph(13,5,NARROW_V_LEFT);ph(13,7,NARROW_V_RIGHT)
    -- Preserve the broad Strength groove at y=12, but break the approach
    -- rings into offset one-cell runs.  Full blocks at x=5/x=10 and around
    -- the upper turns keep both return loops and all NPC approach cells.
    ph(5,11,NARROW_V_RIGHT)
    ph(3,9,NARROW_H_TOP);ph(4,9,NARROW_H_TOP)
    ph(6,9,NARROW_H_TOP);ph(9,9,NARROW_H_TOP)
    ph(7,9,NARROW_H_TOP);ph(8,9,FLOOR);ph(10,9,NARROW_H_TOP)
    ph(2,7,NARROW_V_LEFT);ph(2,8,NARROW_V_LEFT)
    ph(4,6,NARROW_H_BOTTOM);ph(5,6,NARROW_H_BOTTOM);ph(6,6,NARROW_H_BOTTOM)
    ph(8,6,NARROW_H_BOTTOM);ph(9,6,NARROW_H_BOTTOM)
    ph(10,7,NARROW_V_RIGHT);ph(10,8,NARROW_V_RIGHT)
    ph(14,4,NARROW_H_TOP);ph(15,4,NARROW_H_TOP)
    ph(16,8,NARROW_H_BOTTOM)
    -- The boulder travels on the lower native row, so this half-block keeps
    -- every Strength push cell while breaking the last 14-cell-wide ribbon.
    ph(9,12,NARROW_H_BOTTOM);ph(12,12,NARROW_H_BOTTOM);ph(16,12,NARROW_H_BOTTOM)
    -- A west-side light pocket leaves the entry clearing through a one-cell
    -- vertical fissure.  It reconnects nowhere and never touches the boulder
    -- groove, so the relic costs a real retreat to the first junction.
    ph(4,13,NARROW_V_LEFT);ph(4,12,NARROW_V_LEFT);ph(4,11,FLOOR)

    -- Glacier: one enormous connected native CAVERN ice basin, not a chain
    -- of narrow Ice-Path ribbons.  Tiny dry shelves are the only brakes.  The
    -- safe line folds across the whole basin; at its lower, western and upper
    -- decisions, the wrong direction continues over uninterrupted ice into
    -- one of three paired native holes.  Every hole returns to this floor's
    -- entrance.  Sparse rock reefs give the broad field landmarks without
    -- splitting the ice into disconnected strips or importing Johto art.
    local ice,pi=room(26,18)
    rect(pi,2,2,23,15,ICE)
    rect(pi,24,1,24,11,ICE)
    -- Entry tunnel, Strength island and exit cap are the deliberately small
    -- dry interruptions in the otherwise continuous ice.
    rect(pi,1,14,3,16,FLOOR)
    rect(pi,12,11,18,13,FLOOR)
    rect(pi,22,1,24,2,FLOOR)
    -- Memory two hides in a long shelf cut into the north rock, reached only
    -- by braking at (10,2) and leaving the broad ice basin.  Memory three is
    -- deeper still: an L-shaped dry cleft leaves the Strength island at
    -- (16,13) and terminates against the southern cavern wall.  Neither
    -- object is a marker on the safe sliding line.
    rect(pi,7,1,10,1,FLOOR);pi(10,2,FLOOR)
    rect(pi,5,2,7,2,FLOOR);pi(4,2,WALL);pi(8,2,WALL);pi(9,2,WALL)
    rect(pi,5,3,7,3,WALL)
    -- The southern cleft is a real switchback: a top-only native shelf runs
    -- east, the full corner turns down, and bottom-only shelves return west
    -- to the hidden statue.  Adjacent rows cannot be cut across.
    pi(18,14,NARROW_H_TOP);pi(19,14,NARROW_H_TOP);pi(20,14,NARROW_H_TOP)
    pi(21,14,FLOOR)
    pi(18,15,NARROW_H_BOTTOM);pi(19,15,NARROW_H_BOTTOM);pi(20,15,NARROW_H_BOTTOM)
    pi(21,15,FLOOR)
    pi(19,13,WALL);pi(20,13,WALL);pi(21,13,WALL)
    pi(17,14,WALL);pi(17,15,WALL);pi(22,14,WALL);pi(22,15,WALL)
    -- Native wall reefs are compact enough that the basin still has one very
    -- large connected ice component, while their silhouettes break the view
    -- into recognisable sectors at the five expanding sight levels.
    rect(pi,7,5,8,6,WALL)
    rect(pi,14,4,15,5,WALL)
    rect(pi,7,10,8,11,WALL)
    rect(pi,20,7,21,8,WALL)
    -- A native rock breakwater keeps the exit shaft genuinely behind the
    -- Strength rune.  The main basin west of it remains one enormous ice
    -- component; solving the rune opens its sole cell-wide eastern breach.
    rect(pi,23,1,23,15,WALL)
    -- Main sliding line and its grippy turning shelves.  Their coordinates
    -- preserve the existing zellweise slide contract used by real input QA.
    pi(4,14,ICE)
    for _,p in ipairs({{12,14},{12,8},{4,8},{4,3},{18,3},{18,11},{24,11}}) do pi(p[1],p[2],BRAKE) end
    -- False branches: lower-east, middle-west and upper-east.  The broad basin
    -- already supplies their ice; these paired cells replace only the exact
    -- terminal locations with CAVERN's native $22 fall graphic.
    for key in pairs(HOLES) do local x,y=key:match("^(%d+),(%d+)$");hole(pi,tonumber(x),tonumber(y)) end
    pi(17,11,SWITCH_BR);pi(23,11,WALL)
    -- The first ice light occupies a dry terminal pocket off the entry shelf,
    -- not the sliding line.  Bottom-row choke blocks keep it a single-mouth
    -- branch until the final 2x2 interaction bay.
    pi(4,16,NARROW_H_BOTTOM);pi(5,16,NARROW_H_BOTTOM);pi(6,16,NARROW_H_BOTTOM)
    pad(pi,3,33);pad(pi,49,13)

    -- Depths: real native water surrounds a narrow, winding stone crossing.
    -- The main route never requires Surf; Surf alone reaches the optional
    -- western relic island.  A second Strength groove opens the last ascent.
    local depths,pd=room(28,18,WATER)
    for _,r in ipairs({{1,13,6,16},{5,9,7,14},{5,8,11,10},{10,5,12,9},
      {10,4,16,6},{15,4,18,10},{17,8,21,11},{20,1,20,8},{20,1,22,2},
      -- The optional relic island now sits in the lower tidal pocket.  Its
      -- approach first passes the mainland current marker, then folds around
      -- the island and lands from below instead of being a straight westward
      -- swim.
      {9,13,11,15}}) do rect(pd,r[1],r[2],r[3],r[4]) end
    -- Both Depths memories are optional-looking rock cuts rather than posts
    -- on the crossing.  The western spur folds away from the lower mainland;
    -- the eastern spur turns behind the final ascent.  Returning from memory
    -- five still leaves the complete upper approach and the entire Shrine.
    rect(pd,3,11,5,11,FLOOR);rect(pd,3,9,3,11,FLOOR);rect(pd,1,9,3,9,FLOOR)
    -- The last memory receives its own east reservoir wing.  Expanding the
    -- water-backed floor keeps the old route/warp coordinates stable while
    -- providing an east-up-west rock switchback with no second mainland
    -- connection and a long return before the Shrine.
    rect(pd,21,6,25,6,FLOOR);rect(pd,25,4,25,6,FLOOR);rect(pd,23,4,25,4,FLOOR)
    -- Two real native shore lips.  The lower-right cell of the mainland lip
    -- is (17,21), with water at (17,22); the matching island lip is reached
    -- from water (21,32) into land (21,31).
    pd(8,10,SOUTH_SHORE);pd(10,15,SOUTH_SHORE)
    -- Keep the round rune visible in the rock pocket west of the ascent.  The
    -- old position sat directly in the one-block route and its native $20
    -- elevation cells formed an invisible barrier against the $05 floor.
    pd(19,7,SWITCH_BR);pd(20,7,WALL)
    for _,p in ipairs({{6,13},{10,8},{15,5},{18,9},{21,5}}) do pd(p[1],p[2],ICE) end
    -- Keep the eastern statue wing single-entry.  The old decorative glint at
    -- (21,5) touched the main ascent and became an unintended second mouth.
    pd(21,5,WATER)
    pd(20,3,NARROW_V_LEFT);pd(20,6,NARROW_V_RIGHT)
    -- Three dry relic fissures terminate in unused rock around the tidal
    -- crossing.  The lower fissure doubles back through the rock below the
    -- entry shelf, keeping every cell of the Surf channel around the relic
    -- island untouched while making the light a deliberate out-and-back.
    pd(6,17,NARROW_V_LEFT);pd(5,17,NARROW_H_BOTTOM)
    pd(4,17,NARROW_H_BOTTOM);pd(3,17,NARROW_H_BOTTOM)
    pd(12,10,NARROW_V_RIGHT);pd(12,11,NARROW_V_RIGHT);pd(12,12,FLOOR)
    pd(13,12,NARROW_H_BOTTOM);pd(14,12,NARROW_H_BOTTOM)
    pd(15,12,NARROW_H_BOTTOM);pd(16,12,FLOOR)
    pd(19,3,NARROW_H_TOP);pd(18,3,NARROW_H_TOP);pd(17,3,NARROW_H_TOP)
    pd(4,4,BRAKE);pd(12,5,BRAKE);pad(pd,3,33);pad(pd,41,7)

    -- Shrine: a quiet pair of interlocking pilgrimage loops.  The central
    -- cache and black seal are visible landmarks; the shared-door stair is
    -- reached only after circling the eastern shelf, preserving a calm payoff
    -- without reverting to an empty diagonal corridor.
    local shrine,ps=room(20,16)
    for _,r in ipairs({{1,13,5,14},{5,9,5,14},
      {5,9,11,9},{11,6,11,9},{7,6,11,6},{7,6,7,9},
      {9,2,9,6},{4,3,9,3},{9,3,15,3},{11,6,15,6},
      {15,3,15,7},{15,7,18,7},{18,1,18,7},
      {8,1,10,2}}) do rect(ps,r[1],r[2],r[3],r[4]) end
    for _,p in ipairs({{4,3},{7,8},{9,5},{11,8},{15,5},{17,7}}) do ps(p[1],p[2],ICE) end
    ps(5,12,NARROW_V_LEFT);ps(5,10,NARROW_V_RIGHT)
    ps(8,9,NARROW_H_TOP);ps(11,7,NARROW_V_LEFT)
    ps(9,4,NARROW_V_RIGHT);ps(9,6,NARROW_H_BOTTOM)
    -- Quiet chambers remain two cells wide around the cache and seal; the
    -- connecting pilgrimage arms use native half-blocks so they read as
    -- carved cave passages instead of a graph-paper ribbon.
    ps(5,13,NARROW_V_LEFT)
    ps(6,9,NARROW_H_BOTTOM);ps(9,9,NARROW_H_TOP);ps(10,9,NARROW_H_TOP)
    ps(7,7,NARROW_V_LEFT)
    ps(8,6,NARROW_H_BOTTOM);ps(10,6,NARROW_H_BOTTOM)
    ps(12,6,NARROW_H_TOP);ps(13,6,NARROW_H_TOP)
    ps(9,2,NARROW_V_RIGHT)
    ps(5,3,NARROW_H_TOP);ps(6,3,NARROW_H_TOP);ps(7,3,NARROW_H_TOP)
    ps(13,3,NARROW_H_TOP)
    ps(18,4,NARROW_V_LEFT)
    ps(5,11,BRAKE);ps(9,3,BRAKE);ps(15,7,BRAKE);pad(ps,3,29);pad(ps,37,7)
    return threshold,hall,ice,depths,shrine
  end
  local function cellBlock(def,x,y)
    if not def or x<0 or y<0 or x>=def.width*2 or y>=def.height*2 then return nil end
    return def.blocks[math.floor(x/2)+math.floor(y/2)*def.width+1]
  end
  C.cellBlock = cellBlock
  local HOLE_BLOCKS={[HOLE_TL]=true,[HOLE_TR]=true,[HOLE_BL]=true,[HOLE_BR]=true}
  function C.isHoleCell(def,x,y) return HOLES[x..","..y]~=nil and HOLE_BLOCKS[cellBlock(def,x,y)]==true end
  local function slideSurface(def,x,y)
    local block=cellBlock(def,x,y);return block==ICE or HOLE_BLOCKS[block]==true
  end
  C.switches={
    HALL={map=ID.HALL,boulder="KA_HEVO_BLUE_HALL_BOULDER",goal={x=27,y=25},gate={bx=15,by=12,open=FLOOR},flag="KA_HEVO_BLUE_HALL_SWITCH"},
    ICE={map=ID.ICE,boulder="KA_HEVO_BLUE_ICE_BOULDER",goal={x=35,y=25},gate={bx=23,by=11,open=ICE},flag="KA_HEVO_BLUE_ICE_SWITCH"},
    DEPTHS={map=ID.DEPTHS,boulder="KA_HEVO_BLUE_DEPTHS_BOULDER",goal={x=41,y=19},gate={bx=20,by=7,open=FLOOR},flag="KA_HEVO_BLUE_DEPTHS_SWITCH"},
  }
  local SWITCH_BY_MAP={}
  for name,spec in pairs(C.switches) do spec.name=name;SWITCH_BY_MAP[spec.map]=spec end
  function C.switchSolved(name)
    local s=state(false);return s and s.switches and s.switches[name]==true or false
  end
  function C.markSwitch(mapId,npcName,x,y)
    local spec=SWITCH_BY_MAP[mapId]
    if not spec or npcName~=spec.boulder or x~=spec.goal.x or y~=spec.goal.y then return false,"goal" end
    local s=state();s.switches[spec.name]=true;saveRun(s)
    if mod.world and mod.world.setFlag then mod.world:setFlag(spec.flag,true) end
    if mod.world and mod.world.replaceBlock then mod.world:replaceBlock(spec.gate.bx,spec.gate.by,spec.gate.open) end
    return true,spec.name
  end
  function C.simulateIceCells(moves, start)
    local def=C.layouts and C.layouts[ID.ICE]; assert(def,"register first")
    local at={x=(start and start.x) or 7,y=(start and start.y) or 29}
    local dirs={RIGHT={1,0},LEFT={-1,0},UP={0,-1},DOWN={0,1}}
    for _,name in ipairs(moves) do
      local d=assert(dirs[name],"bad direction "..tostring(name)); local slid=0
      while slid<def.width*def.height*4 do
        local nx,ny=at.x+d[1],at.y+d[2]; local b=cellBlock(def,nx,ny)
        if b==nil or b==WALL or b==WATER then break end
        at.x,at.y=nx,ny; slid=slid+1
        if C.isHoleCell(def,nx,ny) then at.x,at.y=3,33;break end
        if not slideSurface(def,nx,ny) then break end
      end
      assert(slid>0,"blocked ice move "..name)
    end
    return {x=at.x,y=at.y,block=cellBlock(def,at.x,at.y)}
  end
  function C.simulateFall(key)
    local target=assert(HOLES[key],"unknown fall hole")
    local x,y=key:match("^(%d+),(%d+)$"); x,y=tonumber(x),tonumber(y)
    assert(C.isHoleCell(C.layouts and C.layouts[ID.ICE],x,y),"fall source is not a native hole")
    return {map=target.map,x=target.x,y=target.y}
  end
  function C.register()
    if C.registered then return false,"already registered" end
    local threshold,hall,ice,depths,shrine=makeLayouts()
    local statueObjects={}
    for name,s in pairs(C.statues) do
      statueObjects[s.map]=statueObjects[s.map] or {}
      local list=statueObjects[s.map]; list[#list+1]={index=#list+1,
        name="KA_HEVO_BLUE_STATUE_"..name,
        sprite="SPRITE_KA_HEVO_QUIZ_STATUE",semanticRole="quiz_statue",
        x=s.x,y=s.y,movement="STAY",range="NONE",text=s.text}
    end
    local function extra(mapId, name, sprite, x, y, text, fields)
      local list=statueObjects[mapId] or {}; statueObjects[mapId]=list
      local obj={index=#list+1,name=name,sprite=sprite,x=x,y=y,movement="STAY",range="NONE",text=text}
      for key,value in pairs(fields or {}) do obj[key]=value end
      list[#list+1]=obj
    end
    extra(ID.HALL,"KA_HEVO_BLUE_HALL_BOULDER","SPRITE_BOULDER",13,25,nil,{pushable=true})
    extra(ID.HALL,"KA_HEVO_BLUE_STRENGTH_TABLET","SPRITE_POKE_BALL",9,29,"TEXT_KA_HEVO_BLUE_STRENGTH")
    extra(ID.HALL,"KA_HEVO_BLUE_HALL_RESET","SPRITE_POKE_BALL",5,31,"TEXT_KA_HEVO_BLUE_RESET_HALL")
    extra(ID.ICE,"KA_HEVO_BLUE_ICE_BOULDER","SPRITE_BOULDER",29,25,nil,{pushable=true})
    extra(ID.ICE,"KA_HEVO_BLUE_ICE_RESET","SPRITE_POKE_BALL",27,27,"TEXT_KA_HEVO_BLUE_RESET_ICE")
    extra(ID.ICE,"KA_HEVO_BLUE_SWAMPERTITE_HINT","SPRITE_POKE_BALL",7,31,"TEXT_KA_HEVO_BLUE_SWAMPERTITE_HINT")
    extra(ID.ICE,"KA_HEVO_BLUE_FROST_RUNE","SPRITE_POKE_BALL",3,7,"TEXT_KA_HEVO_BLUE_FROST_RUNE")
    extra(ID.DEPTHS,"KA_HEVO_BLUE_DEPTHS_BOULDER","SPRITE_BOULDER",35,19,nil,{pushable=true})
    extra(ID.DEPTHS,"KA_HEVO_BLUE_DEPTHS_RESET","SPRITE_POKE_BALL",33,21,"TEXT_KA_HEVO_BLUE_RESET_DEPTHS")
    extra(ID.DEPTHS,"KA_HEVO_BLUE_SWAMPERTITE_CACHE","SPRITE_POKE_BALL",21,29,"TEXT_KA_HEVO_BLUE_SWAMPERTITE")
    C.layouts={}
    C.layouts[ID.THRESHOLD]=map(ID.THRESHOLD,1940,20,16,threshold,{{x=3,y=29,destMap=C.contract.returnMap,destWarp=1},{x=25,y=3,destMap=ID.HALL,destWarp=1}})
    C.layouts[ID.HALL]=map(ID.HALL,1941,22,18,hall,{{x=3,y=33,destMap=ID.THRESHOLD,destWarp=1},{x=41,y=17,destMap=ID.ICE,destWarp=1}},statueObjects[ID.HALL])
    local iceWarps={{x=3,y=33,destMap=ID.HALL,destWarp=2},{x=49,y=13,destMap=ID.DEPTHS,destWarp=1}}
    local holeKeys={};for key in pairs(HOLES) do holeKeys[#holeKeys+1]=key end
    table.sort(holeKeys,function(a,b)
      local ax,ay=a:match("^(%d+),(%d+)$");local bx,by=b:match("^(%d+),(%d+)$")
      return tonumber(ay)==tonumber(by) and tonumber(ax)<tonumber(bx) or tonumber(ay)<tonumber(by)
    end)
    for _,key in ipairs(holeKeys) do local x,y=key:match("^(%d+),(%d+)$");iceWarps[#iceWarps+1]={x=tonumber(x),y=tonumber(y),destMap=ID.ICE,destWarp=1} end
    C.layouts[ID.ICE]=map(ID.ICE,1942,26,18,ice,iceWarps,statueObjects[ID.ICE])
    C.layouts[ID.DEPTHS]=map(ID.DEPTHS,1943,28,18,depths,{{x=3,y=33,destMap=ID.ICE,destWarp=2},{x=41,y=7,destMap=ID.SHRINE,destWarp=1}},statueObjects[ID.DEPTHS])
    C.layouts[ID.SHRINE]=map(ID.SHRINE,1944,20,16,shrine,{{x=3,y=29,destMap=ID.DEPTHS,destWarp=2},{x=37,y=7,destMap=C.contract.endMap,destWarp=1}},{{index=1,name="KA_HEVO_BLUE_REWARD_CACHE",sprite="SPRITE_POKE_BALL",x=19,y=9,movement="STAY",range="NONE",text="TEXT_KA_HEVO_BLUE_REWARD"},{index=2,name="KA_HEVO_BLUE_KYOGRE_DOOR",sprite="SPRITE_KA_HEVO_SHARED_SEALED_DOOR",x=19,y=3,movement="STAY",range="NONE",text="TEXT_KA_HEVO_BLUE_DOOR"}})
    if mod.content.field and mod.content.field.patch then
      mod.content.field:patch("darkMaps",{maps={ID.THRESHOLD,ID.HALL,ID.ICE,ID.DEPTHS,ID.SHRINE}})
    end
    local pointers={}
    for name,s in pairs(C.statues) do
      mod.content.text:register(s.text,tr("A frost statue asks\nfor a Kanto memory.","Eine Froststatue fragt\nnach einer Kanto-Erinnerung.")); pointers[s.text]={text=s.text}
    end
    mod.content.text:register("TEXT_KA_HEVO_BLUE_REWARD",tr("The blue cache waits\nbefore the sealed door.","Die blaue Truhe wartet\nvor der versiegelten Tür."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_DOOR",tr("A distant KYOGRE call\nanswers the black door.","Ein ferner KYOGRE-Ruf\nantwortet der schwarzen Tür."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_SWAMPERTITE_HINT",tr("Cold currents circle\na blue relic beyond the ice.","Kalte Strömungen kreisen\num ein blaues Relikt hinter dem Eis."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_FROST_RUNE",tr("Dry shelves stop a slide.\nBlack eyes return you safely.","Trockene Bänke bremsen.\nSchwarze Augen bringen dich sicher zurück."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_SWAMPERTITE",tr("A hidden SWAMPERTITE\nanswers the tidal path.","Ein verborgenes SWAMPERTITE\nantwortet dem Gezeitenpfad."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_STRENGTH",tr("STRENGTH moves the dark rocks.\nA round wall mark opens a nearby gate.","STÄRKE bewegt die dunklen Felsen.\nEine runde Wandmarke öffnet ein nahes Tor."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_RESET_HALL",tr("Reset the Hall boulder?\nSolved switches stay solved.","Hallenfelsen zurücksetzen?\nGelöste Schalter bleiben gelöst."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_RESET_ICE",tr("Reset this ice section?\nYou return to its entrance.","Diesen Eisabschnitt zurücksetzen?\nDu kehrst zum Eingang zurück."))
    mod.content.text:register("TEXT_KA_HEVO_BLUE_RESET_DEPTHS",tr("Reset the Depths boulder?\nThe tidal route stays recorded.","Tiefenfelsen zurücksetzen?\nDer Gezeitenpfad bleibt vermerkt."))
    for _,id in ipairs({"TEXT_KA_HEVO_BLUE_REWARD","TEXT_KA_HEVO_BLUE_DOOR","TEXT_KA_HEVO_BLUE_SWAMPERTITE_HINT",
      "TEXT_KA_HEVO_BLUE_SWAMPERTITE","TEXT_KA_HEVO_BLUE_FROST_RUNE","TEXT_KA_HEVO_BLUE_STRENGTH",
      "TEXT_KA_HEVO_BLUE_RESET_HALL","TEXT_KA_HEVO_BLUE_RESET_ICE","TEXT_KA_HEVO_BLUE_RESET_DEPTHS"}) do
      pointers[id]={text=id}
    end
    mod.content.text_pointers:patch("???",pointers)
    local talksByMap={}
    for name,s in pairs(C.statues) do
      talksByMap[s.map]=talksByMap[s.map] or {}
      talksByMap[s.map][s.text]=function(game,_,_,done) return C.ask(name,game,done) end
    end
    talksByMap[ID.ICE]=talksByMap[ID.ICE] or {}
    talksByMap[ID.ICE].TEXT_KA_HEVO_BLUE_FROST_RUNE=function(game,_,_,done)
      return show(game,tr("Dry stone brakes the glide.\nA fall returns to this floor's entrance.","Trockener Stein bremst die Gleitbahn.\nEin Sturz führt zum Eingang dieser Etage."),done)
    end
    talksByMap[ID.ICE].TEXT_KA_HEVO_BLUE_SWAMPERTITE_HINT=function(game,_,_,done) return show(game,tr("The current marks a\nSURF path to a blue relic.","Die Strömung markiert\neinen SURF-Pfad zu einem blauen Relikt."),done) end
    talksByMap[ID.DEPTHS]=talksByMap[ID.DEPTHS] or {}
    talksByMap[ID.DEPTHS].TEXT_KA_HEVO_BLUE_SWAMPERTITE=function(game,_,_,done)
      local ok,why=C.claimSwampertite(game)
      local message=ok and tr("You found SWAMPERTITE.","Du findest SWAMPERTITE.") or (why=="claimed" and tr("The hidden relic is gone.","Das verborgene Relikt ist fort.") or tr("The tide rejects you.","Die Flut weist dich ab."))
      return show(game,message,done)
    end
    talksByMap[ID.HALL]=talksByMap[ID.HALL] or {}
    talksByMap[ID.HALL].TEXT_KA_HEVO_BLUE_STRENGTH=function(game,_,_,done)
      return show(game,tr("Use STRENGTH, then push the boulder beside the round wall rune.","Nutze STÄRKE und schiebe den Felsen neben die runde Wandrune."),done)
    end
    local function resetTalk(mapId,x,y,facing)
      return function(game,_,_,done)
        return show(game,tr("The frost path reforms.","Der Frostpfad formt sich neu."),function()
          if mod.world and mod.world.warpTo then
            mod.world:warpTo(mapId,x,y,facing,{onDone=done})
          elseif done then done() end
        end)
      end
    end
    talksByMap[ID.HALL].TEXT_KA_HEVO_BLUE_RESET_HALL=resetTalk(ID.HALL,3,33,"up")
    talksByMap[ID.ICE].TEXT_KA_HEVO_BLUE_RESET_ICE=resetTalk(ID.ICE,3,33,"up")
    talksByMap[ID.DEPTHS].TEXT_KA_HEVO_BLUE_RESET_DEPTHS=resetTalk(ID.DEPTHS,3,33,"up")
    for mapId,talks in pairs(talksByMap) do
      local ownerMap=mapId
      local scripts={priority=2800,talk=talks}
      local spec=SWITCH_BY_MAP[ownerMap]
      if spec then
        scripts.onBoulderMoved=function(_,_,npc)
          return C.markSwitch(ownerMap,npc and npc.def and npc.def.name,npc and npc.cellX,npc and npc.cellY)
        end
      end
      mod.content.map_scripts:register(ownerMap,scripts)
    end
    mod.content.map_scripts:register(ID.SHRINE,{priority=2800,talk={
      TEXT_KA_HEVO_BLUE_REWARD=function(game,_,_,done) local got=C.claimAll(game); return show(game,#got>0 and tr("Permanent frost relics\nwere recorded.","Permanente Frostrelikte\nwurden verzeichnet.") or tr("The cache is empty.","Die Truhe ist leer."),done) end,
      TEXT_KA_HEVO_BLUE_DOOR=function(game,_,_,done)
        if type(C.finalizeEndSeal)=="function" then
          local sealed,why,stoneStatus=C.finalizeEndSeal(game)
          if not sealed then
            local blocked=opts.legacyDungeonAdapter
              and opts.legacyDungeonAdapter.failureText
              and opts.legacyDungeonAdapter.failureText(why)
            if blocked then return show(game,blocked,done) end
            return show(game,tr("The unfinished frost path rejects the final glint.",
              "Der unvollendete Frostpfad weist den letzten Schimmer zurück."),done)
          end
          if stoneStatus=="granted" then
            return show(game,tr(
              "A final blue glint leaves the seal. SWAMPERTITE is secured. KYOGRE calls beyond the black door.",
              "Ein letzter blauer Schimmer löst sich aus dem Siegel. SUMPEXNIT ist gesichert. Hinter der schwarzen Tür ruft KYOGRE."),done)
          end
          if stoneStatus=="claimed" then
            return show(game,tr(
              "The completed blue seal glints steadily. SWAMPERTITE is already secured. KYOGRE calls beyond the black door.",
              "Das vollendete blaue Siegel schimmert stetig. SUMPEXNIT ist bereits gesichert. Hinter der schwarzen Tür ruft KYOGRE."),done)
          end
          return show(game,tr("KYOGRE calls beyond\nthe black seal...","KYOGRE ruft hinter\ndem schwarzen Siegel ..."),done)
        end
        local ok,why=C.claimSwampertite(game)
        if ok then
          return show(game,tr(
            "A final blue glint leaves the seal. SWAMPERTITE is secured. KYOGRE calls beyond the black door.",
            "Ein letzter blauer Schimmer löst sich aus dem Siegel. SUMPEXNIT ist gesichert. Hinter der schwarzen Tür ruft KYOGRE."),done)
        end
        if why~="claimed" then
          return show(game,tr("The unfinished frost path rejects the final glint.",
            "Der unvollendete Frostpfad weist den letzten Schimmer zurück."),done)
        end
        return show(game,tr("KYOGRE calls beyond\nthe black seal...","KYOGRE ruft hinter\ndem schwarzen Siegel ..."),done)
      end,
    }})
    C.registered=true; return true
  end
  local function activeMap()
    local ow=mod.world and mod.world.overworld and mod.world:overworld()
    return ow and ow.map
  end
  local SLIDE_DELTA={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  local HOLE_BEAT_FRAMES=16
  local function occupied(entities,x,y,ignore)
    for _,entity in ipairs(entities or {}) do
      if entity~=ignore and not entity.passable
          and ((entity.cellX==x and entity.cellY==y) or (entity.targetX==x and entity.targetY==y)) then
        return entity
      end
    end
    return nil
  end
  -- One safe scripted ice step.  Native holes are the only intentional
  -- exception to walkability; they must also own a warp record before the
  -- slider is allowed to enter them.
  function C.slideTarget(ow,dir)
    local map,player=ow and ow.map,ow and ow.player
    local delta=SLIDE_DELTA[dir]
    if not(map and player and delta) then return nil,"context" end
    local x,y=player.cellX+delta[1],player.cellY+delta[2]
    if not map:inBounds(x,y) then return nil,"bounds" end
    if occupied(ow.entities,x,y,player) then return nil,"entity" end
    local def=C.layouts and C.layouts[ID.ICE] or map.def
    local hole=C.isHoleCell(def,x,y)
    local warp=map.warpAtCell and map:warpAtCell(x,y) or nil
    if hole and not warp then return nil,"unbound-hole" end
    if not hole and not map:isWalkableCell(x,y) then return nil,"tile" end
    return {x=x,y=y,hole=hole,warp=warp,block=cellBlock(def,x,y)}
  end
  -- The native Player cannot use OverworldState:marchInPlace: that helper is
  -- an NPC movement byte and leaves a Player without targetX/targetY.  Keep
  -- the landed player safely locked for one ordinary 16-frame walk cycle
  -- instead.  bumpFrames supplies the native in-place leg cadence while the
  -- input-step hook below owns the bounded delay; the normal $22 landing
  -- pipeline still runs exactly once after the fracture has been visible.
  function C.beginHoleBeat(ow,ownerMap,player,land,cancel)
    if C._holeHold or not(ow and ownerMap and player and land) then return false end
    C._holeHold={ow=ow,map=ownerMap,player=player,frames=HOLE_BEAT_FRAMES,
      wasLocked=player.inputLocked==true,oldBump=player.bumpFrames,
      land=land,cancel=cancel}
    player.inputLocked=true
    player.bumpFrames=math.max(tonumber(player.bumpFrames) or 0,HOLE_BEAT_FRAMES)
    return true
  end
  function C.tickHoleBeat()
    local hold=C._holeHold
    if not hold then return false end
    local valid=hold.ow and hold.ow.map==hold.map
      and hold.ow.player==hold.player and hold.player
      and hold.player.cellX and hold.player.cellY
    if not valid then
      if hold.player then
        hold.player.inputLocked=hold.wasLocked
        hold.player.bumpFrames=hold.oldBump
      end
      C._holeHold=nil;C._sliding=false
      if hold.cancel then hold.cancel() end
      return false
    end
    hold.frames=hold.frames-1
    if hold.frames>0 then return true end
    hold.player.inputLocked=hold.wasLocked
    hold.player.bumpFrames=hold.oldBump
    C._holeHold=nil
    hold.land()
    return true
  end
  function C.startIceSlide(ow)
    if C._sliding or not(ow and ow.map and ow.player) or ow.map.id~=ID.ICE
        or ow.player.moving or C.isHoleCell(ow.map.def,ow.player.cellX,ow.player.cellY)
        or not slideSurface(ow.map.def,ow.player.cellX,ow.player.cellY) then
      return false,"not-ice"
    end
    local dir=ow.player.facing
    if not SLIDE_DELTA[dir] then return false,"direction" end
    local ownerMap,player=ow.map,ow.player
    C._sliding=true
    local finished=false
    local function finish(reason)
      if finished then return end
      finished=true;C._sliding=false
      return reason
    end
    local function advance()
      if finished then return end
      if not ow.map or ow.map~=ownerMap or ow.map.id~=ID.ICE or ow.player~=player or player.moving then
        return finish("map-change")
      end
      local target=C.slideTarget(ow,dir)
      if not target then return finish("blocked") end
      ow:scriptMove(player,dir,1,function()
        if finished then return end
        if not ow.map or ow.map~=ownerMap or ow.map.id~=ID.ICE or ow.player~=player then
          return finish("map-change")
        end
        -- Every scripted cell re-enters the full normal landing pipeline:
        -- map triggers, forced movement, native warp/hole handling and save
        -- step bookkeeping all see exactly the cell the player reached.
        -- A native one-cycle slip beat makes the terminal fracture visible
        -- under the player before its ordinary $22 fall trigger fires.
        local terminal=target.hole or target.warp or not slideSurface(ownerMap.def,target.x,target.y)
        local function land()
          if finished then return end
          if not ow.map or ow.map~=ownerMap or ow.map.id~=ID.ICE or ow.player~=player then
            return finish("map-change")
          end
          ow:onStepComplete()
          if terminal or not ow.map or ow.map~=ownerMap or ow.map.id~=ID.ICE then
            return finish(terminal and "terminal" or "map-change")
          end
          advance()
        end
        if target.hole then
          assert(C.beginHoleBeat(ow,ownerMap,player,land,function()
            finish("map-change")
          end),"BLUE native-hole beat re-entered")
          return
        end
        land()
      end)
    end
    advance()
    return true
  end
  function C.applySolvedSwitch(mapId)
    local spec=SWITCH_BY_MAP[mapId]
    if not spec or not C.switchSolved(spec.name) then return false end
    if mod.world and mod.world.setFlag then mod.world:setFlag(spec.flag,true) end
    if mod.world and mod.world.replaceBlock then mod.world:replaceBlock(spec.gate.bx,spec.gate.by,spec.gate.open) end
    return true
  end
  function C.allowShrineStep(allowed, ctx)
    if not allowed or C.shrineOpen() then return allowed end
    local mapId=ctx and (ctx.mapId or (ctx.map and ctx.map.id))
    local x,y=ctx and (ctx.toX or ctx.x),ctx and (ctx.toY or ctx.y)
    if mapId==ID.DEPTHS and x==45 and y==3 then
      if ctx then ctx.reason="KA_HEVO_BLUE_NEED_FIVE_SIGHT" end
      return false
    end
    return allowed
  end
  function C.install(game)
    if C.installed then return false,"already installed" end
    C.installed,C.game=true,game or C.game
    -- Prefer BLUE's darkness as the final world-only composite, after flat
    -- PaletteFX sprite redraws and DRAMALESS/upright billboards.  Released
    -- 0.1.83 does not expose that queue, so retain the same authored mask in
    -- drawAtmosphere as a compatibility fallback instead of aborting every
    -- HEVO listener (including the post-Hall researchers).
    local renderer=C.game and C.game.renderer
    local hasPostOverlay=renderer
      and type(renderer.queueWorldPostOverlay)=="function"
    local voxelTools
    local function voxelScreenPoint(wx,wz)
      if voxelTools==false then return nil end
      if voxelTools==nil then
        local projector=voxelRenderer
          and voxelRenderer.module(C.game,"Voxel3D")
        local aa=voxelRenderer and voxelRenderer.module(C.game,"AntiAlias")
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
    if not rawget(OverworldState,"_kaHevoBlueSightWrapped") then
      local original=OverworldState.drawAtmosphere
      OverworldState.drawAtmosphere=function(ow,vw,vh)
        if type(original)=="function" then original(ow,vw,vh) end
        local sight=ow.kaHevoBlueSight
        if not sight or not(love and love.graphics) then return end
        local px=ow.player.px-ow.camera.x+8
        local py=ow.player.py-ow.camera.y+12
        local glacier=ow.map and ow.map.id==ID.ICE
        local function drawSightOverlay(ctx)
          -- CAVERN block 21 remains the exact native Kanto surface.  The
          -- Glacier alone receives a world-only multiplicative cold grade:
          -- pale/glinting pixels become unmistakably cyan, while black hole
          -- mouths stay black.  It runs before the radial dark mask and
          -- before UI, so it is neither a Johto/private atlas nor a HUD tint.
          if glacier then
            love.graphics.setShader()
            love.graphics.setBlendMode("multiply","premultiplied")
            love.graphics.setColor(0.34,0.78,1.0,1.0)
            love.graphics.rectangle("fill",0,0,ctx.width,ctx.height)
            love.graphics.setBlendMode("alpha","alphamultiply")
          end
          if ow.kaHevoBlueSightShader==nil and love.graphics.newShader then
            local ok,shader=pcall(love.graphics.newShader,[[
              extern vec2 sightCenter;
              extern vec2 sightRadius;
              extern number innerOpacity;
              extern number outerOpacity;
              extern number featherPx;
              vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
                // Nearly binary analytic aperture.  Only the last two real
                // screen pixels are antialiased; the interior therefore has
                // one uniform dimming value and cannot expose native tile
                // stipple as a wide checker/raster aura around late sprites.
                number radiusPx=max(1.0,min(sightRadius.x,sightRadius.y));
                number edgeStart=1.0-min(featherPx,2.0)/radiusPx;
                number edge=smoothstep(edgeStart,1.0,
                  length((screen-sightCenter)/sightRadius));
                number darkness=mix(innerOpacity,outerOpacity,edge);
                return vec4(0.003,0.009,0.016,darkness);
              }
            ]])
            ow.kaHevoBlueSightShader=ok and shader or false
          end
          local shader=ow.kaHevoBlueSightShader
          local cx,cy,rx,ry
          if ctx.pipeline then
            local directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
            local facing=directions[ow.player.facing] or directions.down
            local wx,wz=ow.player.px+8,ow.player.py+16
            cx,cy=voxelScreenPoint(wx,wz)
            local ax,ay=voxelScreenPoint(wx+facing[1]*16,wz+facing[2]*16)
            if not (cx and cy and ax and ay) then
              -- Never guess with Renderer.centerX/Y: DRAMALESS projects the
              -- actor roughly one cell away from that camera hint.  A failed
              -- adapter therefore fails closed to black instead of exposing
              -- remote statues or cutting the player out of a false cone.
              love.graphics.setShader()
              love.graphics.setBlendMode("alpha")
              love.graphics.setColor(0.003,0.009,0.016,1)
              love.graphics.rectangle("fill",0,0,ctx.width,ctx.height)
              return
            end
            local dx,dy=ax-cx,ay-cy
            local cellPixels=math.sqrt(dx*dx+dy*dy)
            rx,ry=sight.radius*cellPixels,sight.radius*cellPixels
            ow.kaHevoBlueProjectedSight={x=cx,y=cy,cell=cellPixels}
          else
            cx,cy=ctx.worldToScreen(px,py)
            rx,ry=sight.radius*16*ctx.scaleX,sight.radius*16*ctx.scaleY
          end
          local featherPx=math.max(0.5,math.min(2.0,
            tonumber(sight.featherPx) or 2.0))
          -- Runtime evidence for both flat and projected DRAMALESS captures;
          -- QA asserts this exact screen-space band never scales with radius.
          ow.kaHevoBlueSightRuntime={
            pipeline=ctx.pipeline==true,
            featherPx=featherPx,
            radiusX=rx,
            radiusY=ry,
            presentation=hasPostOverlay and "world-post-overlay"
              or "atmosphere-fallback",
          }
          if shader then
            shader:send("sightCenter",{cx,cy})
            shader:send("sightRadius",{rx,ry})
            shader:send("innerOpacity",sight.innerOpacity)
            shader:send("outerOpacity",sight.outerOpacity)
            shader:send("featherPx",featherPx)
            love.graphics.setShader(shader)
          end
          love.graphics.setColor(1,1,1,shader and 1 or sight.outerOpacity)
          love.graphics.rectangle("fill",0,0,ctx.width,ctx.height)
        end
        if hasPostOverlay then
          renderer:queueWorldPostOverlay(drawSightOverlay)
        else
          -- Compatibility rendering happens on the native world canvas, so
          -- coordinates and radii are already in authored world pixels.  It
          -- cannot shade later third-party upright replays, but it preserves
          -- the real darkness puzzle and, critically, never prevents the
          -- campaign's gameplay/listener installation.
          love.graphics.push("all")
          local ok,err=pcall(drawSightOverlay,{
            width=vw,height=vh,scaleX=1,scaleY=1,pipeline=false,
            worldToScreen=function(x,y) return x,y end,
            compatibilityFallback=true,
          })
          love.graphics.pop()
          if not ok and mod.log and type(mod.log.warn)=="function" then
            mod.log:warn("BLUE atmosphere fallback failed: %s",tostring(err))
          end
        end
      end
      rawset(OverworldState,"_kaHevoBlueSightWrapped",true)
    end
    if mod.hooks and type(mod.hooks.wrap)=="function" then
      mod.hooks:wrap("input.step",function(nextStep,game,dt)
        local result=nextStep(game,dt)
        -- Idempotent fallback for presentation packages that refresh an actor
        -- after map.entered.  This is a pointer check in the steady state and
        -- also releases BLUE's clone on the first non-BLUE input frame.
        C.refreshSurfPresentation(nil,nil,game)
        C.tickHoleBeat()
        return result
      end)
      mod.hooks:wrap("movement.collision",function(nextCollision,allowed,ctx)
        return C.allowShrineStep(nextCollision(allowed,ctx),ctx)
      end)
    end
    local function restoreActiveMapState(mapId)
      local map=activeMap();mapId=mapId or (map and map.id)
      if not mapId then return false end
      local ow=mod.world and mod.world.overworld and mod.world:overworld()
      C.refreshSurfPresentation(ow,mapId)
      C.refreshSight()
      if SWITCH_BY_MAP[mapId] then C.applySolvedSwitch(mapId) end
      return true
    end
    -- Run after the ordinary character-presentation refresh (priority 0), so
    -- equal-priority event sorting can never leave the native all-black SEEL
    -- renderer as the final owner on a BLUE floor.
    mod.events:on("map.entered",function(ev)
      if ev then restoreActiveMapState(ev.mapId) end
    end,-100)
    -- Game:restoreSave rebuilds the Overworld before emitting save.loaded.
    -- Reapply runtime-only block replacements again at that explicit reload
    -- boundary; otherwise a solved Strength rune can return as a solid wall
    -- even though its persistent BLUE switch flag is still true.
    mod.events:on("save.loaded",function()
      restoreActiveMapState()
    end,-100)
    mod.events:on("world.stepped",function(ev)
      if not ev or ev.mapId~=ID.ICE or C._sliding then return end
      local ow,map=mod.world:overworld(),activeMap()
      if not(ow and map and map.id==ID.ICE and ow.player and not ow.player.moving) then return end
      C.startIceSlide(ow)
    end)
    -- Installations normally precede the first Overworld, but a live reload
    -- may already have one.  Apply (or release) the presentation immediately
    -- instead of waiting for an unrelated player step.
    restoreActiveMapState()
    return true
  end
  return C
end
