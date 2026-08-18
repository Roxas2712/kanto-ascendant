-- Resolve the three user-authored Crystal walking sheets without allowing a
-- broken PNG to take the player renderer down.  Walking is deliberately the
-- only surface covered here: bike, fishing, battle, throw, profile and Voxel
-- assets keep their independent resolvers.

local CHARACTERS = { red = true, green = true, blue = true }
local WIDTH, HEIGHT, FRAME_HEIGHT, FRAME_COUNT = 16, 96, 16, 6
local ALPHA_EPSILON = 1 / 255

local function normalizedAlpha(alpha)
  if type(alpha) ~= "number" or alpha < 0 or alpha > 255 then return nil end
  -- LÖVE 11 returns 0..1; older ImageData shims may still expose 0..255.
  if alpha > 1 then alpha = alpha / 255 end
  return alpha
end

local function validateImageData(data)
  if type(data) ~= "userdata" and type(data) ~= "table" then
    return false, "invalid_image_data"
  end
  if type(data.getDimensions) ~= "function"
      or type(data.getPixel) ~= "function" then
    return false, "missing_image_data_api"
  end

  local width, height = data:getDimensions()
  if width ~= WIDTH or height ~= HEIGHT then
    return false, ("bad_dimensions_%sx%s"):format(
      tostring(width), tostring(height))
  end

  for frame = 0, FRAME_COUNT - 1 do
    local top = frame * FRAME_HEIGHT
    local opaque, baseline = false, false
    for y = 0, FRAME_HEIGHT - 1 do
      for x = 0, WIDTH - 1 do
        local _, _, _, alpha = data:getPixel(x, top + y)
        alpha = normalizedAlpha(alpha)
        if alpha == nil then
          return false, "missing_alpha"
        end
        if alpha > ALPHA_EPSILON and alpha < 1 - ALPHA_EPSILON then
          return false, "soft_alpha"
        end
        if alpha >= 1 - ALPHA_EPSILON then
          opaque = true
          if y == FRAME_HEIGHT - 1 then baseline = true end
        end
      end
    end
    if not opaque then return false, "empty_frame_" .. tostring(frame) end
    if not baseline then
      return false, "missing_baseline_" .. tostring(frame)
    end
    for _, corner in ipairs({
      { 0, top }, { WIDTH - 1, top },
      { 0, top + FRAME_HEIGHT - 1 },
      { WIDTH - 1, top + FRAME_HEIGHT - 1 },
    }) do
      local _, _, _, alpha = data:getPixel(corner[1], corner[2])
      alpha = normalizedAlpha(alpha)
      if alpha == nil then return false, "missing_alpha" end
      if alpha >= 1 - ALPHA_EPSILON then
        return false, "opaque_corner_" .. tostring(frame)
      end
    end
  end
  return true
end

return function(mod, deps)
  deps = deps or {}
  local injectedImageApi = deps.imageApi ~= nil
  local imageApi = deps.imageApi or (love and love.image)
  local root = mod.path .. "/assets/characters/crystal_chars/"
  local resolver = { receipts = {} }

  local function inspect(path)
    if not imageApi or type(imageApi.newImageData) ~= "function" then
      return nil, "validation_unavailable"
    end
    local ok, data = pcall(imageApi.newImageData, path)
    if not ok then return false, "decode_failed" end
    -- Real LÖVE ImageData is userdata. The engine's ROM-free love_stub returns
    -- a generic 8x8 Lua table for every path and therefore cannot validate a
    -- packaged PNG. Keep that headless path explicit/unverified; injected
    -- table decoders remain available to the focused corruption tests.
    if not injectedImageApi and type(data) ~= "userdata" then
      return nil, "validation_unavailable"
    end
    return validateImageData(data)
  end

  function resolver.resolve(character)
    character = type(character) == "string" and character:lower() or ""
    assert(CHARACTERS[character], "unknown Crystal walking identity")
    if resolver.receipts[character] then
      return resolver.receipts[character].path
    end

    local primary = root .. character .. "_walk.png"
    local fallbacks = {}
    -- The 2026-08-18 Red/Green/Blue set supersedes all three walking masters.
    -- Green's immediately preceding hotfix is its v3 recovery lane; Red and
    -- Blue enter v2 directly. The per-identity v2 lane then preserves either
    -- the preceding Red/Blue primary or Green's public-6.5.5 sheet before all
    -- identities reach the original reviewed v1 fallback.
    if character == "green" then
      fallbacks[#fallbacks + 1] = {
        path = root .. "fallback_walk_v3/green_walk.png",
        lane = "fallback-v3",
      }
    end
    fallbacks[#fallbacks + 1] = {
      path = root .. "fallback_walk_v2/" .. character .. "_walk.png",
      lane = "fallback-v2",
    }
    fallbacks[#fallbacks + 1] = {
      path = root .. "fallback_walk_v1/" .. character .. "_walk.png",
      lane = "fallback-v1",
    }
    local valid, reason = inspect(primary)
    local receipt
    if valid == false then
      local failures = { "primary=" .. tostring(reason) }
      for _, fallback in ipairs(fallbacks) do
        local fallbackValid, fallbackReason = inspect(fallback.path)
        if fallbackValid == true then
          receipt = {
            path = fallback.path,
            lane = fallback.lane,
            reason = reason,
            fallbackFailures = failures,
          }
          break
        end
        failures[#failures + 1] = fallback.lane .. "="
          .. tostring(fallbackReason)
      end
      assert(receipt ~= nil,
        ("invalid Crystal %s walking chain (%s)")
          :format(character, table.concat(failures, ", ")))
    else
      receipt = {
        path = primary,
        lane = valid == true and "primary" or "primary-unverified",
        reason = reason,
      }
    end
    resolver.receipts[character] = receipt
    return receipt.path
  end

  return resolver
end
