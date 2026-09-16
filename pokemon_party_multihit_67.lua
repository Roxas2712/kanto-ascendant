-- Beat Up and Triple Kick use actual per-strike native FX, not another
-- move/action. Party contributors are identity/stat inputs, never attackers.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-PARTY-MULTIHIT',OWNER='kasc.party-multihit/v1'}
  local definitions={BEAT_UP={number=251},TRIPLE_KICK={number=167}}
  local aliases,frames={},setmetatable({},{__mode='k'})
  local tr=opts.i18n.text
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
  local function monLiving(p)
    return p and type(p.hp)=='number'and p.hp>0 and not(p.isEgg or p.egg or p.is_egg
      or p.eggSpecies or p.species=='EGG'or p.species=='POKEMON_EGG'or p.status=='EGG')
  end
  local function living(w)return w and not w.fainted and monLiving(w.mon)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function party(b,w)
    if w==b.player then return b:playerPartyView()end
    if w==b.enemy then return b.kind=='wild'and{w.mon}or b.enemyParty end
  end
  local function belongs(b,w)
    for i,p in ipairs(party(b,w)or{})do if i<=6 and p==w.mon then return true end end
    return false
  end
  function M.epoch(b,w,move)
    local r=b and b.kascGenerationRulesReceipt;local id=move and(aliases[move.id]or move.id)
    local rec=move and b and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or not integer(r.activeEpoch,1,7)or not definitions[id]or move.backendMoveOwner~=M.OWNER
        or not rec or rec.kascPartyMultihit67~=M.OWNER then return end
    if r.activeEpoch<2 and not(living(w)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species]))then return end
    return math.max(2,r.activeEpoch),id
  end
  local function base(b,p,gen,active,current)
    local species=p.species
    if current and active and opts.identity then species=opts.identity.current(b,active)or species end
    local key=opts.species.bySpecies[species]
    local facts=key and opts.facts.baseStats(key,gen)
    if facts then return facts.atk,facts.def end
    -- A custom species such as Gorochu has no canonical substitute. Its
    -- authored original base values stay its own, including ABI slot >251.
    local def=b.data.pokemon[species];local stats=def and def.baseStats
    return stats and stats.attack,stats and stats.defense
  end
  function M.contributors(b,w,gen)
    local members={};if not living(w)or not belongs(b,w)then return members end
    for i,p in ipairs(party(b,w)or{})do
      if i>6 then break end
      -- V+ explicitly includes the active user even with a status. The
      -- older games require every contributor, including user, status-free.
      if monLiving(p)and((gen>=5 and p==w.mon)or p.status==nil or p.status=='')then
        local attack=base(b,p,gen,p==w.mon and w or nil,gen==2)
        if integer(attack,1,9999)and integer(p.level,1,100)then
          members[#members+1]={mon=p,index=i,attack=attack,level=p.level,species=p.species}
        end
      end
    end
    return members
  end
  function M.profile(b,ctx)
    local u,t,m=ctx and ctx.user,ctx and ctx.target,ctx and ctx.move
    local gen,id=M.epoch(b,u,m)
    if not gen or not living(u)or not living(t)or u==t or not side(b,u)or not side(b,t)
        or side(b,u)==side(b,t)or not belongs(b,u)then return end
    return gen,id
  end
  function M.project(b,w,move,hit,members)
    local gen,id=M.epoch(b,w,move)
    if not gen or not living(w)or not side(b,w)or not belongs(b,w)then return move end
    local frame=frames[b]
    if frame and frame.user==w and frame.id==id then
      hit,members=frame.hit,frame.members
    end
    hit=hit or 1
    if not integer(hit,1,id=='TRIPLE_KICK'and 3 or 6)then return move end
    members=members or(id=='BEAT_UP'and M.contributors(b,w,gen)or nil)
    local member=members and members[hit]
    if id=='BEAT_UP'and not member then return move end
    local out=copy(move)
    out.multiHit=true;out.multihit=nil;out.multiaccuracy=nil
    out.backendMoveNumber=definitions[id].number
    out.kascPartyStrike67=M.OWNER;out.kascPartyHit67=hit
    if id=='TRIPLE_KICK'then
      out.power=10*hit;out.category='physical';out.accuracy=90
    elseif gen<=4 then
      out.power=10;out.type='???';out.category=gen<=3 and'special'or'physical'
      -- Earlier Beat Up is deliberately typeless, even under IV Normalize.
      -- This is NOT opts.typeless (confusion, which skips damage variance).
      out.kascConverted67=M.OWNER;out.kascConversionPower67=nil;out.kascIonDeluge67=nil
    else out.power=5+math.floor(member.attack/10);out.category='physical'end
    return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local gen,id=M.profile(ctx.battle,ctx);if not gen then return nextDamage(ctx)end
    local f=frames[ctx.battle]
    local members=f and f.user.mon==ctx.user.mon and f.target.mon==ctx.target.mon and f.members
      or id=='BEAT_UP'and M.contributors(ctx.battle,ctx.user,gen)
    local hit=f and f.user.mon==ctx.user.mon and f.target.mon==ctx.target.mon and f.hit or 1
    -- Damage hooks can carry detached ability/stat views. They share the
    -- exact native mon objects; project with the original bound battler.
    local user=f and f.user or ctx.user
    local out=copy(ctx);out.move=M.project(ctx.battle,user,ctx.move,hit,members)
    if id=='BEAT_UP'and not(members and members[hit])then
      return 0,{crit=false,typeMult=10,missed=true}
    end
    if id=='BEAT_UP'and gen<=4 then
      local member=members[hit]
      local _,defense=base(ctx.battle,ctx.target.mon,gen,ctx.target,gen==2)
      if not integer(defense,1,9999)then return 0,{crit=false,typeMult=10,missed=true}end
      out.opts=copy(ctx.opts)
      -- A narrow exact-math owner seam resets ALL stat modifiers just
      -- before the formula. III/IV damage-stage burn/screens remain intact.
      out.opts.kascBeatUpBase67={attack=member.attack,defense=defense,
        level=gen==2 and member.level or ctx.user.mon.level}
    end
    return nextDamage(out)
  end
  function M.gate(ctx)
    local gen,id=M.profile(ctx.battle,ctx)
    if gen and(id~='BEAT_UP'or #M.contributors(ctx.battle,ctx.user,gen)>0)then return true end
    return false,tr('But, it failed!','Doch es schlug fehl!')
  end
  function M.noUseful(b,u,t,move)
    local gen,id=M.profile(b,{user=u,target=t,move=move})
    return gen and id=='BEAT_UP'and #M.contributors(b,u,gen)==0 or false
  end
  function M.validateCheckpoint(b)return frames[b]==nil,'unsettled_party_multihit'end
  function M.run(original,b,ctx,record)
    if frames[b]then return original(b,ctx,record)end
    local gen,id=M.profile(b,ctx)
    if not gen then return original(b,ctx,record)end
    local members=id=='BEAT_UP'and M.contributors(b,ctx.user,gen)
    if members and #members==0 then return original(b,ctx,record)end
    local frame={gen=gen,id=id,user=ctx.user,target=ctx.target,hit=1,members=members}
    frames[b]=frame
    local count=id=='BEAT_UP'and #members or gen>=3 and 3 or nil
    local perAccuracy=id=='TRIPLE_KICK'and gen>=3
      and not(opts.abilities and opts.abilities.activeAbility(b,ctx.user)=='SKILL_LINK')
    local rawAccuracy,accuracy=rawget(b,'accuracyRoll'),b.accuracyRoll
    local rawFaint,faint=rawget(b,'onFaint'),b.onFaint
    local priorAnim=b.moveAnimRow;local firstAccuracy=true
    local pending,seen={},{}
    b.accuracyRoll=function(self,move,u,t)
      if u~=ctx.user or t~=ctx.target or not move or move.id~=ctx.move.id
          or move.kascPartyStrike67~=M.OWNER then return accuracy(self,move,u,t)end
      if not firstAccuracy then return true end
      firstAccuracy=false
      local hit=accuracy(self,move,u,t)
      if hit and not count then count=b.rng(1,3)end
      return hit
    end
    b.onFaint=function(self,w)
      if w~=ctx.user and w~=ctx.target then return faint(self,w)end
      if not seen[w]then seen[w]=true;pending[#pending+1]=w end
    end
    local startedAsleep=ctx.user.mon.status=='SLP'
    local total,landed,broke=0,0,false
    local function execute()
      local hit=1
      while hit<=(count or 1)do
        if not living(ctx.user)or not living(ctx.target)or b.result then break end
        if hit>1 and ctx.user.mon.status=='SLP'
            and not(startedAsleep and ctx.isCalled and gen~=4)then break end
        frame.hit=hit
        local move=M.project(b,ctx.user,ctx.move,hit,members)
        -- III+ Triple Kick's later accuracy failure quietly ends the
        -- existing move; it is not another native missed whole action.
        if hit>1 and perAccuracy and not accuracy(b,move,ctx.user,ctx.target)then break end
        if hit>1 then b.moveAnimRow=b:animNext(move.id,ctx.user.isPlayer)end
        local selected=copy(record);selected.hitCount=function()return 1 end
        if hit>1 then selected.beforeAccuracy=nil end
        local single=FX.makeCtx(b,ctx.user,ctx.target,move,ctx.moveInst,ctx.isCalled)
        original(b,single,selected)
        if single.totalDealt==nil then break end
        total=total+single.totalDealt;landed=landed+1;broke=broke or single.brokeSub
        ctx.rawDamage,ctx.hitSfx=single.rawDamage,single.hitSfx
        if hit<(count or 1)and living(ctx.user)and living(ctx.target)then
          local berries=opts.berries or mod.exports and mod.exports.pokemonModernBerries67
          if berries then berries.apply(b,true,ctx.target);berries.apply(b,true,ctx.user)end
          local forms=mod.exports and mod.exports.pokemonHPForms67
          if forms then forms.watch(b)end
        end
        hit=hit+1
      end
      ctx.hits,ctx.totalDealt,ctx.brokeSub=landed,landed>0 and total or nil,broke
      if landed>1 then b:sayNext(b:romText(ctx.user.isPlayer and'_MultiHitText'or'_HitXTimesText',
        ctx.user.isPlayer and'Hit the enemy\n%d times!'or'Hit %d times!',landed))end
    end
    local out=pack(pcall(execute))
    b.accuracyRoll=rawAccuracy;b.onFaint=rawFaint;b.moveAnimRow=priorAnim;frames[b]=nil
    if not out[1]then error(out[2],0)end
    for _,w in ipairs(pending)do faint(b,w)end
    return unpack(out,2,out.n)
  end
  for id,d in pairs(definitions)do
    for _,native in ipairs(opts.species.moveIds(id))do
      local prior=assert(mod.content.moves:get(native),'missing party multi-hit '..native)
      assert(not prior.backendMoveOwner,'foreign party multi-hit '..native)
      aliases[native]=id
      local effect='KA_PARTY_MULTIHIT_67_'..native
      mod.content.move_effects:register(effect,{kind='full',gate=M.gate,kascPartyMultihit67=M.OWNER})
      local fact=assert(opts.facts.move(id,4));assert(fact.number==d.number and fact.generation==2)
      mod.content.moves:patch(native,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=prior.backendLearnsetRevision or 1,multiHit=1,pp=10,
        contact=id=='TRIPLE_KICK',flags=copy(opts.facts.data.moves[id].flags)})
      assert(mod.content.battle_anims:get(native),'missing existing party multi-hit animation '..native)
    end
  end
  function M.install()
    FX._kascPartyMultihit67=M
    if FX._kascPartyMultihitWrapped67 then return end
    local damaging,makeCtx=FX.runDamaging,FX.makeCtx
    FX.runDamaging=function(...)return FX._kascPartyMultihit67.run(damaging,...)end
    FX.makeCtx=function(b,u,t,...)
      local ctx=makeCtx(b,u,t,...);ctx.move=FX._kascPartyMultihit67.project(b,u,ctx.move);return ctx
    end
    FX._kascPartyMultihitWrapped67=true
  end
  mod.hooks:wrap('battle.damage',M.damage,47000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-single-strike-FX-and-historical-base-stat-math',
      providerStatus='gen2-7-beat-up-triple-kick-explicit-backwards-gifts',
      buildReceiptId='docs/PARTY_MULTIHIT_67.md',rollbackReceiptId='docs/PARTY_MULTIHIT_67.md'})
  end
  return M
end
