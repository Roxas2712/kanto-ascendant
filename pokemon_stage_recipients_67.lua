-- Four distinct recipient rules, not generic changes to ctx.target.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-STAGE-RECIPIENTS',OWNER='kasc.stage-recipients/v1'}
  local tr=opts.i18n.text
  local defs={ACUPRESSURE={number=367,generation=4,target=5,type='NORMAL',pp=30},
    ROTOTILLER={number=563,generation=6,target=14,type='GROUND',pp=10},
    FLOWER_SHIELD={number=579,generation=6,target=14,type='FAIRY',pp=10},
    MAGNETIC_FLUX={number=602,generation=6,target=13,type='ELECTRIC',pp=20}}
  local order={'ACUPRESSURE','ROTOTILLER','FLOWER_SHIELD','MAGNETIC_FLUX'}
  local aliases={}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local p=w and w.mon;return p and integer(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function side(b,w)return w==b.player and 1 or w==b.enemy and 2 or nil end
  local function actual(b,w)
    local s=side(b,w);if not s or not live(w)then return false end
    local party=s==1 and b:playerPartyView()or b.enemyParty or{b.enemy.mon}
    local found=false;for i,p in ipairs(party)do if i<=6 and p==w.mon then found=true;break end end
    if not found then return false end
    for _,a in ipairs(b.sides and b.sides[s]and b.sides[s].battlers or{})do if a==w then return true end end
    return false
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function stage(w,key)local v=w.stages and w.stages[key]or 0;return integer(v,-6,6)and v or nil end
  local function grass(w)for _,t in ipairs(w.curTypes or{})do if t=='GRASS'then return true end end;return false end
  function M.epoch(b,m,u)
    local r=b and b.kascGenerationRulesReceipt;local id=m and aliases[m.id];local d=id and defs[id]
    local e=d and b and b.data and b.data.move_effects and b.data.move_effects[m.effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or not integer(r.activeEpoch,1,7)or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not d or not actual(b,u)
        or m.backendMoveOwner~=M.OWNER or m.backendMoveNumber~=d.number
        or m.category~='status'or m.power~=0 or m.target~=d.target
        or not e or e.kascStageRecipients67~=M.OWNER then return end
    if r.activeEpoch<d.generation and not(opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species])
        and opts.rules.monMoveAvailable(b.game,u.mon,m.id,r.activeEpoch,true))then return end
    return r.activeEpoch,id
  end
  -- Raw I/II still have Flying immunity, but neither Levitate nor future
  -- held effects are silently activated by an authenticated future move.
  local function airborne(b,w,gen)
    local g=mod.exports.pokemonGrounding67
    if not g then return nil end
    if gen>=3 then
      if not g.epoch(b)then return nil end
      return not not g.airborne(b,w)
    end
    if g.grounded(b,w)then return false end
    for _,t in ipairs(w.curTypes or{})do if t=='FLYING'then return true end end
    return false
  end
  local function keys(gen,id)
    if id=='ACUPRESSURE'then
      if gen==1 then return{'attack','defense','speed','special','accuracy','evasion'}end
      return{'attack','defense','speed','specialAttack','specialDefense','accuracy','evasion'}
    end
    if id=='ROTOTILLER'then return{'attack',gen==1 and'special'or'specialAttack'}end
    if id=='MAGNETIC_FLUX'then return{'defense',gen==1 and'special'or'specialDefense'}end
    return{'defense'}
  end
  function M.plan(b,u,t,m)
    local gen,id=M.epoch(b,m,u);if not gen then return end
    local priority=mod.exports.pokemonPriorityAbilities67
    if priority and priority.blocks({battle=b,user=u,target=t,move=m})then return end
    local p={id=id,epoch=gen,targets={},airborne={}}
    if id=='ACUPRESSURE'then
      -- This host is singles: the real adjacentAllyOrSelf choice is self,
      -- never the enemy passed to native performMove as ctx.target.
      if math.max(gen,4)==4 and(u.substituteHP or 0)>0 then return end
      p.eligible={}
      for _,key in ipairs(keys(gen,id))do local n=stage(u,key);if n==nil then return end
        if n<6 then p.eligible[#p.eligible+1]=key end
      end
      if #p.eligible==0 then return end
      p.targets[1]={who=u,keys=p.eligible,delta=2};return p
    end
    for _,w in ipairs({b.player,b.enemy})do if actual(b,w)then
      local eligible=false
      if id=='MAGNETIC_FLUX'then
        local a=mod.exports.pokemonAbilityEffects67
        local plus=mod.exports.pokemonPlusMinus67
        if not a or not plus or gen>=3 and not plus.epoch(b)then return end
        local ab=a.activeAbility(b,w)
        eligible=side(b,w)==side(b,u)and(ab=='PLUS'or ab=='MINUS')
      elseif id=='FLOWER_SHIELD'then eligible=grass(w)
      else
        local air=airborne(b,w,gen);if air==nil then return end
        if air then p.airborne[#p.airborne+1]=w else eligible=grass(w)end
      end
      if eligible then
        local ks=keys(gen,id);for _,key in ipairs(ks)do if stage(w,key)==nil then return end end
        p.targets[#p.targets+1]={who=w,keys=ks,delta=1}
      end
    end end
    if #p.targets==0 and not(id=='ROTOTILLER'and#p.airborne>0)then return end
    return p
  end
  local function predicted(b,w,key,delta)
    local old=stage(w,key);if old==nil then return end
    local a=mod.exports.pokemonAbilityEffects67
    delta=a and a.stageDelta(b,w,delta)or delta
    return math.max(-6,math.min(6,old+delta))-old
  end
  function M.noUseful(b,u,t,m)
    if not M.epoch(b,m,u)then return false end
    local function inspect()
      local p=M.plan(b,u,t,m);if not p then return true end
      for _,row in ipairs(p.targets)do for _,key in ipairs(row.keys)do
        local d=predicted(b,row.who,key,row.delta)
        if d and(row.who==u and d>0 or side(b,row.who)~=side(b,u)and d<0)then return false end
      end end
      return true
    end
    local a=mod.exports.pokemonAbilityEffects67
    if a then return a.moveScope(b,u,t,true,inspect,m)end
    return inspect()
  end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move
    local p=M.plan(b,u,t,m);local split=mod.exports.backendSplitSpecial67
    if not p or not split or type(ctx.changeStage)~='function'then return failed()end
    local messages,changed={},false
    local function boost(w,key,delta)
      local old=stage(w,key);local result=split.changeStage(ctx,w,key,delta,false)
      if stage(w,key)~=old then changed=true;for _,line in ipairs(result or{})do messages[#messages+1]=line end end
    end
    if p.id=='ACUPRESSURE'then
      local i=ctx.rng(1,#p.eligible)
      if not integer(i,1,#p.eligible)then return failed()end
      boost(u,p.eligible[i],2)
    else for _,row in ipairs(p.targets)do for _,key in ipairs(row.keys)do boost(row.who,key,row.delta)end end end
    if p.id=='ROTOTILLER'then
      -- Canonical onHitField emits Ground-immunity feedback and succeeds
      -- even with only airborne actors, or with every Grass stat capped.
      for _,w in ipairs(p.airborne)do messages[#messages+1]=tr('%s is immune to the tilling!','%s bleibt vom Pflügen unberührt!')
        :format(ctx.displayName and ctx.displayName(w)or w.name or w.mon.species)end
      if #messages==0 then messages[1]=tr('The ground was tilled!','Der Boden wurde gepflügt!')end
      return messages
    end
    return changed and messages or failed()
  end
  -- All owned state is ordinary native stages; no journal or field token,
  -- party edit, AP refund, second action or checkpoint continuation exists.
  function M.validateCheckpoint(b)
    for _,w in ipairs({b.player,b.enemy})do for _,v in pairs(w and w.stages or{})do
      if not integer(v,-6,6)then return false,'invalid_stage_recipient_stage'end
    end end;return true
  end
  for _,id in ipairs(order)do
    local d=defs[id];local f=assert(opts.facts.move(id,7));local ids=opts.species.moveIds(id)
    assert(f.number==d.number and f.generation==d.generation and f.type==d.type and f.target==d.target
      and f.category=='status'and f.power==0 and f.pp==d.pp and f.accuracy==100 and f.alwaysHits
      and f.priority==0,'stage recipient source drift '..id)
    local effect='KA_STAGE_RECIPIENTS_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=M.cast,kascStageRecipients67=M.OWNER})
    local flags={metronome=1}
    if id~='ACUPRESSURE'then flags.distance=1 end
    if id=='MAGNETIC_FLUX'then flags.snatch=1;flags.bypasssub=1 end
    if id=='ROTOTILLER'then flags.nonsky=1 end
    for _,key in ipairs(ids)do
      local old=assert(mod.content.moves:get(key));assert(not old.backendMoveOwner,'foreign stage recipient owner '..key)
      assert(old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id or old.effect=='KA_GEN_MOVE_STAT_'..id,
        'unexpected generic stage recipient '..key)
      aliases[key]=id
      mod.content.moves:patch(key,{effect=effect,power=0,pp=d.pp,accuracy=100,priority=0,type=d.type,category='status',
        target=d.target,flags=copy(flags),kascBypassSub67=true,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        originGeneration=d.generation,backendLearnsetRevision=old.backendLearnsetRevision or 1,
        anim=copy(assert(mod.content.moves:get('FOCUS_ENERGY')).anim)})
      local animation=copy(assert(mod.content.battle_anims:get('FOCUS_ENERGY')));animation.source=M.OWNER
      if mod.content.battle_anims:get(key)then mod.content.battle_anims:patch(key,animation)
      else mod.content.battle_anims:register(key,animation)end
    end
    assert(#ids>0,'missing existing stage recipient '..id)
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-singles-stages-types-grounding-and-effective-ability',
    providerStatus='four-source-correct-stage-recipient-rules',buildReceiptId='docs/STAGE_RECIPIENTS_67.md',
    rollbackReceiptId='docs/STAGE_RECIPIENTS_67.md'})end
  return M
end
