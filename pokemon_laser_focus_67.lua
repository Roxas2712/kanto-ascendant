-- Laser Focus is a two-round volatile, not permanent Focus Energy.
-- Its field token survives a native checkpoint, never the Pokemon save.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-LASER-FOCUS',OWNER='kasc.laser-focus/v1'}
  local id,effect='LASER_FOCUS','KA_LASER_FOCUS_67'
  local row=assert(opts.facts.move(id,7));local tr=opts.i18n.text
  assert(row.number==673 and row.generation==7 and row.category=='status'
    and row.type=='NORMAL'and row.power==0 and row.pp==30 and row.target==7
    and row.alwaysHits and row.priority==0,'Laser Focus source drift')
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.enabled(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and marker and marker.kascLaserFocus67==M.OWNER
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.active(b,w)
    local key=side(b,w);local r=rows(b);local v=r and key and r[key]
    local turn=b and(b.turnCount or 0)
    return M.enabled(b)and w and w.mon and w.mon.hp>0 and v
      and v.species==w.mon.species and turn>=v.applied and turn<=v.expires or false
  end
  function M.start(b,w)
    local key=side(b,w)
    if not M.enabled(b)or not key or not w.mon or w.mon.hp<=0 then return false end
    local turn=b.turnCount or 0
    rows(b,true)[key]={applied=turn,expires=turn+1,species=w.mon.species}
    return true
  end
  function M.copyFrom(b,w,target)
    local active=M.active(b,target)
    M.clear(b,w)
    -- Transform/Imposter starts a new duration, as addVolatile does.
    if active then return M.start(b,w)end
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_laser_focus_container'end
    for key,v in pairs(r)do
      local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(v)~='table'or type(v.applied)~='number'or v.applied%1~=0
          or v.applied<0 or v.applied>(b.turnCount or 0)or v.expires~=v.applied+1
          or type(v.species)~='string'or not w.mon or v.species~=w.mon.species then
        return false,'invalid_laser_focus_timeline'
      end
      for k in pairs(v)do
        if k~='applied'and k~='expires'and k~='species'then return false,'invalid_laser_focus_field'end
      end
    end
    return true
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end
    for _,key in ipairs({'player','enemy'})do
      local v=r[key];local w=b[key]
      if v and(not M.enabled(b)or not w or not w.mon or w.mon.hp<=0
          or (b.turnCount or 0)>=v.expires)then r[key]=nil end
    end
  end
  function M.prepare(nextDamage,ctx)
    if not ctx or not ctx.move or not M.active(ctx.battle,ctx.user)
        or ctx.move.category=='status'or(tonumber(ctx.move.power)or 0)<=0
        or ctx.opts and(ctx.opts.typeless or ctx.opts.forceCrit~=nil)then return nextDamage(ctx)end
    local adjusted={};for k,v in pairs(ctx)do adjusted[k]=v end
    adjusted.opts={};for k,v in pairs(ctx.opts or{})do adjusted.opts[k]=v end
    local ability=mod.exports and mod.exports.pokemonAbilityEffects67
    adjusted.opts.forceCrit=not(ability and ability.blocksCritical(ctx.battle,ctx.target))
    return nextDamage(adjusted)
  end
  if mod.content.moves:get(id)then M.preserved=true;return M end
  local reference=assert(mod.content.moves:get('FOCUS_ENERGY'))
  mod.content.battle_anims:register(id,copy(assert(mod.content.battle_anims:get('FOCUS_ENERGY'))))
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,
    kascLaserFocus67=M.OWNER,run=function(ctx)
      if not M.start(ctx.battle,ctx.user)then return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
      return {tr('%s\nconcentrated!','%s\nkonzentriert sich!'):format(ctx.user.name or ctx.user.mon.species)}
    end})
  mod.content.moves:register(id,{id=id,name=tr(row.names.en,row.names.de),type=row.type,
    category='status',power=0,pp=30,accuracy=100,priority=0,effect=effect,
    anim=copy(reference.anim),originGeneration=7,backendMoveOwner=M.OWNER,
    backendMoveNumber=673,backendLearnsetRevision=6})
  mod.hooks:wrap('battle.damage',M.prepare,22000)
  mod.events:on('battle.turn_ended',M.endTurn,95)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,95)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-critical-chain-round-tokens',providerStatus='two-round-guaranteed-critical',
      buildReceiptId='docs/LASER_FOCUS_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  M.registered=true;return M
end
