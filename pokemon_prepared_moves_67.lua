-- Beak Blast and Shell Trap prepare before either selected action executes.
-- Real damaging-hit receipts decide retaliation/activation; previews do not.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Status=require('src.battle.StatusRegistry')
  local M={CARD_ID='KASC-67-PREPARED-MOVES',OWNER='kasc.prepared-moves/v1'}
  local defs={BEAK_BLAST={number=690,type='FLYING',category='physical',power=100,pp=15,target=10,revision=31,parts={'EMBER','PECK'}},
    SHELL_TRAP={number=704,type='FIRE',category='special',power=150,pp=5,target=11,revision=32,parts={'HARDEN','EXPLOSION'}}}
  local frames=setmetatable({},{__mode='k'});local resolving=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.KA_PREPARED_67_BEAK_BLAST
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch%1==0 and r.activeEpoch>=1 and r.activeEpoch<=7
        and marker and marker.kascPreparedMoves67==M.OWNER then return r.activeEpoch end
  end
  function M.active(b,move)
    return M.epoch(b)and move and defs[move.id]and move.backendMoveOwner==M.OWNER or false
  end
  function M.category(b,move)
    if M.epoch(b)<=3 then return require('src.battle.TypeChart').category(move.type)end
    return move.category or require('src.battle.TypeChart').category(move.type)
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local k=side(b,w);if k then r[k]=nil end else b.field.tokens[M.OWNER]=nil end
  end
  function M.prepared(b,w)
    local r=rows(b);local k=side(b,w);local v=r and k and r[k]
    return M.epoch(b)and v and v.turn==(b.turnCount or 0)and v or nil
  end
  function M.arm(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    M.clear(b)
    for _,key in ipairs({'player','enemy'})do
      local w=b[key];local action=ev[key..'Action'];local move=action and b.data.moves[action.id]
      if w and w.mon and w.mon.hp>0 and action and not action.special and M.active(b,move)then
        rows(b,true)[key]={turn=b.turnCount or 0,move=move.id,gotHit=false}
        b:say(opts.i18n.text(move.id=='BEAK_BLAST'and'%s heated its beak!'or'%s set a shell trap!',
          move.id=='BEAK_BLAST'and'%s heizt seinen Schnabel auf!'or'%s legt eine Panzerfalle!'):format(w.name))
      end
    end
  end
  function M.hit(ev)
    local b=ev and ev.battle;local frame=b and frames[b]
    local hit=frame and frame.hit;local v=ev and M.prepared(b,ev.target)
    if not v or resolving[ev.target]or not hit or hit.consumed or hit.user~=ev.user or hit.target~=ev.target
        or hit.move~=ev.move or hit.damage~=ev.damage or hit.substitute or not hit.direct then return end
    hit.consumed=true
    if v.move=='SHELL_TRAP'then
      -- onHit qualifies even when Endure at 1 HP prevents actual HP loss.
      -- The positive attempted direct strike, not lost HP, proves the hit.
      if ev.user~=ev.target and M.category(b,ev.move)=='physical'then v.gotHit=true end
    elseif v.move=='BEAK_BLAST'and ev.user~=ev.target and ev.user.mon.hp>0
        and mod.exports.pokemonContactAbilities67.makesContact(ev.move,M.epoch(b),b,ev.user)then
      -- Contact retaliation bypasses the attacker's own Substitute. Keep
      -- native type/ability/status checks, source attribution and text.
      local sub=ev.user.substituteHP;ev.user.substituteHP=nil
      local out=pack(pcall(Status.inflict,b,ev.user,'BRN',{source='BEAK_BLAST',kascStatusSource67=ev.target}))
      ev.user.substituteHP=sub;if not out[1]then error(out[2],0)end
      for _,message in ipairs(out[2])do b:sayStatusMsg(ev.user,message)end
    end
  end
  function M.run(original,b,ctx,record)
    if not M.epoch(b)or not ctx or not ctx.user or not ctx.target or ctx.user==ctx.target then return original(b,ctx,record)end
    local prior=frames[b];local frame={};frames[b]=frame
    local raw,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports and mod.exports.pokemonLethalHitSurvival67
      local attempted=survival and survival.incomingHit(self,w) or amount
      local direct=w==ctx.target and w.mon.hp>0 and type(attempted)=='number'and attempted>0
      local substitute=direct and w.substituteHP~=nil
      local damage=previous(self,w,amount)
      if w==ctx.target then frame.hit={user=ctx.user,target=w,move=ctx.move,damage=damage,
        direct=direct,substitute=substitute}end
      return damage
    end
    local out=pack(pcall(original,b,ctx,record));b.applyDamage=raw;frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.perform(original,b,u,t,slot,isCalled)
    local move=slot and b:moveDef(slot)
    if not M.active(b,move)then return original(b,u,t,slot,isCalled)end
    local prior=resolving[u];local v=M.prepared(b,u)
    resolving[u]={move=move.id,gotHit=not isCalled and v and v.move==move.id and v.gotHit or false}
    local out=pack(pcall(original,b,u,t,slot,isCalled));resolving[u]=prior
    if not isCalled then M.clear(b,u)end
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.gate(ctx)
    if not M.active(ctx.battle,ctx.move)then return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')end
    if ctx.move.id=='SHELL_TRAP'then
      local v=resolving[ctx.user]
      if not v or v.move~='SHELL_TRAP'or not v.gotHit then
        return false,opts.i18n.text('The shell trap was not triggered!','Die Panzerfalle wurde nicht ausgelöst!')
      end
    end
    return true
  end
  function M.validateCheckpoint(b)
    if frames[b]or resolving[b.player]or resolving[b.enemy]then return false,'prepared_move_unsettled'end
    local r=rows(b);if not r then return true end
    if type(r)~='table'then return false,'invalid_prepared_move_container'end
    for k,v in pairs(r)do
      if (k~='player'and k~='enemy')or type(v)~='table'or not defs[v.move]
          or type(v.turn)~='number'or v.turn%1~=0 or v.turn~=(b.turnCount or 0)or type(v.gotHit)~='boolean'then
        return false,'invalid_prepared_move_state'
      end
      for field in pairs(v)do if field~='turn'and field~='move'and field~='gotHit'then return false,'unknown_prepared_move_field'end end
    end
    return true
  end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,7));assert(f.number==d.number and f.type==d.type and f.category==d.category
      and f.power==d.power and f.accuracy==100 and f.pp==d.pp and f.priority==-3 and f.target==d.target,'prepared move source drift '..id)
    assert(not mod.content.moves:get(id),'foreign prepared move owner '..id)
    local effect='KA_PREPARED_67_'..id
    mod.content.move_effects:register(effect,{kind='full',kascPreparedMoves67=M.OWNER,gate=M.gate})
    mod.content.moves:register(id,{id=id,name=opts.i18n.text(f.names.en,f.names.de),type=d.type,category=d.category,
      power=d.power,accuracy=100,pp=d.pp,priority=-3,target=d.target,contact=false,effect=effect,
      originGeneration=7,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,backendLearnsetRevision=d.revision,
      anim=copy(assert(mod.content.moves:get(d.parts[1])).anim)})
    local animation={seq={},source=M.OWNER}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do
      animation.seq[#animation.seq+1]=copy(step)
    end end
    mod.content.battle_anims:register(id,animation)
  end
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local shift=-16;local sprites={}
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascPreparedAnimation67=M
  if not Player._kascPreparedAnimationWrapped67 then local original=Player.start
    Player.start=function(self,id,...)local out=pack(original(self,id,...));Player._kascPreparedAnimation67.position(self,id);return unpack(out,1,out.n)end
    Player._kascPreparedAnimationWrapped67=true
  end
  function M.install()
    FX._kascPreparedMoves67=M;B._kascPreparedMoves67=M
    if not FX._kascPreparedMovesWrapped67 then local original=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascPreparedMoves67.run(original,...)end;FX._kascPreparedMovesWrapped67=true
    end
    if not B._kascPreparedMovesWrapped67 then local original=B.performMove
      B.performMove=function(...)return B._kascPreparedMoves67.perform(original,...)end;B._kascPreparedMovesWrapped67=true
    end
  end
  mod.events:on('battle.turn_started',M.arm,6000)
  mod.events:on('battle.damage_dealt',M.hit,100)
  mod.events:on('battle.turn_ended',function(ev)M.clear(ev.battle)end,-6000)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-selected-turn-and-damaging-hit-provenance',providerStatus='prepared-contact-and-physical-hit-singles',
    buildReceiptId='docs/PREPARED_MOVES_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})end
  return M
end
