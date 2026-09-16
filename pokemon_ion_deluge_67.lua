-- Ion Deluge and Plasma Fists share one turn-local field, not an Electric
-- Terrain alias. Move conversion stays in the common projection pipeline.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-ION-DELUGE',OWNER='kasc.ion-deluge/v1'}
  local specs={ION_DELUGE={number=569,generation=6,category='status',power=0,pp=25,priority=1,target=12,anim='THUNDER'},
    PLASMA_FISTS={number=721,generation=7,category='physical',power=100,pp=15,priority=0,target=10,anim='THUNDERPUNCH'}}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function row(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  function M.enabled(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.KA_ION_DELUGE_67
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and r.activeEpoch>=1 and r.activeEpoch<=7
      and marker and marker.kascIonDeluge67==M.OWNER
  end
  function M.active(b)
    local r=row(b);return M.enabled(b)and type(r)=='table'and r.turn==(b.turnCount or 0)or false
  end
  function M.start(b)
    if not M.enabled(b)or M.active(b)then return false end
    b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    b.field.tokens[M.OWNER]={turn=b.turnCount or 0}
    b:sayNext(opts.i18n.text('Normal moves become Electric this turn!','Normal-Attacken werden diese Runde zu Elektro!'))
    return true
  end
  function M.clear(b)if row(b)then b.field.tokens[M.OWNER]=nil end end
  function M.validateCheckpoint(b)
    local r=row(b);if r==nil then return true end
    if type(r)~='table'or type(r.turn)~='number'or r.turn%1~=0 or r.turn<0
        or r.turn>(b.turnCount or 0)then return false,'invalid_ion_deluge_turn'end
    for k in pairs(r)do if k~='turn'then return false,'invalid_ion_deluge_field'end end
    return true
  end
  function M.afterHit(ctx)
    if ctx.move.id~='PLASMA_FISTS'or ctx.move.backendMoveOwner~=M.OWNER
        or ctx.target.substituteHP or ctx.brokeSub then return end
    -- Native hit pipeline already rejected Protect, miss and immunity.
    -- A KO/Endure hit still creates the field; this is not a secondary roll.
    M.start(ctx.battle)
  end
  function M.noUseful(b,u,t,move)
    return move and move.id=='ION_DELUGE'and move.backendMoveOwner==M.OWNER and M.active(b)
  end
  mod.content.move_effects:register('KA_ION_DELUGE_67',{kind='primary',accuracyChecked=false,kascIonDeluge67=M.OWNER,
    run=function(ctx)
      if ctx.move.backendMoveOwner==M.OWNER and ctx.user.mon.hp>0 and M.start(ctx.battle)then
        ctx.anim(ctx.move.id);return{}
      end
      return{opts.i18n.text('But, it failed!','Doch es schlug fehl!'),failed=true}
    end})
  mod.content.move_effects:register('KA_PLASMA_FISTS_67',{kind='full',kascIonDeluge67=M.OWNER,
    gate=function(ctx)
      if M.enabled(ctx.battle)and ctx.move.backendMoveOwner==M.OWNER then return true end
      return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')
    end,afterDamage=M.afterHit})
  for _,id in ipairs({'ION_DELUGE','PLASMA_FISTS'})do
    local s=specs[id];local f=assert(opts.facts.move(id,s.generation));local old=mod.content.moves:get(id)
    assert(f.number==s.number and f.type=='ELECTRIC'and f.category==s.category and f.power==s.power
      and f.pp==s.pp and f.priority==s.priority and f.target==s.target,'ion source drift '..id)
    assert(not old or id=='ION_DELUGE'and old.effect=='KA_GEN_MOVE_UNSUPPORTED_ION_DELUGE','foreign ion owner '..id)
    local fields={id=id,name=opts.i18n.text(f.names.en,f.names.de),type='ELECTRIC',category=s.category,
      power=s.power,accuracy=100,pp=s.pp,priority=s.priority,target=s.target,
      effect=id=='ION_DELUGE'and'KA_ION_DELUGE_67'or'KA_PLASMA_FISTS_67',
      contact=id=='PLASMA_FISTS',punch=id=='PLASMA_FISTS',originGeneration=s.generation,
      backendMoveNumber=s.number,backendMoveOwner=M.OWNER,backendLearnsetRevision=old and(old.backendLearnsetRevision or 1)or 26,
      anim=copy(assert(mod.content.moves:get(s.anim)).anim)}
    if old then mod.content.moves:patch(id,fields)else mod.content.moves:register(id,fields)end
    local anim=copy(assert(mod.content.battle_anims:get(s.anim)));anim.source=M.OWNER
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,anim)else mod.content.battle_anims:register(id,anim)end
  end
  for i=#opts.catalog.unsupportedStatus,1,-1 do
    if opts.catalog.unsupportedStatus[i]=='ION_DELUGE'then table.remove(opts.catalog.unsupportedStatus,i)end
  end
  mod.events:on('battle.turn_ended',function(ev)M.clear(ev.battle)end,95)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,95)
  -- Effect OAM only: keep electric bursts out of name/HP/text boxes.
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,move)
    local r=player.data and player.data.moveAnims and player.data.moveAnims[move]
    if not specs[move]or not r or r.source~=M.OWNER then return end
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
  Player._kascIonDelugeAnimation67=M
  function M.animationId(player,move)
    local r=player.data and player.data.moveAnims and player.data.moveAnims[move]
    -- Use the source's complete native lightning sequence, not Thunderbolt's
    -- mostly orb-shaped charge. The logical move and rules stay Ion Deluge.
    if move=='ION_DELUGE'and r and r.source==M.OWNER then return specs[move].anim end
    return move
  end
  if not Player._kascIonDelugeAnimationWrapped67 then local start=Player.start
    Player.start=function(self,move,...)
      local owner=Player._kascIonDelugeAnimation67
      local result=start(self,owner.animationId(self,move),...);owner.position(self,move);return result
    end
    Player._kascIonDelugeAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-hit-and-shared-type-projection',
      providerStatus='one-turn-normal-to-electric',buildReceiptId='docs/ION_DELUGE_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
