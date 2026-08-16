-- Authority integration entry point for the post-prototype campaign.
-- main.lua loads this file directly; COPY_SET is the release handoff inventory.
return function(mod, opts)
  opts = opts or {}
  local root = assert(mod.path, "Hidden Evolution campaign needs mod.path")
  -- AssetTransform writes this prefix below save/mod-derived/kanto_ascendant;
  -- Assets.resolve recognizes the generated-cache spelling at render time.
  local derivedAsset = "assets/" .. "generated/hidden_evolution/"
  local function load(file)
    if type(opts.load) == "function" then return opts.load(file) end
    local body, readErr = mod:read(file)
    local chunk, compileErr = body and loadstring(body, "@" .. root .. "/" .. file) or nil
    assert(chunk, compileErr or readErr)
    return chunk()
  end
  local function registerSupport()
    local body, readErr = mod:read("hidden_evolution_music.lua")
    local chunk, compileErr = body and loadstring(body,
      "@" .. root .. "/hidden_evolution_music.lua") or nil
    assert(chunk, compileErr or readErr)
    if not (mod.content.music.get and mod.content.music:get("Music_KA_DeepEvolution")) then
      mod.content.music:register("Music_KA_DeepEvolution", chunk())
    end
    for id, image in pairs({
      SPRITE_KA_EVOLUTION_RELIC = derivedAsset .. "gen2_relic.png",
      SPRITE_KA_HEVO_QUIZ_STATUE = derivedAsset .. "quiz_statue.png",
    }) do
      if not (mod.content.sprites.get and mod.content.sprites:get(id)) then
        mod.content.sprites:register(id, { id = id, image = image,
          frames = 1, walker = false, trueColor = true })
      end
    end
  end
  local coordinatorFactory = load("hidden_evolution_story_coordinator.lua")
  local campaign = coordinatorFactory(mod, {
    load = load,
    i18n = opts.i18n,
    questionUi = opts.questionUi,
    isGerman = opts.isGerman,
    characters = opts.extendedCharacters or opts.characters,
    activeCharacter = opts.activeCharacter,
    postgame = opts.postgame,
    legacyDungeonAdapter = opts.legacyDungeonAdapter,
    megaEvolution = opts.megaEvolution,
    journey = opts.journey,
    voxelRenderer = opts.voxelRenderer,
  })
  campaign.floorLights = load("hidden_evolution_floor_lights.lua")(mod, {
    routes = campaign.load(),
    i18n = opts.i18n,
    activeCharacter = opts.activeCharacter,
    characters = opts.extendedCharacters or opts.characters,
  })
  campaign.encounters = load("hevo_dungeon_encounters.lua")(mod, {
    packages = assert(opts.hevoPackages,
      "Hidden Evolution campaign needs the HEVO package registry"),
    activeCharacter = opts.activeCharacter,
    journeyCycle = opts.journeyCycle,
    characters = opts.extendedCharacters or opts.characters,
    beyondKanto = opts.beyondKanto,
  })
  campaign.COPY_SET = {
    "hidden_evolution_campaign.lua", "hidden_evolution_music.lua",
    "hidden_evolution_architecture.lua", "hidden_evolution_red_path.lua",
    "hidden_evolution_blue_campaign.lua", "hidden_evolution_green_grove.lua",
    "hidden_evolution_visibility_compat.lua", "hidden_evolution_floor_lights.lua",
    "hidden_evolution_shared_story.lua", "hidden_evolution_story_hints.lua",
    "hidden_evolution_story_coordinator.lua", "shiny_transforms.lua",
    "hevo_dungeon_encounters.lua",
    "tools/hevo_dungeon_encounter_demo_manifest.lua",
    "tools/hevo_dungeon_encounter_demo_qa_setup.lua",
    "tools/hidden_evolution_campaign_headless_playthrough.lua",
    "tools/hidden_evolution_runtime_capture.lua",
    "docs/HIDDEN_EVOLUTION_VOXEL_CAPTURE_PLAN.md",
  }
  campaign.LEGACY_PROTOTYPES = {
    "KANTO_ASCENDANT_HIDDEN_EVOLUTION_ENTRY", "KANTO_ASCENDANT_EVOLUTION_THRESHOLD_RUNES",
    "KANTO_ASCENDANT_EVOLUTION_THRESHOLD_PATH", "KA_EVOLUTION_NEXUS", "KA_EVOLUTION_SECTOR_STONE",
  }
  function campaign.validateNoPrototypeFallback()
    for _, id in ipairs(campaign.LEGACY_PROTOTYPES) do
      if campaign.CONTRACT.shared == id then error("Hidden Evolution prototype fallback: " .. id) end
    end
    return true
  end
  -- The maps remain native CAVERN maps.  Field Tech owns the UI and asks this
  -- narrowly-scoped provider whether an otherwise indoor action is permitted.
  -- FLY is an escape only.  None of the three authored visibility trials can
  -- be bypassed with FLASH: RED/BLUE swallow the brief flare, while GREEN's
  -- ancient mist closes over it.  The Field Kit still presents FLASH so the
  -- player receives the authored feedback instead of a mysteriously missing
  -- menu row.  Unknown maps/characters never receive a permissive fallback.
  local hevoMaps = {
    KA_HEVO_TUNNEL_ALL = true,
    KA_HEVO_RED_UPPER = true, KA_HEVO_RED_ABYSS = true, KA_HEVO_RED_RECOVERY = true,
    KA_HEVO_RED_LOWER = true, KA_HEVO_RED_SHRINE = true,
    KA_HEVO_BLUE_FROST_THRESHOLD = true, KA_HEVO_BLUE_FROST_HALL = true,
    KA_HEVO_BLUE_GLACIER_MAZE = true, KA_HEVO_BLUE_TIDAL_DEPTHS = true, KA_HEVO_BLUE_KYOGRE_SHRINE = true,
    KA_HEVO_SHARED_SEALED_ANTECHAMBER = true,
    KA_HEVO_GREEN_THRESHOLD = true, KA_HEVO_GREEN_GROVE = true,
    KA_HEVO_GREEN_MIST = true, KA_HEVO_GREEN_RAYQUAZA_SHRINE = true,
  }
  function campaign.fieldPolicy(_, moveId, mapId)
    if not hevoMaps[mapId] then return nil end
    if moveId == "FLY" then return { allowFlyInside = true } end
    if moveId == "FLASH" then
      if mapId:match("^KA_HEVO_RED_") or mapId:match("^KA_HEVO_BLUE_") then
        return { blockFlash = true, flashBlockReason = "darkness" }
      end
      if mapId:match("^KA_HEVO_GREEN_") then
        return { blockFlash = true, flashBlockReason = "mist" }
      end
    end
    return nil
  end

  -- Gen1Recomp 0.1.90 keeps object-definition metadata on npc.def, but
  -- NPC.new does not copy def.passable onto the live NPC.  Collision reads
  -- the live field, so an explicitly passable HEVO interaction anchor would
  -- otherwise become an invisible wall after every map construction.  Keep
  -- this compatibility repair deliberately narrower than an engine patch:
  -- only the current authored HEVO map is eligible, and only definitions
  -- which opt in with the literal value true are changed.  Floor lights,
  -- quiz statues and every other solid object remain untouched.
  function campaign.refreshPassableObjects(game, ev)
    local ow = mod.world and mod.world.overworld
      and mod.world:overworld() or game and game.overworld
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
      or ow and ow.map and ow.map.id
      or game and game.save and game.save.player and game.save.player.map
    if not (hevoMaps[mapId] and ow and ow.map and ow.map.id == mapId) then
      return false, "map"
    end
    local restored = 0
    for _, npc in ipairs(ow.npcs or {}) do
      local def = npc and npc.def
      if type(def) == "table" and def.passable == true then
        npc.passable = true
        restored = restored + 1
      end
    end
    return true, restored
  end
  local baseRegister = campaign.register
  function campaign.register()
    campaign.validateNoPrototypeFallback()
    registerSupport()
    local ok, why = baseRegister()
    if ok == false and why ~= "already registered" then return ok, why end
    local lightsOk, lightsWhy = campaign.floorLights.register()
    if lightsOk == false and lightsWhy ~= "already registered" then
      return false, "floor-lights:" .. tostring(lightsWhy)
    end
    return true
  end
  local baseInstall = campaign.install
  function campaign.runtimePreflight(game)
    local renderer = game and game.renderer
    if renderer and type(renderer.queueWorldPostOverlay) == "function" then
      return true, "world-post-overlay"
    end
    local ok, overworld = pcall(require, "src.world.OverworldController")
    if ok and type(overworld.drawAtmosphere) == "function" then
      return true, "atmosphere-fallback"
    end
    -- The released 0.1.83 runtime predates both presentation surfaces.  The
    -- campaign installs its own final-world compatibility mask below; native
    -- darkness is only its base palette.  Do not turn a visual capability gap
    -- into a silent disappearance of the whole campaign.
    return true, "legacy-native-darkness"
  end
  function campaign.install(game)
    local compatible, presentation = campaign.runtimePreflight(game)
    if not compatible then return false, "runtime:" .. tostring(presentation) end
    local ok, why = baseInstall(game)
    if ok == false then return false, why end
    local lightsOk, lightsWhy = campaign.floorLights.install(game)
    if lightsOk == false and lightsWhy ~= "already installed" then
      return false, "floor-lights:" .. tostring(lightsWhy)
    end
    local function refreshPassableObjects(ev)
      return campaign.refreshPassableObjects(game, ev)
    end
    -- Run after route/floor-light reconciliation.  The helper only promotes
    -- definitions explicitly authored passable=true, so the ordering cannot
    -- turn a tangible floor light into a walk-through object.
    mod.events:on("map.entered", refreshPassableObjects, -600)
    mod.events:on("map.reloaded", refreshPassableObjects, -600)
    mod.events:on("save.loaded", refreshPassableObjects, -600)
    mod.events:on("save.created", refreshPassableObjects, -600)
    campaign.refreshPassableObjects(game)
    campaign.presentationMode = presentation
    if presentation == "legacy-native-darkness" then
      campaign.visibilityCompat = load("hidden_evolution_visibility_compat.lua")(mod, {
        routes = campaign.load(), voxelRenderer = opts.voxelRenderer,
      })
      local visibilityOk, visibilityWhy = campaign.visibilityCompat.install(game)
      if visibilityOk == false and visibilityWhy ~= "already installed" then
        return false, "legacy-visibility:" .. tostring(visibilityWhy)
      end
      campaign.presentationMode = campaign.visibilityCompat.presentation
    end
    local encountersOk, encountersWhy = campaign.encounters.install(game)
    if encountersOk == false then return false, encountersWhy end
    return true, campaign.presentationMode
  end
  return campaign
end
