-- Direct battle-local assignments, not stat changes: Contrary, Simple and
-- stat-drop reactions must not turn a swap or average into a boost event.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-STAT-EXCHANGE',OWNER='kasc.stat-exchange/v1'}
  local tr=opts.i18n.text
  local defs={POWER_SWAP={number=384,generation=4,kind='swap',pair='attack'},
    GUARD_SWAP={number=385,generation=4,kind='swap',pair='defense'},
    HEART_SWAP={number=391,generation=4,kind='swap',pair='all'},
    POWER_SPLIT={number=471,generation=5,kind='split',pair='attack'},
    GUARD_SPLIT={number=470,generation=5,kind='split',pair='defense'},
    TOPSY_TURVY={number=576,generation=6,kind='invert',pair='all'}}
  local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function living(w)return w and w.mon and type(w.mon.hp)=='number'and w.mon.hp>0 and not w.fainted end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.epoch(b,move,u)
    local r=b and b.kascGenerationRulesReceipt;local d=move and defs[move.id]
    local e=d and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or not integer(r.activeEpoch,1,7)or not d or move.backendMoveOwner~=M.OWNER
        or not e or e.kascStatExchange67~=M.OWNER then return end
    if r.activeEpoch<d.generation and not(living(u)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species]))then return end
    return r.activeEpoch
  end
  local function keys(gen,pair,raw)
    if pair=='attack'then return{'attack',gen==1 and'special'or'specialAttack'}end
    if pair=='defense'then return{'defense',gen==1 and'special'or'specialDefense'}end
    local t={'attack','defense','speed','accuracy','evasion'}
    if gen==1 then t[#t+1]='special'else t[#t+1]='specialAttack';t[#t+1]='specialDefense'end
    return t
  end
  function M.plan(b,u,t,move)
    local gen=M.epoch(b,move,u);local d=move and defs[move.id]
    if not gen or not living(u)or not living(t)or u==t or not side(b,u)or not side(b,t)
        or t.invulnerable then return end
    local ctx={battle=b,user=u,target=t,move=move}
    if mod.exports.pokemonPriorityAbilities67.blocks(ctx)or mod.exports.pokemonProtection67.blocks(ctx)
        or d.kind~='swap'and(t.substituteHP or 0)>0 then return end
    local ks=keys(gen,d.pair,d.kind=='split');local a,z={},{ };local changed=false
    for _,key in ipairs(ks)do
      local x,y
      if d.kind=='split'then
        x=u.curStats and u.curStats[key];y=t.curStats and t.curStats[key]
        if not integer(x,1,9999)or not integer(y,1,9999)then return end
        local n=math.floor((x+y)/2);a[key]=n;z[key]=n;changed=changed or x~=n or y~=n
      else
        x=u.stages and u.stages[key]or 0;y=t.stages and t.stages[key]or 0
        if not integer(x,-6,6)or not integer(y,-6,6)then return end
        if d.kind=='invert'then z[key]=-y;changed=changed or y~=0
        else a[key]=y;z[key]=x;changed=changed or x~=y end
      end
    end
    if d.kind=='invert'and not changed then return end
    return{kind=d.kind,user=a,target=z,changed=changed}
  end
  function M.cast(ctx)
    local p=M.plan(ctx.battle,ctx.user,ctx.target,ctx.move);if not p then return failed()end
    local u,t=ctx.user,ctx.target
    if p.kind=='split'then
      local a,z=copy(u.curStats),copy(t.curStats)
      for k,v in pairs(p.user)do a[k]=v end;for k,v in pairs(p.target)do z[k]=v end
      u.curStats,t.curStats=a,z
    else
      if p.kind~='invert'then local a=copy(u.stages or{});for k,v in pairs(p.user)do a[k]=v end;u.stages=a;u.hazeStatReset=nil end
      local z=copy(t.stages or{});for k,v in pairs(p.target)do z[k]=v end;t.stages=z;t.hazeStatReset=nil
    end
    return{tr('%s changed the battle stats!','%s verändert die Kampfwerte!'):format(ctx.move.name)}
  end
  function M.noUseful(b,u,t,move)
    if not move or not defs[move.id]or not M.epoch(b,move,u)then return false end
    return opts.abilities.moveScope(b,u,t,true,function()
      local p=M.plan(b,u,t,move);if not p or not p.changed then return true end
      local ks=keys(M.epoch(b,move,u),defs[move.id].pair,p.kind=='split')
      for _,k in ipairs(ks)do
        local oldU=p.kind=='split'and u.curStats[k]or(u.stages or{})[k]or 0
        local oldT=p.kind=='split'and t.curStats[k]or(t.stages or{})[k]or 0
        if p.user[k]and p.user[k]>oldU or p.target[k]<oldT then return false end
      end
      return true
    end,move)
  end
  -- The native checkpoint already serializes detached curStats/stages. No
  -- redundant save token or reference to the opposing Pokémon is necessary.
  function M.validateCheckpoint(b)
    for _,w in ipairs({b.player,b.enemy})do if w then
      for _,v in pairs(w.stages or{})do if not integer(v,-6,6)then return false,'invalid_stat_exchange_stage'end end
    end end
    return true
  end
  for _,id in ipairs({'POWER_SWAP','GUARD_SWAP','HEART_SWAP','POWER_SPLIT','GUARD_SPLIT','TOPSY_TURVY'})do
    local d=defs[id];local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.generation and f.category=='status'and f.power==0
      and f.alwaysHits and f.accuracy==100 and f.priority==0 and f.target==10,'stat exchange source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign stat exchange owner '..id)
    local effect='KA_STAT_EXCHANGE_67_'..id;local flags={}
    for _,k in ipairs(f.flags or{})do flags[k]=1 end
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=M.cast,kascStatExchange67=M.OWNER})
    mod.content.moves:patch(id,{effect=effect,power=0,pp=f.pp,accuracy=100,priority=0,type=f.type,
      category='status',target=10,flags=flags,kascBypassSub67=d.kind=='swap',backendMoveOwner=M.OWNER,
      backendMoveNumber=d.number,originGeneration=d.generation,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    mod.content.battle_anims:patch(id,{seq={{effect='SE_SHOOT_BALLS_UPWARD',sound='FOCUS_ENERGY'}},source=M.OWNER})
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  function M.position(player,id)
    if not defs[id]then return end
    local a=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not a or a.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={};for i,s in ipairs(step.sprites or{})do
      local q=copy(s);if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
      sprites[i]=q
    end;step.sprites=sprites end
  end
  function M.install()
    Player._kascStatExchange67=M
    if not Player._kascStatExchangeWrapped67 then local original=Player.start
      Player.start=function(self,id,...)local out={original(self,id,...)};Player._kascStatExchange67.position(self,id);return unpack(out)end
      Player._kascStatExchangeWrapped67=true end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-battle-stats-stages-and-checkpoint',providerStatus='direct-stage-swap-inversion-and-raw-stat-average',
    buildReceiptId='docs/STAT_EXCHANGE_67.md',rollbackReceiptId='docs/STAT_EXCHANGE_67.md'})end
  return M
end
