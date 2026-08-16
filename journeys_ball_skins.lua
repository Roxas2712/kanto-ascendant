-- Pokemon Journeys / Essentials Ball art bridge.
--
-- `modern_ball_skins.lua` owns the existing, mechanics-neutral OAM bridge.
-- This module replaces only that bridge's raster draw function after the
-- regular bridge is installed.  It never changes catch math, queue timing,
-- rolls, shakes, sounds, or BattleState's caught/no-catch branches.

return function(mod)
  local J = {
    SCALE = 4 / 7, -- Journeys' 28px opaque ball -> the engine's 16px OAM ball
    FRAMES_PER_SHEET = 8,
    FRAME_TICKS = {
      TOSS_ANIM = 2, GREATTOSS_ANIM = 2, ULTRATOSS_ANIM = 2,
      SHAKE_ANIM = 3, BLOCKBALL_ANIM = 2,
    },
    BALLS = {
      POKE_BALL = "poke_ball", GREAT_BALL = "great_ball",
      ULTRA_BALL = "ultra_ball", MASTER_BALL = "master_ball",
      SAFARI_BALL = "safari_ball", FAST_BALL = "fast_ball",
      LEVEL_BALL = "level_ball", LURE_BALL = "lure_ball",
      HEAVY_BALL = "heavy_ball", LOVE_BALL = "love_ball",
      FRIEND_BALL = "friend_ball", MOON_BALL = "moon_ball",
    },
    -- The supplied 256x64 masters contain eight authored 32x64 phases.  The
    -- Gen-I OAM path still owns trajectory/rotation; this bridge advances the
    -- Journeys phase deterministically from the real AnimPlayer clock.
    STATES = {
      toss = "closed_sheet_8_frame", roll = "closed_sheet_8_frame",
      shake = "closed_sheet_8_frame", block = "closed_sheet_8_frame",
      no_catch = "closed_sheet_8_frame",
      breakout = "engine_showpic_after_ball_open",
      success = "closed_sheet_final_pose", full_box = "closed_sheet_final_pose",
    },
    UNWIRED_MASTERS = {
      open_master = "The Gen-I animation chain has no open-ball draw state; "
        .. "the delivered Journeys *_open masters are retained for a future "
        .. "engine animation API rather than being displayed in an incorrect state.",
    },
  }

  local images, quads = {}, {}

  local function pathFor(id)
    local stem = J.BALLS[id] or J.BALLS.POKE_BALL
    return mod.path .. "/assets/journeys_balls/" .. stem .. ".png"
  end

  local function imageFor(id)
    local cached = images[id]
    if cached ~= nil then return cached or nil end
    if not (love and love.graphics and love.graphics.newImage) then
      images[id] = false
      return nil
    end
    local ok, image = pcall(love.graphics.newImage, pathFor(id))
    images[id] = ok and image or false
    return images[id] or nil
  end

  local function frameFor(move, elapsed)
    local ticks = J.FRAME_TICKS[move] or 3
    local frame = math.floor(math.max(0, elapsed or 0) / ticks)
      % J.FRAMES_PER_SHEET
    return frame
  end

  local function quadFor(id, image, frame)
    local key = id .. ":" .. tostring(frame)
    local quad = quads[key]
    if quad then return quad end
    quad = love.graphics.newQuad(frame * 32, 0, 32, 64,
      image:getDimensions())
    quads[key] = quad
    return quad
  end

  local function markTrueColor(x, y)
    local PaletteFX = require("src.render.PaletteFX")
    -- The source opaque area is a 28px circle and lands on 16px after scale.
    -- Mark only its scanline spans, preserving the R/B/Y background palette.
    for py = 0, 15 do
      local first, last
      for px = 0, 15 do
        local dx, dy = px + .5 - 8, py + .5 - 8
        if dx * dx + dy * dy <= 64 then first, last = first or px, px end
      end
      if first then PaletteFX.markTrueColor(x + first, y + py, last - first + 1, 1) end
    end
  end

  -- Signature deliberately matches the established modern-ball bridge:
  -- (item id, OAM bounding origin, engine rotation, Ultra/Master flicker).
  function J.draw(id, x, y, angle, flicker, context)
    local image = imageFor(id)
    if not image then return end
    local g = love.graphics
    local scale = J.SCALE
    local move = context and context.move or "TOSS_ANIM"
    local frame = frameFor(move, context and context.elapsed or 0)
    g.push()
    g.translate(x + 8, y + 8)
    g.rotate(angle or 0)
    g.setColor(1, 1, 1, 1)
    g.draw(image, quadFor(id, image, frame), -16 * scale, -32 * scale,
      0, scale, scale)
    if flicker then
      g.setColor(1, 1, 1, .28)
      g.circle("fill", 0, 0, 8)
    end
    g.pop()
    markTrueColor(x, y)
    g.setColor(1, 1, 1, 1)
  end

  local function installBridge()
    local ok, AnimPlayer = pcall(require, "src.battle.AnimPlayer")
    if not ok or type(AnimPlayer) ~= "table" then return false end
    local bridge = AnimPlayer._ascendantBallBridge
    if not bridge then return false end
    bridge.draw = J.draw
    bridge.journeys = true
    return true
  end

  -- main.lua registers this factory after its existing mods.loaded callback,
  -- so the procedural bridge is already available. game.ready retries for
  -- headless/test boot orders without changing visual or catch behaviour.
  if mod.events and mod.events.on then
    mod.events:on("mods.loaded", installBridge)
    mod.events:on("game.ready", installBridge)
  else
    installBridge()
  end

  J.pathFor = pathFor
  J.frameFor = frameFor
  J.installBridge = installBridge
  mod.exports.journeysBallSkins = J
  return J
end
