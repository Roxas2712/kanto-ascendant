-- Ninjatom's body rule and the existing Hoenn bonus, not a second award owner.
return function(mod,opts)
  local M={CARD_ID='KASC-WAVE1-SHEDINJA',OWNER='kasc.shedinja-body/v1',ready=false}
  local registry=mod.content.pokemon
  local def=registry:get('SHEDINJA')
  if not opts.hoenn.enabled or not def or def.id~='SHEDINJA' or def.sourceDex~=292
      or def.formId or def.isMega or def.isGigantamax or def.baseStats.hp~=1
      or not registry:get('NINCADA') or not registry:get('NINJASK') then return M end
  if def.kascShedinjaBody67 then return M end
  registry:patch('SHEDINJA',{kascShedinjaBody67=M.OWNER})
  local Stats=require('src.pokemon.Stats')
  local function copy(x)
    if type(x)~='table'then return x end
    local out={};for k,v in pairs(x)do out[k]=copy(v)end;return out
  end
  function M.matches(d,mon)
    return M.ready and type(d)=='table' and d.id=='SHEDINJA' and d.sourceDex==292
      and d.kascShedinjaBody67==M.OWNER and not d.formId and not d.isMega
      and not d.isGigantamax and (not mon or mon.species=='SHEDINJA')
  end
  function M.normalize(d,mon)
    if not M.matches(d,mon) or mon.isEgg or mon.egg or mon.eggSpecies then return end
    if type(mon.stats)=='table' then
      mon.stats=copy(mon.stats);mon.stats.hp=1
      if type(mon.hp)=='number' then mon.hp=mon.hp>0 and 1 or 0 end
    end
  end
  -- Frozen native Stats.calc has no post-stat hook. One composable runtime
  -- adapter covers creation, level-up and box recalculation without changing
  -- engine files, other species, IVs or permanent base stats.
  Stats._kascShedinjaOwner67=M
  if not Stats._kascShedinjaWrapped67 then
    local calc,ensure=Stats.calc,Stats.ensure
    Stats.calc=function(d,level,dvs,evs,mon)
      local result=calc(d,level,dvs,evs,mon)
      local owner=Stats._kascShedinjaOwner67
      if owner and owner.matches(d,mon)then result.hp=1 end
      return result
    end
    Stats.ensure=function(d,mon)
      local result=ensure(d,mon);local owner=Stats._kascShedinjaOwner67
      if owner and type(mon)=='table'then owner.normalize(d,mon)end
      return result
    end
    Stats._kascShedinjaWrapped67=true
  end
  function M.install(game)
    if not M.ready or not(game and game.save and game.data)then return end
    for _,mon in ipairs(game.save.party or {})do M.normalize(game.data.pokemon[mon.species],mon)end
    for _,box in ipairs(game.save.boxes or {})do
      for _,mon in ipairs(box)do M.normalize(game.data.pokemon[mon.species],mon)end
    end
  end
  function M.prepareBonus(game,source,bonus)
    if not M.ready or source.species~='NINJASK' or bonus.species~='SHEDINJA'then return false end
    if source.eventDistribution then
      local archive=mod.exports and mod.exports.eventArchive
      local valid,_,profile
      if archive then valid,_,profile=archive.battleCompatibleGift(source)end
      if not valid or not profile or profile.species~='NINCADA'
          or profile.backendKey~='dex:290' or profile.formId or profile.megaFormId
          or profile.gigantamaxFormId then return false end
      bonus.eventDistribution=copy(source.eventDistribution)
      local receipt=bonus.eventDistribution.giftCode
      if receipt then
        local parent=receipt.digest
        receipt.digest=opts.digest('kasc.shedinja-bonus/v1:'..parent)
        bonus.eventDistribution.derivedFrom={schema='kasc.shedinja-bonus/v1',digest=parent}
      end
      bonus.backendKey='dex:292'
      if not archive.battleCompatibleGift(bonus)then return false end
    end
    -- Preserve the parent's earned training and known attacks, but not its
    -- held item, nickname, gender binding or equipment identity. The new body
    -- receives its own genderless/ability identity through normal equipment.
    for _,key in ipairs({'dvs','statExp','moves','exp','friendship','happiness'})do
      if source[key]~=nil then bonus[key]=copy(source[key])end
    end
    bonus.stats=Stats.calc(game.data.pokemon.SHEDINJA,bonus.level,bonus.dvs,bonus.statExp,bonus)
    bonus.hp=1;bonus.status=nil
    return true
  end
  M.ready=true;return M
end
