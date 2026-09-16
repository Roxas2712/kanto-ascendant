-- New Day-Care genetics only. Unbound legacy/bank IVs are never activated.
return function(mod,opts)
  opts=opts or{}
  local rules=opts.generationRules
  local M={CARD_ID='KASC-67-BREEDING-IVS',OWNER='kasc.breeding-ivs/v1',SCHEMA='kasc.daycare-ivs/v1'}
  local order={'hp','attack','defense','speed','specialAttack','specialDefense'};M.ORDER=order
  local aliases={attack='atk',defense='def',speed='spe',specialAttack='spa',specialDefense='spd'}
  local Stats=require('src.pokemon.Stats')
  local BRIDGE_KEY='_kascBreedingStatsBridge67'
  local bridge=rawget(Stats,BRIDGE_KEY)
  if type(bridge)~='table'then
    bridge={byDvs=setmetatable({},{__mode='k'})}
    rawset(Stats,BRIDGE_KEY,bridge)
  end
  local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=v end;return r end
  local function integer(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
  local function complete(ivs)
    if type(ivs)~='table'then return false end
    local allowed={};for _,key in ipairs(order)do
      if not integer(ivs[key],0,31)then return false end;allowed[key]=true
    end
    for key in pairs(ivs)do if not allowed[key]then return false end end
    return true
  end
  local function seal(species,epoch,ivs)
    local parts={M.SCHEMA,species,tostring(epoch)}
    for _,key in ipairs(order)do parts[#parts+1]=key..':'..tostring(ivs[key])end
    -- Integrity receipt, not a security credential or public gift code.
    return table.concat(parts,'|')
  end
  local function ancestry(data,origin,current)
    if not data or not data.pokemon or not data.pokemon[origin]or not data.pokemon[current]then return false end
    local queue,seen={origin},{};local index=1
    while index<=#queue do
      local id=queue[index];index=index+1
      if id==current then return true end
      if not seen[id]then
        seen[id]=true
        for _,edge in ipairs(data.pokemon[id].evolutions or{})do
          local target=edge.species
          if target and data.pokemon[target]and not seen[target]then queue[#queue+1]=target end
        end
      end
    end
    return false
  end
  function M.valid(game,mon)
    local receipt=type(mon)=='table'and mon._kascBreedingIVs67
    return type(receipt)=='table'and receipt.schema==M.SCHEMA and receipt.owner==M.OWNER
      and receipt.version==1 and integer(receipt.originGeneration,3,7)
      and type(receipt.originSpecies)=='string'and complete(mon.ivs)
      and receipt.seal==seal(receipt.originSpecies,receipt.originGeneration,mon.ivs)
      and ancestry(game and game.data,receipt.originSpecies,mon.eggSpecies or mon.species)or false
  end
  function M.ivs(game,mon)
    return M.valid(game,mon)and copy(mon.ivs)or nil
  end
  function M.epoch(game)
    if not rules or type(rules.peek)~='function'or not game or not game.save or game.demo then return nil end
    local r=rules.peek(game)
    return r and r.extensionsEnabled and integer(r.activeEpoch,3,7)and r.activeEpoch or nil
  end
  function M.fromLegacy(mon)
    local dvs=mon and mon.dvs or{}
    local function dv(k)return integer(dvs[k],0,15)and dvs[k]or 0 end
    local hp=integer(dvs.hp,0,15)and dvs.hp
      or dv('attack')%2*8+dv('defense')%2*4+dv('speed')%2*2+dv('special')%2
    -- Read-only 2*DV preserves the old stat contribution, with no reroll,
    -- parent mutation or manufactured perfect IVs for old 15-DV parents.
    return {hp=hp*2,attack=dv('attack')*2,defense=dv('defense')*2,speed=dv('speed')*2,
      specialAttack=dv('special')*2,specialDefense=dv('special')*2}
  end
  local function held(mon)
    local a,b=mon and mon.item,mon and mon.heldItem
    if a and b and a~=b then return nil end
    return a or b
  end
  function M.reserve(game,species,a,b,random)
    local epoch=M.epoch(game);if not epoch or not a or not b then return nil end
    if not(game.data and game.data.pokemon and game.data.pokemon[species])then return nil end
    random=random or(love and love.math and love.math.random)or math.random
    local ivs,pool={},copy(order)
    for _,key in ipairs(order)do ivs[key]=random(0,31)end
    local inherited=epoch>=6 and(held(a)=='DESTINY_KNOT'or held(b)=='DESTINY_KNOT')and 5 or 3
    local parents={M.ivs(game,a)or M.fromLegacy(a),M.ivs(game,b)or M.fromLegacy(b)}
    for _=1,inherited do
      local index=random(1,#pool);local key=pool[index];table.remove(pool,index)
      ivs[key]=parents[random(1,2)][key]
    end
    return {ivs=ivs,receipt={schema=M.SCHEMA,owner=M.OWNER,version=1,
      originGeneration=epoch,originSpecies=species,seal=seal(species,epoch,ivs)}}
  end
  function M.attach(game,mon,row)
    if type(row)~='table'or type(row.ivs)~='table'or type(row.breedingIVs67)~='table'then return false end
    local view=copy(mon);view.ivs=copy(row.ivs);view._kascBreedingIVs67=copy(row.breedingIVs67)
    if not M.valid(game,view)then return false end
    mon.ivs=view.ivs;mon._kascBreedingIVs67=view._kascBreedingIVs67
    return true
  end
  function M.stats(game,mon,epoch,base)
    if not integer(epoch,1,7)or not M.valid(game,mon)or type(base)~='table'then return nil end
    local ivs=epoch>=3 and mon.ivs or M.fromLegacy(mon)
    local level=math.max(1,math.min(100,math.floor(tonumber(mon.level)or 1)));local out={}
    for _,key in ipairs(order)do
      local value=base[key]or base[aliases[key]]
      if key=='specialAttack'or key=='specialDefense'then value=value or base.special end
      if not integer(value,1,999)then return nil end
      local trained=(key=='specialAttack'or key=='specialDefense')and'special'or key
      local exp=math.max(0,tonumber(mon.statExp and mon.statExp[trained])or 0)
      local training=math.floor(math.min(255,math.ceil(math.sqrt(exp)))/4)
      out[key]=math.floor((value*2+ivs[key]+training)*level/100)+(key=='hp'and level+10 or 5)
    end
    local def=game.data.pokemon[mon.eggSpecies or mon.species]
    -- Keep the actual one-HP species owner; do not approximate arbitrary
    -- custom forms as Shedinja by a private numeric Dex slot.
    if def and(def.sourceDex==292 or def.dex==292)and not def.isMega and not def.isGigantamax then out.hp=1 end
    out.special=out.specialAttack
    if epoch<=2 and integer(base.special,1,999)then
      local exp=math.max(0,tonumber(mon.statExp and mon.statExp.special)or 0)
      local training=math.floor(math.min(255,math.ceil(math.sqrt(exp)))/4)
      out.special=math.floor((base.special*2+M.fromLegacy(mon).specialAttack+training)*level/100)+5
    end
    return out
  end
  function M.base(game,mon,epoch)
    local ex=mod.exports or{};local facts,species=ex.backendGenerationRules67,ex.backendGiftSpecies67
    local key=species and species.bySpecies[mon.eggSpecies or mon.species]
    local native=game and game.data and game.data.pokemon and game.data.pokemon[mon.eggSpecies or mon.species]
    return key and facts and facts.baseStats(key,epoch)or native and native.baseStats
  end
  function M.apply(game,mon,epoch,base)
    if not integer(epoch,1,7)then return false end
    local projected=M.stats(game,mon,epoch,base or M.base(game,mon,epoch));if not projected then return false end
    mon.stats=projected
    -- A profile switch never heals. Lower maxima clamp; returning to a
    -- larger maximum does not refund lost HP or re-credit earlier healing.
    mon.hp=mon.isEgg and 0 or math.max(0,math.min(tonumber(mon.hp)or 0,projected.hp))
    if type(mon.dvs)=='table'then
      -- Weak references on both sides: this registry must not retain a save
      -- or its Pokémon merely because a process-global Stats shim survives.
      bridge.byDvs[mon.dvs]=setmetatable({game=game,mon=mon},{__mode='v'})
    end
    return true
  end
  local function matching(d,dvs,exp,explicit)
    if bridge.owner~=M or not(mod.exports and mod.exports.daycare and mod.exports.daycare.breedingIVs==M)then return end
    local record=type(dvs)=='table'and bridge.byDvs[dvs]
    local game,mon=record and record.game,record and record.mon
    if not game or not mon or explicit and explicit~=mon or mon.dvs~=dvs
        or not explicit and exp~=nil and exp~=mon.statExp or not M.valid(game,mon)then return end
    local native=game.data.pokemon[mon.eggSpecies or mon.species]
    if d~=native or d.isMega or d.isGigantamax or mon._ascMegaForm or mon.ascMegaForm
        or mon._ascendantYellowPartner and mon._ascendantThunderheartAwakened then return end
    return game,mon
  end
  function M.calcProjection(d,level,dvs,exp,explicit)
    local game,mon=matching(d,dvs,exp,explicit)
    local epoch=game and M.epoch(game);if not epoch then return nil end
    -- Deferred native Experience.apply asks for future levels while the
    -- actual Pokémon is still at its old level. Observe those arguments
    -- without changing the registered mon, stats, genetics or HP.
    local view=copy(mon);view.level=level;view.statExp=exp or{}
    return M.stats(game,view,epoch,M.base(game,view,epoch))
  end
  function M.ensureProjection(d,mon)
    if type(mon)~='table'then return end
    local game,concrete=matching(d,mon.dvs,mon.statExp,mon);if concrete~=mon then return end
    local r=rules and type(rules.peek)=='function'and rules.peek(game)
    local epoch=r and r.extensionsEnabled and not game.demo and r.activeEpoch or 1
    if not integer(epoch,1,7)then epoch=1 end
    if epoch>=3 then M.apply(game,mon,epoch)
    else
      -- Native/off/Gen-I/II math stays on original DVs. In particular a
      -- complete cached modern block must not evade a native ensure call.
      local original=bridge.previousCalc(d,mon.level or 1,mon.dvs,mon.statExp,mon)
      mon.stats=original
      mon.hp=mon.isEgg and 0 or math.max(0,math.min(tonumber(mon.hp)or 0,original.hp))
    end
  end
  bridge.owner=M
  if not bridge.installed then
    bridge.previousCalc,bridge.previousEnsure=Stats.calc,Stats.ensure
    Stats.calc=function(d,level,dvs,exp,mon,...)
      -- Delegate first so the established calculator chain is respected.
      -- Foreign definitions/identities retain its exact result unchanged.
      local original=bridge.previousCalc(d,level,dvs,exp,mon,...)
      local owner=bridge.owner
      return owner and owner.calcProjection(d,level,dvs,exp,mon)or original
    end
    Stats.ensure=function(d,mon,...)
      local result=bridge.previousEnsure(d,mon,...)
      local owner=bridge.owner;if owner then owner.ensureProjection(d,mon)end
      return result
    end
    bridge.installed=true
  end
  return M
end
