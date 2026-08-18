-- Standalone Crystal image-animation controller.
--
-- Ascendant mirrors Crystal Animated Sprites with Shiny Visuals' numbered
-- frame format, but uses a separate battler field. Its bundled Kanto pack is
-- therefore usable alone and yields cleanly when an external visual mod owns
-- the live sprite.

return function(mod, opts)
  opts = opts or {}
  local animationData = opts.animationData or {}
  local shinySystem = opts.shinySystem
  local megaEvolution = opts.megaEvolution
  local speciesOrder = opts.speciesOrder or {}
  local guestDexes = opts.guestDexes or {}
  local classicGuestDexes = opts.classicGuestDexes or {}
  local A = {
    selected = setmetatable({}, { __mode = "k" }),
    activeFrontMons = setmetatable({}, { __mode = "k" }),
    available = {},
    shinyAvailable = {},
    backAvailable = {},
    backShinyAvailable = {},
    backStaticAvailable = {},
    backStaticShinyAvailable = {},
    staticAvailable = {},
    staticShinyAvailable = {},
    grayscaleAvailable = {},
    backGrayscaleAvailable = {},
    frontAnimatedAvailable = { normal = {}, shiny = {}, grayscale = {} },
    backAnimatedAvailable = { normal = {}, shiny = {}, grayscale = {} },
    activeBackSpecies = {},
    presentationSurfaces = {
      title = "crystal_v15 authored front",
      battle_enemy = "authored front",
      battle_player = "authored rear; static unless a real rear frame 002 exists",
      dex_entry = "crystal_v15 authored front",
      summary = "crystal_v15 authored front",
      box_stats = "SummaryMenu authored front",
      hall_of_fame = "crystal_v15 authored front",
      follower = "owned by follower walking renderer",
      wild_overworld = "owned by Wilds walking renderer",
      voxel = "owned by Voxel renderer",
    },
  }
  local dexFor = {}
  local imageCache = {}
  local okPalette, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not okPalette then PaletteFX = nil end

  for index, species in ipairs(speciesOrder) do
    local dex = 151 + index
    dexFor[species] = dex
  end

  local function durations(dex, which, side)
    if side == "back" then
      local backs = type(animationData.back) == "table"
        and animationData.back[which]
      local timing = type(backs) == "table" and backs[tostring(dex)] or nil
      if type(timing) == "table" then return timing end
      -- Native/v1.5 rear packs predate explicit rear timing and intentionally
      -- share the front clock. New private-slot packs publish `{1000}` here
      -- so a single supplied rear pose can never inherit front motion.
    end
    local group = animationData[which]
    return type(group) == "table" and group[tostring(dex)] or nil
  end

  local function scanDex(dex)
    A.staticAvailable[dex] =
      mod:read(("assets/crystal_animated/front/normal/%d/001.png"):format(dex))
        ~= nil
    A.staticShinyAvailable[dex] =
      mod:read(("assets/crystal_animated/front/shiny/%d/001.png"):format(dex))
        ~= nil
    A.grayscaleAvailable[dex] =
      mod:read(("assets/crystal_animated/front/grayscale/%d/001.png"):format(dex))
        ~= nil
    A.available[dex] = A.staticAvailable[dex]
      and type(durations(dex, "normal", "front")) == "table"
    A.shinyAvailable[dex] = A.staticShinyAvailable[dex]
      and type(durations(dex, "shiny", "front")) == "table"
    A.backStaticAvailable[dex] =
      mod:read(("assets/crystal_animated/back/normal/%d/001.png"):format(dex))
        ~= nil
    A.backAvailable[dex] = A.backStaticAvailable[dex]
      and type(durations(dex, "normal", "back")) == "table"
    A.backStaticShinyAvailable[dex] =
      mod:read(("assets/crystal_animated/back/shiny/%d/001.png"):format(dex))
        ~= nil
    A.backShinyAvailable[dex] = A.backStaticShinyAvailable[dex]
      and type(durations(dex, "shiny", "back")) == "table"
    A.backGrayscaleAvailable[dex] =
      mod:read(("assets/crystal_animated/back/grayscale/%d/001.png"):format(dex))
        ~= nil
    for _, which in ipairs({ "normal", "shiny", "grayscale" }) do
      A.frontAnimatedAvailable[which][dex] =
        mod:read(("assets/crystal_animated/front/%s/%d/002.png")
          :format(which, dex)) ~= nil
      A.backAnimatedAvailable[which][dex] =
        mod:read(("assets/crystal_animated/back/%s/%d/002.png")
          :format(which, dex)) ~= nil
      local timing = durations(dex, which, "back")
      local frameCount = math.max(1, type(timing) == "table" and #timing or 1)
      local registry = mod.content and mod.content.battle_sprite_scales
      if registry and registry.register then
        for frame = 1, frameCount do
          local relative = ("assets/crystal_animated/back/%s/%d/%03d.png")
            :format(which, dex, frame)
          if mod:read(relative) ~= nil then
            registry:register(("KA_CRYSTAL_BACK_%s_%03d_%03d")
              :format(which:upper(), dex, frame), {
                path = mod.path .. "/" .. relative,
                scale = 1,
              })
          end
        end
      end
    end
  end
  for dex = 1, 251 do scanDex(dex) end
  for dex in pairs(guestDexes) do scanDex(dex) end

  local function resolveDex(ctx)
    if not (ctx and ctx.species) then return nil end
    if dexFor[ctx.species] then return dexFor[ctx.species] end
    local data = ctx.data or (A.game and A.game.data)
    local def = data and data.pokemon and data.pokemon[ctx.species]
    local dex = def and tonumber(def.dex)
    if dex and dex >= 1 and (dex <= 251 or guestDexes[dex]) then
      dexFor[ctx.species] = dex
      return dex
    end
    return nil
  end

  local function dexForSpecies(species, data)
    if dexFor[species] then return dexFor[species] end
    data = data or (A.game and A.game.data)
    local def = data and data.pokemon and data.pokemon[species]
    local dex = def and tonumber(def.dex)
    if dex and dex >= 1 and (dex <= 251 or guestDexes[dex]) then
      dexFor[species] = dex
      return dex
    end
    return nil
  end

  local function externalKantoActive(dex)
    if not (dex and dex <= 151) then return false end
    if mod and type(mod.find) == "function" then
      local ok, handle = pcall(function()
        return mod.find("crystal_animated_sprites_with_shiny_visuals")
      end)
      local exports = ok and type(handle) == "table" and handle.exports or nil
      return type(exports) == "table"
    end
    return false
  end

  local function artEnabled(dex)
    if not dex then return false end
    if guestDexes[dex] then return true end
    if dex >= 1 and dex <= 251
        and mod.options:get("pokemon_sprite_style") ~= "legacy" then
      return mod.options:get("pokemon_sprite_style") == "crystal"
        and mod.options:get("sprite_style_battle") ~= false
    end
    if dex <= 151 then
      return mod.options:get("kanto_crystal_art") ~= false
        and not externalKantoActive(dex)
    end
    return mod.options:get("legend_art") == "crystal"
  end

  local function motionEnabled(dex)
    return artEnabled(dex)
      and mod.options:get("crystal_animation") ~= false
  end

  local function variant(mon)
    return shinySystem and shinySystem.isShiny(mon) and "shiny" or "normal"
  end

  local function advancedColor()
    -- The headless SDK has no renderer and therefore no active COLORS pass;
    -- keep its historical true-colour contract.  In-game LÖVE is present and
    -- PaletteFX.mode is normally the authoritative live mode.  Voxel is a
    -- full-colour world pipeline, however: feeding its battle overlay the
    -- grayscale GBC source made (among others) Pikachu appear gray inside an
    -- otherwise coloured scene.  In that presentation the authored colour
    -- Crystal frames are the compatible source regardless of the stored
    -- flat-renderer palette mode.
    if rawget(_G, "love") == nil or love.image == nil then return true end
    local ok, Pipelines = pcall(require, "src.render.Pipelines")
    if ok and type(Pipelines.level) == "function"
        and Pipelines.level("voxel") > 0 then
      return true
    end
    return not PaletteFX or PaletteFX.mode == nil or PaletteFX.mode == "redpp"
  end

  local function displayVariant(which, dex, side, surface)
    -- FireRed-style UI surfaces already render in authored full colour.  A
    -- saved GBC/SGB battle palette must not silently replace their Crystal
    -- art with the grayscale source; that made every Box preview (most
    -- visibly Pidgey) look like a missing/placeholder sprite.  Battles keep
    -- the palette-aware grayscale route, while menus preserve normal/shiny.
    if surface and surface ~= "battle" then return which end
    -- Private guest species normally have no ROM-era monochrome identity,
    -- so their authored colour remains authoritative. Gorochu is the one
    -- deliberate exception: its player-facing CLASSIC choice uses a reviewed
    -- black-and-white rendition of the same P-Infinity geometry instead of
    -- silently keeping the colour card. The live COLORS hotkey follows the
    -- same rule, while every other private #252-279 guest stays unchanged.
    if classicGuestDexes[dex]
        and (mod.options:get("pokemon_sprite_style") ~= "crystal"
          or not advancedColor()) then
      if side == "back" and A.backGrayscaleAvailable[dex] then
        return "grayscale"
      elseif side ~= "back" and A.grayscaleAvailable[dex] then
        return "grayscale"
      end
    end
    -- Guest species have no ROM-era DMG palette identity to preserve. Their
    -- bundled normal/shiny cards are the authoritative colours on every
    -- surface; falling back to `normal` here erased every #252-279 battle
    -- shiny whenever the player used a non-ADVANCED display mode.
    if guestDexes[dex] then return which end
    if advancedColor() then return which end
    if side == "back" then
      if A.backGrayscaleAvailable[dex] then return "grayscale" end
    elseif A.grayscaleAvailable[dex] then
      return "grayscale"
    end
    -- A grayscale shiny is intentionally identical to the normal form.
    return "normal"
  end

  local function authoredTrueColor(dex, which)
    -- Gorochu's CLASSIC card is itself the reviewed four-shade artwork. Keep
    -- those exact neutral shades instead of feeding them through a second
    -- SGB/DMG colour transform (which turned the requested black-and-white
    -- sprite green). Other grayscale packs retain their historical palette
    -- pass contract.
    return which ~= "grayscale" or classicGuestDexes[dex] == true
  end

  local function relativePath(dex, which, frame, side)
    return ("assets/crystal_animated/%s/%s/%d/%03d.png")
      :format(side or "front", which, dex, frame or 1)
  end

  local function fullPath(dex, which, frame, side)
    return mod.path .. "/" .. relativePath(dex, which, frame, side)
  end

  local function clearSelection(mon)
    if mon then A.selected[mon] = nil end
  end

  -- Static presentation seam for the Pokédex. It needs only species/data,
  -- deliberately ignores every battle-art/animation option and never reads
  -- or writes A.selected.
  function A.staticFrameOne(ctx, selectedSide, which)
    local dex = resolveDex(ctx)
    selectedSide = selectedSide == "back" and "back" or "front"
    which = which == "shiny" and "shiny" or "normal"
    if not dex then return nil end
    which = displayVariant(which, dex, selectedSide, ctx and ctx.kind)
    local ready
    if selectedSide == "back" then
      if which == "grayscale" then
        ready = A.backGrayscaleAvailable[dex]
      elseif which == "shiny" then
        ready = A.backStaticShinyAvailable[dex]
      else
        ready = A.backStaticAvailable[dex]
      end
    else
      if which == "grayscale" then
        ready = A.grayscaleAvailable[dex]
      elseif which == "shiny" then
        ready = A.staticShinyAvailable[dex]
      else
        ready = A.staticAvailable[dex]
      end
    end
    if not ready then return nil end
    return fullPath(dex, which, 1, selectedSide),
      authoredTrueColor(dex, which)
  end

  -- Called by the final sprite resolver. Returning a path means frame one
  -- should replace the bundled still; nil leaves the still/back/other-mod
  -- result untouched.
  function A.select(ctx, selectedSide, externalOverride)
    if not (ctx and ctx.kind == "battle") then return nil end
    local mon = ctx and ctx.mon
    if mon and selectedSide == "front" then
      -- Recomputed on every battle-front resolution. A later visual provider,
      -- legacy style, or Mega route must be able to withdraw ownership
      -- without leaving a stale native-2D placement adjustment behind.
      A.activeFrontMons[mon] = nil
    end
    local dex = resolveDex(ctx)
    local supportedSide = selectedSide == "front"
      or (selectedSide == "back" and dex and (
        A.backStaticAvailable[dex] or A.backStaticShinyAvailable[dex]
          or A.backGrayscaleAvailable[dex]))
    if not (mon and dex and ctx.kind == "battle"
        and supportedSide)
        or externalOverride or not artEnabled(dex)
        or mon._ascMegaForm or mon.ascMegaForm then
      clearSelection(mon)
      return nil
    end
    local which = displayVariant(variant(mon), dex, selectedSide, "battle")
    local ready
    if selectedSide == "back" then
      if which == "grayscale" then
        ready = A.backGrayscaleAvailable[dex]
      else
        ready = which == "shiny"
          and A.backShinyAvailable[dex] or A.backAvailable[dex]
      end
    else
      if which == "grayscale" then
        ready = A.grayscaleAvailable[dex]
      else
        ready = which == "shiny"
          and A.staticShinyAvailable[dex] or A.staticAvailable[dex]
      end
    end
    if not ready then
      clearSelection(mon)
      return nil
    end
    local timing = durations(dex, which, selectedSide)
    local animatedSide = selectedSide == "back"
      and A.backAnimatedAvailable[which][dex]
      or selectedSide == "front" and A.frontAnimatedAvailable[which][dex]
    if motionEnabled(dex) and animatedSide
        and timing and #timing > 1 then
      A.selected[mon] = {
        species = ctx.species,
        dex = dex,
        side = selectedSide,
        variant = which,
        durations = timing,
      }
    else
      clearSelection(mon)
    end
    if selectedSide == "front" then
      -- This marker is deliberately independent from animation state: a
      -- static Crystal frame needs the same 2D clearance as a moving one.
      A.activeFrontMons[mon] = true
    end
    ctx.trueColor = authoredTrueColor(dex, which)
    return fullPath(dex, which, 1, selectedSide), ctx.trueColor
  end

  local function readPixels(image)
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

  local function transformedPalette(data)
    if PaletteFX and type(PaletteFX.monPal) == "function" then
      local ok, colors = pcall(PaletteFX.monPal, data, "DITTO")
      if ok and type(colors) == "table" and #colors >= 4 then return colors end
    end
    return {
      { 255, 255, 255 }, { 216, 160, 224 },
      { 144, 80, 168 }, { 48, 24, 64 },
    }
  end

  local function visionGoldPalette()
    return {
      { 255, 252, 208 }, { 255, 216, 48 },
      { 216, 136, 0 }, { 88, 48, 0 },
    }
  end

  local function preparedImage(image, side, tint)
    if not image then return nil end
    local data = (tint or side) and readPixels(image) or nil
    if not data then return image end
    if tint then
      pcall(function()
        data:mapPixel(function(_, _, r, g, b, a)
          if a == 0 then return r, g, b, a end
          local y = 0.299 * r + 0.587 * g + 0.114 * b
          local color = y > 0.83 and tint[1] or y > 0.5 and tint[2]
            or y > 0.17 and tint[3] or tint[4]
          local scale = (color[1] or 0) > 1 and 255 or 1
          return color[1] / scale, color[2] / scale,
            color[3] / scale, a
        end)
      end)
    end
    if side then
      local w, h = data:getDimensions()
      local bottom = h - 1
      while bottom >= 0 do
        local opaque = false
        for x = 0, w - 1 do
          local _, _, _, alpha = data:getPixel(x, bottom)
          if alpha > 0 then opaque = true; break end
        end
        if opaque then break end
        bottom = bottom - 1
      end
      local left = 0
      if side == "back" and bottom >= 0 then
        while left < w do
          local opaque = false
          for y = 0, bottom do
            local _, _, _, alpha = data:getPixel(left, y)
            if alpha > 0 then opaque = true; break end
          end
          if opaque then break end
          left = left + 1
        end
      end
      if bottom >= 0 and (bottom < h - 1 or left > 0)
          and love.image and love.image.newImageData then
        local okCrop, cropped = pcall(love.image.newImageData,
          w - left, bottom + 1)
        if okCrop and cropped then
          local okPixels = pcall(function()
            for y = 0, bottom do
              for x = left, w - 1 do
                cropped:setPixel(x - left, y, data:getPixel(x, y))
              end
            end
          end)
          if okPixels then data = cropped end
        end
      end
    end
    local ok, out = pcall(love.graphics.newImage, data)
    if not (ok and out) then return image end
    if out.setFilter then out:setFilter("nearest", "nearest") end
    return out
  end

  local function loadImage(path, opts)
    opts = opts or {}
    local key = path .. "#" .. tostring(opts.side or "raw")
      .. "#" .. tostring(opts.tintTag or "plain")
    if imageCache[key] then return imageCache[key] end
    if not (love and love.graphics and love.graphics.newImage) then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if not (ok and image) then return nil end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    image = preparedImage(image, opts.side, opts.tint)
    imageCache[key] = image
    return image
  end

  local function stateImage(state, frame, data)
    local tint = state.visionGold and visionGoldPalette()
      or state.transformed and transformedPalette(data) or nil
    return loadImage(fullPath(state.dex, state.variant, frame, state.side), {
      side = state.trim and state.side or nil,
      tint = tint,
      tintTag = state.visionGold and "vision-gold"
        or state.transformed and "ditto" or nil,
    })
  end

  local function resetBattler(battle, battler)
    local mon = battler and battler.mon
    if not mon or mon._ascMegaForm or mon.ascMegaForm then
      if battler then battler.__ascendantCrystalAnimation = nil end
      if mon then A.activeBackSpecies[mon.species] = nil end
      return nil
    end
    local transformed = battler.__ascendantCrystalTransformed
    local visionGold = battle and battle.ascendantVision == "ho_oh"
      and battle.enemy == battler and mon.species == "HO_OH"
    local selected = not transformed and A.selected[mon] or nil
    local state
    if transformed then
      local dex = dexForSpecies(transformed, battle and battle.data)
      local side = battle and battle.player == battler and "back" or "front"
      local timing = dex and durations(dex, "normal", side)
      if not (dex and timing and #timing > 0 and motionEnabled(dex)) then
        battler.__ascendantCrystalAnimation = nil
        return nil
      end
      state = {
        species = transformed, dex = dex, side = side, variant = "normal",
        durations = timing, frame = 1, elapsed = 0, transformed = true,
        trim = true,
        animated = side == "back" and A.backAnimatedAvailable.normal[dex]
          or side == "front" and A.frontAnimatedAvailable.normal[dex],
        visionGold = visionGold,
      }
    elseif selected then
      local expected = displayVariant(variant(mon), selected.dex, selected.side)
      if selected.species ~= mon.species or selected.variant ~= expected then
        battler.__ascendantCrystalAnimation = nil
        return nil
      end
      state = {
        species = selected.species,
        dex = selected.dex,
        side = selected.side or "front",
        variant = selected.variant,
        durations = selected.durations,
        frame = 1,
        elapsed = 0,
        trim = true,
        animated = selected.side == "back"
          and A.backAnimatedAvailable[selected.variant][selected.dex]
          or selected.side == "front"
            and A.frontAnimatedAvailable[selected.variant][selected.dex],
        visionGold = visionGold,
      }
    else
      battler.__ascendantCrystalAnimation = nil
      return nil
    end
    local image = stateImage(state, 1, battle and battle.data)
    if image then battler.sprite = image end
    if state.side == "back" then
      A.activeBackSpecies[mon.species] = true
    end
    state.image = image or battler.sprite
    battler.__ascendantCrystalAnimation = state
    return state
  end

  local function updateBattler(battle, battler, dt)
    local mon = battler and battler.mon
    if not mon or mon._ascMegaForm or mon.ascMegaForm then
      if battler then battler.__ascendantCrystalAnimation = nil end
      if mon then A.activeBackSpecies[mon.species] = nil end
      return
    end
    local transformed = battler.__ascendantCrystalTransformed
    local selected = not transformed and A.selected[mon] or nil
    if not transformed and not (selected and motionEnabled(selected.dex)) then
      battler.__ascendantCrystalAnimation = nil
      return
    end

    local expectedSpecies = transformed or mon.species
    local expectedVariant = transformed and "normal"
      or displayVariant(variant(mon), selected.dex, selected.side)
    if not transformed and selected.variant ~= expectedVariant then
      local ready
      if selected.side == "back" then
        ready = expectedVariant == "grayscale"
          and A.backGrayscaleAvailable[selected.dex]
          or expectedVariant == "shiny"
            and A.backStaticShinyAvailable[selected.dex]
          or expectedVariant == "normal"
            and A.backStaticAvailable[selected.dex]
      else
        ready = expectedVariant == "grayscale"
          and A.grayscaleAvailable[selected.dex]
          or expectedVariant == "shiny"
            and A.staticShinyAvailable[selected.dex]
          or expectedVariant == "normal"
            and A.staticAvailable[selected.dex]
      end
      local timing = ready
        and durations(selected.dex, expectedVariant, selected.side) or nil
      if not (ready and type(timing) == "table" and #timing > 0) then
        battler.__ascendantCrystalAnimation = nil
        clearSelection(mon)
        if selected.side == "back" then
          A.activeBackSpecies[mon.species] = nil
        end
        return
      end
      selected = {
        species = mon.species,
        dex = selected.dex,
        side = selected.side,
        variant = expectedVariant,
        durations = timing,
      }
      A.selected[mon] = selected
    end
    local state = battler.__ascendantCrystalAnimation
    if not state or state.species ~= expectedSpecies
        or state.variant ~= expectedVariant then
      state = resetBattler(battle, battler)
    elseif not transformed and state.image and battler.sprite ~= state.image then
      -- Mega Evolution or another renderer changed the live pic.  Yield
      -- instead of restoring the base species over the new presentation.
      battler.__ascendantCrystalAnimation = nil
      clearSelection(mon)
      A.activeBackSpecies[mon.species] = nil
      return
    end
    if not (state and state.animated and state.durations) then return end

    state.elapsed = state.elapsed + (tonumber(dt) or (1 / 60)) * 1000
    local changed, guard = false, 0
    while state.elapsed >= (state.durations[state.frame] or 100)
        and guard < 50 do
      state.elapsed = state.elapsed - (state.durations[state.frame] or 100)
      state.frame = state.frame + 1
      if state.frame > #state.durations then state.frame = 1 end
      changed, guard = true, guard + 1
    end
    if not changed then return end

    local image = stateImage(state, state.frame, battle and battle.data)
    if image then
      battler.sprite = image
      state.image = image
    end
  end

  function A.updateBattle(battle, dt)
    if not battle then return end
    if battle.enemy and not battle.showEnemyTrainer
        and not battle.enemySendingOut then
      if battle.ghost and not battle.enemy.__ascendantCrystalTransformed
          and mod.options:get("pokemon_sprite_style") == "crystal"
          and mod.options:get("sprite_style_battle") ~= false
          and not externalKantoActive(1) then
        local variantName = advancedColor() and "normal" or "grayscale"
        local relative = ("assets/crystal_v15/front/%s/ghost.png")
          :format(variantName)
        if mod:read(relative) ~= nil then
          local image = loadImage(mod.path .. "/" .. relative, {
            side = "front",
          })
          if image then battle.enemy.sprite = image end
        end
        battle.enemy.__ascendantCrystalAnimation = nil
      else
        updateBattler(battle, battle.enemy, dt)
      end
    end
    if battle.player and not battle.showPlayerBack and not battle.sendingOut then
      updateBattler(battle, battle.player, dt)
    end
  end

  function A.clearBattle(battle)
    if not battle then return end
    for _, battler in ipairs({ battle.player, battle.enemy }) do
      if battler then
        battler.__ascendantCrystalAnimation = nil
        battler.__ascendantCrystalTransformed = nil
      end
    end
    A.activeBackSpecies = {}
    A.activeFrontMons = setmetatable({}, { __mode = "k" })
  end

  local function native2DActive()
    local ok, Pipelines = pcall(require, "src.render.Pipelines")
    if not (ok and Pipelines and type(Pipelines.level) == "function") then
      return true
    end
    return Pipelines.level("voxel") <= 0
  end

  -- Exact Gen1Recomp 0.1.96/0.1.98 place a 56px enemy front through row 55,
  -- immediately adjacent to the player's name at row 56. Larger authored
  -- fronts cross that boundary because the engine caps placement math at a
  -- 7-tile slot but still draws the complete image. One tile left/up restores
  -- the intended field separation without changing assets or native fronts.
  function A.enemyFrontOffset(battle)
    local enemy = battle and battle.enemy
    local mon = enemy and enemy.mon
    if not (mon and enemy.sprite) or battle.showEnemyTrainer
        or not native2DActive() then
      return 0, 0
    end
    local owned = A.activeFrontMons[mon] == true
    local animation = enemy.__ascendantCrystalAnimation
    if not owned and animation and animation.side == "front" then
      owned = true
    end
    if not owned and megaEvolution
        and type(megaEvolution.usesCrystalBattleFront) == "function" then
      local ok, result = pcall(megaEvolution.usesCrystalBattleFront, mon)
      owned = ok and result == true
    end
    return owned and -8 or 0, owned and -8 or 0
  end

  function A.presentationAnimation(species, mon, side, surface, opts)
    opts = opts or {}
    side = side == "back" and "back" or "front"
    surface = surface or "scenes"
    local dex = dexForSpecies(species, opts.data)
    local forceBundled = opts.forceBundled == true
    if not dex or (not forceBundled and externalKantoActive(dex)) then
      return nil
    end
    local scope = ({
      battle = "sprite_style_battle", summary = "sprite_style_summary",
      dex = "sprite_style_dex", box = "sprite_style_box",
    })[surface] or "sprite_style_scenes"
    if not forceBundled
        and (mod.options:get("pokemon_sprite_style") ~= "crystal"
          or mod.options:get(scope) == false) then return nil end
    -- Ascendant's full engine-owned title rotation is part of its own
    -- presentation, not a gameplay sprite-style preference.  Each current
    -- native species uses its bundled normal Crystal front, even when a scene
    -- option is disabled or an external Kanto sprite provider is present.
    local which = forceBundled and "normal"
      or displayVariant(variant(mon), dex, side, surface)
    local ready
    if side == "back" then
      ready = which == "grayscale" and A.backGrayscaleAvailable[dex]
        or which == "shiny" and A.backStaticShinyAvailable[dex]
        or which == "normal" and A.backStaticAvailable[dex]
    else
      ready = which == "grayscale" and A.grayscaleAvailable[dex]
        or which == "shiny" and A.staticShinyAvailable[dex]
        or which == "normal" and A.staticAvailable[dex]
    end
    if not ready then return nil end
    local authoredTiming = durations(dex, which, side)
    local authoredFrames = side == "back"
      and A.backAnimatedAvailable[which][dex]
      or side == "front" and A.frontAnimatedAvailable[which][dex]
    local animated = type(authoredTiming) == "table"
      and #authoredTiming > 1 and authoredFrames == true
    local timing = animated and authoredTiming or { 1000 }
    local state = {
      species = species, dex = dex, side = side, variant = which,
      durations = timing, frame = 1, elapsed = 0,
      trueColor = authoredTrueColor(dex, which), trim = opts.trim == true,
      animated = animated,
      authoredTiming = animated,
    }
    state.image = stateImage(state, 1, opts.data)
    state.path = fullPath(dex, which, 1, side)
    return state
  end

  function A.advancePresentation(state, dt, game)
    if not (state and state.animated and state.durations
        and #state.durations > 1) then
      return state and state.image or nil
    end
    local speed = game and type(game.logicSpeed) == "function"
      and tonumber(game:logicSpeed()) or 1
    if not speed or speed <= 0 then speed = 1 end
    state.elapsed = state.elapsed
      + (tonumber(dt) or (1 / 60)) * 1000 / speed
    local changed, guard = false, 0
    while state.elapsed >= (state.durations[state.frame] or 100)
        and guard < 50 do
      state.elapsed = state.elapsed - (state.durations[state.frame] or 100)
      state.frame = state.frame % #state.durations + 1
      changed, guard = true, guard + 1
    end
    if changed then
      state.image = stateImage(state, state.frame, game and game.data)
        or state.image
    end
    return state.image
  end

  function A.tintDitto(image, data)
    return preparedImage(image, nil, transformedPalette(data))
  end

  function A.tintVisionGold(image)
    return preparedImage(image, nil, visionGoldPalette())
  end

  function A.install(game, deps)
    A.game = game
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    -- Animation frames are materialized as LÖVE Images after frame one, so
    -- the engine no longer has their source path for its path-keyed scale
    -- registry. Keep the active player species at Crystal's authored 1x size
    -- for those frames. The normal path registry above still owns frame one
    -- and every static presentation.
    BattleState._kantoAscendantCrystalScalePolicy = A
    if type(BattleState.resolveBattleScale) == "function"
        and not BattleState._kantoAscendantCrystalScaleWrapped then
      local resolveBattleScale = BattleState.resolveBattleScale
      BattleState.resolveBattleScale = function(data, side, path, species)
        local policy = BattleState._kantoAscendantCrystalScalePolicy
        if side == "back" and species and policy
            and policy.activeBackSpecies[species] then
          return 1
        end
        return resolveBattleScale(data, side, path, species)
      end
      BattleState._kantoAscendantCrystalScaleWrapped = true
    end
    -- Keep this seam at the engine's side-composition boundary. Passing the
    -- offset through drawPicsLayer's own sx/sy inputs covers stills, authored
    -- animation frames and send-out grow frames alike. Splitting the ordinary
    -- two-side call preserves enemy-before-player ordering while ensuring the
    -- player back, trainer pictures and every native front remain untouched.
    BattleState._kantoAscendantCrystalLayoutPolicy = A
    if type(BattleState.drawPicsLayer) == "function"
        and not BattleState._kantoAscendantCrystalLayoutWrapped then
      local drawPicsLayer = BattleState.drawPicsLayer
      BattleState.drawPicsLayer = function(battle, slide, sx, sy, onlySide,
          skipMenuClip)
        local policy = BattleState._kantoAscendantCrystalLayoutPolicy
        local dx, dy = 0, 0
        if policy and type(policy.enemyFrontOffset) == "function" then
          dx, dy = policy.enemyFrontOffset(battle)
        end
        if dx == 0 and dy == 0 or onlySide == "player" then
          return drawPicsLayer(battle, slide, sx, sy, onlySide, skipMenuClip)
        end
        local enemyX, enemyY = (tonumber(sx) or 0) + dx,
          (tonumber(sy) or 0) + dy
        if onlySide == "enemy" then
          return drawPicsLayer(battle, slide, enemyX, enemyY, onlySide,
            skipMenuClip)
        end
        drawPicsLayer(battle, slide, enemyX, enemyY, "enemy", skipMenuClip)
        return drawPicsLayer(battle, slide, sx, sy, "player", skipMenuClip)
      end
      BattleState._kantoAscendantCrystalLayoutWrapped = true
    end
    if not BattleState._ascendantCrystalAnimationWrapped then
      BattleState._ascendantCrystalAnimationWrapped = true
      local vanillaUpdate = BattleState.update
      BattleState.update = function(battle, dt)
        local result = vanillaUpdate(battle, dt)
        A.updateBattle(battle, dt)
        return result
      end
    end
    if type(BattleState.effectRecord) == "function"
        and not BattleState._ascendantCrystalTransformRecordWrapped then
      BattleState._ascendantCrystalTransformRecordWrapped = true
      local innerEffectRecord = BattleState.effectRecord
      BattleState.effectRecord = function(battle, effect)
        local record = innerEffectRecord(battle, effect)
        if effect == "TRANSFORM_EFFECT" and record
            and type(record.run) == "function"
            and not record.__ascendantCrystalTransformRun then
          record.__ascendantCrystalTransformRun = true
          local innerRun = record.run
          record.run = function(ctx)
            local result = innerRun(ctx)
            local active = ctx and ctx.battle
            if ctx and ctx.user and ctx.target and active
                and type(active.animationsOn) == "function"
                and not active:animationsOn() then
              ctx.user.__ascendantCrystalTransformed =
                ctx.target.mon and ctx.target.mon.species
              ctx.user.__ascendantCrystalAnimation = nil
            end
            return result
          end
        end
        return record
      end
    end
    if type(BattleState.applyAnimEffect) == "function"
        and not BattleState._ascendantCrystalTransformAnimWrapped then
      BattleState._ascendantCrystalTransformAnimWrapped = true
      local innerApply = BattleState.applyAnimEffect
      BattleState.applyAnimEffect = function(battle, event)
        local result = innerApply(battle, event)
        if event and event.effect == "SE_TRANSFORM_MON"
            and type(battle.animFxBattler) == "function" then
          local user = battle:animFxBattler(false)
          local target = battle:animFxBattler(true)
          if user and target and target.mon then
            user.__ascendantCrystalTransformed = target.mon.species
            user.__ascendantCrystalAnimation = nil
          end
        end
        return result
      end
    end
    if type(BattleState.speciesSprite) == "function"
        and not BattleState._ascendantCrystalTransformSpriteWrapped then
      BattleState._ascendantCrystalTransformSpriteWrapped = true
      local innerSpeciesSprite = BattleState.speciesSprite
      BattleState.speciesSprite = function(battle, species, playerSide)
        local image = innerSpeciesSprite(battle, species, playerSide)
        local dex = dexForSpecies(species, battle and battle.data)
        if not (image and dex and motionEnabled(dex)
            and not externalKantoActive(dex)) then return image end
        return A.tintDitto(image, battle and battle.data) or image
      end
    end
  end

  mod.events:on("battle.battler_switched", function(ev)
    A.clearBattle(ev and (ev.battle or ev.game))
  end)
  mod.events:on("battle.ended", function(ev)
    A.clearBattle(ev and (ev.battle or ev.game))
  end)

  function A.invalidate()
    imageCache = {}
  end

  A.externalKantoActive = externalKantoActive
  A.advancedColor = advancedColor
  A.dexForSpecies = dexForSpecies

  return A
end
