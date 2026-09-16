-- Charge, Autotomize and Clear Smog own battle-local effects, not saved stats.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={OWNER='kasc.body-utilities/v1',CARD_ID='KASC-67-BODY-UTILITIES'}
  local tr=opts.i18n.text;local frames=setmetatable({},{__mode='k'})
  local moving=setmetatable({},{__mode='k'});local transfers=setmetatable({},{__mode='k'})
  local defs={CHARGE={number=268,birth=3,type='ELECTRIC',pp=20,parts={'FOCUS_ENERGY','THUNDERSHOCK'}},
    AUTOTOMIZE={number=475,birth=5,type='STEEL',pp=15,parts={'HARDEN','FOCUS_ENERGY','AGILITY'}},
    CLEAR_SMOG={number=499,birth=5,type='POISON',pp=15,parts={'ACID'}}}
  local aliases={};for id in pairs(defs)do for _,a in ipairs(opts.species.moveIds(id))do aliases[a]=id end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  -- The damage pipeline carries detached stat views. Resolve only its
  -- read-only receipt lookup, never a public cast or ownership mutation.
  local function damageUser(b,w)
    if side(b,w)then return w end
    if b and w and w.mon then for _,a in ipairs({b.player,b.enemy})do
      if a and a.mon==w.mon then return a end
    end end
  end
  local function index(b,w)local key=side(b,w);local party=key=='player'and b:playerPartyView()or key=='enemy'and b.enemyParty
    for i,p in ipairs(party or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.isEgg or p.is_egg or p.egg or p.eggSpecies or p.species=='EGG')end
  local function rows(b,create)if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{charge={},weight={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  local function seal(v)local r=copy(v);r.proof=nil;return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(r))end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or not int(r.activeEpoch,1,7)
      or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not marker or marker.kascBodyUtilities67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local id=aliases[move.id]or move.id;local d=defs[id];local rec=d and b:effectRecord(move.effect)
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
      or not rec or rec.kascBodyUtilities67~=M.OWNER then return end
    if r.activeEpoch<d.birth and not(live(u)and index(b,u)
      and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(r.activeEpoch,d.birth),id
  end
  local function valid(b,w,h)return M.epoch(b)and live(w)and type(h)=='table'and h.species==w.mon.species
    and h.party==index(b,w)and h.profile==M.epoch(b)and h.proof==seal(h)end
  local function token(b,w,kind)local r=rows(b);local h=r and r[kind]and r[kind][side(b,w)]
    return valid(b,w,h)and h or nil end
  local function put(b,w,kind,h)h.proof=seal(h);rows(b,true)[kind][side(b,w)]=h;return h end
  local function base(b,w,epoch)return{species=w.mon.species,party=index(b,w),profile=M.epoch(b),
    epoch=epoch,applied=b.turnCount or 0}end
  function M.charge(b,w)
    local h=token(b,w,'charge');if not h then return end
    local turn=b.turnCount or 0
    if turn<h.applied or h.epoch==3 and turn>h.expires then return end
    return h
  end
  function M.clearCharge(b,w)local r=rows(b);if r and side(b,w)then r.charge[side(b,w)]=nil end end
  function M.chargeMode(b,w,move)
    local h=M.charge(b,w)
    if h and move and move.type=='ELECTRIC'and move.category~='status'and(tonumber(move.power)or 0)>0 then
      return h.epoch<=3 and'damage'or'power'
    end
  end
  -- Returned raw hectograms MUST be before Heavy/Light Metal. Never divide a
  -- rounded Light Metal value to reconstruct provenance.
  local function rawWeight(b,w)
    local v=mod.exports and mod.exports.backendVariablePower67 or opts.variable
    if v and v.OWNER=='kasc.variable-power/v1'and v.rawWeight then return v.rawWeight(b,w)end
  end
  function M.adjustWeight(b,w,hg,key)
    if not int(hg,1,9999999)then return hg end
    local h=token(b,w,'weight');if not h then return hg end
    if h.epoch==5 then return math.max(1,hg-1000*h.layers)end
    if h.basis==key then return h.value end
    return hg
  end
  function M.weight(b,w)
    local hg,key=rawWeight(b,w);if hg then return M.adjustWeight(b,w,hg,key),key end
  end
  function M.formChanged(b,w)
    local h=token(b,w,'weight');if h and h.epoch>=6 then rows(b).weight[side(b,w)]=nil end
  end
  function M.transformed(b,w,target)
    local identity=mod.exports.pokemonBattleIdentity67
    if not M.epoch(b)or not live(w)or not live(target)or not index(b,w)or not identity
      or not identity.transformed(w)or identity.current(b,w)~=identity.current(b,target)then return false end
    local gen=M.epoch(b)
    -- V's noCopy modifier remains the transformer's own volatile. VI+
    -- copies the target's genuine raw weight, not its Metal modifier.
    if gen<=5 then return true end
    local raw,basis=rawWeight(b,w);local targetWeight=M.weight(b,target)
    if not raw or not basis or not targetWeight then return false end
    rows(b,true).weight[side(b,w)]=nil
    if targetWeight~=raw then local h=base(b,w,gen);h.basis=basis;h.value=targetWeight;h.base=raw
      put(b,w,'weight',h)end
    return true
  end
  local function stage(ctx,w,stat,amount)
    return assert(mod.exports.backendSplitSpecial67,'Body utilities need native stage owner').changeStage(ctx,w,stat,amount,false)
  end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function append(out,msgs)for _,m in ipairs(msgs or{})do out[#out+1]=m end end
  function M.noUseful(b,u,t,move)
    local gen,id=M.epoch(b,u,move);if not gen then return false end
    if not live(u)or not index(b,u)then return true end
    if id=='CLEAR_SMOG'then return not live(t)end
    if id=='AUTOTOMIZE'then local contrary=opts.abilities.activeAbility(b,u)=='CONTRARY'
      return contrary and(u.stages.speed or 0)<=-6 or not contrary and(u.stages.speed or 0)>=6 end
    if gen>=4 then local contrary=opts.abilities.activeAbility(b,u)=='CONTRARY';local spd=u.stages.specialDefense or 0
      if contrary and spd>-6 or not contrary and spd<6 then return false end end
    if M.charge(b,u)then return true end
    for _,slot in ipairs(u.curMoves or{})do local m=b.data.moves[slot.id]
      if m and m.type=='ELECTRIC'and m.category~='status'and(m.power or 0)>0 and(slot.pp or 0)>0 then return false end end
    return true
  end
  function M.cast(ctx)
    local b,w=ctx.battle,ctx.user;local gen,id=M.epoch(b,w,ctx.move)
    if not gen or not live(w)or not index(b,w)then return fail()end
    if id=='CHARGE'then
      local h=base(b,w,gen);if gen==3 then h.expires=h.applied+1 end;put(b,w,'charge',h)
      local out={tr('%s began charging power!','%s lädt elektrische Kraft!'):format(w.name)}
      if gen>=4 then append(out,stage(ctx,w,'specialDefense',1))end
      return out
    elseif id=='AUTOTOMIZE'then
      local contrary=opts.abilities.activeAbility(b,w)=='CONTRARY';local speed=w.stages.speed or 0
      if contrary and speed<=-6 or not contrary and speed>=6 then return fail()end
      local raw,basis=rawWeight(b,w);if not raw or not basis then return fail()end
      local out=stage(ctx,w,'speed',2);local previous=token(b,w,'weight')
      if gen==5 then
        local layers=previous and previous.epoch==5 and previous.layers or 0
        if raw-1000*layers>1 then local h=base(b,w,gen);h.layers=layers+1;put(b,w,'weight',h)
          out[#out+1]=tr('%s became nimble!','%s wird leichter!'):format(w.name)end
      else
        local current=M.adjustWeight(b,w,raw,basis)
        if current>1 then local h=base(b,w,gen);h.base=raw;h.basis=basis;h.value=math.max(1,current-1000)
          put(b,w,'weight',h);out[#out+1]=tr('%s became nimble!','%s wird leichter!'):format(w.name)end
      end
      return out
    end
    return fail()
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    local mode=M.chargeMode(ctx.battle,damageUser(ctx.battle,ctx.user),ctx.move);if not mode then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.opts=copy(ctx.opts or{})
    out.opts.kascChargeMode67=mode;out.opts.kascCharge67=M.OWNER
    return nextDamage(out)
  end
  function M.perform(original,b,w,target,slot,called,...)
    local prior=moving[b];moving[b]=true;local h=M.charge(b,w);local move=slot and b:moveDef(slot)
    local out=pack(pcall(original,b,w,target,slot,called,...));moving[b]=prior
    if not out[1]then error(out[2],0)end
    if h and move and(aliases[move.id]or move.id)~='CHARGE'and M.charge(b,w)==h then M.clearCharge(b,w)end
    local r=rows(b);local weight=r and r.weight[side(b,w)]
    if weight and weight.epoch>=6 then local _,key=rawWeight(b,w)
      if weight.basis~=key then r.weight[side(b,w)]=nil end end
    return unpack(out,2,out.n)
  end
  function M.action(original,b,w,target,action,...)
    local h=M.charge(b,w);local move=action and action.id and b.data.moves[action.id]
    local out=pack(pcall(original,b,w,target,action,...));if not out[1]then error(out[2],0)end
    -- Gen-IV-VII onMoveAborted also spends the volatile. Gen-III's real
    -- two-round charge timer still expires after a sleeping/bound turn.
    if h and h.epoch>=4 and move and(aliases[move.id]or move.id)~='CHARGE'
      and M.charge(b,w)==h then M.clearCharge(b,w)end
    return unpack(out,2,out.n)
  end
  function M.hit(ev)
    local b=ev and ev.battle;local f=b and frames[b];local h=f and f.hit
    if not h or not M.epoch(b,ev.user,ev.move)or h.move~=ev.move or h.user~=ev.user
      or h.target~=ev.target or h.damage~=ev.damage or not h.direct or h.substitute or h.consumed then return end
    h.consumed=true;f.body=live(ev.target)and h or nil
  end
  function M.afterDamage(ctx)
    local f=frames[ctx.battle];local h=f and f.body
    if not h or h.target~=ctx.target or h.user~=ctx.user or not live(ctx.target)
      or not M.epoch(ctx.battle,ctx.user,ctx.move)then return end
    f.body=nil;local stages=ctx.target.stages or{};ctx.target.stages=stages
    for _,k in ipairs({'attack','defense','speed','special','specialAttack','specialDefense','accuracy','evasion'})do stages[k]=0 end
    ctx.target.hazeStatReset=nil
    ctx.battle:sayNext(tr('%s\'s stat changes were removed!','%s\' Statusänderungen wurden aufgehoben!'):format(ctx.target.name))
  end
  function M.run(original,b,ctx,rec,...)
    if not ctx or(aliases[ctx.move.id]or ctx.move.id)~='CLEAR_SMOG'or not M.epoch(b,ctx.user,ctx.move)then
      return original(b,ctx,rec,...)
    end
    local previousFrame=frames[b];local f={};frames[b]=f
    local raw,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports.pokemonLethalHitSurvival67
      local attempted=survival and survival.incomingHit and survival.incomingHit(self,w)or amount
      local direct=w==ctx.target and live(w)and tonumber(attempted)and attempted>0
      local substitute=direct and w.substituteHP~=nil
      local damage=previous(self,w,amount)
      f.hit={user=ctx.user,target=w,move=ctx.move,damage=damage,direct=direct,substitute=substitute}
      return damage
    end
    local out=pack(pcall(original,b,ctx,rec,...));b.applyDamage=raw;frames[b]=previousFrame
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.clear(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end
    if ev.battler then local key=side(b,ev.battler);if key then r.charge[key]=nil;r.weight[key]=nil end
    else b.field.tokens[M.OWNER]=nil;frames[b]=nil;moving[b]=nil;transfers[b]=nil end
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end
    for _,key in ipairs({'player','enemy'})do local h=r.charge[key]
      if h and(not live(b[key])or h.epoch==3 and(b.turnCount or 0)>=h.expires)then r.charge[key]=nil end
      if not live(b[key])then r.weight[key]=nil end
    end
  end
  -- Baton Pass copies Charge, never Autotomize's noCopy/raw-weight state.
  -- prepare() runs after replacement but before switched clears the token.
  function M.prepareTransfer(b,old,new)
    local r=rows(b);local key=side(b,new);local h=r and key and r.charge[key]
    if not M.epoch(b)or not h or not live(new)or h.species~=old.mon.species or h.proof~=seal(h)then return end
    local fresh=copy(h);fresh.species=new.mon.species;fresh.party=index(b,new);fresh.proof=seal(fresh)
    transfers[b]={previous=old,battler=new,key=key,charge=fresh}
  end
  function M.restoreTransfer(ev)
    local b=ev and ev.battle;local h=b and transfers[b]
    if h and ev.sourceCard=='KASC-67-BATON-PASS'and ev.previous==h.previous and ev.battler==h.battler
      and b[h.key]==h.battler then rows(b,true).charge[h.key]=h.charge;transfers[b]=nil end
  end
  function M.validateCheckpoint(b)
    if frames[b]or moving[b]or transfers[b]then return false,'body_utilities_unsettled'end
    local r=rows(b);if r==nil then return true end
    if not M.epoch(b)or type(r)~='table'or type(r.charge)~='table'or type(r.weight)~='table'then return false,'invalid_body_utilities_container'end
    for k in pairs(r)do if k~='charge'and k~='weight'then return false,'unknown_body_utilities_container_field'end end
    for _,kind in ipairs({'charge','weight'})do for key,h in pairs(r[kind])do local w=(key=='player'or key=='enemy')and b[key]
      if not w or not valid(b,w,h)or not int(h.applied,0,b.turnCount or 0)or not int(h.epoch,kind=='charge'and 3 or 5,7)
        or h.epoch~=math.max(h.profile,kind=='charge'and 3 or 5)then return false,'invalid_body_utilities_identity'end
      local fields={species=true,party=true,profile=true,epoch=true,applied=true,proof=true}
      if kind=='charge'then
        if h.epoch==3 then fields.expires=true;if h.expires~=h.applied+1 or(b.turnCount or 0)>h.expires then return false,'invalid_charge_timeline'end end
      elseif h.epoch==5 then fields.layers=true
        if not int(h.layers,1,10000)then return false,'invalid_autotomize_layers'end
      else fields.value=true;fields.base=true;fields.basis=true
        local raw,basis=rawWeight(b,w)
        if not int(h.value,1,9999999)or not int(h.base,1,9999999)or h.value>h.base
          or h.base~=raw or h.basis~=basis then return false,'invalid_autotomize_raw_weight'end
      end
      for k in pairs(h)do if not fields[k]then return false,'unknown_body_utilities_record_field'end end
    end end;return true
  end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,d.birth));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.birth and f.type==d.type and f.pp==d.pp and f.priority==0
      and f.alwaysHits and f.target==(id=='CLEAR_SMOG'and 10 or 7)
      and f.category==(id=='CLEAR_SMOG'and'special'or'status')and f.power==(id=='CLEAR_SMOG'and 50 or 0),
      'Body utilities source drift '..id)
    assert(not old.backendMoveOwner and old.effect==(id=='CLEAR_SMOG'and'NO_ADDITIONAL_EFFECT'or'KA_GEN_MOVE_STAT_'..id),
      'foreign Body utilities owner '..id)
    local effect='KA_BODY_UTILITIES_67_'..id
    mod.content.move_effects:register(effect,{kind=id=='CLEAR_SMOG'and'full'or'primary',accuracyChecked=false,
      kascBodyUtilities67=M.OWNER,run=id~='CLEAR_SMOG'and M.cast or nil,
      afterDamage=id=='CLEAR_SMOG'and M.afterDamage or nil})
    for _,a in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(a)then
      mod.content.moves:patch(a,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,originGeneration=d.birth,
        power=id=='CLEAR_SMOG'and 50 or 0,category=f.category,target=f.target,contact=false,
        anim=copy(assert(mod.content.moves:get(d.parts[1])).anim)})end end
    local animation={seq={},source=M.OWNER}
    for _,part in ipairs(d.parts)do
      local source=mod.content.battle_anims:get(part)
      if not source then for _,alias in ipairs(opts.species.moveIds(part))do
        source=mod.content.battle_anims:get(alias);if source then break end
      end end
      assert(source,'missing native Body utilities animation '..part)
      for _,step in ipairs(source.seq)do animation.seq[#animation.seq+1]=copy(step)end
    end
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,animation)else mod.content.battle_anims:register(id,animation)end
    if opts.catalog then for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascBodyUtilities67=M.OWNER})
  function M.position(player,id)
    local r=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not r or r.source~=M.OWNER then return end
    local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
    for _,step in ipairs(player.steps or{})do local sprites={};local shift=-16
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s);if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        local x,y=q.x-8,q.y-16;for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end;sprites[i]=q end
      step.sprites=sprites
    end
  end
  function M.install()
    B._kascBodyUtilities67=M;FX._kascBodyUtilities67=M;Player._kascBodyUtilities67=M
    if not B._kascBodyUtilitiesWrapped67 then local perform,action=B.performMove,B.executeAction
      B.performMove=function(...)return B._kascBodyUtilities67.perform(perform,...)end
      B.executeAction=function(...)return B._kascBodyUtilities67.action(action,...)end;B._kascBodyUtilitiesWrapped67=true end
    if not FX._kascBodyUtilitiesWrapped67 then local run=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascBodyUtilities67.run(run,...)end;FX._kascBodyUtilitiesWrapped67=true end
    if not Player._kascBodyUtilitiesWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascBodyUtilities67.position(self,id);return unpack(out,1,out.n)end
      Player._kascBodyUtilitiesWrapped67=true end
  end
  M.install();mod.hooks:wrap('battle.damage',M.damage,-7100)
  -- Native Gen-I bypasses the modern damage owner. Authenticate only a real
  -- Charge receipt, then use unchanged native epoch math with its own flag.
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if ctx.opts and ctx.opts.kascCharge67==M.OWNER and ctx.opts.kascChargeMode67=='damage'
      and M.epoch(ctx.battle)==1 and M.chargeMode(ctx.battle,damageUser(ctx.battle,ctx.user),ctx.move)=='damage'then
      return assert(opts.damage,'Charge needs native math seam').compute(ctx.ruleset,ctx.user,ctx.target,ctx.move,ctx.opts)
    end;return nextDamage(ctx)
  end,-9505)
  mod.events:on('battle.damage_dealt',M.hit,9900)
  mod.events:on('battle.turn_ended',M.endTurn,94)
  mod.events:on('battle.battler_switched',M.clear,8000)
  mod.events:on('battle.battler_switched',M.restoreTransfer,7998)
  mod.events:on('battle.fainted',function(ev)if ev and ev.battle and ev.battler then M.clear(ev)end end,8000)
  mod.events:on('battle.ended',M.clear,94)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-charge-math-raw-weight-stages-and-body-event',providerStatus='three-era-correct-body-utilities',
    buildReceiptId='docs/BODY_UTILITIES_67.md',rollbackReceiptId='docs/BODY_UTILITIES_67.md'})end
  return M
end
