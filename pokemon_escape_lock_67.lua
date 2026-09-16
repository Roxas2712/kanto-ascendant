-- Persistent trapping while its source remains active. No residual damage,
-- no battler pointers in saves, and no independent switch-menu owner.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-ESCAPE-LOCK',OWNER='kasc.escape-lock/v1'}
  local tr=opts.i18n.text
  local specs={ANCHOR_SHOT={number=677,gen=7,power=80,pp=20,type='STEEL',contact=true,anim='CLAMP'},
    SPIRIT_SHACKLE={number=662,gen=7,power=80,pp=10,type='GHOST',anim='LICK'},
    MEAN_LOOK={number=212,gen=2,power=0,pp=5,type='NORMAL',anim='LEER'},
    SPIDER_WEB={number=169,gen=2,power=0,pp=10,type='BUG',anim='STRING_SHOT'},
    BLOCK={number=335,gen=3,power=0,pp=5,type='NORMAL',anim='BARRIER'}}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function active(b,w)return w and w.mon and w.mon.hp>0 and side(b,w)end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function has(w,kind)for _,t in ipairs(w.curTypes or{})do if t==kind then return true end end;return false end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and r.activeEpoch>=1 and r.activeEpoch<=7 then return r.activeEpoch end
  end
  function M.state(b,w)
    if not M.epoch(b)or not active(b,w)then return end
    local r=rows(b);local row=r and r[side(b,w)]
    if row and active(b,b[row.source])then return row end
  end
  function M.blocked(b,w,forRun)
    local gen=M.epoch(b)
    if not gen or not M.state(b,w)or gen>=6 and has(w,'GHOST')then return false end
    local A,E=mod.exports.pokemonAbilityEffects67,mod.exports.pokemonEquipment67
    if not forRun and gen>=4 and A and E and E.battleHeldId(w.mon,b,w)=='SHED_SHELL'
        and A.activeAbility(b,w)~='KLUTZ'then return false end
    return true
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if not w then b.field.tokens[M.OWNER]=nil;return end
    local key=side(b,w);if not key then return end
    for target,row in pairs(r)do if target==key or row.source==key then r[target]=nil end end
  end
  local function failure()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.canStart(ctx,secondary)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b)
    local s=ctx.move and specs[ctx.move.id]
    if not gen or not s or not active(b,u)or not active(b,t)or u==t
        or M.state(b,t)or gen>=6 and has(t,'GHOST')then return false end
    if secondary then
      local A=mod.exports.pokemonAbilityEffects67
      return not t.substituteHP and not ctx.brokeSub
        and ((ctx.totalDealt or 0)>0 or (ctx.hits or 0)>0 and (ctx.rawDamage or 0)>0)
        and (not A or A.secondaryChance(ctx,100)>0)
    end
    local A=mod.exports.pokemonAbilityEffects67
    local bypass=gen>=6 and A and A.activeAbility(b,u)=='INFILTRATOR'
    if t.invulnerable or math.max(gen,s.gen)>=3 and t.substituteHP and not bypass then return false end
    local priority=mod.exports.pokemonPriorityAbilities67
    return not(priority and priority.blocks(ctx))
  end
  function M.start(ctx)
    local s=specs[ctx.move.id];local secondary=s and s.power>0
    if not M.canStart(ctx,secondary)then return secondary and{}or failure()end
    local b,u,t=ctx.battle,ctx.user,ctx.target
    rows(b,true)[side(b,t)]={source=side(b,u),move=ctx.move.id}
    return{tr('%s cannot escape!','%s kann nicht entkommen!'):format(t.name or t.mon.species)}
  end
  function M.afterDamage(ctx)
    -- Endure at 1 HP is still a successful hit. The host's secondary.run
    -- path requires actual HP loss and would silently omit the trap here.
    -- Keep the same Substitute, KO, Shield Dust and Sheer Force guards.
    for _,message in ipairs(M.start(ctx))do ctx.battle:sayNext(message)end
  end
  function M.noUseful(b,u,t,move)
    local s=move and specs[move.id]
    if not s or s.power>0 or not M.epoch(b)then return false end
    local ctx={battle=b,user=u,target=t,move=move}
    local A=mod.exports.pokemonAbilityEffects67
    return A.moveScope(b,u,t,true,function()
      local guard=mod.exports.pokemonProtection67
      return not M.canStart(ctx,false)or guard and guard.blocks(ctx)
        or M.epoch(b)>=5 and A.activeAbility(b,t)=='MAGIC_BOUNCE'
    end,move)
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_escape_lock_container'end
    for target,row in pairs(r)do
      if(target~='player'and target~='enemy')or type(row)~='table'
          or(row.source~='player'and row.source~='enemy')or row.source==target
          or not specs[row.move]or not b.data.moves[row.move]then return false,'invalid_escape_lock_state'end
      for key in pairs(row)do if key~='source'and key~='move'then return false,'unknown_escape_lock_field'end end
    end
    return true
  end
  for _,id in ipairs({'ANCHOR_SHOT','SPIRIT_SHACKLE','MEAN_LOOK','SPIDER_WEB','BLOCK'})do
    local s=specs[id];local f=assert(opts.facts.move(id,s.gen));local secondary=s.power>0
    assert(f.number==s.number and f.type==s.type and f.power==s.power and f.pp==s.pp
      and f.category==(secondary and'physical'or'status')and f.priority==0,'escape-lock source drift '..id)
    local old=mod.content.moves:get(id);local effect='KA_ESCAPE_LOCK_67_'..id
    assert(not old or old.effect=='NO_ADDITIONAL_EFFECT'or old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,
      'foreign escape-lock owner '..id..': '..tostring(old and old.effect))
    mod.content.move_effects:register(effect,{kind=secondary and'full'or'primary',
      accuracyChecked=false,run=not secondary and M.start or nil,
      afterDamage=secondary and M.afterDamage or nil,kascEscapeLock67=M.OWNER})
    local fields={id=id,name=tr(f.names.en,f.names.de),type=s.type,power=s.power,pp=s.pp,
      category=f.category,accuracy=100,priority=0,contact=s.contact==true,effect=effect,
      originGeneration=s.gen,backendMoveNumber=s.number,backendMoveOwner=M.OWNER,
      backendLearnsetRevision=old and(old.backendLearnsetRevision or 1)or 21,
      anim=copy(assert(mod.content.moves:get(s.anim)).anim)}
    if old then mod.content.moves:patch(id,fields)else mod.content.moves:register(id,fields)end
    if opts.catalog then for i=#opts.catalog.unsupportedStatus,1,-1 do
      if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end
    end end
    local anim=copy(assert(mod.content.battle_anims:get(s.anim)));anim.source=M.OWNER
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,anim)else mod.content.battle_anims:register(id,anim)end
  end
  -- Position only our copied attack OAM. CLAMP's lower claw otherwise
  -- reaches the Crystal name card; the source move and Pokemon art stay put.
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id,playerSide)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if id~='ANCHOR_SHOT'or not row or row.source~=M.OWNER then return end
    local dx,dy=0,-8
    for _,step in ipairs(player.steps or{})do
      local sprites={}
      for i,s in ipairs(step.sprites or{})do
        local moved=copy(s)
        if s.x>0 and s.x<168 and s.y>=16 and s.y<144 then moved.x,moved.y=s.x+dx,s.y+dy end
        sprites[i]=moved
      end
      step.sprites=sprites
    end
  end
  Player._kascEscapeLockAnimation67=M
  if not Player._kascEscapeLockAnimationWrapped67 then
    local start=Player.start
    Player.start=function(self,id,playerSide,...)
      local result=start(self,id,playerSide,...)
      Player._kascEscapeLockAnimation67.position(self,id,playerSide)
      return result
    end
    Player._kascEscapeLockAnimationWrapped67=true
  end
  local colour={BLOCK=true,MEAN_LOOK=true,SPIDER_WEB=true}
  local function pack(...)return{n=select('#',...),...}end
  function M.withEffectTransform(g,original,b,...)
    if not g or type(g.push)~='function'or type(g.pop)~='function'
        or type(g.translate)~='function'then return original(b,...)end
    g.push()
    local result=pack(pcall(function(...)
      -- A travelling enemy web must pass above the player name card before
      -- reaching the back sprite; stationary target marks need less offset.
      g.translate(0,(b.animPlayer.attackerIsPlayer or b.animName=='SPIDER_WEB')and -24 or -8)
      return original(b,...)
    end,...));g.pop()
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.draw(original,b,...)
    -- VASC colour programs have a separate effect layer. Use the engine's
    -- public draw seam, not private VASC anchors or a Pokemon renderer.
    if not M.epoch(b)or not colour[b.animName]or not b.animPlaying
        or b.voxelAscendantShot or not b.animPlayer or not b.animPlayer.custom then return original(b,...)end
    return M.withEffectTransform(love and love.graphics,original,b,...)
  end
  B._kascEscapeLockDraw67=M
  if not B._kascEscapeLockDrawWrapped67 then
    local draw=B.drawAnimLayer
    B.drawAnimLayer=function(...)return B._kascEscapeLockDraw67.draw(draw,...)end
    B._kascEscapeLockDrawWrapped67=true
  end
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler or ev.previous)end,8000)
  mod.events:on('battle.fainted',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='shared-run-switch-owner-and-checkpoints',
      providerStatus='source-bound-escape-lock',buildReceiptId='docs/ESCAPE_LOCK_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
