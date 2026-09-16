-- Passable battle-local recovery; never a permanent saved Pokemon flag.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-ROOT-RECOVERY',OWNER='kasc.root-recovery/v1'}
  local tr=opts.i18n.text
  local defs={INGRAIN={number=275,generation=3,type='GRASS',flag='ingrain',anim='GROWTH'},
    AQUA_RING={number=392,generation=4,type='WATER',flag='aquaRing',anim='BUBBLE'}}
  local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
  local function side(b,w)
    if not b or not w then return end
    if w==b.player or b.player and w.mon==b.player.mon then return'player'end
    if w==b.enemy or b.enemy and w.mon==b.enemy.mon then return'enemy'end
  end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local mark=b and b.data and b.data.move_effects and b.data.move_effects.KA_ROOT_RECOVERY_67_INGRAIN
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch%1==0 and r.activeEpoch>=1 and r.activeEpoch<=7
        and mark and mark.kascRootRecovery67==M.OWNER then return r.activeEpoch end
  end
  function M.row(b,w)
    local list=rows(b);local key=side(b,w);local row=key and list and list[key]
    return M.epoch(b)and w and w.mon and w.mon.hp>0 and row and row.species==w.mon.species and row or nil
  end
  function M.rooted(b,w)local r=M.row(b,w);return r and r.ingrain==true or false end
  function M.grounded(b,w)local gen=M.epoch(b);return gen and gen>=4 and M.rooted(b,w)or false end
  function M.blocked(b,w)
    if not M.rooted(b,w)then return false end
    if M.epoch(b)>=6 then for _,typ in ipairs(w.curTypes or{})do if typ=='GHOST'then return false end end end
    return true
  end
  function M.clear(b,w)
    local list=rows(b);if not list then return end
    if w then local key=side(b,w);if key then list[key]=nil end else b.field.tokens[M.OWNER]=nil end
  end
  function M.transfer(b,old,fresh)
    local key=side(b,fresh);local list=rows(b);local r=key and list and list[key]
    if not M.epoch(b)or not key or b[key]~=fresh or not old or not old.mon or not fresh.mon
        or old.isPlayer~=fresh.isPlayer or not r or r.species~=old.mon.species then return false end
    local passed=copy(r);passed.species=fresh.mon.species;list[key]=passed;return true
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,w,move=ctx.battle,ctx.user,ctx.move;local d=defs[move.id]
    if not d or not M.epoch(b)or not side(b,w)or not w.mon or w.mon.hp<=0 then return failed()end
    local row=M.row(b,w)
    if row and row[d.flag]then return failed()end
    local list=rows(b,true);local key=side(b,w)
    row=row or{species=w.mon.species};row[d.flag]=true;list[key]=row
    return{tr(move.id=='INGRAIN'and'%s planted its roots!'or'%s is surrounded by a water ring!',
      move.id=='INGRAIN'and'%s schlägt Wurzeln!'or'%s umgibt sich mit einem Wasserring!'):format(w.name)}
  end
  function M.noUseful(b,w,t,move)
    local d=move and defs[move.id];local row=d and M.row(b,w)
    return M.epoch(b)and d and move.backendMoveOwner==M.OWNER and row and row[d.flag]==true or false
  end
  function M.residual(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return 0 end
    local turn=ev.turn or b.turnCount or 0
    if type(turn)~='number'or turn%1~=0 or turn<1 or turn~=(b.turnCount or 0)then return 0 end
    local total=0
    for _,key in ipairs({'player','enemy'})do local w=b[key];local r=w and M.row(b,w)
      if r and r.lastTurn~=turn then
        r.lastTurn=turn
        for _,flag in ipairs({'aquaRing','ingrain'})do
          local block=mod.exports.pokemonHealBlock67
          if r[flag]and w.mon.hp>0 and w.mon.hp<w.mon.stats.hp
              and not(block and block.blocksRecovery(b,w,'move'))then
            local amount=math.max(1,math.floor(w.mon.stats.hp/16))
            amount=mod.exports.pokemonStrengthSap67.drainAmount(b,w,amount)
            local hp=w.mon.hp;w.mon.hp=math.min(w.mon.stats.hp,hp+amount);total=total+w.mon.hp-hp
            b:sayNext(tr(flag=='ingrain'and'%s absorbed nutrients with its roots!'or'%s regained HP with Aqua Ring!',
              flag=='ingrain'and'%s nimmt Nährstoffe über seine Wurzeln auf!'or'%s heilt KP mit Wasserring!'):format(w.name))
            b:drainNext()
          end
        end
      end
    end
    return total
  end
  function M.validateCheckpoint(b)
    local list=rows(b);if list==nil then return true end
    if type(list)~='table'then return false,'invalid_root_recovery_container'end
    for key,r in pairs(list)do local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(r)~='table'or r.species~=w.mon.species or not(r.ingrain or r.aquaRing)
          or r.ingrain~=nil and r.ingrain~=true or r.aquaRing~=nil and r.aquaRing~=true
          or r.lastTurn~=nil and(type(r.lastTurn)~='number'or r.lastTurn%1~=0 or r.lastTurn<1
            or r.lastTurn>(b.turnCount or 0))then return false,'invalid_root_recovery_state'end
      for field in pairs(r)do if field~='species'and field~='ingrain'and field~='aquaRing'and field~='lastTurn'then
        return false,'unknown_root_recovery_field'end end
    end
    return true
  end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,d.generation));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.type==d.type and f.category=='status'and f.pp==20 and f.target==7
      and f.alwaysHits and f.priority==0,'root recovery source drift '..id)
    assert(old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign root recovery owner '..id)
    local effect='KA_ROOT_RECOVERY_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascRootRecovery67=M.OWNER,run=M.cast})
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    local anim=copy(assert(mod.content.battle_anims:get(d.anim)));anim.source=M.OWNER
    mod.content.battle_anims:patch(id,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id,isPlayer)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not row or row.source~=M.OWNER then return end
    if id=='AQUA_RING'then
      assert(opts.ringComposer(player,isPlayer),'owned Aqua Ring Bubble geometry changed')
      return
    end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascRootRecoveryAnimation67=M
  if not Player._kascRootRecoveryAnimationWrapped67 then local start=Player.start
    Player.start=function(self,id,isPlayer,...)
      local out=start(self,id,isPlayer,...)
      Player._kascRootRecoveryAnimation67.position(self,id,isPlayer);return out
    end
    Player._kascRootRecoveryAnimationWrapped67=true
  end
  function M.nativeRing(b,player,id,options)
    if id~='AQUA_RING'or options~=nil or not M.epoch(b)or b.animPlayer~=player
        or not player.native then return false end
    local move=b.data.moves and b.data.moves[id]
    local anim=b.data.battle_anims and b.data.battle_anims.moveAnims[id]
    if not move or move.backendMoveOwner~=M.OWNER or not anim or anim.source~=M.OWNER then return false end
    -- Only the flat native battle field needs this bounded composition.
    -- MAP/DISCS/ARENA retain their renderer-owned presentation and settings.
    local compat=mod.exports.voxelRendererCompat
    local stage=compat and compat.module(b.game,'OverworldBattle')
    if stage and (type(stage.enabled)~='function'or stage.enabled())then return false end
    return true
  end
  function M.bindPresentation(b)
    if not M.epoch(b)or not b.animPlayer or type(b.animPlayer.start)~='function'then return end
    local player=b.animPlayer
    local binding=rawget(player,'_kascRootPresentation67')
    if binding then binding.owner=M;binding.battle=b;return end
    binding={owner=M,battle=b,start=player.start};player._kascRootPresentation67=binding
    player.start=function(self,id,isPlayer,options,...)
      local held=self._kascRootPresentation67
      if held.owner.nativeRing(held.battle,self,id,options)then
        -- Public AnimPlayer opts select the native-special lane. The extra
        -- owner tag is ignored by the native compiler; ball/presentation opts
        -- supplied by another caller are never replaced.
        options={kascNativeAnimation=held.owner.OWNER}
      end
      return held.start(self,id,isPlayer,options,...)
    end
  end
  mod.events:on('battle.started',function(ev)M.bindPresentation(ev.battle)end,-10000)
  mod.events:on('battle.turn_ended',M.residual,-40)
  mod.events:on('battle.battler_switched',function(ev)
    local list=rows(ev.battle);local key=side(ev.battle,ev.battler);local row=key and list and list[key]
    if row and not(ev.sourceCard=='KASC-67-BATON-PASS'and ev.previous and row.species==ev.battler.mon.species)then list[key]=nil end
  end,10000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,10000)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-residual-trapping-and-grounding',providerStatus='passable-root-and-water-ring-recovery',
    buildReceiptId='docs/ROOT_RECOVERY_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})end
  return M
end
