-- Static Johto Signals content: two key items and one self-contained research
-- outpost.  Progression and encounter logic live in their controller modules.

local Module = {
  MAP_ID = "KANTO_ASCENDANT_DRIFTGLASS",
  MAP_INDEX = 1900,
  PALLET_MAP_ID = "PALLET_TOWN",
  ITEMS = {
    MIGRATION_RECEIVER = "MIGRATION_RECEIVER",
    RESONANCE_SEAL = "RESONANCE_SEAL",
  },
  PALLET_BOAT = {
    name = "DRIFTGLASS_PALLET_BOAT",
    sprite = "SPRITE_SAILOR",
    preferred = {
      { 8, 14 }, { 9, 14 }, { 8, 15 }, { 9, 15 }, { 6, 12 },
    },
  },
  PALLET_CAPSULE = {
    name = "DRIFTGLASS_DARK_CAPSULE",
    sprite = "SPRITE_POKE_BALL",
    preferred = {
      { 14, 14 }, { 14, 15 }, { 13, 14 }, { 13, 15 }, { 15, 14 },
    },
  },
  PRISM_ENTRANCE = {
    name = "DRIFTGLASS_PRISM_SEAM",
    sprite = "SPRITE_KA_PRISM_SEAM",
    x = 12,
    y = 9,
    approach = { x = 11, y = 9, facing = "right" },
  },
  ARRIVAL = { x = 8, y = 12, facing = "up" },
  PALLET_RETURN = { x = 10, y = 12, facing = "up" },
}

local TEXT = {
  PALLET_BOAT = "TEXT_KA_SIGNALS_PALLET_BOAT",
  PALLET_CAPSULE = "TEXT_KA_SIGNALS_PALLET_CAPSULE",
  RESEARCHER = "TEXT_KA_SIGNALS_RESEARCHER",
  LOOKOUT = "TEXT_KA_SIGNALS_LOOKOUT",
  RETURN_BOAT = "TEXT_KA_SIGNALS_RETURN_BOAT",
  SIGN = "TEXT_KA_SIGNALS_SIGN",
  PRISM_ENTRANCE = "TEXT_KA_SIGNALS_PRISM_ENTRANCE",
}

