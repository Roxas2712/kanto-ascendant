-- Entry-limited moves share one battle-local action budget per active side.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-FIRST-ACTION',OWNER='kasc.first-action/v1'}
  local frames=setmetatable({},{__mode='k'})
  local specs={FAKE_OUT={number=252,gen=3,power=40,type='NORMAL',priority=1,revision=1,anim='POUND'},
    FIRST_IMPRESSION={number=660,gen=7,power=90,type='BUG',priority=2,revision=20,anim='QUICK_ATTACK'}}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.enabled(b)
    local r=b and b.kascGenerationRulesReceipt
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]={actions=0,acted=false}end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.allowed(b,w)
    if not M.enabled(b)or not side(b,w)or not w.mon or w.mon.hp<=0 then return false end
    local f=frames[b];if f and f.user==w then return f.first end
    local r=rows(b);local v=r and r[side(b,w)]
    return not v or v.actions==0
  end
  function M.spend(b,w)
    if not M.enabled(b)or not side(b,w)or not w.mon or w.mon.hp<=0 then return end
    local r=rows(b,true);local key=side(b,w);local old=r[key]
    r[key]={actions=math.min(2,(old and old.actions or 0)+1),acted=true}
  end
  local function scoped(original,b,u,t,action,called)
    if not M.enabled(b)or not action or not side(b,u)or not u.mon or u.mon.hp<=0
        or not t or not t.mon or t.mon.hp<=0 then return original(b,u,t,action,called)end
    local parent=frames[b]
    if parent and parent.user==u then return original(b,u,t,action,called)end
    local f={user=u,first=M.allowed(b,u)}
    if not called then M.spend(b,u)end
    frames[b]=f
    local result=pack(pcall(original,b,u,t,action,called));frames[b]=parent
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  M.scoped=scoped
  function M.gate(ctx)
    if not M.enabled(ctx.battle)or not ctx.move or ctx.move.kascFirstAction67~=M.OWNER
        or not M.allowed(ctx.battle,ctx.user)then
      return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')
    end
    return true
  end
  function M.flinch(ctx)
    local b,t=ctx.battle,ctx.target;local r=rows(b);local v=r and r[side(b,t)]
    if not M.enabled(b)or t.mon.hp<=0 or t.substituteHP or ctx.brokeSub or v and v.acted then return{}end
    local a=mod.exports.pokemonAbilityEffects67
    if a and(a.blocksFlinch(b,t)or a.secondaryChance(ctx,100)<=0)then return{}end
    -- Fake Out's own guaranteed secondary is not native Bite's 10% roll.
    t.flinched=true
    if b.kascGenerationRulesReceipt.activeEpoch==2 then t.mustRecharge=nil end
    return{}
  end
  function M.noUseful(b,u,t,move)
    return move and specs[move.id]and move.kascFirstAction67==M.OWNER and M.enabled(b)and not M.allowed(b,u)or false
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'first_action_unsettled'end
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_first_action_container'end
    for key,v in pairs(r)do
      if(key~='player'and key~='enemy')or type(v)~='table'or not b[key]
          or type(v.actions)~='number'or v.actions%1~=0 or v.actions<0 or v.actions>2
          or type(v.acted)~='boolean'then return false,'invalid_first_action_state'end
      for k in pairs(v)do if k~='actions'and k~='acted'then return false,'unknown_first_action_field'end end
    end
    return true
  end
  function M.resume(b)
    -- Older checkpoints cannot prove an unused entry action. Do not grant
    -- another Fake Out after loading; the next real switch resets the side.
    if M.enabled(b)and not rows(b)then
      local r=rows(b,true);for _,key in ipairs({'player','enemy'})do r[key]={actions=2,acted=false}end
    end
  end
  function M.install()
    B._kascFirstAction67=M
    if B._kascFirstActionWrapped67 then return end
    for _,name in ipairs({'executeAction','performMove'})do
      local original=B[name];B[name]=function(...)return B._kascFirstAction67.scoped(original,...)end
    end
    local item,run=B.itemUsed,B.tryRun
    B.itemUsed=function(b,...)B._kascFirstAction67.spend(b,b.player);return item(b,...)end
    B.tryRun=function(b,...)
      if b.kind~='trainer'then B._kascFirstAction67.spend(b,b.player)end
      return run(b,...)
    end
    B._kascFirstActionWrapped67=true
  end
  for _,id in ipairs({'FAKE_OUT','FIRST_IMPRESSION'})do
    local s=specs[id];local f=assert(opts.facts.move(id,s.gen));local effect='KA_FIRST_ACTION_'..id..'_67'
    assert(f.number==s.number and f.power==s.power and f.type==s.type and f.category=='physical'
      and f.pp==10 and f.accuracy==100 and f.priority==s.priority,'first-action source drift '..id)
    local old=mod.content.moves:get(id)
    assert(not old or old.effect=='NO_ADDITIONAL_EFFECT'or old.effect=='FLINCH_SIDE_EFFECT1'
      or old.effect=='FLINCH_SIDE_EFFECT2','foreign first-action move '..id)
    mod.content.move_effects:register(effect,{kind='secondary',gate=M.gate,
      run=id=='FAKE_OUT'and M.flinch or nil,kascFirstAction67=M.OWNER})
    local fields={id=id,name=opts.i18n.text(f.names.en,f.names.de),type=s.type,category='physical',power=s.power,
      accuracy=100,pp=10,priority=s.priority,contact=true,effect=effect,kascFirstAction67=M.OWNER,
      originGeneration=s.gen,backendMoveNumber=s.number,backendMoveOwner=M.OWNER,
      backendLearnsetRevision=old and(old.backendLearnsetRevision or 1)or s.revision,
      anim=copy(assert(mod.content.moves:get(s.anim)).anim)}
    if old then mod.content.moves:patch(id,fields)else mod.content.moves:register(id,fields)end
    local anim=copy(assert(mod.content.battle_anims:get(s.anim)));anim.source=M.OWNER
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,anim)else mod.content.battle_anims:register(id,anim)end
  end
  -- Native hit OAM is offset from the Crystal battler anchors. Adjust only
  -- these owned move effects, never Pokemon artwork or the source moves.
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id,playerSide)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not specs[id]or not row or row.source~=M.OWNER then return end
    local dx,dy=0,id=='FAKE_OUT'and -16 or -12
    if not playerSide then dx,dy=id=='FAKE_OUT'and -32 or -16,id=='FAKE_OUT'and -8 or -4 end
    for _,step in ipairs(player.steps or{})do
      local sprites={}
      for i,s in ipairs(step.sprites or{})do
        local shifted=copy(s)
        if s.x>0 and s.x<168 and s.y>=16 and s.y<144 then
          shifted.x,shifted.y=s.x+dx,s.y+dy
        end
        sprites[i]=shifted
      end
      step.sprites=sprites
    end
  end
  Player._kascFirstActionAnimation67=M
  if not Player._kascFirstActionAnimationWrapped67 then
    local start=Player.start
    Player.start=function(self,id,playerSide,...)
      local result=start(self,id,playerSide,...)
      Player._kascFirstActionAnimation67.position(self,id,playerSide)
      return result
    end
    Player._kascFirstActionAnimationWrapped67=true
  end
  function M.withEffectTransform(g,original,b,...)
    if not g or type(g.push)~='function'or type(g.pop)~='function'
        or type(g.translate)~='function'then return original(b,...)end
    g.push()
    local result=pack(pcall(function(...)
      if b.animPlayer.attackerIsPlayer then g.translate(0,-16)else g.translate(-32,-8)end
      return original(b,...)
    end,...));g.pop()
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.draw(original,b,...)
    -- VASC's full-colour overlay is not native OAM, and its anchor module
    -- is intentionally not exported. Position ONLY this move's flat 2D
    -- effect layer using the engine draw seam. Never obtain private modules,
    -- mutate the provider's programs, or displace staged MAP/arena effects.
    if not M.enabled(b)or b.animName~='FAKE_OUT'or not b.animPlaying
        or b.voxelAscendantShot or not b.animPlayer or not b.animPlayer.custom then return original(b,...)end
    return M.withEffectTransform(love and love.graphics,original,b,...)
  end
  if not B._kascFirstActionDrawWrapped67 then
    local draw=B.drawAnimLayer
    B.drawAnimLayer=function(...)return B._kascFirstAction67.draw(draw,...)end
    B._kascFirstActionDrawWrapped67=true
  end
  mod.events:on('battle.started',function(ev)
    if M.enabled(ev.battle)then local r=rows(ev.battle,true)
      for _,key in ipairs({'player','enemy'})do r[key]={actions=0,acted=false}end
    end
  end,-11000)
  local function clearActed(ev)local r=rows(ev.battle);for _,v in pairs(r or{})do v.acted=false end end
  mod.events:on('battle.turn_started',clearActed,8000)
  mod.events:on('battle.turn_ended',clearActed,-11000)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-entry-actions-and-checkpoints',
      providerStatus='first-action-gate-and-guaranteed-flinch',buildReceiptId='docs/FIRST_ACTION_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
