-- Move-owned Mold Breaker semantics share the existing scoped ability owner.
-- No persistent suppression, Pokemon art replacement, or alternate damage engine.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-ABILITY-BYPASS-MOVES',OWNER='kasc.ability-bypass-moves/v1'}
  local specs={
    SUNSTEEL_STRIKE={number=713,type='STEEL',category='physical',contact=true,parts={'FOCUS_ENERGY','SLAM'}},
    MOONGEIST_BEAM={number=714,type='GHOST',category='special',contact=false,parts={'NIGHT_SHADE','PSYBEAM'}},
    PHOTON_GEYSER={number=722,type='PSYCHIC_TYPE',category='special',contact=false,parts={'FOCUS_ENERGY','PSYBEAM'}},
  }
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  function M.epoch(b,move)
    local r=b and b.kascGenerationRulesReceipt
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
        and move and specs[move.id]and move.kascAbilityBypassMove67==M.OWNER then return r.activeEpoch end
  end
  function M.bypasses(b,move)return M.epoch(b,move)~=nil and move.ignoreAbility==true end
  function M.project(b,u,move)
    local gen=M.epoch(b,move)
    -- Before IV the selected historical profile still owns the type-based
    -- physical/special split. Later gifts do not rewrite that global rule.
    if not gen or gen<4 or move.id~='PHOTON_GEYSER'or not u or not u.curStats then return move end
    local who={mon=u.mon,curStats=copy(u.curStats),_ascMegaProfile=u._ascMegaProfile}
    mod.exports.backendSplitSpecial67.prepare(b,who)
    local function staged(stat)
      local stage=math.max(-6,math.min(6,(u.stages or{})[stat]or 0))
      local value=assert(who.curStats[stat],'missing Photon stat '..stat)
      return math.max(1,math.floor(stage>=0 and value*(2+stage)/2 or value*2/(2-stage)))
    end
    -- Ignore burn, held items and ability stat multipliers when choosing;
    -- those still apply normally after selecting the damaging category.
    local out=copy(move)
    out.category=staged('attack')>staged('specialAttack')and'physical'or'special'
    return out
  end
  for _,id in ipairs({'SUNSTEEL_STRIKE','MOONGEIST_BEAM','PHOTON_GEYSER'})do
    local spec=specs[id];local fact=assert(opts.facts.move(id,7))
    assert(fact.number==spec.number and fact.generation==7 and fact.type==spec.type
      and fact.category==spec.category and fact.power==100 and fact.accuracy==100
      and fact.pp==5 and fact.priority==0 and fact.target==10,'ability-bypass source drift '..id)
    assert(not mod.content.moves:get(id),'foreign ability-bypass move '..id)
    mod.content.moves:register(id,{id=id,name=opts.i18n.text(fact.names.en,fact.names.de),
      type=spec.type,category=spec.category,power=100,accuracy=100,pp=5,priority=0,
      effect='NO_ADDITIONAL_EFFECT',contact=spec.contact,ignoreAbility=true,
      originGeneration=7,backendMoveNumber=spec.number,backendMoveOwner=M.OWNER,
      backendLearnsetRevision=17,kascAbilityBypassMove67=M.OWNER,
      anim=copy(assert(mod.content.moves:get(spec.parts[#spec.parts])).anim)})
    local anim={seq={},source=M.OWNER}
    for _,part in ipairs(spec.parts)do
      for _,row in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(row)end
    end
    mod.content.battle_anims:register(id,anim)
  end
  -- The reversed native beam crosses the player's name in the 2D HUD.
  -- Translate only our composed beam OAM; source moves and Pokemon stay put.
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if (id~='MOONGEIST_BEAM'and id~='PHOTON_GEYSER')or not row or row.source~=M.OWNER then return end
    local beamStart
    for _,event in ipairs(player.events or{})do
      if event.sound=='PSYBEAM'then beamStart=event.frame;break end
    end
    if not beamStart then return end
    local frame=0
    for _,step in ipairs(player.steps or{})do
      local sprites={}
      for i,s in ipairs(step.sprites or{})do
        local shifted=copy(s)
        if frame>=beamStart and s.x>0 and s.x<168 and s.y>=16 and s.y<144 then shifted.y=s.y-8 end
        sprites[i]=shifted
      end
      step.sprites=sprites
      frame=frame+step.dur
    end
  end
  Player._kascAbilityBypassAnimation67=M
  if not Player._kascAbilityBypassAnimationWrapped67 then
    local start=Player.start
    Player.start=function(self,id,...)
      local result=start(self,id,...)
      Player._kascAbilityBypassAnimation67.position(self,id)
      return result
    end
    Player._kascAbilityBypassAnimationWrapped67=true
  end
  FX._kascAbilityBypassMoves67=M
  if not FX._kascAbilityBypassMovesWrapped67 then
    local make=FX.makeCtx
    FX.makeCtx=function(b,u,t,...)
      local ctx=make(b,u,t,...);ctx.move=FX._kascAbilityBypassMoves67.project(b,u,ctx.move);return ctx
    end
    FX._kascAbilityBypassMovesWrapped67=true
  end
  for _,hook in ipairs({'battle.damage','battle.accuracy'})do
    mod.hooks:wrap(hook,function(nextFn,ctx)
      local move=M.project(ctx.battle,ctx.user,ctx.move)
      if move==ctx.move then return nextFn(ctx)end
      local out={};for k,v in pairs(ctx)do out[k]=v end;out.move=move
      return nextFn(out)
    end,32000)
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='scoped-ability-and-historical-stat-owners',
      providerStatus='move-bypass-and-photon-category',buildReceiptId='docs/ABILITY_BYPASS_MOVES_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