local function packed(rows)
  local width = #rows[1]
  local blocks = {}
  for rowIndex, row in ipairs(rows) do
    assert(#row == width,
      ("Driftglass row %d has %d blocks; expected %d")
        :format(rowIndex, #row, width))
    for _, block in ipairs(row) do blocks[#blocks + 1] = block end
  end
  return blocks, width, #rows
end

local function currentMap(game, mod)
  local ow = game and game.overworld
  if ow and ow.map then return ow.map.id end
  if mod.world and mod.world.current then
    local current = mod.world:current()
    return current and current.mapId
  end
  local player = game and game.save and game.save.player
  return player and player.map
end

function Module.create(mod, opts)
  assert(mod and mod.content, "Johto Signals requires mod.content")
  opts = opts or {}
  local state = assert(opts.state, "Johto Signals state missing")
  local i18n = opts.i18n
  local tilesetCatalog = mod.content.tilesets
  local catalogAware = type(tilesetCatalog) == "table"
    and type(tilesetCatalog.get) == "function"
  -- Production R/B/Y catalogs all expose OVERWORLD.  A catalog-aware base
  -- that does not must not receive a map which its loader cannot resolve.
  -- Lightweight focused-test doubles predate the tileset registry, so they
  -- keep exercising the authored record exactly as before.
  local mapSupported = not catalogAware
    or tilesetCatalog:get("OVERWORLD") ~= nil

  local C = {
    game = nil,
    registered = false,
    installed = false,
    mapSupported = mapSupported,
    MAP_ID = Module.MAP_ID,
    MAP_INDEX = Module.MAP_INDEX,
    PALLET_MAP_ID = Module.PALLET_MAP_ID,
    PALLET_BOAT = Module.PALLET_BOAT,
    PALLET_CAPSULE = Module.PALLET_CAPSULE,
    ITEMS = Module.ITEMS,
    ARRIVAL = Module.ARRIVAL,
    PALLET_RETURN = Module.PALLET_RETURN,
    TEXT = TEXT,
  }
  local researcherCallback = opts.onResearcher
  local canTravelCallback = opts.canTravel
  local canShowBoatmanCallback = opts.canShowBoatman
  local canShowCapsuleCallback = opts.canShowCapsule
  local capsuleCallback = opts.onCapsule
  local boatmanCallback = opts.onBoatman
  local prismEntranceCallback = opts.onPrismEntrance

  local function tr(english, german)
    return i18n and i18n.text(english, german) or english
  end

  local function show(game, text, onDone, boxOpts)
    if opts.showText then
      return opts.showText(game, text, onDone, boxOpts)
    end
    game.stack:push(require("src.render.TextBox").new(
      game, text, onDone, boxOpts))
    return true
  end

  local function setFrozen(npc, frozen)
    if npc then npc.frozen = frozen and true or false end
  end

  local function travelAllowed(game)
    if type(canTravelCallback) ~= "function" then return false end
    local ok, allowed = pcall(canTravelCallback, game, C)
    if ok then return allowed == true end
    if mod.log and mod.log.error then
      mod.log:error("Driftglass travel callback failed: %s",
        tostring(allowed))
    end
    return false
  end

  local function callbackAllowed(callback, game, label)
    if type(callback) ~= "function" then return false end
    local ok, allowed = pcall(callback, game, C)
    if ok then return allowed == true end
    if mod.log and mod.log.error then
      mod.log:error(label .. " callback failed: %s", tostring(allowed))
    end
    return false
  end

  local function count(name)
    local s = state.section("earlyJohto")
    s[name] = math.max(0, math.floor(tonumber(s[name]) or 0)) + 1
    state.persist()
  end

  local function warp(game, mapId, position)
    if mod.world and mod.world.warpTo then
      local ok, reason = mod.world:warpTo(
        mapId, position.x, position.y, position.facing)
      if ok then return true end
      if reason and reason ~= "no overworld" then return nil, reason end
    end
    local ow = game and game.overworld
    if not (ow and ow.startWarpTo) then return nil, "no overworld" end
    ow:startWarpTo(mapId, position.x, position.y, position.facing)
    return true
  end

  function C.dialogue()
    return {
      travel = tr(
        "BOATMAN:\nThe trip is short.\f"
          .. "I can always bring\nyou back.\f"
          .. "NOTICE:\nSaving is safe.\f"
          .. "You will resume at\nPALLET pier.\f"
          .. "Sail to\nDRIFTGLASS?",
        "BOOTSMANN:\nDie Überfahrt ist\nkurz.\f"
          .. "Ich bringe dich\nsicher zurück.\f"
          .. "HINWEIS:\nSpeichern ist\nsicher.\f"
          .. "Du beginnst wieder\nam ALABASTIA-Steg.\f"
          .. "Nach DRIFTGLAS?"),
      returnTrip = tr(
        "BOATMAN: My launch\nis ready for\nPALLET TOWN."
          .. "\fNo current can\nstrand you here."
          .. "\fReturn now?",
        "BOOTSMANN: Bereit\nfür ALABASTIA."
          .. "\fKeine Strömung\nhält dich fest."
          .. "\fJetzt zurück?"),
      researcher = tr(
        "RESEARCHER:\nPokémon follow\nclimate and food.\f"
          .. "This receiver only\nshows their paths.\f"
          .. "You decide which\npaths may open.",
        "FORSCHER:\nPokémon folgen\nKlima und Nahrung.\f"
          .. "Dieser Empfänger\nzeigt ihre Wege.\f"
          .. "Was sich öffnet,\nbestimmst du."),
      lookout = tr(
        "LOOKOUT:\nDriftglass shines\nunder the water.\f"
          .. "The current flows\nto Kanto today.",
        "AUSGUCK:\nUnter dem Wasser\nglänzt Driftglas.\f"
          .. "Die Strömung geht\nheute nach Kanto."),
      sign = tr(
        "DRIFTGLASS POST\nKANTO MIGRATION\nRESEARCH STATION",
        "DRIFTGLAS-POSTEN\nKANTO-MIGRATION\nFORSCHUNGSSTATION"),
    }
  end

  -- Driftglass is mod-owned content, so a save must never require that map
  -- in order to boot. Game:writeSave emits save.writing after capturing the
  -- current location. Rewriting those save fields deliberately records the
  -- native Pallet landing as the next resume point; the active overworld
  -- controller remains on Driftglass until the player leaves or reloads.
  -- The engine's unknown-map quarantine remains a second line of defence for
  -- older/custom saves made before this rule existed.
  function C.secureSaveLocation(save)
    local player = save and save.player
    if type(player) ~= "table" or player.map ~= Module.MAP_ID then
      return false
    end
    player.map = Module.PALLET_MAP_ID
    player.x = Module.PALLET_RETURN.x
    player.y = Module.PALLET_RETURN.y
    player.facing = Module.PALLET_RETURN.facing
    player.surfing = false
    save.lastOutdoor = {
      id = Module.PALLET_MAP_ID,
      x = Module.PALLET_RETURN.x,
      y = Module.PALLET_RETURN.y,
    }
    C.safeSaveRedirects = (C.safeSaveRedirects or 0) + 1
    return true
  end

  function C.travelToOutpost(game)
    game = game or C.game
    if not C.mapSupported then
      return false, "OVERWORLD tileset unavailable"
    end
    local mapId = currentMap(game, mod)
    if mapId == Module.MAP_ID then return false, "already at outpost" end
    if mapId ~= Module.PALLET_MAP_ID then
      return false, "departure requires Pallet Town"
    end
    if not travelAllowed(game) then return false, "travel not unlocked" end
    local ok, reason = warp(game, Module.MAP_ID, Module.ARRIVAL)
    if ok then count("outpostVisits") end
    return ok, reason
  end

  function C.returnToPallet(game)
    game = game or C.game
    if not C.mapSupported then
      return false, "OVERWORLD tileset unavailable"
    end
    local mapId = currentMap(game, mod)
    if mapId == Module.PALLET_MAP_ID then
      return false, "already in Pallet Town"
    end
    if mapId ~= Module.MAP_ID then
      return false, "return requires Driftglass"
    end
    local ok, reason = warp(game, Module.PALLET_MAP_ID, Module.PALLET_RETURN)
    if ok then count("outpostReturns") end
    return ok, reason
  end

  function C.offerTravel(game, npc, onDone)
    if type(npc) == "function" and onDone == nil then
      onDone, npc = npc, nil
    end
    setFrozen(npc, true)
    return show(game, C.dialogue().travel, nil, {
      defaultNo = true,
      choice = function(yes)
        setFrozen(npc, false)
        if yes then C.travelToOutpost(game) end
        if onDone then onDone(yes) end
      end,
    })
  end

  function C.offerReturn(game, npc, onDone)
    setFrozen(npc, true)
    return show(game, C.dialogue().returnTrip, nil, {
      defaultNo = true,
      choice = function(yes)
        setFrozen(npc, false)
        if yes then C.returnToPallet(game) end
        if onDone then onDone() end
      end,
    })
  end

  function C.interactResearcher(game, ow, npc, onDone)
    local callback = researcherCallback
    if callback then
      local ok, handled = pcall(callback, game, ow, npc, onDone, C)
      if ok and handled ~= false then return handled end
      if not ok and mod.log and mod.log.error then
        mod.log:error("Driftglass researcher callback failed: %s",
          tostring(handled))
      end
    end
    setFrozen(npc, true)
    return show(game, C.dialogue().researcher, function()
      setFrozen(npc, false)
      if onDone then onDone() end
    end)
  end

  function C.interactCapsule(game, ow, npc, onDone)
    local callback = capsuleCallback
    if callback then
      local ok, handled = pcall(callback, game, ow, npc, onDone, C)
      if ok and handled ~= false then return handled end
      if not ok and mod.log and mod.log.error then
        mod.log:error("Pallet capsule callback failed: %s",
          tostring(handled))
      end
    end
    if onDone then onDone() end
    return false
  end

  function C.interactBoatman(game, ow, npc, onDone)
    local callback = boatmanCallback
    if callback then
      local ok, handled = pcall(callback, game, ow, npc, onDone, C)
      if ok and handled ~= false then return handled end
      if not ok and mod.log and mod.log.error then
        mod.log:error("Pallet boatman callback failed: %s",
          tostring(handled))
      end
    end
    return C.offerTravel(game, npc, onDone)
  end

  function C.interactPrismEntrance(game, ow, npc, onDone)
    local callback = prismEntranceCallback
    if callback then
      local ok, handled = pcall(callback, game, ow, npc, onDone, C)
      if ok and handled ~= false then return handled end
      if not ok and mod.log and mod.log.error then
        mod.log:error("Prism Grotto entrance callback failed: %s",
          tostring(handled))
      end
    end
    if onDone then onDone() end
    return false
  end

  local function runtimeIds(game, objectName)
    local ids = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[Module.PALLET_MAP_ID]
    for _, object in ipairs(map and map.objects or {}) do
      if object.runtime and object.owner == mod.id
          and object.name == objectName then
        ids[#ids + 1] = Module.PALLET_MAP_ID
          .. "_obj_" .. tostring(object.index)
      end
    end
    return ids
  end

  local function runtimeBoatIds(game)
    return runtimeIds(game, Module.PALLET_BOAT.name)
  end

  local function runtimeCapsuleIds(game)
    return runtimeIds(game, Module.PALLET_CAPSULE.name)
  end

  local function findSpawnCell(ow, preferred)
    local function free(x, y)
      return ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
        and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
        and not (ow.player.cellX == x and ow.player.cellY == y)
    end
    for _, cell in ipairs(preferred or {}) do
      if free(cell[1], cell[2]) then return cell[1], cell[2] end
    end
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if free(x, y) then return x, y end
      end
    end
  end

  function C.refreshTravelNpc(game, mapId)
    game = game or C.game
    if not (game and mod.world) then return false, "no game" end
    local ids = runtimeBoatIds(game)
    if not C.mapSupported then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return false, "OVERWORLD tileset unavailable"
    end
    local showBoatman = callbackAllowed(
      canShowBoatmanCallback, game, "Pallet boatman")
      or travelAllowed(game)
    if not showBoatman then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return false, "travel not unlocked"
    end

    local ow = mod.world:overworld()
    mapId = mapId or (ow and ow.map and ow.map.id)
    if mapId ~= Module.PALLET_MAP_ID then return false, "not in Pallet Town" end
    if #ids > 0 then
      -- A failed active-map instantiation can leave the runtime definition
      -- behind without a visible NPC. Remove that ghost and recreate it.
      if ow and ow.map and ow.map.id == Module.PALLET_MAP_ID
          and type(mod.world.npc) == "function" then
        local live = mod.world:npc(
          Module.PALLET_MAP_ID, Module.PALLET_BOAT.name)
        if live then return true, "present" end
        for _, id in ipairs(ids) do mod.world:removeNpc(id) end
        ids = {}
      else
        return true, "present"
      end
    end
    if not (ow and ow.map and ow.map.id == Module.PALLET_MAP_ID) then
      return false, "Pallet Town is not active"
    end
    local x, y = findSpawnCell(ow, Module.PALLET_BOAT.preferred)
    if not x then return false, "no safe Pallet Town cell" end
    local id, reason = mod.world:spawnNpc(Module.PALLET_MAP_ID, {
      name = Module.PALLET_BOAT.name,
      sprite = Module.PALLET_BOAT.sprite,
      movement = "STAY",
      range = "DOWN",
      text = TEXT.PALLET_BOAT,
      x = x,
      y = y,
    })
    return id ~= nil, reason or id
  end

  function C.refreshCapsule(game, mapId)
    game = game or C.game
    if not (game and mod.world) then return false, "no game" end
    local ids = runtimeCapsuleIds(game)
    local visible = C.mapSupported and callbackAllowed(
      canShowCapsuleCallback, game, "Pallet capsule")
    if not visible then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return false, "capsule unavailable"
    end

    local ow = mod.world:overworld()
    mapId = mapId or (ow and ow.map and ow.map.id)
    if mapId ~= Module.PALLET_MAP_ID then return false, "not in Pallet Town" end
    if #ids > 0 then
      if ow and ow.map and ow.map.id == Module.PALLET_MAP_ID
          and type(mod.world.npc) == "function" then
        local live = mod.world:npc(
          Module.PALLET_MAP_ID, Module.PALLET_CAPSULE.name)
        if live then return true, "present" end
        for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      else
        return true, "present"
      end
    end
    if not (ow and ow.map and ow.map.id == Module.PALLET_MAP_ID) then
      return false, "Pallet Town is not active"
    end
    local x, y = findSpawnCell(ow, Module.PALLET_CAPSULE.preferred)
    if not x then return false, "no safe Pallet Town cell" end
    local id, reason = mod.world:spawnNpc(Module.PALLET_MAP_ID, {
      name = Module.PALLET_CAPSULE.name,
      sprite = Module.PALLET_CAPSULE.sprite,
      movement = "STAY",
      range = "DOWN",
      text = TEXT.PALLET_CAPSULE,
      x = x,
      y = y,
    })
    return id ~= nil, reason or id
  end

  function C.refreshPalletActors(game, mapId)
    local capsuleOk, capsuleReason = C.refreshCapsule(game, mapId)
    local boatOk, boatReason = C.refreshTravelNpc(game, mapId)
    return capsuleOk or boatOk, capsuleOk and capsuleReason or boatReason
  end

  function C.register()
    if C.registered then return false, "already registered" end

    if mod.content.sprites then
      mod.content.sprites:register(Module.PRISM_ENTRANCE.sprite, {
        id = Module.PRISM_ENTRANCE.sprite,
        image = mod.path .. "/assets/prism_grotto/prism_seam.png",
        frames = 1,
        walker = false,
        trueColor = true,
      })
    end

    for _, row in ipairs({
      { Module.ITEMS.MIGRATION_RECEIVER,
        tr("MIGR. RECEIVER", "MIGR.-EMPF.") },
      { Module.ITEMS.RESONANCE_SEAL,
        tr("RESONANCE SEAL", "RESONANZ-SIEGEL") },
    }) do
      mod.content.items:register(row[1], {
        id = row[1], name = row[2], price = 0,
        keyItem = true, tossable = false, needsTarget = false,
      })
    end

    local blocks, width, height = packed({
      { 67,67,67,67,67,67,67,67,67,67,67,67 },
      { 67,67,24,25,25,25,25,25,25,24,67,67 },
      { 67,24, 1, 1,11,11,11, 1, 1, 1,24,67 },
      { 67,24, 1,10,10, 1, 1,10,10, 1,24,67 },
      { 67,24, 1,10,49,49,49,49,10, 1,24,67 },
      { 67,24, 1, 1,49,116,116,49, 1, 1,24,67 },
      { 67,24, 1,10,49,119, 1,49,10, 1,24,67 },
      { 67,24, 1,10,10, 1, 1,10,10, 1,24,67 },
      { 67,67,24,25,25,25,25,25,25,24,67,67 },
      { 67,67,67,67,67,67,67,67,67,67,67,67 },
    })

    C.mapRecord = {
      id = Module.MAP_ID,
      label = "DriftglassOutpost",
      index = Module.MAP_INDEX,
      tileset = "OVERWORLD",
      palette = "CERULEAN",
      borderBlock = 67,
      width = width,
      height = height,
      blocks = blocks,
      warps = {},
      connections = {},
      objects = {
        {
          index = 1, name = "DRIFTGLASS_RESEARCHER",
          movement = "STAY", range = "DOWN", sprite = "SPRITE_SCIENTIST",
          text = TEXT.RESEARCHER, x = 9, y = 11,
        },
        {
          index = 2, name = "DRIFTGLASS_LOOKOUT",
          movement = "STAY", range = "LEFT", sprite = "SPRITE_FISHER",
          text = TEXT.LOOKOUT, x = 15, y = 6,
        },
        {
          index = 3, name = "DRIFTGLASS_RETURN_BOAT",
          movement = "STAY", range = "UP", sprite = "SPRITE_SAILOR",
          text = TEXT.RETURN_BOAT, x = 8, y = 15,
        },
        {
          index = 4, name = Module.PRISM_ENTRANCE.name,
          movement = "STAY", range = "NONE",
          sprite = Module.PRISM_ENTRANCE.sprite,
          text = TEXT.PRISM_ENTRANCE,
          x = Module.PRISM_ENTRANCE.x, y = Module.PRISM_ENTRANCE.y,
        },
      },
      signs = {
        { text = TEXT.SIGN, x = 12, y = 13 },
      },
    }
    if C.mapSupported then
      mod.content.maps:register(Module.MAP_ID, C.mapRecord)
      -- A remote research island should not inherit Pallet Town's theme from
      -- the departure map. Cinnabar supplies the native island atmosphere in
      -- Red, Blue and Yellow without bundling or replacing anyone's music.
      -- The ROM-free Modkit fixture intentionally has no music catalog. Skip
      -- the optional assignment only there; imported R/B/Y data exposes the
      -- native song and receives the intended map theme.
      local music = mod.content.music
      if not (music and type(music.get) == "function")
          or music:get("Music_Cinnabar") then
        mod.content.map_songs:register(Module.MAP_ID, "Music_Cinnabar")
      end
      mod.content.map_scripts:register(Module.MAP_ID, {
        priority = 2600,
        talk = {
          [TEXT.RESEARCHER] = function(game, ow, npc, onDone)
            return C.interactResearcher(game, ow, npc, onDone)
          end,
          [TEXT.LOOKOUT] = function(game, _, npc, onDone)
            setFrozen(npc, true)
            return show(game, C.dialogue().lookout, function()
              setFrozen(npc, false)
              if onDone then onDone() end
            end)
          end,
          [TEXT.RETURN_BOAT] = function(game, _, npc, onDone)
            return C.offerReturn(game, npc, onDone)
          end,
          [TEXT.SIGN] = function(game, _, _, onDone)
            return show(game, C.dialogue().sign, onDone)
          end,
          [TEXT.PRISM_ENTRANCE] = function(game, ow, npc, onDone)
            return C.interactPrismEntrance(game, ow, npc, onDone)
          end,
        },
      })
      mod.content.map_scripts:register(Module.PALLET_MAP_ID, {
        priority = 2600,
        talk = {
          [TEXT.PALLET_BOAT] = function(game, _, npc, onDone)
            return C.interactBoatman(game, nil, npc, onDone)
          end,
          [TEXT.PALLET_CAPSULE] = function(game, ow, npc, onDone)
            return C.interactCapsule(game, ow, npc, onDone)
          end,
        },
      })
    end

    C.registered = true
    if C.mapSupported and mod.events and mod.events.on then
      mod.events:on("map.entered", function(ev)
        local game = ev and ev.game or C.game
        local mapId = ev and (ev.mapId or ev.map and ev.map.id)
        if game then C.refreshPalletActors(game, mapId) end
      end, 120)
      mod.events:on("player.step", function(ev)
        local game = ev and ev.game or C.game
        local mapId = ev and (ev.mapId or ev.map and ev.map.id)
        if not mapId and game and game.overworld and game.overworld.map then
          mapId = game.overworld.map.id
        end
        if game and mapId == Module.PALLET_MAP_ID then
          C.refreshPalletActors(game, mapId)
        end
      end, 120)
      mod.events:on("save.loaded", function(ev)
        C.game = ev and ev.game or C.game
        if C.game then C.refreshPalletActors(C.game) end
      end, 120)
      -- Run after ordinary progress snapshotters so this final location in
      -- the encoded file is always a native, mod-independent landing.
      mod.events:on("save.writing", function(ev)
        C.secureSaveLocation(ev and ev.save)
      end, -10000)
    end
    return true
  end

  function C.install(game, callbacks)
    C.game = game or C.game
    if callbacks and callbacks.onResearcher then
      researcherCallback = callbacks.onResearcher
    end
    if callbacks and callbacks.canTravel then
      canTravelCallback = callbacks.canTravel
    end
    if callbacks and callbacks.canShowBoatman then
      canShowBoatmanCallback = callbacks.canShowBoatman
    end
    if callbacks and callbacks.canShowCapsule then
      canShowCapsuleCallback = callbacks.canShowCapsule
    end
    if callbacks and callbacks.onCapsule then
      capsuleCallback = callbacks.onCapsule
    end
    if callbacks and callbacks.onBoatman then
      boatmanCallback = callbacks.onBoatman
    end
    if callbacks and callbacks.onPrismEntrance then
      prismEntranceCallback = callbacks.onPrismEntrance
    end
    if state.install then state.install(C.game) end
    C.installed = C.game ~= nil
    if C.installed then C.refreshPalletActors(C.game) end
    return C.installed
  end

  function C.status()
    return {
      registered = C.registered,
      installed = C.installed,
      mapId = Module.MAP_ID,
      mapIndex = Module.MAP_INDEX,
      mapSupported = C.mapSupported,
      currentMap = currentMap(C.game, mod),
      safeSaveRedirects = C.safeSaveRedirects or 0,
      state = state.status and state.status() or nil,
    }
  end

  return C
end

return Module
