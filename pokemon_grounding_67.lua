-- Shared groundedness for Levitate and the five elevation moves. These
-- scalar field tokens survive checkpoints but never a battler switch.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Effects=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-GROUNDING',OWNER='kasc.grounding/v1'}
  local tr=opts.i18n.text
  local items={IRON_BALL={gen=4,en='IRON BALL',de='EISENKUGEL'},
    AIR_BALLOON={gen=5,en='AIR BALLOON',de='LUFTBALLON'}}
  function M.itemMetadata(id)
    local r=items[id];if not r then return end
    return {id=id,generation=r.gen,names={en=r.en,de=r.de},flags={'holdable','holdable-passive'}}
  end
  for id,r in pairs(items)do
    local fields={kascGroundingItem67=M.OWNER,kascEquipmentRewardEpochs={}}
    for gen=r.gen,7 do fields.kascEquipmentRewardEpochs[gen]=true end
    if mod.content.items:get(id)then mod.content.items:patch(id,fields)
    else
      fields.id=id;fields.name=tr(r.en,r.de);fields.names={en=r.en,de=r.de}
      fields.price=0;fields.keyItem=false;fields.field=false;fields.battle=false
      mod.content.items:register(id,fields)
    end
  end
  function M.supportsItem(game,id,gen)
    local def=game and game.data and game.data.items and game.data.items[id]
    local effects=game and game.data and game.data.move_effects
    return items[id]and def and def.kascGroundingItem67==M.OWNER
      and effects and effects.HEAL_EFFECT and effects.HEAL_EFFECT.kascGrounding67==M.OWNER
      and type(gen)=='number'and gen%1==0 and gen>=items[id].gen and gen<=7 or false
  end
  function M.item(b,w)
    local gen=M.epoch(b);local mon=w and w.mon
    if not gen or not mon or mon.egg or mon.isEgg or mon.eggSpecies
        or opts.abilities.activeAbility(b,w)=='KLUTZ'then return end
    local id=opts.held(mon,b,w)
    if M.supportsItem(b.game,id,gen)then return id end
  end
  function M.speedFactor(b,w)return M.item(b,w)=='IRON_BALL'and 0.5 or 1 end
  local aliases,gravityMoves={},{}
  for id,row in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do
      aliases[alias]=id
      for _,flag in ipairs(row.flags or{})do if flag=='gravity'then gravityMoves[alias]=true end end
    end
  end
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return {n=select('#',...),...}end
  local function side(b,w)return w==b.player and 'player'or w==b.enemy and 'enemy'or nil end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{} end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function row(b,w,create)
    local r=state(b,create);local key=side(b,w)
    if not r or not key then return end
    if create then r[key]=r[key]or{}end
    return r[key]
  end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascGrounding67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  local function active(b,value)return type(value)=='number'and value>=(b.turnCount or 0)end
  function M.gravity(b)local r=state(b);return M.epoch(b)and r and active(b,r.gravity)or false end
  function M.grounded(b,w)
    local r=row(b,w);local roots=mod.exports.pokemonRootRecovery67
    return M.gravity(b)or M.epoch(b)and r and r.grounded==true
      or roots and roots.grounded(b,w)
      or M.item(b,w)=='IRON_BALL'or false
  end
  local function hasType(w,typ)for _,t in ipairs(w.curTypes or{})do if t==typ then return true end end;return false end
  function M.airborne(b,w)
    if not M.epoch(b)or not w or not w.mon or w.mon.hp<=0 or M.grounded(b,w)then return false end
    local r=row(b,w)
    return hasType(w,'FLYING')or opts.abilities.activeAbility(b,w)=='LEVITATE'
      or M.item(b,w)=='AIR_BALLOON'
      or r and (active(b,r.rise)or active(b,r.tele))or false
  end
  function M.blocksGround(b,u,t,move)
    return move and move.type=='GROUND'and aliases[move.id]~='THOUSAND_ARROWS'and u~=t and M.airborne(b,t)or false
  end
  local function airCharge(w)
    local id=w and w.charging and aliases[w.charging.id]
    return id=='FLY'or id=='BOUNCE'or id=='SKY_DROP'
  end
  function M.down(b,w,permanent)
    local r=row(b,w,true);if not r then return end
    if permanent then r.grounded=true end
    r.rise=nil;r.tele=nil
    local sky=mod.exports.pokemonSkyDrop67
    local keep=sky and sky.groundingDown(b,w,permanent)
    if not keep and airCharge(w)then w.charging=nil;w.invulnerable=nil;r.cancelAirTurn=b.turnCount or 0 end
  end
  function M.blockedMove(b,w,move)
    if not M.epoch(b)or not move then return false end
    local r=row(b,w);local id=aliases[move.id]
    return M.gravity(b)and gravityMoves[move.id]or r and r.cancelAirTurn==(b.turnCount or 0)
      and (id=='FLY'or id=='BOUNCE'or id=='SKY_DROP')or false
  end
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.canRise(b,u)
    local gen=M.epoch(b);local r=row(b,u);local roots=mod.exports.pokemonRootRecovery67
    return gen and u and u.mon and u.mon.hp>0 and not M.gravity(b)
      and not(r and(r.grounded or active(b,r.rise)))and not(roots and roots.grounded(b,u))
      and not(gen==4 and opts.abilities.activeAbility(b,u)=='LEVITATE')or false
  end
  function M.noUseful(b,u,t,move)
    return M.epoch(b)and move and aliases[move.id]=='MAGNET_RISE'and not M.canRise(b,u)or false
  end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    if not M.epoch(b)or opts.priority.blocks(ctx)then return failed()end
    local id=aliases[ctx.move.id];local turn=b.turnCount or 0
    if id=='GRAVITY'then
      if M.gravity(b)then return failed()end
      state(b,true).gravity=turn+4
      for _,w in ipairs({b.player,b.enemy})do M.down(b,w,false)end
      return {tr('Gravity intensified!','Die Schwerkraft steigt!')}
    end
    if id=='MAGNET_RISE'then
      if not M.canRise(b,u)then return failed()end
      row(b,u,true).rise=turn+4
    elseif id=='TELEKINESIS'then
      if M.grounded(b,t)or t.mon.hp<=0 or t.substituteHP or active(b,(row(b,t)or{}).tele)then return failed()end
      local key=opts.binding.key(b.game,t.mon);local def=key and opts.catalog.entries[key]
      local dex=def and def.nationalDex
      if dex==50 or dex==51 or dex==769 or dex==770 or def and def.identifier=='gengar-mega'then return failed()end
      row(b,t,true).tele=turn+2
    end
    return {tr('It floats above the ground!','Es schwebt über dem Boden!')}
  end
  function M.scope(b,u,t,move,fn)
    if not M.epoch(b)or not move or not u or not t or u==t then return fn()end
    local id=aliases[move.id];local oldTypes,view=t.curTypes,nil
    if move.type=='GROUND'and (M.grounded(b,t)or id=='THOUSAND_ARROWS')then
      view={}
      -- V+ Iron Ball makes a Flying holder's entire Ground matchup neutral,
      -- unless another grounding effect already applies. IV keeps other types.
      local neutralBall=M.epoch(b)>=5 and M.item(b,t)=='IRON_BALL'and hasType(t,'FLYING')
        and not M.gravity(b)and not((row(b,t)or{}).grounded)
      if not neutralBall and not(id=='THOUSAND_ARROWS'and hasType(t,'FLYING')and not M.grounded(b,t))then
        for _,typ in ipairs(oldTypes or{})do if typ~='FLYING'then view[#view+1]=typ end end
      end
      t.curTypes=view
    end
    local oldInv=t.invulnerable
    local hitAir=(id=='SMACK_DOWN'or id=='THOUSAND_ARROWS')and airCharge(t)
    if hitAir then t.invulnerable=nil end
    local out=pack(pcall(fn))
    if view and t.curTypes==view then t.curTypes=oldTypes end
    if hitAir and airCharge(t)and t.invulnerable==nil then t.invulnerable=oldInv end
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    return M.scope(ctx.battle,ctx.user,ctx.target,ctx.move,function()
      if M.blocksGround(ctx.battle,ctx.user,ctx.target,ctx.move)then return 0,{crit=false,typeMult=0}end
      return nextDamage(ctx)
    end)
  end
  function M.accuracy(nextAccuracy,ctx)
    local b=ctx and ctx.battle
    if not M.epoch(b)or not ctx.move then return nextAccuracy(ctx)end
    local r=row(b,ctx.target)
    if r and active(b,r.tele)and ctx.move.effect~='OHKO_EFFECT'then return true end
    if M.gravity(b)and type(ctx.move.accuracy)=='number'and ctx.move.effect~='OHKO_EFFECT'then
      local out=copy(ctx);out.move=copy(ctx.move)
      out.move.accuracy=math.floor(ctx.move.accuracy*6840/4096)
      return nextAccuracy(out)
    end
    return nextAccuracy(ctx)
  end
  function M.run(original,b,ctx,record)
    local sub=ctx.target.substituteHP~=nil;ctx.kascGroundHitSub67=sub
    if not M.blocksGround(b,ctx.user,ctx.target,ctx.move)then return original(b,ctx,record)end
    local selected=copy(record);local gate=selected.gate
    selected.gate=function(c)
      if gate then local ok,msg=gate(c);if not ok then return ok,msg end end
      return false,tr('It does not affect the airborne target!','Das schwebende Ziel ist immun!')
    end
    return original(b,ctx,selected)
  end
  function M.validateCheckpoint(b)
    local r=state(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_grounding_container'end
    local function turn(v)return type(v)=='number'and v%1==0 and v>=0 and v<=(b.turnCount or 0)+4 end
    for key,value in pairs(r)do
      if key=='gravity'then if not turn(value)then return false,'invalid_gravity_turn'end
      elseif key=='player'or key=='enemy'then
        if type(value)~='table'then return false,'invalid_grounding_side'end
        for k,v in pairs(value)do
          if k=='grounded'then if v~=true then return false,'invalid_grounding_flag'end
          elseif k=='rise'or k=='tele'or k=='cancelAirTurn'then if not turn(v)then return false,'invalid_elevation_turn'end
          else return false,'unknown_elevation_field'end
        end
      else return false,'unknown_grounding_side'end
    end
    return true
  end
  function M.endTurn(ev)
    local b=ev.battle;local r=state(b);if not r then return end
    local turn=b.turnCount or 0
    if r.gravity and r.gravity<=turn then r.gravity=nil end
    for _,key in ipairs({'player','enemy'})do
      for _,field in ipairs({'rise','tele','cancelAirTurn'})do
        if r[key]and r[key][field]and r[key][field]<=turn then r[key][field]=nil end
      end
    end
  end
  function M.switch(ev)
    local r=state(ev.battle);local key=side(ev.battle,ev.battler);if r and key then r[key]=nil end
  end
  local function deep(v)
    if type(v)~='table'then return v end
    local r={};for k,x in pairs(v)do r[k]=deep(x)end;return r
  end
  for _,id in ipairs({'GRAVITY','MAGNET_RISE','TELEKINESIS'})do
    local move=assert(mod.content.moves:get(id));local effect='KA_GROUNDING_67_'..id
    assert(move.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign elevation move '..id)
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=id=='TELEKINESIS',run=M.cast})
    mod.content.moves:patch(id,{effect=effect})
    local anim=id=='MAGNET_RISE'and 'LIGHT_SCREEN'or 'CONFUSION'
    mod.content.battle_anims:patch(id,deep(assert(mod.content.battle_anims:get(anim))))
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  for _,id in ipairs({'SMACK_DOWN','THOUSAND_ARROWS'})do
    local move=assert(mod.content.moves:get(id));local record=copy(mod.content.move_effects:get(move.effect))
    local old=record.afterDamage
    record.afterDamage=function(ctx)
      if old then old(ctx)end
      if M.epoch(ctx.battle)and ctx.totalDealt>0 and not ctx.kascGroundHitSub67 and ctx.target.mon.hp>0 then M.down(ctx.battle,ctx.target,true)end
    end
    local effect='KA_GROUNDING_67_'..id;mod.content.move_effects:register(effect,record)
    mod.content.moves:patch(id,{effect=effect})
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascGrounding67=M.OWNER})
  B._kascGrounding67=M;Effects._kascGrounding67=M
  if not B._kascGroundingWrapped67 then
    local old=B.performMove
    B.performMove=function(b,u,t,move,called)
      return B._kascGrounding67.scope(b,u,t,b:moveDef(move),function()return old(b,u,t,move,called)end)
    end
    local run=Effects.runDamaging
    Effects.runDamaging=function(...)return Effects._kascGrounding67.run(run,...)end
    B._kascGroundingWrapped67=true
  end
  mod.hooks:wrap('battle.damage',M.damage,28000)
  mod.hooks:wrap('battle.accuracy',M.accuracy,-7100)
  mod.events:on('battle.turn_ended',M.endTurn,90)
  mod.events:on('battle.damage_dealt',function(ev)
    local b,w=ev.battle,ev.target
    -- This native event only reports direct move hits (including Substitute).
    -- A preview, poison tick, missed strike or immunity never consumes it.
    if (ev.damage or 0)>0 and ev.user~=w and M.item(b,w)=='AIR_BALLOON'then
      w.mon.item=nil;w.mon.heldItem=nil
      if opts.abilities.onItemLost then opts.abilities.onItemLost(b,w,'AIR_BALLOON')end
      b:sayNext(tr('The Air Balloon popped!','Der Luftballon ist geplatzt!'))
    end
  end,100)
  mod.events:on('battle.battler_switched',M.switch,8000)
  mod.events:on('battle.ended',function(ev)
    local b=ev.battle;if state(b)then b.field.tokens[M.OWNER]=nil end
  end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-moves-selection-and-checkpoint',providerStatus='grounding-and-levitate',
      buildReceiptId='docs/FINISH_1600_20260910.md',rollbackReceiptId='docs/FINISH_1600_20260910.md'})
  end
  return M
end
