-- KASC-67-BACKEND-GENERATION-AUTHORITY. Pure, versioned data resolution.
-- This Card resolves facts; battle support is a separate capability, never
-- inferred from the existence of a move or ability in this catalog.
return function(opts)
  opts=opts or {}
  local data=assert(opts.data,'backend generation data required')
  local catalog=assert(opts.catalog,'backend species catalog required')
  local load=assert(opts.load,'learnset loader required')
  local overrides=opts.formLearnsetOverrides
  if overrides then assert(overrides.schema=='kasc.form-learnset-overrides/v1')end
  assert(data.schema=='kasc.backend-generation-rules/v1')
  local M={CARD_ID='KASC-67-BACKEND-GENERATION-AUTHORITY',
    OWNER='kasc.backend.generation-authority/v1',schema=data.schema}
  if opts.supportLog and type(opts.supportLog.registerSegment)=='function' then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='pinned-local-data',
      providerStatus='read-only-authority-loaded',
      buildReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md#rollback-regelautorität'})
  end
  local cache={}
  -- Main-series battle-era baselines. In particular LGPE/Legends/Champions
  -- must not silently replace the USUM/SwSh/SV rule era just by sorting last.
  local defaults=opts.defaultVersionGroups or {[1]=2,[2]=4,[3]=6,[4]=9,
    [5]=14,[6]=16,[7]=18,[8]=22,[9]=27}
  local function copy(v)
    if type(v)~='table' then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  local function get(t,k)return t and (t[tostring(k)] or t[k])end
  local function entry(key)
    if type(key)=='table' then key=key.backendKey or key.key end
    return catalog.entries[key]
  end
  local function source(row)
    local pid=row.pokeapiId
    if not get(data.learnsetPaths,pid) and not row.isBase then
      local base=catalog.entries['dex:'..row.nationalDex]
      pid=base and base.pokeapiId
    end
    if not pid then return nil end
    if not cache[pid] then
      local path=get(data.learnsetPaths,pid)
      if not path then return nil end
      cache[pid]=assert(load(path),'missing learnset '..tostring(pid))
    end
    return cache[pid],pid
  end
  function M.epoch(key,active)
    local row=entry(key)
    if not row then return nil,'unknown_species' end
    local epoch=math.max(1,math.min(9,math.floor(tonumber(active) or 1)))
    -- A Gen7+ gift uses at least its own introduction generation. Its
    -- existence does not raise the global rule selector or frontend Dex.
    if row.originGeneration>6 then epoch=math.max(epoch,row.originGeneration)end
    return epoch
  end
  function M.baseStats(key,active)
    local row=entry(key);if not row then return nil,'unknown_species' end
    -- No fabricated pre-introduction stats for a later gift or form.
    local epoch=math.max(M.epoch(key,active),row.originGeneration)
    local result=copy(row.baseStats)
    local rename={[1]='hp',[2]='atk',[3]='def',[4]='spa',[5]='spd',[6]='spe',[9]='special'}
    local past=get(data.baseStatsPast,row.pokeapiId) or {}
    local generations={}
    for gen in pairs(past)do
      if tonumber(gen)>=epoch then generations[#generations+1]=tonumber(gen)end
    end
    table.sort(generations,function(a,b)return a>b end)
    for _,gen in ipairs(generations)do
      for stat,value in pairs(get(past,gen))do
        result[assert(rename[tonumber(stat)],'unknown historical stat')]=value
      end
    end
    -- Original Special is explicit and is NOT modern SpA or SpD.
    -- The Gen-I runtime remains native; consumers can inspect this fact.
    if epoch==1 and result.special then result.spa=result.special;result.spd=result.special end
    return result,epoch
  end
  function M.learnset(key,active,requestedGroup)
    local row=entry(key);if not row then return nil,'unknown_species' end
    local epoch=M.epoch(key,active)
    local override=overrides and overrides.entries[row.key]
    if override and epoch==override.generation
        and (not requestedGroup or tonumber(requestedGroup)==override.versionGroup) then
      return {key=row.key,pokeapiId=row.pokeapiId,inherited=override.inherited,
        generation=epoch,versionGroup=override.versionGroup,rows=copy(override.rows),
        sourceSpecies=override.sourceSpecies,sourceCommit=overrides.commit,source=overrides.source}
    end
    local byVersion,pid=source(row);if not byVersion then return nil,'no_learn_source' end
    local chosen,rank
    if requestedGroup then
      local group=get(data.groups,requestedGroup)
      if not group or group.generation~=epoch or not get(byVersion,requestedGroup) then
        return nil,'wrong_version_group'
      end
      chosen=tonumber(requestedGroup)
    else
      if get(byVersion,defaults[epoch])then chosen=defaults[epoch]end
      for id in pairs(byVersion)do
        local group=get(data.groups,id)
        if not get(byVersion,defaults[epoch]) and group and group.generation==epoch and (not rank or group.order>rank) then
          chosen,rank=tonumber(id),group.order
        end
      end
    end
    if not chosen then return nil,'no_source_for_generation' end
    return {key=row.key,pokeapiId=pid,inherited=pid~=row.pokeapiId,
      generation=epoch,versionGroup=chosen,rows=copy(get(byVersion,chosen))}
  end
  -- Enumerate legal historical sources for this exact identity, never a
  -- national-Dex union that could leak another regional form's moves.
  function M.learnsetGroups(key,active)
    local row=entry(key);if not row then return {} end
    local byVersion=source(row);local out={}
    local ceiling=math.max(M.epoch(key,active),row.originGeneration)
    for id in pairs(byVersion or {})do
      local group=get(data.groups,id)
      if group and group.generation>=row.originGeneration
          and group.generation<=ceiling then
        out[#out+1]={generation=group.generation,versionGroup=tonumber(id)}
      end
    end
    table.sort(out,function(a,b)return a.generation<b.generation
      or a.generation==b.generation and a.versionGroup<b.versionGroup end)
    return out
  end
  local physical={NORMAL=true,FIGHTING=true,FLYING=true,POISON=true,
    GROUND=true,ROCK=true,BUG=true,GHOST=true,STEEL=true}
  function M.move(id,epoch,requestedGroup)
    local current=data.moves[id];if not current then return nil,'unknown_move' end
    epoch=math.max(1,math.min(9,math.floor(tonumber(epoch) or 1)))
    local extension=current.generation>6 and current.generation>epoch
    if current.generation>epoch and not extension then return nil,'move_not_introduced' end
    local effective=extension and current.generation or epoch
    local group=get(data.groups,requestedGroup or defaults[effective])
    if requestedGroup and not group then return nil,'wrong_version_group' end
    if group and group.generation~=effective then return nil,'wrong_version_group' end
    if not group then
      for _,g in pairs(data.groups)do
        if g.generation==effective and (not group or g.order>group.order)then group=g end
      end
    end
    if not group then return nil,'unknown_generation' end
    local result=copy(current);local history=copy(current.history)
    table.sort(history,function(a,b)
      return get(data.groups,a.versionGroup).order>get(data.groups,b.versionGroup).order
    end)
    local rename={type_id='typeId',target_id='target',effect_id='effect',effect_chance='effectChance'}
    for _,change in ipairs(history)do
      if get(data.groups,change.versionGroup).order>group.order then
        for k,v in pairs(change)do
          if k~='versionGroup' then result[rename[k] or k]=v end
        end
        if change.accuracy~=nil then result.alwaysHits=false end
      end
    end
    result.type=get(data.types,result.typeId)
    -- PokeAPI does not encode this priority history. Pinned Showdown Gen IV
    -- moves.ts keeps Fake Out at +1; +3 starts in Gen V.
    if id=='FAKE_OUT'and effective<=4 then result.priority=1 end
    -- PokeAPI's meta/stat rows have no historical versions. LGPE's moves
    -- retain their Gen-VII effects (pinned Showdown gen7/moves.ts).
    if effective<=7 and id=='BOUNCY_BUBBLE'then result.meta.drain=50 end
    if effective<=7 and id=='ZIPPY_ZAP'then
      result.meta.crit_rate=6;result.meta.stat_chance=0;result.meta.meta_category_id=0;result.statChanges={}
    end
    if effective<4 and result.category~='status' then
      result.category=physical[result.type] and 'physical' or 'special'
    end
    result.effectiveGeneration=effective;result.extension=extension
    result.versionGroup=group.id
    return result
  end
  function M.statChanges(id,epoch)
    local source=data.moves[id];if not source then return nil,'unknown_move' end
    epoch=math.max(1,math.min(9,tonumber(epoch) or 1))
    -- PokeAPI's stat-change rows describe current mechanics. These explicit
    -- historical exceptions are sourced from pinned Showdown Gen3/4 rules.
    if id=='GROWTH' and epoch<=4 then return {{4,1}}end
    if id=='TAIL_GLOW' and epoch<=4 then return {{4,2}}end
    if id=='ACID' and epoch<=3 then return {{3,-1}}end
    if id=='CRUNCH' and epoch<=3 then return {{5,-1}}end
    if id=='STRING_SHOT' and epoch<=5 then return {{6,-1}}end
    if id=='SWEET_SCENT' and epoch<=5 then return {{8,-1}}end
    if id=='RAPID_SPIN' and epoch<8 then return {}end
    if id=='ZIPPY_ZAP' and epoch<=7 then return {}end
    return copy(source.statChanges)
  end
  function M.abilitySlots(key,active,includeHidden)
    local row=entry(key);if not row then return nil,'unknown_species' end
    local epoch=M.epoch(key,active)
    if epoch<3 then return {},'inactive_generation' end
    local slots={}
    for _,slot in ipairs(get(data.abilitySlots,row.pokeapiId) or {})do slots[slot.slot]=slot end
    local past=get(data.abilitySlotsPast,row.pokeapiId) or {};local generations={}
    for gen in pairs(past)do if tonumber(gen)>=epoch then generations[#generations+1]=tonumber(gen)end end
    table.sort(generations,function(a,b)return a>b end)
    -- Past rows are per-slot changes, not a complete replacement roster.
    -- A NULL ability removes only that slot (e.g. pre-Gen5 hidden abilities).
    for _,gen in ipairs(generations)do
      for _,slot in ipairs(get(past,gen))do slots[slot.slot]=slot.ability~=0 and slot or nil end
    end
    local result={}
    for _,slot in pairs(slots)do
      local ability=get(data.abilities,slot.ability)
      if ability and ability.generation<=epoch and (not slot.hidden or includeHidden and epoch>=5)then
        result[#result+1]={slot=slot.slot,hidden=slot.hidden,id=ability.id,
          number=slot.ability,names=copy(ability.names)}
      end
    end
    table.sort(result,function(a,b)return a.slot<b.slot end)
    return result
  end
  function M.heldTable(key,epoch,version)
    local row=entry(key);if not row then return nil,'unknown_species' end
    epoch=math.max(1,math.min(9,math.floor(tonumber(epoch) or 1)))
    if epoch<2 then return {},'inactive_generation' end
    if epoch==2 then
      version=tonumber(version or 6)
      local versions=data.gen2Held and data.gen2Held.versions
      local byDex=get(versions,version)
      if not byDex then return nil,'wrong_version' end
      -- A regional form must never inherit the old species' wild item roll.
      local slots=row.isBase and get(byDex,row.nationalDex)
      if not slots then return {},'species_not_in_generation',version end
      local result={}
      -- Preserve native byte probabilities: 192/256 none, then 20/256
      -- selects item2. They are not the later 50%/5% item probabilities.
      for slot,id in ipairs(slots)do
        if id~='NO_ITEM' then
          result[#result+1]={id=id,slot=slot,
            percent=slot==1 and 23.046875 or 1.953125}
        end
      end
      return result,nil,version
    end
    local byVersion=get(data.wildHeldItems,row.pokeapiId) or {}
    local selected,rank
    if version then
      local v=get(data.versions,version);local g=v and get(data.groups,v.group)
      if not g or g.generation~=epoch then return nil,'wrong_version' end
      selected=version
    else
      for id in pairs(byVersion)do
        local v=get(data.versions,id);local g=v and get(data.groups,v.group)
        if g and g.generation==epoch and (not rank or g.order>rank or
          g.order==rank and tonumber(id)<tonumber(selected))then selected,rank=id,g.order end
      end
    end
    local result,total={},0
    for _,r in ipairs(get(byVersion,selected) or {})do
      local item=get(data.items,r.item)
      if item and item.generation<=epoch then
        total=total+r.percent;result[#result+1]={id=item.id,number=r.item,percent=r.percent}
      end
    end
    if total>100 then return nil,'invalid_probability_total' end
    return result,nil,tonumber(selected)
  end
  function M.rollHeld(key,epoch,version,rng,context)
    local values,reason,selected=M.heldTable(key,epoch,version)
    if not values then return nil,reason end
    if tonumber(epoch)==2 and not reason then
      local row=entry(key)
      local slots=get(get(data.gen2Held.versions,selected),row.nationalDex)
      if context and context.forceFirstItem==true then
        return slots[1]~='NO_ITEM' and slots[1] or false,nil,selected
      end
      local function byte()
        local value=assert(rng,'explicit rng required')(0,255)
        assert(type(value)=='number' and value%1==0 and value>=0 and value<=255,'invalid rng draw')
        return value
      end
      if byte()<data.gen2Held.rng.noneBelow then return false,nil,selected end
      local id=slots[byte()<data.gen2Held.rng.secondItemBelow and 2 or 1]
      return id~='NO_ITEM' and id or false,nil,selected
    end
    if #values==0 then return false,reason,selected end
    local roll=assert(rng,'explicit rng required')(1,100)
    assert(type(roll)=='number' and roll>=1 and roll<=100 and roll%1==0,'invalid rng draw')
    local total=0
    for _,r in ipairs(values)do total=total+r.percent;if roll<=total then return r.id,nil,selected end end
    return false,nil,selected
  end
  function M.item(id,epoch)
    if tonumber(epoch)==2 and data.gen2Held and data.gen2Held.items[id] then
      return copy(data.gen2Held.items[id])
    end
    for _,item in pairs(data.items)do if item.id==id then return copy(item)end end
    return nil,'unknown_item'
  end
  M.data=data
  return M
end
