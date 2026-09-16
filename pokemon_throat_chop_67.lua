-- Throat Chop / Neck Strike: two-round sound lock, not a permanent Disable.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-THROAT-CHOP',OWNER='kasc.throat-chop/v1'}
  local id,effect='THROAT_CHOP','KA_THROAT_CHOP_67'
  local row=assert(opts.facts.move(id,7));local tr=opts.i18n.text
  assert(row.number==675 and row.type=='DARK'and row.category=='physical'
    and row.power==80 and row.accuracy==100 and row.pp==15 and row.target==10
    and row.meta.ailment_chance==100 and row.meta.min_turns==2 and row.meta.max_turns==2,
    'Throat Chop source drift')
  local sounds={}
  for name,r in pairs(opts.facts.data.moves)do
    for _,flag in ipairs(r.flags or{})do if flag=='sound'then sounds[name:gsub('_','')]=true end end
  end
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.enabled(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and marker and marker.kascThroatChop67==M.OWNER
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.active(b,w)
    if not b or not w or not w.mon or w.mon.hp<=0 or not M.enabled(b)then return false end
    local key=side(b,w);local r=rows(b);local v=r and key and r[key]
    return v and(b.turnCount or 0)>=v.applied and(b.turnCount or 0)<=v.expires or false
  end
  function M.start(b,w)
    if not M.enabled(b)or not side(b,w)or w.mon.hp<=0 or M.active(b,w)then return false end
    local turn=b.turnCount or 0
    rows(b,true)[side(b,w)]={applied=turn,expires=turn+1}
    return true
  end
  function M.blocked(b,w,move)
    return M.active(b,w)and move and not(move.isZ or move.isMax or move.isZOrMaxPowered)
      and sounds[(move.id or''):gsub('_','')]==true or false
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end
    for _,key in ipairs({'player','enemy'})do
      local v=r[key];local w=b[key]
      if v and(not M.enabled(b)or not w or not w.mon or w.mon.hp<=0
          or(b.turnCount or 0)>=v.expires)then r[key]=nil end
    end
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_throat_chop_container'end
    for key,v in pairs(r)do
      if(key~='player'and key~='enemy')or not b[key]or type(v)~='table'
          or type(v.applied)~='number'or v.applied%1~=0 or v.applied<0
          or v.applied>(b.turnCount or 0)or v.expires~=v.applied+1 then
        return false,'invalid_throat_chop_timeline'
      end
      for k in pairs(v)do if k~='applied'and k~='expires'then return false,'unknown_throat_chop_field'end end
    end
    return true
  end
  local function notice()return tr('Throat Chop blocks\nsound moves!','Neck Strike sperrt\nSchall-Attacken!')end
  function M.perform(original,b,u,t,inst,called)
    if M.blocked(b,u,b:moveDef(inst))then b:sayNext(notice());return end
    return original(b,u,t,inst,called)
  end
  local function choices(b,w)
    local out={};local choice=mod.exports and mod.exports.pokemonChoiceItems67
    local lock=choice and choice.locked(b,w)
    for i,slot in ipairs(w.curMoves or{})do
      local def=b:moveDef(slot)
      local use=mod.exports.pokemonConditionalUse67
      local unlimited=not w.isPlayer and b.kind~='link'and b.ruleset and b.ruleset.enemyUnlimitedPP
        and b.kascGenerationRulesReceipt and b.kascGenerationRulesReceipt.activeEpoch==1
      if def and i~=w.disabledSlot and(unlimited or(slot.pp or 0)>0)
          and(not lock or slot.id==lock.move)and not M.blocked(b,w,def)
          and not(use and use.blocksSelection(b,w,def))then out[#out+1]=slot end
    end
    return out
  end
  function M.playerHasPP(original,b,...)
    if not M.active(b,b.player)then return original(b,...)end
    return original(b,...)and#choices(b,b.player)>0
  end
  function M.chooseMove(original,b,index,...)
    local slot=b.player and b.player.curMoves and b.player.curMoves[index]
    if b.phase=='moveSelect'and slot and M.blocked(b,b.player,b:moveDef(slot))then
      b:say(notice());b.phase='messages';b.afterQueue='menu';return true
    end
    return original(b,index,...)
  end
  function M.enemyAction(original,b,...)
    local action=original(b,...)
    if not action or action.special or not M.blocked(b,b.enemy,b:moveDef(action))then return action end
    -- Forced continuations can fail this turn; do not replace a lock with
    -- another move. Ordinary selection uses a legal non-sound alternative.
    if b:lockedAction(b.enemy)then return action end
    local pool=choices(b,b.enemy);local best=pool[1]
    for _,slot in ipairs(pool)do
      local def=b:moveDef(slot)
      if def.category~='status'and(def.power or 0)>0 then best=slot;break end
    end
    return best or{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.install()
    B._kascThroatChop67=M
    if B._kascThroatChopWrapped67 then return end
    local perform,choose,enemy,pp=B.performMove,B.chooseMove,B.enemyAction,B.playerHasPP
    B.performMove=function(...)return B._kascThroatChop67.perform(perform,...)end
    B.chooseMove=function(...)return B._kascThroatChop67.chooseMove(choose,...)end
    B.enemyAction=function(...)return B._kascThroatChop67.enemyAction(enemy,...)end
    B.playerHasPP=function(...)return B._kascThroatChop67.playerHasPP(pp,...)end
    B._kascThroatChopWrapped67=true
  end
  if mod.content.moves:get(id)then M.preserved=true;return M end
  local animation={seq={}}
  for _,part in ipairs({'KARATE_CHOP','NIGHT_SHADE'})do
    for _,r in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=copy(r)end
  end
  mod.content.battle_anims:register(id,animation)
  mod.content.move_effects:register(effect,{kind='secondary',kascThroatChop67=M.OWNER,run=function(ctx)
    local target=ctx.target
    if not target or target.mon.hp<=0 or target.substituteHP or ctx.brokeSub then return {}end
    local ability=mod.exports and mod.exports.pokemonAbilityEffects67
    local chance=ability and ability.secondaryChance(ctx,100)or 100
    if ctx.rng(1,100)<=chance then M.start(ctx.battle,target)end
    return {}
  end})
  mod.content.moves:register(id,{id=id,name=tr(row.names.en,row.names.de),type=row.type,
    category=row.category,power=80,accuracy=100,pp=15,priority=0,contact=true,effect=effect,
    originGeneration=7,backendMoveNumber=675,backendMoveOwner=M.OWNER,backendLearnsetRevision=9,
    anim=copy(assert(mod.content.moves:get('KARATE_CHOP')).anim)})
  mod.events:on('battle.turn_ended',M.endTurn,95)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,95)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-sound-selection-secondary-round-tokens',providerStatus='two-round-sound-lock',
      buildReceiptId='docs/THROAT_CHOP_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  M.registered=true;return M
end
