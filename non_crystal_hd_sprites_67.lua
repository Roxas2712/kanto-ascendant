local function optionalImage(mod,path)
  local optional=mod.exports and mod.exports.optionalPokemonAssets
  return optional and optional.allowPending(path)==true or false
end
-- Optional VASC battle-front Card for species that have no authored Crystal
-- art. Real Gen-II-Neo front animations are used when supplied; missing or
-- single-frame variants use the selected static Gen-II-style front.
--
-- Classic 2D battles never use this module. Their separate Front/Back Card,
-- as well as #001-251, Mega and Gorochu providers, remains authoritative.
-- OFF is immediate and save-neutral.

return function(mod, opts)
  opts = opts or {}
  local H = {
    CARD_ID = "KASC-66-VOXEL-NON-CRYSTAL-ANIMATION",
    OWNER = "kasc.voxel.non-crystal-animated-sprites/v1",
    VERSION = "1.0.0",
    OPTION_KEY = "non_crystal_voxel_animations",
    data = opts.data or {},
    bySpecies = {},
    fallbackBySpecies = {},
    voxelStates = setmetatable({}, { __mode="k" }),
  }
  local voxelRenderer=opts.voxelRenderer
  local fallbackData=opts.fallbackData or{}
  local shinySystem=opts.shinySystem
  local additionalArtState

  -- Backend gifts are registered after this renderer is constructed. Join
  -- their validated front catalog here as well as in the 2D controller;
  -- otherwise the live VASC sideTexture hook never learns their species.
  function H.registerAdditionalArt(payload)
    if type(opts.additionalArtRegistrar)~='function'then
      return nil,'additional_art_capability_unavailable'
    end
    local current=additionalArtState or {
      voxel=H.data,fallback=fallbackData,
      read=function(path)return mod:read(path)end,
      optionalImageMetadata=mod.exports and mod.exports.optionalPokemonAssets and mod.exports.optionalPokemonAssets.metadata,
      optionalImageHash=mod.exports and mod.exports.optionalPokemonAssets and mod.exports.optionalPokemonAssets.imageHash,
    }
    local staged,reason=opts.additionalArtRegistrar(current,payload)
    if not staged then return nil,reason end
    staged.read=current.read
    staged.optionalImageMetadata=current.optionalImageMetadata
    staged.optionalImageHash=current.optionalImageHash
    for dex,input in pairs(payload.entries)do
      local row=staged.voxel[tostring(dex)]
      if row then H.bySpecies[input.species]=row end
      H.fallbackBySpecies[input.species]=staged.fallback[tostring(dex)]
      local moving=0
      for _,variant in ipairs({'normal','shiny'})do
        if row and row.variants and row.variants[variant]then moving=moving+1
        else H.fallbackVariantCount=H.fallbackVariantCount+1 end
      end
      if moving>0 then H.count=H.count+1 end
      H.variantCount=H.variantCount+moving
    end
    additionalArtState=staged
    return staged.count
  end

  local function optionEnabledFor(key)
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, key)
      if ok and value == false then return false end
    end
    return true
  end
  local function optionEnabled()return optionEnabledFor(H.OPTION_KEY)end

  -- `crystal_animation` is the presentation-wide motion master.  This Card
  -- remains independently switchable for rollback, but it must never keep
  -- later-generation VASC sprites moving after the user disabled Crystal
  -- animation.  Keeping both checks separate also preserves a useful static
  -- frame-one fallback when only motion is disabled.
  local function motionEnabled()
    if not optionEnabled() then return false end
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options,
        "crystal_animation")
      if ok and value == false then return false end
    end
    return true
  end

  H.active = optionEnabled()
  H.enabled = optionEnabled
  H.motionEnabled = motionEnabled
  H.count = 0
  H.variantCount = 0
  for dex, row in pairs(H.data) do
    assert(tonumber(dex), "HD front runtime dex must be numeric")
    assert(type(row) == "table" and type(row.root) == "string",
      "HD front row missing runtime root: " .. tostring(dex))
    assert(type(row.durations) == "table" and #row.durations > 1,
      "HD front row is not animated: " .. tostring(dex))
    assert(row.species ~= "GOROCHU" and not row.species:find("MEGA", 1, true),
      "HD front Card must not own Mega/Gorochu: " .. tostring(row.species))
    assert(mod:read(row.root .. "/001.png") ~= nil or optionalImage(mod,row.root .. "/001.png"),
      "HD front frame missing: " .. tostring(row.species))
    row.variants=row.variants or{normal={root=row.root,scale=row.scale,
      durations=row.durations}}
    for variant,entry in pairs(row.variants)do
      assert(variant=="normal"or variant=="shiny",
        "unsupported VASC animation variant: "..tostring(variant))
      assert(type(entry.root)=="string"and type(entry.durations)=="table"
          and #entry.durations>1,
        "VASC variant is not a real animation: "..tostring(row.species)
          .."/"..variant)
      assert(mod:read(entry.root.."/001.png")~=nil or optionalImage(mod,entry.root.."/001.png"),
        "VASC variant frame missing: "..tostring(row.species).."/"..variant)
      H.variantCount=H.variantCount+1
    end
    H.bySpecies[row.species]=row
    H.count = H.count + 1
  end
  for _,row in pairs(fallbackData)do
    if type(row)=="table"and type(row.species)=="string"then
      H.fallbackBySpecies[row.species]=row
    end
  end
  H.fallbackVariantCount=0
  for species,row in pairs(H.fallbackBySpecies)do
    local animated=H.bySpecies[species]
    for _,variant in ipairs({"normal","shiny"})do
      if not(animated and animated.variants[variant])then
        local path=variant=="shiny"and row.frontShiny or row.front
        if path and mod:read(path)~=nil then
          H.fallbackVariantCount=H.fallbackVariantCount+1
        end
      end
    end
  end

  local function framePath(row,frame)
    if row.path then return row.path end
    return ("%s/%03d.png"):format(row.root,frame)
  end

  local function variantFor(mon)
    if shinySystem and type(shinySystem.isShiny)=="function"then
      local ok,value=pcall(shinySystem.isShiny,mon)
      if ok and value then return"shiny"end
    end
    return mon and mon.shiny==true and"shiny"or"normal"
  end

  local function rowFor(mon)
    local variant=variantFor(mon)
    local battleForm=H.battleFormProvider and H.battleFormProvider(mon,mon and mon.species)
    local cosmetic=battleForm
      or H.castformProvider and H.castformProvider(mon,mon and mon.species)
      or H.burmyCloakProvider and H.burmyCloakProvider(mon,mon and mon.species)
      or H.laterGenderProvider and H.laterGenderProvider(mon,mon and mon.species)
      or H.gen3GenderProvider and H.gen3GenderProvider(mon,mon and mon.species)
      or H.genderFormProvider and H.genderFormProvider(mon,mon and mon.species)
    local selected=cosmetic and cosmetic.artAlias or mon and mon.species
    local animated=selected and H.bySpecies[selected]
    local entry=animated and animated.variants[variant]
    if entry then
      return{
        root=entry.root,durations=entry.durations,
        scale=tonumber(entry.scale)or tonumber(animated.scale)or 1.5,
        source="gen2-neo",variant=variant,presentationSpecies=selected,battleForm=battleForm~=nil,
      }
    end
    if not optionEnabledFor("non_crystal_pixel_2d")then return nil end
    local fallback=selected and H.fallbackBySpecies[selected]
    local path=fallback and(variant=="shiny"and fallback.frontShiny
      or fallback.front)
    if path and mod:read(path)~=nil then
      -- Static fallbacks are 96x96 catalog sprites, not the normalized
      -- 64x64 Neo animation stages above.  Preserve their reviewed
      -- species/connector scale or large silhouettes (Rayquaza in
      -- particular) can invalidate VASC's HUD-safe camera.
      return{path=path,durations={1000},
        scale=tonumber(fallback.scale)or 1.5,
        source="static-2d-fallback",variant=variant,static=true,
        presentationSpecies=selected,battleForm=battleForm~=nil}
    end
    return nil
  end

  function H.setBurmyCloakProvider(provider)
    assert(type(provider)=='function' and not H.burmyCloakProvider,'Burmy front owner already bound')
    H.burmyCloakProvider=provider
  end
  function H.setGenderFormProvider(provider)
    assert(type(provider)=='function' and not H.genderFormProvider,'Gender front owner already bound')
    H.genderFormProvider=provider
  end
  function H.setCastformProvider(provider)
    assert(type(provider)=='function' and not H.castformProvider)
    H.castformProvider=provider
  end
  function H.setBattleFormProvider(provider)
    assert(type(provider)=='function' and not H.battleFormProvider)
    H.battleFormProvider=provider
  end
  function H.setLaterGenderProvider(provider)
    assert(type(provider)=='function' and not H.laterGenderProvider,'Later gender art already bound')
    H.laterGenderProvider=provider
  end

  function H.setGen3GenderProvider(provider)
    assert(type(provider)=='function' and not H.gen3GenderProvider,'Gen 3 gender front already bound')
    H.gen3GenderProvider=provider
  end

  function H.install(game,deps)
    deps=deps or{}
    local overworld=voxelRenderer and voxelRenderer.module
      and voxelRenderer.module(game,"OverworldBattle")or nil
    if not(overworld and type(overworld.sideTexture)=="function")then
      return false,"no-public-overworld-battle"
    end
    if overworld.kantoAscendantNonCrystalHdFrontHook then return true end
    local BattleState=deps.battleState or require("src.battle.BattleState")
    local images,canvases={},{}
    local function imageFor(row,frame)
      local relative=framePath(row,frame)
      local image=images[relative]
      if image then return image,relative end
      local ok,loaded=pcall(love.graphics.newImage,mod.path.."/"..relative)
      if not(ok and loaded)then return nil end
      if loaded.setFilter then loaded:setFilter("nearest","nearest")end
      images[relative]=loaded
      return loaded,relative
    end
    local function canvasFor(side,width,height)
      local key=side..":"..width.."x"..height
      if canvases[key]then return canvases[key]end
      local ok,canvas=pcall(love.graphics.newCanvas,width,height,{dpiscale=1})
      if not(ok and canvas)then return nil end
      if canvas.setFilter then canvas:setFilter("nearest","nearest")end
      canvases[key]=canvas
      return canvas
    end
    local function ensureState(battle,battler)
      local mon=battler and battler.mon
      local identity=mod.exports and mod.exports.pokemonBattleIdentity67
      if mon and identity then mon=(identity.presentationMon or identity.visualMon)(battle,battler)end
      local row=mon and rowFor(mon)
      if not(row and optionEnabled())or mon._ascMegaForm or mon.ascMegaForm
          or mon.species=="GOROCHU"then
        if battler then H.voxelStates[battler]=nil end
        return nil
      end
      local state=H.voxelStates[battler]
      if not state or state.species~=mon.species
          or state.variant~=row.variant or state.source~=row.source
          or state.row.path~=row.path or state.row.root~=row.root then
        local image,relative=imageFor(row,1)
        if not image then return nil end
        state={species=mon.species,row=row,frame=1,elapsed=0,
          variant=row.variant,source=row.source,scale=row.scale,
          animated=not row.static and motionEnabled()and #row.durations>1,
          image=image,path=relative,side="front",static=row.static==true}
        H.voxelStates[battler]=state
      else
        state.animated=not state.static and motionEnabled()
          and #state.row.durations>1
      end
      return state
    end
    local function advance(battler,dt)
      local state=H.voxelStates[battler]
      if not state then return end
      state.animated=not state.static and motionEnabled()
        and #state.row.durations>1
      if not state.animated then
        state.elapsed=0
        if state.frame~=1 then
          local image,relative=imageFor(state.row,1)
          state.frame=1
          if image then state.image,state.path=image,relative end
        end
        return
      end
      state.elapsed=state.elapsed+(tonumber(dt)or 1/60)*1000
      local changed,guard=false,0
      while state.elapsed>=(state.row.durations[state.frame]or 100)
          and guard<50 do
        state.elapsed=state.elapsed-(state.row.durations[state.frame]or 100)
        state.frame=state.frame%#state.row.durations+1
        changed,guard=true,guard+1
      end
      if changed then
        local image,relative=imageFor(state.row,state.frame)
        if image then state.image,state.path=image,relative end
      end
    end
    if type(BattleState.update)=="function"
        and not BattleState._kantoAscendantNonCrystalHdFrontWrapped then
      local innerUpdate=BattleState.update
      BattleState.update=function(battle,dt)
        local result=innerUpdate(battle,dt)
        advance(battle and battle.enemy,dt)
        advance(battle and battle.player,dt)
        return result
      end
      BattleState._kantoAscendantNonCrystalHdFrontWrapped=true
    end
    local innerSideTexture=overworld.sideTexture
    overworld.sideTexture=function(battle,side)
      local texture=innerSideTexture(battle,side)
      local battler=battle and(side=="enemy"and battle.enemy or battle.player)
      local trainerPhase=battle and(side=="enemy"and battle.showEnemyTrainer
        or side=="player"and battle.showPlayerBack)
      if not(texture and battler and not trainerPhase)then return texture end
      local state=ensureState(battle,battler)
      if not(state and state.image)then return texture end
      local base=texture.canvas
      local width,height=base and base:getDimensions()
      width,height=tonumber(width)or 160,tonumber(height)or 144
      local anchorX=tonumber(texture.ax)or width/2
      local anchorY=tonumber(texture.ay)or 96
      local iw,ih=state.image:getDimensions()
      local scale=tonumber(state.scale)or 1.5
      -- A 96px form master at 1.5x extends above the old y=96 anchor.
      -- Retain the complete source before VASC applies density conversion.
      -- Growing this private canvas changes no scene/world coordinates.
      local left=math.max(0,math.ceil(iw*scale/2-anchorX))
      local top=math.max(0,math.ceil(ih*scale-anchorY))
      anchorX,anchorY=anchorX+left,anchorY+top
      width=math.max(width+left,math.ceil(anchorX+iw*scale/2))
      height=math.max(height+top,math.ceil(anchorY))
      local canvas=canvasFor(side,width,height)
      if not canvas then return texture end
      local g=love.graphics
      local previous=g.getCanvas and g.getCanvas()or nil
      local blend,alpha=g.getBlendMode()
      local red,green,blue,a=g.getColor()
      local ok=pcall(function()
        g.setCanvas(canvas);g.clear(0,0,0,0);g.setBlendMode("alpha")
        g.setColor(1,1,1,1)
        g.draw(state.image,anchorX-iw*scale/2,anchorY-ih*scale,
          0,scale,scale)
      end)
      if previous then g.setCanvas(previous)else g.setCanvas()end
      g.setBlendMode(blend or"alpha",alpha)
      g.setColor(red or 1,green or 1,blue or 1,a or 1)
      if not ok then return texture end
      texture.canvas=canvas
      texture.ax,texture.ay=anchorX,anchorY
      -- The side canvas is reused, but its content is now our full front,
      -- not the inner renderer's native sprite (usually a static player
      -- rear). VASC keys its alpha-bounds cache by canvas + inkIdentity.
      -- Include authored frame/variant and placement, retaining a stable key
      -- for an unchanged frame rather than forcing a readback on every draw.
      texture.inkIdentity=table.concat({H.OWNER,state.path,width,height,
        anchorX,anchorY,tonumber(state.scale)or 1.5},'|')
      -- Backend-only gifts have no native dexEntry measurements. Supply the
      -- same inches contract through the public texture, not a fabricated
      -- frontend Dex entry or private VASC sizing override. Native measured
      -- species keep their own authority; only this Card's full-front body
      -- receives this metadata, never trainers or foreign sprite providers.
      local physical=H.fallbackBySpecies[state.row.presentationSpecies or state.species]
      local meters=physical and physical.heightM
      if (texture.heightIn==nil or state.row.battleForm)and type(meters)=='number' and meters==meters
          and meters>0 and meters<math.huge then
        texture.heightIn=math.max(1,math.floor(meters/0.0254+0.5))
      end
      texture.kantoAscendantNonCrystalHd=true
      texture.kantoAscendantNonCrystalHdSource=state.path
      texture.kantoAscendantNonCrystalHdFrame=state.frame
      texture.kantoAscendantNonCrystalHdVariant=state.variant
      texture.kantoAscendantNonCrystalHdProvider=state.source
      texture.kantoAscendantNonCrystalHdStaticFallback=state.static==true
      -- These cards use 64/96px sources and an authored draw scale, whereas
      -- the engine's physical battle-card reference is 56px. Publish source
      -- density independently of species height. VASC can undo this exactly
      -- once without measuring each animation pose or changing classic 2D.
      local metrics=mod.exports and mod.exports.battleSpriteMetrics67
      local extent=metrics and metrics.forPath(state.path)
      texture.ascendantSpriteReceipt={apiVersion=1,view="front",body="full",
        referenceExtent=extent and extent*scale or nil,
        pixelScale=math.max(iw,ih)*scale/56,
        heightIn=state.row.battleForm and type(meters)=='number'
          and meters==meters and meters>0 and meters<math.huge
          and meters/0.0254 or nil}
      return texture
    end
    overworld.kantoAscendantNonCrystalHdFrontHook=true
    H.overworldBattle=overworld
    return true
  end

  local support = opts.supportLog
  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      segmentId=H.CARD_ID, cardId=H.CARD_ID, version=H.VERSION,
      schema="kasc.optional-visual-card/v1", owner=H.OWNER,
      active=H.active, dependencyStatus="reviewed-local-source",
      providerStatus=H.active and "vasc-gen2-neo-animation-plus-static-fallback"
        or "cold-disabled",
      buildReceiptId="docs/NON_CRYSTAL_SPRITE_SURFACES_67.md",
      rollbackReceiptId="select-non_crystal_voxel_animations-off",
    })
  end
  return H
end
