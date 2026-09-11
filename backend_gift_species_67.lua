-- KASC-67-BACKEND-GIFT-SPECIES. Additive base/persistent-form runtime ownership.
-- Private IDs never change constants.dexSize or replace established art.
return function(mod, opts)
  local catalog=assert(opts.catalog)
  local facts=assert(opts.facts)
  local art=assert(opts.art)
  local registry=assert(mod.content.pokemon)
  local C={CARD_ID='KASC-67-BACKEND-GIFT-SPECIES',
    OWNER='kasc.backend.gift-species/v1',byKey={},bySpecies={},
    registered={},reused={},pending={},moveAudit={},forms={},
    frontendDexLimit=mod.content.constants:get('dexSize')}
  local function copy(v)
    if type(v)~='table' then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  local function canonical(row)return row.identifier:upper():gsub('[^A-Z0-9]','_')end
  local aliases={MR_MIME='MR_MIME',MIME_JR='MIME_JR',FARFETCHD='FARFETCHD',
    NIDORAN_F='NIDORAN_F',NIDORAN_M='NIDORAN_M'}
  local byDex,occupied={},{}
  for id,row in registry:each()do
    occupied[row.dex]=id
    -- Never mistake a private ABI slot (e.g. Gorochu #279) for a Dex number.
    local dex=tonumber(row.sourceDex)
      or tonumber(row.dex) and row.dex<=251 and row.dex
    if dex and not row.form and not row.formId and not row.isMega
        and not row.isGigantamax and id~='GOROCHU' and not id:find('MEGA',1,true)
        and not id:find('ALOLA',1,true) then
      byDex[dex]=byDex[dex] or {};byDex[dex][#byDex[dex]+1]=id
    end
  end
  local moves=mod.content.moves
  -- These are spelling aliases, not mechanical approximations.
  local moveAliases={POISON_POWDER='POISONPOWDER',STUN_SPORE='STUN_SPORE',
    VICE_GRIP='VICEGRIP',DOUBLE_SLAP='DOUBLESLAP',SONIC_BOOM='SONICBOOM',
    BUBBLE_BEAM='BUBBLEBEAM',SOLAR_BEAM='SOLARBEAM',SMOKESCREEN='SMOKESCREEN',
    THUNDER_PUNCH='THUNDERPUNCH',FEINT_ATTACK='FAINT_ATTACK',
    EXTREME_SPEED='EXTREMESPEED',ANCIENT_POWER='ANCIENTPOWER'}
  function C.moveId(id)
    if moves:get(id) then return id end
    local alias=moveAliases[id]
    return alias and moves:get(alias) and alias or nil
  end
  function C.moveRevision(id)
    local row=moves:get(id)
    return math.max(1,tonumber(row and row.backendLearnsetRevision) or 1)
  end
  -- Some established cart spellings coexist with the newer catalog ID.
  -- Every runtime owner needs the same mechanics; choosing one for new
  -- gifts must not leave already saved FAINT_ATTACK etc. unprojected.
  function C.moveIds(id)
    local out={}
    if moves:get(id) then out[#out+1]=id end
    local alias=moveAliases[id]
    if alias and alias~=id and moves:get(alias) then out[#out+1]=alias end
    return out
  end
  function C.projectLearnset(key,epoch,versionGroup)
    local row=assert(catalog.entries[key],'unknown backend species')
    -- A gift born after the selected era uses its first actual learnset,
    -- without raising the global AUTO profile merely by opening a menu.
    local source,reason=facts.learnset(key,math.max(epoch or 6,row.originGeneration),versionGroup)
    if not source then return nil,reason end
    local out={level1Moves={},learnset={},tmhm={},tutor={},egg={},
      unavailable={},generation=source.generation,versionGroup=source.versionGroup}
    local seen={}
    for _,learn in ipairs(source.rows)do
      local method,level,sourceId=learn[1],learn[2],learn[3]
      local id=C.moveId(sourceId)
      if not id then out.unavailable[sourceId]=true
      else
        local slot=method..':'..level..':'..id
        if not seen[slot] then
          seen[slot]=true
          if method==1 then
            if level<=1 then out.level1Moves[#out.level1Moves+1]=id
            else out.learnset[#out.learnset+1]={level=level,move=id} end
          elseif method==4 then out.tmhm[#out.tmhm+1]=id
          elseif method==3 then out.tutor[#out.tutor+1]=id
          elseif method==2 then out.egg[#out.egg+1]=id end
        end
      end
    end
    table.sort(out.learnset,function(a,b)
      return a.level<b.level or a.level==b.level and a.move<b.move end)
    return out
  end
  function C.historicalLearnsets(key,epoch)
    local out={}
    for _,group in ipairs(facts.learnsetGroups(key,epoch))do
      local row=C.projectLearnset(key,group.generation,group.versionGroup)
      if row then out[#out+1]=row end
    end
    return out
  end
  local payload={schema='kasc.backend-gift-art/v1',entries={}}
  local plans={}
  local function plan(key,row,id,private,form)
    assert(not registry:get(id) and not occupied[private],'backend species ABI collision '..key)
    local images=art[key];local p=images and images.paths
    local complete=p and p.front and p.back and p.frontShiny and p.backShiny
      and p.voxelFront and p.voxelFrontShiny and p.icon
    local learned,reason=C.projectLearnset(key,6)
    if not complete then C.pending[key]='missing_art';return end
    if not learned or #learned.level1Moves==0 then
      C.pending[key]=reason or 'missing_native_birth_moves';return
    end
    local s=row.baseStats;local names=row.formNames or row.names
    local name=opts.i18n and opts.i18n.text(names.en,names.de) or names.en
    local types={};for _,kind in ipairs(row.types)do
      types[#types+1]=kind=='PSYCHIC' and 'PSYCHIC_TYPE' or kind
    end
    local definition={id=id,name=name,dex=private,sourceDex=row.nationalDex,
      backendKey=key,originGeneration=row.originGeneration,
      backendOwner=C.OWNER,frontendDexExpansion=false,giftOnly=true,
      types=types,baseStats={hp=s.hp,attack=s.atk,defense=s.def,
        speed=s.spe,special=s.spa},modernBaseStats=copy(s),
      catchRate=row.catchRate,baseExp=math.min(255,row.baseExp),
      sourceBaseExp=row.baseExp,growthRate=({MEDIUM='MEDIUM_FAST',
        SLOW_THEN_VERY_FAST='ERRATIC',FAST_THEN_VERY_SLOW='FLUCTUATING'})[row.growthRate]
        or row.growthRate,
      level1Moves=learned.level1Moves,learnset=learned.learnset,
      tmhm=learned.tmhm,evolutions={},
      spriteFront=mod.path..'/'..p.front,spriteBack=mod.path..'/'..p.back,
      frontSize=7,trueColor=true,battleScaleFront=1,battleScaleBack=1,
      icon={image=mod.path..'/'..p.icon,frames=1}}
    if form then
      definition.baseSpecies=C.byKey['dex:'..row.nationalDex]
      definition.formId='BACKEND_'..row.pokeapiId
      definition.backendForm=true
      form.formId=definition.formId;form.baseSpecies=definition.baseSpecies
    end
    local animation=images.animations or {}
    payload.entries[tostring(private)]={species=id,
      pixel={front=p.front,back=p.back,frontShiny=p.frontShiny,
        backShiny=p.backShiny,preferPixel2D=true},
      fallback={front=p.voxelFront,frontShiny=p.voxelFrontShiny},
      native={front=animation.front,back=animation.back,
        frontShiny=animation.frontShiny,backShiny=animation.backShiny},
      voxel={variants={normal=animation.voxel,shiny=animation.voxelShiny}}}
    plans[#plans+1]=definition;occupied[private]=id
    C.byKey[key]=id;C.bySpecies[id]=key;C.moveAudit[key]=learned.unavailable
  end
  for dex=1,catalog.maximumNationalDex do
    local key='dex:'..dex;local row=assert(catalog.entries[key])
    local id=aliases[canonical(row)] or canonical(row)
    local existing=registry:get(id)
    if not existing and byDex[dex] and #byDex[dex]==1 then
      id=byDex[dex][1];existing=registry:get(id)
    end
    if existing then
      C.byKey[key]=id;C.bySpecies[id]=key;C.reused[#C.reused+1]=id
    elseif dex<=251 then
      -- A partial test engine is not permission to replace Crystal's owner.
      C.pending[key]='missing_protected_owner'
    else
      id='KA_GIFT_NAT_'..dex
      plan(key,row,id,20000+dex)
    end
  end
  local formKeys={}
  for key,row in pairs(catalog.entries)do if not row.isBase then formKeys[#formKeys+1]=key end end
  table.sort(formKeys)
  for _,key in ipairs(formKeys)do
    local row=catalog.entries[key]
    local form={key=key,sourceId=row.pokeapiId,identifier=row.identifier}
    C.forms[key]=form
    local battleOnly=row.isMega or row.isGigantamax
    for _,meta in ipairs(row.formMetadata or {})do
      battleOnly=battleOnly or meta.is_battle_only=='1'
    end
    if battleOnly then
      -- Temporary transformations belong to their battle controller. Never
      -- serialize them as permanently boosted ordinary species.
      form.kind=row.isMega and 'mega' or row.isGigantamax and 'gigantamax' or 'battle'
      form.status='requires_transformation_controller'
    else
      form.kind='persistent'
      local id=canonical(row)
      local base,region=id:match('^(.-)_(ALOLA)$')
      if not registry:get(id) and base then id=region..'_'..base end
      local existing=registry:get(id)
      if existing and existing.formId and existing.sourceDex==row.nationalDex then
        C.byKey[key]=id;C.bySpecies[id]=key;C.reused[#C.reused+1]=id
        form.formId=existing.formId;form.baseSpecies=existing.baseSpecies
        form.status='reused'
      elseif not C.byKey['dex:'..row.nationalDex] then
        form.status='missing_base_owner'
      else
        plan(key,row,'KA_GIFT_FORM_'..row.pokeapiId,25000+row.pokeapiId,form)
        form.status=C.byKey[key] and 'registered' or C.pending[key]
      end
    end
  end
  -- Validate the entire asset batch before any species is registered. The
  -- native loader rolls this card's registrations back on initialization error.
  if #plans>0 then
    local count,reason=opts.sprites.registerAdditionalArt(payload)
    assert(count==#plans,reason or 'backend art batch incomplete')
    for _,definition in ipairs(plans)do
      registry:register(definition.id,definition)
      C.registered[#C.registered+1]=definition.id
    end
  end
  -- KASC-67-RIOLU-EVOLUTION: restore the missing backend family edge.
  -- Reuse KASC's established friendship/day contract (johtoBond >= 100,
  -- johto_time AUTO/day/night), not a level-only or item shortcut.
  local riolu,lucario=C.byKey['dex:447'],C.byKey['dex:448']
  local parent=riolu and registry:get(riolu)
  if parent and parent.backendOwner==C.OWNER and lucario then
    local methods=mod.content.evolution_methods
    local friendship=assert(methods:get('FRIENDSHIP_DAY'),
      'Riolu requires the existing KASC friendship/day method')
    local method='KA_RIOLU_FRIENDSHIP_DAY'
    methods:register(method,{
      check=function(game,mon,evo,trigger)
        return not mon.isEgg and not mon.eggSpecies and (tonumber(mon.hp) or 0)>0
          and friendship.check(game,mon,evo,trigger)
      end,
      describe=friendship.describe,
    })
    local evolutions=copy(parent.evolutions or {})
    evolutions[#evolutions+1]={method=method,species=lucario}
    registry:patch(riolu,{evolutions=evolutions})
    -- Gifts may hatch before the postgame Johto research programme opens.
    -- Give this missing family its own durable walking progress; do not
    -- change any other Pokemon, gift receipt, saved moves or global era.
    -- Native world.stepped carries map/coordinates, not the Game object.
    -- Keep the live Game, but read its current save/party on every step.
    local activeGame=mod.game
    mod.events:on('game.ready',function(ev)
      activeGame=ev and ev.game or activeGame
    end)
    mod.events:on('world.stepped',function(ev)
      local game=ev and ev.game or activeGame
      for _,mon in ipairs(game and game.save and game.save.party or {})do
        if mon.species==riolu and not mon.isEgg and not mon.eggSpecies
            and (tonumber(mon.hp) or 0)>0 then
          local steps=math.max(0,math.floor(tonumber(mon._kascRioluBondSteps) or 0))+1
          mon._kascRioluBondSteps=steps%64
          if steps>=64 then
            mon.johtoBond=math.min(255,math.max(0,tonumber(mon.johtoBond) or 0)+1)
          end
        end
      end
    end)
    C.rioluEvolution={from=riolu,to=lucario,method=method,bondThreshold=100}
    function C.giftEvolutionAllowed(game,mon,evo)
      local archive=mod.exports and mod.exports.eventArchive
      if not (mon and mon.species==riolu and evo and evo.species==lucario
          and evo.method==method and archive) then return false end
      local valid,_,profile=archive.battleCompatibleGift(mon)
      return valid and profile and profile.backendKey=='dex:447' or false
    end
  end
  function C.status()
    return {registered=#C.registered,reused=#C.reused,pending=copy(C.pending),
      forms=copy(C.forms),giftCodesReady=false,frontendDexExpansion=false}
  end
  return C
end
