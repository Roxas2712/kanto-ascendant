-- Additive port of the upstream Crystal v1.5 presentation features.
-- Kanto Ascendant's existing sprite resolver remains the sole Pokémon-art
-- owner; this module only decorates UI states, trainer art and player art.

return function(mod, opts)
  opts = opts or {}
  local crystal = opts.crystalAnimation
  local V = { game = nil }
  local imageCache = {}
  local okPalette, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not okPalette then PaletteFX = nil end
  local GameVersion = require("src.core.GameVersion")

  local function advancedColor()
    if crystal and type(crystal.advancedColor) == "function" then
      return crystal.advancedColor()
    end
    if rawget(_G, "love") == nil or love.image == nil then return true end
    return not PaletteFX or PaletteFX.mode == nil or PaletteFX.mode == "redpp"
  end

  local function externalActive()
    return crystal and crystal.externalKantoActive
      and crystal.externalKantoActive(1) or false
  end

  local function scopeEnabled(kind)
    if externalActive() then return false end
    if mod.options:get("pokemon_sprite_style") ~= "crystal" then return false end
    local key = ({
      battle = "sprite_style_battle", summary = "sprite_style_summary",
      dex = "sprite_style_dex", box = "sprite_style_box",
    })[kind] or "sprite_style_scenes"
    return mod.options:get(key) ~= false
  end

  local function artVariant()
    return advancedColor() and "normal" or "grayscale"
  end

  local function characterArtEnabled()
    -- Kanto Ascendant owns one reviewed FRLG-scale trainer family for Oak,
    -- Red, Blue, Casey and all opponent classes.  Upstream v1.5 trainer PNGs
    -- used to overwrite that family late in screen construction and could
    -- even put Red back onto a selected Blue/Casey card.  v1.5 remains the
    -- Pokemon-animation provider only; trainer presentation stays with the
    -- central character/FRLG resolvers.
    return false
  end

  local function relativeTrainer(name, variant)
    if type(name) ~= "string" or name == "" then return nil end
    return ("assets/crystal_v15/trainers/%s/%s.png")
      :format(variant or artVariant(), name)
  end

  local function loadImage(relative)
    if not relative or mod:read(relative) == nil then return nil end
    local path = mod.path .. "/" .. relative
    if imageCache[path] then return imageCache[path] end
    if not (love and love.graphics and love.graphics.newImage) then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if not (ok and image) then return nil end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    imageCache[path] = image
    return image
  end

  local function trainerPicName(path)
    if type(path) ~= "string" then return nil end
    return path:match("([^/\\]+)%.png$") or path:match("([^/\\]+)$")
  end

  local function trainerName(game, trainer, oppClass, partyIndex)
    if not trainer then return nil end
    local path
    if oppClass == "OPP_ROCKET" and (partyIndex or 1) >= 42
        and trainer.picJessieJames then
      path = trainer.picJessieJames
    elseif trainer.pic then
      path = trainer.pic
    elseif trainer.basePic and game and game.data and game.data.trainers
        and game.data.trainers[trainer.basePic] then
      path = game.data.trainers[trainer.basePic].pic
    end
    return trainerPicName(path)
  end

  local function pixelCopy(image)
    if not (image and love and love.graphics) then return nil end
    local okData, data = pcall(image.getData, image)
    if okData and data and data.clone then
      local okClone, clone = pcall(data.clone, data)
      if okClone then return clone end
    end
    local ok, out = pcall(function()
      local g = love.graphics
      local w, h = image:getDimensions()
      local previous = g.getCanvas and g.getCanvas() or nil
      local canvas = g.newCanvas(w, h, { dpiscale = 1 })
      g.setCanvas(canvas)
      g.clear(0, 0, 0, 0)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 0, 0)
      if previous then g.setCanvas(previous) else g.setCanvas() end
      return canvas:newImageData()
    end)
    return ok and out or nil
  end

  local function flipHorizontal(image)
    local data = pixelCopy(image)
    if not data then return image end
    local source = data.clone and data:clone() or nil
    if not source then return image end
    local width = data:getWidth()
    local ok = pcall(function()
      data:mapPixel(function(x, y)
        return source:getPixel(width - 1 - x, y)
      end)
    end)
    if not ok then return image end
    local okImage, flipped = pcall(love.graphics.newImage, data)
    if not (okImage and flipped) then return image end
    if flipped.setFilter then flipped:setFilter("nearest", "nearest") end
    return flipped
  end

  function V:trainerImage(name, kind)
    if not characterArtEnabled() or not scopeEnabled(kind or "scenes") then
      return nil
    end
    return loadImage(relativeTrainer(name))
  end

  function V:decorateSummary(screen, mon)
    if not (crystal and screen and mon) then return end
    local state = crystal.presentationAnimation(
      mon.species, mon, "front", "summary", { data = screen.game.data })
    if state and state.image then
      screen.__ascendantCrystalV15 = state
      screen.sprite = state.image
      screen.spriteTrueColor = state.trueColor
    end
  end

  function V:decorateDex(screen, species)
    if not (crystal and screen and species) then return end
    local state = crystal.presentationAnimation(
      species, nil, "front", "dex", { data = screen.game.data })
    if state and state.image then
      screen.__ascendantCrystalV15 = state
      screen.sprite = state.image
      screen.spriteTrueColor = state.trueColor
    end
  end

  function V:updateScreen(screen, dt)
    local state = screen and screen.__ascendantCrystalV15
    if not state then return end
    local image = crystal.advancePresentation(state, dt, screen.game)
    if image then screen.sprite = image end
  end

  local function drawClock(screen, entries)
    if not (love and love.timer and love.timer.getTime) then return end
    local now = love.timer.getTime()
    local previous = screen.__ascendantCrystalV15Clock
    screen.__ascendantCrystalV15Clock = now
    local dt = previous and now - previous or 0
    if dt <= 0 or dt >= 2 then return end
    for _, item in ipairs(entries) do
      local state, field = item[1], item[2]
      if state then
        local old = screen[field]
        local image = crystal.advancePresentation(state, dt, screen.game)
        if image then
          screen[field] = image
          if screen.pic == old then screen.pic = image end
        end
      end
    end
  end

  function V:decorateEvolution(screen)
    if not (crystal and screen and screen.mon) then return end
    local data = screen.game.data
    local old = crystal.presentationAnimation(screen.mon.species, screen.mon,
      "front", "scenes", { data = data, trim = true })
    local new = crystal.presentationAnimation(screen.newSpecies, screen.mon,
      "front", "scenes", { data = data, trim = true })
    screen.__ascendantCrystalV15Evolution = { old = old, new = new }
    if old and old.image then
      screen.oldSprite = old.image
      screen.oldSpriteTrueColor = old.trueColor
    end
    if new and new.image then
      screen.newSprite = new.image
      screen.newSpriteTrueColor = new.trueColor
    end
  end

  function V:advanceEvolution(screen)
    local states = screen and screen.__ascendantCrystalV15Evolution
    if not states then return end
    drawClock(screen, {
      { states.old, "oldSprite" }, { states.new, "newSprite" },
    })
  end

  function V:hallSprite(screen, species)
    if not (crystal and screen and species) then return nil end
    screen.__ascendantCrystalV15Hall = screen.__ascendantCrystalV15Hall or {}
    local state = screen.__ascendantCrystalV15Hall[species]
    if not state then
      local mon = screen.game.save.party[screen.index or 0]
      if not (mon and mon.species == species) then mon = nil end
      state = crystal.presentationAnimation(species, mon, "front", "scenes",
        { data = screen.game.data, trim = true })
      screen.__ascendantCrystalV15Hall[species] = state or false
    end
    -- HallOfFame owns the final palette pass.  Preserve the resolver's
    -- true-colour bit alongside the animated image, otherwise SGB/GBC modes
    -- remap the authored Crystal card into a purple four-shade silhouette.
    screen.spriteTrueColors = screen.spriteTrueColors or {}
    screen.spriteTrueColors[species] = state and state.trueColor == true or false
    screen.__ascendantCrystalV15HallTrueColors =
      screen.__ascendantCrystalV15HallTrueColors or setmetatable({}, {
        __mode = "k",
      })
    if state and state.image then
      screen.__ascendantCrystalV15HallTrueColors[state.image] =
        state.trueColor == true
    end
    return state and state.image or nil
  end

  function V:updateHall(screen, dt)
    for _, state in pairs(screen.__ascendantCrystalV15Hall or {}) do
      if state then crystal.advancePresentation(state, dt, screen.game) end
    end
  end

  function V:titleSprite(screen)
    if not (crystal and screen and screen.cycleSpecies) then return nil end
    -- The final title wrapper owns the Pokemon half of Ascendant's paired
    -- trainer + animated-Crystal-Pokemon composition.  Ascendant publishes
    -- the engine-selected cycle species atomically with the next trainer;
    -- other callers retain their ordinary scene resolver.
    local forcedCycle = screen.kaTitleAtomicCycle == true
      and screen.kaTitleSpecies ~= nil
    local species = forcedCycle and screen.kaTitleSpecies
      or screen.cycleSpecies[screen.cycleIndex]
    local state = screen.__ascendantCrystalV15Title
    if not state or state.species ~= species
        or state.kaTitlePairId ~= screen.kaTitlePairId then
      state = crystal.presentationAnimation(species, nil, "front", "scenes",
        { data = screen.game.data, forceBundled = forcedCycle })
      if state then state.kaTitlePairId = screen.kaTitlePairId end
      screen.__ascendantCrystalV15Title = state
    end
    return state and state.image or nil, state and state.trueColor or false
  end

  function V:updateTitle(screen, dt)
    local state = screen and screen.__ascendantCrystalV15Title
    if state then crystal.advancePresentation(state, dt, screen.game) end
  end

  function V:decorateOak(screen)
    if not screen then return end
    -- Oak's native Gen-I Nidorino is exact but its mirrored pose reads like
    -- two overlapping creatures at the intro's large scale.  Force only this
    -- scripted demo onto the clearer bundled Crystal front, independently of
    -- the player's global scene/style setting.  All other scene art keeps the
    -- ordinary option and external-provider contract below.
    local forceNidorino = screen.demoSpecies == "NIDORINO"
    local scenesEnabled = scopeEnabled("scenes")
    if not forceNidorino and not scenesEnabled then return end
    screen.__ascendantCrystalV15OakDecorated = true
    if scenesEnabled then
      screen.oakPic = self:trainerImage("prof.oak") or screen.oakPic
      screen.rivalPic = self:trainerImage("rival1") or screen.rivalPic
      screen.playerPic = self:trainerImage("red") or screen.playerPic
      screen.playerTrueColor = advancedColor()
    end
    if crystal and screen.demoSpecies then
      local state = screen.__ascendantCrystalV15OakDemo
      if not state or state.species ~= screen.demoSpecies
          or (forceNidorino and state.__kaOakForceBundled ~= true) then
        state = crystal.presentationAnimation(screen.demoSpecies, nil,
          "front", "scenes", {
            data = screen.game.data,
            forceBundled = forceNidorino,
          })
        if state then state.__kaOakForceBundled = forceNidorino end
      end
      if state and state.image then
        screen.__ascendantCrystalV15OakDemo = state
        screen.demoPic = state.image
        screen.demoTrueColor = state.trueColor
        screen.__ascendantCrystalV15OakDemoReceipt = {
          schema = "ka-oak-crystal-animation/v1",
          species = state.species,
          dex = state.dex,
          animated = state.animated == true,
          frameCount = type(state.durations) == "table"
            and #state.durations or 0,
          source = state.path,
          forcedBundled = forceNidorino,
        }
      end
    end
  end

  function V:advanceOak(screen)
    -- Re-run the idempotent decorator on every Oak frame.  Compatibility
    -- paths may publish or replace demoSpecies after the constructor wrapper;
    -- a one-shot "decorated" flag used to strand that late Nidorino on its
    -- static engine picture for the complete introduction.
    if screen then self:decorateOak(screen) end
    local state = screen and screen.__ascendantCrystalV15OakDemo
    if state then drawClock(screen, { { state, "demoPic" } }) end
  end

  -- Older packaged renderers collect palette exclusions before draw() can
  -- report a late true-colour rectangle. Publish the Crystal demo picture
  -- through OakSpeech's ordinary palette contract as well, otherwise the
  -- MEWMON pass washes e.g. CHARMANDER almost completely white.
  function V:oakTrueColorZone(screen)
    if not (screen and screen.pic and screen.picTrueColor
        and screen.pic.getDimensions) then return nil end
    local w, h = screen.pic:getDimensions()
    local x = 48 + math.floor((8 - w / 8) / 2) * 8
    local y = 32 + (7 - h / 8) * 8
    local reveal, off = screen.picReveal, 0
    if reveal and reveal.kind == "wipe" then
      local progress = math.min(1,
        (reveal.t or 0) / math.max(1, reveal.dur or 1))
      off = math.floor((160 - x) * (1 - progress))
    end
    return { colors = false, x = x + off, y = y, w = w, h = h }
  end

  local function pngWidth(bytes)
    if type(bytes) ~= "string" or #bytes < 24
        or bytes:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
    return bytes:byte(17) * 16777216 + bytes:byte(18) * 65536
      + bytes:byte(19) * 256 + bytes:byte(20)
  end

  local function registerPlayerScale(relative)
    local bytes = mod:read(relative)
    local width = pngWidth(bytes)
    if not width or width <= 0 then return end
    local scale = 64 / width
    if scale < 0.25 or scale > 4 then return end
    mod.content.battle_sprite_scales:register(
      "KANTO_ASCENDANT_CRYSTAL_V15_" .. relative:gsub("[^%w]", "_"), {
        path = mod.path .. "/" .. relative,
        scale = scale,
      })
  end

  for _, variantName in ipairs({ "normal", "grayscale" }) do
    for _, name in ipairs({ "red", "redb" }) do
      local relative = relativeTrainer(name, variantName)
      if mod:read(relative) ~= nil then registerPlayerScale(relative) end
    end
  end

  mod.hooks:wrap("player.sprite", function(nextSprite, path, ctx)
    ctx = ctx or {}
    -- The explicit three-character selector and any higher-priority external
    -- player resolver own their selected image.  Preserve that result before
    -- applying v1.5's default Red portrait.  Vanilla Yellow likewise keeps
    -- its Yellow-specific protagonist until the player opts into Ascendant's
    -- character selection.
    local selected = nextSprite(path, ctx)
    if selected ~= path or GameVersion.get() == "yellow" then
      return selected
    end
    local kind = ctx.kind == "battle" and "battle" or "scenes"
    if characterArtEnabled() and scopeEnabled(kind)
        and not ctx.demo and not ctx.oakDemo then
      local name = ctx.side == "back" and "redb" or "red"
      local relative = relativeTrainer(name)
      if mod:read(relative) == nil and name == "redb" then
        relative = relativeTrainer("red")
      end
      if relative and mod:read(relative) ~= nil then
        ctx.trueColor = advancedColor()
        return mod.path .. "/" .. relative
      end
    end
    return selected
  end, 925)

  function V.install(game, deps)
    V.game = game
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    BattleState._ascendantCrystalV15Controller = V
    if not BattleState._ascendantCrystalV15TrainerWrapped then
      BattleState._ascendantCrystalV15TrainerWrapped = true
      local innerTrainer = BattleState.newTrainer
      BattleState.newTrainer = function(activeGame, oppClass, partyIndex, ...)
        local battle = innerTrainer(activeGame, oppClass, partyIndex, ...)
        local controller = BattleState._ascendantCrystalV15Controller
        if controller and battle and battle.trainer and scopeEnabled("battle") then
          local name = trainerName(activeGame, battle.trainer,
            oppClass, partyIndex)
          local image = controller:trainerImage(name, "battle")
          if image then battle.trainerPic = image end
        end
        return battle
      end
    end

    local function module(name)
      local ok, value = pcall(require, "src.ui." .. name)
      return ok and value or nil
    end

    local SummaryMenu = module("SummaryMenu")
    if SummaryMenu then
      SummaryMenu._ascendantCrystalV15Controller = V
      if not SummaryMenu._ascendantCrystalV15Wrapped then
        SummaryMenu._ascendantCrystalV15Wrapped = true
        local innerNew, innerUpdate = SummaryMenu.new, SummaryMenu.update
        SummaryMenu.new = function(activeGame, mon)
          local screen = innerNew(activeGame, mon)
          SummaryMenu._ascendantCrystalV15Controller:decorateSummary(screen, mon)
          return screen
        end
        SummaryMenu.update = function(screen, dt)
          SummaryMenu._ascendantCrystalV15Controller:updateScreen(screen, dt)
          return innerUpdate(screen, dt)
        end
      end
    end

    local DexEntryMenu = module("DexEntryMenu")
    if DexEntryMenu then
      DexEntryMenu._ascendantCrystalV15Controller = V
      if not DexEntryMenu._ascendantCrystalV15Wrapped then
        DexEntryMenu._ascendantCrystalV15Wrapped = true
        local innerNew, innerUpdate = DexEntryMenu.new, DexEntryMenu.update
        DexEntryMenu.new = function(activeGame, speciesOrOpts, ...)
          -- DexEntryMenu's third argument is a continuation.  The Fighting
          -- Dojo prize balls (and any later map script using the same public
          -- screen seam) rely on it to resume only after the entry closes.
          -- Forward every trailing engine argument before decorating the
          -- resulting screen; swallowing onDone made both prizes inert while
          -- Kanto Ascendant was enabled on 0.1.96 and 0.1.98.
          local screen = innerNew(activeGame, speciesOrOpts, ...)
          local species = type(speciesOrOpts) == "table"
            and (speciesOrOpts.species or speciesOrOpts[1]) or speciesOrOpts
          DexEntryMenu._ascendantCrystalV15Controller:decorateDex(screen, species)
          return screen
        end
        DexEntryMenu.update = function(screen, dt)
          DexEntryMenu._ascendantCrystalV15Controller:updateScreen(screen, dt)
          return innerUpdate(screen, dt)
        end
      end
    end

    local EvolutionState = module("EvolutionState")
    if EvolutionState then
      EvolutionState._ascendantCrystalV15Controller = V
      if not EvolutionState._ascendantCrystalV15Wrapped then
        EvolutionState._ascendantCrystalV15Wrapped = true
        local innerNew, innerDraw = EvolutionState.new, EvolutionState.draw
        EvolutionState.new = function(...)
          local screen = innerNew(...)
          EvolutionState._ascendantCrystalV15Controller:decorateEvolution(screen)
          return screen
        end
        EvolutionState.draw = function(screen, ...)
          EvolutionState._ascendantCrystalV15Controller:advanceEvolution(screen)
          return innerDraw(screen, ...)
        end
      end
    end

    local HallOfFame = module("HallOfFame")
    if HallOfFame then
      HallOfFame._ascendantCrystalV15Controller = V
      if not HallOfFame._ascendantCrystalV15Wrapped then
        HallOfFame._ascendantCrystalV15Wrapped = true
        local innerNew = HallOfFame.new
        local innerSprite, innerUpdate = HallOfFame.spriteFor, HallOfFame.update
        local innerDrawPic = HallOfFame.drawPic
        HallOfFame.new = function(...)
          local screen = innerNew(...)
          -- RC25-era engines did not preserve the true-colour bit returned
          -- by Sprites.playerPath and consequently recoloured both the
          -- player and animated Crystal Pokémon into a purple four-shade
          -- card.  Remember whether the engine already owns the native fix;
          -- the compatibility late-pass below only runs for older apps.
          screen.__ascendantHallNativeTrueColor =
            type(screen.spriteTrueColors) == "table"
              and screen.playerTrueColor ~= nil
          if not screen.__ascendantHallNativeTrueColor then
            local _, trueColor = require("src.pokemon.Sprites").playerPath(
              screen.game.data, "front", { kind = "hof" })
            screen.playerTrueColor = trueColor == true
          end
          -- HallOfFame.new already resolves the active RED/BLUE/GREEN avatar
          -- through Sprites.playerPath.  Replacing that result with v1.5's
          -- generic Red card made every selected character appear as Red in
          -- the Hall of Fame.  Retain the resolved current-character image;
          -- only an old engine with no player picture at all may use the
          -- historic Red fallback.
          if not screen.playerPic then
            local controller = HallOfFame._ascendantCrystalV15Controller
            local player = controller:trainerImage("red")
            if player then screen.playerPic = flipHorizontal(player) end
          end
          return screen
        end
        HallOfFame.spriteFor = function(screen, species)
          return HallOfFame._ascendantCrystalV15Controller:hallSprite(
            screen, species) or innerSprite(screen, species)
        end
        HallOfFame.update = function(screen, dt)
          HallOfFame._ascendantCrystalV15Controller:updateHall(screen, dt)
          return innerUpdate(screen, dt)
        end
        if type(innerDrawPic) == "function" then
          HallOfFame.drawPic = function(screen, image, ...)
            local result = innerDrawPic(screen, image, ...)
            if not screen.__ascendantHallNativeTrueColor and image then
              local trueColors = screen.__ascendantCrystalV15HallTrueColors
              local isTrueColor = image == screen.playerPic
                and screen.playerTrueColor == true
                or trueColors and trueColors[image] == true
              if isTrueColor and PaletteFX and PaletteFX.markTrueColor
                  and image.getDimensions then
                local width, height = image:getDimensions()
                PaletteFX.markTrueColor(screen.scrollX or 96, 40,
                  width, height)
              end
            end
            return result
          end
        end
      end
    end

    local TrainerCard = module("TrainerCard")
    if TrainerCard then
      TrainerCard._ascendantCrystalV15Controller = V
      if not TrainerCard._ascendantCrystalV15Wrapped then
        TrainerCard._ascendantCrystalV15Wrapped = true
        local innerNew = TrainerCard.new
        TrainerCard.new = function(...)
          local screen = innerNew(...)
          local player = TrainerCard._ascendantCrystalV15Controller
            :trainerImage("red")
          if player then screen.pic = flipHorizontal(player) end
          return screen
        end
      end
    end

    local TitleState = module("TitleState")
    if TitleState then
      TitleState._ascendantCrystalV15Controller = V
      if not TitleState._ascendantCrystalV15Wrapped then
        TitleState._ascendantCrystalV15Wrapped = true
        local innerSprite, innerUpdate = TitleState.currentSprite, TitleState.update
        local function validTitlePokemon(image, screen)
          if not image or image == screen.version then return false end
          if not image.getDimensions then return true end
          local ok, width, height = pcall(image.getDimensions, image)
          if not ok then return false end
          -- A title Pokémon is a picture, never an 8px edition ribbon.  A
          -- late asset provider once returned the German 80x8 strip here;
          -- TitleState then animated a second "ROTE EDITION" from the right.
          return not (height <= 16 and width >= 48)
        end
        TitleState.currentSprite = function(screen)
          local image, trueColor = TitleState._ascendantCrystalV15Controller
            :titleSprite(screen)
          if validTitlePokemon(image, screen) then return image, trueColor end
          -- Ascendant's atomic title cycle is an identity contract. If a bundled
          -- Crystal frame is unavailable, fail closed for that Pokemon half;
          -- never substitute an option/translation/scene resolver image after
          -- the trainer and native cycle species were published together.
          if screen.kaTitleAtomicCycle then return nil, false end
          -- The fallback is not automatically trustworthy.  Translation or
          -- compatibility wrappers can sit below this final wrapper and may
          -- return their edition ribbon from the ordinary sprite resolver.
          -- Validate that result at the same presentation seam as the
          -- Crystal candidate; returning no moving picture is preferable to
          -- ever animating UI text as a Pokémon.
          image, trueColor = innerSprite(screen)
          if validTitlePokemon(image, screen) then return image, trueColor end
          return nil, false
        end
        TitleState.update = function(screen, dt)
          local result = innerUpdate(screen, dt)
          TitleState._ascendantCrystalV15Controller:updateTitle(screen, dt)
          return result
        end
      end
    end

    local OakSpeech = module("OakSpeech")
    if OakSpeech then
      OakSpeech._ascendantCrystalV15Controller = V
      if not OakSpeech._ascendantCrystalV15Wrapped then
        OakSpeech._ascendantCrystalV15Wrapped = true
        local innerNew, innerDraw = OakSpeech.new, OakSpeech.draw
        local innerPalettes = OakSpeech.sgbPalettes
        OakSpeech.new = function(...)
          local screen = innerNew(...)
          OakSpeech._ascendantCrystalV15Controller:decorateOak(screen)
          return screen
        end
        OakSpeech.draw = function(screen, ...)
          OakSpeech._ascendantCrystalV15Controller:advanceOak(screen)
          return innerDraw(screen, ...)
        end
        OakSpeech.sgbPalettes = function(screen, game, ...)
          local zones = innerPalettes(screen, game, ...) or {}
          local zone = OakSpeech._ascendantCrystalV15Controller
            :oakTrueColorZone(screen)
          if zone then zones[#zones + 1] = zone end
          return zones
        end
      end
    end
  end

  function V.invalidate()
    imageCache = {}
    if crystal and crystal.invalidate then crystal.invalidate() end
  end

  mod.events:on("map.reloaded", function(event)
    if event and event.reason == "colors" then V.invalidate() end
  end)

  V.advancedColor = advancedColor
  V.scopeEnabled = scopeEnabled
  V.trainerPicName = trainerPicName
  return V
end
