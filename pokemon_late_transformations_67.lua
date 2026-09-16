-- Primal Reversion and Ultra Burst are NOT Mega forms or permanent species.
-- Existing HPForms owns their native temporary stats, types and art aliases.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-LATE-TRANSFORMATIONS',OWNER='kasc.late-transformations/v1'}
  local forms,identity=assert(opts.forms),assert(opts.identity)
  local tr=opts.i18n.text;local rosters=setmetatable({},{__mode='k'})
  local target={['dex:382']='form:10077',['dex:383']='form:10078',
    ['form:10155']='form:10157',['form:10156']='form:10157'}
  local equipment={BLUE_ORB={number=535,generation=6,names={en='Blue Orb',de='Blauer Edelstein'},source='dex:382'},
    RED_ORB={number=534,generation=6,names={en='Red Orb',de='Roter Edelstein'},source='dex:383'},
    ULTRANECROZIUM_Z={number=923,generation=7,names={en='Ultranecrozium Z',de='Ultranecrozium Z'}}}
  local required={['dex:382']='BLUE_ORB',['dex:383']='RED_ORB',
    ['form:10155']='ULTRANECROZIUM_Z',['form:10156']='ULTRANECROZIUM_Z'}
  assert(forms.registerExternalSet({'dex:382'},'form:10077','PRIMAL_REVERSION_KYOGRE',6))
  assert(forms.registerExternalSet({'dex:383'},'form:10078','PRIMAL_REVERSION_GROUDON',6))
  assert(forms.registerExternalSet({'form:10155','form:10156'},'form:10157','ULTRA_BURST',7))
  for source,key in pairs(target)do
    local base,z=assert(opts.catalog.entries[source]),assert(opts.catalog.entries[key])
    assert(base.nationalDex==z.nationalDex and base.baseStats.hp==z.baseStats.hp and not z.isMega
      and not z.isGigantamax,'late transformation canonical source drift')
  end
  local expected={['form:10077']='PRIMORDIAL_SEA',['form:10078']='DESOLATE_LAND',['form:10157']='NEUROFORCE'}
  for key,id in pairs(expected)do
    local slots=assert(opts.facts.abilitySlots(key,7,false));assert(slots[1]and slots[1].id==id,'late form ability source drift '..key)
  end
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function lane(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy'or nil)or nil end
  local function party(b,side)
    return side=='player'and b.game and b.game.save and b.game.save.party
      or side=='enemy'and(b.enemyParty or{b.enemy and b.enemy.mon})or nil
  end
  local function slot(b,w)
    local side=lane(b,w)
    if side then for i,m in ipairs(party(b,side)or{})do if i<=6 and m==w.mon then return side..':'..i,side end end end
  end
  local function monFor(b,id)
    local side,i
    if type(id)=='string'then side,i=id:match('^(%a+):([1-6])$')end
    return i and(party(b,side)or{})[tonumber(i)]or nil
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{records={},usedUltra={}}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=marker and marker.kascLateTransformations67==M.OWNER and opts.status.epoch(b)
    return getmetatable(b)==B and not b.result and not b.demo and not b.safari and b.kind~='link'
      and marker and marker.kascHPForms67==forms.OWNER and gen and gen>=6 and gen<=7 and gen or nil
  end
  local function live(w)
    local m=w and w.mon
    return m and(tonumber(m.hp)or 0)>0 and not w.fainted
      and not(m.isEgg or m.egg or m.is_egg or m.eggSpecies)
  end
  local function clean(b,w)
    return M.epoch(b)and lane(b,w)and slot(b,w)and live(w)and not identity.transformed(w)
      and not w._ascMegaProfile and not w.mon._ascMegaForm and not w.mon.ascMegaForm
  end
  local function record(b,w)
    local s,k=state(b),slot(b,w);local r=s and k and s.records[k]
    return r and w.mon.species==r.species and r or nil
  end
  function M.itemMetadata(id)
    local r=equipment[id];if not r then return end
    return{id=id,number=r.number,generation=r.generation,names=copy(r.names),
      flags={'holdable','holdable-passive'},kascLateTransformation67=id}
  end
  function M.supportsItem(game,id,gen)
    local row=equipment[id];local def=game and game.data and game.data.items and game.data.items[id]
    local marker=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
    return row and def and def.kascLateTransformationOwner67==M.OWNER
      and marker and marker.kascLateTransformations67==M.OWNER and marker.kascHPForms67==forms.OWNER
      and type(gen)=='number'and gen%1==0 and gen>=row.generation and gen<=7 or false
  end
  for id,r in pairs(equipment)do
    local prior=mod.content.items:get(id)
    assert(not prior or prior.kascLateTransformationOwner67==M.OWNER,'foreign late transformation item '..id)
    local eras={};for gen=r.generation,7 do eras[gen]=true end
    local fields={id=id,name=tr(r.names.en,r.names.de),names=r.names,originGeneration=r.generation,
      price=10000,keyItem=false,tossable=true,field=false,battle=false,
      kascNoTake67=id=='ULTRANECROZIUM_Z'or nil,kascLateTransformationOwner67=M.OWNER,
      kascEquipmentRewardEpochs=eras}
    if prior then mod.content.items:patch(id,fields)else mod.content.items:register(id,fields)end
  end
  function M.eligibility(b,w)
    if not clean(b,w)then return nil,'unsupported_battle'end
    local source=opts.species.bySpecies[w.mon.species];local id=required[source]
    if not id then return nil,'ineligible'end
    local gen=M.epoch(b);local row=equipment[id]
    if gen<row.generation then return nil,'inactive_generation'end
    if record(b,w)then return nil,'already_transformed'end
    local held,err=opts.held(w.mon)
    -- Possession, not the passive effect: Primal/Ultra catalysts work under
    -- Klutz/Embargo/Magic Room just as the pinned canonical controllers do.
    if err or held~=id or not M.supportsItem(b.game,id,gen)then return nil,'equipment'end
    local _,side=slot(b,w);local s=state(b)
    if id=='ULTRANECROZIUM_Z'and s and s.usedUltra[side]then return nil,'ultra_used'end
    return{source=source,form=target[source],item=id,generation=gen,
      kind=id=='ULTRANECROZIUM_Z'and'ultra'or'primal'}
  end
  function M.abilityKey(b,w)
    local r=clean(b,w)and record(b,w)
    return r and equipment[r.item]and target[r.source]==r.form and M.epoch(b)>=equipment[r.item].generation
      and forms.currentKey(b,w)==r.form and r.form or nil
  end
  function M.changed(b,w)local r=record(b,w);return r and r.form or nil end
  local function remember(b,w)
    local list=rosters[b]or{};rosters[b]=list
    for _,old in ipairs(list)do if old==w then return end end;list[#list+1]=w
  end
  local function apply(b,w,r)
    remember(b,w)
    forms.detach(b,w);forms.change(b,w,r.form,r.epoch,true)
  end
  function M.activate(b,w)
    local plan,reason=M.eligibility(b,w);if not plan then return false,reason end
    local key,side=slot(b,w);local s=state(b,true)
    local r={species=w.mon.species,source=plan.source,form=plan.form,item=plan.item,
      epoch=plan.generation,turn=b.turnCount or 0}
    s.records[key]=r;if plan.kind=='ultra'then s.usedUltra[side]=true end
    apply(b,w,r)
    b:sayNext(plan.kind=='ultra'and tr('Ultra Burst!','Ultra-Explosion!')
      or tr('Primal Reversion!','Proto-Morphose!'));b:drainNext()
    return true
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local function start(w)
      if not clean(b,w)then return end
      local r=record(b,w)
      if r then apply(b,w,r);return end
      local plan=M.eligibility(b,w)
      if plan and plan.kind=='primal'then M.activate(b,w)end
    end
    if ev.battler then start(ev.battler)else start(b.player);start(b.enemy)end
  end
  function M.commandView(b,w)
    local plan,reason=M.eligibility(b,w)
    return{schema='kasc.battle-transformation-view/v1',owner=M.OWNER,kind='ultra',input='select',
      label=tr('ULTRA BURST','ULTRA-EXPLOSION'),available=plan~=nil and plan.kind=='ultra',
      reasonCode=reason or(plan and plan.kind~='ultra'and'automatic_primal'or false),
      transformed=M.changed(b,w)or false}
  end
  function M.nativeInput(b)
    if not b or b.phase~='menu'or b.demo or b.safari or b.result
        or b.queue and#b.queue>0 or b.draining or b.animPlaying or b.pendingHit
        or not M.commandView(b,b.player).available then return false end
    local input=b.game and b.game.input
    if input and input:wasPressed('select')then
      local ok=M.activate(b,b.player)
      if ok then b.phase='messages';b.afterQueue='menu';return true end
    end
    return false
  end
  function M.resume(b)
    -- Resume recorded forms, never auto-trigger a fresh form from metadata.
    if not M.epoch(b)then return end
    for _,w in ipairs({b.player,b.enemy})do if clean(b,w)then
      local r=record(b,w);if r then apply(b,w,r)end
    end end
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or type(s.records)~='table'or type(s.usedUltra)~='table'then return false,'invalid_late_transformation_container'end
    for k in pairs(s)do if k~='records'and k~='usedUltra'then return false,'unknown_late_transformation_container_field'end end
    local ultra={}
    for key,r in pairs(s.records)do
      local mon=monFor(b,key);local side=type(key)=='string'and key:match('^(%a+):')
      if type(r)~='table'or not mon or mon.species~=r.species or opts.species.bySpecies[r.species]~=r.source
          or target[r.source]~=r.form or required[r.source]~=r.item
          or type(r.epoch)~='number'or r.epoch%1~=0 or r.epoch<equipment[r.item].generation or r.epoch>7
          or type(r.turn)~='number'or r.turn%1~=0 or r.turn<0 or r.turn>(b.turnCount or 0)
          or not forms.validForm(r.species,r.form)then return false,'invalid_late_transformation_record'end
      for k in pairs(r)do if k~='species'and k~='source'and k~='form'and k~='item'and k~='epoch'and k~='turn'then return false,'unknown_late_transformation_record_field'end end
      if r.item=='ULTRANECROZIUM_Z'then
        if ultra[side]then return false,'duplicate_team_ultra_transformation'end;ultra[side]=true
      end
    end
    for side,v in pairs(s.usedUltra)do
      if(side~='player'and side~='enemy')or v~=true or not ultra[side]then return false,'invalid_team_ultra_usage'end
    end
    for side in pairs(ultra)do if not s.usedUltra[side]then return false,'missing_team_ultra_usage'end end
    return true
  end
  function M.clear(b)
    for _,w in ipairs(rosters[b]or{})do
      local r=record(b,w)
      if r and target[r.source]then forms.detach(b,w);forms.change(b,w,r.source,r.epoch,true);forms.detach(b,w)end
    end
    rosters[b]=nil;if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end
  function M.install()
    B._kascLateTransformations67=M
    -- Install once at registration and once after the existing Mega wrapper.
    -- Rewrapping only when another owned installer changed native update
    -- keeps SELECT available before Mega's ineligible-species message.
    if B.update~=B._kascLateTransformationsUpdate67 then
      local original=B.update
      local wrapped=function(b,dt)
        if B._kascLateTransformations67.nativeInput(b)then return end
        return original(b,dt)
      end
      B._kascLateTransformationsUpdate67=wrapped;B.update=wrapped
    end
  end
  mod.events:on('battle.started',M.entry,-10045)
  mod.events:on('battle.battler_switched',M.entry,-10045)
  mod.events:on('battle.ended',function(ev)if ev and ev.battle then M.clear(ev.battle)end end,20003)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascLateTransformations67=M.OWNER})
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='canonical-catalyst-and-native-temporary-form-owner',providerStatus='primal-vi-vii-ultra-vii',
    buildReceiptId='docs/LATE_TRANSFORMATIONS_67.md',rollbackReceiptId='docs/LATE_TRANSFORMATIONS_67.md'})end
  return M
end
