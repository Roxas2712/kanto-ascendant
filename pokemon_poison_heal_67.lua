-- Gen 3-7 status residuals on the native Gen-I host, including Poison Heal.
-- Keep the native turn/faint/HP-queue owner and its checkpoint fields.
return function(mod,opts)
  local M={CARD_ID='KASC-67-POISON-HEAL',OWNER='kasc.poison-heal-residual/v1'}
  local Status=require('src.battle.Status')
  local Battle=require('src.battle.BattleState')
  local romText=require('src.core.RomText')
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascPoisonHealOwner67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  local function append(dst,src)for _,v in ipairs(src or {})do dst[#dst+1]=v end end
  function M.validateCheckpoint(b)
    local row=b.field and b.field.tokens and b.field.tokens[M.OWNER]
    if row==nil then return true end
    if type(row)~='table' then return false,'invalid status residual timeline' end
    for side,turn in pairs(row)do
      if (side~='player' and side~='enemy') or type(turn)~='number'
          or turn<0 or turn~=math.floor(turn) or turn>(b.turnCount or 0) then
        return false,'invalid status residual side/turn'
      end
    end
    return true
  end
  function M.poison(original,who,opponent,b)
    local gen=M.epoch(b)
    if not gen then return original(who,opponent,b)end
    local mon=who.mon
    if mon.hp<=0 then return {}end
    local damage=math.max(1,math.floor(mon.stats.hp/8))
    if who.toxicCounter then
      local count=math.max(1,math.min(15,who.toxicCounter))
      damage=math.max(1,math.floor(mon.stats.hp/16))*count
      who.toxicCounter=math.min(15,count+1)
    end
    if gen>=4 and opts.abilities.activeAbility(b,who)=='POISON_HEAL' then
      local block=mod.exports.pokemonHealBlock67
      if block and block.blocksRecovery(b,who,'ability')then return {}end
      local hp=math.min(mon.stats.hp,mon.hp+math.max(1,math.floor(mon.stats.hp/8)))
      if hp==mon.hp then return {}end
      mon.hp=hp
      return {opts.i18n.text('%s: Poison Heal restores HP!','%s: Aufheber heilt KP!'):format(who.name)}
    end
    if opts.abilities.blocksIndirect(b,who,'poison')then return {}end
    mon.hp=math.max(0,mon.hp-damage)
    return {romText(b.data,'_HurtByPoisonText',"%s's\nhurt by poison!",who.name)}
  end
  function M.burn(original,who,opponent,b)
    local gen=M.epoch(b)
    if not gen then return original(who,opponent,b)end
    if who.mon.hp<=0 then return {}end
    if opts.abilities.blocksIndirect(b,who,'burn')then return {}end
    local divisor=gen==7 and 16 or 8
    if opts.abilities.activeAbility(b,who)=='HEATPROOF'then divisor=divisor*2 end
    who.mon.hp=math.max(0,who.mon.hp-math.max(1,math.floor(who.mon.stats.hp/divisor)))
    return {romText(b.data,'_HurtByBurnText',"%s's\nhurt by the burn!",who.name)}
  end
  function M.residual(original,who,opponent,b)
    if not M.epoch(b) then return original(who,opponent,b)end
    local side=who==b.player and 'player' or who==b.enemy and 'enemy'
    if not side then return original(who,opponent,b)end
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    local row=b.field.tokens[M.OWNER] or {}
    assert(M.validateCheckpoint(b),'invalid KASC status residual timeline')
    b.field.tokens[M.OWNER]=row
    local turn=b.turnCount or 0
    if row[side]==turn then return {}end
    row[side]=turn
    local messages={};local mon=who.mon
    who.skipMove=nil
    if mon.hp<=0 then return messages end
    -- Modern Leech Seed precedes status damage and never borrows/increments
    -- Toxic's counter. Only HP actually removed can heal the recipient.
    if who.leechSeeded and opponent.mon.hp>0 and not opts.abilities.blocksIndirect(b,who,'seed')then
      local damage=math.min(mon.hp,math.max(1,math.floor(mon.stats.hp/8)))
      mon.hp=mon.hp-damage
      local sap=mod.exports.pokemonStrengthSap67
      local gain=sap and sap.drainAmount(b,opponent,damage)or damage
      if opts.abilities.activeAbility(b,who)=='LIQUID_OOZE'then
        if not opts.abilities.blocksIndirect(b,opponent,'ooze')then opponent.mon.hp=math.max(0,opponent.mon.hp-gain)end
      elseif not(mod.exports.pokemonHealBlock67 and mod.exports.pokemonHealBlock67.blocksRecovery(b,opponent,'leechseed'))then
        opponent.mon.hp=math.min(opponent.mon.stats.hp,opponent.mon.hp+gain)
      end
      messages[#messages+1]=romText(b.data,'_HurtByLeechSeedText','LEECH SEED saps\n%s!',who.name)
    end
    if mon.hp>0 then
      local record=Status.recordFor(b.data.statuses,mon.status)
      if record and record.residual then append(messages,record.residual(who,opponent,b))end
    end
    return messages
  end
  for id,fn in pairs({PSN=M.poison,BRN=M.burn})do
    local original=assert(mod.content.statuses:get(id).residual)
    mod.content.statuses:patch(id,{residual=function(...)return fn(original,...)end})
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPoisonHealOwner67=M.OWNER})
  local function pack(...)return {n=select('#',...),...}end
  function M.timing(original,b,...)
    if not M.epoch(b)then return original(b,...)end
    local living={}
    for _,who in ipairs({b.player,b.enemy})do if who.mon.hp>0 then living[#living+1]=who end end
    local previous=b.ruleset;local scoped={}
    for k,v in pairs(previous or {})do scoped[k]=v end
    scoped.residualAfterMove=false;b.ruleset=scoped
    local out=pack(pcall(original,b,...))
    b.ruleset=previous
    if not out[1]then error(out[2],0)end
    -- Native residual code only checks the seeded battler for a faint.
    -- Ooze can instead KO the recipient; settle it after native HP queues.
    for _,who in ipairs(living)do
      if (who==b.player or who==b.enemy)and who.mon.hp<=0 and not who.faintQueued then b:onFaint(who)end
    end
    return unpack(out,2,out.n)
  end
  Battle._kascPoisonHealTiming67=M
  if not Battle._kascPoisonHealTimingWrapped67 then
    for _,name in ipairs({'executeAction','endOfTurn'})do
      local original=Battle[name]
      Battle[name]=function(...)return Battle._kascPoisonHealTiming67.timing(original,...)end
    end
    Battle._kascPoisonHealTimingWrapped67=true
  end
  mod.events:on('battle.ended',function(ctx)
    local b=ctx.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,100)
  Status._kascPoisonHeal67=M
  if not Status._kascPoisonHealWrapped67 then
    local original=Status.residual
    Status.residual=function(...)return Status._kascPoisonHeal67.residual(original,...)end
    Status._kascPoisonHealWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-status-residual',providerStatus='era-bound-poison-heal',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
