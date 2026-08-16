-- Native generic 1-4 follower chain for Red, Blue and Yellow.
--
-- Gen1Recomp's proven Yellow trail remains follower #1 and the sole owner of
-- Yellow story interaction. Additional followers are passable render-only
-- NPC-shaped entities. Each one consumes the bounded committed-cell trail of
-- its immediate predecessor; no follower independently chases the player.

return function(mod, opts)
  opts = opts or {}
  local selection = assert(opts.selection, "follower selection is required")
  local sprites = assert(opts.sprites, "follower sprite registry is required")
  local config = opts.config
  local i18n = opts.i18n
  local MAX_FOLLOWERS, MAX_TRAIL = 4, 64
  local N = {
    active = false, count = 1,
    runtime = setmetatable({}, { __mode = "k" }),
  }
  local STATE_KEY = "__kantoAscendantNativeSingleFollower"
  local INTERACT_STATE_KEY = "__kantoAscendantFollowerInteraction"
  local OPPOSITE = {
    up = "down", down = "up", left = "right", right = "left",
  }

  local function clampCount(value)
    return math.max(1, math.min(MAX_FOLLOWERS,
      math.floor(tonumber(value) or 1)))
  end

  local function externalFollower(game)
    for _, id in ipairs({ "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge" }) do
      local ok, handle = false, nil
      if mod and type(mod.find) == "function" then
        ok, handle = pcall(function() return mod.find(id) end)
      end
      local api = ok and type(handle) == "table" and handle.exports or nil
      if api ~= N and api ~= opts.yellowPartner
          and type(api) == "table" and type(api.activeMon) == "function" then
        return tostring(id)
      end
    end
    return nil
  end

  local function replaceUpvalue(fn, name, replacement)
    if type(fn) ~= "function" or not (debug and debug.getupvalue
        and debug.setupvalue) then return nil end
    local index = 1
    while true do
      local key, old = debug.getupvalue(fn, index)
      if not key then return nil end
      if key == name then
        debug.setupvalue(fn, index, replacement)
        return { fn = fn, index = index, old = old }
      end
      index = index + 1
    end
  end

  local function pushBounded(list, value)
    list[#list + 1] = value
    if #list > MAX_TRAIL then table.remove(list, 1) end
  end

  local function movementState(ow)
    local state = N.runtime[ow]
    if not state then
      local p = ow and ow.player or {}
      state = {
        lastX = p.targetX or p.cellX, lastY = p.targetY or p.cellY,
        history = {}, queue = {}, chainHistory = {}, extras = {}, queues = {},
        moveKeys = {}, chain = {}, hidden = false,
      }
      N.runtime[ow] = state
    end
    return state
  end

  local function reconcileInterruptedHide(ow)
    local state = ow and N.runtime[ow]
    if state and state.hidden and not ow.healAnim and not ow.pikaHop
        and not ow.pikachuBillsScene then
      state.hidden = false
    end
    return state
  end

  local function observePlayer(ow)
    if not (ow and ow.player) then return end
    local state = movementState(ow)
    local p = ow.player
    local x, y = p.targetX or p.cellX, p.targetY or p.cellY
    if x ~= state.lastX or y ~= state.lastY then
      pushBounded(state.queue, { x = state.lastX, y = state.lastY })
      pushBounded(state.history, {
        fromX = state.lastX, fromY = state.lastY,
        toX = x, toY = y, facing = p.facing,
      })
      state.lastX, state.lastY = x, y
    elseif state.lastFacing ~= p.facing then
      pushBounded(state.history, { x = x, y = y, facing = p.facing, turn = true })
    end
    state.lastFacing = p.facing
  end

  local function rows(game)
    if selection.activeMany then return selection.activeMany(game, N.count) end
    local mon, slot, source = selection.active(game)
    return mon and { { mon = mon, slot = slot, source = source } } or {}
  end

  local function contains(list, wanted)
    for _, value in ipairs(list or {}) do if value == wanted then return true end end
    return false
  end

  local function addEntity(ow, npc)
    if not contains(ow.entities, npc) then ow.entities[#ow.entities + 1] = npc end
  end

  local function removeEntity(ow, npc)
    for index, value in ipairs(ow and ow.entities or {}) do
      if value == npc then table.remove(ow.entities, index) return end
    end
  end

  local function cloneDefinition(def, path)
    local result = {}
    for key, value in pairs(def or {}) do result[key] = value end
    result.image = path
    return result
  end

  local function applyVisual(game, npc, row, chainIndex)
    local mon = row and row.mon
    local path = mon and sprites.resolve(game, mon)
    if not path then return false end
    local identity = selection.identity(mon)
    -- Metadata can survive a follower/map refresh while PikachuFollower has
    -- rebuilt its renderer from the vanilla placeholder definition.  Treat
    -- the renderer's own image path as authoritative too; otherwise the
    -- registry reports Gorochu while the screen still draws Pikachu.
    if npc.followerIdentity ~= identity or npc.followerSprite ~= path
        or not npc.sprite or not npc.sprite.def
        or npc.sprite.def.image ~= path then
      local def = select(1, sprites.configure(game, mon))
      if not def then return false end
      local Renderer = require("src.render.SpriteRenderer")
      npc.sprite = Renderer.new(cloneDefinition(def, path), npc.id)
    end
    npc._ascendantNativeFollower = true
    npc._ascendantChainIndex = chainIndex
    npc.followerIdentity = identity
    npc.followerSpecies = mon.species
    npc.followerSprite = path
    npc.followerPartySlot = row.slot
    npc.followerSelectionSource = row.source
    npc.followerMon = mon -- runtime-only; never serialized
    if npc._ascendantStableFacing == nil then
      npc._ascendantStableFacing = npc.facing or "down"
    end
    npc.followerFacing = npc.facing
    npc.followerAnimation = npc.moving and "walk" or "stand"
    npc.followerActive = true
    return true
  end

  -- PikachuFollower is the proven movement transport for follower #1, but
  -- its standing state also contains Yellow-only personality animations:
  -- random glances, bounce, shuffle and a clockwise spin.  Those poses look
  -- like rapid direction changes (the historical "breakdance" report) when
  -- the transported sprite is Raichu, Espeon, a Hoenn starter, etc.  Preserve
  -- them only for the actual Yellow Pikachu; every generic follower keeps the
  -- last direction of a committed step and an exact cell-aligned idle pose.
  local function usesClassicPikachuIdle(npc)
    return selection.edition() == "yellow"
      and npc and npc.followerSpecies == "PIKACHU"
  end

  local function stabilizeIdle(npc)
    if not npc or usesClassicPikachuIdle(npc) then return end
    if npc.moving then
      npc.idle = nil
      npc._ascendantStableFacing = npc.facing or npc._ascendantStableFacing or "down"
      return
    end
    npc.idle = nil
    npc.idleClock = 0
    npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
    npc.facing = npc._ascendantStableFacing or npc.facing or "down"
    npc.followerFacing = npc.facing
    npc.followerAnimation = "stand"
  end

  local function behindCell(ow, predecessor)
    local facing = predecessor.facing or "down"
    local dx = facing == "left" and 1 or facing == "right" and -1 or 0
    local dy = facing == "up" and 1 or facing == "down" and -1 or 0
    local x, y = predecessor.cellX + dx, predecessor.cellY + dy
    if ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y) then return x, y end
    return predecessor.cellX, predecessor.cellY
  end

  -- PikachuFollower's native warp spawn uses the cell directly behind the
  -- player and historically falls back to the player's own cell when that
  -- one tile is rock.  That is harmless to Gen-I player collision because
  -- the follower is passable, but it is not a valid world-occupancy state:
  -- visible Wilds must reserve around followers and therefore sees two
  -- blocking owners on one cell.  Keep the native preferred cell intact and
  -- repair only the overlap fallback, choosing a deterministic adjacent dry
  -- cell.  Connection crossings retain their existing keepPikachu/rebase
  -- path and never come through this repair.
  local SPAWN_OFFSETS = {
    up =    { { 0, 1 }, { -1, 0 }, { 1, 0 }, { 0, -1 } },
    down =  { { 0,-1 }, {  1, 0 }, {-1, 0 }, { 0,  1 } },
    left =  { { 1, 0 }, {  0, 1 }, { 0,-1 }, {-1,  0 } },
    right = { {-1, 0 }, {  0,-1 }, { 0, 1 }, { 1,  0 } },
  }

  local function freeFollowerSpawnCell(ow, follower, x, y)
    local map = ow and ow.map
    if not (map and map:inBounds(x, y) and map:isWalkableCell(x, y)) then
      return false
    end
    if map.warpAtCell and map:warpAtCell(x, y) then return false end
    for _, entity in ipairs(ow.entities or {}) do
      if entity ~= follower and entity ~= ow.player
          and ((entity.cellX == x and entity.cellY == y)
            or (entity.targetX == x and entity.targetY == y)) then
        return false
      end
    end
    return true
  end

  local function repairFirstFollowerSpawn(ow, follower)
    local player = ow and ow.player
    if not (player and follower
        and follower.cellX == player.cellX and follower.cellY == player.cellY) then
      return false
    end
    local offsets = SPAWN_OFFSETS[player.facing or follower.facing or "down"]
      or SPAWN_OFFSETS.down
    for _, offset in ipairs(offsets) do
      local x, y = player.cellX + offset[1], player.cellY + offset[2]
      if freeFollowerSpawnCell(ow, follower, x, y) then
        follower.cellX, follower.cellY = x, y
        follower.px, follower.py = x * 16, y * 16
        follower.targetX, follower.targetY = nil, nil
        follower.goalX, follower.goalY = nil, nil
        follower.moving, follower.marching, follower.hopStep = false, nil, nil
        follower.progress = 0
        if ow.pikachuTrail then
          ow.pikachuTrail.x, ow.pikachuTrail.y = player.cellX, player.cellY
        end
        return true
      end
    end
    return false
  end

  local function makeExtra(game, ow, chainIndex, predecessor)
    local NPC = require("src.world.NPC")
    local x, y = behindCell(ow, predecessor)
    local npc = NPC.new(game.data, ow.map.id, {
      index = 0x7000 + chainIndex,
      name = "ASCENDANT_FOLLOWER_" .. chainIndex,
      sprite = sprites.spriteId, movement = "STAY", range = "NONE", x = x, y = y,
    })
    npc.passable = true
    npc.facing = predecessor.facing or "down"
    npc._ascendantNativeFollower = true
    npc._ascendantChainIndex = chainIndex
    return npc
  end

  local function removeExtras(ow, state, first)
    for index = #state.extras, 1, -1 do
      local npc = state.extras[index]
      removeEntity(ow, npc)
      state.extras[index] = nil
    end
    state.extras, state.queues, state.moveKeys = {}, {}, {}
    state.chain = first and { first } or {}
  end

  local function visibleRows(game)
    local visible = {}
    for _, row in ipairs(rows(game)) do
      if sprites.resolve(game, row.mon) then visible[#visible + 1] = row end
    end
    return visible
  end

  local function syncChain(game, ow, follower)
    if not ow then return {} end
    local state = movementState(ow)
    local selected = visibleRows(game)
    local first = follower.current(ow)
    if not (selected[1] and first and applyVisual(game, first, selected[1], 1)) then
      removeExtras(ow, state)
      return {}
    end

    -- A scripted hide (notably the Pokecenter machine) removes follower #1
    -- from the draw list but keeps its NPC object alive. If the scene is
    -- interrupted by a reload/map handoff before its matching show callback,
    -- the engine finds the old object and never inserts it again. Reconcile
    -- draw membership from the current scene state on every chain refresh;
    -- addEntity is idempotent, so this cannot duplicate the follower.
    if not state.hidden and not ow.pikachuBillsScene then
      addEntity(ow, first)
    else
      removeEntity(ow, first)
    end

    local chain = { first }
    local wantedExtras = #selected - 1
    for extraIndex = 1, wantedExtras do
      local chainIndex = extraIndex + 1
      local row = selected[chainIndex]
      local identity = selection.identity(row.mon)
      local npc = state.extras[extraIndex]
      if npc and npc.followerIdentity ~= identity then
        removeEntity(ow, npc)
        npc = nil
        state.queues[chainIndex], state.moveKeys[chainIndex] = nil, nil
      end
      if not npc then
        npc = makeExtra(game, ow, chainIndex, chain[#chain])
        state.extras[extraIndex] = npc
        state.queues[chainIndex] = {}
      end
      if not applyVisual(game, npc, row, chainIndex) then
        removeEntity(ow, npc)
        state.extras[extraIndex] = nil
      else
        if not state.hidden and not ow.pikachuBillsScene then addEntity(ow, npc) end
        chain[#chain + 1] = npc
      end
    end
    for extraIndex = #state.extras, wantedExtras + 1, -1 do
      removeEntity(ow, state.extras[extraIndex])
      state.extras[extraIndex] = nil
      state.queues[extraIndex + 1], state.moveKeys[extraIndex + 1] = nil, nil
    end
    state.chain = chain
    return chain
  end

  local function moveKey(npc)
    if not (npc and npc.moving and npc.targetX and npc.targetY) then return nil end
    return table.concat({ npc.cellX, npc.cellY, npc.targetX, npc.targetY }, ":")
  end

  local function advanceExtras(ow, state)
    if state.hidden or ow.pikachuBillsScene then return end
    for _, npc in ipairs(state.extras) do
      if contains(ow.entities, npc) then npc:update(ow.map, ow.entities) end
    end
  end

  local function beginQueuedStep(ow, state, chainIndex, npc, predecessor)
    if npc.moving then return end
    local queue = state.queues[chainIndex] or {}
    state.queues[chainIndex] = queue
    while queue[1] and npc.cellX == queue[1].x and npc.cellY == queue[1].y do
      table.remove(queue, 1)
    end
    local goal = table.remove(queue, 1)
    if not goal then return end
    local dx, dy = goal.x - npc.cellX, goal.y - npc.cellY
    local distance = math.abs(dx) + math.abs(dy)
    if distance > 6 or not ow.map:inBounds(goal.x, goal.y) then
      npc.cellX, npc.cellY = goal.x, goal.y
      npc.px, npc.py = goal.x * 16, goal.y * 16
      npc.targetX, npc.targetY, npc.goalX, npc.goalY = nil, nil, nil, nil
      npc.moving, npc.hopStep = false, nil
      return
    end
    local dir
    if dx > 0 then dir = "right"
    elseif dx < 0 then dir = "left"
    elseif dy > 0 then dir = "down"
    elseif dy < 0 then dir = "up"
    else return end
    npc.facing = dir
    npc._ascendantStableFacing = dir
    local span = distance == 2 and (dx == 0 or dy == 0) and 2 or 1
    npc.targetX = npc.cellX + (dir == "right" and span or dir == "left" and -span or 0)
    npc.targetY = npc.cellY + (dir == "down" and span or dir == "up" and -span or 0)
    npc.hopStep = span == 2 or nil
    -- A missed frame around a corner can make the next predecessor cell
    -- diagonal or several cells away. Never discard the unconsumed part of
    -- that direct trail: finish one axis/step, then resume the same goal
    -- before accepting newer predecessor commands.
    if npc.targetX ~= goal.x or npc.targetY ~= goal.y then
      table.insert(queue, 1, goal)
    end
    local stepFrames = predecessor.stepFrames or 16
    if #queue > 1 and not npc.hopStep then
      stepFrames = math.max(1, math.floor(stepFrames / 2))
    end
    npc.stepFrames = stepFrames
    npc.moving, npc.progress = true, 0
    npc:update(ow.map, ow.entities) -- burn the first frame this update
    pushBounded(state.chainHistory, {
      index = chainIndex, fromX = npc.cellX, fromY = npc.cellY,
      toX = npc.targetX, toY = npc.targetY,
    })
  end

  local function updateChainMovement(ow, state, chain)
    if state.hidden or ow.pikachuBillsScene then
      for _, npc in ipairs(state.extras) do removeEntity(ow, npc) end
      return
    end
    for chainIndex = 2, #chain do
      local predecessor, npc = chain[chainIndex - 1], chain[chainIndex]
      local key = moveKey(predecessor)
      if key and state.moveKeys[chainIndex] ~= key then
        state.moveKeys[chainIndex] = key
        local queue = state.queues[chainIndex] or {}
        state.queues[chainIndex] = queue
        local goalX, goalY = predecessor.cellX, predecessor.cellY
        local dx = (predecessor.targetX or goalX) - goalX
        local dy = (predecessor.targetY or goalY) - goalY
        -- A native catch-up/ledge command can cover two cells in one
        -- animation. Following only its original cell would leave the next
        -- link two cells away after the hop. Consume the intermediate cell
        -- on that same predecessor path instead, then let every later link
        -- propagate the identical two-cell catch-up progressively.
        if math.abs(dx) + math.abs(dy) == 2 and (dx == 0 or dy == 0) then
          goalX = goalX + (dx == 0 and 0 or dx > 0 and 1 or -1)
          goalY = goalY + (dy == 0 and 0 or dy > 0 and 1 or -1)
        end
        pushBounded(queue, {
          x = goalX, y = goalY,
          facing = predecessor.facing,
        })
      elseif not key then
        state.moveKeys[chainIndex] = nil
      end
      beginQueuedStep(ow, state, chainIndex, npc, predecessor)
      stabilizeIdle(npc)
      npc.followerFacing = npc.facing
      npc.followerAnimation = npc.moving and "walk" or "stand"
      npc.followerMovement = {
        history = state.chainHistory,
        queue = state.queues[chainIndex],
      }
    end
  end

  local function rebaseExtra(npc, dx, dy)
    npc.cellX, npc.cellY = npc.cellX + dx, npc.cellY + dy
    npc.px, npc.py = npc.px + dx * 16, npc.py + dy * 16
    if npc.targetX then npc.targetX = npc.targetX + dx end
    if npc.targetY then npc.targetY = npc.targetY + dy end
    if npc.goalX then npc.goalX = npc.goalX + dx end
    if npc.goalY then npc.goalY = npc.goalY + dy end
  end

  local function compactStretchedLinks(ow, state, chain, stableOnly)
    for index = 2, #(chain or {}) do
      local predecessor, npc = chain[index - 1], chain[index]
      local gap = math.abs(npc.cellX - predecessor.cellX)
        + math.abs(npc.cellY - predecessor.cellY)
      local queue = state.queues[index] or {}
      local stable = not predecessor.moving and not npc.moving and #queue == 0
      if gap > 1 and (not stableOnly or stable) then
        local x, y = behindCell(ow, predecessor)
        npc.cellX, npc.cellY, npc.px, npc.py = x, y, x * 16, y * 16
        npc.targetX, npc.targetY, npc.goalX, npc.goalY = nil, nil, nil, nil
        npc.moving, npc.hopStep, npc.progress = false, nil, 0
        state.queues[index] = {}
        state.moveKeys[index] = moveKey(predecessor)
      end
    end
  end

  local FRIENDSHIP_METHODS = {
    FRIENDSHIP = true,
    FRIENDSHIP_DAY = true,
    FRIENDSHIP_NIGHT = true,
  }

  local function tr(english, german)
    return i18n and i18n.text and i18n.text(english, german) or english
  end

  -- Read the live, already-composed species registry. This deliberately does
  -- not maintain a Golbat/Eevee/etc. allow-list: any present or future
  -- species whose current definition has a valid friendship branch receives
  -- the same feedback. Unknown registry shapes fail closed to ordinary talk.
  local function friendshipProfile(game, mon)
    if type(mon) ~= "table" or type(mon.species) ~= "string"
        or mon.species == "" then return nil end
    local pokemon = game and game.data and game.data.pokemon
    local def = type(pokemon) == "table" and pokemon[mon.species] or nil
    if type(def) ~= "table" or type(def.evolutions) ~= "table" then return nil end
    local methods = {}
    for _, evolution in ipairs(def.evolutions) do
      if type(evolution) == "table" then
        local method = evolution.method or evolution[1]
        local target = evolution.species or evolution[2]
        if FRIENDSHIP_METHODS[method]
            and type(target) == "string" and target ~= "" then
          methods[method] = true
        end
      end
    end
    if not next(methods) then return nil end

    -- Nil is the legitimate pre-first-step value and means zero friendship.
    -- Other non-numeric/future shapes are not guessed at and retain the
    -- ordinary follower line. Merely inspecting never writes back to the mon.
    local bond = mon.johtoBond
    if bond == nil then
      bond = 0
    elseif type(bond) ~= "number" or bond ~= bond
        or bond < 0 or bond > 255 or bond % 1 ~= 0 then
      return nil
    end
    return { bond = bond, methods = methods }
  end

  local function readySuffix(methods)
    if methods.FRIENDSHIP then
      return tr(
        "At its next level,\nit can evolve.",
        "Beim n\195\164chsten\nLevel kann es sich\nentwickeln.")
    end
    if methods.FRIENDSHIP_DAY and methods.FRIENDSHIP_NIGHT then
      return tr(
        "At its next level,\ntime decides its\npath.",
        "Beim n\195\164chsten\nLevel entscheidet\ndie Tageszeit.")
    end
    if methods.FRIENDSHIP_DAY then
      return tr(
        "At its next level,\nit can evolve\nby day.",
        "Beim n\195\164chsten\nLevel entwickelt es\nsich am Tag.")
    end
    return tr(
      "At its next level,\nit can evolve\nby night.",
      "Beim n\195\164chsten\nLevel entwickelt es\nsich nachts.")
  end

  local function friendshipText(game, mon, name, Strings)
    local profile = friendshipProfile(game, mon)
    if not profile then return nil end
    local format
    if profile.bond < 50 then
      format = tr(
        "%s seems wary.\fIt still needs time\nto trust you.",
        "%s wirkt noch\nskeptisch.\fEs braucht Zeit, um\ndir zu vertrauen.")
    elseif profile.bond < 100 then
      format = tr(
        "%s is starting\nto trust you.\fYour bond is\ngrowing.",
        "%s fasst langsam\nVertrauen.\fEure Bindung wird\nst\195\164rker.")
    elseif profile.bond < 200 then
      format = tr(
        "%s looks very\nhappy!\f%s",
        "%s sieht sehr\ngl\195\188cklich aus!\f%s")
      return Strings(format, name, readySuffix(profile.methods))
    else
      format = tr(
        "%s trusts you\ncompletely!\f%s",
        "%s vertraut dir\nvollkommen!\f%s")
      return Strings(format, name, readySuffix(profile.methods))
    end
    return Strings(format, name)
  end

  local function genericTalk(game, ow, npc, done)
    local mon = npc and npc.followerMon
    -- The engine's native first-follower call can arrive before Ascendant's
    -- runtime metadata is attached. Preserve that historical fallback only
    -- for entity #1/no entity; an incomplete extra must never impersonate #1.
    if not mon and (not npc or not npc._ascendantChainIndex
        or npc._ascendantChainIndex == 1) then
      mon = selection.active(game)
    end
    if not mon then if done then done() end return end
    if npc and npc.moving then
      npc.cellX, npc.cellY = npc.targetX or npc.cellX, npc.targetY or npc.cellY
      npc.targetX, npc.targetY = nil, nil
      npc.moving, npc.marching, npc.hopStep = false, false, nil
      npc.progress = 0
      npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
    end
    if npc and npc.facePlayer and ow and ow.player then npc:facePlayer(ow.player) end
    if npc then
      npc._ascendantStableFacing = npc.facing or npc._ascendantStableFacing
    end
    if npc and ow and ow.player then
      ow.player.facing = OPPOSITE[npc.facing] or ow.player.facing
    end
    pcall(function() require("src.core.Sound").playCry(game.data, mon.species) end)
    local pokemon = game.data.pokemon and game.data.pokemon[mon.species]
    local name = mon.nickname or (pokemon and pokemon.name) or mon.species
    local Strings = require("src.core.Strings")
    local TextBox = require("src.render.TextBox")
    local text = friendshipText(game, mon, name, Strings)
      or Strings("%s is following\nyou!", name)
    game.stack:push(TextBox.new(game, text, done))
  end

  function N.install(game)
    local version = selection.edition()
    if version ~= "red" and version ~= "blue" and version ~= "yellow" then
      return false
    end
    local external = externalFollower(game)
    if external then
      if mod.log and mod.log.info then
        mod.log:info("native follower yields to external follower mod %s", external)
      end
      N.external = external
      return false
    end

    if config and config.count then N.count = clampCount(config.count()) end
    local Follower = require("src.world.PikachuFollower")
    local Overworld = require("src.world.OverworldController")
    local previous = rawget(Follower, STATE_KEY)
    if previous and previous.restore then previous.restore() end
    local previousInteraction = rawget(Overworld, INTERACT_STATE_KEY)
    if previousInteraction and previousInteraction ~= previous
        and previousInteraction.restore then
      previousInteraction.restore()
    end

    local yellowBridge = rawget(Follower, "__ascendantYellowPartnerFollower")
    local spawnOwner = yellowBridge and yellowBridge.update or Follower.update
    local originalUpdate = Follower.update
    local originalOnMapEntered = Follower.onMapEntered
    local originalTalk = Follower.talk
    local originalRebase = Follower.rebase
    local originalSetVisible = Follower.setVisible
    local originalInteract = Overworld.interact
    local oldShouldSpawn
    local patch
    local sandboxTransport

    local function shouldSpawn(activeGame, ow)
      local save = activeGame and activeGame.save
      if not (save and ow and ow.player) then return false end
      if save.onBike or ow.player.surfing then return false end
      local mon = selection.active(activeGame)
      return mon ~= nil and sprites.resolve(activeGame, mon) ~= nil
    end

    patch = replaceUpvalue(spawnOwner, "shouldSpawn", shouldSpawn)
    if not patch then
      -- Engine 0.1.86 deliberately removes Lua's debug library from the mod
      -- sandbox, so the historical upvalue seam above is unavailable there.
      -- Keep using the engine's complete, battle-tested transport instead of
      -- reimplementing its ledges, map connections, Bill scene and Pokecenter
      -- choreography.  The Yellow controller retains the raw engine callbacks
      -- it wrapped; bypassing its spawn-alias wrapper is important here because
      -- that older bridge temporarily changes real party species.
      local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
      local nativeOnMapEntered = yellowBridge and yellowBridge.onMapEntered
        or originalOnMapEntered
      local nativeUpdate = yellowBridge and yellowBridge.update or originalUpdate
      if not (okVersion and type(GameVersion) == "table"
          and type(GameVersion.isYellow) == "function"
          and type(nativeOnMapEntered) == "function"
          and type(nativeUpdate) == "function") then
        if mod.log and mod.log.error then
          mod.log:error("native follower compatibility transport unavailable")
        end
        return false
      end

      local function proxyFor(activeGame, ow)
        local realSave = activeGame and activeGame.save or {}
        local realFlags = realSave.flags or {}
        local eligible = shouldSpawn(activeGame, ow)
        local flags = setmetatable({
          EVENT_GOT_STARTER = true,
          EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true,
        }, { __index = realFlags })
        local party = eligible and { { species = "PIKACHU", hp = 1 } } or {}
        local save = setmetatable({
          flags = flags,
          party = party,
          -- A false value skips the engine's legacy rival-flag fallback.
          -- When hidden, true makes the native predicate remove the entity.
          pikachuInBall = not eligible,
        }, { __index = realSave })
        return setmetatable({ save = save }, {
          -- Copy-on-write is intentional: future engine transport versions
          -- may cache scene state on game/save.  Eligibility coercion must
          -- never leak a write into the actual playthrough.
          __index = activeGame,
        })
      end

      local function pack(...)
        return { n = select("#", ...), ... }
      end

      local function invoke(callback, activeGame, ow, args, isolateEntry)
        local gameProxy = proxyFor(activeGame, ow)
        local previousYellow = GameVersion.isYellow
        local previousEntry = Follower.onMapEntered
        local result
        GameVersion.isYellow = function() return true end
        -- PikachuFollower.update may request a mid-map spawn.  Point that
        -- internal public-table dispatch at the raw callback for the duration
        -- so it cannot re-enter Ascendant's wrapper with the eligibility
        -- proxy.  Everything is restored synchronously, including errors.
        if isolateEntry then Follower.onMapEntered = nativeOnMapEntered end
        local ok, err = xpcall(function()
          result = pack(callback(gameProxy, ow, unpack(args or {})))
        end, function(value) return value end)
        if isolateEntry then Follower.onMapEntered = previousEntry end
        GameVersion.isYellow = previousYellow
        if not ok then error(err, 0) end
        return unpack(result, 1, result.n)
      end

      sandboxTransport = {
        onMapEntered = function(activeGame, ow, args)
          return invoke(nativeOnMapEntered, activeGame, ow, args, false)
        end,
        update = function(activeGame, ow, args)
          return invoke(nativeUpdate, activeGame, ow, args, true)
        end,
      }
    else
      oldShouldSpawn = patch.old
    end

    local wrappedOnMapEntered = function(activeGame, ow, ...)
      local args = { ... }
      local transition = args[1]
      reconcileInterruptedHide(ow)
      if not (transition and transition.keepPikachu) and N.runtime[ow] then
        removeExtras(ow, N.runtime[ow])
      end
      local selected = rows(activeGame)
      sprites.configure(activeGame, selected[1] and selected[1].mon)
      local result
      if sandboxTransport then
        result = sandboxTransport.onMapEntered(activeGame, ow, args)
      else
        result = originalOnMapEntered(activeGame, ow, unpack(args))
      end
      if not (transition and transition.keepPikachu) then
        repairFirstFollowerSpawn(ow, Follower.current(ow))
      end
      if not (transition and transition.keepPikachu) then N.runtime[ow] = nil end
      syncChain(activeGame, ow, Follower)
      return result
    end

    local wrappedUpdate = function(activeGame, ow, ...)
      observePlayer(ow)
      local state = movementState(ow)
      advanceExtras(ow, state)
      local selected = rows(activeGame)
      sprites.configure(activeGame, selected[1] and selected[1].mon)
      local updateArgs = { ... }
      local result
      if sandboxTransport then
        result = sandboxTransport.update(activeGame, ow, updateArgs)
        -- Mid-map native respawns use the player's own cell when every
        -- behind tile is blocked.  Keep the existing deterministic occupancy
        -- repair in the no-debug transport path as well as map entry.
        repairFirstFollowerSpawn(ow, Follower.current(ow))
      else
        result = originalUpdate(activeGame, ow, unpack(updateArgs))
      end
      local chain = syncChain(activeGame, ow, Follower)
      state = movementState(ow)
      stabilizeIdle(chain[1])
      updateChainMovement(ow, state, chain)
      -- A map swap can cancel the last pixel/landing frame of one extra.
      -- Once both links are idle and no queued command can close the hole,
      -- repair it along the predecessor's own facing instead of leaving a
      -- permanent two-cell gap.
      compactStretchedLinks(ow, state, chain, true)
      return result
    end

    local wrappedTalk = function(activeGame, ow, npc, done)
      if npc and npc._ascendantChainIndex and npc._ascendantChainIndex > 1 then
        return genericTalk(activeGame, ow, npc, done)
      end
      -- The first transport entity is historically named PikachuFollower,
      -- but in Ascendant it may carry any selected party species.  Yellow's
      -- mood/portrait conversation belongs only to an actual Pikachu; after
      -- an evolution (Raichu/Gorochu) or a non-Pikachu Legacy choice the
      -- follower must use the ordinary species-aware interaction instead.
      if selection.edition() == "yellow"
          and npc and npc.followerSpecies == "PIKACHU" then
        return originalTalk(activeGame, ow, npc, done)
      end
      return genericTalk(activeGame, ow, npc, done)
    end

    local wrappedRebase = function(ow, dx, dy)
      local result = originalRebase(ow, dx, dy)
      local state = N.runtime[ow]
      if state then
        for _, npc in ipairs(state.extras) do rebaseExtra(npc, dx, dy) end
        for _, queue in pairs(state.queues) do
          for _, goal in ipairs(queue) do goal.x, goal.y = goal.x + dx, goal.y + dy end
        end
        -- A connection can swap maps between two links' landing frames. The
        -- engine preserves follower #1, but an extra that was one frame from
        -- finishing then has no old-map update left to commit its target.
        -- Reconstruct only stretched links on the new map, in predecessor
        -- order, so a seam cannot leave a permanent two-cell hole.
        compactStretchedLinks(ow, state, state.chain, false)
        for index = 2, #(state.chain or {}) do
          state.moveKeys[index] = moveKey(state.chain[index - 1])
        end
      end
      return result
    end

    local wrappedSetVisible = function(ow, visible)
      local result = originalSetVisible(ow, visible)
      local state = N.runtime[ow]
      if state then
        state.hidden = not visible
        for _, npc in ipairs(state.extras) do
          if visible and not ow.pikachuBillsScene then addEntity(ow, npc)
          else removeEntity(ow, npc) end
        end
      end
      return result
    end

    local function listedNpcAt(ow, x, y)
      if ow.npcAtCell then return ow:npcAtCell(x, y) end
      for _, npc in ipairs(ow.npcs or {}) do
        if (npc.cellX == x and npc.cellY == y)
            or (npc.targetX == x and npc.targetY == y) then
          return npc
        end
      end
      return nil
    end

    local function facingExtra(ow)
      local player = ow and ow.player
      local state = ow and N.runtime[ow]
      if not (player and player.facingCell and state and not state.hidden
          and not ow.pikachuBillsScene) then return nil end
      local x, y = player:facingCell()
      -- Never steal A from a native/map NPC (including Yellow Pikachu #1).
      -- Extras remain absent from ow.npcs and therefore keep their passable,
      -- render-only movement semantics.
      if listedNpcAt(ow, x, y) then return nil end
      for _, npc in ipairs(state.extras or {}) do
        if npc and npc._ascendantNativeFollower
            and (npc._ascendantChainIndex or 0) > 1
            and contains(ow.entities, npc)
            and ((npc.cellX == x and npc.cellY == y)
              or (npc.targetX == x and npc.targetY == y)) then
          return npc, x, y
        end
      end
      return nil
    end

    -- OverworldController's native A path only searches ow.npcs. Keep the
    -- extra followers out of that list (no collision/update/map-script side
    -- effects), and add one exact facing-cell seam before vanilla interact.
    -- The standard path remains byte-for-byte authoritative when no extra is
    -- addressed, especially for Yellow's native Pikachu mood conversation.
    local wrappedInteract = function(ow, ...)
      local npc, x, y = facingExtra(ow)
      local activeGame = N.game or game
      if not (npc and activeGame) then return originalInteract(ow, ...) end
      genericTalk(activeGame, ow, npc)
      local ok, Runtime = pcall(require, "src.mods.Runtime")
      if ok and Runtime and Runtime.emit then
        Runtime.emit("world.interacted", {
          mapId = ow.map and ow.map.id, x = x, y = y,
          kind = "npc", target = npc,
        })
      end
      return nil
    end

    Follower.onMapEntered = wrappedOnMapEntered
    Follower.update = wrappedUpdate
    Follower.talk = wrappedTalk
    Follower.rebase = wrappedRebase
    Follower.setVisible = wrappedSetVisible
    Overworld.interact = wrappedInteract

    local state = {}
    state.restore = function()
      local activeState = N.game and N.game.overworld and N.runtime[N.game.overworld]
      if activeState then removeExtras(N.game.overworld, activeState) end
      if patch and patch.fn and debug and debug.getupvalue
          and debug.setupvalue then
        local key, current = debug.getupvalue(patch.fn, patch.index)
        if key == "shouldSpawn" and current == shouldSpawn then
          debug.setupvalue(patch.fn, patch.index, oldShouldSpawn)
        end
      end
      if Follower.update == wrappedUpdate then Follower.update = originalUpdate end
      if Follower.onMapEntered == wrappedOnMapEntered then
        Follower.onMapEntered = originalOnMapEntered
      end
      if Follower.talk == wrappedTalk then Follower.talk = originalTalk end
      if Follower.rebase == wrappedRebase then Follower.rebase = originalRebase end
      if Follower.setVisible == wrappedSetVisible then
        Follower.setVisible = originalSetVisible
      end
      if Overworld.interact == wrappedInteract then
        Overworld.interact = originalInteract
      end
      if rawget(Follower, STATE_KEY) == state then rawset(Follower, STATE_KEY, nil) end
      if rawget(Overworld, INTERACT_STATE_KEY) == state then
        rawset(Overworld, INTERACT_STATE_KEY, nil)
      end
      N.active = false
    end
    rawset(Follower, STATE_KEY, state)
    rawset(Overworld, INTERACT_STATE_KEY, state)
    N.restore = state.restore
    N.active, N.game = true, game
    N.refresh(game)
    return true
  end

  function N.refresh(game)
    game = game or N.game
    if not (N.active and game and game.overworld) then return false end
    local Follower = require("src.world.PikachuFollower")
    reconcileInterruptedHide(game.overworld)
    local selected = rows(game)
    sprites.configure(game, selected[1] and selected[1].mon)
    if not Follower.current(game.overworld) then
      Follower.onMapEntered(game, game.overworld)
    end
    local chain = syncChain(game, game.overworld, Follower)
    return #chain > 0
  end

  function N.setCount(value, game, fromConfig)
    local nextCount = clampCount(value)
    if config and config.setCount and not fromConfig then
      return config.setCount(nextCount)
    end
    N.count = nextCount
    if N.active then N.refresh(game or N.game) end
    return N.count
  end

  function N.applyConfig(game)
    if config and config.count then N.count = clampCount(config.count()) end
    if N.active then N.refresh(game or N.game) end
    return N.count
  end

  function N.getCount() return N.count end
  function N.activeMon(game) return selection.active(game or N.game) end
  function N.activeMons(game) return rows(game or N.game) end
  function N.entity(game)
    game = game or N.game
    if not (game and game.overworld) then return nil end
    return require("src.world.PikachuFollower").current(game.overworld)
  end
  function N.entities(game)
    game = game or N.game
    if not (game and game.overworld) then return {} end
    local state = N.runtime[game.overworld]
    if state and state.chain then return state.chain end
    local first = N.entity(game)
    return first and { first } or {}
  end
  function N.movement(game)
    game = game or N.game
    return game and game.overworld and N.runtime[game.overworld] or nil
  end

  -- Narrow inspection seams for the ROM-free contract suite. They are pure:
  -- neither function mutates a Pokemon or a save.
  N.friendshipProfile = friendshipProfile
  N.friendshipText = function(game, mon, name)
    local Strings = require("src.core.Strings")
    return friendshipText(game, mon, name or mon and mon.nickname
      or mon and mon.species or "POKEMON", Strings)
  end
  N._genericTalk = genericTalk

  if mod.events and mod.events.on then
    mod.events:on("pokemon.evolved", function() N.refresh() end, -20)
    mod.events:on("pokemon.caught", function() N.refresh() end, -20)
    mod.events:on("save.loaded", function()
      sprites.invalidate()
      N.refresh()
    end, -20)
    mod.events:on("game.ready", function() N.refresh() end, -20)
  end
  return N
end
