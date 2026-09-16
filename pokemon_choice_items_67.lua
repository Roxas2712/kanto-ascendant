-- Choice boosts and selection constraints share one checkpointed owner.
-- Do not put the choice into lockedAction: trainers may still switch/use
-- items, and the player must retain the native party/item/run menus.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-CHOICE-ITEMS',OWNER='kasc.choice-items/v1'}
  local items={CHOICE_BAND={gen=3,en='CHOICE BAND',de='WAHLBAND'},
    CHOICE_SPECS={gen=4,en='CHOICE SPECS',de='WAHLGLAS'},
    CHOICE_SCARF={gen=4,en='CHOICE SCARF',de='WAHLSCHAL'}}
  local function pack(...)return {n=select('#',...),...}end
  local function copy(v)local out={};for k,x in pairs(v or {})do out[k]=x end;return out end
  function M.itemMetadata(id)
    local row=items[id];if not row then return end
    return {id=id,generation=row.gen,names={en=row.en,de=row.de},flags={'holdable','holdable-passive'}}
  end
  local function side(b,w)return w==b.player and 'player' or w==b.enemy and 'enemy' or nil end
  local function rows(b,create)
    if create then b.field=b.field or {};b.field.tokens=b.field.tokens or {}end
    local t=b and b.field and b.field.tokens
    if create and not t[M.OWNER]then t[M.OWNER]={}end
    return t and t[M.OWNER]
  end
  for id,row in pairs(items)do
    local fields={kascChoiceItemOwner67=M.OWNER,kascEquipmentRewardEpochs={}}
    for gen=row.gen,7 do fields.kascEquipmentRewardEpochs[gen]=true end
    if mod.content.items:get(id)then mod.content.items:patch(id,fields)
    else
      local facts=opts.facts.item(id,row.gen)or{}
      fields.id=id;fields.name=opts.i18n.text(row.en,row.de);fields.names={en=row.en,de=row.de}
      fields.price=facts.cost or 0;fields.keyItem=false;fields.field=false;fields.battle=false
      mod.content.items:register(id,fields)
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascChoiceItemOwner67=M.OWNER})
  function M.supportsItem(game,id,gen)
    local def=game and game.data and game.data.items and game.data.items[id]
    local effects=game and game.data and game.data.move_effects
    return items[id] and def and def.kascChoiceItemOwner67==M.OWNER
      and effects and effects.HEAL_EFFECT and effects.HEAL_EFFECT.kascChoiceItemOwner67==M.OWNER
      and effects.FOCUS_ENERGY_EFFECT and effects.FOCUS_ENERGY_EFFECT.kascCriticalOwner67=='kasc.critical-rules/v1'
      and type(gen)=='number' and gen%1==0 and gen>=items[id].gen and gen<=7 or false
  end
  function M.epoch(b)
    local gen=b and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.item(b,w)
    local gen=M.epoch(b);local mon=w and w.mon
    if not gen or not mon or mon.isEgg or mon.egg or mon.eggSpecies or (tonumber(mon.hp)or 0)<=0 then return end
    local id=opts.held(mon,b,w)
    if M.supportsItem(b.game,id,gen)then return id,gen end
  end
  function M.clear(b,w)
    local t=rows(b);if not t then return end
    if w then local key=side(b,w);if key then t[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.validateCheckpoint(b)
    local t=rows(b);if t==nil then return true end
    if type(t)~='table'then return false,'invalid_choice_timeline'end
    for key,r in pairs(t)do
      if key~='player' and key~='enemy'then return false,'invalid_choice_side'end
      if type(r)~='table' or not items[r.item] or type(r.move)~='string'
          or not b.data.moves[r.move] or r.move=='STRUGGLE' or not b[key]then return false,'invalid_choice_lock'end
      for field in pairs(r)do
        if field~='item' and field~='move'then return false,'unknown_choice_field'end
      end
    end
    return true
  end
  function M.locked(b,w)
    local t=rows(b);local key=b and side(b,w);local r=t and key and t[key]
    if not r then return end
    local id,gen=M.item(b,w)
    if not id or gen>=5 and id~=r.item then M.clear(b,w);return end
    -- A copied/forgotten move list can remove the original locked move.
    for _,slot in ipairs(w.curMoves or {})do if slot.id==r.move then return r end end
    M.clear(b,w)
  end
  function M.remember(b,w,move)
    local id=M.item(b,w);local key=side(b,w)
    if not id or not key or not move or move=='STRUGGLE' or not b.data.moves[move] then return end
    -- A same-battler form change (e.g. Mega) is not a switch.
    if not M.locked(b,w)then rows(b,true)[key]={item=id,move=move}end
  end
  local attempt
  function M.used(ev)
    if ev.isCalled or not ev.move or ev.move.id=='STRUGGLE'then return end
    if attempt and attempt.battle==ev.battle and attempt.user==ev.user then
      attempt.used=ev.move.id
    end
    local _,gen=M.item(ev.battle,ev.user)
    if gen and gen>=5 then M.remember(ev.battle,ev.user,ev.move.id)end
  end
  local function refusal(b,w)
    local id=opts.held(w.mon);local def=b.data.items[id]
    return opts.i18n.text('%s only allows the chosen move!','%s erlaubt nur die gewählte Attacke!')
      :format(def and def.name or id or 'Choice item')
  end
  function M.perform(original,b,user,target,move,isCalled)
    if not M.epoch(b) or isCalled or not move then return original(b,user,target,move,isCalled)end
    local lock=M.locked(b,user)
    if lock and not move.struggle and move.id~=lock.move then b:sayNext(refusal(b,user));return end
    local previous=attempt;local this={battle=b,user=user};attempt=this
    local result=pack(pcall(original,b,user,target,move,isCalled));attempt=previous
    if not result[1]then error(result[2],0)end
    local gen=M.epoch(b)
    if gen and gen<=4 and this.used then M.remember(b,user,this.used)end
    return unpack(result,2,result.n)
  end
  local function slotFor(w,lock)
    for i,slot in ipairs(w.curMoves or {})do
      if slot.id==lock.move and i~=w.disabledSlot and (tonumber(slot.pp)or 0)>0 then return slot end
    end
  end
  function M.playerHasPP(original,b,...)
    local lock=M.locked(b,b.player)
    if lock then return slotFor(b.player,lock)~=nil end
    return original(b,...)
  end
  function M.chooseMove(original,b,index,...)
    local lock=M.locked(b,b.player);local move=b.player and b.player.curMoves[index]
    if b.phase=='moveSelect' and lock and move and move.id~=lock.move then
      b:say(refusal(b,b.player));b.phase='messages';b.afterQueue='menu';return true
    end
    return original(b,index,...)
  end
  function M.enemyAction(original,b,...)
    local action=original(b,...);local lock=M.locked(b,b.enemy)
    if not lock or action and action.special or b:lockedAction(b.enemy)then return action end
    return slotFor(b.enemy,lock)or{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or not ctx.user or ctx.opts and ctx.opts.typeless
        or ctx.move.category=='status' or (tonumber(ctx.move.power)or 0)<=0 then return nextDamage(ctx)end
    local id=M.item(ctx.battle,ctx.user)
    local special=(ctx.move.category or require('src.battle.TypeChart').category(ctx.move.type))=='special'
    if id~='CHOICE_BAND' or special then
      if id~='CHOICE_SPECS' or not special then return nextDamage(ctx)end
    end
    local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts);adjusted.opts.kascHeldAttack67=6144
    return nextDamage(adjusted)
  end
  function M.speed(b,w)
    return opts.weather.speed(b,w,M.item(b,w)=='CHOICE_SCARF' and 1.5 or 1)
  end
  local activeBattle
  function M.scoped(original,b,...)
    local previous=activeBattle;activeBattle=b
    local result=pack(pcall(original,b,...));activeBattle=previous
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.order(nextOrder,a,am,z,zm,ctx)
    local b=activeBattle
    if not b or a~=b.player or z~=b.enemy
        or M.item(b,a)~='CHOICE_SCARF' and M.item(b,z)~='CHOICE_SCARF'then
      return nextOrder(a,am,z,zm,ctx)
    end
    local function priority(move)return move and (move.priority or ({QUICK_ATTACK=1,COUNTER=-1})[move.id]or 0)or 0 end
    if priority(am)~=priority(zm)then return nextOrder(a,am,z,zm,ctx)end
    local rooms=mod.exports and mod.exports.pokemonBattleRooms67
    if rooms and rooms.hasOrderEffect(b)then return nextOrder(a,am,z,zm,ctx)end
    local sa,sz=M.speed(b,a),M.speed(b,z)
    if sa~=sz then return sa>sz end
    local first=(ctx.rng or b.rng)(0,1)==0
    return ctx.invertTie and not first or not ctx.invertTie and first
  end
  mod.hooks:wrap('battle.damage',M.damage,-7800)
  mod.hooks:wrap('battle.turn_order',M.order,-6800)
  mod.events:on('battle.move_used',M.used,6500)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  Battle._kascChoiceItems67=M
  if not Battle._kascChoiceItemsWrapped67 then
    local perform,choose,enemy,pp,resolve=Battle.performMove,Battle.chooseMove,Battle.enemyAction,Battle.playerHasPP,Battle.resolveTurn
    Battle.performMove=function(...)return Battle._kascChoiceItems67.perform(perform,...)end
    Battle.chooseMove=function(...)return Battle._kascChoiceItems67.chooseMove(choose,...)end
    Battle.enemyAction=function(...)return Battle._kascChoiceItems67.enemyAction(enemy,...)end
    Battle.playerHasPP=function(...)return Battle._kascChoiceItems67.playerHasPP(pp,...)end
    Battle.resolveTurn=function(...)return Battle._kascChoiceItems67.scoped(resolve,...)end
    Battle._kascChoiceItemsWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-selection-pp-and-checkpoint',providerStatus='era-choice-lock-and-stats',
      buildReceiptId='docs/CHOICE_ITEMS_67.md',rollbackReceiptId='docs/CHOICE_ITEMS_67.md'})
  end
  return M
end
