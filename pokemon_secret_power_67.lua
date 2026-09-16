-- Secret Power uses the authored encounter environment, never a guessed map
-- name. Only the actual native body-hit scope may apply its secondary.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer');local A=assert(opts.abilities)
  local M={CARD_ID='KASC-67-SECRET-POWER',OWNER='kasc.secret-power/v1'}
  local aliases={};local frames=setmetatable({},{__mode='k'})
  local hits=setmetatable({},{__mode='k'});local statusScopes=setmetatable({},{__mode='k'})
  for _,native in ipairs(opts.species.moveIds('SECRET_POWER'))do aliases[native]=true end
  local environments={grass=true,long_grass=true,sand=true,underwater=true,water=true,pond=true,
    mountain=true,cave=true,building=true,plain=true,snow=true,ice=true,marsh=true,bridge=true,puddle=true}
  -- Emerald's actual getsecretpowereffect switch; Platinum's actual terrain
  -- table. V+ keeps explicitly authored world environments (not Wi-Fi).
  local era3={grass='PSN',long_grass='SLP',sand='accuracy',underwater='def',water='atk',pond='spe',
    mountain='confusion',cave='flinch',building='PAR',plain='PAR',snow='PAR',ice='PAR',marsh='PAR',bridge='PAR',puddle='PAR'}
  local era4={grass='SLP',long_grass='SLP',sand='accuracy',underwater='def',water='atk',pond='atk',
    mountain='flinch',cave='flinch',building='PAR',plain='accuracy',snow='FRZ',ice='FRZ',marsh='spe',bridge='evasion',puddle='SLP'}
  local era5={grass='SLP',long_grass='SLP',sand='accuracy',underwater='def',water='atk',pond='atk',
    mountain='accuracy',cave='flinch',building='PAR',plain='accuracy',snow='FRZ',ice='FRZ',marsh='spe',bridge='evasion',puddle='spe'}
  local era6={grass='SLP',long_grass='SLP',sand='accuracy',underwater='atk',water='atk',pond='atk',
    mountain='accuracy',cave='flinch',building='PAR',plain='PAR',snow='FRZ',ice='FRZ',marsh='spe',bridge='evasion',puddle='spe'}
  local terrainEffects={electric='PAR',grassy='SLP',misty='spa',psychic='spe'}
  local statNames={atk='attack',def='defense',spe='speed',spa='specialAttack'}
  local major={PSN=true,SLP=true,PAR=true,FRZ=true}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function index(b,w)local key=side(b,w);local mons=key=='player'and b:playerPartyView()or key=='enemy'and(b.enemyParty or{w.mon})
    for i,p in ipairs(mons or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function mode(b)local r=b and b.kascGenerationRulesReceipt;local marker=b and b.data and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or type(r)~='table'
      or not int(r.activeEpoch,1,7)or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      or not marker or marker.kascSecretPower67~=M.OWNER then return end;return r.activeEpoch end
  local function owned(move)return move and aliases[move.id]and move.backendMoveOwner==M.OWNER and move.backendMoveNumber==290 end
  function M.epoch(b,u,move)
    local gen=mode(b);if not move then return gen end
    local effect=gen and b.data.move_effects[move.effect]
    if not gen or not owned(move)or not effect or effect.kascSecretPower67~=M.OWNER then return end
    if gen<3 and not(live(u)and index(b,u)and opts.rules.monMoveAvailable(b.game,u.mon,move.id,gen,true))then return end
    return math.max(3,gen)
  end
  local function state(b,create)local tokens=b and b.field and b.field.tokens
    if not tokens then return end;local r=tokens[M.OWNER]
    if not r and create then r={};tokens[M.OWNER]=r end;return r end
  local function mapId(b)return b.checkpointOrigin and b.checkpointOrigin.map or false end
  function M.environment(b)
    local r=state(b);if r then return r.kind end
    local ow=b and b.game and b.game.overworld;local map=ow and ow.map;local def=map and map.def
    local mapKey=mapId(b)
    if not map or mapKey and map.id~=mapKey then def=mapKey and b.data.maps[mapKey]end
    if def and environments[def.battleEnvironment]then return def.battleEnvironment end
    -- Existing owner uses Map.defCellTile/defIsWaterCell and real tileset
    -- categories. In particular pond is NOT Platinum's distinct puddle.
    local called=assert(mod.exports.pokemonCalledMoves67,'Secret Power needs authored environment owner')
    local kind=called.environment(b);assert(environments[kind],'unknown authored battle environment')
    return kind
  end
  function M.choice(b,u,move)
    local gen=M.epoch(b,u,move);if not gen then return end
    local kind=M.environment(b);local terrain=mod.exports.pokemonTerrain67
    local active=gen>=6 and terrain and terrain.current(b);local effect=active and terrainEffects[active]
    if not effect then effect=(gen==3 and era3 or gen==4 and era4 or gen==5 and era5 or era6)[kind]end
    local out={effect=statNames[effect]or effect,environment=kind,epoch=gen,chance=30}
    if active then out.terrain=active end;return out
  end
  function M.chance(ctx)
    local gen=M.epoch(ctx.battle,ctx.user,ctx.move);if not gen then return 0 end
    local chance=A.secondaryChance(ctx,30)
    -- Gen V's explicit Serene Grace exception; III/IV and VI/VII double.
    if gen==5 and chance>0 and A.activeAbility(ctx.battle,ctx.user)=='SERENE_GRACE'then return 30 end
    return chance
  end
  function M.preview(b,u,t,move)
    local out=M.choice(b,u,move);if not out then return end
    out.chance=M.chance({battle=b,user=u,target=t,move=move});return out
  end
  local function same(a,z)return a and z and a.id==z.id and a.effect==z.effect and owned(a)and owned(z)end
  local function body(ctx)
    local owner=assert(mod.exports.pokemonBodyCounter67,'Secret Power needs private native body-hit owner')
    return owner.nativeHit(ctx.battle,{battle=ctx.battle,user=ctx.user,target=ctx.target,move=ctx.move,damage=ctx.totalDealt})
  end
  function M.authorizedStatusEpoch(b,t,status,options)
    local ctx=statusScopes[b];local o=options or{};local scope=hits[b]
    if not ctx or not scope or scope.user~=ctx.user or scope.target~=t or ctx.target~=t
      or not same(scope.move,ctx.move)or o.source~=ctx.move.id or o.secondary~=true
      or o.kascStatusSource67~=ctx.user or not live(t)then return end
    local proof=body(ctx);local choice=M.choice(b,ctx.user,ctx.move)
    if proof and not proof.substitute and not ctx.brokeSub and choice and choice.effect==status and major[status]then return choice.epoch end
  end
  function M.secondary(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local scope=hits[b]
    if not scope or scope.user~=u or scope.target~=t or not same(scope.move,ctx.move)
      or scope.seen[ctx]or not M.epoch(b,u,ctx.move)or not live(t)then return{}end
    local proof=body(ctx)
    if not proof or proof.substitute or ctx.brokeSub or t.substituteHP then return{}end
    scope.seen[ctx]=true
    local choice=M.choice(b,u,ctx.move);local chance=M.chance(ctx)
    if chance<=0 or ctx.rng(1,100)>chance then return{}end
    local effect=choice.effect
    if major[effect]then
      local prior=statusScopes[b];statusScopes[b]=ctx
      local out=pack(pcall(ctx.inflict,t,effect,{source=ctx.move.id,moveType=ctx.move.type,
        secondary=true,kascStatusSource67=u}));statusScopes[b]=prior
      if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
    elseif effect=='confusion'then
      -- Reuse the native PRIMARY application after this Card's single
      -- 30% roll: no additional secondary roll or raw volatile assignment.
      return b.data.move_effects.CONFUSION_EFFECT.run(ctx)
    elseif effect=='flinch'then
      if not(b._kascFlinchActed67 and b._kascFlinchActed67[t])and not A.blocksFlinch(b,t)then t.flinched=true end
      return{}
    end
    return assert(opts.split).changeStage(ctx,t,effect,-1,true)
  end
  function M.damageScope(original,b,ctx,effect,...)
    if not b or not M.epoch(b,ctx.user,ctx.move)or not side(b,ctx.user)or not side(b,ctx.target)
      or ctx.user==ctx.target or not index(b,ctx.user)or not index(b,ctx.target)then return original(b,ctx,effect,...)end
    local prior=hits[b];hits[b]={user=ctx.user,target=ctx.target,move=ctx.move,seen=setmetatable({},{__mode='k'})}
    local out=pack(pcall(original,b,ctx,effect,...));hits[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.context(original,b,u,t,...)
    local ctx=original(b,u,t,...);local f=frames[b]
    if f and f.user==u and f.target==t and same(f.move,ctx.move)and M.epoch(b,u,ctx.move)then
      if not state(b)then local kind=M.environment(b);local r=state(b,true);r.kind=kind;r.map=mapId(b);r.profile=mode(b)end
    end;return ctx
  end
  function M.perform(original,b,u,t,inst,called,...)
    local move=inst and b:moveDef(inst)
    if not M.epoch(b,u,move)or not live(u)or not side(b,u)or not index(b,u)then return original(b,u,t,inst,called,...)end
    local prior=frames[b];frames[b]={user=u,target=t,move=move}
    local out=pack(pcall(original,b,u,t,inst,called,...));frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    if frames[b]or hits[b]or statusScopes[b]then return false,'secret_power_unsettled'end
    local r=state(b);if r==nil then return true end
    local gen=mode(b);local frozen=b.field.tokens['kasc.generation-receipt/v1']
    if not gen and type(frozen)=='table'and int(frozen.activeEpoch,1,7)
      and(frozen.mode=='auto'or frozen.mode=='gen'..frozen.activeEpoch)then gen=frozen.activeEpoch end
    if type(r)~='table'or not environments[r.kind]or not gen or r.profile~=gen or r.map~=mapId(b)then return false,'invalid_secret_power_environment'end
    for k in pairs(r)do if k~='kind'and k~='map'and k~='profile'then return false,'unknown_secret_power_field'end end;return true
  end
  function M.resume(b)local ok,err=M.validateCheckpoint(b);assert(ok,err);return true end
  local fact=assert(opts.facts.move('SECRET_POWER',7));local old=assert(mod.content.moves:get('SECRET_POWER'))
  assert(fact.number==290 and fact.generation==3 and fact.power==70 and fact.pp==20 and fact.accuracy==100
    and fact.category=='physical'and fact.type=='NORMAL'and fact.priority==0,'Secret Power source drift')
  assert(not old.backendMoveOwner and old.effect=='NO_ADDITIONAL_EFFECT','foreign Secret Power owner')
  local effect='KA_SECRET_POWER_67'
  mod.content.move_effects:register(effect,{kind='secondary',run=M.secondary,kascSecretPower67=M.OWNER})
  for native in pairs(aliases)do if mod.content.moves:get(native)then mod.content.moves:patch(native,{effect=effect,
    flags={protect=1,mirror=1,metronome=1},backendMoveOwner=M.OWNER,backendMoveNumber=290,
    originGeneration=3,backendLearnsetRevision=old.backendLearnsetRevision or 1})end end
  local animation=copy(assert(mod.content.battle_anims:get('BODY_SLAM'),'missing established Secret Power impact'))
  animation.source=M.OWNER;mod.content.battle_anims:patch('SECRET_POWER',animation)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSecretPower67=M.OWNER})
  function M.position(p,id)
    if not aliases[id]or not p.data.moveAnims[id]or p.data.moveAnims[id].source~=M.OWNER then return end
    local hud=assert(mod.exports.pokemonPartnerHits67)
    for _,step in ipairs(p.steps or{})do for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or hud.inHud(q))then q.x=0 end;step.sprites[i]=q end end
  end
  function M.install()
    B._kascSecretPower67=M;FX._kascSecretPower67=M;Player._kascSecretPower67=M
    if not B._kascSecretPowerWrapped67 then local old=B.performMove
      B.performMove=function(...)return B._kascSecretPower67.perform(old,...)end;B._kascSecretPowerWrapped67=true end
    if not FX._kascSecretPowerContextWrapped67 then local old=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascSecretPower67.context(old,...)end;FX._kascSecretPowerContextWrapped67=true end
    if not FX._kascSecretPowerDamageWrapped67 then local old=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascSecretPower67.damageScope(old,...)end;FX._kascSecretPowerDamageWrapped67=true end
    if not Player._kascSecretPowerWrapped67 then local old=Player.start
      Player.start=function(self,id,...)local out=pack(old(self,id,...));Player._kascSecretPower67.position(self,id);return unpack(out,1,out.n)end
      Player._kascSecretPowerWrapped67=true end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='authored-environment-native-private-body-hit',providerStatus='era-specific-secret-power-secondary',
    buildReceiptId='docs/SECRET_POWER_67.md',rollbackReceiptId='docs/SECRET_POWER_67.md'})end
  return M
end
