-- Flower Gift's damage bonus is evaluated from current effective weather;
-- its visual form is temporary and never rewrites the saved Pokemon.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-FLOWER-GIFT',OWNER='kasc.flower-gift/v1'}
  local base,key='dex:421','cosmetic:421:sunshine'
  local species=assert(opts.species.byKey[base])
  local root='assets/flower_gift_67/'
  local timing={100,467,200,467,117,133}
  local function track(side,variant)
    return{root=root..side..'/'..variant,durations=timing,animated=true,scale=side=='voxel'and 1.5 or 1}
  end
  opts.forms.registerCosmeticPair(base,key,'FLOWER_GIFT',4,89421,{
    species='KA_GIFT_CHERRIM_SUNSHINE',heightM=0.5,voxelSize=64,
    pixel={front=root..'front/normal/001.png',frontShiny=root..'front/shiny/001.png',
      back=root..'back/normal/001.png',backShiny=root..'back/shiny/001.png',
      preferPixel2D=true,rearLayout='upper32-of-48'},
    fallback={front=root..'voxel/normal/001.png',frontShiny=root..'voxel/shiny/001.png',scale=1.5},
    native={front=track('front','normal'),frontShiny=track('front','shiny')},
    voxel={variants={normal=track('voxel','normal'),shiny=track('voxel','shiny')}}})
  local function copy(v)local t={};for k,x in pairs(v or{})do t[k]=x end;return t end
  local function pack(...)return{n=select('#',...),...}end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=getmetatable(b)==B and not b.result and r and r.kascFlowerGift67==M.OWNER and opts.status.epoch(b)
    return gen and gen>=4 and gen<=7 and gen or nil
  end
  function M.bonus(b,w)
    local gen=M.epoch(b)
    return gen and w and w.mon and w.mon.hp>0 and opts.weather.current(b)=='sun'
      and (gen==4 or w.mon.species==species)
      and opts.abilities.activeAbility(b,w)=='FLOWER_GIFT' or false
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or ctx.move.category=='status'or ctx.opts and ctx.opts.typeless
        or not M.epoch(ctx.battle)then return nextDamage(ctx)end
    local a,z=M.bonus(ctx.battle,ctx.user),M.bonus(ctx.battle,ctx.target)
    if not a and not z then return nextDamage(ctx)end
    local out=copy(ctx);out.opts=copy(ctx.opts)
    out.opts.kascFlowerGiftAttack67=a;out.opts.kascFlowerGiftDefense67=z
    return nextDamage(out)
  end
  function M.sync(b)
    local gen=M.epoch(b);if not gen or not b.player or not b.enemy then return end
    for _,w in ipairs({b.player,b.enemy})do
      if w.mon and w.mon.species==species and w.mon.hp>0 and not opts.identity.transformed(w)
          and not w._ascMegaProfile and not w.mon._ascMegaForm and not w.mon.ascMegaForm then
        -- Mold Breaker's transient damage frame must not close the flower.
        local available=gen==4 or not w.abilitySuppressed and opts.abilities.abilityIdentity(b,w)=='FLOWER_GIFT'
        local chosen=available and opts.weather.current(b)=='sun'and key or base
        opts.forms.change(b,w,chosen,gen,true)
      end
    end
  end
  function M.entry(ev)if ev and ev.battle then M.sync(ev.battle)end end
  function M.wrap(original,b,...)
    M.sync(b);local out=pack(pcall(original,b,...));M.sync(b)
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  B._kascFlowerGift67=M
  if not B._kascFlowerGiftWrapped67 then
    for _,method in ipairs({'performMove','update','endOfTurn'})do
      local old=assert(B[method]);B[method]=function(...)return B._kascFlowerGift67.wrap(old,...)end
    end
    B._kascFlowerGiftWrapped67=true
  end
  -- Weather setters have no existing event seam. Wrap the current mod
  -- instance only; Castform keeps its own preceding synchronization.
  for _,method in ipairs({'set','abilityChanged'})do
    local old=assert(opts.weather[method]);opts.weather[method]=function(b,...)
      local out=pack(old(b,...));M.sync(b);return unpack(out,1,out.n)
    end
  end
  mod.events:on('battle.started',M.entry,-10061)
  mod.events:on('battle.battler_switched',M.entry,-10061)
  mod.events:on('battle.fainted',M.entry,-20002)
  mod.hooks:wrap('battle.damage',M.damage,19500)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascFlowerGift67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-weather-damage-temporary-form',providerStatus='gen4-7-flower-gift',
      buildReceiptId='docs/FLOWER_GIFT_67.md',rollbackReceiptId='docs/FLOWER_GIFT_67.md'})
  end
  return M
end
