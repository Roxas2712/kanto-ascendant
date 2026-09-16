-- Actual critical hits in one completed battle, not level/preview counters.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-SIRFETCHD',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local method='KA_WAVE1_THREE_CRITICAL_HITS'
  local parent,target,base=S.byKey['form:10166'],S.byKey['dex:865'],S.byKey['dex:83']
  local p,t=parent and registry:get(parent),target and registry:get(target)
  if parent~='KA_GIFT_FORM_10166' or not p or p.backendOwner~=S.OWNER
      or p.backendKey~='form:10166' or p.sourceDex~=83 or p.formId~='BACKEND_10166'
      or base~='FARFETCHD' or not registry:get(base) or p.baseSpecies~=base
      or p.isMega or p.isGigantamax or p.form then C.pending[#C.pending+1]='parent_identity'end
  if target~='KA_GIFT_NAT_865' or not t or t.backendOwner~=S.OWNER
      or t.backendKey~='dex:865' or t.sourceDex~=865 or t.formId or t.form
      or t.baseSpecies or t.isMega or t.isGigantamax then C.pending[#C.pending+1]='target_identity'end
  if p and #(p.evolutions or {})>0 then C.pending[#C.pending+1]='existing_edges'end
  if mod.content.evolution_methods:get(method) then C.pending[#C.pending+1]='method_owned'end
  if #C.pending>0 then return C end
  local Evolution=require('src.pokemon.Evolution')
  local Battle=require('src.battle.BattleState')
  local counts=setmetatable({},{__mode='k'})
  local finished=setmetatable({},{__mode='k'})
  local active=setmetatable({},{__mode='k'})
  local permit=setmetatable({},{__mode='k'})
  local function body(mon)
    return type(mon)=='table' and mon.species==parent and mon.formId==p.formId
      and mon.baseSpecies==base and (not mon.form or mon.form==p.formId)
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and not mon._ascMegaForm and not mon.ascMegaForm
      and not mon.cosmeticForm and not mon.cosmeticFormId
      and type(mon.level)=='number' and mon.level==math.floor(mon.level)
      and mon.level>=1 and mon.level<=100
  end
  local function healthy(mon)
    return body(mon) and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
  end
  local function member(game,mon)
    for _,m in ipairs(game and game.save and game.save.party or {})do
      if m==mon then return true end
    end
    return false
  end
  local function edge(mon,evo)
    return healthy(mon) and type(evo)=='table' and evo.method==method and evo.species==target
      and not evo.level and not evo.item and not evo.move and not evo.partySpecies
  end
  mod.content.evolution_methods:register(method,{
    check=function(game,mon,evo,trigger)
      return C.ready and edge(mon,evo) and member(game,mon) and permit[game]==mon
        and trigger and trigger.kind=='critical-battle' or false
    end,
    describe=function()return opts.i18n.text('3 critical hits in one completed battle',
      '3 Volltreffer in einem abgeschlossenen Kampf')end,
  })
  registry:patch(parent,{evolutions={{method=method,species=target}}})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if C.ready and edge(mon,evo) and archive then
      local valid,_,profile=archive.battleCompatibleGift(mon)
      if valid and profile and profile.backendKey=='form:10166' and profile.species==parent
          and profile.formId==p.formId and profile.baseSpecies==base
          and not profile.megaFormId and not profile.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  local function real(b)
    return getmetatable(b)==Battle and not b.demo and (b.kind=='wild' or b.kind=='trainer')
      and b.game and b.game.save and b.player and b.enemy
  end
  mod.events:on('battle.started',function(ev)
    local b=ev and ev.battle
    if real(b) then counts[b]={};finished[b.game]=nil;active[b.game]=b end
  end)
  mod.events:on('battle.damage_dealt',function(ev)
    local b=ev and ev.battle;local row=b and counts[b]
    if not (row and real(b) and not b.result and ev.user==b.player and ev.target==b.enemy
        and ev.crit==true and type(ev.damage)=='number' and ev.damage>0 and ev.damage<math.huge
        and body(ev.user.mon) and member(b.game,ev.user.mon)) then return end
    local mon=ev.user.mon;row[mon]=math.min(3,(row[mon] or 0)+1)
  end)
  local function collect(b,result,skipped)
    local row=b and counts[b]
    if b then counts[b]=nil end
    if b and b.game and active[b.game]==b then active[b.game]=nil end
    if not (row and real(b)) then return {} end
    if skipped or (result~='win' and result~='caught') then return {} end
    local list={}
    for _,mon in ipairs(b.game.save.party or {})do
      if row[mon]==3 and healthy(mon) then list[#list+1]=mon end
    end
    return list
  end
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle
    local list=collect(b,ev and ev.result,ev and ev.skipped)
    if #list>0 then finished[b.game]=list end
  end)
  -- Compose with native party-order level evolutions. A single-use in-memory
  -- permit prevents Rare Candy/manual requests and does not pollute saves.
  local checkParty=Evolution.checkParty
  local function pending(game,mon)
    if not (healthy(mon) and member(game,mon)) then return end
    permit[game]=mon
    local ok,to,evo=pcall(Evolution.pendingFor,game,mon,{kind='critical-battle'})
    permit[game]=nil
    if not ok then error(to,0)end
    return to,evo
  end
  Evolution.checkParty=function(game,onDone,leveledUp)
    local candidates=finished[game] or {};finished[game]=nil
    -- Newer native cores run checkParty inside BattleState.finish, before
    -- battle.ended/map return. Older cores do so afterwards. Consume once
    -- at the native completion checkpoint, never during ordinary turns.
    local b=active[game]
    if real(b) and b.evolutionsChecked==true and (b.result=='win' or b.result=='caught') then
      candidates=collect(b,b.result,false)
    end
    local list={}
    for _,mon in ipairs(candidates)do if pending(game,mon) then list[#list+1]=mon end end
    local function extra()
      local i=0
      local function nextOne()
        i=i+1;local mon=list[i]
        if not mon then if onDone then onDone()end;return end
        local to,evo=pending(game,mon)
        if to then Evolution.evolve(game,mon,to,nextOne,evo.method) else nextOne()end
      end
      nextOne()
    end
    return (checkParty(game,extra,leveledUp) or 0)+#list
  end
  mod.events:on('pokemon.evolved',function(ev)
    if ev and ev.via==method and ev.fromSpecies==parent and ev.toSpecies==target
        and ev.mon and ev.mon.species==target then
      ev.mon.formId=nil;ev.mon.form=nil;ev.mon.baseSpecies=nil
    end
  end,900)
  C.ready=true;C.method=method;C.parent=parent;C.target=target;return C
end
