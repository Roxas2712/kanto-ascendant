-- KASC-67-ABILITY-BINDING: deterministic, save-owned ability slots.
-- Pure plans/views. The equipment transaction owns application and rollback.
return function(opts)
  local facts=assert(opts.facts)
  local catalog=assert(opts.catalog)
  local sha=assert(opts.digest)
  local M={CARD_ID='KASC-67-ABILITY-BINDING',schema='kasc.ability-slot/v1'}
  -- Custom KASC evolution: retain Raichu's historical slot progression,
  -- without pretending Gorochu is Raichu in the species/Dex registries.
  local customSources={['custom:gorochu']='dex:26'}
  function M.abilitySlots(key,epoch,includeHidden)
    return facts.abilitySlots(customSources[key] or key,epoch,includeHidden)
  end
  local bySpecies={}
  for key,row in pairs(catalog.entries)do
    local id=row.identifier:upper():gsub('-','_')
    bySpecies[id]=key
    local base,region=id:match('^(.-)_(ALOLA)$')
    if base then bySpecies[region..'_'..base]=key end
  end
  local function egg(mon)return mon.isEgg or mon.egg or mon.eggSpecies or mon.species=='EGG'end
  function M.key(game,mon)
    local def=game.data and game.data.pokemon and game.data.pokemon[mon.species] or {}
    if mon.species=='GOROCHU' and def.id=='GOROCHU' then return 'custom:gorochu' end
    -- A gift's saved backendKey records its birth species and survives
    -- evolution. Resolve the live species first so the stable ability SLOT
    -- follows the new species, without rerolling or rewriting provenance.
    local explicit=def.backendKey
    if explicit and catalog.entries[explicit]then return explicit end
    if bySpecies[mon.species] then return bySpecies[mon.species] end
    local dex=tonumber(def.sourceDex)
    if dex and catalog.entries['dex:'..dex]then return 'dex:'..dex end
    return nil,'unknown_species'
  end
  local function valid(row)
    return type(row)=='table' and row.schema==M.schema
      and (row.slot==1 or row.slot==2 or row.slot==3)
      and type(row.originKey)=='string'
      and (catalog.entries[row.originKey]~=nil or customSources[row.originKey]~=nil)
  end
  function M.plan(game,mon,handle,epoch)
    if mon._kascAbility67~=nil then
      if not valid(mon._kascAbility67) then return nil,'invalid_ability_binding' end
      return false
    end
    if egg(mon) or epoch<3 then return false end
    local key=M.key(game,mon);if not key then return false end
    local slots=M.abilitySlots(key,epoch,true)
    if not slots or #slots==0 then return false end
    local existing=mon.abilityId or mon.ability
    local hasExisting=existing~=nil and existing~=false and existing~=0 and existing~=''
    local selected
    if hasExisting then
      for _,slot in ipairs(slots)do
        if existing==slot.id or existing==slot.number then selected=slot end
      end
      -- Preserve an unrecognized legacy ability verbatim, but do not silently
      -- substitute a newly rolled ability for it or declare it supported.
      if not selected then return false end
    else
      local normal={}
      for _,slot in ipairs(slots)do if not slot.hidden then normal[#normal+1]=slot end end
      if #normal==0 then return false end
      local seed=assert(tonumber(sha('ability-slot:'..handle):sub(1,8),16))
      selected=normal[seed%#normal+1]
    end
    return {_kascAbility67={schema=M.schema,slot=selected.slot,originKey=key,
      originalId=selected.id,source=hasExisting and 'existing' or 'identity-migration'}}
  end
  function M.view(game,mon,epoch)
    if egg(mon)then return {id=false,active=false,reasonCode='egg_unrevealed'}end
    local binding=mon._kascAbility67
    if not binding then return {id=false,active=false,reasonCode='no_ability'}end
    if not valid(binding)then return {id=false,active=false,reasonCode='invalid_ability_binding'}end
    local key=M.key(game,mon)
    if not key then return {id=false,slot=binding.slot,active=false,reasonCode='unknown_species'}end
    -- A validated temporary Mega profile supplies its own ability, without
    -- overwriting the base Pokemon's stable slot or save provenance.
    local megaKey=epoch>=6 and opts.megaKey and opts.megaKey(mon)
    if megaKey then key=megaKey end
    -- Dormant profiles still display the preserved ability without activating
    -- it. The current species and historical table resolve the stable slot.
    local slots=M.abilitySlots(key,math.max(epoch,3),not megaKey and binding.slot==3) or {}
    local selected
    for _,slot in ipairs(slots)do if slot.slot==(megaKey and 1 or binding.slot)then selected=slot end end
    if not selected and (megaKey or binding.slot~=3)then selected=slots[1]end
    if not selected then return {id=false,slot=binding.slot,active=false,reasonCode='inactive_generation'}end
    local supported=opts.supports and opts.supports(game,selected.id,epoch)==true or false
    local active=epoch>=3 and supported
    local reason=false
    if epoch<3 then reason='inactive_generation'
    elseif not supported then reason='effect_not_implemented' end
    return {id=selected.id,slot=binding.slot,names=selected.names,active=active,reasonCode=reason}
  end
  -- Reserve once alongside the egg's DVs/moves, never at pickup/hatching.
  -- Gen3/4 use the independent normal slot. Gen5+ may inherit the parent's
  -- slot, but Ditto never contributes its own ability. The hidden-slot
  -- availability still comes from the historical species authority.
  function M.reserveEgg(game,species,parent,withDitto,epoch,seed)
    local child={species=species}
    local plan=M.plan(game,child,'egg:'..seed,math.max(3,epoch))
    if not plan then return false end
    local result=plan._kascAbility67
    result.source='egg-reservation';result.birthEpoch=epoch
    local inherited=parent and parent._kascAbility67
    if epoch>=5 and valid(inherited) and (epoch>=6 or not withDitto) then
      local slots=M.abilitySlots(result.originKey,epoch,true) or {}
      local selected
      for _,slot in ipairs(slots)do if slot.slot==inherited.slot then selected=slot end end
      local chance=inherited.slot==3 and (epoch==5 and 80 or 60) or 80
      local roll=tonumber(sha('egg-inheritance:'..seed):sub(1,8),16)%100
      if selected and roll<chance then
        result.slot=selected.slot;result.originalId=selected.id
        result.source='egg-parent-slot'
      end
    end
    return result
  end
  return M
end
