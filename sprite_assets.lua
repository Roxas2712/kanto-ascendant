-- Runtime preparation for the bundled full-colour sprite packs.
--
-- Crystal battle PNGs use an opaque color-0 background because the original
-- games drew them against a flat battle field. A voxel battle needs actual
-- alpha, so only the edge-connected background is flood-cleared here.
--
-- PokeWilds' Gen-2-style overworld sheets are six horizontal 16x16 frames.
-- Gen1 Recomp expects the same poses in a vertical 16x96 sheet and a
-- different order. Converted files live in LOVE's derived cache; bundled
-- source sheets remain untouched.

return function(mod)
  local A = {}
  -- Bump the derived cache whenever follower layout/alpha handling changes.
  -- Mobile installations otherwise keep an older converted sheet forever.
  local CACHE_ROOT = "mod-derived/trainer_rematch/sprite-cache-v6"
  local prepared = {}

  local function available()
    return love and love.filesystem and love.image
      and love.image.newImageData and love.filesystem.createDirectory
  end

  local function info(path)
    return love and love.filesystem and love.filesystem.getInfo
      and love.filesystem.getInfo(path) or nil
  end

  local function current(source, target)
    local src, dst = info(source), info(target)
    if not (src and dst) then return false end
    if src.modtime and dst.modtime then return dst.modtime >= src.modtime end
    return true
  end

  local function ensureParent(path)
    local parent = path:match("^(.*)/[^/]+$")
    return parent and love.filesystem.createDirectory(parent)
  end

  local function encode(image, target)
    if not ensureParent(target) then return false end
    local ok = pcall(image.encode, image, "png", target)
    return ok and info(target) ~= nil
  end

  local function sameColor(a, b)
    return math.abs(a[1] - b[1]) < 0.001
      and math.abs(a[2] - b[2]) < 0.001
      and math.abs(a[3] - b[3]) < 0.001
      and math.abs(a[4] - b[4]) < 0.001
  end

  local function clearConnectedBackground(image)
    local w, h = image:getDimensions()
    local bg = { image:getPixel(0, 0) }
    local visited, qx, qy = {}, {}, {}
    local first, last = 1, 0

    local function add(x, y)
      if x < 0 or x >= w or y < 0 or y >= h then return end
      local key = y * w + x
      if visited[key] then return end
      local pixel = { image:getPixel(x, y) }
      if not sameColor(pixel, bg) then return end
      visited[key] = true
      last = last + 1
      qx[last], qy[last] = x, y
    end

    for x = 0, w - 1 do add(x, 0); add(x, h - 1) end
    for y = 0, h - 1 do add(0, y); add(w - 1, y) end
    while first <= last do
      local x, y = qx[first], qy[first]
      first = first + 1
      local r, g, b = image:getPixel(x, y)
      image:setPixel(x, y, r, g, b, 0)
      add(x - 1, y); add(x + 1, y)
      add(x, y - 1); add(x, y + 1)
    end
    return image
  end

  function A.crystal(relativePath)
    local source = mod.path .. "/" .. relativePath
    if not info(source) then return nil end
    if not available() then return source end
    local filename = relativePath:match("([^/]+)$")
    local target = CACHE_ROOT .. "/crystal/" .. filename
    local key = "crystal:" .. source
    if prepared[key] then return prepared[key] end
    if current(source, target) then
      prepared[key] = target
      return target
    end
    local ok, image = pcall(love.image.newImageData, source)
    if ok and image then
      clearConnectedBackground(image)
      if encode(image, target) then
        prepared[key] = target
        return target
      end
    end
    prepared[key] = source
    return source
  end

  -- PokeWilds: side still/walk, up still/walk, down still/walk.
  -- Gen1 Recomp: down still, up still, side still, down walk, up walk,
  -- side walk.
  local FOLLOWER_ORDER = { 4, 2, 0, 5, 3, 1 }
  A.followerOrder = FOLLOWER_ORDER

  local function iconFollower(source)
    local input = love.image.newImageData(source)
    clearConnectedBackground(input)
    local w, h = input:getDimensions()
    local minX, minY, maxX, maxY = w, h, -1, -1
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, alpha = input:getPixel(x, y)
        if alpha > 0 then
          minX, minY = math.min(minX, x), math.min(minY, y)
          maxX, maxY = math.max(maxX, x), math.max(maxY, y)
        end
      end
    end
    if maxX < minX or maxY < minY then return nil end
    local sourceW, sourceH = maxX - minX + 1, maxY - minY + 1
    local scale = math.min(14 / sourceW, 14 / sourceH)
    local drawW = math.max(1, math.floor(sourceW * scale + 0.5))
    local drawH = math.max(1, math.floor(sourceH * scale + 0.5))
    local offsetX, offsetY = math.floor((16 - drawW) / 2), 16 - drawH
    local output = love.image.newImageData(16, 96)
    for frame = 0, 5 do
      local targetY = frame * 16 + offsetY
      for y = 0, drawH - 1 do
        for x = 0, drawW - 1 do
          local sourceX = minX + math.min(sourceW - 1,
            math.floor((x + 0.5) * sourceW / drawW))
          local sourceY = minY + math.min(sourceH - 1,
            math.floor((y + 0.5) * sourceH / drawH))
          output:setPixel(offsetX + x, targetY + y,
            input:getPixel(sourceX, sourceY))
        end
      end
    end
    return output
  end

  local function verticalFollower(source, species)
    local input = love.image.newImageData(source)
    local w, h = input:getDimensions()
    if w == 16 and h == 96 then return input end
    if species == "UNOWN" then return iconFollower(source) end
    if w ~= 96 or h ~= 16 then return nil end
    local output = love.image.newImageData(16, 96)
    for targetFrame, sourceFrame in ipairs(FOLLOWER_ORDER) do
      local targetY = (targetFrame - 1) * 16
      local sourceX = sourceFrame * 16
      for y = 0, 15 do
        for x = 0, 15 do
          output:setPixel(x, targetY + y,
            input:getPixel(sourceX + x, y))
        end
      end
    end
    return output
  end

  function A.follower(species, shiny)
    if type(species) ~= "string" or species == "" then return nil end
    -- Release packages carry renderer-ready vertical sheets. Mobile builds
    -- can consume these directly without depending on ImageData encoding or
    -- write access during follower selection.
    local runtimeVariant = shiny and "shiny/" or "normal/"
    local runtime = mod.path .. "/assets/followers_runtime/"
      .. runtimeVariant .. "follower_" .. species .. ".png"
    if info(runtime) then return runtime end

    local filename = species:lower() .. ".png"
    local variant = shiny and "shiny/" or ""
    local source = mod.path .. "/assets/followers/" .. variant .. filename
    if species == "UNOWN" and not info(source) then
      source = mod.path .. "/assets/crystal/unown_front"
        .. (shiny and "_shiny" or "") .. ".png"
    end
    if not info(source) then return nil end
    if not available() then return source end
    local target = CACHE_ROOT .. "/followers/follower_"
      .. species .. (shiny and "_shiny" or "") .. ".png"
    local key = "follower:" .. source
    if prepared[key] then return prepared[key] end
    if current(source, target) then
      prepared[key] = target
      return target
    end
    local ok, image = pcall(verticalFollower, source, species)
    if ok and image and encode(image, target) then
      prepared[key] = target
      return target
    end
    return nil
  end

  function A.invalidate()
    prepared = {}
  end

  return A
end
