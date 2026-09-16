-- Safety Goggles owns a passive immunity, not item possession or a new move.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-SAFETY-GOGGLES',OWNER='kasc.safety-goggles/v1'}
  local rules,facts,species=assert(opts.rules),assert(opts.facts),assert(opts.species)
  local held=assert(opts.held,'effective battle-held item adapter required')
  local tr=opts.i18n.text;local frames=setmetatable({},{__mode='k'})
  local source=assert(opts.projectileSource,'existing pinned projectile metadata required')
  local item=source.bySourceId and source.bySourceId.safetygoggles
  assert(source.schema=='kasc.held-projectiles-source/v1'
    and source.commit=='6b4bc34e44cc2541929cc4b8fff96e756ab3f268'
    and item and item.sourceId=='safetygoggles'and item.number==650 and item.generation==6
    and not item.berry and item.fling and item.fling.power==80,'Safety Goggles source drift')
  local powder={}
  for id,row in pairs(facts.data.moves)do
    local flag=false;for _,f in ipairs(row.flags or{})do if f=='powder'then flag=true end end
    if flag and row.generation<=7 then
      for _,alias in ipairs(species.moveIds(id))do powder[alias]={id=id,number=row.number,target=row.target}end
    end
  end
  assert(powder.POWDER and powder.POWDER.number==600 and not powder.POWDER_SNOW
    and not powder.POWDERSNOW,'canonical Powder/Powder Snow boundary drift')
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function actual(b,w)
    if side(b,w)then return w end
    if b and w and w.mon then return b.player and b.player.mon==w.mon and b.player
      or b.enemy and b.enemy.mon==w.mon and b.enemy end
  end
  local function index(b,w)local key=side(b,w)
    local party=key=='player'and b:playerPartyView()or key=='enemy'and(b.enemyParty or{b.enemy.mon})
    for i,mon in ipairs(party or{})do if i<=6 and mon==w.mon then return i end end
  end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.isEgg or p.is_egg or p.egg or p.eggSpecies or p.species=='EGG')end
  local function grass(w)for _,id in ipairs(w.curTypes or{})do if id=='GRASS'then return true end end;return false end
  function M.itemMetadata(id)
    if id~='SAFETY_GOGGLES'then return end
    return{id=id,generation=6,names={en='SAFETY GOGGLES',de='SCHUTZBRILLE'},
      flags={'holdable','holdable-passive'},sourceCommit=source.commit,showdownNumber=650}
  end
  function M.itemHelp(id)
    if id~='SAFETY_GOGGLES'then return end
    return{en='From Gen VI: prevents opposing powder moves and sandstorm/hail damage. Not consumed. Klutz, Embargo and Magic Room disable this protection.',
      de='Ab Gen VI: schützt vor gegnerischen Puder-Attacken sowie Sandsturm-/Hagelschaden. Bleibt erhalten. Tollpatsch, Itemsperre und Magieraum deaktivieren den Schutz.'}
  end
  function M.supportsItem(game,id,gen)
    local native=game and game.data and game.data.items and game.data.items[id]
    local h=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
    return id=='SAFETY_GOGGLES'and int(gen,6,7)and native and native.kascSafetyGoggles67==M.OWNER
      and native.originGeneration==6 and h and h.kascSafetyGoggles67==M.OWNER
      and h.kascWeatherOwner67=='kasc.battle-weather/v1'
      and h.kascHeldEffect67=='kasc.held-effect/v1'
      and h.kascItemAccess67=='kasc.item-access/v1'
      and h.kascBattleRooms67=='kasc.battle-rooms/v1'or false
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and type(r)=='table'
      and int(r.activeEpoch,6,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      and M.supportsItem(b.game,'SAFETY_GOGGLES',r.activeEpoch)then return r.activeEpoch end
  end
  function M.active(b,w)
    w=actual(b,w)
    return M.epoch(b)~=nil and live(w)and index(b,w)~=nil
      and held(w.mon,b,w)=='SAFETY_GOGGLES'or false
  end
  function M.powderMove(move)
    local row=move and powder[move.id]
    return row and(move.backendMoveNumber==nil or move.backendMoveNumber==row.number)
      and row or nil
  end
  -- Pure item-effect qualification: does not declare/execute any move, spend
  -- PP, grant caller permission, consume the item or mutate a type/stage.
  function M.powderShield(b,w,move)return M.active(b,w)and M.powderMove(move)~=nil or false end
  function M.blocksPowder(b,u,t,move)
    return live(u)and side(b,u)~=nil and index(b,u)~=nil and actual(b,t)~=u
      and M.powderShield(b,t,move)or false
  end
  function M.weatherShield(b,w,kind)
    return(kind=='sand'or kind=='hail')and M.active(b,w)or false
  end
  function M.canBlock(b,u,t,move)
    local row=M.powderMove(move)
    if not row or(row.target~=2 and row.target~=8 and row.target~=9 and row.target~=10 and row.target~=11)
      or not live(u)or not live(t)or not side(b,u)or not side(b,t)or u==t
      or not index(b,u)or not index(b,t)or grass(t)or not M.blocksPowder(b,u,t,move)then return false end
    local protection=mod.exports.pokemonProtection67
    local priority=mod.exports.pokemonPriorityAbilities67
    local ctx={battle=b,user=u,target=t,move=move}
    if protection and protection.blocks(ctx)or priority and priority.blocks(ctx)then return false end
    if t.invulnerable then
      local memory=mod.exports.pokemonTargetMemory67
      local abilities=mod.exports.pokemonAbilityEffects67
      if not(memory and memory.phaseBypass(b,u,t,move))
        and not(abilities and(abilities.activeAbility(b,u)=='NO_GUARD'or abilities.activeAbility(b,t)=='NO_GUARD'))then return false end
    end
    return true
  end
  local function same(a,z)return a and z and a.id==z.id and a.effect==z.effect end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and same(f.move,ev.move)
      and ev.isCalled==f.called then f.declared=true end
  end
  function M.context(nextCtx,b,u,t,...)
    local ctx=nextCtx(b,u,t,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and same(f.move,ctx.move)then
      f.reached=true;f.ctx=ctx
    end;return ctx
  end
  local function block(ctx)
    ctx.battle:cancelMoveAnim()
    ctx.battle:sayNext(tr('%s\nSafety Goggles!','%s\nSchutzbrille!'):format(ctx.target.name))
  end
  function M.perform(original,b,u,t,inst,called,...)
    local move=inst and b:moveDef(inst)
    if not M.epoch(b)or not M.powderMove(move)or not side(b,u)or not side(b,t)
      or not live(u)or not live(t)or u==t or not index(b,u)or not index(b,t)then
      return original(b,u,t,inst,called,...)end
    local previous=frames[b];local f={user=u,target=t,move=move,inst=inst,called=called or false};frames[b]=f
    local raw,old=rawget(b,'effectRecord'),b.effectRecord
    b.effectRecord=function(self,id)
      local record=old(self,id);if id~=move.effect or not record then return record end
      local proxy={};for k,v in pairs(record)do if k~='perform'then proxy[k]=v end end
      return setmetatable(proxy,{__index=function(_,key)
        if key=='perform'and f.declared and f.reached and f.ctx
          and M.canBlock(b,u,t,f.ctx.move)then return block end
        return record[key]
      end})
    end
    local out=pack(pcall(original,b,u,t,inst,called,...));b.effectRecord=raw;frames[b]=previous
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    local tokens=b and b.field and b.field.tokens
    return not frames[b]and not(tokens and tokens[M.OWNER]~=nil),'safety_goggles_unsettled_or_unexpected_token'
  end
  local native=mod.content.items:get('SAFETY_GOGGLES')
  if not native then
    mod.content.items:register('SAFETY_GOGGLES',{id='SAFETY_GOGGLES',name=tr('SAFETY GOGGLES','SCHUTZBRILLE'),
      names=M.itemMetadata('SAFETY_GOGGLES').names,originGeneration=6,price=0,keyItem=false,
      tossable=true,needsTarget=false,field=false,battle=false})
  end
  mod.content.items:patch('SAFETY_GOGGLES',{kascSafetyGoggles67=M.OWNER,originGeneration=6,
    kascEquipmentRewardEpochs={[6]=true,[7]=true}})
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSafetyGoggles67=M.OWNER})
  mod.events:on('battle.move_used',M.used,95001)
  function M.install()
    B._kascSafetyGoggles67=M;FX._kascSafetyGoggles67=M
    if B.performMove~=B._kascSafetyGogglesPerform67 then local old=B.performMove
      local w=function(...)return B._kascSafetyGoggles67.perform(old,...)end
      B.performMove=w;B._kascSafetyGogglesPerform67=w end
    if FX.makeCtx~=FX._kascSafetyGogglesContext67 then local old=FX.makeCtx
      local w=function(...)return FX._kascSafetyGoggles67.context(old,...)end
      FX.makeCtx=w;FX._kascSafetyGogglesContext67=w end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='effective-held-and-real-weather',
      providerStatus='vi-vii-powder-and-damaging-weather-only',buildReceiptId='docs/SAFETY_GOGGLES_67.md',
      rollbackReceiptId='docs/SAFETY_GOGGLES_67.md'})
  end
  return M
end
