-- Baton Pass uses the native PartyMenu provider and the shared no-extra-turn
-- replacement seam. Only explicitly owned, source-passable volatiles move.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-BATON-PASS',OWNER='kasc.baton-pass/v1',ID='BATON_PASS'}
  local effect='KA_BATON_PASS_67';local tr=opts.i18n.text
  local pending=setmetatable({},{__mode='k'})
  local transfers=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function living(w)
    local p=w and w.mon
    return p and type(p.hp)=='number'and p.hp>0 and not w.fainted
      and not(p.isEgg or p.is_egg or p.egg or p.eggSpecies or p.status=='EGG'
        or p.species=='EGG'or p.species=='POKEMON_EGG')
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and not b.result and b.kind~='link'
        and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch%1==0
        and r.activeEpoch>=1 and r.activeEpoch<=7 and marker and marker.kascBatonPass67==M.OWNER then return r.activeEpoch end
  end
  function M.active(b,move)
    return M.epoch(b)and move and move.id==M.ID and move.backendMoveOwner==M.OWNER or false
  end
  function M.isPending(w)return pending[w]==true end
  function M.candidates(b,w)
    if not M.epoch(b)or not living(w)or not side(b,w)then return{}end
    local party=w==b.player and b:playerPartyView()or b.kind=='trainer'and b.enemyParty or{}
    local out={}
    local follower=require('src.world.PikachuFollower')
    for index,p in ipairs(party or{})do
      local unavailable=w==b.player and follower.isFollowingDisabled(b.game.overworld)
        and follower.isStarterPikachu(b.game.save,p)
      if p~=w.mon and living({mon=p})and b.data.pokemon[p.species]and not unavailable then
        out[#out+1]={mon=p,index=index}
      end
    end
    return out
  end
  function M.noUseful(b,u,t,move)
    return M.active(b,move)and(not living(u)or not side(b,u)or pending[u]or #M.candidates(b,u)==0)or false
  end
  -- Selection considers this trainer's real healthy reserves, their own PP,
  -- their attack's matchup and the passable offensive boosts. No new roster.
  function M.enemyPick(b,w)
    local foe=w==b.enemy and b.player or b.enemy
    local chart=b.data.type_chart and b.data.type_chart.matchups or{}
    local function matchup(typ,types)
      local value=1
      for _,row in ipairs(chart)do if row.attacker==typ then
        for _,targetType in ipairs(types or{})do if row.defender==targetType then value=value*row.multiplier/10;break end end
      end end
      return value
    end
    local best,score
    for _,pick in ipairs(M.candidates(b,w))do
      local p=pick.mon;local damage=0
      for _,slot in ipairs(p.moves or{})do local move=b.data.moves[slot.id]
        local unlimited=w==b.enemy and M.epoch(b)==1 and b.ruleset and b.ruleset.enemyUnlimitedPP
        if move and(unlimited or(slot.pp or 0)>0)and move.category~='status'and(move.power or 0)>0
            and not(move.effect or''):find('UNSUPPORTED',1,true)then
          local category=move.category
          if M.epoch(b)<=3 then local typ=b.data.type_chart.types and b.data.type_chart.types[move.type];category=typ and typ.category or category end
          local boost=(w.stages or{})[category=='special'and(M.epoch(b)==1 and'special'or'specialAttack')or'attack']or 0
          local value=move.power*matchup(move.type,foe and foe.curTypes)*(boost>=0 and(2+boost)/2 or 2/(2-boost))
          if value>damage then damage=value end
        end
      end
      local value=p.hp/math.max(1,p.stats and p.stats.hp or p.hp)*100+math.min(200,damage)/2
      if not best or value>score then best,score=pick,value end
    end
    return best
  end
  -- Owner callbacks clear these side tokens at priority 8000. Restore only
  -- whitelisted snapshots at 7999, before entry abilities and entry hazards.
  -- Side screens/weather/terrain are not battler volatiles and stay in place.
  local providers={
    {name='pokemonMoveRestrictions67',fields={'applied','expires'}},
    {name='pokemonHealBlock67',fields={'applied','expires'}},
    {name='pokemonLaserFocus67',fields={'applied','expires','species'},species=true},
    {name='pokemonThroatChop67',fields={'applied','expires'}},
    {name='pokemonGrounding67',fields={'rise','tele'}},
    {name='pokemonProtection67',fields={'move','lastTurn','guardTurn','count'}},
  }
  local stageKeys={'attack','defense','speed','accuracy','evasion'}
  local function snapshot(b,old,new,key)
    local gen=M.epoch(b);local stages={}
    for _,stat in ipairs(stageKeys)do if old.stages and old.stages[stat]~=nil then stages[stat]=old.stages[stat]end end
    -- Gen-I's Special is a single stage, not two independently copied stats.
    if gen==1 then stages.special=old.stages and old.stages.special
    else for _,stat in ipairs({'specialAttack','specialDefense'})do stages[stat]=old.stages and old.stages[stat]end end
    new.stages=stages
    for _,field in ipairs({'substituteHP','confusedTurns','focusEnergy','leechSeeded','mist'})do new[field]=old[field]end
    if gen==1 then new.reflect=old.reflect;new.lightScreen=old.lightScreen end
    local saved={key=key,previous=old,battler=new,tokens={}}
    local tokens=b.field and b.field.tokens or{}
    for _,spec in ipairs(providers)do
      local owner=mod.exports[spec.name];local row=owner and tokens[owner.OWNER]and tokens[owner.OWNER][key]
      if type(row)=='table'then local chosen={}
        for _,field in ipairs(spec.fields)do if row[field]~=nil then chosen[field]=copy(row[field])end end
        if spec.species then chosen.species=new.mon.species end
        if next(chosen)then saved.tokens[owner.OWNER]=chosen end
      end
    end
    -- GenII-IV permit both trapper and trapped links to cross Baton Pass.
    -- From V these permanent traps are noCopy; ability traps are never copied.
    local locks=mod.exports.pokemonEscapeLock67
    local rows=locks and tokens[locks.OWNER]
    if gen<=4 and type(rows)=='table'then
      saved.escapeOwner=locks.OWNER;saved.escape={}
      for target,row in pairs(rows)do
        if(target==key or row.source==key)and(row.move=='MEAN_LOOK'or row.move=='SPIDER_WEB'or row.move=='BLOCK')then
          saved.escape[target]=copy(row)
        end
      end
    end
    -- Binding damage follows the affected Pokemon's position. Its original
    -- user leaving instead releases the opposing target: never copy its link.
    local partial=mod.exports.backendPartialTrapping67
    local row=partial and tokens[partial.OWNER]and tokens[partial.OWNER][key]
    if type(row)=='table'then saved.partialOwner=partial.OWNER;saved.partial=copy(row)end
    local roots=mod.exports.pokemonRootRecovery67
    if roots then roots.transfer(b,old,new)end
    local control=mod.exports.pokemonAbilityControl67
    if control then control.transfer(b,old,new)end
    local trick=mod.exports.pokemonPowerTrick67
    if trick then trick.transfer(b,old,new)end
    local fatal=mod.exports.pokemonFatalConditions67
    if fatal then fatal.transfer(b,old,new)end
    local itemAccess=mod.exports.pokemonItemAccess67
    if itemAccess then itemAccess.transfer(b,old,new)end
    transfers[b]=saved
  end
  function M.restore(ev,late)
    local b=ev and ev.battle;local saved=b and transfers[b]
    if not saved or ev.sourceCard~=M.CARD_ID or ev.previous~=saved.previous
        or ev.battler~=saved.battler or b[saved.key]~=saved.battler then return end
    b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    local tokens=b.field.tokens
    if not late then
      for owner,row in pairs(saved.tokens)do tokens[owner]=tokens[owner]or{};tokens[owner][saved.key]=row end
      if saved.escapeOwner then tokens[saved.escapeOwner]=tokens[saved.escapeOwner]or{}
        for target,row in pairs(saved.escape)do tokens[saved.escapeOwner][target]=row end
      end
    else
      if saved.partial then tokens[saved.partialOwner]=tokens[saved.partialOwner]or{};tokens[saved.partialOwner][saved.key]=saved.partial end
      transfers[b]=nil
    end
  end
  function M.commit(b,w,pick)
    if not M.epoch(b)or not living(w)or not side(b,w)then return false end
    local present=false;for _,row in ipairs(M.candidates(b,w))do if row.mon==pick.mon and row.index==pick.index then present=true;break end end
    if not present then return false end
    local key=side(b,w);local F=assert(mod.exports.pokemonForcedSwitch67);local prepared=false
    local ok,result,deferred=pcall(F.swap,b,w,pick,{voluntary=true,sourceCard=M.CARD_ID,prepare=function(battle,old,fresh)
      assert(battle==b and old==w and fresh.mon==pick.mon and b[key]==fresh,'Baton Pass replacement identity')
      snapshot(b,w,fresh,key);prepared=true
      local body=mod.exports.pokemonBodyUtilities67
      if body then body.prepareTransfer(b,w,fresh)end
      local sports=mod.exports.pokemonSports67
      if sports then sports.prepareTransfer(b,w,fresh)end
    end})
    transfers[b]=nil
    if not ok then error(result,0)end
    assert(not result or prepared or deferred,'Baton Pass needs prepare-before-entry switch seam')
    return result
  end
  function M.choose(b,w,mon,menu)
    if not pending[w]or not M.epoch(b)or not living(w)or not side(b,w)then
      pending[w]=nil;if menu then menu:close()end;return false
    end
    local pick;for _,row in ipairs(M.candidates(b,w))do if row.mon==mon then pick=row;break end end
    if not pick then
      if menu and menu.refuse then menu:refuse(tr('Choose another healthy Pokemon.','Wähle ein anderes kampffähiges Pokémon.'))end
      return false
    end
    pending[w]=nil;if menu then menu:close()end
    b.nextInsert=0
    return M.commit(b,w,pick)
  end
  function M.openChoice(b,w)
    b:uiNext(function()
      return b:buildScreen('PartyMenu',{battle=b,party=b:playerPartyView(),forceSwitch=true,keepOpen=true,
        onSwitch=function(mon,menu)return M.choose(b,w,mon,menu)end,
        onCancel=function()
          b.nextInsert=0
          if pending[w]and M.epoch(b)and living(w)and side(b,w)and #M.candidates(b,w)>0 then M.openChoice(b,w)
          else pending[w]=nil end
        end})
    end)
  end
  function M.cast(ctx)
    local b,w,move=ctx.battle,ctx.user,ctx.move
    if not M.active(b,move)or not living(w)or not side(b,w)or pending[w]or #M.candidates(b,w)==0 then
      b:cancelMoveAnim();b:sayNext(tr('But, it failed!','Doch es schlug fehl!'));return false
    end
    pending[w]=true
    b:actNext(function()
      if not M.epoch(b)or not living(w)or not side(b,w)or #M.candidates(b,w)==0 then pending[w]=nil;return end
      if w==b.enemy then local pick=M.enemyPick(b,w);if pick then M.choose(b,w,pick.mon)else pending[w]=nil end
      else M.openChoice(b,w)end
    end)
    return true
  end
  function M.validateCheckpoint(b)
    if transfers[b]or pending[b.player]or pending[b.enemy]then return false,'unsettled_baton_pass_choice'end
    return true
  end
  local fact=assert(opts.facts.move(M.ID,2));local old=assert(mod.content.moves:get(M.ID))
  assert(fact.number==226 and fact.type=='NORMAL'and fact.category=='status'and fact.pp==40
    and fact.target==7 and fact.alwaysHits and fact.priority==0,'Baton Pass source drift')
  assert(old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..M.ID,'foreign Baton Pass owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascBatonPass67=M.OWNER,perform=M.cast})
  for _,alias in ipairs(opts.species.moveIds(M.ID))do if mod.content.moves:get(alias)then
    mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,backendLearnsetRevision=old.backendLearnsetRevision or 1})
  end end
  local animation=copy(assert(mod.content.battle_anims:get('FOCUS_ENERGY')));animation.source=M.OWNER
  mod.content.battle_anims:patch(M.ID,animation)
  if opts.catalog then for i=#opts.catalog.unsupportedStatus,1,-1 do
    if opts.catalog.unsupportedStatus[i]==M.ID then table.remove(opts.catalog.unsupportedStatus,i)end
  end end
  mod.events:on('battle.battler_switched',function(ev)M.restore(ev,false)end,7999)
  mod.events:on('battle.battler_switched',function(ev)M.restore(ev,true)end,-1)
  mod.events:on('battle.ended',function(ev)
    transfers[ev.battle]=nil;pending[ev.battle.player]=nil;pending[ev.battle.enemy]=nil
  end,80)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-party-provider-and-prepare-before-entry-switch',providerStatus='single-battle-passable-stages-and-owned-volatiles',
    buildReceiptId='docs/BATON_PASS_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})end
  return M
end
