-- Mind Blown costs half maximum HP once per attempted move, not per hit.
-- Register before gift projection; install the hit adapter after the shared
-- protection/ability owners so their early returns still count as attempts.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-MIND-BLOWN',OWNER='kasc.mind-blown/v1',ID='MIND_BLOWN'}
  local effect='KA_MIND_BLOWN_67'
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  function M.active(b,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
      and move and move.id==M.ID and move.backendMoveOwner==M.OWNER
      and marker and marker.kascMindBlown67==M.OWNER
  end
  function M.recoil(ctx)
    if ctx._kascMindBlownRecoil67 then return end
    ctx._kascMindBlownRecoil67=true
    local b,u=ctx.battle,ctx.user
    if not u or not u.mon or u.mon.hp<=0
        or mod.exports.pokemonAbilityEffects67.blocksIndirect(b,u,'mind_blown')then return end
    local maximum=assert(u.mon.stats and u.mon.stats.hp,'Mind Blown requires native maximum HP')
    local amount=math.max(1,math.floor(maximum/2+0.5))
    b:sayNext(opts.i18n.text('Mind Blown!\nLost HP.','Knallkopf!\nKP verloren.'))
    -- Do not strike the user's own Substitute, feed Bide, or trigger Rage.
    -- Rock Head does not prevent this HP cost; Magic Guard does.
    mod.exports.pokemonContactAbilities67.indirectDamage(b,u,amount)
  end
  function M.run(original,b,ctx,record)
    if not M.active(b,ctx and ctx.move)then return original(b,ctx,record)end
    -- Damp is an execution prohibition, not a missed explosion. Its shared
    -- owner still announces the failure and the engine still spends PP.
    local damp=mod.exports.pokemonContactAbilities67.blocksExplosion(b,ctx.move)
    local result=pack(original(b,ctx,record))
    if not damp and not ctx._kascMindBlownRecoil67 then
      M.recoil(ctx)
      -- Hit success uses the engine's normal faint checks after afterDamage.
      -- Miss/Protect/immunity return early and need the recoil faint here.
      if ctx.user.mon.hp<=0 then b:onFaint(ctx.user)end
    end
    return unpack(result,1,result.n)
  end
  function M.install()
    FX._kascMindBlown67=M
    if not FX._kascMindBlownWrapped67 then local original=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascMindBlown67.run(original,...)end
      FX._kascMindBlownWrapped67=true
    end
  end
  local f=assert(opts.facts.move(M.ID,7))
  assert(f.number==720 and f.type=='FIRE'and f.category=='special'and f.power==150
    and f.accuracy==100 and f.pp==5 and f.priority==0 and f.target==9,'Mind Blown source drift')
  assert(not mod.content.moves:get(M.ID),'foreign Mind Blown owner')
  mod.content.move_effects:register(effect,{kind='full',kascMindBlown67=M.OWNER,
    gate=function(ctx)
      if M.active(ctx.battle,ctx.move)then return true end
      return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')
    end,afterDamage=M.recoil})
  mod.content.moves:register(M.ID,{id=M.ID,name=opts.i18n.text(f.names.en,f.names.de),type='FIRE',category='special',
    power=150,accuracy=100,pp=5,priority=0,target=9,contact=false,effect=effect,
    originGeneration=7,backendMoveNumber=720,backendMoveOwner=M.OWNER,backendLearnsetRevision=28,
    anim=copy(assert(mod.content.moves:get('EXPLOSION')).anim)})
  local anim=copy(assert(mod.content.battle_anims:get('EXPLOSION')));anim.source=M.OWNER
  mod.content.battle_anims:register(M.ID,anim)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if id~=M.ID or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local shift=-16;local sprites={}
      for _,s in ipairs(step.sprites or{})do
        if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end
      end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascMindBlownAnimation67=M
  if not Player._kascMindBlownAnimationWrapped67 then local original=Player.start
    Player.start=function(self,id,...)
      local owner=Player._kascMindBlownAnimation67
      local row=self.data and self.data.moveAnims and self.data.moveAnims[id]
      local source=id==M.ID and row and row.source==M.OWNER and'EXPLOSION'or id
      local result=original(self,source,...);owner.position(self,id);return result
    end
    Player._kascMindBlownAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-hit-and-shared-indirect-damage',
      providerStatus='half-maximum-hp-cost-per-attempt',buildReceiptId='docs/MIND_BLOWN_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
