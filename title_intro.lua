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
  local M = { order = { "GREEN", "BLUE", "RED" } }

  local LEGACY_SENTINEL = "__kantoAscendantTrainerCycle"
  local STATE_KEY = "__kantoAscendantTitleIntroState"
  local INSTALL_VERSION = 2

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
    return whiteUiZones(originalSgbPalettes(self, game))
  end

  -- Preserve the resolver's true-colour bit.  The final Crystal-v1.5 title
  -- wrapper is installed later and owns frame advancement; forcing `false`
  -- here used to send its fallback full-colour PNG through the Gen-I title
  -- palette (the reported white/orange birds and starters).
  function TitleState:currentSprite()
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
    local green = titleSlot(tryCutout(runtimePath(greenVisual and greenVisual.path)))
    local blue = titleSlot(tryCutout(runtimePath(blueVisual and blueVisual.path)))
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
    if self.kaTitleAtomicCycle and self.cycleIndex ~= cycleBefore
        and speciesAfter ~= speciesBefore then
      local nextTrainer = self.kaTitleTrainerIndex % #self.kaTitleTrainers + 1
      publishTitleIdentity(self, nextTrainer, speciesAfter)
      self.kaTitlePhase = "pair"
    end
  end

  -- Keep the native paired compositor intact.  In particular, do not clear
  -- `player`, `playerQuads` or `ballQuad`: those fields are the trainer half
  -- of the same frame in which `currentSprite()` supplies the animated
  -- Crystal Pokemon.
  local function drawNativeTitle(screen)
    return originalDraw(screen)
  end

  function TitleState:draw()
    recoverForeignYellowLogo(self)
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
      currentSprite = originalCurrentSprite,
      sgbPalettes = originalSgbPalettes,
    },
    wrappers = {
      new = TitleState.new,
      update = TitleState.update,
      draw = TitleState.draw,
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
