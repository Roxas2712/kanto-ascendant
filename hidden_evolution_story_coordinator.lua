-- E-SHARED/STORY contract.  This is intentionally the only composition point
-- for optional tunnel/path packages; missing packages fail closed at release.
return function(mod, opts)
  opts = opts or {}
  local C = { registered = false }
  C.CONTRACT = {
    version = 2,
    shared = "KA_HEVO_SHARED_SEALED_ANTECHAMBER",
    tunnel = "KA_HEVO_TUNNEL_ALL",
    starts = { RED = "KA_HEVO_RED_UPPER", BLUE = "KA_HEVO_BLUE_FROST_THRESHOLD", GREEN = "KA_HEVO_GREEN_THRESHOLD" },
    ends = { RED = "KA_HEVO_RED_SHRINE", BLUE = "KA_HEVO_BLUE_KYOGRE_SHRINE", GREEN = "KA_HEVO_GREEN_RAYQUAZA_SHRINE" },
    tunnels = { RED = "KA_HEVO_TUNNEL_ALL", BLUE = "KA_HEVO_TUNNEL_ALL", GREEN = "KA_HEVO_TUNNEL_ALL" },
  }
  C.END_WARPS = {
    RED = { x = 37, y = 3 },
    BLUE = { x = 37, y = 3 },
    GREEN = { x = 57, y = 3 },
  }
  local FILES = {
    shared = "hidden_evolution_shared_story.lua",
    hints = "hidden_evolution_story_hints.lua",
    tunnel = "hidden_evolution_architecture.lua",
    RED = "hidden_evolution_red_path.lua",
    BLUE = "hidden_evolution_blue_campaign.lua",
    GREEN = "hidden_evolution_green_grove.lua",
  }

  local function fail(message)
    error("Hidden Evolution story contract failure: " .. message, 2)
  end
  local function load(name)
    local source = opts.modules and opts.modules[name]
    if source then return source end
    local loader = opts.load
    if type(loader) ~= "function" then
      if name == "RED" or name == "BLUE" or name == "GREEN" then
        fail(name .. " path package missing")
      end
      fail("missing optional module " .. FILES[name])
    end
    local ok, factory = pcall(loader, FILES[name])
    if not ok or type(factory) ~= "function" then fail("missing optional module " .. FILES[name]) end
    local pathOpts = {
      i18n = opts.i18n, isGerman = opts.isGerman,
      questionUi = opts.questionUi,
      characters = opts.characters or (mod.exports and mod.exports.extendedCharacters),
      postgame = opts.postgame,
      legacyDungeonAdapter = opts.legacyDungeonAdapter,
      megaEvolution = opts.megaEvolution,
      journey = opts.journey,
      voxelRenderer = opts.voxelRenderer,
    }
    pathOpts.activeCharacter = opts.activeCharacter or function(game)
      local chars = pathOpts.characters
      return chars and chars.getPlayerCharacter and chars.getPlayerCharacter()
    end
    if name == "RED" or name == "BLUE" or name == "GREEN" then
      pathOpts.commonAntechamberId = C.CONTRACT.tunnels[name]
      pathOpts.sharedSealedAntechamberId = C.CONTRACT.shared
      pathOpts.character = name
    end
    local module = factory(mod, pathOpts)
    if type(module) ~= "table" then fail("invalid module " .. FILES[name]) end
    return module
  end

  function C.load()
    if C.modules then return C.modules end
    C.modules = { shared = load("shared"), hints = load("hints"), tunnel = load("tunnel") }
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do C.modules[key] = load(key) end
    return C.modules
  end

  function C.pathIds(path)
    local ids = path and path.IDS or {}
    local source = path and path.ids or {}
    return { upper = ids.upper or ids.threshold or source.THRESHOLD,
      shrine = ids.shrine or ids.SHRINE or source.SHRINE }
  end

  function C.validate(modules)
    modules = modules or C.load()
    local shared = modules.shared
    if not (shared and shared.ID == C.CONTRACT.shared and type(shared.register) == "function") then
      fail("shared end room is absent or has the wrong stable ID")
    end
    local tunnel = modules.tunnel
    if not (tunnel and tunnel.sites and type(tunnel.register) == "function") then fail("tunnel package missing") end
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      local path, site = modules[key], tunnel.sites[key]
      if not (path and type(path.register) == "function" and (type(path.IDS) == "table" or type(path.ids) == "table")) then
        fail(key .. " path package missing")
      end
      if not (site and site.tunnel == C.CONTRACT.tunnels[key]) then fail(key .. " tunnel ID mismatch") end
      local ids = C.pathIds(path)
      if ids.upper ~= C.CONTRACT.starts[key] then fail(key .. " start ID mismatch") end
      if ids.shrine ~= C.CONTRACT.ends[key] then fail(key .. " end ID mismatch") end
    end
    return true
  end

  local function replaceWarp(mapId, point, destination, destinationWarp, reason)
    local def = mod.content.maps:get(mapId)
    if not (def and type(def.warps) == "table") then fail(reason .. " map is unavailable") end
    local warps, found = {}, false
    for i, warp in ipairs(def.warps) do
      local copy = {}; for field, value in pairs(warp) do copy[field] = value end
      if copy.x == point.x and copy.y == point.y then
        copy.destMap, copy.destWarp, found = destination, destinationWarp, true
      end
      warps[i] = copy
    end
    if not found then warps[#warps + 1] = { x = point.x, y = point.y, destMap = destination, destWarp = destinationWarp } end
    mod.content.maps:patch(mapId, { warps = warps })
    local confirmed = mod.content.maps:get(mapId)
    for _, warp in ipairs((confirmed and confirmed.warps) or {}) do
      if warp.x == point.x and warp.y == point.y and warp.destMap == destination and warp.destWarp == destinationWarp then return true end
    end
    fail(reason .. " warp patch did not persist")
  end

  local function appendEndWarp(modules, key)
    local path = modules[key]
    local point = path and (path.END_WARP or C.END_WARPS[key])
    if not (point and point.x and point.y and mod.content.maps and mod.content.maps.patch and mod.content.maps.get) then
      fail(key .. " shrine end-room warp cannot be installed")
    end
    replaceWarp(C.pathIds(path).shrine, point, C.CONTRACT.shared, ({ RED = 1, BLUE = 2, GREEN = 3 })[key],
      key .. " shrine -> shared end room")
  end

  function C.validateWarps(modules)
    modules = modules or C.load()
    local room = mod.content.maps and mod.content.maps.get and mod.content.maps:get(C.CONTRACT.shared)
    if not (room and type(room.warps) == "table") then fail("shared end room map is unavailable for warp validation") end
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      local target = modules.shared.RETURN_POINTS and modules.shared.RETURN_POINTS[key] and modules.shared.RETURN_POINTS[key].map
      if not target then fail(key .. " shared end-room return point is missing") end
      if target ~= C.CONTRACT.ends[key] then fail(key .. " shared end-room return must target that path shrine") end
      local found = false
      for _, warp in ipairs(room.warps) do if warp.destMap == target then found = true end end
      if not found then fail(key .. " shared end-room return warp is missing") end
      appendEndWarp(modules, key)
      -- The old common-room exits are initial-path escapes, not this end room.
      -- Keep their source modules untouched, but patch their live map record
      -- to Package A's tunnel pads so the way out is always safe.
      local ids = C.pathIds(modules[key])
      local first = mod.content.maps:get(ids.upper)
      local old = first and first.warps and first.warps[1]
      if not old then fail(key .. " path start return warp is missing") end
      local returnSlot = modules.tunnel.sites[key]
        and modules.tunnel.sites[key].branch
        and modules.tunnel.sites[key].branch.returnSlot
      if not returnSlot then fail(key .. " shared-tunnel return slot is missing") end
      replaceWarp(ids.upper, old, C.CONTRACT.tunnels[key], returnSlot,
        key .. " start -> shared tunnel return")
    end
    return true
  end

  function C.register()
    if C.registered then return false, "already registered" end
    local modules = C.load()
    C.validate(modules) -- validate before any package can partially register
    for _, key in ipairs({ "tunnel", "shared", "hints", "RED", "BLUE", "GREEN" }) do
      local ok, why = modules[key].register()
      if ok == false and why ~= "already registered" then fail(key .. " registration failed: " .. tostring(why)) end
    end
    C.validateWarps(modules)
    C.registered = true
    return true
  end

  function C.install(game)
    local modules = C.load(); C.validate(modules)
    if opts.legacyDungeonAdapter and opts.legacyDungeonAdapter.install then
      opts.legacyDungeonAdapter.install(game)
    end
    for _, key in ipairs({ "tunnel", "shared", "hints", "RED", "BLUE", "GREEN" }) do
      if modules[key].install then modules[key].install(game) end
    end
    local function currentSeal(key)
      if opts.journey and type(opts.journey.currentHevoSeal)=="function" then
        return opts.journey.currentHevoSeal(game.save,key)
      end
      return false,nil
    end
    local function routeReady(key, path)
      if not (path and type(path.completionProgress) == "function") then
        return false, "progress"
      end
      local ok, report = pcall(path.completionProgress, game.save)
      if not ok or type(report) ~= "table" then return false, "progress" end
      local statues = tonumber(report.statues) or 0
      if key == "RED" then
        local b = type(report.boulders) == "table" and report.boulders or {}
        return statues >= 5 and b.A == true and b.B == true and b.C == true,
          "gate"
      elseif key == "BLUE" then
        local switches = type(report.switches) == "table"
          and report.switches or {}
        return statues >= 5 and report.finalStatue == true
          and switches.HALL == true and switches.ICE == true
          and switches.DEPTHS == true, "sight"
      elseif key == "GREEN" then
        return statues >= 5 and report.rootgate == true
          and report.canopy == true, "statues"
      end
      return false, "character"
    end
    local function completeHandoff(key, source)
      local path = modules[key]
      local pathReason
      local sealed, owner = currentSeal(key)
      sealed = sealed == true and owner == key
      if not sealed then
        local ready, why = routeReady(key, path)
        if not ready then return false, why end
        if key == "BLUE" and type(path.claimAll) == "function" then
          local _, why = path.claimAll(game)
          pathReason = why
        elseif type(path.complete) == "function" then
          local _, why = path.complete(game)
          pathReason = why
        end
        sealed, owner = currentSeal(key)
        sealed = sealed == true and owner == key
      end
      if not sealed then return false, pathReason or "seal" end
      local stoneStatus = "unavailable"
      if key == "BLUE" and type(path.claimSwampertite) == "function" then
        local ok, why = path.claimSwampertite(game)
        stoneStatus = ok and "granted" or tostring(why)
      elseif type(path.claimMega) == "function" then
        local ok, why = path.claimMega(game)
        stoneStatus = ok and "granted" or tostring(why)
      end
      local handoffOk, handoffResult = modules.shared.recordHandoff(game, key, {
        sourceMap = source,
        stone = ({ RED="BLAZIKENITE", BLUE="SWAMPERTITE",
          GREEN="SCEPTILITE" })[key],
        stoneStatus = stoneStatus,
      })
      -- Keep the current interaction result separate from the durable,
      -- monotonic receipt.  On a repeated touch the receipt correctly stays
      -- `granted`, while the claim controller truthfully returns `claimed`.
      -- End-seal text can therefore distinguish a new item from an already
      -- owned one without weakening the persisted hand-off.
      return handoffOk, handoffResult, stoneStatus
    end
    -- The visible character shrine seal is the primary completion boundary.
    -- Route callbacks receive only this bound seam: it reuses the exact same
    -- puzzle-gated finalize/secret/handoff transaction as warp and door
    -- recovery, and cannot select a different character or source map.
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      local character = key
      modules[character].finalizeEndSeal = function(requestGame)
        if requestGame ~= game then return false, "game" end
        return completeHandoff(character, C.CONTRACT.ends[character])
      end
    end
    -- Give the physical black-door interaction one bounded recovery attempt.
    -- This is deliberately the same exact-character, puzzle-gated transaction
    -- used by the warp hooks above; the shared room cannot mint a seal from a
    -- visual avatar, a landing coordinate or an old receipt.
    modules.shared.ensureOwnHandoff = function(requestGame, key)
      if requestGame ~= nil and requestGame ~= game then
        return false, "game"
      end
      key = type(key) == "string" and key:upper() or nil
      if not (key and C.CONTRACT.ends[key]) then
        return false, "character"
      end
      return completeHandoff(key, C.CONTRACT.ends[key])
    end
    -- The black door may explain an ordinary unfinished route, but it must
    -- not reach into any path's private save layout.  Each path exposes one
    -- read-only summary; this coordinator adds the shared Beyond-Kanto gate
    -- and binds the query to this exact game/character.
    modules.shared.completionProgress = function(requestGame, key)
      if requestGame ~= game then return nil, "game" end
      key = type(key) == "string" and key:upper() or nil
      local path = key and modules[key] or nil
      if not (path and C.CONTRACT.ends[key]
          and type(path.completionProgress) == "function") then
        return nil, key and "progress" or "character"
      end
      local ok, report = pcall(path.completionProgress, game.save)
      if not ok or type(report) ~= "table" then return nil, "progress" end
      local adapter = opts.legacyDungeonAdapter
      if not (adapter and type(adapter.beyondActive) == "function") then
        return nil, "adapter"
      end
      local beyondOk, beyond = pcall(adapter.beyondActive, game.save)
      if not beyondOk then return nil, "adapter" end
      report.character, report.beyond = key, beyond == true
      return report
    end
    -- After the player dismisses the complete report, return to the matching
    -- branch entry in the common fissure tunnel.  No progress is reset; the
    -- adjacent outside pad remains the player's explicit choice to leave.
    modules.shared.returnToTrialStart = function(requestGame, key, done)
      if requestGame ~= game then return false, "game" end
      key = type(key) == "string" and key:upper() or nil
      local site = key and modules.tunnel.sites[key] or nil
      local entry = site and site.branch and site.branch.entry or nil
      if not (site and site.tunnel == C.CONTRACT.tunnel and entry
          and entry.x and entry.y and entry.facing) then
        return false, key and "entry" or "character"
      end
      if not (mod.world and type(mod.world.warpTo) == "function") then
        return false, "warp"
      end
      local finished = false
      local function finishOnce()
        if finished then return end
        finished = true
        if done then done() end
      end
      local started, warpWhy = mod.world:warpTo(C.CONTRACT.tunnel,
        entry.x, entry.y, entry.facing, { onDone = finishOnce })
      if started ~= true then return false, warpWhy or "warp" end
      return true
    end
    if not C._handoffHook and mod.hooks and mod.hooks.wrap then
      local sharedSlots = { RED = 1, BLUE = 2, GREEN = 3 }
      C._handoffHook = mod.hooks:wrap("warp.destination",
        function(nextDestination, mapId, x, y, ctx)
          local destMap, destX, destY = nextDestination(mapId, x, y, ctx)
          if destMap ~= C.CONTRACT.shared then
            return destMap, destX, destY
          end
          local warp = ctx and ctx.warp
          local source = game and game.save and game.save.player
            and game.save.player.map
          local key
          for _, candidate in ipairs({ "RED", "BLUE", "GREEN" }) do
            if source == C.CONTRACT.ends[candidate]
                and warp and warp.destMap == C.CONTRACT.shared
                and warp.destWarp == sharedSlots[candidate] then
              key = candidate
              break
            end
          end
          if not key then return destMap, destX, destY end

          completeHandoff(key, source)
          return destMap, destX, destY
        end, 3000)
    end
    -- `player.warped` carries the source map explicitly and is therefore the
    -- authoritative receipt edge.  The destination hook above remains as a
    -- compatibility fast path, but must not be the only source: save.player
    -- is lifecycle-sensitive during a real warp and imported/adapter saves
    -- can update it earlier than the destination resolver expects.  Both
    -- paths are idempotent through shared.recordHandoff.
    if not C._handoffWarpedHook and mod.events and mod.events.on then
      local sharedSlots = { RED = 1, BLUE = 2, GREEN = 3 }
      C._handoffWarpedHook = true
      mod.events:on("player.warped", function(ev)
        if not (ev and ev.toMap == C.CONTRACT.shared) then return end
        local warp = ev.warp
        for _, candidate in ipairs({ "RED", "BLUE", "GREEN" }) do
          if ev.fromMap == C.CONTRACT.ends[candidate]
              and warp and warp.destMap == C.CONTRACT.shared
              and warp.destWarp == sharedSlots[candidate] then
            completeHandoff(candidate, ev.fromMap)
            return
          end
        end
      end, 3000)
    end
    -- One-time compatibility for an RC save already standing in the shared
    -- room: use the active character only to retry the same puzzle-gated
    -- completion, then immediately persist the normal receipt.  This cannot
    -- open an unfinished or foreign trial because each path's own complete
    -- function remains the authority.
    if not C._handoffMapHook and mod.events and mod.events.on then
      C._handoffMapHook = true
      mod.events:on("map.entered", function(ev)
        if not (ev and ev.mapId == C.CONTRACT.shared) then return end
        -- Old RC saves can already be standing on one of the three arrival
        -- pads before the durable receipt existed.  The landing cell is a
        -- stronger identity source than the currently selected presentation
        -- avatar, so recover it first and only then use the character API.
        local player = game and game.save and game.save.player or {}
        local x, y = tonumber(player.x), tonumber(player.y)
        local key = y == 21 and ({ [3] = "RED", [15] = "BLUE",
          [27] = "GREEN" })[x] or nil
        if not key then key = modules.shared.character(game) end
        if key and C.CONTRACT.ends[key] then
          local receipt = modules.shared.handoff and modules.shared.handoff()
          local status = receipt and tostring(receipt.stoneStatus or "")
          -- A pre-fix receipt may have persisted `character`/`unavailable`
          -- after the seal itself was already durable.  Retry that exact
          -- arrival so recordHandoff can monotonically upgrade it.  Only a
          -- successful same-character receipt is terminal and idempotent.
          if receipt and receipt.character == key
              and (status == "granted" or status == "claimed") then return end
          completeHandoff(key, C.CONTRACT.ends[key])
        end
      end, 3000)
    end
    return true
  end

  return C
end
