-- Ability replacement/suppression is a volatile, not a new saved ability slot.
-- Existing Trace/Receiver/Mummy and Transform retain their own provenance.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-ABILITY-CONTROL',OWNER='kasc.ability-control/v1'}
  local A=assert(opts.abilities);local tr=opts.i18n.text
  local defs={ROLE_PLAY={number=272,gen=3,pp=10,type='PSYCHIC_TYPE',always=true,sub=true,anim='FOCUS_ENERGY'},
    SKILL_SWAP={number=285,gen=3,pp=10,type='PSYCHIC_TYPE',always=true,sub=true,anim='PSYBEAM'},
    GASTRO_ACID={number=380,gen=4,pp=10,type='POISON',anim='ACID'},
    WORRY_SEED={number=388,gen=4,pp=10,type='GRASS',anim='LEECH_SEED'},
    SIMPLE_BEAM={number=493,gen=5,pp=15,type='NORMAL',anim='PSYBEAM'},
    ENTRAINMENT={number=494,gen=5,pp=15,type='NORMAL',anim='FOCUS_ENERGY'}}
  local aliases,known={},{}
  local changes=setmetatable({},{__mode='k'});local transfers=setmetatable({},{__mode='k'})
  local departed=setmetatable({},{__mode='k'})
  for _,r in pairs(opts.facts.data.abilities)do if r.generation<=7 then known[r.id]=true end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function name(move)return move and(aliases[move.id]or move.id)end
  local function lane(b,w)
    return b and w and w.mon and(b.player and w.mon==b.player.mon and'player'
      or b.enemy and w.mon==b.enemy.mon and'enemy')or nil
  end
  local function party(b,key)return key=='player'and b.game.save.party
    or key=='enemy'and(b.enemyParty or{b.enemy.mon})or{}end
  local function index(b,w)
    local key=lane(b,w);for i,mon in ipairs(party(b,key))do if mon==w.mon then return i end end
  end
  local function live(w)
    local m=w and w.mon;return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
      and not(m.isEgg or m.is_egg or m.egg or m.eggSpecies or m.status=='EGG')
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or type(r)~='table'or r.mode=='off'
        or type(r.activeEpoch)~='number'or r.activeEpoch%1~=0 or r.activeEpoch<1 or r.activeEpoch>7
        or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
        or not marker or marker.kascAbilityControl67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local d=defs[name(move)];local effect=b.data.move_effects[move.effect]
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
        or not effect or effect.kascAbilityControl67~=M.OWNER then return end
    if r.activeEpoch<d.gen and not(live(u)and opts.rules.monMoveAvailable
        and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(d.gen,r.activeEpoch)
  end
  -- Exact <=VII flags; later-generation protected abilities are not imported.
  local permanent={MULTITYPE=true,STANCE_CHANGE=true,BATTLE_BOND=true,COMATOSE=true,
    DISGUISE=true,POWER_CONSTRUCT=true,RKS_SYSTEM=true,SCHOOLING=true,SHIELDS_DOWN=true}
  function M.protected(id,gen,flag)
    if permanent[id]then return true end
    if id=='ZEN_MODE'then return flag~='cantsuppress'and flag~='failskillswap'or gen>=7 end
    if flag=='cantsuppress'then return false end
    if flag=='failskillswap'then return id=='WONDER_GUARD'or id=='ILLUSION'end
    if id=='WONDER_GUARD'or id=='ILLUSION'or id=='IMPOSTER'
        or id=='RECEIVER'or id=='POWER_OF_ALCHEMY'then return true end
    if id=='FORECAST'or id=='TRACE'then return gen>=5 end
    if id=='FLOWER_GIFT'then return gen>=5 end
    return false
  end
  local function allowed(old,id,donor,move,gen)
    -- Fixed replacements do not copy the source ability. A legitimate
    -- future-gift user can have no active historical slot (Audino III/IV),
    -- but still give a real target SIMPLE/INSOMNIA. Only those two moves
    -- accept the explicitly observed false donor in their strict receipt.
    local fixed=move=='WORRY_SEED'or move=='SIMPLE_BEAM'
    if not known[old]or not known[id]or not(known[donor]or fixed and donor==false)then return false end
    if move=='SKILL_SWAP'then return id==donor and not M.protected(old,gen,'failskillswap')
      and not M.protected(id,gen,'failskillswap')and(gen>=6 or old~=id)end
    if M.protected(old,gen,'cantsuppress')or M.protected(id,gen,'cantsuppress')then return false end
    if move=='ROLE_PLAY'then return old~=id and id==donor and not M.protected(donor,gen,'failroleplay')end
    if move=='WORRY_SEED'then return id=='INSOMNIA'and old~='INSOMNIA'and old~='TRUANT'end
    if move=='SIMPLE_BEAM'then return id=='SIMPLE'and old~='SIMPLE'and old~='TRUANT'end
    if move=='ENTRAINMENT'then return id==donor and old~=id and old~='TRUANT'
      and not M.protected(donor,gen,'noentrain')end
    return false
  end
  local function row(b,w)
    local gen=M.epoch(b);if not gen or gen<3 or not w or not w.mon then return end
    local key=lane(b,w);local list=state(b);local r=key and list and list[key]
    if r and(r.species~=w.mon.species or r.index~=index(b,w))then return end
    if not key then local out=departed[w.mon];r=out and out.battle==b and out.row end
    return r
  end
  -- Called by the canonical ability view AFTER Transform, BEFORE the older
  -- Trace/Receiver/Mummy overrides. Transform's real success clears control.
  function M.project(b,w)
    local r=row(b,w);local c=r and r.control
    if c and known[c.id]then return c.id,true end
    return nil,false
  end
  function M.suppressed(b,w,id)
    local r=row(b,w);local acid=r and r.acid
    return acid~=nil and not M.protected(id,math.max(M.epoch(b),acid.epoch),'cantsuppress')or false
  end
  -- An immutable-query proof of this owner's synchronous real change. It
  -- cannot be fabricated by setting a public battler/mon property.
  function M.pendingChange(b,w)
    local c=changes[b]
    if c and c.who==w and b[lane(b,w)]==w then return c.noStart,c.keepOverride,true end
    return false,false,false
  end
  local function prepare(b,w)
    assert(A.kascAbilityControl67==M.OWNER and type(A.prepareAbilityControl67)=='function',
      'ability control requires authenticated override preparation API')
    local previous=changes[b];changes[b]={who=w,noStart=true,keepOverride=false}
    local out=pack(pcall(A.prepareAbilityControl67,b,w));changes[b]=previous
    if not out[1]then error(out[2],0)end
  end
  local function changed(b,w,noStart,keepOverride)
    assert(A.kascAbilityControl67==M.OWNER,'ability control requires canonical projection/change API')
    local previous=changes[b];changes[b]={who=w,noStart=noStart,keepOverride=keepOverride}
    local asleep=w.mon.status=='SLP'
    local out=pack(pcall(A.transformedAbilityChanged,b,w,keepOverride))
    changes[b]=previous
    if not out[1]then error(out[2],0)end
    if asleep and w.mon.status~='SLP'then
      local sleep=assert(mod.exports.pokemonStatusLifecycle67,'ability cure needs native sleep lifecycle')
      sleep.clear(w,b)
    end
  end
  local function ensure(b,w)
    local key=lane(b,w);local list=state(b,true);local r=list[key]
    if not r or r.species~=w.mon.species or r.index~=index(b,w)then
      r={species=w.mon.species,index=assert(index(b,w),'ability control requires native party identity')};list[key]=r
    end
    return r
  end
  local function replace(b,w,id,old,donor,move,gen)
    ensure(b,w).control={id=id,old=old,donor=donor,move=move,epoch=gen,turn=b.turnCount or 0}
  end
  local function blocked(b,u,t,move)
    local d=defs[name(move)]
    if not live(u)or not live(t)or not lane(b,u)or not lane(b,t)or u.mon==t.mon or t.invulnerable
        or not d or not d.sub and t.substituteHP then return true end
    local ctx={battle=b,user=u,target=t,move=move}
    return mod.exports.pokemonProtection67.blocks(ctx)or mod.exports.pokemonPriorityAbilities67.blocks(ctx)
  end
  local function identities(b,u,t)return A.abilityIdentity(b,u),A.abilityIdentity(b,t)end
  local function canCast(b,u,t,move)
    local gen=M.epoch(b,u,move)
    if not gen or M.epoch(b)<3 or blocked(b,u,t,move)or not index(b,u)or not index(b,t)then return false end
    local us,ts=identities(b,u,t);local id=name(move)
    if id=='GASTRO_ACID'then local r=row(b,t)
      return known[ts]and not M.protected(ts,gen,'cantsuppress')and not(r and r.acid)
    end
    if id=='ROLE_PLAY'then return allowed(us,ts,ts,id,gen)end
    if id=='SKILL_SWAP'then return allowed(us,ts,ts,id,gen)and allowed(ts,us,us,id,gen)end
    return allowed(ts,id=='WORRY_SEED'and'INSOMNIA'or id=='SIMPLE_BEAM'and'SIMPLE'or us,us,id,gen)
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,u,move)then return false end
    return A.moveScope(b,u,t,true,function()
      if not canCast(b,u,t,move)then return true end
      local absorption=mod.exports.pokemonTypeAbsorption67
      if absorption and absorption.canAbsorb(b,u,t,move)then return true end
      -- VI+ same-ability Skill Swap succeeds, but repeating it is not useful AI.
      if name(move)=='SKILL_SWAP'then local us,ts=identities(b,u,t);return us==ts end
      return false
    end,move)
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen=M.epoch(b,u,move)
    if not gen or b[lane(b,u)]~=u or b[lane(b,t)]~=t or not canCast(b,u,t,move)then return failed()end
    local us,ts=identities(b,u,t);local id=name(move)
    if id=='GASTRO_ACID'then
      ensure(b,t).acid={ability=ts,epoch=gen,turn=b.turnCount or 0}
      changed(b,t,true,true)
      return{tr('%s\'s Ability was suppressed!','Die Fähigkeit von %s wird unterdrückt!'):format(t.name)}
    elseif id=='ROLE_PLAY'then
      replace(b,u,ts,us,ts,id,gen);prepare(b,u);changed(b,u,gen<=3,false)
      return{tr('%s copied the Ability!','%s kopiert die Fähigkeit!'):format(u.name)}
    elseif id=='SKILL_SWAP'then
      -- Commit both identities before either Start callback runs. A swapped
      -- Intimidate/Trace/entry weather sees the genuine other new identity.
      replace(b,u,ts,us,ts,id,gen);replace(b,t,us,ts,us,id,gen)
      prepare(b,u);prepare(b,t)
      changed(b,t,gen<=3,false);changed(b,u,gen<=3,false)
      return{tr('The Abilities were swapped!','Die Fähigkeiten wurden getauscht!')}
    else
      local nextId=id=='WORRY_SEED'and'INSOMNIA'or id=='SIMPLE_BEAM'and'SIMPLE'or us
      replace(b,t,nextId,ts,us,id,gen);prepare(b,t);changed(b,t,gen<=3,false)
      -- Worry Seed explicitly wakes a sleeping target even under Gastro Acid.
      if id=='WORRY_SEED'and t.mon.status=='SLP'then t.mon.status=nil
        mod.exports.pokemonStatusLifecycle67.clear(t,b)
      end
      return{tr('%s\'s Ability changed!','Die Fähigkeit von %s hat sich geändert!'):format(t.name)}
    end
  end
  function M.perform(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    local gen=M.epoch(b,u,ctx.move);local d=defs[name(ctx.move)]
    if not gen or M.epoch(b)<3 or not live(u)or not live(t)or b[lane(b,u)]~=u or b[lane(b,t)]~=t then
      b:cancelMoveAnim();b:sayNext(failed()[1]);return
    end
    local function accuracy()
      if t.invulnerable or not d.always and not b:accuracyRoll(ctx.move,u,t)then b:cancelMoveAnim()
        b:sayNext(b:romText('_AttackMissedText','%s\'s\nattack missed!',u.name));return false end
      return true
    end
    local function immune()
      if name(ctx.move)~='WORRY_SEED'then return false end
      local id=A.abilityIdentity(b,t)
      if id=='INSOMNIA'or id=='TRUANT'then b:cancelMoveAnim();b:sayNext(failed()[1]);return true end
      return false
    end
    -- Pinned battle-actions hit steps: semi-invulnerability is first. IV
    -- alone orders accuracy -> move TryImmunity -> global TryHit. III/V+
    -- order global TryHit -> move TryImmunity -> accuracy. Substitute is a
    -- later TryPrimaryHit and must remain AFTER the legitimate accuracy roll.
    if t.invulnerable then accuracy();return end
    if gen==4 and(not accuracy()or immune())then return end
    if mod.exports.pokemonProtection67.blocks(ctx)or mod.exports.pokemonPriorityAbilities67.blocks(ctx)then
      b:cancelMoveAnim();b:sayNext(failed()[1]);return
    end
    if name(ctx.move)=='WORRY_SEED'then
      local absorption=mod.exports.pokemonTypeAbsorption67
      if absorption and absorption.absorb(b,ctx)then return end
    end
    if gen~=4 and(immune()or not accuracy())then return end
    local result=M.cast(ctx);if result.failed then b:cancelMoveAnim()end
    for _,text in ipairs(result)do b:sayNext(text)end;b:drainNext()
  end
  M.worry=M.perform
  function M.transformed(b,w)
    local key=lane(b,w);if not key or b[key]~=w then return end
    local r=row(b,w);if r then r.control=nil;if not r.acid then state(b)[key]=nil end end
  end
  function M.transfer(b,old,fresh)
    local key=lane(b,fresh);local list=state(b);local r=key and list and list[key]
    if not M.epoch(b)or not key or b[key]~=fresh or not old or not old.mon or not live(fresh)
        or old.isPlayer~=fresh.isPlayer or old.mon==fresh.mon or not r or r.species~=old.mon.species
        or party(b,key)[r.index]~=old.mon then return false end
    departed[old.mon]={battle=b,row=copy(r)}
    transfers[b]={old=old,fresh=fresh}
    -- Gastro Acid's volatile passes. An acquired/swapped ability never does.
    list[key]=r.acid and{species=fresh.mon.species,index=assert(index(b,fresh)),acid=copy(r.acid)}or nil
    return r.acid~=nil
  end
  function M.switch(ev)
    local b,w,old=ev and ev.battle,ev and ev.battler,ev and ev.previous
    local key=lane(b,w);if not key or b[key]~=w or not old or not old.mon or old.mon==w.mon
        or old.isPlayer~=w.isPlayer or old==b.player or old==b.enemy then return end
    local list=state(b);local r=list and list[key];local pass=transfers[b]
    if pass and pass.old==old and pass.fresh==w and ev.sourceCard=='KASC-67-BATON-PASS'then
      transfers[b]=nil;return
    end
    if r and r.species==old.mon.species then departed[old.mon]={battle=b,row=copy(r)}end
    if list then list[key]=nil end;transfers[b]=nil
  end
  function M.copyCleanup(ev)
    local b,w=ev and ev.battle,ev and ev.battler
    if not M.epoch(b)or ev.sourceCard~='KASC-67-BATON-PASS'or not w or b[lane(b,w)]~=w then return end
    local r=row(b,w);if r and r.acid and M.protected(A.abilityIdentity(b,w),math.max(M.epoch(b),r.acid.epoch),'cantsuppress')then
      r.acid=nil;if not r.control then state(b)[lane(b,w)]=nil end
    end
  end
  function M.validateCheckpoint(b)
    if changes[b]or transfers[b]then return false,'unsettled_ability_control'end
    local list=state(b);if list==nil then return true end
    if type(list)~='table'then return false,'invalid_ability_control_container'end
    local profile=M.epoch(b)
    if not profile or profile<3 then return false,'inactive_ability_control_profile'end
    local function turn(n)return type(n)=='number'and n%1==0 and n>=0 and n<=(b.turnCount or 0)end
    local function epoch(n)return type(n)=='number'and n%1==0 and n>=3 and n<=7 end
    for key,r in pairs(list)do local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(r)~='table'or r.species~=w.mon.species or r.index~=index(b,w)
          or not(r.control or r.acid)then return false,'invalid_ability_control_identity'end
      for k in pairs(r)do if k~='species'and k~='index'and k~='control'and k~='acid'then return false,'unknown_ability_control_field'end end
      local c=r.control
      if c~=nil then
        if type(c)~='table'or not defs[c.move]or c.move=='GASTRO_ACID'or not turn(c.turn)
            or not epoch(c.epoch)or c.epoch~=math.max(defs[c.move].gen,profile)
            or not allowed(c.old,c.id,c.donor,c.move,c.epoch)then return false,'invalid_ability_control_replacement'end
        for k in pairs(c)do if not({id=true,old=true,donor=true,move=true,epoch=true,turn=true})[k]then return false,'unknown_ability_replacement_field'end end
      end
      local acid=r.acid
      if acid~=nil then
        if type(acid)~='table'or not known[acid.ability]or not epoch(acid.epoch)or acid.epoch~=math.max(4,profile)
            or not turn(acid.turn)or M.protected(acid.ability,acid.epoch,'cantsuppress')then return false,'invalid_gastro_acid_state'end
        for k in pairs(acid)do if k~='ability'and k~='epoch'and k~='turn'then return false,'unknown_gastro_acid_field'end end
      end
    end
    return true
  end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,d.gen));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.gen and f.type==d.type and f.category=='status'
      and f.power==0 and f.pp==d.pp and f.accuracy==100 and f.alwaysHits==(d.always==true)
      and f.priority==0 and f.target==10,'ability control source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign ability control owner '..id)
    local effect='KA_ABILITY_CONTROL_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=not d.always,kascAbilityControl67=M.OWNER,
      run=M.cast,perform=M.perform})
    for _,alias in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(alias)then aliases[alias]=id
      mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,originGeneration=d.gen,
        power=0,pp=d.pp,category='status',kascBypassSub67=d.sub==true})
    end end;aliases[id]=id
    local anim=copy(assert(mod.content.battle_anims:get(d.anim)));anim.source=M.OWNER
    mod.content.battle_anims:patch(id,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  function M.position(player,id)
    local anim=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not anim or anim.source~=M.OWNER then return end
    local hud=assert(mod.exports.pokemonPartnerHits67,'ability control needs actual HUD owner')
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or hud.inHud(q))then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    Player._kascAbilityControl67=M
    if not Player._kascAbilityControlWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascAbilityControl67.position(self,id);return unpack(out,1,out.n)end
      Player._kascAbilityControlWrapped67=true
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascAbilityControl67=M.OWNER})
  mod.events:on('battle.battler_switched',M.switch,50010)
  mod.events:on('battle.battler_switched',M.copyCleanup,6500)
  mod.events:on('battle.ended',function(ev)changes[ev.battle]=nil;transfers[ev.battle]=nil
    if state(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end,10100)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='canonical-ability-view-change-and-native-identity-provenance',
    providerStatus='temporary-replacement-swap-and-passable-gastro-acid',buildReceiptId='docs/ABILITY_CONTROL_67.md',
    rollbackReceiptId='docs/ABILITY_CONTROL_67.md'})end
  return M
end
