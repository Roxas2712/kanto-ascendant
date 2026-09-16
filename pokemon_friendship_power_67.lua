-- Return/Frustration consume the existing friendship value, never reroll it.
-- This Card owns a detached per-use power view, not saved friendship or art.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-FRIENDSHIP-POWER',OWNER='kasc.friendship-power/v1'}
  local defs={RETURN={number=216,part='POUND'},FRUSTRATION={number=218,part='RAGE'}}
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function live(w)
    local mon=w and w.mon
    return mon and type(mon.hp)=='number'and mon.hp>0
      and not(mon.isEgg or mon.egg or mon.is_egg or mon.eggSpecies)
  end
  function M.friendship(mon)
    -- Johto's existing durable bond is already a 0..255 value. Its older
    -- 100-point evolution threshold is NOT a reason to rescale it here.
    for _,key in ipairs({'happiness','friendship','johtoBond'})do
      local value=mon and mon[key]
      if type(value)=='number'and value==value and value~=math.huge and value~=-math.huge then
        return math.max(0,math.min(255,math.floor(value)))
      end
    end
    return 0 -- existing missing-bond policy; no save initialization/retcon
  end
  function M.epoch(b,u,move)
    local receipt=b and b.kascGenerationRulesReceipt
    local def=move and defs[move.id]
    local effect=def and b and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    local gen=receipt and receipt.mode~='off'and receipt.activeEpoch
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result
        or type(gen)~='number'or gen%1~=0 or gen<1 or gen>7
        or not effect or effect.kascFriendshipPower67~=M.OWNER
        or move.backendMoveOwner~=M.OWNER then return end
    if gen==1 and not(live(u)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species]))then return end
    return gen
  end
  function M.power(id,friendship,gen)
    if not defs[id]then return end
    local power=math.floor((id=='RETURN'and friendship or 255-friendship)*10/25)
    -- Crystal's zero-power callback fails; III+ clamps that edge to one.
    return gen and gen<=2 and power or math.max(1,power)
  end
  function M.project(b,u,move)
    local gen=M.epoch(b,u,move)
    if not gen or not live(u)or move.kascFriendshipProjected67==M.OWNER then return move end
    local out=copy(move);out.power=M.power(move.id,M.friendship(u.mon),gen)
    out.kascFriendshipProjected67=M.OWNER;return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local move=M.project(ctx.battle,ctx.user,ctx.move)
    if move==ctx.move then return nextDamage(ctx)end
    local adjusted={};for k,v in pairs(ctx)do adjusted[k]=v end;adjusted.move=move
    return nextDamage(adjusted)
  end
  function M.context(original,b,u,t,...)
    local ctx=original(b,u,t,...);ctx.move=M.project(b,u,ctx.move);return ctx
  end
  function M.gate(ctx)
    return M.epoch(ctx.battle,ctx.user,ctx.move)~=nil and live(ctx.user)and live(ctx.target)
      and M.power(ctx.move.id,M.friendship(ctx.user.mon),M.epoch(ctx.battle,ctx.user,ctx.move))>0
      or false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')
  end
  for id,def in pairs(defs)do
    local f=assert(opts.facts.move(id,2))
    assert(f.number==def.number and f.generation==2 and f.type=='NORMAL'
      and f.category=='physical'and f.power==0 and f.pp==20 and f.accuracy==100,
      'friendship power source drift '..id)
    local prior=assert(mod.content.moves:get(id))
    assert(not prior.backendMoveOwner,'foreign friendship move owner '..id)
    local effect='KA_FRIENDSHIP_POWER_67_'..id
    mod.content.move_effects:register(effect,{kind='full',gate=M.gate,kascFriendshipPower67=M.OWNER})
    mod.content.moves:patch(id,{effect=effect,power=1,contact=true,backendMoveOwner=M.OWNER,
      backendMoveNumber=def.number,backendLearnsetRevision=prior.backendLearnsetRevision or 1})
    local animation=copy(assert(mod.content.battle_anims:get(def.part)))
    animation.source=M.OWNER;mod.content.battle_anims:patch(id,animation)
  end
  local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
  function M.inHud(s)
    local x,y=s.x-8,s.y-16
    for _,r in ipairs(hud)do if x<r[3]and x+8>r[1]and y<r[4]and y+8>r[2]then return true end end
    return false
  end
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do
      local sprites={}
      for i,s in ipairs(step.sprites or{})do
        local out=copy(s)
        if out.x>0 and out.x<168 and out.y>0 and out.y<160 then
          out.y=math.max(16,out.y-16);if M.inHud(out)then out.x=0 end
        end
        sprites[i]=out
      end
      step.sprites=sprites
    end
  end
  function M.install()
    FX._kascFriendshipPower67=M;Player._kascFriendshipPower67=M
    if not FX._kascFriendshipPowerWrapped67 then
      local context=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascFriendshipPower67.context(context,...)end
      FX._kascFriendshipPowerWrapped67=true
    end
    if not Player._kascFriendshipPowerWrapped67 then
      local start=Player.start
      Player.start=function(self,id,...)
        local out=start(self,id,...);Player._kascFriendshipPower67.position(self,id);return out
      end
      Player._kascFriendshipPowerWrapped67=true
    end
  end
  mod.hooks:wrap('battle.damage',M.damage,31511)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',
    owner=M.OWNER,active=true,dependencyStatus='existing-friendship-native-damage-and-context',
    providerStatus='return-frustration-pure-power',buildReceiptId='docs/FRIENDSHIP_POWER_67.md',
    rollbackReceiptId='docs/FRIENDSHIP_POWER_67.md'})end
  return M
end
