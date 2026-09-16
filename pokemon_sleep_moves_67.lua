-- Native Snore/Sleep Talk execution, separate from catalog availability.
-- Reviewed against Showdown 6b4bc34e44cc2541929cc4b8fff96e756ab3f268:
-- data/moves.ts and mods/gen{2,3,4,5}/moves.ts / gen3/conditions.ts.
return function(mod,opts)
  local M={CARD_ID='KASC-67-SLEEP-MOVES',OWNER='kasc.sleep-moves/v1'}
  local Battle=require('src.battle.BattleState')
  local nested=setmetatable({},{__mode='k'})
  local aliases={}
  for id in pairs(opts.facts.data.moves)do
    for _,native in ipairs(opts.species.moveIds(id))do aliases[native]=id end
  end
  local function pack(...)return {n=select('#',...),...}end
  local function failed()return opts.i18n.text('But, it failed!','Doch es schlug fehl!')end
  function M.epoch(b)
    local gen=opts.lifecycle.epoch(b)
    if gen and gen>=2 and gen<=7 then return gen end
  end
  function M.sleepUsable(b,id)
    local move=b and b.data and b.data.moves[id]
    local effect=move and b.data.move_effects[move.effect]
    return M.epoch(b)~=nil and (id=='SNORE' or id=='SLEEP_TALK')
      and effect and effect.kascSleepMoves67==M.OWNER or false
  end
  -- These restrictions are move-call rules, not the TM/learnset policy.
  -- II permits Mirror Move; II-IV permit Mimic/Sketch/Bide/Struggle.
  local excluded={SLEEP_TALK=2,METRONOME=3,MIRROR_MOVE=3,ASSIST=3,
    FOCUS_PUNCH=3,UPROAR=3,CHATTER=4,COPYCAT=4,ME_FIRST=4,
    MIMIC=5,SKETCH=5,BIDE=5,STRUGGLE=5,NATURE_POWER=5,
    BELCH=6,CELEBRATE=6,HOLD_HANDS=6,BEAK_BLAST=7,SHELL_TRAP=7}
  local charge={FLY=true,DIG=true,DIVE=true,BOUNCE=true,RAZOR_WIND=true,
    SKULL_BASH=true,SKY_ATTACK=true,SOLAR_BEAM=true,SHADOW_FORCE=true,
    SKY_DROP=true,FREEZE_SHOCK=true,ICE_BURN=true,GEOMANCY=true,
    PHANTOM_FORCE=true,SOLAR_BLADE=true}
  function M.candidates(b,user)
    local gen=M.epoch(b);local out={}
    if not gen then return out end
    for _,slot in ipairs(user.curMoves or {})do
      local id=aliases[slot.id] or slot.id
      local move=b.data.moves[slot.id]
      local effect=move and b.data.move_effects[move.effect]
      if move and not charge[id] and not (effect and effect.charge)
          and not (excluded[id] and gen>=excluded[id]) and not move.isZ and not move.isMax then
        out[#out+1]=slot
      end
    end
    return out
  end
  function M.call(ctx)
    if not M.sleepUsable(ctx.battle,'SLEEP_TALK') or not opts.abilities.isAsleep(ctx.battle,ctx.user) then
      ctx.say(failed());return nil
    end
    local choices=M.candidates(ctx.battle,ctx.user)
    if #choices==0 then ctx.say(failed());return nil end
    local selected=choices[ctx.rng(1,#choices)]
    -- ADV samples zero-PP slots, then fails. Filtering them beforehand
    -- would change the distribution; all other scoped eras can call them.
    if M.epoch(ctx.battle)==3 and (tonumber(selected.pp) or 0)<=0 then
      ctx.say(opts.i18n.text('The chosen move has no PP left!',
        'Die gewählte Attacke hat keine AP mehr!'));return nil
    end
    return selected.id
  end
  function M.perform(original,b,user,target,inst,isCalled)
    local id=inst and inst.id;local gen=M.epoch(b)
    if not gen or not M.sleepUsable(b,id) then return original(b,user,target,inst,isCalled)end
    local talk=id=='SLEEP_TALK'
    local prior=nested[user]
    -- Gen-II Mirror Move/Metronome can indirectly call Sleep Talk again.
    -- Refuse a cycle in this call stack, not a later turn or another user.
    if talk and prior then b:sayNext(failed());return end
    if talk then nested[user]=true end
    -- Sound moves bypass substitutes from VI. Only the synchronous Snore
    -- pipeline sees this; misses/errors restore the original substitute.
    local sub=id=='SNORE' and opts.abilities.isAsleep(b,user) and gen>=6 and target.substituteHP
    if sub then target.substituteHP=nil end
    local result=pack(pcall(original,b,user,target,inst,isCalled))
    if sub and target.mon.hp>0 then target.substituteHP=sub end
    if talk then nested[user]=prior end
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  local snore=mod.content.moves:get('SNORE')
  local talk=mod.content.moves:get('SLEEP_TALK')
  -- Upgrade only KASC's previous plain-damage/unsupported projections.
  -- A different provider's effect is not ours to replace.
  if not snore or not talk or snore.backendMoveOwner or talk.backendMoveOwner
      or (snore.effect~='NO_ADDITIONAL_EFFECT' and snore.effect~='FLINCH_SIDE_EFFECT2')
      or talk.effect~='KA_GEN_MOVE_UNSUPPORTED_SLEEP_TALK' then
    M.pending='missing-or-foreign-move-owner';return M
  end
  local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  -- Native sound pulses / sleeping + move-call gesture. Borrow the visual
  -- primitives only, never the source move's gameplay effect or status.
  local anims=mod.content.battle_anims
  local compositions={SNORE={'SING'},SLEEP_TALK={'REST','METRONOME'}}
  local prepared={}
  for id,parts in pairs(compositions)do
    local animation={seq={}}
    for _,part in ipairs(parts)do
      local row=anims and anims:get(part)
      if not row or not row.seq or #row.seq==0 then
        M.pending='missing-native-animation:'..part;return M
      end
      for _,step in ipairs(row.seq)do animation.seq[#animation.seq+1]=copy(step)end
    end
    prepared[id]=animation
  end
  local previous=assert(mod.content.move_effects:get(snore.effect))
  local flinch=assert(mod.content.move_effects:get('FLINCH_SIDE_EFFECT2'))
  local snoreEffect={kind='secondary',kascSleepMoves67=M.OWNER,
    gate=function(ctx)
      if M.epoch(ctx.battle)then return opts.abilities.isAsleep(ctx.battle,ctx.user),failed()end
      if previous.gate then return previous.gate(ctx)end
      return true
    end,
    run=function(ctx)
      if M.epoch(ctx.battle)then return flinch.run(ctx)end
      return previous.run and previous.run(ctx) or {}
    end}
  mod.content.move_effects:register('KA_SLEEP_SNORE_67',snoreEffect)
  mod.content.move_effects:register('KA_SLEEP_TALK_67',{
    kind='full',kascSleepMoves67=M.OWNER,callsMove=M.call})
  mod.content.moves:patch('SNORE',{effect='KA_SLEEP_SNORE_67',sound=true})
  mod.content.moves:patch('SLEEP_TALK',{effect='KA_SLEEP_TALK_67'})
  if opts.catalog then for i=#opts.catalog.unsupportedStatus,1,-1 do
    if opts.catalog.unsupportedStatus[i]=='SLEEP_TALK'then table.remove(opts.catalog.unsupportedStatus,i)end
  end end
  for id,animation in pairs(prepared)do
    if anims:get(id)then anims:patch(id,animation)else anims:register(id,animation)end
    local source=opts.facts.move(id,2)
    mod.content.moves:patch(id,{name=opts.i18n.text(source.names.en,source.names.de),
      anim=copy(mod.content.moves:get(compositions[id][1]).anim)})
  end
  M.animationReview={parts=compositions,status='native-composition-needs-visual-review'}
  Battle._kascSleepMoves67=M
  if not Battle._kascSleepMovesWrapped67 then
    local original=Battle.performMove
    Battle.performMove=function(...)return Battle._kascSleepMoves67.perform(original,...)end
    Battle._kascSleepMovesWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-status-and-move-call-pipeline',providerStatus='era-bound-sleep-moves',
      buildReceiptId='qa/gen6-wave15-alignment-20260909/SLEEP-MOVES-REVIEW.md',
      rollbackReceiptId='qa/gen6-wave15-alignment-20260909/SLEEP-MOVES-REVIEW.md'})
  end
  return M
end
