-- Shared one-turn shields and consecutive-use history. The history is a
-- native checkpoint token, never a saved Pokemon property or preview effect.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Status=require('src.battle.StatusRegistry');local A=opts.abilities
  local M={CARD_ID='KASC-67-PROTECTION',OWNER='kasc.protection/v1'}
  local guards={PROTECT=2,DETECT=2,ENDURE=2,KINGS_SHIELD=6,SPIKY_SHIELD=6,BANEFUL_BUNKER=7}
  local flags,aliases={},{}
  for id,row in pairs(opts.facts.data.moves)do
    local protected=false;for _,v in ipairs(row.flags or{})do if v=='protect'then protected=true end end
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id;flags[alias]=protected end
  end
  local function pack(...)return {n=select('#',...),...}end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=marker and marker.kascProtection67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and not b.demo and b.kind~='link'and gen and gen>=2 and gen<=7 then return gen end
  end
  function M.active(b,w)
    local r=rows(b);local key=b and w and side(b,w);local v=r and r[key]
    local gen=M.epoch(b)
    return gen and v and guards[v.move]and gen>=guards[v.move]
      and v.guardTurn==(b.turnCount or 0)and w.mon.hp>0 and v.move or nil
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.chance(b,w)
    local gen=M.epoch(b);if not gen then return 0,1 end
    local sideGuard=mod.exports.pokemonSideGuards67
    if sideGuard then local n,d=sideGuard.stallChance(b,w,gen);if n~=nil then return n,d end end
    local r=rows(b);local v=r and r[side(b,w)]
    local count=v and v.lastTurn==(b.turnCount or 0)-1 and v.count or 0
    if gen==2 then return math.floor(255/2^count),255 end
    return 1,gen<=4 and 2^math.min(3,count)or gen==5 and (count>=8 and 4294967296 or 2^count)
      or 3^math.min(6,count)
  end
  function M.noUseful(b,w,move)
    local id=move and(aliases[move.id]or move.id)
    if not guards[id]or not M.epoch(b)then return false end
    local n,d=M.chance(b,w)
    return n/d<1 or M.epoch(b)==2 and w.substituteHP~=nil
  end
  local function failure()return {opts.i18n.text('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b)
    local id=aliases[ctx.move.id]or ctx.move.id
    local sideGuard=mod.exports.pokemonSideGuards67
    local function failedCast()
      if sideGuard then sideGuard.noteFailure(ctx,gen)end
      M.clear(b,u);return failure()
    end
    if not gen or gen<(guards[id]or 99)or not side(b,u)or u.mon.hp<=0 or not t or t.mon.hp<=0
        or b._kascFlinchActed67 and b._kascFlinchActed67[t]
        or gen==2 and u.substituteHP~=nil then return failedCast()end
    local n,d=M.chance(b,u)
    local success=n>0 and (gen~=2 and d==1 or b.rng(1,d)<=n)
    if not success then return failedCast()end
    local r=rows(b,true);local key=side(b,u);local v=r[key];local turn=b.turnCount or 0
    local count=v and v.lastTurn==turn-1 and v.count or 0
    r[key]={move=id,guardTurn=turn,lastTurn=turn,count=math.min(8,count+1)}
    if sideGuard then sideGuard.noteProtection(ctx,gen)end
    if id=='ENDURE'then return {opts.i18n.text('Braced for impact!','Zum Durchhalten bereit!')}end
    return {opts.i18n.text('Protection ready!','Schutz aufgebaut!')}
  end
  function M.blocks(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move
    if not u or not t or u==t or not m then return false end
    local guard=M.active(b,t)
    if (aliases[m.id]or m.id)=='SPIDER_WEB'and M.epoch(b)==2 then return false end
    local protected=flags[m.id]
    -- Late Cards register literal move IDs after this owner's initial alias
    -- snapshot. Resolve only missing flags; an explicit canonical false stays
    -- false. This is read-only and cannot widen a known shield exception.
    if protected==nil then
      local row=opts.facts.data.moves[aliases[m.id]or m.id]
      local current=row and row.flags or m.flags or{}
      protected=current.protect==true
      for _,flag in ipairs(current)do if flag=='protect'then protected=true end end
    end
    if not guard or guard=='ENDURE' or not protected or guard=='KINGS_SHIELD'and m.category=='status'then return false end
    return guard
  end
  function M.notice(ctx,react)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local guard=M.blocks(ctx)
    if not guard then return end
    b:cancelMoveAnim();local text=opts.i18n.text('The attack was\nblocked!','Die Attacke wurde\nabgewehrt!')
    if react and u.mon.hp>0 and opts.contact.makesContact(m,M.epoch(b),b,u)then
      local sub=u.substituteHP;u.substituteHP=nil
      local ok,err=pcall(function()
      if guard=='SPIKY_SHIELD'and not A.blocksIndirect(b,u,'contact')then
        opts.contact.indirectDamage(b,u,math.max(1,math.floor(u.mon.stats.hp/8)))
        if u.mon.hp<=0 then b:onFaint(u)end
      elseif guard=='KINGS_SHIELD'then
        local c={battle=b,user=t,target=u,move=b.data.moves.KINGS_SHIELD,rng=b.rng,
          changeStage=function(w,s,d,f)return require('src.battle.MoveEffects').changeStage(b,w,s,d,f)end}
        for _,msg in ipairs(opts.split.changeStage(c,u,'attack',-2,true))do b:sayNext(msg)end
      elseif guard=='BANEFUL_BUNKER'then
        for _,msg in ipairs(Status.inflict(b,u,'PSN',{source='BANEFUL_BUNKER',kascStatusSource67=t}))do b:sayStatusMsg(u,msg)end
      end
      end)
      u.substituteHP=sub;if not ok then error(err,0)end
    end
    return text
  end
  function M.damage(original,b,ctx,record)
    if record and record.explode and opts.contact.damp(b)then return original(b,ctx,record)end
    if M.blocks(ctx)then
      b:sayNext(M.notice(ctx,true))
      if record and record.onMiss then record.onMiss(ctx,'protected')end
      return
    end
    local gen=M.epoch(b);local id=aliases[ctx.move.id]or ctx.move.id
    local breakers={FEINT=4,SHADOW_FORCE=4,PHANTOM_FORCE=6,HYPERSPACE_HOLE=6,HYPERSPACE_FURY=6}
    local breaks=gen and breakers[id]and gen>=breakers[id]
    local shield=M.active(b,ctx.target)
    if gen==4 and id=='FEINT'and (not shield or shield=='ENDURE')then b:cancelMoveAnim();b:sayNext(failure()[1]);return end
    if not breaks then return original(b,ctx,record)end
    local raw,old=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      if w==ctx.target and amount>0 then local r=rows(b);local v=r and r[side(b,w)]
        if v and v.move~='ENDURE'then v.guardTurn=nil end end
      return old(self,w,amount)
    end
    local result=pack(pcall(original,b,ctx,record));b.applyDamage=raw
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_protection_container'end
    for key,v in pairs(r)do
      if (key~='player'and key~='enemy')or type(v)~='table'or not guards[v.move]
          or type(v.lastTurn)~='number'or v.lastTurn%1~=0 or v.lastTurn<0 or v.lastTurn>(b.turnCount or 0)
          or type(v.count)~='number'or v.count%1~=0 or v.count<1 or v.count>8
          or v.guardTurn~=nil and v.guardTurn~=v.lastTurn then return false,'invalid_protection_timeline'end
      for k in pairs(v)do if k~='move'and k~='lastTurn'and k~='guardTurn'and k~='count'then return false,'unknown_protection_field'end end
    end
    return true
  end
  for id in pairs(guards)do
    local move=mod.content.moves:get(id)
    if move then assert(move.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign protection move '..id)end
    local effect='KA_PROTECTION_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',run=M.cast})
    if move then mod.content.moves:patch(id,{effect=effect})
    else
      local fact=assert(opts.facts.move(id,guards[id]));assert(fact.category=='status'and fact.target==7)
      mod.content.moves:register(id,{id=id,name=opts.i18n.text(fact.names.en,fact.names.de),
        type=fact.type,category='status',power=0,accuracy=100,pp=fact.pp,priority=fact.priority,
        originGeneration=guards[id],backendMoveOwner=M.OWNER,backendMoveNumber=fact.number,
        backendLearnsetRevision=1,effect=effect})
    end
    aliases[id]=id;flags[id]=false
    local anim=copy(assert(mod.content.battle_anims:get('BARRIER')))
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,anim)
    else mod.content.battle_anims:register(id,anim)end
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  -- Wrap existing primary/custom effect entry points after the other owners
  -- are installed. Called moves are judged on their own target/flags.
  local patched={}
  for id in pairs(aliases)do
    local move=mod.content.moves:get(id);local effect=move and move.effect
    local record=effect and mod.content.move_effects:get(effect)
    if record and not patched[effect]then
      patched[effect]=true
      if record.perform then local old=record.perform
        mod.content.move_effects:patch(effect,{perform=function(ctx)
          if M.blocks(ctx)then ctx.battle:sayNext(M.notice(ctx,true));return end
          return old(ctx)
        end})
      elseif record.kind=='primary'and record.run then local old=record.run
        mod.content.move_effects:patch(effect,{run=function(ctx)
          if M.blocks(ctx)then return {M.notice(ctx,true),failed=true}end
          return old(ctx)
        end})
      end
    end
  end
  FX._kascProtection67=M
  if not FX._kascProtectionWrapped67 then local old=FX.runDamaging
    FX.runDamaging=function(b,ctx,record)return FX._kascProtection67.damage(old,b,ctx,record)end
    FX._kascProtectionWrapped67=true
  end
  local activeBattle
  function M.scoped(old,b,...)
    local prior=activeBattle;activeBattle=b;local out=pack(pcall(old,b,...));activeBattle=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  B._kascProtection67=M
  if not B._kascProtectionWrapped67 then local old=B.resolveTurn
    B.resolveTurn=function(b,...)return B._kascProtection67.scoped(old,b,...)end
    B._kascProtectionWrapped67=true
  end
  mod.hooks:wrap('battle.turn_order',function(nextOrder,a,am,z,zm,ctx)
    local gen=M.epoch(activeBattle)
    local function project(move)
      if gen and move and guards[aliases[move.id]or move.id]then
        local r={};for k,v in pairs(move)do r[k]=v end;r.priority=gen==2 and 2 or gen<=4 and 3 or 4;return r
      end
      return move
    end
    return nextOrder(a,project(am),z,project(zm),ctx)
  end,30000)
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if not(ctx.opts and ctx.opts.typeless)and M.blocks(ctx)then return 0,{crit=false,typeMult=0}end
    return nextDamage(ctx)
  end,32000)
  mod.events:on('battle.move_used',function(ev)
    if not guards[aliases[ev.move.id]or ev.move.id]and not ev.isCalled then M.clear(ev.battle,ev.user)end
  end,5000)
  mod.events:on('battle.turn_ended',function(ev)
    local r=rows(ev.battle);for _,v in pairs(r or{})do v.guardTurn=nil end
  end,10000)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,90)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascProtection67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.1.0',owner=M.OWNER,active=true,dependencyStatus='native-target-flags-round-lifecycle',
      providerStatus='five-shields-endure-and-feint',buildReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
