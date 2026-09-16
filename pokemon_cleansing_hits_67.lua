-- Gen-VII hit effects: target burn cure, whole-field stage reset, party cure.
-- These are three different effects, not aliases for Gen-I Haze or Rest.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-CLEANSING-HITS',OWNER='kasc.cleansing-hits/v1'}
  local tr=opts.i18n.text
  local specs={SPARKLING_ARIA={number=664,type='WATER',pp=10,target=9,parts={'BUBBLEBEAM','SING'}},
    FREEZY_FROST={number=739,type='ICE',pp=15,target=10,parts={'ICE_BEAM'}},
    SPARKLY_SWIRL={number=740,type='FAIRY',pp=15,target=10,parts={'PSYBEAM','RECOVER'}}}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and r.activeEpoch>=1 and r.activeEpoch<=7 then return r.activeEpoch end
  end
  function M.cure(b,who)
    if not who or not who.mon or who.mon.hp<=0 or not who.mon.status then return false end
    who.mon.status=nil;who.toxicCounter=nil
    mod.exports.pokemonStatusLifecycle67.clear(who,b)
    return true
  end
  function M.afterHit(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move
    if not M.epoch(b)or not specs[m.id]or m.backendMoveOwner~=M.OWNER then return end
    local A=mod.exports.pokemonAbilityEffects67
    if m.id=='SPARKLING_ARIA'then
      -- Singles: Shield Dust blocks this secondary; Sheer Force suppresses
      -- it and boosts damage. Sound bypasses Substitute through runDamaging.
      if u.mon.hp>0 and t.mon.hp>0 and t.mon.status=='BRN'
          and not t.substituteHP and not ctx.brokeSub and A.secondaryChance(ctx,100)>0 then
        M.cure(b,t);b:sayNext(tr('%s\'s burn was healed!','%s\' Verbrennung wurde geheilt!'):format(t.name))
      end
    elseif m.id=='FREEZY_FROST'then
      if t.substituteHP or ctx.brokeSub then return end
      -- Not Gen-I Haze: retain major status, counters, screens, Focus Energy,
      -- volatile effects and raw stats. Clear only actual stage modifiers.
      for _,who in ipairs({b.player,b.enemy})do who.stages={}end
      b:sayNext(tr('All stat changes were eliminated!','Alle Statusstufen wurden aufgehoben!'))
    elseif u.mon.hp>0 then
      -- A self-side hit effect, also on KO or a hit into Substitute. Neither
      -- Soundproof nor Shield Dust blocks it; reserves never take damage.
      local party=u==b.player and b.game.save.party or b.enemyParty
      local seen={[u.mon]=true};local healed=M.cure(b,u)
      for _,mon in ipairs(party or{})do
        if not seen[mon]then seen[mon]=true;healed=M.cure(b,{mon=mon})or healed end
      end
      if healed then b:sayNext(tr('The team\'s status was cured!','Die Statusprobleme des Teams wurden geheilt!'))end
    end
  end
  function M.runDamaging(original,b,ctx,record)
    local m=ctx and ctx.move;local target=ctx and ctx.target
    if not M.epoch(b)or not m or m.id~='SPARKLING_ARIA'or m.backendMoveOwner~=M.OWNER
        or not target or not target.substituteHP then return original(b,ctx,record)end
    local sub=target.substituteHP;target.substituteHP=nil
    local result=pack(pcall(original,b,ctx,record))
    if target.mon.hp>0 then target.substituteHP=sub end
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  Effects._kascCleansingHits67=M
  if not Effects._kascCleansingHitsWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(...)return Effects._kascCleansingHits67.runDamaging(original,...)end
    Effects._kascCleansingHitsWrapped67=true
  end
  for _,id in ipairs({'SPARKLING_ARIA','FREEZY_FROST','SPARKLY_SWIRL'})do
    local s=specs[id];local f=assert(opts.facts.move(id,7))
    assert(f.number==s.number and f.type==s.type and f.power==90 and f.accuracy==100
      and f.pp==s.pp and f.category=='special'and f.target==s.target and f.priority==0,'cleansing source drift '..id)
    assert(not mod.content.moves:get(id),'foreign cleansing owner '..id)
    local effect='KA_CLEANSING_HITS_67_'..id
    mod.content.move_effects:register(effect,{kind='full',afterDamage=M.afterHit,kascCleansingHits67=M.OWNER})
    mod.content.moves:register(id,{id=id,name=tr(f.names.en,f.names.de),type=f.type,category=f.category,
      power=90,accuracy=100,pp=f.pp,priority=0,contact=false,target=f.target,sound=id=='SPARKLING_ARIA',
      effect=effect,originGeneration=7,backendMoveNumber=f.number,backendMoveOwner=M.OWNER,
      backendLearnsetRevision=22,anim=copy(assert(mod.content.moves:get(s.parts[1])).anim)})
    local anim={seq={},source=M.OWNER}
    for _,part in ipairs(s.parts)do
      for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(step)end
    end
    mod.content.battle_anims:register(id,anim)
  end
  -- Opponent projectiles and the player's late ice crystals cross the lower
  -- name card. Move only their visible effect OAM, never battler art
  -- or the source Bubblebeam/Ice Beam/Psybeam/healing animations.
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id,playerSide)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if playerSide and id~='FREEZY_FROST'or not specs[id]or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do
      local sprites={}
      for i,s in ipairs(step.sprites or{})do
        local moved=copy(s)
        if s.x>0 and s.x<168 and s.y>=16 and s.y<144 then moved.y=s.y-16 end
        sprites[i]=moved
      end
      step.sprites=sprites
    end
  end
  Player._kascCleansingHitsAnimation67=M
  if not Player._kascCleansingHitsAnimationWrapped67 then
    local start=Player.start
    Player.start=function(self,id,playerSide,...)
      local result=start(self,id,playerSide,...)
      Player._kascCleansingHitsAnimation67.position(self,id,playerSide)
      return result
    end
    Player._kascCleansingHitsAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-hit-status-and-stage-owners',
      providerStatus='generation-seven-cleansing-effects',buildReceiptId='docs/CLEANSING_HITS_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
