-- Battle-local Fire loss after a successful hit. Preserve typeless slots
-- so Roost cannot turn a burned-out Fire/Flying Pokemon into Normal.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-BURN-UP',OWNER='kasc.burn-up/v1'}
  local id,effect='BURN_UP','KA_BURN_UP_67'
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  function M.active(b,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and r.activeEpoch>=1 and r.activeEpoch<=7
      and move and move.id==id and move.backendMoveOwner==M.OWNER
      and marker and marker.kascBurnUp67==M.OWNER
  end
  function M.hasFire(w)
    for _,typ in ipairs(w and w.curTypes or{})do if typ=='FIRE'then return true end end
    return false
  end
  function M.noUseful(b,u,t,move)return M.active(b,move)and not M.hasFire(u)end
  local function withoutFire(types)
    local out={};for i,typ in ipairs(types)do out[i]=typ=='FIRE'and'???'or typ end;return out
  end
  function M.afterHit(ctx)
    local b,u=ctx.battle,ctx.user
    if not M.active(b,ctx.move)or not u or u.mon.hp<=0 or not M.hasFire(u)then return end
    local items=mod.exports.pokemonTypeItems67
    if items and items.locked(b,u)then return end
    local healing=mod.exports.pokemonHealingMoves67
    local key=u==b.player and'player'or'enemy'
    local roost=healing and b.field and b.field.tokens and b.field.tokens[healing.OWNER]
    roost=roost and roost[key]
    if roost then
      roost.original=withoutFire(roost.original)
      roost.applied=withoutFire(u.curTypes)
      u.curTypes=copy(roost.applied)
    else u.curTypes=withoutFire(u.curTypes)end
    local changing=mod.exports.pokemonTypeChanges67
    if changing then changing.fireLost(ctx)end
    b:sayNext(opts.i18n.text('%s burned itself out!','%s hat sich ausgebrannt!'):format(u.name))
  end
  local f=assert(opts.facts.move(id,7))
  assert(f.number==682 and f.type=='FIRE'and f.category=='special'and f.power==130
    and f.accuracy==100 and f.pp==5 and f.priority==0 and f.target==10,'Burn Up source drift')
  assert(not mod.content.moves:get(id),'foreign Burn Up')
  mod.content.move_effects:register(effect,{kind='full',kascBurnUp67=M.OWNER,
    gate=function(ctx)
      if M.active(ctx.battle,ctx.move)and M.hasFire(ctx.user)then return true end
      return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')
    end,afterDamage=M.afterHit})
  mod.content.moves:register(id,{id=id,name=opts.i18n.text(f.names.en,f.names.de),type='FIRE',category='special',
    power=130,accuracy=100,pp=5,priority=0,target=10,contact=false,defrost=true,effect=effect,kascConditionalDamage67=true,
    originGeneration=7,backendMoveNumber=682,backendMoveOwner=M.OWNER,backendLearnsetRevision=25,
    anim=copy(assert(mod.content.moves:get('FIRE_BLAST')).anim)})
  local anim=copy(assert(mod.content.battle_anims:get('FIRE_BLAST')));anim.source=M.OWNER
  mod.content.battle_anims:register(id,anim)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,move)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[move]
    if move~=id or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={};local shift=-16
      for _,s in ipairs(step.sprites or{})do
        if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end
      end
      for i,s in ipairs(step.sprites or{})do
        local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
        sprites[i]=q
      end
      step.sprites=sprites
    end
  end
  Player._kascBurnUpAnimation67=M
  if not Player._kascBurnUpAnimationWrapped67 then local start=Player.start
    Player.start=function(self,move,...)
      local result=start(self,move,...);Player._kascBurnUpAnimation67.position(self,move);return result
    end
    Player._kascBurnUpAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-types-status-and-hit-pipeline',
      providerStatus='successful-hit-fire-loss',buildReceiptId='docs/BURN_UP_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
