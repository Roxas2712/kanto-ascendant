-- Kanto Ascendant title presentation.
--
-- Red/Blue's title screen already composes a trainer and a Pokemon beside one
-- another and owns the complete edition-specific Pokemon rotation.  Preserve
-- that native list and selection unchanged.  Ascendant rotates Green, Blue and
-- Red exactly once on each real Pokemon-change edge, then publishes the two
-- visible identities together before the next draw.  Unrelated timer resets
-- can never rotate a trainer by themselves.  This is presentation-only and
-- never reads or writes the selected character in a save.

return function(mod, characters)
  local TitleState = require("src.ui.TitleState")
  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local GameVersion = require("src.core.GameVersion")
  local Logger = require("src.core.Logger")
  local M = {
    order = { "GREEN", "BLUE", "RED" },
    owner = "kasc.title-intro-static-compositor",
    animationOwner = "kasc.animated-title-core-prep/v1",
  }
  local trainerAnimation
  local trainerAnimationFailed = false
  local visualThemes

  -- The optional 6.6 preparation Card gets one deliberately narrow adapter.
  -- TitleState remains the sole compositor owner, and no presentation-registry
  -- or species-pool seam is exposed here.
  function M.setTrainerAnimation(controller)
    trainerAnimation = controller
    trainerAnimationFailed = false
    return controller ~= nil
  end

  -- The visual-theme Card owns only a defensive palette transform. This
  -- adapter deliberately shares no trainer, draw, input or music authority.
  function M.setVisualThemes(controller)
    visualThemes = controller
    return controller ~= nil
  end

  local LEGACY_SENTINEL = "__kantoAscendantTrainerCycle"
  local STATE_KEY = "__kantoAscendantTitleIntroState"
  local INSTALL_VERSION = 3

  -- UPDATE5 used a permanent boolean as its only install receipt.  A 0.1.86
  -- hot import therefore saw the old wrapper and returned before it could add
  -- a newly shipped repair.  UPDATE6 publishes the owned function identities
  -- instead.  A directly owned prior install can be removed exactly; when a
  -- later Crystal wrapper sits above it, the still-live title movie remains
  -- authoritative and a narrow constructor/draw repair is layered on it.
  local priorState = rawget(TitleState, STATE_KEY)
  if type(priorState) == "table" and type(priorState.restore) == "function" then
    priorState.restore()
  end
  local inheritedCycle = rawget(TitleState, LEGACY_SENTINEL) == true

  -- `debug` is deliberately absent from the 0.1.86 mod sandbox.  Error
  -- handlers must preserve restoration without reaching outside that API.
  local function errorMessage(problem)
    return tostring(problem)
  end

  local function runtimePath(path)
    if not path or path == "" then return nil end
    if path:sub(1, 5) == "save/" or path:sub(1, 1) == "/" then return path end
    return mod.path .. "/" .. path
  end

  local function tryImage(path)
    if not path then return nil end
    local ok, image = pcall(love.graphics.newImage, Assets.resolve(path))
    return ok and image or nil
  end

  local function tryImageRaw(path)
    if not path then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    return ok and image or nil
  end

  local function imagePath(entry)
    return type(entry) == "table" and entry.path or entry
  end

  local function isForeignYellowLogo(path)
    if type(path) ~= "string" then return false end
    local normalized = path:gsub("\\", "/")
    local relative = "deutsch-gelb/overrides/title/pokemon_logo.png"
    if normalized == relative then return true end
    local suffix = "/" .. relative
    return #normalized >= #suffix
      and normalized:sub(-#suffix) == suffix
  end

  -- 0.1.86 resolves every generated title image through every loaded mod's
  -- overrides, including a translation whose edition guard returned.  That
  -- lets deutsch-gelb's logo (which already contains GELBE EDITION) replace
  -- Red/Blue's neutral logo while the correct separate ribbon remains.  Load
  -- the already-mounted active-edition source directly, but only for that
  -- exact foreign override.  Calling this from draw also repairs a TitleState
  -- that already existed when UPDATE6 was hot-imported.
  local function recoverForeignYellowLogo(screen)
    if not screen or GameVersion.get() == "yellow" then return false end
    local logoPath = imagePath(screen.title and screen.title.logo)
    local resolvedLogo = logoPath and Assets.resolve(logoPath) or nil
    if not (logoPath and isForeignYellowLogo(resolvedLogo)) then return false end
    if screen.kaTitleLogoRecovered
        and screen.kaTitleLogoSource == logoPath
        and screen.kaTitleLogoRejected == resolvedLogo
        and screen.logo == screen.kaTitleRecoveredLogo then
      return true
    end
    local editionLogo = tryImageRaw(logoPath)
    if not editionLogo then return false end
    screen.logo = editionLogo
    screen.kaTitleLogoRecovered = true
    screen.kaTitleLogoSource = logoPath
    screen.kaTitleLogoRejected = resolvedLogo
    screen.kaTitleRecoveredLogo = editionLogo
    return true
  end

  -- An old UPDATE5 wrapper cannot be unwrapped without the forbidden debug
  -- library.  Keep its already-running title cycle intact and add only the
  -- edition-logo repair required by UPDATE6.  This path also covers a class
  -- whose complete current wrapper is still underneath Crystal's update
  -- wrapper during an install-over-install hot reload.
  if inheritedCycle then
    local originalNew = TitleState.new
    local originalDraw = TitleState.draw
    local function upgradedNew(...)
      local screen = originalNew(...)
      recoverForeignYellowLogo(screen)
      return screen
    end
    local function upgradedDraw(screen, ...)
      recoverForeignYellowLogo(screen)
      return originalDraw(screen, ...)
    end
    TitleState.new = upgradedNew
    TitleState.draw = upgradedDraw
    local state = {
      version = INSTALL_VERSION,
      mode = "legacy-upgrade",
      originalNew = originalNew,
      originalDraw = originalDraw,
      wrappedNew = upgradedNew,
      wrappedDraw = upgradedDraw,
    }
    state.restore = function()
      if TitleState.new ~= upgradedNew or TitleState.draw ~= upgradedDraw then
        return false
      end
      TitleState.new = originalNew
      TitleState.draw = originalDraw
      if rawget(TitleState, STATE_KEY) == state then
        rawset(TitleState, STATE_KEY, nil)
      end
      return true
    end
    rawset(TitleState, STATE_KEY, state)
    M.installed = true
    M.upgraded = true
    M.recoverForeignYellowLogo = recoverForeignYellowLogo
    return M
  end
  rawset(TitleState, LEGACY_SENTINEL, true)

  -- Trainer portraits are stored like Gen-I BG pictures: pure white is their
  -- paper background.  The title character is OAM-style art, where colour 0
  -- must instead be transparent so only the figure can sit over the Pokemon.
  local function tryCutout(path)
    if not (path and love.image and love.image.newImageData) then return nil end
    local ok, data = pcall(love.image.newImageData, Assets.resolve(path))
    if not ok or not data then return nil end
    data:mapPixel(function(_, _, red, green, blue, alpha)
      if red > 0.999 and green > 0.999 and blue > 0.999 then
        return red, green, blue, 0
      end
      return red, green, blue, alpha
    end)
    local made, image = pcall(love.graphics.newImage, data)
    return made and image or nil
  end

  -- Green and Blue portraits use the 56x56 trainer canvas, while the title's
  -- original Red OAM composition is 40x56.  Centre-crop to that native slot
  -- with nearest-neighbour rendering; this avoids scaling, blur and drift.
  local function titleSlot(image)
    if not image then return nil end
    local width, height = image:getDimensions()
    if width == 40 and height == 56 then return image end
    if not (love.graphics.newCanvas and love.graphics.setCanvas) then
      return image
    end
    local prior = love.graphics.getCanvas and love.graphics.getCanvas() or nil
    local canvas = love.graphics.newCanvas(40, 56)
    if canvas.setFilter then canvas:setFilter("nearest", "nearest") end
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, math.floor((40 - width) / 2), 56 - height)
    love.graphics.setCanvas(prior)
    love.graphics.setColor(1, 1, 1, 1)
    return canvas
  end

  local originalNew = TitleState.new
  local originalUpdate = TitleState.update
  local originalDraw = TitleState.draw
  local originalOpenMenu = TitleState.openMenu
  local originalCurrentSprite = TitleState.currentSprite
  local originalSgbPalettes = TitleState.sgbPalettes

  local function publishTitleIdentity(self, trainerIndex, species)
    local trainers = self.kaTitleTrainers
    local entry = trainers and trainers[trainerIndex]
    if not entry then return false end
    -- Publish trainer and the engine-selected Pokemon identity together.  The
    -- final Crystal title wrapper reads kaTitleSpecies and rebuilds its
    -- animated state from this same edge; it never guesses from an
    -- option-dependent scene fallback.
    self.kaTitleTrainerIndex = trainerIndex
    self.kaTitleTrainerId = entry.id
    self.kaTitleTrainerSource = entry.source
    self.kaTitleSpecies = species
    self.kaTitlePairId = entry.id .. ":" .. tostring(species)
    self.player = entry.image
    self.__ascendantCrystalV15Title = nil
    if not trainerAnimationFailed and trainerAnimation
        and type(trainerAnimation.applyTitle) == "function" then
      local ok, problem = pcall(trainerAnimation.applyTitle,
        self, entry.id, self.kaTitlePairId, entry.image)
      -- The controller owns only a post-palette overlay.  The classic image
      -- always stays in TitleState.player for OFF, engine/provider and asset
      -- fallback, and for every non-title consumer of this screen.
      self.player = entry.image
      if not ok then
        trainerAnimationFailed = true
        if type(trainerAnimation.failSession) == "function" then
          pcall(trainerAnimation.failSession, problem)
        end
        if type(trainerAnimation.resetTitle) == "function" then
          pcall(trainerAnimation.resetTitle, self, entry.image)
        end
        Logger.warn(
          "Kanto Ascendant title animation failed closed to static: %s",
          tostring(problem))
      end
    end
    return true
  end

  local function whiteUiZones(zones)
    if type(zones) ~= "table" then return zones end
    local result = {}
    for index, zone in ipairs(zones) do
      local copy = {}
      for key, value in pairs(zone) do copy[key] = value end
      if type(zone.colors) == "table" and zone.colors[1] then
        copy.colors = {
          { 255, 255, 255 }, zone.colors[2], zone.colors[3], zone.colors[4],
        }
      end
      result[index] = copy
    end
    return result
  end

  -- Kanto Ascendant's intro is authored on clean white paper.  The SGB
  -- title palettes use a slightly magenta hardware white, which became very
  -- obvious once full-colour trainer/monster art was added.  Preserve every
  -- ink colour and zone boundary, changing only shade zero to actual white.
  function TitleState:sgbPalettes(game)
    local classic = whiteUiZones(originalSgbPalettes(self, game))
    if not (visualThemes
        and type(visualThemes.applyTitlePalettes) == "function") then
      return classic
    end
    local ok, themed, receipt = pcall(visualThemes.applyTitlePalettes,
      classic, {
        identity = self.kaTitleTrainerId,
        pairId = self.kaTitlePairId,
        yellowLayout = self.yellowLayout == true,
      })
    if ok and type(themed) == "table" then
      self.__ascendantVisualTitleThemeReceipt66 = receipt
      return themed
    end
    if type(visualThemes.failSession) == "function" then
      pcall(visualThemes.failSession,
        ok and "invalid-theme-result" or themed)
    end
    self.__ascendantVisualTitleThemeReceipt66 = {
      status = "fallback", theme = "classic",
      reason = ok and "invalid-theme-result" or tostring(themed),
    }
    return classic
  end

  -- Preserve the resolver's true-colour bit.  The final Crystal-v1.5 title
  -- wrapper is installed later and owns frame advancement; forcing `false`
  -- here used to send its fallback full-colour PNG through the Gen-I title
  -- palette (the reported white/orange birds and starters).
  function TitleState:currentSprite()
    if self.kaTitleOverlaySuppressed66 then return nil, false end
    return originalCurrentSprite(self)
  end

  function TitleState.new(game, opts)
    local self = originalNew(game, opts)
    recoverForeignYellowLogo(self)
    -- Yellow owns a different fixed-Pikachu composition and has no standing
    -- Red to replace.  Leave that version's faithful intro untouched.
    if self.yellowLayout then return self end

    local red = self.player
    -- The optional CRYSTAL CHARS skin is a gameplay/battle skin.  It must
    -- never silently replace the already approved Red/Blue title figures.
    -- Keep this small title movie on the Ascendant identity art regardless
    -- of the option; only Green is the newly added title participant.
    local greenVisual = characters.definition("GREEN").visuals.front
    local blueVisual = characters.definition("BLUE").visuals.front
    local green = titleSlot(tryCutout(runtimePath(greenVisual and greenVisual.path))
      or tryCutout(runtimePath(greenVisual and greenVisual.fallbackPath)))
    local blue = titleSlot(tryCutout(runtimePath(blueVisual and blueVisual.path))
      or tryCutout(runtimePath(blueVisual and blueVisual.fallbackPath)))
    local trainers = {
      { id = "GREEN", image = green, source = "ascendant" },
      { id = "BLUE", image = blue, source = "ascendant" },
      { id = "RED", image = red, source = "vanilla" },
    }
    for _, entry in ipairs(trainers) do
      if not entry.image then
        Logger.warn("Kanto Ascendant title trainer %s could not be loaded",
                    entry.id)
        entry.image = red
      end
    end
    self.kaTitleTrainers = trainers
    self.kaTitleAtomicCycle = true
    self.kaTitlePhase = "pair"
    publishTitleIdentity(self, 1,
      self.cycleSpecies and self.cycleSpecies[self.cycleIndex])
    self.kaTitleTrainerX = 82
    self.kaTitlePokemonOffsetX = 0
    local footer = self.title and self.title.copyrightText
    if footer and footer ~= "" then
      self.kaTitleFooterX = math.floor((160 - Font.width(footer)) / 2)
    end
    return self
  end

  function TitleState:update(dt)
    -- A patched-engine title overlay is frozen below Menu/New Game.  Restore
    -- the exact classic trainer on the first tick back without selecting a new
    -- variant or consuming an animation tick.
    if self.kaTitleOverlaySuppressed66 then
      self.kaTitleOverlaySuppressed66 = nil
      self.player = self.kaTitleSuppressedPlayer66
      self.kaTitleSuppressedPlayer66 = nil
    end
    local cycleBefore = self.cycleIndex
    local speciesBefore = self.cycleSpecies
      and self.cycleSpecies[cycleBefore] or nil
    originalUpdate(self, dt)
    local speciesAfter = self.cycleSpecies
      and self.cycleSpecies[self.cycleIndex] or nil
    -- The timer is not an identity edge: native/compatibility transitions may
    -- reset it more than once.  Advance only when TitleState actually selected
    -- another species.  Keep that engine-owned pick and publish it with the
    -- next trainer in one operation before draw.
    local pairChanged = false
    if self.kaTitleAtomicCycle and self.cycleIndex ~= cycleBefore
        and speciesAfter ~= speciesBefore then
      local nextTrainer = self.kaTitleTrainerIndex % #self.kaTitleTrainers + 1
      publishTitleIdentity(self, nextTrainer, speciesAfter)
      self.kaTitlePhase = "pair"
      pairChanged = true
    end
    -- One TitleState update is one engine tick.  The pair-change tick owns
    -- frame 1 and is intentionally not counted as a playback tick as well.
    if self.kaTitleAtomicCycle and not pairChanged
        and not trainerAnimationFailed and trainerAnimation
        and type(trainerAnimation.advanceTitle) == "function" then
      local ok, problem = pcall(trainerAnimation.advanceTitle, self, 1)
      if not ok then
        trainerAnimationFailed = true
        if type(trainerAnimation.failSession) == "function" then
          pcall(trainerAnimation.failSession, problem)
        end
        local entry = self.kaTitleTrainers
          and self.kaTitleTrainers[self.kaTitleTrainerIndex]
        self.player = entry and entry.image or self.player
        if type(trainerAnimation.resetTitle) == "function" then
          pcall(trainerAnimation.resetTitle, self, self.player)
        end
        Logger.warn(
          "Kanto Ascendant title animation failed closed to static: %s",
          tostring(problem))
      end
    end
  end

  -- Gen1Recomp 0.2.56 made the post-palette UI redraw queue part of the
  -- stock renderer, but deliberately kept it at virtual-pixel scale.  The
  -- earlier reviewed companion exposed the same queue with explicit sx/sy
  -- parameters and a capability marker.  Accept both contracts: use the
  -- authored 128px master directly on the scaled contract and a cached 64px
  -- logical / 128px physical high-density canvas on the stock contract.
  -- Older engines that expose
  -- neither complete queue shape still fail closed to the classic trainer.
  local function redrawApi()
    local ok, PaletteFX = pcall(require, "src.render.PaletteFX")
    if not (ok and type(PaletteFX.markUiSpriteRedraw) == "function") then
      return nil
    end
    if PaletteFX.uiSpriteRedrawScaleSupported == true then
      return PaletteFX, "scaled"
    end
    if type(PaletteFX.uiSpriteRedraws) == "function" then
      return PaletteFX, "stock"
    end
    return nil
  end

  local stockFrameCache = setmetatable({}, { __mode = "k" })

  local function stockRedrawFrame(image, scale)
    local cached = stockFrameCache[image]
    if cached and cached.scale == scale then return cached.image end
    if not (love.graphics.newCanvas and love.graphics.setCanvas
        and love.graphics.draw) then return nil end
    local okSize, width, height = pcall(image.getDimensions, image)
    if not okSize then return nil end
    local targetWidth = math.max(1, math.floor(width * scale + 0.5))
    local targetHeight = math.max(1, math.floor(height * scale + 0.5))
    local prior = love.graphics.getCanvas and love.graphics.getCanvas() or nil
    local dpiScale = 1 / scale
    local ok, canvas = pcall(love.graphics.newCanvas,
      targetWidth, targetHeight, { dpiscale = dpiScale })
    if not (ok and canvas) then return nil end
    if type(canvas.setFilter) == "function" then
      pcall(canvas.setFilter, canvas, "nearest", "nearest")
    end
    local rendered, problem = xpcall(function()
      love.graphics.setCanvas(canvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(image, 0, 0, 0, scale, scale)
    end, errorMessage)
    love.graphics.setCanvas(prior)
    love.graphics.setColor(1, 1, 1, 1)
    if not rendered then return nil, problem end
    stockFrameCache[image] = { scale = scale, image = canvas }
    return canvas
  end

  local function retireOptionalAnimation(screen, staticImage, reason)
    trainerAnimationFailed = true
    -- Late capability/queue failures can arrive while another wrapper has put
    -- the HD frame in `player`. Prefer the provider-owned Classic reference;
    -- never bless that transient animation frame as the reset image.
    local state = screen
      and rawget(screen, "__ascendantTitleTrainerAnimation67") or nil
    local classicImage = staticImage
      or screen and rawget(screen, "__ascendantTitleTrainerStatic67")
      or state and state.staticImage
      or screen and screen.player
    if trainerAnimation and type(trainerAnimation.failSession) == "function" then
      pcall(trainerAnimation.failSession, reason)
    end
    if trainerAnimation and type(trainerAnimation.resetTitle) == "function" then
      pcall(trainerAnimation.resetTitle, screen, classicImage)
    elseif screen then
      screen.__ascendantTitleTrainerAnimation67 = nil
      screen.__ascendantTitleTrainerStatic67 = nil
      if classicImage ~= nil then screen.player = classicImage end
    end
  end

  function TitleState:openMenu()
    local animation = rawget(self, "__ascendantTitleTrainerAnimation67")
    -- Bare 0.1.90, OFF, missing assets and missing provider are byte-for-byte
    -- the established 6.6 path, including the original openMenu call.
    if type(animation) ~= "table" or animation.trueColor ~= true then
      return originalOpenMenu(self)
    end
    if not redrawApi() then
      retireOptionalAnimation(self, nil, "engine-capability-unavailable")
      return originalOpenMenu(self)
    end
    local persistent = self.player
    self.kaTitleOverlaySuppressed66 = true
    self.kaTitleSuppressedPlayer66 = persistent
    self.player = nil
    local ok, problem = xpcall(function()
      originalOpenMenu(self)
    end, errorMessage)
    if not ok then
      self.kaTitleOverlaySuppressed66 = nil
      self.kaTitleSuppressedPlayer66 = nil
      self.player = persistent
      error(problem, 0)
    end
  end

  local function queueHdTrainer(animation, PaletteFX, redrawMode)
    local image = animation.image
    if not (image and type(image.getDimensions) == "function") then
      return false
    end
    local okSize, width, height = pcall(image.getDimensions, image)
    if not okSize or width ~= 128 or height ~= 128 then return false end
    local scale = tonumber(animation.drawScale) or 0.5
    local x = tonumber(animation.drawX) or 82
    local y = tonumber(animation.drawY) or 68
    if redrawMode == "stock" then
      image = stockRedrawFrame(image, scale)
      if not image then return false end
      local redraws = PaletteFX.uiSpriteRedraws()
      if type(redraws) ~= "table" then return false end
      local before = #redraws
      local okQueue = pcall(PaletteFX.markUiSpriteRedraw,
        image, nil, x, y)
      return okQueue and #redraws == before + 1
    end
    local okQueue, queued = pcall(PaletteFX.markUiSpriteRedraw,
      image, nil, x, y, scale, scale)
    return okQueue and queued == true
  end

  -- Only an active animation on the patched 0.1.90 companion enters the
  -- post-palette overlay transaction.  Every fallback calls the pre-Card
  -- native compositor with all fields untouched.
  local function drawNativeTitle(screen)
    if screen.kaTitleOverlaySuppressed66 then return originalDraw(screen) end
    local animation = rawget(screen, "__ascendantTitleTrainerAnimation67")
    local PaletteFX, redrawMode
    if type(animation) == "table" and animation.trueColor == true then
      PaletteFX, redrawMode = redrawApi()
    end
    if not PaletteFX then
      if type(animation) == "table" then
        retireOptionalAnimation(screen, nil,
          "engine-capability-unavailable")
      end
      return originalDraw(screen)
    end

    local player, playerQuads, ballQuad = screen.player,
      screen.playerQuads, screen.ballQuad
    local first, second, third
    local queued = false
    screen.player, screen.playerQuads, screen.ballQuad = nil, nil, nil
    local ok, problem = xpcall(function()
      first, second, third = originalDraw(screen)
      queued = queueHdTrainer(animation, PaletteFX, redrawMode)
    end, errorMessage)
    screen.player, screen.playerQuads, screen.ballQuad =
      player, playerQuads, ballQuad
    if not ok then error(problem, 0) end
    if not queued then
      -- A capability marker without a usable UI-pass queue is an incomplete
      -- companion, not permission to omit the trainer or crash the title.
      -- Retire only this optional animation state and repaint once through the
      -- exact static compositor with every classic field restored.
      retireOptionalAnimation(screen, nil, "ui-redraw-unavailable")
      return originalDraw(screen)
    end
    return first, second, third
  end

  local function drawSuppressedTitle(screen)
    if not screen.title then return drawNativeTitle(screen) end
    local footer = screen.title.copyrightText
    local germanFullRibbon = screen.title.germanFullVersionRibbon
    local player, playerQuads, ballQuad = screen.player,
      screen.playerQuads, screen.ballQuad
    screen.title.copyrightText = ""
    screen.title.germanFullVersionRibbon = false
    screen.player, screen.playerQuads, screen.ballQuad = nil, nil, nil
    local first, second, third
    local ok, problem = xpcall(function()
      first, second, third = originalDraw(screen)
    end, errorMessage)
    screen.title.copyrightText = footer
    screen.title.germanFullVersionRibbon = germanFullRibbon
    screen.player, screen.playerQuads, screen.ballQuad =
      player, playerQuads, ballQuad
    if not ok then error(problem, 0) end
    return first, second, third
  end

  function TitleState:draw()
    recoverForeignYellowLogo(self)
    if self.kaTitleOverlaySuppressed66 then
      return drawSuppressedTitle(self)
    end
    local footer = self.title and self.title.copyrightText
    if not footer or footer == "" then return drawNativeTitle(self) end
    -- Suppress TitleState's vanilla x=1 footer, then redraw the mod name at
    -- its measured horizontal centre.  All other title coordinates remain
    -- byte-for-byte on their original Red/Blue/Yellow positions.
    --
    -- Engine 0.1.76 gained native support for continuous localized ribbons
    -- (`versionFull`) plus its own one-copy boot fly-in.  The older German
    -- compatibility wrapper still redraws the same full strip at x=48 after
    -- every engine draw.  During 0.1.76's `ribbon` phase that produced one
    -- stationary and one moving "ROTE EDITION".  Disable only that legacy
    -- redraw while the newer engine is already the full-ribbon owner.  Older
    -- engines have no `versionFull` marker and retain the compatibility draw.
    local germanFullRibbon = self.title.germanFullVersionRibbon
    if self.versionFull == true and germanFullRibbon then
      self.title.germanFullVersionRibbon = false
    end
    self.title.copyrightText = ""
    local ok, problem = xpcall(function()
      drawNativeTitle(self)
    end, errorMessage)
    self.title.copyrightText = footer
    self.title.germanFullVersionRibbon = germanFullRibbon
    if not ok then error(problem, 0) end
    self.kaTitleFooterX = math.floor((160 - Font.width(footer)) / 2)
    local scrollY = self.yellowLayout and -(self.scy or 0) or 0
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(footer, self.kaTitleFooterX, 136 + scrollY)
    love.graphics.setColor(1, 1, 1, 1)
  end

  local state = {
    version = INSTALL_VERSION,
    mode = "full",
    originals = {
      new = originalNew,
      update = originalUpdate,
      draw = originalDraw,
      openMenu = originalOpenMenu,
      currentSprite = originalCurrentSprite,
      sgbPalettes = originalSgbPalettes,
    },
    wrappers = {
      new = TitleState.new,
      update = TitleState.update,
      draw = TitleState.draw,
      openMenu = TitleState.openMenu,
      currentSprite = TitleState.currentSprite,
      sgbPalettes = TitleState.sgbPalettes,
    },
  }
  state.restore = function()
    for name, wrapper in pairs(state.wrappers) do
      if TitleState[name] ~= wrapper then return false end
    end
    for name, original in pairs(state.originals) do
      TitleState[name] = original
    end
    rawset(TitleState, LEGACY_SENTINEL, nil)
    if rawget(TitleState, STATE_KEY) == state then
      rawset(TitleState, STATE_KEY, nil)
    end
    return true
  end
  rawset(TitleState, STATE_KEY, state)
  M.installed = true
  M.recoverForeignYellowLogo = recoverForeignYellowLogo
  return M
end
