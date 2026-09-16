-- Optional title-trainer motion provider for Red, Blue and Green.
--
-- The existing TitleState compositor remains the owner of trainer/Pokemon
-- placement and identity timing.  Internal authoring builds may supply the
-- complete 16-frame action sequences.  Public packages deliberately omit
-- those provenance-pending files and animate an already shipped 128x128 HD
-- standee with a bounded, code-native offset curve instead.  Missing fallback
-- assets, provider errors and an explicit OFF option all return the caller-
-- owned static trainer unchanged.

return function(mod, opts)
  opts = opts or {}
  local registry = assert(opts.registry,
    "title trainer animation requires presentation sprite registry")
  local A = {
    schema = "kanto-ascendant-title-trainer-animation/v3",
    owner = "kasc.animated-title-core-prep/v1",
    providerId = "ascendant.title_trainers_67",
    frameCount = 16,
    ticksPerFrame = 8,
    actionTicks = 128,
    masterCanvas = 128,
    drawX = 82,
    -- Blue, Green and Red share the exact same immutable canvas geometry.
    -- Green/Red's source sheets are rebuilt before import so their complete
    -- shoes, rather than a quarter-sheet crop edge, land on this foot line.
    drawY = 68,
    drawYByIdentity = { BLUE = 68, GREEN = 68, RED = 68 },
    drawScale = 0.5,
    drawScaleByIdentity = { BLUE = 0.5, GREEN = 0.5, RED = 0.5 },
    root = opts.root or "assets/title_trainers_67",
    actions = {
      BLUE = {
        A = "subtle vertical title motion",
        B = "subtle horizontal title motion",
      },
      GREEN = {
        A = "subtle vertical title motion",
        B = "subtle horizontal title motion",
      },
      RED = {
        A = "subtle vertical title motion",
        B = "subtle horizontal title motion",
      },
    },
  }
  local identities = { BLUE = "blue", GREEN = "green", RED = "red" }
  local publicFallbackPaths = {
    BLUE = "assets/characters/crystal_chars/blue_voxel_front_hd.png",
    GREEN = "assets/characters/crystal_chars/green_voxel_front_hd.png",
    RED = "assets/characters/crystal_chars/red_voxel_front_hd.png",
  }
  local imageCache = {}
  -- A broken optional dependency retires the animation for this boot only.
  -- The option store is deliberately never changed here, so a saved ON can
  -- try again after assets/the companion are repaired and the game restarts.
  local sessionFallbackReason

  -- No identity receives a per-frame canvas correction on either axis.
  -- All six authored actions keep the same 128x128 overlay origin.
  local anchorOffsets = {
    BLUE = { a = {}, b = {} },
    GREEN = { a = {}, b = {} },
    RED = { a = {}, b = {} },
  }

  -- Public-safe A/B variants use the same immutable HD standee.  Only its
  -- title-space transform changes, by at most two logical pixels.  Both
  -- curves return to the exact baseline on frame 16, so the completed action
  -- can hold indefinitely without a jump or a hidden replacement image.
  local publicMotionOffsets = {
    a = {
      {0,0},{0,0},{0,-1},{0,-1},{0,-2},{0,-2},{0,-1},{0,-1},
      {0,0},{0,0},{0,1},{0,1},{0,0},{0,0},{0,0},{0,0},
    },
    b = {
      {0,0},{1,0},{1,-1},{2,-1},{2,-1},{1,-1},{1,0},{0,0},
      {0,1},{-1,1},{-1,1},{-2,1},{-2,0},{-1,0},{0,0},{0,0},
    },
  }

  local function anchorOffset(identity, variant, frame)
    identity = type(identity) == "string" and identity:upper() or nil
    variant = type(variant) == "string" and variant:lower() or nil
    frame = tonumber(frame)
    local row = identity and anchorOffsets[identity]
    row = row and row[variant]
    row = row and row[frame]
    return tonumber(row) or 0, 0
  end

  local function publicMotionOffset(variant, frame)
    variant = type(variant) == "string" and variant:lower() or nil
    frame = math.max(1, math.min(A.frameCount,
      math.floor(tonumber(frame) or 1)))
    local point = publicMotionOffsets[variant]
      and publicMotionOffsets[variant][frame]
    return point and point[1] or 0, point and point[2] or 0
  end

  local function publicFallbackPath(identity)
    identity = type(identity) == "string" and identity:upper() or nil
    return publicFallbackPaths[identity]
  end

  local function drawYFor(identity)
    identity = type(identity) == "string" and identity:upper() or nil
    return A.drawYByIdentity[identity] or A.drawY
  end

  local function drawScaleFor(identity)
    identity = type(identity) == "string" and identity:upper() or nil
    return A.drawScaleByIdentity[identity] or A.drawScale
  end

  local function failSession(reason)
    if sessionFallbackReason == nil then
      sessionFallbackReason = tostring(reason or "animation-unavailable")
    end
    return sessionFallbackReason
  end

  local function enabled()
    -- Once an optional title dependency has failed, do not repeatedly touch
    -- the same broken reader/provider during this boot.
    if sessionFallbackReason ~= nil then return false end
    local ok, value = pcall(mod.options.get, mod.options,
      "animated_title_trainers")
    if not ok then
      failSession("option-read-failed: " .. tostring(value))
      return false
    end
    -- The RC follow-up migrates old profiles virtually: a missing key uses
    -- ON without writing one. Explicit false (and any legacy CLASSIC marker)
    -- remains fail-closed and is never normalized behind the user's back.
    if value == nil then return true end
    return value == true
  end

  local function framePath(identity, variant, frame)
    local folder = identities[identity]
    variant = type(variant) == "string" and variant:lower() or nil
    frame = tonumber(frame)
    if not (folder and (variant == "a" or variant == "b")
        and frame and frame >= 1 and frame <= A.frameCount
        and frame == math.floor(frame)) then return nil end
    -- Only the final 128x128 RGBA masters are accepted.  The historical
    -- 40x56 derivatives had clipped foot lines and are intentionally not part
    -- of this Card or its package allowlist.
    return ("%s/%s/variants/%s/frames/%03d.png")
      :format(A.root, folder, variant, frame)
  end

  local function loadFrame(relative)
    if not relative then return nil end
    if imageCache[relative] then return imageCache[relative] end
    local okRead, bytes = pcall(mod.read, mod, relative)
    if not (okRead and bytes ~= nil) then return nil end
    local ok, image
    if type(opts.loadImage) == "function" then
      ok, image = pcall(opts.loadImage, relative)
    elseif rawget(_G, "love") and love.graphics
        and type(love.graphics.newImage) == "function" then
      ok, image = pcall(love.graphics.newImage, mod.path .. "/" .. relative)
    end
    if not (ok and image) then return nil end
    if type(image.setFilter) == "function" then
      -- Pixel-art title figures must stay crisp at every integer or bounded
      -- downscale.  Linear filtering was the source of the visibly blurred
      -- screenshots in the previous candidate.
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    imageCache[relative] = image
    return image
  end

  local function resolve(request)
    local identity = type(request.identity) == "string"
      and request.identity:upper() or nil
    local variant = type(request.variant) == "string"
      and request.variant:lower() or nil
    local frames, authored = {}, true
    for frame = 1, A.frameCount do
      local image = loadFrame(framePath(identity, variant, frame))
      if not image then
        authored = false
        frames = {}
        break
      end
      frames[frame] = image
    end
    local source = "authored-action-frames"
    local sourcePath
    if not authored then
      sourcePath = publicFallbackPath(identity)
      local standee = loadFrame(sourcePath)
      if not standee then return nil end
      for frame = 1, A.frameCount do frames[frame] = standee end
      source = "existing-hd-code-motion"
    end
    local function offset(frame)
      if authored then return anchorOffset(identity, variant, frame) end
      return publicMotionOffset(variant, frame)
    end
    local dx, dy = offset(1)
    local baseY = drawYFor(identity)
    local state = {
      image = frames[1], trueColor = true,
      identity = identity, variant = variant,
      pairId = request.pairId, frame = 1,
      elapsedTicks = 0, complete = false,
      frames = frames,
      source = source, sourcePath = sourcePath,
      publicFallback = not authored,
      drawX = A.drawX + dx, drawY = baseY + dy,
      drawScale = drawScaleFor(identity),
      cropTop = 0, masterCanvas = A.masterCanvas,
    }
    state.advance = function(result, _, context)
      local ticks = math.floor(math.max(0,
        tonumber(context and context.ticks) or 1))
      result.elapsedTicks = math.min(A.actionTicks,
        result.elapsedTicks + ticks)
      result.frame = math.min(A.frameCount,
        math.floor(result.elapsedTicks / A.ticksPerFrame) + 1)
      result.complete = result.elapsedTicks >= A.actionTicks
      result.cropTop = 0
      local frameDx, frameDy = offset(result.frame)
      result.drawX = A.drawX + frameDx
      result.drawY = baseY + frameDy
      return result.frames[result.frame]
    end
    return state
  end

  local registered, why = registry:registerTrainer(A.providerId, {
    owner = "Kanto Ascendant",
    priority = 100,
    supports = function(request)
      local identity = type(request.identity) == "string"
        and request.identity:upper() or nil
      local variant = type(request.variant) == "string"
        and request.variant:lower() or nil
      return enabled() and request.surface == "title"
        and identities[identity] ~= nil
        and (variant == "a" or variant == "b")
    end,
    resolve = resolve,
  })
  assert(registered, "title trainer provider registration failed: "
    .. tostring(why))

  local function restoreStatic(screen, staticImage)
    if not screen then return nil end
    local state = screen.__ascendantTitleTrainerAnimation67
    local fallback = staticImage
      or screen.__ascendantTitleTrainerStatic67
      or state and state.staticImage
      or screen.player
    screen.__ascendantTitleTrainerAnimation67 = nil
    screen.__ascendantTitleTrainerStatic67 = nil
    if fallback ~= nil then screen.player = fallback end
    return fallback
  end

  function A.applyTitle(screen, identity, pairId, staticImage)
    if not screen then return staticImage, { status = "invalid" } end
    if staticImage ~= nil then screen.player = staticImage end
    if not enabled() then
      return restoreStatic(screen, staticImage), { status = "disabled" }
    end
    identity = type(identity) == "string" and identity:upper() or nil
    local current = screen.__ascendantTitleTrainerAnimation67
    if current and current.identity == identity and current.pairId == pairId then
      screen.player = current.staticImage or staticImage or screen.player
      return current.image, { status = "unchanged", variant = current.variant }
    end
    local history = screen.__ascendantTitleTrainerVariantHistory67
    if type(history) ~= "table" then
      history = {}
      screen.__ascendantTitleTrainerVariantHistory67 = history
    end
    local variant = history[identity] == "a" and "b" or "a"
    local result, receipt = registry:resolveTrainer({
      surface = "title", identity = identity, variant = variant,
      pairId = pairId, screen = screen, staticImage = staticImage,
    })
    screen.__ascendantTitleTrainerResolveReceipt67 = receipt
    if not result then
      failSession(receipt and receipt.reason or "provider-unavailable")
      return restoreStatic(screen, staticImage), {
        status = "fallback", variant = variant, receipt = receipt,
      }
    end
    history[identity] = variant
    result.staticImage = staticImage
    result.pairId = pairId
    screen.__ascendantTitleTrainerStatic67 = staticImage
    screen.__ascendantTitleTrainerAnimation67 = result
    screen.player = staticImage
    return result.image, { status = "animated", variant = variant,
      providerId = result.providerId }
  end

  function A.advanceTitle(screen, ticks)
    if not screen then return nil, { status = "invalid" } end
    if not enabled() then
      return restoreStatic(screen), { status = "disabled" }
    end
    local state = screen.__ascendantTitleTrainerAnimation67
    if not state then return screen.player, { status = "static" } end
    screen.player = state.staticImage or screen.player
    if state.pairId ~= screen.kaTitlePairId then
      return restoreStatic(screen), { status = "pair-drift" }
    end
    local image, receipt = registry:advance(state, 0, {
      surface = "title", screen = screen, ticks = ticks or 1,
    })
    screen.__ascendantTitleTrainerAdvanceReceipt67 = receipt
    if receipt and receipt.status == "yielded" then
      failSession(receipt.reason or "advance-failed")
      return restoreStatic(screen), receipt
    end
    return image, receipt
  end

  function A.resetTitle(screen, staticImage)
    return restoreStatic(screen, staticImage)
  end

  A.enabled = enabled
  A.framePath = framePath
  A.publicFallbackPath = publicFallbackPath
  A.loadFrame = loadFrame
  A.anchorOffset = anchorOffset
  A.publicMotionOffset = publicMotionOffset
  A.drawYFor = drawYFor
  A.drawScaleFor = drawScaleFor
  A.failSession = failSession
  A.sessionFallbackReason = function() return sessionFallbackReason end
  return A
end
