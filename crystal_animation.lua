-- Standalone Crystal image-animation controller.
--
-- Ascendant mirrors Crystal Animated Sprites with Shiny Visuals' numbered
-- frame format, but uses a separate battler field. Its bundled Kanto pack is
-- therefore usable alone and yields cleanly when an external visual mod owns
-- the live sprite.

return function(mod, opts)
  opts = opts or {}
  local animationData = opts.animationData or {}
  local voxelAnimationData = opts.voxelAnimationData or opts.hdFrontData or {}
  local pixel2DData = opts.pixel2DData or {}
  local voxelFallbackData = opts.voxelFallbackData or {}
  local neo2DData = opts.neo2DData or {}
  local shinySystem = opts.shinySystem
  local megaEvolution = opts.megaEvolution
  local voxelRenderer = opts.voxelRenderer
  local classic2DConnector=opts.classic2DConnector
  local speciesOrder = opts.speciesOrder or {}
  local guestDexes = opts.guestDexes or {}
  local classicGuestDexes = opts.classicGuestDexes or {}
  local A = {
    selected = setmetatable({}, { __mode = "k" }),
    activeFrontMons = setmetatable({}, { __mode = "k" }),
    activeBackMons = setmetatable({}, { __mode = "k" }),
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
  local function cosmeticFor(mon,species)
    return (A.battleFormProvider and A.battleFormProvider(mon,species))
      or (A.castformProvider and A.castformProvider(mon,species))
      or (A.burmyCloakProvider and A.burmyCloakProvider(mon,species))
      or (A.laterGenderProvider and A.laterGenderProvider(mon,species))
      or (A.gen3GenderProvider and A.gen3GenderProvider(mon,species))
      or (A.genderFormProvider and A.genderFormProvider(mon,species))
  end
  local imageCache = {}
  local classicRearViews = setmetatable({}, { __mode = "k" })
  local classicRearSources = setmetatable({}, { __mode = "k" })
  local classicFront = {
    views = setmetatable({}, { __mode = "k" }),
    sources = setmetatable({}, { __mode = "k" }),
  }
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

  local function voxelActive()
    local ok, Pipelines = pcall(require, "src.render.Pipelines")
    return ok and Pipelines and type(Pipelines.level) == "function"
      and Pipelines.level("voxel") > 0 or false
  end

  local arenaResolved, arenaModule = false, nil
  local function voxelArenaActive()
    -- A voxel OVERWORLD pipeline is not an active voxel BATTLE. Honor the
    -- battle provider's explicit off setting before falling back to a global
    -- render level; otherwise native fronts lose their existing HUD clearance.
    if not arenaResolved and A.game and voxelRenderer
        and type(voxelRenderer.module) == "function" then
      arenaResolved = true
      local ok, value = pcall(voxelRenderer.module, A.game,
        "OverworldBattle")
      if ok and type(value) == "table" then arenaModule = value end
    end
    if type(arenaModule) ~= "table" then return voxelActive() end
    if type(arenaModule.enabled) == "function" then
      local ok, value = pcall(arenaModule.enabled)
      if ok then return value == true end
    end
    local setting = arenaModule.setting
    if type(setting) == "table" and type(setting.get) == "function" then
      local ok, value = pcall(setting.get, setting)
      if ok then return value ~= false and value ~= nil end
    end
    return voxelActive()
  end

  local function native2DActive(battle,mon)
    if not voxelArenaActive() then return true end
    -- A selected VASC mode is not proof that this exact battle has a scene.
    -- Only the bounded cosmetic owner may use this exception, and only on
    -- VASC's explicit public native-fallback receipt. Never infer fallback
    -- from an absent/pending shot or move protected species into our layout.
    if not (battle and mon and cosmeticFor(mon,mon.species) and voxelRenderer
        and type(voxelRenderer.module)=='function') then return false end
    local ok,renderer=pcall(voxelRenderer.module,battle.game,'OverworldBattle')
    if not ok or type(renderer)~='table' or type(renderer.hudSnapReceipt)~='function' then return false end
    local read,receipt=pcall(renderer.hudSnapReceipt,battle)
    return read and type(receipt)=='table'
      and receipt.schema=='voxel-ascendant/hud-snap/v1'
      and receipt.reason=='scene-cover-unavailable' and receipt.snapped==false
      and receipt.shot==nil or false
  end

  local function battleMotionActive(surface, source)
    -- Preserve the established #001-251 Crystal animation owner. The strict
    -- static rule concerns the new Gen-II-style #252+ classic-battle provider
    -- (`pixel2d`); its one-frame timing can never animate. The user's Crystal
    -- profile now also owns real Neo pixel motion after #251 in native 2D.
    return surface ~= "battle" or voxelArenaActive() or source == "crystal"
      or source == "neo_2d"
  end

  local function dataRow(data,dex)
    return data[tostring(dex)] or data[dex]
  end
  local function voxelRow(dex)return dataRow(voxelAnimationData,dex)end
  local function voxelVariantRow(dex,which)
    local row=voxelRow(dex)
    if not row then return nil end
    if type(row.variants)=="table"then return row.variants[which]end
    if which=="normal"then return row end
    return nil
  end
  local function pixelRow(dex,source)
    return dataRow(source=="voxel_static_2d" and voxelFallbackData or pixel2DData,dex)
      or dataRow(pixel2DData,dex)
  end
  local function neoRow(dex,which,side)
    local row=dataRow(neo2DData,dex)
    return row and row[(side or "front")..(which=="shiny"and"Shiny"or"")]
  end
  local function optionEnabled(key)
    if mod.options and type(mod.options.get)=="function"then
      local ok,value=pcall(mod.options.get,mod.options,key)
      if ok and value==false then return false end
    end
    return true
  end
  local function pixelPath(row,which,side)
    if not row then return nil end
    if side=="back"then return which=="shiny"and row.backShiny or row.back end
    return which=="shiny"and row.frontShiny or row.front
  end
  local function voxelSurfaceActive(surface)
    surface=type(surface)=="string"and surface:lower()or surface
    if surface and not({battle=true,voxel=true,voxel_map=true,
        voxel_disk=true,voxel_arena=true})[surface]then return false end
    if surface=="battle"then return voxelArenaActive()end
    return voxelActive()
  end
  local function voxelFrontEnabled(dex, which, side, surface)
    local row=voxelVariantRow(dex,which)
    if side~="front"or not row then
      return false
    end
    return optionEnabled("non_crystal_voxel_animations")
      and voxelSurfaceActive(surface)
      and mod:read((row.root .. "/001.png")) ~= nil
  end

  -- A VASC surface must never fall back to the discarded 3DS-style set.
  -- Where Gen-II-Neo has no real multi-frame variant, reuse the separate
  -- reviewed static 2D front. The 2D Card can still be switched off on its
  -- own; in that case this provider yields to the previous renderer.
  local function voxelStaticFrontEnabled(dex,which,side,surface)
    if side~="front"or which=="grayscale"or voxelVariantRow(dex,which)
        or not voxelSurfaceActive(surface)then return false end
    local row=pixelRow(dex,"voxel_static_2d");local path=pixelPath(row,which,"front")
    return optionEnabled("non_crystal_voxel_animations")
      and optionEnabled("non_crystal_pixel_2d")
      and path~=nil and mod:read(path)~=nil
  end

  local function pixel2DEnabled(dex,which,side,surface)
    local row=pixelRow(dex);local path=pixelPath(row,which,side)
    if not row or not path or (surface=="battle"and voxelArenaActive())
        or (surface~="battle"and voxelActive()) or which=="grayscale"then
      return false
    end
    if surface and surface~="battle"then return false end
    return optionEnabled("non_crystal_pixel_2d")and mod:read(path)~=nil
  end

  local function sourceFor(dex, which, side, surface)
    if voxelFrontEnabled(dex,which,side,surface)then return"voxel_hd"end
    if voxelStaticFrontEnabled(dex,which,side,surface)then
      return"voxel_static_2d"
    end
    local neo=neoRow(dex,which,side)
    if surface=="battle" and not voxelArenaActive() and neo
        and which~="grayscale" and not classicGuestDexes[dex]
        and mod.options:get("pokemon_sprite_style")=="crystal"
        and optionEnabled("sprite_style_battle")
        and optionEnabled("non_crystal_pixel_2d")
        and mod:read(neo.root.."/001.png")~=nil then return"neo_2d"end
    -- Canonical #252-721 art from the reviewed Gen-2-style library owns both
    -- classic 2D sides. This check precedes the retained animated-detail
    -- still so a 2D fight cannot silently show a VASC/3DS-derived front.
    local pixel = pixelRow(dex)
    if pixel and pixel.preferPixel2D
        and pixel2DEnabled(dex,which,side,surface)then return"pixel2d"end
    if pixel2DEnabled(dex,which,side,surface)then return"pixel2d"end
    return"crystal"
  end

  local function sourceDurations(dex, which, side, source)
    if source=="neo_2d"then return neoRow(dex,which,side).durations end
    local row = source == "voxel_hd" and voxelVariantRow(dex,which) or nil
    if source=="pixel2d"or source=="voxel_static_2d"then return{1000}end
    return row and row.durations or durations(dex, which, side)
  end

  local function assetPresence(path)
    if type(mod.info)=='function' then
      local info=mod:info(path)
      return info and info.type=='file' and (info.size==nil or info.size>0) and true or nil
    end
    return mod:read(path)
  end
  local function scanDex(dex, presenceOnly)
    A.staticAvailable[dex] =
      assetPresence(("assets/crystal_animated/front/normal/%d/001.png"):format(dex))
        ~= nil
    A.staticShinyAvailable[dex] =
      assetPresence(("assets/crystal_animated/front/shiny/%d/001.png"):format(dex))
        ~= nil
    A.grayscaleAvailable[dex] =
      assetPresence(("assets/crystal_animated/front/grayscale/%d/001.png"):format(dex))
        ~= nil
    A.available[dex] = A.staticAvailable[dex]
      and type(durations(dex, "normal", "front")) == "table"
    A.shinyAvailable[dex] = A.staticShinyAvailable[dex]
      and type(durations(dex, "shiny", "front")) == "table"
    A.backStaticAvailable[dex] =
      assetPresence(("assets/crystal_animated/back/normal/%d/001.png"):format(dex))
        ~= nil
    A.backAvailable[dex] = A.backStaticAvailable[dex]
      and type(durations(dex, "normal", "back")) == "table"
    A.backStaticShinyAvailable[dex] =
      assetPresence(("assets/crystal_animated/back/shiny/%d/001.png"):format(dex))
        ~= nil
    A.backShinyAvailable[dex] = A.backStaticShinyAvailable[dex]
      and type(durations(dex, "shiny", "back")) == "table"
    A.backGrayscaleAvailable[dex] =
      assetPresence(("assets/crystal_animated/back/grayscale/%d/001.png"):format(dex))
        ~= nil
    for _, which in ipairs({ "normal", "shiny", "grayscale" }) do
      local frontTiming = durations(dex, which, "front")
      local backTiming = durations(dex, which, "back")
      A.frontAnimatedAvailable[which][dex] =
        type(frontTiming) == "table" and #frontTiming > 1 and
        assetPresence(("assets/crystal_animated/front/%s/%d/002.png")
          :format(which, dex)) ~= nil
      A.backAnimatedAvailable[which][dex] =
        type(backTiming) == "table" and #backTiming > 1 and
        assetPresence(("assets/crystal_animated/back/%s/%d/002.png")
          :format(which, dex)) ~= nil
      local timing = backTiming
      local frameCount = math.max(1, type(timing) == "table" and #timing or 1)
      local registry = mod.content and mod.content.battle_sprite_scales
      if not presenceOnly and registry and registry.register then
        for frame = 1, frameCount do
          local relative = ("assets/crystal_animated/back/%s/%d/%03d.png")
            :format(which, dex, frame)
          local optional=mod.exports and mod.exports.optionalPokemonAssets
          if assetPresence(relative) ~= nil or (optional and optional.declared(relative)) then
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
    local cosmetic=cosmeticFor(ctx.mon,ctx.species)
    if cosmetic and guestDexes[cosmetic.artSlot] and pixelRow(cosmetic.artSlot) then
      -- Per-mon cosmetic state must never enter the species-wide dex cache.
      return cosmetic.artSlot
    end
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

  local function relativePath(dex, which, frame, side, source)
    local row = source=="voxel_hd"and voxelVariantRow(dex,which)
      or source=="neo_2d"and neoRow(dex,which,side)or nil
    if row then
      return ("%s/%03d.png"):format(row.root, frame or 1)
    end
    if source=="pixel2d"or source=="voxel_static_2d"then
      return pixelPath(pixelRow(dex,source),which,side)
    end
    return ("assets/crystal_animated/%s/%s/%d/%03d.png")
      :format(side or "front", which, dex, frame or 1)
  end

  local function fullPath(dex, which, frame, side, source)
    return mod.path .. "/" .. relativePath(dex, which, frame, side, source)
  end

  local function clearSelection(mon)
    if mon then
      A.selected[mon] = nil
    end
  end

  -- Static presentation seam for the Pokédex. It needs only species/data,
  -- deliberately ignores every battle-art/animation option and never reads
  -- or writes A.selected.
  function A.staticFrameOne(ctx, selectedSide, which)
    local dex = resolveDex(ctx)
    selectedSide = selectedSide == "back" and "back" or "front"
    which = which == "shiny" and "shiny" or "normal"
    if not dex then return nil end
    local cosmetic=cosmeticFor(ctx.mon,ctx.species)
    if cosmetic and cosmetic.artSlot==dex then
      return fullPath(dex,which,1,selectedSide,'pixel2d'),true
    end
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
    if mon and selectedSide == "back" then
      -- The provider is resolved again for every player battler.  Clearing
      -- both markers here prevents a previous static guest back from
      -- retaining its scale after a Mega/external/native sprite takes over.
      A.activeBackMons[mon] = nil
    end
    local dex = resolveDex(ctx)
    local which = mon and dex
      and displayVariant(variant(mon), dex, selectedSide, "battle")or"normal"
    local source = dex and sourceFor(dex, which, selectedSide,"battle")or"crystal"
    local cosmetic=cosmeticFor(mon,ctx.species)
    if cosmetic and cosmetic.artSlot==dex and (not cosmetic.animated or source=='crystal') then
      -- Keep the native battler's correct cosmetic identity ready even when
      -- VASC is selected or the optional artwork replacement is disabled.
      -- VASC's separate full-front provider still owns its displayed texture.
      source='pixel2d'
    end
    local supportedSide = source~="crystal"or selectedSide == "front"
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
    local ready
    if source ~= "crystal" then
      ready = true
    elseif selectedSide == "back" then
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
    local timing = sourceDurations(dex, which, selectedSide, source)
    local animatedSide = (source == "voxel_hd" or source == "neo_2d") and timing and #timing > 1
      or selectedSide == "back"
      and A.backAnimatedAvailable[which][dex]
      or selectedSide == "front" and A.frontAnimatedAvailable[which][dex]
    if battleMotionActive(ctx.kind, source) and motionEnabled(dex)
        and animatedSide
        and timing and #timing > 1 then
      A.selected[mon] = {
        species = ctx.species,
        dex = dex,
        side = selectedSide,
        variant = which,
        source = source,
        durations = timing,
      }
    else
      clearSelection(mon)
    end
    if selectedSide == "front" then
      -- This marker is deliberately independent from animation state: a
      -- static Crystal frame needs the same 2D clearance as a moving one.
      local row = source=="voxel_hd"and voxelVariantRow(dex,which)
        or source=="neo_2d"and neoRow(dex,which,selectedSide)
        or (source=="pixel2d"or source=="voxel_static_2d")
          and pixelRow(dex,source)or nil
      -- Appended backend cards may omit scale (native default is 1). They
      -- still own their placement: nil would bypass the connector entirely.
      -- Keep nil for original Crystal rows with no replacement card.
      local scale = row and (tonumber(row.scale) or 1) or nil
      A.activeFrontMons[mon] = {
        source=source, dex=dex, requestedScale=scale,
      }
    end
    if selectedSide=="back"then
      local row=source=="pixel2d"and pixelRow(dex)
        or source=="neo_2d"and neoRow(dex,which,selectedSide)or nil
      A.activeBackMons[mon]={
        source=source,dex=dex,requestedScale=row and tonumber(row.scale)or 1,
      }
    end
    ctx.trueColor = authoredTrueColor(dex, which)
    return fullPath(dex, which, 1, selectedSide, source), ctx.trueColor
  end

  local function readPixels(image)
    if not (image and love and love.graphics) then return nil end
    local okData, data = pcall(image.getData, image)
    if okData and data and data.clone then
      local okClone, clone = pcall(data.clone, data)
      if okClone then return clone end
    end
    local g=love.graphics
    -- Pixel extraction must be independent of the screen that requested it.
    -- A late presentation frame may arrive with a palette shader, viewport
    -- transform or scissor still active; baking those into the cache corrupts
    -- otherwise correct normal/shiny artwork for the rest of the session.
    if not (g.push and g.pop and g.origin and g.setShader and g.setScissor
        and g.setBlendMode) then return nil end
    local previousCanvas = g.getCanvas and g.getCanvas() or nil
    g.push('all')
    local ok, out = pcall(function()
      local w, h = image:getDimensions()
      local canvas = g.newCanvas(w, h, { dpiscale = 1 })
      g.setCanvas(canvas)
      g.origin();g.setShader();g.setScissor()
      g.setBlendMode('replace','premultiplied')
      g.clear(0, 0, 0, 0)
      g.setColor(1, 1, 1, 1)
      g.draw(image, 0, 0)
      -- LOVE cannot read back a Canvas while it is an active render target.
      -- Detach it before extraction; pop('all') restores the caller target.
      g.setCanvas()
      return canvas:newImageData()
    end)
    -- Bind the caller's target before restoring its scissor. Its vertical
    -- origin depends on target height, not the scratch/window framebuffer.
    if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
    g.pop()
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

  -- Static fallback canvases carry transparent export padding, not body size.
  -- Keep this restricted to the owned canonical 96px fallback: authored
  -- Crystal/Neo frames, forms and the selected 48px masters are untouched.
  local function paddedClassicSource(owner,mon,source,side)
    local row=owner and owner.source=='pixel2d' and pixelRow(owner.dex)
    local dex=row and tonumber(row.sourceDex)
    if not(row and mon and row.species==mon.species and dex and dex>721
        and dex<=1025 and tonumber(row.pokeapiId)==dex
        and mon.species~='GOROCHU' and not mon._ascMegaForm
        and not mon.ascMegaForm and source
        and (not owner.liveSprite or owner.liveSprite==source))then return false end
    local path=row[side]
    if type(path)~='string' or not path:match('^assets/non_crystal_pixel_2d_67/')then return false end
    local w,h=source:getDimensions()
    return w==96 and h==96
  end

  local function classicBodyView(source,views,sources)
    local view=views[source]
    if view~=nil then return view or source end
    local g=love and love.graphics
    if not(g and g.push and love.image and love.image.newImageData)then return source end
    local previous=g.getCanvas and g.getCanvas() or nil
    g.push('all')
    local ok,result=pcall(function()
      g.setShader();g.setBlendMode('alpha')
      local pixels=readPixels(source)
      if not pixels then return false end
      local w,h=source:getDimensions()
      local left,top,right,bottom=w,h,-1,-1
      for y=0,h-1 do for x=0,w-1 do
        local _,_,_,alpha=pixels:getPixel(x,y)
        if alpha>0 then
          left=math.min(left,x);right=math.max(right,x)
          top=math.min(top,y);bottom=math.max(bottom,y)
        end
      end end
      if right<left or (left==0 and top==0 and right==w-1 and bottom==h-1)then return false end
      local cropped=love.image.newImageData(right-left+1,bottom-top+1)
      for y=top,bottom do for x=left,right do
        cropped:setPixel(x-left,y-top,pixels:getPixel(x,y))
      end end
      local image=g.newImage(cropped);image:setFilter('nearest','nearest')
      return image
    end)
    if g.setCanvas then
      if previous then g.setCanvas(previous)else g.setCanvas()end
    end
    g.pop()
    view=ok and result or false
    views[source]=view
    if view then sources[view]=source end
    return view or source
  end

  -- The supplied 48x48 rear masters explicitly place rows 32..47 behind
  -- the HUD. Fitting the entire master into 32px shrank the whole body and
  -- exposed its feet. Crop only the authored hidden rows, preserve pixels,
  -- and let native placement/grow/faint/menu clipping own the 32px view.
  function A.prepareClassicRear(battle)
    local battler=battle and battle.player
    local mon=battler and battler.mon
    local owner=mon and A.activeBackMons[mon]
    local row=owner and pixelRow(owner.dex)
    local source=battler and (classicRearSources[battler.sprite] or battler.sprite)
    if source and paddedClassicSource(owner,mon,source,'back')
        and native2DActive(battle,mon) and not battler.__ascendantCrystalTransformed
        and classic2DConnector and classic2DConnector.enabled()then
      battler.sprite=classicBodyView(source,classicRearViews,classicRearSources)
      return
    end
    local eligible=source and native2DActive(battle,mon) and owner
      and (owner.source=="neo_2d" or owner.source=="pixel2d"
        and row and (row.provider=="jphyper-gen2ified-2d"
          or row.rearLayout=='upper32-of-48'))
      and not mon._ascMegaForm and not battler.__ascendantCrystalTransformed
      and classic2DConnector and classic2DConnector.enabled()
    if not eligible then
      if battler and classicRearSources[battler.sprite] then battler.sprite=source end
      return
    end
    local visibleRows=(row and row.rearLayout=='full48') and 48 or 32
    local neo=owner.source=='neo_2d' and dataRow(neo2DData,owner.dex)
    -- This retained Lazarus rear places its eye below row 31. Keep the
    -- supplied fin and face intact, hiding only the bottom eight body rows.
    -- This is a source-specific viewport, not a global rear-size change.
    if tonumber(owner.dex)==368 and mon.species=='GOREBYSS' and neo
        and neo.species=='GOREBYSS' and neo.sourceDex==368
        and neo.back and neo.backShiny
        and neo.back.root=='assets/neo_crystal_2d_67/final-selection/368/back/normal'
        and neo.backShiny.root=='assets/neo_crystal_2d_67/final-selection/368/back/shiny' then
      visibleRows=40
    end
    local view=classicRearViews[source]
    if not view then
      local w,h=source:getDimensions()
      if w~=48 or h~=48 then return end
      local g=love and love.graphics
      if not(g and g.push and love.image and love.image.newImageData)then return end
      g.push('all');g.setShader();g.setBlendMode('alpha')
      local pixels=readPixels(source)
      g.pop()
      if not pixels then return end
      local left,right,bottom=48,-1,-1
      for y=0,visibleRows-1 do for x=0,47 do
        local _,_,_,a=pixels:getPixel(x,y)
        if a>0 then left=math.min(left,x);right=math.max(right,x);bottom=math.max(bottom,y)end
      end end
      if right<left then return end
      local cropped=love.image.newImageData(right-left+1,visibleRows)
      -- Transparent bottom padding is not body height. Anchor the visible
      -- upper-body cut to the HUD rather than leaving a floating air gap.
      for y=0,bottom do for x=left,right do
        cropped:setPixel(x-left,y+visibleRows-1-bottom,pixels:getPixel(x,y))
      end end
      view=love.graphics.newImage(cropped);view:setFilter('nearest','nearest')
      classicRearViews[source]=view;classicRearSources[view]=source
    end
    battler.sprite=view
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
    -- Assets.image participates in the verified DLC resolver. A direct
    -- filename load sees only the mod folder and freezes downloaded motion.
    local haveAssets, Assets = pcall(require, "src.render.Assets")
    local loader = haveAssets and type(Assets.image)=="function"
      and Assets.image or love.graphics.newImage
    local ok, image = pcall(loader, path)
    if not (ok and image) then return nil end
    if image.setFilter then
      local filter = opts.filter == "linear" and "linear" or "nearest"
      image:setFilter(filter, filter)
    end
    image = preparedImage(image, opts.side, opts.tint)
    if image and image.setFilter then
      local filter = opts.filter == "linear" and "linear" or "nearest"
      image:setFilter(filter, filter)
    end
    local metrics = mod.exports and mod.exports.battleSpriteMetrics67
    if metrics then metrics.bindImage(image, path) end
    imageCache[key] = image
    return image
  end

  local function stateImage(state, frame, data)
    local tint = state.visionGold and visionGoldPalette()
      or state.transformed and transformedPalette(data) or nil
    return loadImage(fullPath(state.dex, state.variant, frame, state.side,
      state.source), {
      side = state.source~="neo_2d" and state.trim and state.side or nil,
      tint = tint,
      -- Gen-II-Neo and its static fallback are authored pixel art. Nearest
      -- filtering keeps their deliberate edges crisp on VASC billboards.
      filter = "nearest",
      tintTag = state.visionGold and "vision-gold"
        or state.transformed and "ditto" or nil,
    })
  end

  local function battleVisualMon(battle,battler)
    local mon=battler and battler.mon
    local identity=mod.exports and mod.exports.pokemonBattleIdentity67
    local visual=mon and identity and (identity.presentationMon or identity.visualMon)(battle,battler)or mon
    return visual,visual~=mon
  end
  local function resetBattler(battle, battler)
    local mon,modernCopy = battleVisualMon(battle,battler)
    if not mon or mon._ascMegaForm or mon.ascMegaForm then
      if battler then battler.__ascendantCrystalAnimation = nil end
      if mon then
        A.activeBackMons[mon] = nil
        A.activeFrontMons[mon] = nil
      end
      return nil
    end
    local transformed = not modernCopy and battler.__ascendantCrystalTransformed
    local visionGold = battle and battle.ascendantVision == "ho_oh"
      and battle.enemy == battler and mon.species == "HO_OH"
    local selected = not transformed and A.selected[mon] or nil
    local state
    if transformed then
      local dex = dexForSpecies(transformed, battle and battle.data)
      local side = battle and battle.player == battler and "back" or "front"
      local source = dex and sourceFor(dex, "normal", side,"battle") or "crystal"
      local timing = dex and sourceDurations(dex, "normal", side, source)
      if not (dex and timing and #timing > 0 and motionEnabled(dex)
          and battleMotionActive("battle", source)) then
        battler.__ascendantCrystalAnimation = nil
        return nil
      end
      state = {
        species = transformed, dex = dex, side = side, variant = "normal",
        source = source,
        durations = timing, frame = 1, elapsed = 0, transformed = true,
        trim = true,
        animated = battleMotionActive("battle", source) and (
          (source == "voxel_hd" or source == "neo_2d") and timing and #timing > 1
          or side == "back" and A.backAnimatedAvailable.normal[dex]
          or side == "front" and A.frontAnimatedAvailable.normal[dex]),
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
        source = selected.source,
        durations = selected.durations,
        frame = 1,
        elapsed = 0,
        trim = true,
        animated = battleMotionActive("battle", selected.source) and (
          (selected.source == "voxel_hd" or selected.source == "neo_2d") and selected.durations
            and #selected.durations > 1
          or selected.side == "back"
          and A.backAnimatedAvailable[selected.variant][selected.dex]
          or selected.side == "front"
            and A.frontAnimatedAvailable[selected.variant][selected.dex]),
        visionGold = visionGold,
      }
    else
      battler.__ascendantCrystalAnimation = nil
      return nil
    end
    local image = stateImage(state, 1, battle and battle.data)
    if image then battler.sprite = image end
    if state.side == "back" then
      local row=state.source=="pixel2d"and pixelRow(state.dex)
        or state.source=="neo_2d"and neoRow(state.dex,state.variant,state.side)or nil
      local requested=row and tonumber(row.scale)or 1
      A.activeBackMons[mon]={source=state.source,dex=state.dex,
        requestedScale=requested,liveSprite=image or battler.sprite}
    end
    state.image = image or battler.sprite
    battler.__ascendantCrystalAnimation = state
    return state
  end

  local function updateBattler(battle, battler, dt)
    local mon,modernCopy = battleVisualMon(battle,battler)
    if not mon or mon._ascMegaForm or mon.ascMegaForm then
      if battler then battler.__ascendantCrystalAnimation = nil end
      if mon then
        A.activeBackMons[mon] = nil
        A.activeFrontMons[mon] = nil
      end
      return
    end
    local transformed = not modernCopy and battler.__ascendantCrystalTransformed
    local selected = not transformed and A.selected[mon] or nil
    if not transformed and not (selected and motionEnabled(selected.dex)) then
      -- Static classic-2D fronts still own the layout offset even though they
      -- deliberately have no animation state. Remember the first live image
      -- handed to the battle renderer and withdraw that ownership if another
      -- provider replaces it later. Otherwise the replacement inherits our
      -- -8/-8 Crystal clearance and is visibly knocked out of the native
      -- Gen-I track.
      local ownerRows = battle and battle.player == battler
        and A.activeBackMons or A.activeFrontMons
      local owner = ownerRows[mon]
      if owner and battler and battler.sprite then
        local live=classicFront.sources[battler.sprite]
          or classicRearSources[battler.sprite] or battler.sprite
        if owner.liveSprite == nil then
          owner.liveSprite = live
        elseif owner.liveSprite ~= live then
          ownerRows[mon] = nil
        end
      end
      battler.__ascendantCrystalAnimation = nil
      return
    end

    local expectedSpecies = transformed or mon.species
    local expectedVariant = transformed and "normal"
      or displayVariant(variant(mon), selected.dex, selected.side)
    local expectedSource = not transformed
      and sourceFor(selected.dex, expectedVariant, selected.side,"battle") or nil
    if not transformed and (selected.variant ~= expectedVariant
        or selected.source ~= expectedSource) then
      local ready
      if expectedSource ~= "crystal" then
        ready = true
      elseif selected.side == "back" then
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
      local timing = ready and sourceDurations(selected.dex, expectedVariant,
        selected.side, expectedSource) or nil
      if not (ready and type(timing) == "table" and #timing > 0) then
        battler.__ascendantCrystalAnimation = nil
        clearSelection(mon)
        A.activeFrontMons[mon] = nil
        A.activeBackMons[mon] = nil
        return
      end
      selected = {
        species = mon.species,
        dex = selected.dex,
        side = selected.side,
        variant = expectedVariant,
        source = expectedSource,
        durations = timing,
      }
      A.selected[mon] = selected
    end
    local state = battler.__ascendantCrystalAnimation
    if not state or state.species ~= expectedSpecies
        or state.variant ~= expectedVariant then
      state = resetBattler(battle, battler)
    elseif not transformed and state.image
        and (classicFront.sources[battler.sprite]
          or classicRearSources[battler.sprite] or battler.sprite) ~= state.image then
      -- Mega Evolution or another renderer changed the live pic.  Yield
      -- instead of restoring the base species over the new presentation.
      battler.__ascendantCrystalAnimation = nil
      clearSelection(mon)
      A.activeBackMons[mon] = nil
      A.activeFrontMons[mon] = nil
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
      local ownerRows=state.side=="back"and A.activeBackMons
        or A.activeFrontMons
      local owner=ownerRows[mon]
      if owner then owner.liveSprite=image end
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
    -- Layout consumers still receive the real battler. Mirror only its
    -- battle art ownership; never substitute the saved Pokemon in menus.
    for _,who in ipairs({battle.player,battle.enemy})do
      local visual,modernCopy=battleVisualMon(battle,who)
      if modernCopy then
        A.activeBackMons[who.mon]=A.activeBackMons[visual]
        A.activeFrontMons[who.mon]=A.activeFrontMons[visual]
      end
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
    A.activeBackMons = setmetatable({}, { __mode = "k" })
    A.activeFrontMons = setmetatable({}, { __mode = "k" })
  end

  -- Static backend fronts are padded to a 56px texture. That padding is not
  -- body size: fitting it to a 40px slot needlessly resamples a 35px body.
  -- Remove transparent margins only; retain every visible RGBA pixel and
  -- leave the established connector to centre/ground the complete body.
  -- Animated frames keep their shared canvas to avoid frame-to-frame jitter.
  function A.prepareClassicFront(battle)
    local battler=battle and battle.enemy
    local mon=battler and battler.mon
    local source=battler and (classicFront.sources[battler.sprite] or battler.sprite)
    local owner=mon and A.activeFrontMons[mon]
    local data=battle and (battle.data or battle.game and battle.game.data)
    local def=mon and data and data.pokemon and data.pokemon[mon.species]
    local dex=def and tonumber(def.sourceDex)
    local eligible=source and owner and owner.source=='pixel2d'
      and (not owner.liveSprite or owner.liveSprite==source)
      and native2DActive(battle,mon) and not battle.showEnemyTrainer
      and def and ((def.backendOwner=='kasc.backend.gift-species/v1'
        and dex and dex>251 and dex<=1025)
        or paddedClassicSource(owner,mon,source,'front'))
      and not def.backendForm and not def.formId and not def.isMega
      and not def.isGigantamax and mon.species~='GOROCHU'
      and not mon._ascMegaForm and not mon.ascMegaForm
      and not battler.__ascendantCrystalTransformed
      and classic2DConnector and classic2DConnector.enabled()
    if not eligible then
      if battler and classicFront.sources[battler.sprite] then battler.sprite=source end
      return
    end
    battler.sprite=classicBodyView(source,classicFront.views,classicFront.sources)
  end

  local function frontNeedsClearance(owner,mon)
    if not owner or not mon or mon.species=='GOROCHU'
        or mon._ascMegaForm or mon.ascMegaForm then return false end
    return owner.source=='neo_2d' or owner.source=='pixel2d'
      and (tonumber(owner.dex) or 0)>251
  end

  -- BattleState historically exposes only species and an image path to its
  -- scale resolver. That is insufficient when the same species is on both
  -- sides: resolving the player's back used to erase or reuse the enemy's
  -- front scale. The draw wrapper below supplies the live battle briefly, so
  -- the exact battler/mon instance and side own their own requested scale.
  function A.battleScale(battle, side, path, species, data)
    if not battle then return nil end
    local battler=side=="back"and battle.player or battle.enemy
    local mon=battleVisualMon(battle,battler)
    if not mon or not native2DActive(battle,mon) then return nil end
    local owner=side=="back"and A.activeBackMons[mon]
      or A.activeFrontMons[mon]
    local requested=owner and tonumber(owner.requestedScale)or nil
    if not requested then return nil end
    if species and mon.species and species~=mon.species
        and not (battler.mon and species==battler.mon.species and mon~=battler.mon) then return nil end
    local image=battler.sprite or path
    if side=="back" and classicRearSources[image] then
      return math.min(2,64/image:getWidth(),64/image:getHeight())
    end
    if side=='front' and classicFront.sources[image]
        and paddedClassicSource(owner,mon,classicFront.sources[image],'front')then
      requested=1 -- legacy 7/12 compensated the padded canvas, not this body
    end
    if classic2DConnector
        and type(classic2DConnector.fitScale)=="function"then
      local scale=classic2DConnector.fitScale(image,side,requested,
        mon.species or species,data or battle.data)
      if side=="front" and frontNeedsClearance(owner,mon)
          and classic2DConnector.enabled() then
        -- The native player-name row starts at 56. Keep a four-pixel gap
        -- without cutting tall authored heads off the top of the field.
        local ok,height=pcall(function()
          local _,h=image:getDimensions();return h
        end)
        if ok and type(height)=="number" and height>0 then
          scale=math.min(scale,52/height)
        end
      end
      return scale
    end
    return requested
  end

  local function protectedJohtoFrontY(owner,mon,image,dy)
    local dex=owner and tonumber(owner.dex)
    if not (owner and owner.source=='crystal' and dex and dex>151
        and dex<=251 and owner.requestedScale==nil and mon
        and not mon._ascMegaForm and not mon.ascMegaForm) then return dy end
    local ok,w,h=pcall(image.getDimensions,image)
    if not (ok and type(w)=='number' and type(h)=='number'
        and w>0 and w<=56 and h>0 and h<=56) then return dy end
    -- These protected cards use native scale, not the later-species fit.
    -- Retain their existing track where possible, but never move a complete
    -- 56px card above row zero. No crop, resize, palette or frame replacement.
    local originY=8*(7-math.max(1,math.min(7,math.floor(h/8))))
    return math.max(dy,-originY)
  end

  -- Exact Gen1Recomp 0.1.96/0.1.98 place a 56px enemy front through row 55,
  -- immediately adjacent to the player's name at row 56. Larger authored
  -- fronts cross that boundary because the engine caps placement math at a
  -- 7-tile slot but still draws the complete image. One tile left/up restores
  -- the intended field separation without changing assets or native fronts.
  function A.enemyFrontOffset(battle)
    local enemy = battle and battle.enemy
    local mon = battleVisualMon(battle,enemy)
    if not (mon and enemy.sprite) or battle.showEnemyTrainer
        or not native2DActive(battle,mon) then
      return 0, 0
    end
    local ownedRow = A.activeFrontMons[mon]
    local owned = ownedRow ~= nil
    local animation = enemy.__ascendantCrystalAnimation
    if not owned and animation and animation.side == "front" then
      owned = true
    end
    if not owned and megaEvolution
        and type(megaEvolution.usesCrystalBattleFront) == "function" then
      local ok, result = pcall(megaEvolution.usesCrystalBattleFront, mon)
      owned = ok and result == true
    end
    if ownedRow and classic2DConnector
        and type(classic2DConnector.frontOffset)=="function"then
      -- `enemyPicXY` caps geometry at seven tiles but `frontPlacement` still
      -- uses the real source dimensions. A retained-detail image larger than
      -- 56px would therefore keep its own far-away bottom/right edge pinned
      -- and land on the status card. Reconstruct the engine's unshifted
      -- source anchor, then place its centre/baseline on the already approved
      -- Ascendant target (one tile left/up from the stock 124/56 slot).
      local dx,dy=classic2DConnector.frontOffset(enemy.sprite)
      -- The authored card fits rows 0..51, leaving rows 52..55 clear before
      -- the player's name. battleScale applies the matching height cap.
      if frontNeedsClearance(ownedRow,mon) and classic2DConnector.enabled() then dy=dy+4 end
      return dx,protectedJohtoFrontY(ownedRow,mon,enemy.sprite,dy)
    end
    return owned and -8 or 0,
      protectedJohtoFrontY(ownedRow,mon,enemy.sprite,owned and -8 or 0)
  end

  -- Translate the whole Lati front at composition time, preserving the
  -- artwork at all four edges of its full 56px canvas.
  function A.enemyFlightOffset(battle)
    local enemy=battle and battle.enemy
    local mon=battleVisualMon(battle,enemy)
    local state=enemy and enemy.__ascendantCrystalAnimation
    if not (mon and state and state.animated and state.side=="front"
        and state.source=="neo_2d" and (state.dex==380 or state.dex==381)
        and state.species==mon.species and not state.transformed
        and not mon._ascMegaForm and not mon.ascMegaForm
        and not battle.showEnemyTrainer and not battle.enemySendingOut
        and native2DActive(battle,mon)) then return 0,0 end
    local elapsed,total=state.elapsed or 0,0
    for i,duration in ipairs(state.durations or {}) do
      total=total+duration
      if i<(state.frame or 1) then elapsed=elapsed+duration end
    end
    if total<=0 then return 0,0 end
    local phase=2*math.pi*(elapsed%total)/total
    return math.floor(math.sin(phase)+0.5),
      math.floor(math.cos(phase)-1+0.5)
  end

  function A.presentationAnimation(species, mon, side, surface, opts)
    opts = opts or {}
    side = side == "back" and "back" or "front"
    surface = type(surface) == "string" and surface:lower() or "scenes"
    local dex = resolveDex({species=species,mon=mon,data=opts.data})
    local forceBundled = opts.forceBundled == true
    local forceStyle = opts.forceStyle == true
    if not dex or (not forceBundled and not forceStyle and externalKantoActive(dex)) then
      return nil
    end
    local voxelSurface = ({
      voxel = true, voxel_map = true, voxel_disk = true, voxel_arena = true,
    })[surface] == true
    local scope = ({
      battle = "sprite_style_battle", summary = "sprite_style_summary",
      dex = "sprite_style_dex", box = "sprite_style_box",
    })[surface] or (voxelSurface and "sprite_style_battle"
      or "sprite_style_scenes")
    if not forceBundled and not forceStyle
        and (mod.options:get("pokemon_sprite_style") ~= "crystal"
          or mod.options:get(scope) == false) then return nil end
    -- Ascendant's full engine-owned title rotation is part of its own
    -- presentation, not a gameplay sprite-style preference.  Each current
    -- native species uses its bundled normal Crystal front, even when a scene
    -- option is disabled or an external Kanto sprite provider is present.
    local which = forceBundled and "normal"
      or displayVariant(variant(mon), dex, side, surface)
    local source = not forceBundled and sourceFor(dex, which, side,surface)
      or "crystal"
    local ready
    if source ~= "crystal" then
      ready = true
    elseif side == "back" then
      ready = which == "grayscale" and A.backGrayscaleAvailable[dex]
        or which == "shiny" and A.backStaticShinyAvailable[dex]
        or which == "normal" and A.backStaticAvailable[dex]
    else
      ready = which == "grayscale" and A.grayscaleAvailable[dex]
        or which == "shiny" and A.staticShinyAvailable[dex]
        or which == "normal" and A.staticAvailable[dex]
    end
    if not ready then return nil end
    local authoredTiming = sourceDurations(dex, which, side, source)
    local authoredFrames = (source == "voxel_hd" or source == "neo_2d") and authoredTiming
      and #authoredTiming > 1 or side == "back"
      and A.backAnimatedAvailable[which][dex]
      or side == "front" and A.frontAnimatedAvailable[which][dex]
    -- The title's atomic trainer/Pokémon cycle is an engine-owned authored
    -- presentation and intentionally ignores gameplay sprite toggles. All
    -- ordinary surfaces remain governed by the Crystal motion master.
    -- An encounter-local Crystal choice overrides style, never the motion
    -- toggle, side ownership or availability of real authored frames.
    local wantsMotion = forceStyle and mod.options:get("crystal_animation") ~= false
      or not forceStyle and motionEnabled(dex)
    local animated = (forceBundled
        or (wantsMotion and battleMotionActive(surface, source)))
      and type(authoredTiming) == "table"
      and #authoredTiming > 1 and authoredFrames == true
    local timing = animated and authoredTiming or { 1000 }
    local state = {
      species = species, dex = dex, side = side, variant = which,
      source = source,
      durations = timing, frame = 1, elapsed = 0,
      trueColor = authoredTrueColor(dex, which), trim = opts.trim == true,
      animated = animated,
      authoredTiming = animated,
    }
    state.image = stateImage(state, 1, opts.data)
    state.path = fullPath(dex, which, 1, side, source)
    return state
  end

  -- Stable seam for VASC.  MAP/DISK/ARENA deliberately request only the
  -- animated front provider; classic 2D battles never call this function.
  function A.voxelPresentationAnimation(species, mon, mode, opts)
    local surface = ({
      MAP = "voxel_map", DISK = "voxel_disk", ARENA = "voxel_arena",
      map = "voxel_map", disk = "voxel_disk", arena = "voxel_arena",
    })[mode]
    if not surface then return nil end
    return A.presentationAnimation(species, mon, "front", surface, opts)
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
    arenaResolved, arenaModule = false, nil
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
        if policy and policy._scaleBattle
            and type(policy.battleScale)=="function"then
          local owned=policy.battleScale(policy._scaleBattle,side,path,
            species,data)
          if owned then return owned end
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
        if policy and type(policy.prepareClassicFront)=="function" then
          policy.prepareClassicFront(battle)
        end
        if policy and type(policy.prepareClassicRear)=="function" then
          policy.prepareClassicRear(battle)
        end
        local function drawWithScaleContext(drawOnlySide, drawX, drawY)
          local scalePolicy=BattleState._kantoAscendantCrystalScalePolicy
          local previous=scalePolicy and scalePolicy._scaleBattle or nil
          if scalePolicy then scalePolicy._scaleBattle=battle end
          local result=drawPicsLayer(battle,slide,drawX,drawY,drawOnlySide,
            skipMenuClip)
          if scalePolicy then scalePolicy._scaleBattle=previous end
          return result
        end
        local dx, dy = 0, 0
        if policy and type(policy.enemyFrontOffset) == "function" then
          dx, dy = policy.enemyFrontOffset(battle)
        end
        if policy and type(policy.enemyFlightOffset)=="function" then
          local flightX,flightY=policy.enemyFlightOffset(battle)
          dx,dy=dx+flightX,dy+flightY
        end
        if dx == 0 and dy == 0 or onlySide == "player" then
          return drawWithScaleContext(onlySide,sx,sy)
        end
        local enemyX, enemyY = (tonumber(sx) or 0) + dx,
          (tonumber(sy) or 0) + dy
        if onlySide == "enemy" then
          return drawWithScaleContext(onlySide,enemyX,enemyY)
        end
        drawWithScaleContext("enemy",enemyX,enemyY)
        return drawWithScaleContext("player",sx,sy)
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
                and not(type(result)=='table'and result.failed)
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
        local identity=mod.exports and mod.exports.pokemonBattleIdentity67
        if identity and identity.rendering(battle)then return image end
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

  function A.refreshDownloadedAssets()
    for dex=1,251 do scanDex(dex,true)end
    for dex in pairs(guestDexes)do scanDex(dex,true)end
    A.invalidate()
  end

  -- Explicit append-only seam for the backend-gift Card. The existing owner
  -- tables remain untouched; validation completes before swapping any view.
  -- A second Crystal controller is not safe: global battle wrappers capture
  -- this instance, so new private slots must join this same renderer.
  function A.registerAdditionalArt(payload)
    if type(opts.additionalArtRegistrar)~='function' then
      return nil,'additional_art_capability_unavailable'
    end
    local result,reason=opts.additionalArtRegistrar({
      pixel=pixel2DData,native=neo2DData,voxel=voxelAnimationData,
      fallback=voxelFallbackData,guests=guestDexes,species=dexFor,
      read=function(path)return mod:read(path)end,
      optionalImageMetadata=mod.exports and mod.exports.optionalPokemonAssets and mod.exports.optionalPokemonAssets.metadata,
      optionalImageHash=mod.exports and mod.exports.optionalPokemonAssets and mod.exports.optionalPokemonAssets.imageHash,
    },payload)
    if not result then return nil,reason end
    if type(opts.additionalVoxelArtRegistrar)=='function'then
      local count,why=opts.additionalVoxelArtRegistrar(payload)
      if not count then return nil,why end
    end
    pixel2DData,neo2DData,voxelAnimationData,voxelFallbackData,guestDexes=
      result.pixel,result.native,result.voxel,result.fallback,result.guests
    for species,dex in pairs(result.species)do dexFor[species]=dex end
    A.invalidate()
    return result.count
  end

  function A.setBurmyCloakProvider(provider)
    assert(type(provider)=='function' and not A.burmyCloakProvider,'Burmy art owner already bound')
    A.burmyCloakProvider=provider
  end
  function A.setGenderFormProvider(provider)
    assert(type(provider)=='function' and not A.genderFormProvider,'Gender art owner already bound')
    A.genderFormProvider=provider
  end
  function A.setCastformProvider(provider)
    assert(type(provider)=='function' and not A.castformProvider)
    A.castformProvider=provider
  end
  function A.setBattleFormProvider(provider)
    assert(type(provider)=='function' and not A.battleFormProvider)
    A.battleFormProvider=provider
  end
  function A.setLaterGenderProvider(provider)
    assert(type(provider)=='function' and not A.laterGenderProvider,'Later gender art already bound')
    A.laterGenderProvider=provider
  end

  function A.setGen3GenderProvider(provider)
    assert(type(provider)=='function' and not A.gen3GenderProvider,'Gen 3 gender art already bound')
    A.gen3GenderProvider=provider
  end

  A.externalKantoActive = externalKantoActive
  A.advancedColor = advancedColor
  A.dexForSpecies = dexForSpecies
  A.voxelArenaActive = voxelArenaActive

  return A
end
