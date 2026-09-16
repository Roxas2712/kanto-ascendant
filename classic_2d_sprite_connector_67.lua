-- Side-aware placement contract for KASC-owned classic 2D battle art.
--
-- Gen-I placement math assumes a maximum 56px enemy card and a 32px rear.
-- Modern retained-detail sources are larger, so their *visible card* must be
-- fitted first and then anchored to the same two cartridge tracks.  This Card
-- owns only scale/placement math; it never chooses a species or image.

return function(mod,opts)
  opts=opts or{}
  local C={
    CARD_ID="KASC-66-CLASSIC-2D-SPRITE-CONNECTOR",
    OWNER="kasc.classic-2d-sprite-connector/v1",
    VERSION="1.0.0",
    OPTION_KEY="classic_2d_sprite_connector",
    FRONT_CENTER_X=116,FRONT_BASELINE_Y=48,FRONT_SLOT=56,
    BACK_BASELINE_Y=96,BACK_SLOT=32,
    SMALL_FRONT_SLOT=40,MEDIUM_FRONT_SLOT=48,LARGE_FRONT_SLOT=56,
  }
  function C.enabled()
    if mod.options and type(mod.options.get)=="function"then
      local ok,value=pcall(mod.options.get,mod.options,C.OPTION_KEY)
      if ok and value==false then return false end
    end
    return true
  end
  local function dimensions(image)
    if not image then return nil end
    local ok,w,h=pcall(image.getDimensions,image)
    w,h=tonumber(w),tonumber(h)
    if not(ok and w and h and w>0 and h>0)then return nil end
    return w,h
  end
  local function heightMetres(data,species)
    local def=data and data.pokemon and data.pokemon[species]
    local dex=def and def.dexEntry
    local metric=dex and tonumber(dex.heightM)
    if metric and metric>0 then return metric end
    local feet=dex and tonumber(dex.heightFt)
    local inches=dex and tonumber(dex.heightIn)
    if feet or inches then
      return((feet or 0)*12+(inches or 0))*0.0254
    end
    -- Backend-only gifts deliberately have no frontend dexEntry. Keep the
    -- authored/native measurements authoritative, then use render metadata.
    local backendMetric=def and tonumber(def.heightM)
    if backendMetric and backendMetric>0 then return backendMetric end
  end
  -- Gen-I already communicates body scale through its authored 5x5, 6x6 and
  -- 7x7 front-card ladder. New species reuse that visual language instead of
  -- all being enlarged to the maximum slot: Rattata/Bulbasaur-sized bodies
  -- use 40px, Wartortle-sized bodies 48px, and large/long bodies 56px.
  function C.referenceSlot(data,species,side)
    if side=="back"then return C.BACK_SLOT,"classic-back"end
    local metres=heightMetres(data,species)
    if not metres then return C.FRONT_SLOT,"unknown-large-safe"end
    if metres<=0.8 then return C.SMALL_FRONT_SLOT,"rattata-small"end
    if metres<=1.3 then return C.MEDIUM_FRONT_SLOT,"wartortle-medium"end
    return C.LARGE_FRONT_SLOT,"charizard-large"
  end
  function C.fitScale(image,side,requested,species,data)
    local w,h=dimensions(image)
    local scale=tonumber(requested)or 1
    if not(w and C.enabled())then return scale end
    local slot=C.referenceSlot(data,species,side)
    return math.min(scale,slot/math.max(w,h))
  end
  function C.frontOffset(image)
    local width,height=dimensions(image)
    if not(width and C.enabled())then return 0,0 end
    local tw=math.max(1,math.min(7,math.floor(width/8)))
    local th=math.max(1,math.min(7,math.floor(height/8)))
    local originX=96+8*math.floor((8-tw)/2)
    local originY=8*(7-th)
    return C.FRONT_CENTER_X-(originX+width/2),
      C.FRONT_BASELINE_Y-(originY+height)
  end
  function C.backBaseline()return C.BACK_BASELINE_Y end

  local support=opts.supportLog
  if support and type(support.registerSegment)=="function"then
    support.registerSegment({
      segmentId=C.CARD_ID,cardId=C.CARD_ID,version=C.VERSION,
      schema="kasc.optional-visual-card/v1",owner=C.OWNER,
      active=C.enabled(),dependencyStatus="self-contained",
      providerStatus=C.enabled()and"front-back-track-normalizer"
        or"cold-disabled",
      buildReceiptId="docs/NON_CRYSTAL_SPRITE_SURFACES_67.md",
      rollbackReceiptId="select-classic_2d_sprite_connector-off",
    })
  end
  return C
end
