-- Window-resolution replacement for the single native Trainer Card.
--
-- The engine still owns input, dismissal and the 160x144 native fallback.
-- Kanto Ascendant only replaces the final presentation in render.hud, where
-- the card can use the actual window resolution, 128px portraits and vector
-- badges without first destroying detail on the Game Boy canvas.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local characters = opts.extendedCharacters or opts.characters
  local legacyHall = opts.legacyHall
  local R = {
    width = 640,
    height = 400,
    marker = "__kantoAscendantHdStandardTrainerCard",
    modelKey = "__kantoAscendantHdStandardTrainerCardModel",
    lastError = nil,
  }

  local G = love and love.graphics
  local cache = { fonts = {}, images = {}, leaderQuads = {} }
  local PLAYER_PORTRAITS = {
    RED = "assets/characters/crystal_chars/red_voxel_front_hd.png",
    GREEN = "assets/characters/crystal_chars/green_voxel_front_hd.png",
    BLUE = "assets/characters/crystal_chars/blue_voxel_front_hd.png",
  }
  local LEADERS = {
    {
      id = "BROCK", badge = "BOULDERBADGE", name = { "BROCK", "ROCKO" },
      path = "assets/characters/frlg_trainers/leader_brock_voxel_front_hd_v2.png",
    },
    {
      id = "MISTY", badge = "CASCADEBADGE", name = { "MISTY", "MISTY" },
      path = "assets/characters/frlg_trainers/leader_misty_voxel_front_hd_v2.png",
    },
    {
      id = "SURGE", badge = "THUNDERBADGE", name = { "SURGE", "MAJOR BOB" },
      path = "assets/characters/frlg_trainers/leader_lt_surge_voxel_front_hd_v2.png",
    },
    {
      id = "ERIKA", badge = "RAINBOWBADGE", name = { "ERIKA", "ERIKA" },
      path = "assets/characters/frlg_trainers/leader_erika_voxel_front_hd_v2.png",
    },
    {
      id = "KOGA", badge = "SOULBADGE", name = { "KOGA", "KOGA" },
      path = "assets/characters/frlg_trainers/leader_koga_voxel_front_hd_v2.png",
    },
    {
      id = "SABRINA", badge = "MARSHBADGE", name = { "SABRINA", "SABRINA" },
      path = "assets/characters/frlg_trainers/leader_sabrina_voxel_front_hd_v2.png",
    },
    {
      id = "BLAINE", badge = "VOLCANOBADGE", name = { "BLAINE", "PYRO" },
      path = "assets/characters/frlg_trainers/leader_blaine_voxel_front_hd_v2.png",
    },
    {
      id = "GIOVANNI", badge = "EARTHBADGE", name = { "GIOVANNI", "GIOVANNI" },
      path = "assets/characters/frlg_trainers/leader_giovanni_voxel_front_hd_v2.png",
    },
  }
  local GIOVANNI_VICTORY_FLAGS = {
    "EVENT_BEAT_GIOVANNI",
    "EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI",
  }

  local COLORS = {
    ink = { 0.018, 0.027, 0.043, 1 },
    panel = { 0.025, 0.052, 0.078, 0.94 },
    panelSoft = { 0.04, 0.086, 0.12, 0.92 },
    gold = { 0.94, 0.78, 0.34, 1 },
    goldSoft = { 0.79, 0.61, 0.22, 1 },
    teal = { 0.13, 0.73, 0.72, 1 },
    tealSoft = { 0.08, 0.43, 0.46, 1 },
    white = { 0.95, 0.975, 0.99, 1 },
    muted = { 0.62, 0.69, 0.73, 1 },
  }

  local function tr(english, german)
    if i18n and type(i18n.text) == "function" then
      local ok, value = pcall(i18n.text, english, german)
      if ok and type(value) == "string" and value ~= "" then return value end
    end
    return english
  end

  local function setColor(value, alpha)
    value = type(value) == "table" and value or COLORS.white
    G.setColor(value[1] or 1, value[2] or 1, value[3] or 1,
      alpha == nil and (value[4] or 1) or alpha)
  end

  local function withGraphicsState(mode, body)
    local pushed = false
    if mode then pushed = pcall(G.push, mode) end
    if not pushed then G.push() end
    local ok, first, second = pcall(body)
    G.pop()
    if not ok then error(first, 0) end
    return first, second
  end

  local function rounded(mode, x, y, width, height, radius)
    G.rectangle(mode, x, y, width, height, radius or 0, radius or 0)
  end

  local function font(size)
    size = math.max(7, math.floor(tonumber(size) or 12))
    if cache.fonts[size] then return cache.fonts[size] end
    if not (G and type(G.newFont) == "function") then return nil end
    local ok, value = pcall(G.newFont, size)
    if not ok then return nil end
    if type(value.setFilter) == "function" then
      value:setFilter("linear", "linear")
    end
    cache.fonts[size] = value
    return value
  end

  local function fittedFont(text, maximum, preferred, minimum)
    text = tostring(text or "")
    for size = preferred, minimum or 7, -1 do
      local candidate = font(size)
      if candidate and candidate:getWidth(text) <= maximum then
        return candidate
      end
    end
    return font(minimum or 7)
  end

  local function printFit(text, x, y, width, preferred, minimum, align, color)
    text = tostring(text or ""):gsub("[\r\n\t]+", " ")
      :gsub("  +", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local selected = fittedFont(text, width, preferred, minimum)
    if not selected then return end
    local natural = math.max(0, selected:getWidth(text))
    local scaleX = natural > width and width / natural or 1
    local drawX = x
    if align == "right" then
      drawX = x + width - natural * scaleX
    elseif align == "center" then
      drawX = x + (width - natural * scaleX) / 2
    end
    G.setFont(selected)
    setColor(color or COLORS.white)
    withGraphicsState(nil, function()
      G.translate(drawX, y)
      G.scale(scaleX, 1)
      G.print(text, 0, 0)
    end)
  end

  local function ownImage(path)
    if type(path) ~= "string" or path == "" or not G then return nil end
    if cache.images[path] ~= nil then return cache.images[path] or nil end
    local ok, image
    if mod.assets and type(mod.assets.image) == "function" then
      ok, image = pcall(mod.assets.image, mod.assets, path)
    else
      ok, image = pcall(G.newImage, (mod.path or "") .. "/" .. path)
    end
    if not ok then image = nil end
    if image and type(image.setFilter) == "function" then
      image:setFilter("nearest", "nearest")
    end
    cache.images[path] = image or false
    return image
  end

  local function drawContain(image, x, y, width, height, alpha)
    if not image or type(image.getDimensions) ~= "function" then return false end
    local imageWidth, imageHeight = image:getDimensions()
    if imageWidth <= 0 or imageHeight <= 0 then return false end
    local scale = math.min(width / imageWidth, height / imageHeight)
    setColor(COLORS.white, alpha or 1)
    G.draw(image, math.floor(x + (width - imageWidth * scale) / 2),
      math.floor(y + (height - imageHeight * scale) / 2), 0, scale, scale)
    return true
  end

  local function drawLeaderBust(entry, x, y, width, height, alpha)
    local image = entry and entry.portrait
    if not image or type(image.getDimensions) ~= "function" then return false end
    local imageWidth, imageHeight = image:getDimensions()
    if imageWidth <= 0 or imageHeight <= 0 then return false end
    local key = tostring(entry.path or entry.id or image)
    local quad = cache.leaderQuads[key]
    local cropWidth = math.max(1, math.floor(imageWidth * 0.58))
    local cropHeight = math.max(1, math.floor(imageHeight * 0.59))
    local cropX = math.floor((imageWidth - cropWidth) / 2)
    local cropY = math.max(0, math.floor(imageHeight * 0.025))
    if quad == nil and type(G.newQuad) == "function" then
      local ok, value = pcall(G.newQuad, cropX, cropY, cropWidth, cropHeight,
        imageWidth, imageHeight)
      quad = ok and value or false
      cache.leaderQuads[key] = quad
    end
    if not quad then
      return drawContain(image, x, y, width, height, alpha)
    end
    local scale = math.min(width / cropWidth, height / cropHeight)
    if entry.hidden then
      setColor({ 0, 0, 0, 1 }, 0.98)
    else
      setColor(COLORS.white, alpha or 1)
    end
    G.draw(image, quad,
      math.floor(x + (width - cropWidth * scale) / 2),
      math.floor(y + (height - cropHeight * scale) / 2), 0, scale, scale)
    return true
  end

  local function playerIdentity(model)
    if characters and type(characters.getPlayerCharacter) == "function" then
      local ok, value = pcall(characters.getPlayerCharacter)
      value = ok and tostring(value or ""):upper() or ""
      if PLAYER_PORTRAITS[value] then return value end
    end
    local name = tostring(model and model.name or ""):upper()
    for _, id in ipairs({ "GREEN", "BLUE", "RED" }) do
      if name:find(id, 1, true) then return id end
    end
    -- Yellow's native protagonist is Red-shaped and has no separate 128px
    -- master in the supported asset set.  This is presentation-only and does
    -- not create or change Ascendant character-selection state.
    return "RED"
  end

  local function currentTitle()
    if legacyHall and type(legacyHall.currentTitle) == "function" then
      local ok, _, name = pcall(legacyHall.currentTitle)
      if ok and type(name) == "string" and name ~= "" then return name end
    end
    return tr("NO ACTIVE TITLE", "KEIN AKTIVER TITEL")
  end

  local function currentPact(save)
    if legacyHall and type(legacyHall.pactCardText) == "function" then
      local ok, value = pcall(legacyHall.pactCardText, save)
      if ok and type(value) == "string" and value ~= "" then return value end
    end
    return nil
  end

  local function editionName()
    local ok, GameVersion = pcall(require, "src.core.GameVersion")
    local value = ok and GameVersion and type(GameVersion.get) == "function"
      and GameVersion.get() or "red"
    value = tostring(value or "red"):upper()
    if value == "YELLOW" then return tr("YELLOW", "GELB") end
    if value == "BLUE" then return tr("BLUE", "BLAU") end
    return tr("RED", "ROT")
  end

  local function badgeState(game)
    local result, ownedCount = {}, 0
    local ok, Badges = pcall(require, "src.inventory.Badges")
    local list = ok and Badges and type(Badges.list) == "function"
      and Badges.list(game and game.data) or {}
    local inventory = game and game.save and game.save.inventory or {}
    local flags = game and game.save and game.save.flags or {}
    local byId = {}
    for _, entry in ipairs(list) do
      if type(entry) == "table" and entry.id ~= nil then
        byId[tostring(entry.id):upper()] = entry
      end
    end
    for index, leader in ipairs(LEADERS) do
      local entry = byId[leader.badge]
      local item = entry and type(Badges.itemFor) == "function"
        and Badges.itemFor(entry) or nil
      local owned = item ~= nil and not not inventory[item]
      if owned then ownedCount = ownedCount + 1 end
      local defeated = leader.id ~= "GIOVANNI"
        or flags[GIOVANNI_VICTORY_FLAGS[1]] == true
        or flags[GIOVANNI_VICTORY_FLAGS[2]] == true
      result[index] = {
        id = leader.id,
        name = tr(leader.name[1], leader.name[2]),
        path = leader.path,
        portrait = ownImage(leader.path),
        owned = owned,
        hidden = not defeated,
      }
    end
    return result, ownedCount
  end

  function R.buildModel(game, card)
    local save = game and game.save or {}
    local player = save.player or {}
    local playTime = math.max(0, math.floor(tonumber(save.playTime) or 0))
    local model = {
      brand = "KANTO ASCENDANT",
      cardLabel = tr("TRAINER CARD", "TRAINERKARTE"),
      name = tostring(player.name or "RED"),
      money = math.max(0, math.floor(tonumber(save.money) or 0)),
      hours = math.floor(playTime / 3600),
      minutes = math.floor(playTime / 60) % 60,
      title = currentTitle(),
      pact = currentPact(save),
      edition = editionName(),
      styleLabel = tr("HD STANDARD", "HD-STANDARD"),
      nativePortrait = card and card.pic or nil,
    }
    local identity = playerIdentity(model)
    model.identity = identity
    model.portraitPath = PLAYER_PORTRAITS[identity]
    model.portrait = ownImage(model.portraitPath)
    model.badges, model.badgesOwned = badgeState(game)
    return model
  end

  local function drawBackdrop()
    setColor({ 0.018, 0.04, 0.075, 1 })
    G.rectangle("fill", 0, 0, R.width, R.height)
    setColor({ 0.075, 0.19, 0.27, 0.28 })
    for offset = -R.height, R.width, 54 do
      G.polygon("fill", offset, 0, offset + 18, 0,
        offset + R.height + 18, R.height, offset + R.height, R.height)
    end
    setColor({ 0.15, 0.8, 0.74, 0.08 })
    G.circle("fill", 570, 52, 170)
    setColor({ 0.95, 0.75, 0.26, 0.06 })
    G.circle("fill", 76, 350, 185)
  end

  local BADGE_BASE = {
    { 0.56, 0.59, 0.62 }, { 0.12, 0.62, 0.86 },
    { 0.98, 0.72, 0.08 }, { 0.42, 0.76, 0.35 },
    { 0.78, 0.23, 0.58 }, { 0.93, 0.66, 0.13 },
    { 0.9, 0.2, 0.14 }, { 0.12, 0.58, 0.31 },
  }

  local function drawBadge(index, x, y, size, alpha)
    local base = BADGE_BASE[index] or BADGE_BASE[1]
    alpha = alpha or 1
    withGraphicsState(nil, function()
      G.translate(x, y)
      G.scale(size / 100, size / 100)
      setColor({ 0.005, 0.012, 0.02, 1 }, 0.9 * alpha)
      G.circle("fill", 50, 52, 45)
      setColor({ base[1], base[2], base[3], 1 }, alpha)
      if index == 1 then
        G.polygon("fill", 13, 55, 28, 20, 67, 13, 88, 49, 68, 86, 29, 80)
        setColor({ 0.84, 0.87, 0.9, 1 }, 0.65 * alpha)
        G.polygon("fill", 28, 20, 67, 13, 51, 49)
      elseif index == 2 then
        G.circle("fill", 50, 56, 31)
        G.polygon("fill", 50, 6, 76, 56, 24, 56)
        setColor(COLORS.white, 0.62 * alpha)
        G.ellipse("fill", 43, 38, 8, 17)
      elseif index == 3 then
        for spoke = 0, 7 do
          local angle = spoke * math.pi / 4
          G.rectangle("fill", 46 + math.cos(angle) * 34,
            46 + math.sin(angle) * 34, 9, 9)
        end
        G.circle("fill", 50, 50, 28)
        setColor({ 1, 0.96, 0.42, 1 }, alpha)
        G.polygon("fill", 55, 17, 31, 54, 49, 54, 40, 85, 72, 43, 54, 43)
      elseif index == 4 then
        local petals = {
          { 0.9, 0.18, 0.32 }, { 0.98, 0.56, 0.16 },
          { 0.98, 0.88, 0.28 }, { 0.36, 0.75, 0.24 },
          { 0.15, 0.72, 0.78 }, { 0.18, 0.45, 0.82 },
          { 0.66, 0.27, 0.72 }, { 0.9, 0.35, 0.63 },
        }
        for petal = 1, 8 do
          local angle = (petal - 1) * math.pi / 4
          local c = petals[petal]
          setColor({ c[1], c[2], c[3], 1 }, alpha)
          G.circle("fill", 50 + math.cos(angle) * 25,
            50 + math.sin(angle) * 25, 17)
        end
        setColor(COLORS.white, 0.9 * alpha)
        G.circle("fill", 50, 50, 15)
      elseif index == 5 then
        G.polygon("fill", 50, 9, 62, 31, 88, 27, 72, 51, 86, 77,
          58, 69, 50, 92, 42, 69, 14, 77, 28, 51, 12, 27, 38, 31)
        setColor({ 0.98, 0.66, 0.86, 1 }, 0.82 * alpha)
        G.circle("fill", 50, 50, 18)
      elseif index == 6 then
        G.circle("fill", 50, 50, 39)
        setColor({ 1, 0.91, 0.35, 1 }, alpha)
        G.circle("fill", 50, 50, 27)
        setColor({ 0.98, 0.69, 0.12, 1 }, alpha)
        G.circle("fill", 50, 50, 15)
      elseif index == 7 then
        G.polygon("fill", 50, 5, 88, 50, 50, 95, 12, 50)
        setColor({ 1, 0.43, 0.15, 1 }, alpha)
        G.polygon("fill", 51, 24, 71, 58, 54, 81, 31, 59)
        setColor({ 1, 0.76, 0.43, 1 }, alpha)
        G.polygon("fill", 51, 39, 59, 59, 50, 70, 43, 57)
      else
        G.polygon("fill", 29, 8, 71, 8, 92, 29, 92, 71, 71, 92,
          29, 92, 8, 71, 8, 29)
        setColor({ 0.64, 0.84, 0.27, 1 }, alpha)
        G.polygon("fill", 50, 23, 72, 50, 50, 77, 28, 50)
        setColor({ 0.86, 0.94, 0.53, 1 }, alpha)
        G.polygon("fill", 50, 31, 50, 50, 37, 50)
      end
      setColor(COLORS.white, 0.28 * alpha)
      G.setLineWidth(2)
      G.circle("line", 50, 50, 46)
    end)
    G.setLineWidth(1)
  end

  local function drawLeaderTile(entry, index, x, y, width, height)
    setColor(COLORS.panelSoft, entry.owned and 0.96 or 0.72)
    rounded("fill", x, y, width, height, 8)
    setColor(entry.owned and COLORS.gold or COLORS.tealSoft,
      entry.owned and 0.9 or 0.55)
    G.setLineWidth(entry.owned and 2 or 1)
    rounded("line", x, y, width, height, 8)

    local shown = drawLeaderBust(entry, x + 4, y + 3, 43, height - 6,
      entry.owned and 1 or 0.72)
    if not shown then
      setColor(COLORS.tealSoft, 0.5)
      G.circle("fill", x + 25, y + 18, 8)
      rounded("fill", x + 15, y + 28, 20, 15, 4)
    end
    printFit(('%02d'):format(index), x + 48, y + 4, width - 54,
      9, 7, "center", entry.owned and COLORS.gold or COLORS.muted)
    drawBadge(index, x + width - 28, y + height - 29, 24,
      entry.owned and 1 or 0.23)
    G.setLineWidth(1)
  end

  local function drawCard(model)
    drawBackdrop()
    setColor({ 0, 0, 0, 0.55 })
    rounded("fill", 22, 20, 604, 372, 28)
    setColor(COLORS.gold)
    G.setLineWidth(4)
    rounded("line", 16, 12, 608, 376, 30)
    setColor(COLORS.teal)
    G.setLineWidth(3)
    rounded("line", 24, 20, 592, 360, 24)
    setColor(COLORS.ink, 0.97)
    rounded("fill", 30, 26, 580, 348, 18)

    -- Header.
    setColor(COLORS.panel)
    rounded("fill", 40, 34, 560, 61, 11)
    setColor(COLORS.gold)
    G.rectangle("fill", 40, 89, 560, 3)
    printFit(model.brand, 54, 40, 370, 15, 10, "left", COLORS.gold)
    printFit(model.cardLabel, 54, 58, 410, 27, 17, "left", COLORS.white)
    printFit(model.edition, 473, 42, 108, 13, 9, "right", COLORS.teal)
    printFit(model.styleLabel, 473, 62, 108, 10, 8, "right", COLORS.muted)

    -- Player identity.
    setColor(COLORS.panel)
    rounded("fill", 40, 106, 184, 245, 15)
    setColor(COLORS.teal, 0.78)
    G.setLineWidth(2)
    rounded("line", 40, 106, 184, 245, 15)
    setColor(COLORS.tealSoft, 0.2)
    G.circle("fill", 132, 205, 80)
    local shown = drawContain(model.portrait, 51, 116, 162, 170, 1)
    if not shown then shown = drawContain(model.nativePortrait, 51, 116, 162, 170, 1) end
    if not shown then
      setColor(COLORS.tealSoft, 0.55)
      G.circle("fill", 132, 172, 28)
      rounded("fill", 91, 215, 82, 61, 18)
    end
    printFit(tr("TRAINER", "TRAINER"), 54, 296, 156, 9, 7,
      "center", COLORS.muted)
    printFit(model.name, 54, 310, 156, 21, 12, "center", COLORS.white)
    printFit(model.identity, 54, 335, 156, 9, 7, "center", COLORS.teal)

    -- Current title and native card values.
    setColor(COLORS.panel)
    rounded("fill", 238, 106, 362, 94, 15)
    setColor(COLORS.teal, 0.72)
    G.setLineWidth(2)
    rounded("line", 238, 106, 362, 94, 15)
    printFit(tr("CURRENT TITLE", "AKTUELLER TITEL"), 254, 116, 330,
      10, 8, "left", COLORS.muted)
    printFit(model.title, 254, 132, 330, 25, 12, "left", COLORS.gold)
    setColor(COLORS.tealSoft, 0.68)
    G.rectangle("fill", 254, 163, 330, 2)
    printFit(tr("MONEY", "GELD"), 254, 172, 62, 9, 7, "left", COLORS.muted)
    printFit(("¥%d"):format(model.money), 308, 170, 112, 13, 9,
      "left", COLORS.white)
    printFit(tr("PLAY TIME", "SPIELZEIT"), 427, 172, 82, 9, 7,
      "left", COLORS.muted)
    printFit(("%d:%02d"):format(model.hours, model.minutes), 510, 170,
      73, 13, 9, "right", COLORS.white)

    -- Eight HD leader portraits with vector badge overlays.
    setColor(COLORS.panel)
    rounded("fill", 238, 212, 362, 139, 15)
    setColor(COLORS.teal, 0.72)
    G.setLineWidth(2)
    rounded("line", 238, 212, 362, 139, 15)
    printFit(tr("KANTO BADGES", "KANTO-ORDEN"), 252, 220, 220,
      11, 8, "left", COLORS.muted)
    printFit(("%d / 8"):format(model.badgesOwned or 0), 500, 220, 84,
      12, 8, "right", COLORS.gold)
    local startX, startY, cellW, cellH, gapX, gapY = 252, 239, 78, 48, 6, 6
    for index, entry in ipairs(model.badges or {}) do
      local column = (index - 1) % 4
      local row = math.floor((index - 1) / 4)
      drawLeaderTile(entry, index, startX + column * (cellW + gapX),
        startY + row * (cellH + gapY), cellW, cellH)
    end

    setColor(COLORS.panel, 0.92)
    rounded("fill", 40, 360, 560, 10, 5)
    setColor(COLORS.gold)
    G.circle("fill", 286, 365, 3)
    G.circle("fill", 354, 365, 3)
    if model.pact then
      printFit(model.pact, 54, 355, 220, 10, 8, "left", COLORS.gold)
    end
    printFit(tr("A / B  BACK", "A / B  ZURÜCK"), 375, 355, 210,
      10, 8, "right", COLORS.muted)
    G.setLineWidth(1)
    setColor(COLORS.white)
  end

  function R.drawLogical(model)
    assert(G, "love.graphics is unavailable")
    drawCard(assert(model, "trainer card model is required"))
    return model
  end

  local function viewportSize(viewport)
    local width = type(viewport) == "table" and tonumber(viewport.width) or nil
    local height = type(viewport) == "table" and tonumber(viewport.height) or nil
    if (not width or not height) and G and type(G.getDimensions) == "function" then
      width, height = G.getDimensions()
    end
    return math.max(1, width or R.width), math.max(1, height or R.height)
  end

  function R.drawWindow(model, viewport)
    assert(G, "love.graphics is unavailable")
    local windowWidth, windowHeight = viewportSize(viewport)
    local scale = math.min(windowWidth / R.width, windowHeight / R.height)
    local x = (windowWidth - R.width * scale) / 2
    local y = (windowHeight - R.height * scale) / 2
    local canvasWidth = math.max(1, math.floor(windowWidth + 0.5))
    local canvasHeight = math.max(1, math.floor(windowHeight + 0.5))
    local canvasSupported = type(G.newCanvas) == "function"
    local sameSurfaceSize = cache.surfaceWidth == canvasWidth
      and cache.surfaceHeight == canvasHeight
    local surface = sameSurfaceSize and cache.surface or nil
    if not sameSurfaceSize and canvasSupported then
      local previous = cache.surface
      if previous and type(previous.release) == "function" then
        pcall(previous.release, previous)
      end
      local ok, value = pcall(G.newCanvas, canvasWidth, canvasHeight)
      surface = ok and value or false
      cache.surface = surface
      cache.surfaceError = ok and nil or tostring(value)
      cache.surfaceWidth, cache.surfaceHeight = canvasWidth, canvasHeight
    end

    local function paint()
      setColor({ 0, 0, 0, 1 })
      G.rectangle("fill", 0, 0, windowWidth, windowHeight)
      withGraphicsState("all", function()
        if G.setScissor then
          local left, top = math.floor(x), math.floor(y)
          local right = math.ceil(x + R.width * scale)
          local bottom = math.ceil(y + R.height * scale)
          G.setScissor(left, top, right - left, bottom - top)
        end
        G.translate(x, y)
        G.scale(scale, scale)
        R.drawLogical(model)
      end)
    end

    if surface then
      -- Compose atomically.  If any asset or draw call fails, the exception
      -- escapes before this private surface reaches the real window and the
      -- engine's native Trainer Card remains visible as the fallback.
      withGraphicsState("all", function()
        G.setCanvas(surface)
        if G.origin then G.origin() end
        if G.setScissor then G.setScissor() end
        if G.setShader then G.setShader() end
        if G.setBlendMode then G.setBlendMode("alpha") end
        if G.clear then G.clear(0, 0, 0, 0) end
        paint()
      end)
      setColor(COLORS.white)
      G.draw(surface, 0, 0)
    elseif canvasSupported then
      error("HD Trainer Card surface unavailable: "
        .. tostring(cache.surfaceError or "unknown Canvas error"), 0)
    else
      -- Exact supported clients provide Canvas.  This direct path keeps the
      -- pure-Lua SDK harness useful without adding a second renderer.
      paint()
    end
    return { x = x, y = y, width = R.width * scale,
      height = R.height * scale, scale = scale }
  end

  local function topCard(game)
    local stack = game and game.stack
    local top = stack and type(stack.top) == "function" and stack:top() or nil
    return top and top[R.marker] == true and top or nil
  end

  function R.newScreen(game, screenOptions)
    local TrainerCard = require("src.ui.TrainerCard")
    local state = TrainerCard.new(game, screenOptions or {})
    state[R.marker] = true
    return state
  end

  if mod.content and mod.content.screens
      and type(mod.content.screens.override) == "function" then
    mod.content.screens:override("TrainerCard", { new = R.newScreen })
    R.screenRegistered = true
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    R.unsubscribe = mod.hooks:wrap("render.hud", function(nextHud, game, viewport)
      nextHud(game, viewport)
      local state = topCard(game)
      if not state or not G then return end
      local ok, problem = pcall(withGraphicsState, "all", function()
        if G.setCanvas then G.setCanvas() end
        if G.origin then G.origin() end
        if G.setScissor then G.setScissor() end
        if G.setShader then G.setShader() end
        if G.setBlendMode then G.setBlendMode("alpha") end
        -- Match the native card's live values: play time and any title/pact
        -- authority changes must not freeze at the first presented frame.
        local model = R.buildModel(game, state)
        state[R.modelKey] = model
        R.drawWindow(model, viewport)
      end)
      if ok then R.lastError = nil else R.lastError = tostring(problem) end
    end, 125)
    R.hudRegistered = true
  end

  function R.install(game)
    R.game = game
    return R
  end

  R.assetPolicy = {
    playerSourcePixels = 128,
    leaderSourcePixels = 128,
    playerPortraits = PLAYER_PORTRAITS,
    leaders = LEADERS,
    giovanniRevealFlags = GIOVANNI_VICTORY_FLAGS,
    nativeCardIsFallbackOnly = true,
  }

  return R
end
