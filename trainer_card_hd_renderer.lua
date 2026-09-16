-- Native high-resolution Trainer Card collection renderer for KASC 6.6.
--
-- The ordinary Gen-I card is 160x144.  This replacement keeps that state as
-- a failure fallback, but authors the collection on a 640x400 logical surface
-- and mirrors it through render.hud after the finished frame.  Geometry is
-- therefore rasterized in window space and the approved 128px portraits are
-- presented as portraits, not reduced to postage stamps.

return function(mod, opts)
  opts = opts or {}
  local cards = assert(opts.collection, "Trainer Card renderer needs collection")
  local characters = opts.characters or opts.extendedCharacters
  local standard = opts.standardFallback or opts.standard
  local R = {
    game = nil,
    width = 640,
    height = 400,
    marker = "__kantoAscendantTrainerCardCollection",
    modelKey = "__kantoAscendantTrainerCardModel",
    lastError = nil,
    cards = cards,
    hostedByStandard = false,
    lastClassicError = nil,
  }

  local G = love and love.graphics
  local cache = { fonts = {}, materials = {}, images = {} }

  local function withGraphicsState(mode, body)
    if mode then G.push(mode) else G.push() end
    local ok, first, second = pcall(body)
    G.pop()
    if not ok then error(first, 0) end
    return first, second
  end
  local leaderPaths = {
    brock = "assets/characters/frlg_trainers/leader_brock_voxel_front_hd_v2.png",
    misty = "assets/characters/frlg_trainers/leader_misty_voxel_front_hd_v2.png",
    surge = "assets/characters/frlg_trainers/leader_lt_surge_voxel_front_hd_v2.png",
    erika = "assets/characters/frlg_trainers/leader_erika_voxel_front_hd_v2.png",
    koga = "assets/characters/frlg_trainers/leader_koga_voxel_front_hd_v2.png",
    sabrina = "assets/characters/frlg_trainers/leader_sabrina_voxel_front_hd_v2.png",
    blaine = "assets/characters/frlg_trainers/leader_blaine_voxel_front_hd_v2.png",
    giovanni = "assets/characters/frlg_trainers/leader_giovanni_voxel_front_hd_v2.png",
    OPP_LORELEI = "assets/characters/frlg_trainers/elite_four_lorelei_voxel_front_hd_v3.png",
    OPP_BRUNO = "assets/characters/frlg_trainers/elite_four_bruno_voxel_front_hd_v3.png",
    OPP_AGATHA = "assets/characters/frlg_trainers/elite_four_agatha_voxel_front_hd_v3.png",
    OPP_LANCE = "assets/characters/frlg_trainers/elite_four_lance_voxel_front_hd_v3.png",
  }
  local rivalPaths = {
    RED = "assets/characters/crystal_chars/red_voxel_front_hd.png",
    GREEN = "assets/characters/crystal_chars/green_voxel_front_hd.png",
    BLUE = "assets/characters/crystal_chars/blue_voxel_front_hd.png",
  }

  local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
  end

  local function hex(value, alpha)
    value = tostring(value or "ffffff"):gsub("#", "")
    if #value ~= 6 then value = "ffffff" end
    return {
      tonumber(value:sub(1, 2), 16) / 255,
      tonumber(value:sub(3, 4), 16) / 255,
      tonumber(value:sub(5, 6), 16) / 255,
      alpha == nil and 1 or alpha,
    }
  end

  local function color(c, alpha)
    if type(c) == "string" then c = hex(c, alpha) end
    c = type(c) == "table" and c or { 1, 1, 1, 1 }
    G.setColor(c[1] or 1, c[2] or 1, c[3] or 1,
      alpha == nil and (c[4] or 1) or alpha)
  end

  local function font(size)
    size = math.max(7, math.floor(tonumber(size) or 12))
    if cache.fonts[size] then return cache.fonts[size] end
    if not (G and G.newFont) then return nil end
    local ok, value = pcall(G.newFont, size)
    if not ok then return nil end
    if value.setFilter then value:setFilter("linear", "linear") end
    cache.fonts[size] = value
    return value
  end

  local function fittedFont(text, maximum, preferred, minimum)
    text = tostring(text or "")
    for size = preferred, minimum or 8, -1 do
      local f = font(size)
      if f and f:getWidth(text) <= maximum then return f end
    end
    return font(minimum or 8)
  end

  local function printFit(text, x, y, width, preferred, minimum, align, c)
    local f = fittedFont(text, width, preferred, minimum)
    if not f then return end
    G.setFont(f)
    color(c or { 1, 1, 1, 1 })
    G.printf(tostring(text or ""), x, y, width, align or "left")
  end

  local function printWrap(text, x, y, width, size, align, c)
    local f = font(size)
    if not f then return end
    G.setFont(f)
    color(c or { 1, 1, 1, 1 })
    G.printf(tostring(text or ""), x, y, width, align or "left")
  end

  local function rounded(mode, x, y, w, h, radius)
    G.rectangle(mode, x, y, w, h, radius or 0, radius or 0)
  end

  local function safeOwnImage(path, material)
    if type(path) ~= "string" or path == "" or not G then return nil end
    local key = (material and "material:" or "own:") .. path
    if cache.images[key] ~= nil then return cache.images[key] or nil end
    local ok, image
    if mod.assets and type(mod.assets.image) == "function" then
      ok, image = pcall(mod.assets.image, mod.assets, path)
    else
      ok, image = pcall(G.newImage, (mod.path or "") .. "/" .. path)
    end
    if not ok then image = nil end
    if image and image.setFilter then
      image:setFilter(material and "linear" or "nearest",
        material and "linear" or "nearest")
    end
    cache.images[key] = image or false
    return image
  end

  local function safeResolvedImage(path)
    if type(path) ~= "string" or path == "" or not G then return nil end
    if cache.images[path] ~= nil then return cache.images[path] or nil end
    local okAssets, Assets = pcall(require, "src.render.Assets")
    local ok, image
    if okAssets and Assets and type(Assets.image) == "function" then
      ok, image = pcall(Assets.image, path)
    else
      ok, image = pcall(G.newImage, path)
    end
    if not ok then image = nil end
    if image and image.setFilter then image:setFilter("nearest", "nearest") end
    cache.images[path] = image or false
    return image
  end

  local function materialImage(id)
    if cache.materials[id] ~= nil then return cache.materials[id] or nil end
    local image = safeOwnImage(
      "assets/trainer_card/collection/materials/" .. tostring(id) .. ".png",
      true)
    cache.materials[id] = image or false
    return image
  end

  local function drawCover(image, x, y, w, h)
    if not image then return false end
    local iw, ih = image:getDimensions()
    if not iw or iw <= 0 or not ih or ih <= 0 then return false end
    local scale = math.max(w / iw, h / ih)
    local dw, dh = iw * scale, ih * scale
    G.draw(image, x + (w - dw) / 2, y + (h - dh) / 2, 0, scale, scale)
    return true
  end

  local function drawContain(image, x, y, w, h, scaleBias)
    if not image then return false end
    local iw, ih = image:getDimensions()
    if not iw or iw <= 0 or not ih or ih <= 0 then return false end
    local scale = math.min(w / iw, h / ih) * (scaleBias or 1)
    G.draw(image, math.floor(x + (w - iw * scale) / 2),
      math.floor(y + (h - ih * scale) / 2), 0, scale, scale)
    return true
  end

  local function palette(model)
    local p = model and model.visual and model.visual.palette or {}
    return {
      dark = hex(p[1] or "101827"),
      mid = hex(p[2] or "48647a"),
      light = hex(p[3] or "f2d98b"),
      ink = { 0.035, 0.047, 0.066, 1 },
      paper = { 0.965, 0.975, 0.985, 1 },
    }
  end

  local function drawCornerGem(x, y, size, c, rotation)
    color(c)
    withGraphicsState(nil, function()
      G.translate(x, y)
      G.rotate(rotation or 0)
      G.polygon("fill", 0, -size, size, 0, 0, size, -size, 0)
      color({ 1, 1, 1, 0.45 })
      G.polygon("fill", 0, -size * 0.72, 0, 0, -size * 0.72, 0)
    end)
  end

  local function drawShell(shell, x, y, w, h, p)
    shell = math.max(1, math.min(10, math.floor(tonumber(shell) or 1)))
    color({ 0.01, 0.015, 0.025, 0.88 })
    rounded("fill", x + 5, y + 7, w, h, shell % 2 == 0 and 18 or 10)
    if shell == 1 then
      color(p.light); rounded("line", x, y, w, h, 24)
      color(p.mid); rounded("line", x + 8, y + 8, w - 16, h - 16, 18)
      drawCornerGem(x + 20, y + 20, 10, p.light)
      drawCornerGem(x + w - 20, y + h - 20, 10, p.light)
    elseif shell == 2 then
      color(p.light)
      G.polygon("line", x + 26, y, x + w - 26, y, x + w, y + 26,
        x + w, y + h - 26, x + w - 26, y + h, x + 26, y + h,
        x, y + h - 26, x, y + 26)
      color(p.mid)
      G.polygon("line", x + 36, y + 10, x + w - 36, y + 10,
        x + w - 10, y + 36, x + w - 10, y + h - 36,
        x + w - 36, y + h - 10, x + 36, y + h - 10,
        x + 10, y + h - 36, x + 10, y + 36)
    elseif shell == 3 then
      color(p.light)
      G.rectangle("fill", x, y + 24, 8, h - 48)
      G.rectangle("fill", x + w - 8, y + 24, 8, h - 48)
      for i = 0, 5 do
        G.rectangle("fill", x + 24 + i * (w - 48) / 6, y, 26, 5)
        G.rectangle("fill", x + 24 + i * (w - 48) / 6, y + h - 5, 26, 5)
      end
      color(p.mid); rounded("line", x + 12, y + 8, w - 24, h - 16, 8)
    elseif shell == 4 then
      color(p.light)
      -- A faceted crown arch stays wholly inside the card.  The former
      -- circle used a 303px radius around y+58 and sent most of this border
      -- above the 640x400 canvas.
      G.line(x + 5, y + 58, x + w * 0.18, y + 22,
        x + w * 0.5, y, x + w * 0.82, y + 22, x + w - 5, y + 58)
      G.line(x + 5, y + 58, x + 5, y + h - 5, x + w - 5, y + h - 5,
        x + w - 5, y + 58)
      color(p.mid); G.line(x + 24, y + 62, x + 24, y + h - 18)
      G.line(x + w - 24, y + 62, x + w - 24, y + h - 18)
      drawCornerGem(x + w / 2, y + 8, 13, p.light)
    elseif shell == 5 then
      color(p.light)
      G.polygon("line", x + 50, y, x + w, y, x + w - 50, y + h,
        x, y + h)
      color(p.mid)
      G.line(x + 70, y + 8, x + w - 12, y + 8)
      G.line(x + 12, y + h - 8, x + w - 70, y + h - 8)
      for i = 0, 3 do
        G.line(x + 18 + i * 16, y + h - 14, x + 54 + i * 16, y + 14)
      end
    elseif shell == 6 then
      color(p.light)
      local n = 34
      G.line(x, y + n, x, y, x + n, y)
      G.line(x + w - n, y, x + w, y, x + w, y + n)
      G.line(x, y + h - n, x, y + h, x + n, y + h)
      G.line(x + w - n, y + h, x + w, y + h, x + w, y + h - n)
      color(p.mid)
      for i = 0, 7 do
        local px = x + 54 + i * (w - 108) / 7
        G.circle("fill", px, y + 7, 3)
        G.circle("fill", px, y + h - 7, 3)
      end
    elseif shell == 7 then
      color(p.light); rounded("line", x + 4, y + 4, w - 8, h - 8, 42)
      for i = 0, 5 do
        local px = x + 28 + i * (w - 56) / 5
        G.circle("line", px, y + 8, 12)
        G.circle("line", px, y + h - 8, 12)
      end
      color(p.mid); rounded("line", x + 17, y + 17, w - 34, h - 34, 30)
    elseif shell == 8 then
      color(p.light)
      local top = { x, y + 28, x + 48, y + 28, x + 75, y,
        x + 105, y + 28, x + w - 105, y + 28, x + w - 75, y,
        x + w - 48, y + 28, x + w, y + 28 }
      G.line(top)
      G.line(x, y + 28, x, y + h, x + w, y + h, x + w, y + 28)
      color(p.mid); rounded("line", x + 14, y + 38, w - 28, h - 52, 7)
    elseif shell == 9 then
      color(p.light)
      G.rectangle("line", x, y, w, h)
      G.line(x + w * 0.31, y, x + w * 0.25, y + h)
      G.line(x + w * 0.73, y, x + w * 0.79, y + h)
      color(p.mid)
      G.polygon("fill", x, y, x + 38, y, x, y + 38)
      G.polygon("fill", x + w, y + h, x + w - 38, y + h, x + w, y + h - 38)
    else
      color(p.light); rounded("line", x + 6, y + 6, w - 12, h - 12, 60)
      color(p.mid)
      G.arc("line", "open", x + w / 2, y + h / 2, w * 0.46,
        math.pi * 1.08, math.pi * 1.92)
      for i = 0, 7 do
        local a = i * math.pi / 4
        drawCornerGem(x + w / 2 + math.cos(a) * (w / 2 - 8),
          y + h / 2 + math.sin(a) * (h / 2 - 8), 7, p.light, a)
      end
    end
    G.setLineWidth(1)
  end

  local function identitySeed(model)
    local visual = model and model.visual or {}
    local text = tostring(visual.frame or "") .. "|"
      .. tostring(visual.motif or "")
    local seed = 17
    for index = 1, #text do seed = (seed * 33 + text:byte(index)) % 65521 end
    return seed
  end

  -- The material/shell pair already gives every card a unique base frame.
  -- This six-glyph edge signature makes frameIdentity/motif visible too: the
  -- 0..49 serial code cannot repeat, while the authored names choose each
  -- glyph's geometry and orientation.
  local function drawFrameIdentity(model, x, y, w, h, p, miniature)
    local serialCode = math.max(0, (tonumber(model and model.serial) or 1) - 1)
    local seed = identitySeed(model)
    local glyphSize = miniature and 1.5 or 3.2
    local spacing = miniature and 7 or 16
    local startX = miniature and (x + w - 4)
      or (x + w / 2 - spacing * 2.5)
    local startY = miniature and (y + 20) or (y + 6)
    G.setLineWidth(miniature and 1 or 1.5)
    for index = 0, 5 do
      local bit = math.floor(serialCode / (2 ^ index)) % 2
      color(bit == 1 and p.light or p.mid, bit == 1 and 0.9 or 0.58)
      local gx = miniature and startX or (startX + index * spacing)
      local gy = miniature and (startY + index * spacing) or startY
      local shape = (seed + index) % 3
      if shape == 0 then
        G.circle(bit == 1 and "fill" or "line", gx, gy, glyphSize)
      elseif shape == 1 then
        if bit == 1 then
          G.polygon("fill", gx, gy - glyphSize, gx + glyphSize, gy,
            gx, gy + glyphSize, gx - glyphSize, gy)
        else
          G.polygon("line", gx, gy - glyphSize, gx + glyphSize, gy,
            gx, gy + glyphSize, gx - glyphSize, gy)
        end
      else
        local side = glyphSize * 1.55
        G.rectangle(bit == 1 and "fill" or "line", gx - side / 2,
          gy - side / 2, side, side)
      end
      if not miniature then
        color(bit == 1 and p.mid or p.light, 0.34)
        G.circle("fill", gx, y + h - 6, math.max(1.2, glyphSize / 2))
      end
    end
    G.setLineWidth(1)
  end

  local function tr(en, de)
    local i18n = opts.i18n
    if i18n and type(i18n.text) == "function" then
      local ok, value = pcall(i18n.text, en, de)
      if ok and type(value) == "string" and value ~= "" then return value end
    end
    return en
  end

  local function semanticBadgeColor(name, p)
    if name == "shadow" then return { 0.015, 0.02, 0.035, 0.92 } end
    if name == "base" then return p.mid end
    if name == "accent" then return p.light end
    return { 1, 1, 1, 0.82 }
  end

  local function drawBadge(icon, x, y, size, p, opacity)
    if type(icon) ~= "table" or type(icon.primitives) ~= "table" then
      return false
    end
    local alpha = opacity == nil and 1 or opacity
    withGraphicsState(nil, function()
      G.translate(x, y)
      G.scale(size / 100, size / 100)
      for _, primitive in ipairs(icon.primitives) do
        local c = semanticBadgeColor(primitive.fill, p)
        color(c, (c[4] or 1) * alpha)
        if primitive.kind == "polygon" and type(primitive.points) == "table" then
          G.polygon("fill", primitive.points)
        elseif primitive.kind == "ellipse" then
          local width = tonumber(primitive.width) or 0
          local height = tonumber(primitive.height) or width
          G.ellipse("fill", (tonumber(primitive.x) or 0) + width / 2,
            (tonumber(primitive.y) or 0) + height / 2, width / 2, height / 2)
        end
      end
      color({ 1, 1, 1, 0.28 * alpha })
      G.setLineWidth(1.4)
      G.circle("line", 50, 50, 47)
    end)
    G.setLineWidth(1)
    return true
  end

  local function abstractMark(model, x, y, size, p, quiet)
    local serial = math.max(1, tonumber(model and model.serial) or 1)
    local spokes = 4 + serial % 7
    local inner = size * (0.18 + (serial % 4) * 0.025)
    local outer = size * 0.42
    withGraphicsState(nil, function()
      G.translate(x + size / 2, y + size / 2)
      G.rotate((serial % 16) * math.pi / 16)
      color(p.mid, quiet and 0.42 or 0.72)
      G.setLineWidth(math.max(1, size / 40))
      for i = 0, spokes - 1 do
        local angle = i * math.pi * 2 / spokes
        G.line(math.cos(angle) * inner, math.sin(angle) * inner,
          math.cos(angle) * outer, math.sin(angle) * outer)
        G.circle("fill", math.cos(angle) * outer, math.sin(angle) * outer,
          math.max(1.5, size / 35))
      end
      color(p.light, quiet and 0.55 or 0.9)
      if serial % 3 == 0 then
        G.polygon("fill", 0, -inner, inner, 0, 0, inner, -inner, 0)
      elseif serial % 3 == 1 then
        G.circle("line", 0, 0, inner)
        G.circle("fill", 0, 0, math.max(2, inner / 3))
      else
        G.polygon("line", 0, -inner, inner * 0.9, inner * 0.65,
          -inner * 0.9, inner * 0.65)
      end
    end)
    G.setLineWidth(1)
  end

  local function materialBackdrop(model)
    local p = palette(model)
    color(p.dark)
    G.rectangle("fill", 0, 0, R.width, R.height)
    local material = model and model.visual and model.visual.material
    local image = materialImage(material)
    if image then
      color({ 1, 1, 1, 0.72 })
      drawCover(image, 0, 0, R.width, R.height)
    else
      color(p.mid, 0.28)
      for offset = -R.height, R.width, 38 do
        G.polygon("fill", offset, 0, offset + 16, 0,
          offset + R.height + 16, R.height, offset + R.height, R.height)
      end
    end
    color(p.dark, 0.56)
    G.rectangle("fill", 0, 0, R.width, R.height)
    color({ 0, 0, 0, 0.28 })
    G.rectangle("fill", 0, R.height - 70, R.width, 70)
    return p
  end

  local function playerPortrait(model)
    -- The stock player.sprite trainer-card seam intentionally returns compact
    -- 64px art.  The collection has a 176px portrait plate, so resolve the
    -- authoritative Ascendant identity to its approved 128px standing master
    -- first; playerPath remains the compatibility fallback for other mods.
    local hdIdentity = R.playerCharacterId(model)
    local hdImage = rivalPaths[hdIdentity]
      and safeOwnImage(rivalPaths[hdIdentity]) or nil
    if hdImage then return hdImage end
    local okSprites, Sprites = pcall(require, "src.pokemon.Sprites")
    if okSprites and Sprites and R.game and R.game.data
        and type(Sprites.playerPath) == "function" then
      local ok, path = pcall(Sprites.playerPath, R.game.data, "front",
        { kind = "trainer_card" })
      if ok and path then
        local image = safeResolvedImage(path)
        if image then return image end
      end
    end
    local identity = tostring(model and model.player and model.player.id or "")
      :upper()
    for id, path in pairs(rivalPaths) do
      if identity:find(id, 1, true) then
        local image = safeOwnImage(path)
        if image then return image end
      end
    end
    return safeOwnImage(rivalPaths.GREEN)
      or safeOwnImage(rivalPaths.RED)
      or safeOwnImage(rivalPaths.BLUE)
  end

  local function rivalPortrait(model)
    local id = R.rivalCharacterId(model)
    local image = rivalPaths[id] and safeOwnImage(rivalPaths[id]) or nil
    if image then return image end
    return safeOwnImage(rivalPaths.BLUE)
  end

  local function leaderPortrait(id, model)
    if id == "OPP_RIVAL3" then return rivalPortrait(model) end
    return safeOwnImage(leaderPaths[id])
  end

  local function portraitPlate(image, x, y, w, h, p, locked, emphasized)
    color({ 0.015, 0.025, 0.04, 0.78 })
    rounded("fill", x, y, w, h, emphasized and 18 or 11)
    color(p.mid, 0.68)
    G.setLineWidth(emphasized and 3 or 2)
    rounded("line", x, y, w, h, emphasized and 18 or 11)
    color({ 1, 1, 1, locked and 0.22 or 1 })
    if image then drawContain(image, x + 4, y + 4, w - 8, h - 8, 1.02) end
    if locked then
      color({ 0.015, 0.02, 0.03, 0.76 })
      rounded("fill", x + 2, y + 2, w - 4, h - 4, 9)
    end
    G.setLineWidth(1)
  end

  function R.playerCharacterId(model)
    if characters and type(characters.getPlayerCharacter) == "function" then
      local ok, id = pcall(characters.getPlayerCharacter)
      id = ok and tostring(id or ""):upper() or ""
      if rivalPaths[id] then return id end
    end
    local identity = tostring(model and model.player and model.player.id or "")
      :upper()
    for _, id in ipairs({ "RED", "GREEN", "BLUE" }) do
      if identity:find(id, 1, true) then return id end
    end
    return "RED"
  end

  function R.rivalCharacterId(model)
    if characters and type(characters.getRivalCharacter) == "function" then
      local ok, id = pcall(characters.getRivalCharacter)
      id = ok and tostring(id or ""):upper() or ""
      if rivalPaths[id] then return id end
    end
    local playerId = R.playerCharacterId(model)
    return ({ RED = "BLUE", GREEN = "RED", BLUE = "GREEN" })[playerId]
      or "BLUE"
  end

  local function drawLeaderCollection(model, x, y, w, h, p)
    local ids = model.leaderIds or {}
    if #ids == 0 then
      local all = cards.ui and cards.ui.badgePrimitives or {}
      local badgeOrder = {
        "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
        "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
      }
      local badgeSize = math.min(34, (w - 21) / 4)
      for index, id in ipairs(badgeOrder) do
        local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
        drawBadge(all[id], x + col * (badgeSize + 7),
          y + row * (badgeSize + 9), badgeSize, p, model.unlocked and 1 or 0.3)
      end
      return
    end
    if #ids == 1 then
      portraitPlate(leaderPortrait(ids[1], model), x, y, w, h, p,
        not model.unlocked, true)
      return
    end
    local cols = #ids > 4 and 4 or #ids
    local rows = math.ceil(#ids / cols)
    local gap = 5
    local cellW = (w - (cols - 1) * gap) / cols
    local cellH = (h - (rows - 1) * gap) / rows
    for index, id in ipairs(ids) do
      local col = (index - 1) % cols
      local row = math.floor((index - 1) / cols)
      portraitPlate(leaderPortrait(id, model), x + col * (cellW + gap),
        y + row * (cellH + gap), cellW, cellH, p, not model.unlocked, false)
    end
  end

  local function drawWorldRank(model)
    local p = materialBackdrop(model)
    local visual, rank = model.visual or {}, model.worldRank or {}
    G.setLineWidth(3)
    drawShell(visual.shell, 12, 10, 616, 380, p)
    drawFrameIdentity(model, 12, 10, 616, 380, p, false)
    color({ 0.006, 0.014, 0.025, 0.92 })
    rounded("fill", 22, 18, 596, 58, 11)
    printFit(tr("WORLD RANK TOURNAMENTS", "WELTRANG-TURNIERE"),
      36, 27, 390, 22, 13, "left", p.light)
    printFit(rank.active and tr("ACTIVE", "AKTIV")
      or rank.unlocked and tr("REGISTRATION", "ANMELDUNG")
      or tr("LOCKED", "GESPERRT"), 438, 32, 162, 13, 9, "right", p.light)

    if rank.active then
      color({ 0.006, 0.014, 0.025, 0.84 })
      rounded("fill", 24, 86, 592, 226, 12)
      printFit(rank.tournament or "TOURNAMENT", 40, 101, 370, 22, 14,
        "left", p.light)
      printFit(tr("RANK ", "RANG ") .. tostring(rank.rank or 50),
        430, 101, 166, 22, 14, "right", p.light)
      printFit(rank.opponent or "—", 40, 148, 556, 20, 12, "left",
        { 1, 1, 1, 0.96 })
      printFit(rank.location or "—", 40, 184, 556, 16, 10, "left", p.light)
      printFit(rank.rule or "", 40, 220, 556, 13, 9, "left",
        { 1, 1, 1, 0.72 })
      printFit(tr("STEPS LEFT: ", "SCHRITTE: ")
        .. tostring(rank.remainingSteps or 0), 40, 278, 556, 12, 9,
        "right", p.light)
    else
      for index, row in ipairs(rank.formats or {}) do
        local column = (index - 1) % 2
        local line = math.floor((index - 1) / 2)
        local x, y = 28 + column * 296, 88 + line * 37
        local available = row.available == true
        color(row.selected and p.dark
          or { 0.006, 0.014, 0.025, available and 0.82 or 0.5 })
        rounded("fill", x, y, 286, 30, 7)
        if row.selected then
          color(p.light, 0.9)
          rounded("line", x, y, 286, 30, 7)
        end
        printFit(row.name or row.id or "—", x + 9, y + 8, 196, 10, 8,
          "left", available and { 1, 1, 1, 0.94 }
            or { 1, 1, 1, 0.42 })
        local status = available and tr("READY", "BEREIT")
          or (row.returnsIn or 0) > 0 and tostring(row.returnsIn)
          or tr("LOCKED", "GESPERRT")
        printFit(status, x + 207, y + 8, 69, 9, 7, "right",
          available and p.light or { 1, 1, 1, 0.38 })
      end
    end
    color({ 0.006, 0.014, 0.025, 0.92 })
    rounded("fill", 22, 325, 596, 61, 10)
    printFit(tr("ITEMS ARE FORBIDDEN FOR BOTH SIDES",
      "ITEMS SIND FÜR BEIDE SEITEN VERBOTEN"),
      34, 337, 572, 10, 8, "center", p.light)
    printFit(tr("UP / DOWN  FORMAT   A  REGISTER   SELECT / B  BACK",
      "HOCH / RUNTER  FORMAT   A  ANMELDEN   SELECT / B  ZURÜCK"),
      34, 359, 572, 8, 7, "center", { 1, 1, 1, 0.72 })
    G.setLineWidth(1)
  end

  local function drawDetail(model)
    if model.worldRankOpen then return drawWorldRank(model) end
    local p = materialBackdrop(model)
    local visual = model.visual or {}
    G.setLineWidth(3)
    drawShell(visual.shell, 12, 10, 616, 380, p)
    drawFrameIdentity(model, 12, 10, 616, 380, p, false)

    color({ 0.015, 0.025, 0.04, 0.82 })
    rounded("fill", 28, 24, 584, 67, 12)
    color(p.light, 0.86)
    G.rectangle("fill", 28, 85, 584, 3)
    printFit(model.brand or "KANTO ASCENDANT", 42, 30, 390, 16, 11,
      "left", p.light)
    printFit(model.cardName or "TRAINER CARD", 42, 51, 470, 28, 16,
      "left", { 1, 1, 1, 1 })
    printFit(model.serialText or "--/50", 508, 33, 88, 18, 11,
      "right", p.light)
    printFit("COLLECTION", 508, 58, 88, 9, 7, "right",
      { 1, 1, 1, 0.62 })

    color({ 0.012, 0.022, 0.035, 0.78 })
    rounded("fill", 28, 104, 204, 222, 16)
    color(p.mid, 0.64)
    rounded("line", 28, 104, 204, 222, 16)
    color(p.mid, 0.2)
    G.circle("fill", 130, 196, 86)
    portraitPlate(playerPortrait(model), 42, 113, 176, 168, p,
      not model.unlocked, true)
    printFit(tr("TRAINER", "TRAINER"), 44, 287, 172, 9, 7, "center",
      { 1, 1, 1, 0.56 })
    printFit(model.player and model.player.name or "TRAINER", 44, 299, 172,
      19, 11, "center", { 1, 1, 1, 1 })

    color({ 0.012, 0.022, 0.035, 0.78 })
    rounded("fill", 244, 104, 368, 222, 16)
    color(p.mid, 0.64)
    rounded("line", 244, 104, 368, 222, 16)
    printFit(tr("CURRENT TITLE", "AKTUELLER TITEL"), 261, 116, 330,
      10, 8, "left", { 1, 1, 1, 0.58 })
    printFit(model.activeTitle or tr("TRAINER", "KANTO-TRAINER"), 261, 131,
      330, 24, 13, "left", p.light)
    color(p.mid, 0.5)
    G.rectangle("fill", 260, 163, 336, 2)

    local motifX, motifY, motifSize = 261, 177, 122
    color(p.dark, 0.72)
    rounded("fill", motifX, motifY, motifSize, motifSize, 14)
    color(p.mid, 0.56)
    rounded("line", motifX, motifY, motifSize, motifSize, 14)
    if not drawBadge(model.badgeIcon, motifX + 15, motifY + 15,
        motifSize - 30, p, model.unlocked and 1 or 0.3) then
      abstractMark(model, motifX + 7, motifY + 7, motifSize - 14, p,
        not model.unlocked)
    end
    printFit(visual.finish or visual.frame or "ASCENDANT", motifX + 8,
      motifY + motifSize - 20, motifSize - 16, 8, 7, "center",
      { 1, 1, 1, 0.62 })

    drawLeaderCollection(model, 397, 177, 198, 122, p)
    if model.pact then
      printFit(model.pact, 260, 304, 336, 10, 7, "center",
        { 1, 1, 1, 0.78 })
    elseif not model.unlocked then
      printFit(model.hint or tr("LOCKED", "GESPERRT"), 260, 304, 336,
        10, 7, "center", p.light)
    else
      printFit(tr("COLLECTED", "GESAMMELT"), 260, 304, 336, 9, 7,
        "center", { 1, 1, 1, 0.58 })
    end

    color({ 0.008, 0.014, 0.024, 0.84 })
    rounded("fill", 28, 338, 584, 35, 10)
    printFit(tr("START  COLLECTION   SELECT  WORLD RANK",
      "START  SAMMLUNG   SELECT  WELTRANG"),
      42, 348, 260, 11, 8, "left", { 1, 1, 1, 0.72 })
    printFit(tr("A  EQUIP     B  BACK", "A  ANLEGEN     B  ZURÜCK"),
      308, 348, 288, 11, 8, "right", p.light)
  end

  local function miniatureShell(card, x, y, w, h, p)
    local shell = card.visual and card.visual.shell or 1
    local inset = 2 + (shell % 4)
    color(p.light, card.unlocked and 0.86 or 0.24)
    if shell % 3 == 0 then
      G.polygon("line", x + 9, y, x + w - 9, y, x + w, y + 9,
        x + w, y + h - 9, x + w - 9, y + h, x + 9, y + h,
        x, y + h - 9, x, y + 9)
    else
      rounded("line", x, y, w, h, shell % 2 == 0 and 9 or 4)
    end
    color(p.mid, card.unlocked and 0.62 or 0.2)
    rounded("line", x + inset, y + inset, w - inset * 2, h - inset * 2,
      math.max(2, 7 - inset))
  end

  local function drawGalleryCard(card, x, y, w, h, activeTitle)
    local p = palette(card)
    color(p.dark, 0.96)
    rounded("fill", x, y, w, h, 6)
    if card.id == "classic_hd" then
      -- Keep the VASC Default recognisable in the collection without adding
      -- another material asset or changing any existing card shell.
      color({ 0.025, 0.16, 0.18, card.unlocked and 0.98 or 0.36 })
      rounded("fill", x + 2, y + 2, w - 4, h - 4, 5)
      color({ 0.94, 0.76, 0.31, card.unlocked and 0.92 or 0.28 })
      G.setLineWidth(card.previewed and 3 or 1.5)
      rounded("line", x + 1, y + 1, w - 2, h - 2, 6)
      G.rectangle("fill", x + 5, y + 14, w - 10, 2)
      color({ 0.04, 0.48, 0.5, card.unlocked and 0.75 or 0.22 })
      G.rectangle("fill", x + 5, y + h - 17, w - 10, 11)
    end
    local material = card.visual and materialImage(card.visual.material)
    if material and card.id ~= "classic_hd" then
      color({ 1, 1, 1, card.unlocked and 0.28 or 0.08 })
      local iw, ih = material:getDimensions()
      -- Scissors are window-space in LÖVE and would not follow drawWindow's
      -- responsive transform.  Stretching this deliberately abstract
      -- material into the miniature keeps it bounded at every HUD scale.
      G.draw(material, x, y, 0, w / iw, h / ih)
      color(p.dark, 0.52)
      rounded("fill", x, y, w, h, 6)
    end
    G.setLineWidth(card.previewed and 3 or 1.5)
    if card.id ~= "classic_hd" then
      miniatureShell(card, x + 1, y + 1, w - 2, h - 2, p)
      drawFrameIdentity(card, x + 1, y + 1, w - 2, h - 2, p, true)
    end
    if card.selected then
      color({ 0.35, 1, 0.73, 0.9 })
      G.setLineWidth(2)
      rounded("line", x + 4, y + 4, w - 8, h - 8, 4)
    end
    printFit(card.brand or "KANTO ASCENDANT", x + 7, y + 5, w - 27,
      7, 7, "left", p.light)
    printFit(card.serialText or "--/50", x + w - 28, y + 5, 22,
      7, 7, "right", { 1, 1, 1, 0.58 })
    printFit(card.cardName or "CARD", x + 7, y + 19, w - 14, 10, 7,
      "left", { 1, 1, 1, card.unlocked and 1 or 0.42 })
    if card.badgeIcon then
      drawBadge(card.badgeIcon, x + 8, y + 35, 25, p,
        card.unlocked and 0.9 or 0.2)
    else
      abstractMark(card, x + 8, y + 34, 27, p, not card.unlocked)
    end
    printFit(activeTitle or card.activeTitle or "TRAINER", x + 39, y + 39,
      w - 46, 7, 7, "left", p.light)
    printFit(card.unlocked and tr("COLLECTED", "GESAMMELT")
        or tr("LOCKED", "GESPERRT"), x + 39, y + 52, w - 46, 7, 7,
      "left", { 1, 1, 1, card.unlocked and 0.55 or 0.34 })
    G.setLineWidth(1)
  end

  local function drawGallery(model)
    local p = materialBackdrop(model)
    color({ 0.01, 0.02, 0.033, 0.91 })
    rounded("fill", 12, 10, 616, 380, 12)
    color(p.mid, 0.7)
    G.setLineWidth(2)
    rounded("line", 12, 10, 616, 380, 12)
    printFit(model.brand or "KANTO ASCENDANT", 24, 18, 350, 21, 13,
      "left", p.light)
    printFit(tr("TRAINER CARD COLLECTION", "TRAINERKARTEN-SAMMLUNG"),
      24, 42, 350, 11, 8, "left", { 1, 1, 1, 0.65 })
    printFit(tr("TITLE", "TITEL") .. ": " .. tostring(model.activeTitle or
      tr("TRAINER", "KANTO-TRAINER")), 380, 20, 228, 10, 7, "right",
      { 1, 1, 1, 0.78 })
    printFit(string.format("%s  %d/%d", model.pageId or "--", model.page or 1,
      model.pageCount or 3), 380, 41, 228, 10, 7, "right", p.light)

    local startX, startY, cellW, cellH, gapX, gapY = 18, 62, 116, 68, 7, 7
    for index, card in ipairs(model.pageCards or {}) do
      local col = (index - 1) % 5
      local row = math.floor((index - 1) / 5)
      drawGalleryCard(card, startX + col * (cellW + gapX),
        startY + row * (cellH + gapY), cellW, cellH, model.activeTitle)
    end
    color({ 0.008, 0.014, 0.024, 0.9 })
    rounded("fill", 18, 360, 604, 22, 7)
    printFit(tr("D-PAD  BROWSE    START  NEXT PAGE", "STEUERKREUZ  WÄHLEN    START  NÄCHSTE SEITE"),
      28, 366, 350, 9, 7, "left", { 1, 1, 1, 0.65 })
    printFit(tr("A  EQUIP    SELECT / B  DETAIL", "A  ANLEGEN    SELECT / B  DETAIL"),
      382, 366, 230, 9, 7, "right", p.light)
    G.setLineWidth(1)
  end

  local function drawClassic(model)
    if not (standard and type(standard.buildModel) == "function"
        and type(standard.drawLogical) == "function") then
      R.lastClassicError = "HD standard delegate unavailable"
      return false
    end
    local ok, classic = pcall(standard.buildModel, R.game or cards.game)
    if not ok or type(classic) ~= "table" then
      R.lastClassicError = tostring(classic or "HD standard model unavailable")
      return false
    end
    classic.collectionCardId = model.id
    classic.cardName = model.cardName
    classic.serialText = model.serialText
    classic.styleLabel = tr("VASC DEFAULT", "VASC-STANDARD")

    local rendered, problem = pcall(standard.drawLogical, classic)
    if not rendered then
      R.lastClassicError = tostring(problem)
      return false
    end
    R.lastClassicError = nil
    return true
  end

  function R.drawLogical(model)
    assert(G, "love.graphics is unavailable")
    model = model or cards.model(R.game)
    color({ 0, 0, 0, 1 })
    G.rectangle("fill", 0, 0, R.width, R.height)
    if model.galleryOpen then
      drawGallery(model)
    elseif model.id == "classic_hd" and not model.worldRankOpen
        and drawClassic(model) then
      -- The exact published Gold/Teal renderer owns VASC Default.
    else
      drawDetail(model)
    end
    color({ 1, 1, 1, 1 })
    return model
  end

  local function viewportSize(viewport)
    local width, height
    if type(viewport) == "table" then
      width, height = tonumber(viewport.width), tonumber(viewport.height)
    end
    if (not width or not height) and G and G.getDimensions then
      width, height = G.getDimensions()
    end
    return math.max(1, width or R.width), math.max(1, height or R.height)
  end

  function R.drawWindow(model, viewport)
    assert(G, "love.graphics is unavailable")
    local windowW, windowH = viewportSize(viewport)
    local scale = math.min(windowW / R.width, windowH / R.height)
    local x = (windowW - R.width * scale) / 2
    local y = (windowH - R.height * scale) / 2
    color({ 0, 0, 0, 1 })
    G.rectangle("fill", 0, 0, windowW, windowH)
    withGraphicsState(nil, function()
      G.translate(x, y)
      G.scale(scale, scale)
      R.drawLogical(model)
    end)
    return { x = x, y = y, width = R.width * scale,
      height = R.height * scale, scale = scale }
  end

  local function popCard(state)
    cards.toggleGallery(false)
    local game = state and state.game
    if game and game.stack and type(game.stack.pop) == "function" then
      game.stack:pop()
    end
    if state and type(state.onCancel) == "function" then state.onCancel() end
  end

  function R.newScreen(game, screenOpts)
    local Vanilla = require("src.ui.TrainerCard")
    local state = Vanilla.new(game, screenOpts or {})
    local nativeDraw = state.draw
    local nativeEnter = state.enter
    local nativeExit = state.exit
    state[R.marker] = true
    state.isOpaque = true
    -- A shader-free zone stops Game's palette search at this top state and
    -- survives OG/CLASSIC palette normalisation.  An empty table can be
    -- expanded into a full-screen four-colour zone by PaletteFX.ensureZones.
    state.sgbPalettes = function()
      return { { colors = false, x = 0, y = 0, w = R.width, h = R.height } }
    end

    function state:uiSize() return R.width, R.height end
    function state:enter()
      if type(nativeEnter) == "function" then nativeEnter(self) end
      self[R.modelKey] = cards.begin(self.game)
    end
    function state:exit()
      cards.toggleGallery(false)
      self[R.modelKey] = nil
      if type(nativeExit) == "function" then nativeExit(self) end
    end
    function state:draw()
      local renderModel = self[R.modelKey] or cards.model(self.game)
      self[R.modelKey] = renderModel
      local ok, err = pcall(R.drawLogical, renderModel)
      if ok then R.lastError = nil; return end
      R.lastError = tostring(err)
      if standard and type(standard.buildModel) == "function"
          and type(standard.drawLogical) == "function" then
        local fallbackOk, fallbackErr = pcall(function()
          local fallbackModel = standard.buildModel(self.game, self)
          self[standard.modelKey] = fallbackModel
          standard.drawLogical(fallbackModel)
        end)
        if fallbackOk then return end
        R.lastError = R.lastError .. " | HD standard fallback: "
          .. tostring(fallbackErr)
      end
      if type(nativeDraw) == "function" then
        local fallbackOk, fallbackErr = pcall(withGraphicsState, nil,
          function()
            local scale = math.min(R.width / 160, R.height / 144)
            G.translate((R.width - 160 * scale) / 2,
              (R.height - 144 * scale) / 2)
            G.scale(scale, scale)
            nativeDraw(self)
          end)
        if not fallbackOk then
          R.lastError = R.lastError .. " | native fallback: "
            .. tostring(fallbackErr)
        end
      end
    end
    function state:update()
      local input = self.game and self.game.input
      if not (input and type(input.wasPressed) == "function") then return end
      local model = self[R.modelKey] or cards.model(self.game)
      local updated
      if model.worldRankOpen then
        if input:wasPressed("up") then
          updated = cards.moveWorldRank(-1, self.game)
        elseif input:wasPressed("down") then
          updated = cards.moveWorldRank(1, self.game)
        elseif input:wasPressed("a") then
          local _, _, value = cards.registerWorldRank(self.game)
          updated = value or cards.model(self.game)
        elseif input:wasPressed("select") or input:wasPressed("b") then
          local _, value = cards.toggleWorldRank(false, self.game)
          updated = value
        elseif input:wasPressed("start") then
          cards.toggleWorldRank(false, self.game)
          local _, value = cards.toggleGallery(true)
          updated = value
        end
      elseif model.galleryOpen then
        if input:wasPressed("left") then updated = cards.move(-1)
        elseif input:wasPressed("right") then updated = cards.move(1)
        elseif input:wasPressed("up") then updated = cards.move(-5)
        elseif input:wasPressed("down") then updated = cards.move(5)
        elseif input:wasPressed("start") then updated = cards.page(1)
        elseif input:wasPressed("select") or input:wasPressed("b") then
          local _, value = cards.toggleGallery(false)
          updated = value
        elseif input:wasPressed("a") then
          if cards.select(model.id, self.game) then
            local _, value = cards.toggleGallery(false)
            updated = value
          end
        end
      else
        if input:wasPressed("left") then updated = cards.move(-1)
        elseif input:wasPressed("right") then updated = cards.move(1)
        elseif input:wasPressed("up") then updated = cards.move(-5)
        elseif input:wasPressed("down") then updated = cards.move(5)
        elseif input:wasPressed("select") then
          local _, value = cards.toggleWorldRank(true, self.game)
          updated = value
        elseif input:wasPressed("start") then
          local _, value = cards.toggleGallery(true)
          updated = value
        elseif input:wasPressed("a") then
          if cards.select(model.id, self.game) then
            updated = cards.model(self.game)
          end
        elseif input:wasPressed("b") then popCard(self); return end
      end
      if updated then self[R.modelKey] = updated end
    end
    return state
  end

  local function topTrainerCard(game)
    local stack = game and game.stack
    local top = stack and type(stack.top) == "function" and stack:top()
    if not top or top.screenId ~= "TrainerCard" or not top[R.marker] then
      return nil
    end
    return top
  end

  if not standard and mod.content and mod.content.screens
      and type(mod.content.screens.override) == "function" then
    mod.content.screens:override("TrainerCard", { new = R.newScreen })
    R.screenRegistered = true
  end

  if not standard and mod.hooks and type(mod.hooks.wrap) == "function" then
    R.unsubscribe = mod.hooks:wrap("render.hud",
      function(nextHud, game, viewport)
        nextHud(game, viewport)
        local top = topTrainerCard(game)
        if not top or not G then return end
        local ok, err = pcall(withGraphicsState, "all", function()
          if G.setCanvas then G.setCanvas() end
          if G.origin then G.origin() end
          if G.setScissor then G.setScissor() end
          if G.setShader then G.setShader() end
          if G.setBlendMode then G.setBlendMode("alpha") end
          R.game = game
          local renderModel = top[R.modelKey] or cards.model(game)
          top[R.modelKey] = renderModel
          R.drawWindow(renderModel, viewport)
        end)
        if ok then R.lastError = nil else R.lastError = tostring(err) end
      end, 125)
    R.hudRegistered = true
  end

  function R.install(game)
    R.game = game
    if cards.game ~= game and type(cards.install) == "function" then
      cards.install(game)
    end
    return R
  end

  if standard then
    assert(type(standard.setCollectionRenderer) == "function",
      "HD standard Trainer Card owner cannot host collection renderer")
    standard.setCollectionRenderer(R)
  end

  R.draw = R.drawLogical
  R.drawCollection = R.drawLogical
  R.portraitPolicy = {
    sourcePixels = 128,
    collectionAlwaysHd = true,
    -- A save without Ascendant character state normalises read-only to RED.
    -- This deliberately gives fresh Yellow and ORIGINAL-style saves the
    -- approved 128px Red master on this new card surface; no character or
    -- edition state is written or changed.
    unselectedYellow = "RED",
    ignoresCompactTrainerCardStyle = true,
    standardFallback = standard ~= nil,
  }
  R.classicPolicy = {
    id = "classic_hd",
    source = "trainer_card_hd_standard",
    sides = { "front" },
    controls = { browse = "d-pad", equip = "a" },
  }
  return R
end
