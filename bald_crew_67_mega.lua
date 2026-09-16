-- Only the admitted final encounter may transform each of its six enemies.
-- Normal Mega equipment/options/link policy and the player's once-only flag
-- stay owned by mega_evolution.lua. No global option is changed.
return function(mod,opts)
 local D,Mega=assert(opts.data),assert(opts.mega)
 local M={}
 local plans=setmetatable({},{__mode='k'})
 local original=Mega.activate
 function M.prepare(battle,row)
  if row~=D.opponents.pandy then return function()return true end end
  local rule=row.developerMegaOverride
  if not(rule and rule.scope=='this_battle_only'and rule.enemyActivations==12
    and rule.playerActivations==1 and battle.kaCrewOpponent==row.id
    and battle.ascendantForcedSource=='bald_crew:pandy'and battle.kind=='trainer'
    and #battle.enemyParty==6)then return nil,'invalid_final_mega_contract'end
  local forms={};for _,p in ipairs(Mega.forms)do forms[p.id]=p end
  local plan={slots={},used={},count=0,token=false,reserve=battle.kaCrewReserveParty}
  if type(plan.reserve)~='table'or #plan.reserve~=6 or not row.phaseTwo then return nil,'missing_reserve'end
  for phase,roster in ipairs({row.team,row.phaseTwo.team})do
  local party=phase==1 and battle.enemyParty or plan.reserve
  for i,slot in ipairs(roster)do
   local p=slot.megaKey and opts.backend and opts.backend.byKey[slot.megaKey]or forms[slot.megaForm]
   if not(p and p.species==slot.species and not p.secret
     and party[i].species==slot.species)then return nil,'missing_final_mega:'..phase..':'..i end
   if p.requiredMove then
    local found=false;for _,move in ipairs(party[i].moves)do if move.id==p.requiredMove then found=true end end
    if not found then return nil,'missing_mega_move:'..i end
   end
   plan.slots[(phase-1)*6+i]={mon=party[i],species=p.species,form=p.id}
  end
  end
  return function(token)
   if type(token)~='string'or token==''or battle.kaBaldCrewToken~=token then return false,'battle_token'end
   plan.token=token;plans[battle]=plan;battle._ascMegaEnemyPending=nil
   return true
  end
 end
 function M.activate(battle,battler,side)
  local p=plans[battle]
  if not p or side~='enemy'then return original(battle,battler,side)end
  local index=battle.enemyIndex;local i=((battle.kaCrewPhase or 1)-1)*6+index;local slot=p.slots[i]
  if battle.kaBaldCrewToken~=p.token or not slot or battler~=battle.enemy
    or battler.mon~=slot.mon or battle.enemyParty[index]~=slot.mon or slot.mon.species~=slot.species
    or battler.isPlayer or (battler.mon.hp or 0)<=0 then return false,'crew_identity'end
  if p.used[i]or p.count>=12 then return false,'used'end
  local used,form,pending=battle._ascMegaEnemyUsed,battle.ascendantEnemyMegaForm,battle._ascMegaEnemyPending
  battle._ascMegaEnemyUsed=nil;battle.ascendantEnemyMegaForm=slot.form;battle._ascMegaEnemyPending=nil
  local ok,activated,why=pcall(original,battle,battler,'enemy')
  if not ok or not activated then
   battle._ascMegaEnemyUsed=used;battle.ascendantEnemyMegaForm=form;battle._ascMegaEnemyPending=pending
   if not ok then error(activated,0)end
   return false,why
  end
  p.used[i]=true;p.count=p.count+1
  battle.kaCrewMegaActivations=p.count
  return true
 end
 function M.install()
  if M.installed then return false end
  M.installed=true;Mega.activate=M.activate
  local B=opts.battleState or require('src.battle.BattleState')
  local faint=B.enemyMonFainted
  if faint then B.enemyMonFainted=function(b,...)
   local plan=plans[b];local nextIndex
   for i,mon in ipairs(b.enemyParty or{})do if mon.hp>0 then nextIndex=i;break end end
   local function say(row)
    if row then b:say(opts.i18n and opts.i18n.text(row.en,row.de)or row.en)end
   end
   if plan and b.kaBaldCrewToken==plan.token and not nextIndex
     and b.kaCrewPhase==1 and not b.result then
    local alive=false
    for _,m in ipairs(b.game.save.party)do if m.hp>0 then alive=true;break end end
    if alive then
     -- Same battle, same player battler, PP, status, fields and Mega receipt.
     -- Never call newTrainer/finish/heal here. Replace six slots, not a 12-slot HUD.
     b.kaCrewPhase=2;b.kaCrewCheatUsed=true
     b.kaCrewDefeatedFirstParty=b.enemyParty
     b.enemyParty=plan.reserve;b.kaCrewReserveParty=nil
     b:act(function()b.showEnemyTrainer=b.trainerPic~=nil end)
     say(opts.dialogue and opts.dialogue.cheat or {en='CHEAT: RESERVE LOADED. Six more Megas. No player heal.',de='CHEAT: RESERVE GELADEN. Sechs weitere Megas. Keine Spielerheilung.'})
     b:act(function()b.showEnemyTrainer=false end)
     nextIndex=1
    end
   end
   if b.kaBaldCrew and b.kaBaldCrewToken and nextIndex and nextIndex>1 and opts.dialogue then
    b.kaCrewSpoken=b.kaCrewSpoken or{}
    local n=nextIndex-1+((b.kaCrewPhase or 1)-1)*5
    local key=(b.kaCrewPhase or 1)..':'..nextIndex
    local en=opts.dialogue.sendouts[b.kaCrewOpponent]
    local de=opts.dialogue.sendoutsDE[b.kaCrewOpponent]
    if en and en[n]and not b.kaCrewSpoken[key]then
     b.kaCrewSpoken[key]=true
     b:act(function()b.showEnemyTrainer=b.trainerPic~=nil end)
     say({en=b.trainer.name..': '..en[n],de=b.trainer.name..': '..de[n]})
     b:act(function()b.showEnemyTrainer=false end)
    end
   end
   return faint(b,...)
  end end
  local update=B.update
  B.update=function(b,dt,...)
   if plans[b]and b.phase=='menu'and not b.demo and not b.safari then
    local ok,why=M.activate(b,b.enemy,'enemy')
    b.kaCrewMegaDenial=not ok and why or nil
    if ok then return end
   end
   return update(b,dt,...)
  end
  mod.events:on('battle.ended',function(ev)
   if ev and ev.battle then plans[ev.battle]=nil end
  end)
  return true
 end
 return M
end
