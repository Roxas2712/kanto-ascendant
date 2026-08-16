-- Package A: the final, character-routed entrance architecture.
--
-- The legacy Route 22 entrance remains on disk as a migration fallback, but
-- this controller is authoritative: no Johto Signals state is consulted.
-- Coordinates were checked against the supported Kanto map registry and its
-- authored overworld collision data (not guessed from a screenshot).
return function(mod, opts)
  opts = opts or {}

  local A = { registered = false, installed = false, game = nil }
  local derivedAsset = "assets/" .. "generated/hidden_evolution/"
  -- Interaction and art are deliberately separate. The NPC stays on the
  -- solid wall cell so the vanilla talk path remains authoritative, but its
  -- The anchor itself stays transparent; the visible fissure is composited
  -- directly onto the authored wall face.
  -- art and can therefore lie on the cliff in both flat and voxel renderers.
  local FISSURE_ANCHOR = "SPRITE_KA_HEVO_FISSURE_ANCHOR"
  local SHARED_TUNNEL = "KA_HEVO_TUNNEL_ALL"
  -- Leave a full native-camera-width of solid rock between shafts.  The
  -- earlier centres (3/8/13) were collision-isolated, but an adjacent shaft
  -- could still enter the viewport.  RED keeps its original centre; BLUE and
  -- GREEN move into the unused rock mass at centres 13 and 23.
  local SHARED_TUNNEL_WIDTH = 27
  local SHARED_TUNNEL_CENTRES = { 3, 13, 23 }
  local LEGACY_TUNNELS = {
    RED = "KA_HEVO_TUNNEL_RED",
    BLUE = "KA_HEVO_TUNNEL_BLUE",
    GREEN = "KA_HEVO_TUNNEL_GREEN",
  }
  -- The user's accepted Map-Studio layout has three isolated shafts in one
  -- native CAVERN map. Coordinates are engine cells, not metatile blocks.
  -- The upper pads sit on CAVERN block $7c's real warp cell; the lower pads
  -- sit on block $23's real warp cell. No controller-side teleport is needed.
  local BRANCHES = {
    RED = {
      entry = { x = 6, y = 21, facing = "up" },
      returnPad = { x = 6, y = 22 }, trialPad = { x = 7, y = 1 },
      returnSlot = 1, trialSlot = 4,
    },
    BLUE = {
      entry = { x = 26, y = 21, facing = "up" },
      returnPad = { x = 26, y = 22 }, trialPad = { x = 27, y = 1 },
      returnSlot = 2, trialSlot = 5,
    },
    GREEN = {
      entry = { x = 46, y = 21, facing = "up" },
      returnPad = { x = 46, y = 22 }, trialPad = { x = 47, y = 1 },
      returnSlot = 3, trialSlot = 6,
    },
  }
  local SITES = {
    RED = {
      map = "ROUTE_22", fissure = { x = 35, y = 1 }, approach = { x = 35, y = 2, facing = "up" },
      -- The interaction cell stays reachable below the solid wall; only the
      -- site keeps the requested six-pixel elevation; the matching wall-local
      -- correction prevents the sparse reference mask leaving the rock face.
      decalElevation = 6, decalFaceOffsetY = 6,
      tunnel = SHARED_TUNNEL, legacyTunnel = LEGACY_TUNNELS.RED,
      campaignStart = "KA_HEVO_RED_UPPER", branch = BRANCHES.RED,
    },
    BLUE = {
      -- The hidden opening belongs on the rear cliff beyond Nugget Bridge,
      -- not on the first foreground wall.  (10,3) is native solid rock and
      -- (10,4) is its unobstructed talk cell, roughly five tiles deeper than
      -- the rejected foreground placement at (10,7)/(10,8).
      map = "ROUTE_24", fissure = { x = 10, y = 3 }, approach = { x = 10, y = 4, facing = "up" },
      decalElevation = 0,
      tunnel = SHARED_TUNNEL, legacyTunnel = LEGACY_TUNNELS.BLUE,
      campaignStart = "KA_HEVO_BLUE_FROST_THRESHOLD", branch = BRANCHES.BLUE,
    },
    GREEN = {
      -- Centre of Route 3's long straight north rock face. The seven-cell
      -- checked span is uniform tile $37 with a fully clear approach row,
      -- away from Mt. Moon's corner and every map edge.
      map = "ROUTE_3", fissure = { x = 41, y = 3 }, approach = { x = 41, y = 4, facing = "up" },
      decalElevation = 0,
      tunnel = SHARED_TUNNEL, legacyTunnel = LEGACY_TUNNELS.GREEN,
      campaignStart = "KA_HEVO_GREEN_THRESHOLD", branch = BRANCHES.GREEN,
    },
  }
  local TRIAL_MAPS = {
    RED = {
      KA_HEVO_RED_UPPER=true, KA_HEVO_RED_ABYSS=true,
      KA_HEVO_RED_RECOVERY=true, KA_HEVO_RED_LOWER=true,
      KA_HEVO_RED_SHRINE=true,
    },
    BLUE = {
      KA_HEVO_BLUE_FROST_THRESHOLD=true, KA_HEVO_BLUE_FROST_HALL=true,
      KA_HEVO_BLUE_GLACIER_MAZE=true, KA_HEVO_BLUE_TIDAL_DEPTHS=true,
      KA_HEVO_BLUE_KYOGRE_SHRINE=true,
    },
    GREEN = {
      KA_HEVO_GREEN_THRESHOLD=true, KA_HEVO_GREEN_GROVE=true,
      KA_HEVO_GREEN_MIST=true, KA_HEVO_GREEN_RAYQUAZA_SHRINE=true,
    },
  }
  -- Safe, non-warp cells inside the three final shrines.  These are used
  -- both by the live destination guard and by save migration so an older RC
  -- save that entered the wrong character's shrine cannot remain trapped.
  local SHRINE_RETURNS = {
    RED = { map="KA_HEVO_RED_SHRINE", x=3, y=31, facing="up" },
    BLUE = { map="KA_HEVO_BLUE_KYOGRE_SHRINE", x=3, y=27, facing="up" },
    GREEN = { map="KA_HEVO_GREEN_RAYQUAZA_SHRINE", x=3, y=35, facing="up" },
  }
  A.sites = SITES
  A.trialMaps = TRIAL_MAPS
  A.shrineReturns = SHRINE_RETURNS
  A.sharedTunnel = SHARED_TUNNEL
  A.legacyTunnels = LEGACY_TUNNELS
  A.branches = BRANCHES
  A.flags = {
    architecture = "KA_HEVO_CHARACTER_ARCHITECTURE_V1",
    entered = "KA_HEVO_CHARACTER_TUNNEL_ENTERED_",
    -- Set only by the matching post-Hall-of-Fame field researcher dialogue.
    discovered = "KA_HEVO_FISSURE_DISCOVERED_",
  }

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end
  local function slotIdentity(game)
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
    local state, present = slotIdentity(game)
    if present then
      if type(state) ~= "table" then return nil end
      local raw = type(state.player_character) == "string"
        and state.player_character:upper() or nil
      return raw and SITES[raw] and raw or nil
    end
    local raw
    if type(opts.activeCharacter) == "function" then
      raw=opts.activeCharacter(game)
      if raw ~= nil then
        raw=type(raw)=="string" and raw:upper() or nil
        return raw and SITES[raw] and raw or nil
      end
    end
    local c = opts.characters
    if c and type(c.getPlayerCharacter) == "function" then
      raw=c.getPlayerCharacter()
      if raw ~= nil then
        raw=type(raw)=="string" and raw:upper() or nil
        return raw and SITES[raw] and raw or nil
      end
    end
    -- Official pre-6.5 saves have no extended-character bucket because RED
    -- was the sole playable identity. The matching researcher already applies
    -- this migration rule; the physical entrance must resolve it identically
    -- or a legacy Champion can solve Aster's clue and still see no opening.
    return game and game.save and "RED" or nil
  end
  local function show(game, text, done, options)
    if type(opts.showText) == "function" then
      return opts.showText(game, text, done, options)
    end
    game.stack:push(require("src.render.TextBox").new(game, text, done,
      options)); return true
  end
  local function warp(game, map, pos)
    if mod.world and mod.world.warpTo then return mod.world:warpTo(map, pos.x, pos.y, pos.facing) end
    local ow = game and game.overworld
    if ow and ow.startWarpTo then ow:startWarpTo(map, pos.x, pos.y, pos.facing); return true end
    return false, "no overworld"
  end
  local function activeSave(game)
    return type(game and game.save) == "table" and game.save
      or type(A.game and A.game.save) == "table" and A.game.save or nil
  end
  local function saveBucket(save)
    local modData = type(save and save.modData) == "table" and save.modData
    return type(modData) == "table" and type(modData[mod.id]) == "table"
      and modData[mod.id] or nil
  end
  local function ownTrialMap(key, mapId)
    return type(TRIAL_MAPS[key]) == "table"
      and TRIAL_MAPS[key][mapId] == true
  end
  local function trialOwner(mapId)
    for key, maps in pairs(TRIAL_MAPS) do
      if maps[mapId] == true then return key end
    end
  end
  local function rawCharacter(save)
    local bucket = saveBucket(save)
    local chars = bucket and bucket.extended_characters or nil
    if chars == nil then return nil, false end
    if type(chars) ~= "table" then return nil, true end
    local raw = type(chars.player_character) == "string"
      and chars.player_character:upper() or nil
    return raw and SITES[raw] and raw or nil, true
  end
  local function completedSeal(save, key)
    local bucket = saveBucket(save) or {}
    local run = type(bucket.hevo_run) == "table" and bucket.hevo_run
      or type(save and save.hevo_run) == "table" and save.hevo_run or {}
    local dungeon = type(run.dungeonLegacy) == "table"
      and run.dungeonLegacy or {}
    return type(dungeon.seals) == "table" and dungeon.seals[key] == true
  end
  function A.entranceAvailable(key, game)
    if not SITES[key] or character(game or A.game) ~= key then
      return false, "character"
    end
    local save = activeSave(game)
    local flags = type(save and save.flags) == "table" and save.flags or {}
    if flags[A.flags.discovered .. key] == true then
      return true, "discovered"
    end
    -- The external entrance has one authority: the matching researcher's
    -- solved deduction.  Legacy entered/completion receipts are still used
    -- by save-location migration to rescue somebody already inside a trial,
    -- but must not reopen a route-side fissure and bypass a failed 250-step
    -- researcher cooldown.
    return false, "research"
  end
  local function sharedTunnelBlocks()
    -- Reference geometry from hidden-evolution-dungeon-3.json, SHA-256
    -- 35e2176fdbcba08602cd3f327cc8052dea2d39c0e0cdecf819d1ee8a8d09576a.
    -- The three-cell shaft profile remains byte-for-byte identical; the
    -- final map repositions that profile in a wider solid-rock field so one
    -- character can no longer see a neighbouring path.
    local importedRows = {
      {3,3,20,124,22,3,3,20,124,22,3,3,20,124,22,3,3,3,3,3,3,3,3,3},
      {3,3,24,25,26,3,3,24,25,26,3,3,24,25,26,3,3,3,3,3,3,3,3,3},
      {3,3,28,41,30,3,3,28,41,30,3,3,28,41,30,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      {3,3,125,1,125,3,3,125,1,125,3,3,125,1,125,3,3,3,3,3,3,3,3,3},
      -- The three $00 cells in the imported final row were blank editor
      -- filler, not walkable or decorative tunnel geometry.  At the lower
      -- pads they rendered as 160px white rectangles in a full viewport.
      -- Normalize only those inert cells to the same solid $03 rock mass;
      -- the three $23 return-pad blocks and their $7d walls stay untouched.
      {3,3,125,35,125,3,3,125,35,125,3,3,125,35,125,3,3,3,3,3,3,3,3,3},
    }
    local rows = {}
    for _, imported in ipairs(importedRows) do
      local row = {}
      for x = 1, SHARED_TUNNEL_WIDTH do row[x] = 3 end
      for _, centre in ipairs(SHARED_TUNNEL_CENTRES) do
        row[centre] = imported[3]
        row[centre + 1] = imported[4]
        row[centre + 2] = imported[5]
      end
      rows[#rows + 1] = row
    end
    local blocks = {}
    for _, row in ipairs(rows) do
      for _, block in ipairs(row) do blocks[#blocks + 1] = block end
    end
    return blocks
  end
  A.sharedTunnelBlocks = sharedTunnelBlocks
  local function layoutHash(blocks)
    local h = 1
    -- Small-modulus rolling checksum: deterministic on LuaJIT's doubles and
    -- sufficient to prove the authored layout identity in Package-A tests.
    for _, block in ipairs(blocks) do h = (h * 31 + block + 1) % 65521 end
    return ("hevo-a-%04x"):format(h)
  end
  A.layoutHash = layoutHash
  local function map(id, index, width, height, blocks, warps)
    mod.content.maps:register(id, {
      id = id, index = index, label = tr("FISSURE TUNNEL", "RISS-TUNNEL"), tileset = "CAVERN",
      -- Solid native CAVERN rock ($03) fills both the enlarged gaps and the
      -- out-of-bounds camera border, so no neighbouring shaft or blank block
      -- can enter the viewport near a return pad.
      width = width, height = height, borderBlock = 3, blocks = blocks,
      warps = warps or {}, objects = {}, signs = {}, connections = {},
      -- Public Map-Studio/DRAMALESS metadata: cave is flat-ground, never flyable.
      voxelMode = "FULL", voxelRevision = 2,
      layoutHash = layoutHash(blocks),
      sourceProjectHash = "35e2176fdbcba08602cd3f327cc8052dea2d39c0e0cdecf819d1ee8a8d09576a",
      generation = "Kanto Ascendant 6.5 RC", sourceTileset = "CAVERN",
      theme = "g1_cavern", atmosphere = { effect = "none", intensity = 50, visibility = 5 },
      outdoor = false,
    })
    mod.content.encounters:register(id, { grass = { rate = 0, slots = {} } })
  end
  local function siteForMap(mapId)
    for key, site in pairs(SITES) do
      if site.map == mapId or site.tunnel == mapId or site.legacyTunnel == mapId then
        return key, site
      end
    end
  end

  local function mapDefinition(game, mapId)
    local maps = game and game.data and game.data.maps
    if type(maps) == "table" and type(maps[mapId]) == "table" then
      return maps[mapId]
    end
    if mod.content and mod.content.maps and mod.content.maps.get then
      return mod.content.maps:get(mapId)
    end
  end

  local function decalId(key)
    return "KA_HEVO_WALL_FISSURE_" .. key
  end

  local function fissureDecal(key, site)
    return {
      id = decalId(key),
      image = derivedAsset .. "sealed_fissure.png",
      cellX = site.fissure.x, cellY = site.fissure.y,
      face = "south", elevation = site.decalElevation,
      faceOffsetY = site.decalFaceOffsetY,
    }
  end

  local function removeDecal(def, key)
    local rows = def and def.wallDecals
    if type(rows) ~= "table" then return false end
    local changed = false
    for index = #rows, 1, -1 do
      if rows[index] and rows[index].id == decalId(key) then
        table.remove(rows, index)
        changed = true
      end
    end
    return changed
  end

  local function setDecal(game, key, visible)
    local site = SITES[key]
    local def = site and mapDefinition(game, site.map)
    if not def then return false, "map unavailable" end
    removeDecal(def, key)
    if visible then
      def.wallDecals = type(def.wallDecals) == "table" and def.wallDecals or {}
      def.wallDecals[#def.wallDecals + 1] = fissureDecal(key, site)
    end
    return true
  end

  local function runtimeAnchorIds(game, key)
    local site = SITES[key]
    local def = site and mapDefinition(game, site.map)
    local ids = {}
    for _, object in ipairs(def and def.objects or {}) do
      if object.runtime and object.owner == mod.id
          and object.name == "KA_HEVO_FISSURE_" .. key then
        ids[#ids + 1] = site.map .. "_obj_" .. tostring(object.index)
      end
    end
    return ids
  end

  local function removeAnchors(game, key)
    local changed = false
    local ids = runtimeAnchorIds(game, key)
    if mod.world and mod.world.removeNpc then
      for _, id in ipairs(ids) do
        local ok = mod.world:removeNpc(id)
        changed = ok and true or changed
      end
    end
    -- WorldAPI intentionally becomes a quiet no-op when the title/new-save
    -- transition has no live overworld. Runtime definitions still reside in
    -- the merged map catalog, so remove only this mod's owned anchors there as
    -- a fail-closed fallback; otherwise Continue -> New Game can inherit one.
    local site = SITES[key]
    local def = site and mapDefinition(game, site.map)
    for index = #(def and def.objects or {}), 1, -1 do
      local object = def.objects[index]
      if object.runtime and object.owner == mod.id
          and object.name == "KA_HEVO_FISSURE_" .. key then
        table.remove(def.objects, index)
        changed = true
      end
    end
    return changed
  end

  local function currentMapId(game)
    local ow = mod.world and mod.world.overworld and mod.world:overworld()
    return ow and ow.map and ow.map.id
      or game and game.overworld and game.overworld.map
        and game.overworld.map.id or nil
  end

  function A.clearEntrances(game)
    game = game or A.game
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      setDecal(game, key, false)
      removeAnchors(game, key)
    end
    return true
  end

  function A.register()
    if A.registered then return false, "already registered" end
    mod.content.sprites:register(FISSURE_ANCHOR, {
      id = FISSURE_ANCHOR, image = derivedAsset .. "interaction_anchor.png",
      frames = 1, walker = false,
    })
    for key, site in pairs(SITES) do
      local text = "TEXT_KA_HEVO_FISSURE_" .. key
      mod.content.text:register(text, tr("A narrow fissure answers only its rightful traveler.",
        "Ein schmaler Riss antwortet nur dem richtigen Reisenden."))
      mod.content.text_pointers:patch("???", { [text] = { text = text } })
      -- The crack is save-local progression art.  Registering it in the merged
      -- map catalog made it visible in every slot, including a brand-new game.
      -- `refresh` below adds both decal and talk anchor only after the matching
      -- post-Hall researcher has set the canonical discovery flag (or an older
      -- completed path supplies the narrow compatibility authority).
      mod.content.map_scripts:register(site.map, { priority = 2700, talk = {
        [text] = function(game, _, _, done) return A.enter(key, game, done) end,
      }})
    end
    local warps = {}
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      local site, pad = SITES[key], BRANCHES[key].returnPad
      -- Route maps do not have a reciprocal numbered warp at the fissure.
      -- LAST_MAP remains the engine's cave-exit contract; the destination
      -- resolver below then restores the exact character-specific approach.
      site.returnWarp = { x = pad.x, y = pad.y, destMap = "LAST_MAP", destWarp = 1 }
      warps[#warps + 1] = site.returnWarp
    end
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      local site, pad = SITES[key], BRANCHES[key].trialPad
      site.trialWarp = { x = pad.x, y = pad.y, destMap = site.campaignStart, destWarp = 1 }
      warps[#warps + 1] = site.trialWarp
    end
    map(SHARED_TUNNEL, 1920, SHARED_TUNNEL_WIDTH, 12, sharedTunnelBlocks(), warps)
    -- A custom map without a song assignment inherits the route music that
    -- happened to be playing before the fissure warp.  The approach shaft is
    -- already part of the trial, so switch to the same authored dungeon
    -- score before the character-specific first floor.
    if mod.content.map_songs then
      mod.content.map_songs:register(SHARED_TUNNEL, "Music_KA_DeepEvolution")
    end
    A.registered = true
    return true
  end

  function A.enter(key, game, done)
    local site = assert(SITES[key])
    A.game = game or A.game
    local available, why = A.entranceAvailable(key, A.game)
    if why == "character" then
      return show(A.game, tr("The fissure stays still. This path is not yours.",
        "Der Riss bleibt still. Dieser Pfad ist nicht deiner."), done)
    end
    if not available then
      return show(A.game, tr(
        "The fissure is sealed. A field researcher must trace it first.",
        "Der Riss ist versiegelt. Erst muss ein Feldforscher ihn deuten."), done)
    end
    local air = {
      RED = tr("A hot, dry draft seeps from the rock.",
        "Ein heißer, trockener Luftzug dringt aus dem Fels."),
      BLUE = tr("A cold, damp draft seeps from the rock.",
        "Ein kalter, feuchter Luftzug dringt aus dem Fels."),
      GREEN = tr("An unusually clear wind stirs behind the rock.",
        "Ein ungewöhnlich klarer Wind weht hinter dem Fels."),
    }
    local question = air[key] .. tr(
      "\fThere is a fissure behind the wall.\nEnter it?",
      "\fHinter der Wand ist ein Spalt.\nRiss betreten?")
    return show(A.game, question, done, {
      defaultNo = true,
      choice = function(yes)
        if not yes then if done then done() end; return false, "cancelled" end
        if mod.world and mod.world.setFlag then
          mod.world:setFlag(A.flags.architecture, true)
          mod.world:setFlag(A.flags.entered .. key, true)
        end
        -- Each fissure lands in its own isolated shaft, one cell clear of the
        -- physical return pad, so a spawn can never retrigger the exit.
        local ok, warpWhy = warp(A.game, SHARED_TUNNEL, site.branch.entry)
        if done then done() end
        return ok, warpWhy
      end,
    })
  end

  function A.leave(key, game)
    local site = assert(SITES[key])
    return warp(game or A.game, site.map, site.approach)
  end

  function A.resolveTunnelWarp(mapId, x, y, ctx)
    local warpDef=ctx and ctx.warp
    if not warpDef then return mapId,x,y end
    for _,site in pairs(SITES) do
      local tunnel=ctx and ctx.data and ctx.data.maps and ctx.data.maps[SHARED_TUNNEL]
      local isReturn=warpDef==site.returnWarp
      if tunnel and tunnel.warps then
        for _,candidate in ipairs(tunnel.warps) do
          if candidate==warpDef and candidate.x==site.branch.returnPad.x
              and candidate.y==site.branch.returnPad.y then isReturn=true end
        end
      end
      if isReturn then return site.map,site.approach.x,site.approach.y end
    end
    return mapId,x,y
  end

  -- The shared end room contains three authored return pads for visual
  -- symmetry, but only the active character's trial is ever a legal
  -- destination.  Older builds let RED walk into BLUE/GREEN (and vice
  -- versa), which could strand the save behind character-specific gates.
  function A.resolveCharacterTrialWarp(mapId, x, y, gameOrSave)
    local owner = trialOwner(mapId)
    if not owner then return mapId, x, y end
    local save = type(gameOrSave and gameOrSave.save) == "table"
      and gameOrSave.save or gameOrSave
    if type(save) ~= "table" then save = activeSave(A.game) end
    -- The save-bound identity is authoritative for a destination guard.
    -- Presentation/global character state may still describe the previous
    -- slot during load/swap; consulting it first can route a BLUE or GREEN
    -- save through RED's shaft.  Legacy records without the explicit field
    -- retain the API fallback below.
    local key, identityPresent = rawCharacter(save)
    if not identityPresent then
      key = character(type(gameOrSave and gameOrSave.save) == "table"
        and gameOrSave or A.game)
    end
    if not key or owner == key then return mapId, x, y end
    if completedSeal(save, key) then
      local target = SHRINE_RETURNS[key]
      return target.map, target.x, target.y
    end
    local entry = BRANCHES[key].entry
    return SHARED_TUNNEL, entry.x, entry.y
  end

  function A.migrateSaveLocation(save)
    local player = save and save.player
    if type(player) ~= "table" then return false end
    local function retainAdmission(key)
      save.flags = type(save.flags) == "table" and save.flags or {}
      local flag = A.flags.entered .. key
      local changed = save.flags[flag] ~= true
      save.flags[flag] = true
      return changed
    end
    for key, oldMap in pairs(LEGACY_TUNNELS) do
      if player.map == oldMap then
        local entry = BRANCHES[key].entry
        player.map, player.x, player.y, player.facing =
          SHARED_TUNNEL, entry.x, entry.y, entry.facing
        player.surfing = false
        retainAdmission(key)
        return true, key
      end
    end
    local owner = trialOwner(player.map)
    local key, identityPresent = rawCharacter(save)
    if not identityPresent then key = character(A.game) end
    if owner and key and owner ~= key then
      local target = completedSeal(save, key) and SHRINE_RETURNS[key]
        or BRANCHES[key].entry
      player.map = completedSeal(save, key) and target.map or SHARED_TUNNEL
      player.x, player.y, player.facing = target.x, target.y, target.facing
      player.surfing = false
      retainAdmission(key)
      return true, key
    end
    for key in pairs(TRIAL_MAPS) do
      if ownTrialMap(key, player.map) then
        return retainAdmission(key), key
      end
    end
    return false
  end

  function A.refresh(game, mapId)
    A.game = game or A.game
    game = game or A.game
    mapId = mapId or currentMapId(game)
    local activeKey, activeSite = siteForMap(mapId)
    local active = activeSite and activeSite.map == mapId and activeKey or nil
    local spawned = false
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      local available = A.entranceAvailable(key, game) == true
      setDecal(game, key, available)
      -- Runtime definitions live in the merged map catalog, not in a save.
      -- Reconcile every slot/map boundary so a prior discovered slot cannot
      -- leak an interaction anchor into New Game or another character.
      removeAnchors(game, key)
      if available and active == key and mod.world and mod.world.spawnNpc then
        local site = SITES[key]
        local id = mod.world:spawnNpc(site.map, {
          name = "KA_HEVO_FISSURE_" .. key, sprite = FISSURE_ANCHOR,
          -- The native rock cell remains the physical collision authority.
          -- Before discovery this actor does not exist at all; afterward it is
          -- passable metadata so Wilds/followers do not see a second wall.
          renderMode = "none", passable = true, movement = "STAY", range = "NONE",
          x = site.fissure.x, y = site.fissure.y,
          text = "TEXT_KA_HEVO_FISSURE_" .. key,
        })
        spawned = id ~= nil or spawned
      end
    end
    return spawned or active == nil
  end

  function A.install(game)
    if A.installed then return false, "already installed" end
    A.installed, A.game = true, game or A.game
    mod.events:on("save.loading", function(ev)
      -- The merged map catalog survives slot changes.  Clear the outgoing
      -- slot's art/actors before the incoming save becomes authoritative.
      A.clearEntrances(A.game)
      A.migrateSaveLocation(ev and ev.raw)
    end, 4000)
    mod.events:on("save.loaded", function(ev)
      A.migrateSaveLocation(ev and ev.save)
      local active = ev and ev.game or A.game
      A.refresh(active, currentMapId(active))
    end, 4000)
    mod.events:on("save.created", function(ev)
      local active = ev and ev.game or A.game
      A.clearEntrances(active)
      A.refresh(active, currentMapId(active))
    end, 4000)
    if mod.hooks and type(mod.hooks.wrap)=="function" then
      mod.hooks:wrap("warp.destination", function(nextDestination, mapId, x, y, ctx)
        local destMap,destX,destY=nextDestination(mapId,x,y,ctx)
        destMap,destX,destY=A.resolveTunnelWarp(destMap,destX,destY,ctx)
        return A.resolveCharacterTrialWarp(destMap,destX,destY,
          ctx and ctx.game or A.game)
      end)
    end
    mod.events:on("map.entered", function(ev)
      local active = ev and ev.game or A.game
      local mapId = ev and (ev.mapId or ev.map and ev.map.id)
      A.refresh(active, mapId)
    end)
    mod.events:on("map.reloaded", function(ev)
      local active = ev and ev.game or A.game
      local mapId = ev and (ev.mapId or ev.map and ev.map.id)
      A.refresh(active, mapId)
    end)
    A.clearEntrances(A.game)
    return true
  end
  return A
end
