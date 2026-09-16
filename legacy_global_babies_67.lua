local function optionalImage(mod,path)
  local optional=mod.exports and mod.exports.optionalPokemonAssets
  return optional and optional.allowPending(path)==true or false
end
-- Optional ZUFALL-GLOBAL extension for baby forms introduced after Hoenn
-- whose evolution target belongs to Generation I--III.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "legacy global baby data required")
  local generationRules = assert(opts.generationRules,
    "legacy global babies need generation rules")
  local i18n = opts.i18n
  local B = {
    CARD_ID = "KASC-67-LEGACY-GLOBAL-BABIES",
    OWNER = "kasc.legacy-global-babies/v1",
    VERSION = "1.2.0",
    OPTION_KEY = "legacy_global_babies",
    order = data.order,
    data = data,
  }

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end
  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end
  local function enabled()
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, B.OPTION_KEY)
      if ok and value == false then return false end
    end
    return true
  end
  local function availableMove(id)
    return mod.content.moves and mod.content.moves.get
      and mod.content.moves:get(id) ~= nil
  end
  local function filterMoves(values, levelRows)
    local out = {}
    for _, value in ipairs(values or {}) do
      local id = levelRows and value.move or value
      if availableMove(id) then out[#out + 1] = copy(value) end
    end
    return out
  end

  local missingParents = {}
  for _, species in ipairs(data.order) do
    local row = assert(data.species[species], "missing global baby " .. species)
    if not mod.content.pokemon:get(row.parent) then
      missingParents[#missingParents + 1] = row.parent
    end
  end
  table.sort(missingParents)
  B.ready = #missingParents == 0
  B.missingParents = missingParents
  local ownedSpritePaths={}

  -- These are level-up conditions, not a replacement level threshold. A
  -- reminder/tutor can supply MIMIC; zero PP still means the move is known.
  -- Remoraid must be a real party member (not an egg or a boxed Pokemon).
  local function notEgg(mon)
    return type(mon)=="table" and not mon.isEgg and not mon.egg and not mon.eggSpecies
  end
  local function canLevel(mon, trigger)
    return notEgg(mon) and (tonumber(mon.hp) or 0)>0
      and trigger and trigger.kind=="levelup"
  end
  local friendshipMethods={BUDEW='FRIENDSHIP_DAY',CHINGLING='FRIENDSHIP_NIGHT',
    MUNCHLAX='FRIENDSHIP'}
  if B.ready then
    local methods=assert(mod.content.evolution_methods, "baby evolution registry required")
    for _,method in pairs(friendshipMethods) do
      local native=assert(methods:get(method), 'baby needs existing friendship method '..method)
      methods:register('KA_BABY_'..method, {
        check=function(game,mon,evo,trigger)
          return canLevel(mon,trigger) and native.check(game,mon,evo,trigger) or false
        end,
        describe=function()
          if method=='FRIENDSHIP_DAY' then return tr('High friendship by day','Hohe Freundschaft am Tag') end
          if method=='FRIENDSHIP_NIGHT' then return tr('High friendship at night','Hohe Freundschaft nachts') end
          return tr('High friendship','Hohe Freundschaft')
        end,
      })
    end
    methods:register("KA_BABY_MIMIC", {
      check=function(_,mon,evo,trigger)
        if not canLevel(mon,trigger) then return false end
        for _,move in ipairs(mon.moves or {}) do
          if type(move)=="table" and move.id=="MIMIC" then return true end
        end
        return false
      end,
      describe=function(evo,gameData)
        local move=gameData and gameData.moves and gameData.moves.MIMIC
        return tr("Level up knowing ", "Levelaufstieg mit ") .. (move and move.name or "MIMIC")
      end,
    })
    methods:register("KA_BABY_REMORAID", {
      check=function(game,mon,evo,trigger)
        if not canLevel(mon,trigger) then return false end
        for _,member in ipairs(game and game.save and game.save.party or {}) do
          if member~=mon and notEgg(member) and member.species=="REMORAID" then return true end
        end
        return false
      end,
      describe=function(evo,gameData)
        local def=gameData and gameData.pokemon and gameData.pokemon.REMORAID
        return tr("Level up with ", "Levelaufstieg mit ") .. (def and def.name or "REMORAID")
          .. tr(" in the party", " im Team")
      end,
    })
  end

  -- Species identities remain registered while the Card is OFF. That is the
  -- safe rollback path for an already sealed NG+ journey; OFF only prevents
  -- a fresh draw from adding these seven rows. Minimal/older engine fixtures
  -- may intentionally omit the Hoenn registry. That is a dependency-cold
  -- Card, not a reason to abort the complete KASC loader.
  if B.ready then for _, species in ipairs(data.order) do
    local row = assert(data.species[species], "missing global baby " .. species)
    assert(row.originGeneration <= data.generationCeiling,
      species .. " exceeds the Gen-VI ceiling")
    assert(row.sourceDex >= 387 and row.sourceDex <= 721,
      species .. " is not a Gen-IV--VI identity")
    assert(row.evolution and row.evolution.species == row.parent,
      species .. " must evolve into its Gen-I--III parent")
    local front = "assets/non_crystal_pixel_2d_67/front/"
      .. tostring(row.sourceDex) .. ".png"
    local back = "assets/non_crystal_pixel_2d_67/back/"
      .. tostring(row.sourceDex) .. ".png"
    local paths={front=front,back=back,
      frontShiny="assets/non_crystal_pixel_2d_67/frontShiny/"..row.sourceDex..".png",
      backShiny="assets/non_crystal_pixel_2d_67/backShiny/"..row.sourceDex..".png"}
    local cry = "assets/legacy_global_babies_67/cries/"
      .. tostring(row.sourceDex) .. ".ogg"
    assert((mod:read(front) ~= nil or optionalImage(mod,front)), species .. " missing static front")
    assert((mod:read(back) ~= nil or optionalImage(mod,back)), species .. " missing static back")
    assert((mod:read(paths.frontShiny) ~= nil or optionalImage(mod,paths.frontShiny)) and (mod:read(paths.backShiny) ~= nil or optionalImage(mod,paths.backShiny)),
      species .. " missing static shiny sides")
    ownedSpritePaths[species]=paths
    assert(mod:read(cry) ~= nil, species .. " missing cry")
    local level1 = filterMoves(row.level1Moves)
    assert(#level1 > 0, species .. " has no executable level-one move")
    local textId = "_KantoAscendantGlobalBabyDex" .. species
    mod.content.text:register(textId, tr(
      "A later baby form linked to an earlier Kanto, Johto or Hoenn family.",
      "Eine spätere Babyform aus einer Kanto-, Johto- oder Hoenn-Familie."))
    mod.content.cries:register(species, { file=mod.path .. "/" .. cry })
    local inches = math.floor(row.heightM * 39.3700787 + 0.5)
    mod.content.pokemon:register(species, {
      id=species, name=tr(row.names.en, row.names.de),
      dex=row.sourceDex, sourceDex=row.sourceDex,
      originGeneration=row.originGeneration,
      types=copy(row.types), baseStats=copy(row.baseStats),
      catchRate=row.catchRate, baseExp=math.min(row.baseExp, 255),
      growthRate=row.growthRate, level1Moves=level1,
      learnset=filterMoves(row.learnset, true), tmhm=filterMoves(row.tmhm),
      evolutions={ copy(row.evolution) }, cry=species,
      spriteFront=mod.path .. "/" .. front,
      spriteBack=mod.path .. "/" .. back,
      frontSize=7, trueColor=true,
      battleScaleFront=7/12, battleScaleBack=7/12,
      icon="MON", certificateExcluded=true,
      dexEntry={
        kind=tr("BABY", "BABY"), text=textId,
        heightFt=math.floor(inches/12), heightIn=inches%12,
        weight=math.floor(row.weightKg*22.0462262+0.5),
        heightM=row.heightM, weightKg=row.weightKg,
      },
    })
  end end

  -- Early gifts must be able to earn friendship even before Johto research.
  -- Existing selected-follower and research travel remain the first owners;
  -- do not award an extra cadence on top of either. A partial reserve counter
  -- stays on the individual Pokemon across storage and save/reload.
  function B.walkFriendship(game)
    if not B.ready or not (game and game.save) then return end
    local exports=mod.exports or {}
    local research=exports.johtoResearch
    if research and research.awardsWalkingBond and research.awardsWalkingBond(game) then return end
    local selected={}
    local follower=exports.singleFollower
    if follower and follower.activeMons then
      for _,row in ipairs(follower.activeMons(game) or {}) do selected[row.mon]=true end
    end
    local seen={}
    for _,mon in ipairs(game.save.party or {}) do
      local happiny=exports.wave1Happiny67
      local familyFriendship=happiny and happiny.familyChansey and happiny.familyChansey(game,mon)
      local backend=exports.backendGiftEvolutions67
      familyFriendship=familyFriendship or backend and backend.walkFriendshipEligible
        and backend.walkFriendshipEligible(mon)
      if (friendshipMethods[mon.species] or familyFriendship) and not selected[mon] and not seen[mon]
          and notEgg(mon) and (tonumber(mon.hp) or 0)>0 then
        seen[mon]=true
        local bond=mon.johtoBond or 0
        local steps=mon._kascBabyBondSteps or 0
        if type(bond)=='number' and bond==math.floor(bond) and bond>=0 and bond<=255
            and type(steps)=='number' and steps==math.floor(steps) and steps>=0 and steps<64 then
          mon._kascBabyBondSteps=(steps+1)%64
          if steps==63 then mon.johtoBond=math.min(255,bond+1) end
        end
      end
    end
  end
  if B.ready and mod.events and mod.events.on then
    mod.events:on('world.stepped',function(ev) B.walkFriendship(ev and ev.game) end,-30)
  end

  -- Evolution previews resolve the requested species, which can differ from
  -- mon.species before the movie applies. Only our exact authored paths are
  -- owned here; battle animation, Mega and foreign sprite providers stay out.
  function B.staticSprite(path,requested,ctx)
    if not ctx or ctx.kind=='battle' or path~=requested then return nil end
    if ctx.mon and (ctx.mon._ascMegaForm or ctx.mon.ascMegaForm) then return nil end
    local paths=ownedSpritePaths[ctx.species]
    if not paths then return nil end
    local side=ctx.side=='back' and 'back' or 'front'
    if requested~=mod.path..'/'..paths[side] then return nil end
    local shiny=mod.exports and mod.exports.shinySystem
    local isShiny=shiny and shiny.isShiny(ctx.mon)
      and not (mod.options and mod.options:get('shiny_effects')==false)
    return mod.path..'/'..paths[side..(isShiny and 'Shiny' or '')]
  end

  function B.enabled() return enabled() end
  function B.rows(game)
    if not enabled() or not B.ready then return {} end
    local resolved = generationRules.resolve(game)
    local unlocked = tonumber(resolved and resolved.unlockedEpoch) or 1
    local rows = {}
    for _, species in ipairs(data.order) do
      local source = data.species[species]
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[species]
      if def and source.originGeneration <= unlocked then
        rows[#rows + 1] = {
          id=species, def=def, dex=source.sourceDex,
          generation=source.originGeneration, laterBaby=true,
          evolvesTo=source.parent,
        }
      end
    end
    return rows
  end

  if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
    opts.supportLog.registerSegment({
      segmentId=B.CARD_ID, cardId=B.CARD_ID, version=B.VERSION,
      schema="kasc.optional-feature-card/v1", owner=B.OWNER,
      active=enabled(), dependencyStatus="local-reviewed",
      providerStatus=not B.ready and "dependency-cold-hoenn-parent-registry"
        or enabled() and "gen4-babies-to-gen1-3-global-pool"
        or "cold-disabled-sealed-saves-preserved",
      buildReceiptId="docs/LEGACY_GLOBAL_BABIES_67.md",
      rollbackReceiptId="select-legacy_global_babies-off",
    })
  end
  return B
end
