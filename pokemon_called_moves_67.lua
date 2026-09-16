-- Called attacks keep their genuine outer AP slot and never become learned slots.
return function(mod,opts)
  local B=require('src.battle.BattleState');local CP=require('src.core.BattleCheckpoint')
  local Player=require('src.battle.AnimPlayer');local Map=require('src.world.Map')
  local M={CARD_ID='KASC-67-CALLED-MOVES',OWNER='kasc.called-moves/v1'}
  local tr=opts.i18n.text;local Damage=assert(opts.damage)
  local defs={NATURE_POWER={number=267,gen=3,target=10},ASSIST={number=274,gen=3,target=7},
    COPYCAT={number=383,gen=4,target=7},ME_FIRST={number=382,gen=4,target=10}}
  local frames=setmetatable({},{__mode='k'});local previews=setmetatable({},{__mode='k'})
  local capturing=setmetatable({},{__mode='k'});local depth=setmetatable({},{__mode='k'})
  local currentFrame
  local sources={};for id,f in pairs(opts.facts.data.moves)do for _,alias in ipairs(opts.species.moveIds(id))do sources[alias]=id end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local m=w and w.mon;return m and(tonumber(m.hp)or 0)>0 and not w.fainted
    and not(m.isEgg or m.egg or m.is_egg or m.eggSpecies)end
  local function side(b,w)return w and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function party(b,key,scope)
    if key~='player'and key~='enemy'then return end
    if key=='player'then return scope and b:playerPartyView()or b.game.save.party end
    return b.kind=='wild'and{b.enemy.mon}or b.enemyParty
  end
  local function index(b,w)local key=side(b,w);for i,m in ipairs(party(b,key)or{})do if i<=6 and m==w.mon then return i end end end
  local function locate(b,mon)
    for _,key in ipairs({'player','enemy'})do for i,m in ipairs(party(b,key)or{})do if i<=6 and m==mon then return key,i end end end
  end
  local function slotIndex(w,slot)for i,s in ipairs(w and w.curMoves or{})do if i<=4 and s==slot then return i end end end
  local function named(w,id)for _,s in ipairs(w and w.curMoves or{})do if s.id==id then return s end end end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{charges={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local mark=b and b.data and b.data.move_effects and b.data.move_effects.KA_CALLED_67_ASSIST
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or not integer(r.activeEpoch,1,7)or not mark or mark.kascCalledMoves67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local d=defs[move.id];local record=d and b.data.move_effects[move.effect]
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
        or not record or record.kascCalledMoves67~=M.OWNER then return end
    if r.activeEpoch<d.gen and not(live(u)and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(r.activeEpoch,d.gen)
  end
  -- Primary source: pinned Showdown base plus VII→III flag replacements.
  local forbidden={}
  forbidden[3]={}
  forbidden[3].ASSIST={[68]=true,[102]=true,[118]=true,[119]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[243]=true,[264]=true,[266]=true,[270]=true,[271]=true,[274]=true,[289]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[566]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[3].COPYCAT={[68]=true,[118]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[264]=true,[266]=true,[270]=true,[271]=true,[289]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[3].ME_FIRST={[68]=true,[168]=true,[243]=true,[264]=true,[382]=true,[448]=true,[562]=true,[690]=true,[704]=true}
  forbidden[4]={}
  forbidden[4].ASSIST={[68]=true,[102]=true,[118]=true,[119]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[243]=true,[264]=true,[266]=true,[270]=true,[271]=true,[274]=true,[289]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[566]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[4].COPYCAT={[68]=true,[102]=true,[118]=true,[119]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[264]=true,[266]=true,[270]=true,[271]=true,[274]=true,[289]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[4].ME_FIRST={[68]=true,[165]=true,[168]=true,[243]=true,[264]=true,[343]=true,[382]=true,[448]=true,[562]=true,[690]=true,[704]=true}
  forbidden[5]={}
  forbidden[5].ASSIST={[68]=true,[102]=true,[118]=true,[119]=true,[144]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[243]=true,[264]=true,[266]=true,[267]=true,[270]=true,[271]=true,[274]=true,[289]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[566]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[5].COPYCAT={[68]=true,[102]=true,[118]=true,[119]=true,[144]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[264]=true,[266]=true,[267]=true,[270]=true,[271]=true,[274]=true,[289]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[5].ME_FIRST={[68]=true,[165]=true,[168]=true,[243]=true,[264]=true,[343]=true,[368]=true,[382]=true,[448]=true,[562]=true,[690]=true,[704]=true}
  forbidden[6]={}
  forbidden[6].ASSIST={[18]=true,[19]=true,[46]=true,[68]=true,[91]=true,[102]=true,[118]=true,[119]=true,[144]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[243]=true,[264]=true,[266]=true,[267]=true,[270]=true,[271]=true,[274]=true,[289]=true,[291]=true,[340]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[467]=true,[476]=true,[507]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[566]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[6].COPYCAT={[18]=true,[46]=true,[68]=true,[102]=true,[118]=true,[119]=true,[144]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[264]=true,[266]=true,[267]=true,[270]=true,[271]=true,[274]=true,[289]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[6].ME_FIRST={[68]=true,[165]=true,[168]=true,[243]=true,[264]=true,[343]=true,[368]=true,[382]=true,[562]=true,[690]=true,[704]=true}
  forbidden[7]={}
  forbidden[7].ASSIST={[18]=true,[19]=true,[46]=true,[68]=true,[91]=true,[102]=true,[118]=true,[119]=true,[144]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[243]=true,[264]=true,[266]=true,[267]=true,[270]=true,[271]=true,[274]=true,[289]=true,[291]=true,[340]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[467]=true,[476]=true,[507]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[566]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[7].COPYCAT={[18]=true,[46]=true,[68]=true,[102]=true,[118]=true,[119]=true,[144]=true,[165]=true,[166]=true,[168]=true,[182]=true,[194]=true,[197]=true,[203]=true,[214]=true,[264]=true,[266]=true,[267]=true,[270]=true,[271]=true,[274]=true,[289]=true,[343]=true,[364]=true,[382]=true,[383]=true,[415]=true,[448]=true,[476]=true,[509]=true,[516]=true,[525]=true,[561]=true,[562]=true,[588]=true,[596]=true,[606]=true,[607]=true,[661]=true,[671]=true,[690]=true,[704]=true}
  forbidden[7].ME_FIRST={[68]=true,[165]=true,[168]=true,[243]=true,[264]=true,[343]=true,[368]=true,[382]=true,[562]=true,[690]=true,[704]=true}
  local environments={grass=true,long_grass=true,sand=true,underwater=true,water=true,pond=true,mountain=true,cave=true,
    building=true,plain=true,snow=true,ice=true,marsh=true,bridge=true}
  local function terrain(b)local t=mod.exports.pokemonTerrain67;return t and t.current(b)end
  function M.environment(b)
    local r=state(b);if r and r.environment then return r.environment.kind end
    local ow=b.game and b.game.overworld;local map=ow and ow.map;local pos=ow and ow.player
    local mapId=b.checkpointOrigin and b.checkpointOrigin.map
    local def=map and map.def or mapId and b.data.maps[mapId]
    if map and mapId and map.id~=mapId then map=nil;pos=nil;def=b.data.maps[mapId]end
    local set=def and b.data.tilesets[def.tileset]
    if def and environments[def.battleEnvironment]then return def.battleEnvironment end
    if def and set and pos and integer(pos.cellX,0,10000)and integer(pos.cellY,0,10000)then
      -- The host has no sea/pond region discriminator. Water is an actual
      -- collision-tile observation; explicit authored environments can
      -- distinguish pond/underwater without guessing a region schema.
      if Map.defIsWaterCell(def,set,pos.cellX,pos.cellY)then return'water'end
      local tile=Map.defCellTile(def,set,pos.cellX,pos.cellY)
      if tile~=nil and(tile==set.grassTile or type(set.grassTiles)=='table'and(function()for _,v in ipairs(set.grassTiles)do if v==tile then return true end end end)())then return'grass'end
    end
    local tileset=def and def.tileset
    if tileset=='CAVERN'then return'cave'elseif tileset=='PLATEAU'then return'mountain'
    elseif tileset=='OVERWORLD'then return'plain'end
    return'building'
  end
  function M.natureMove(b,epoch)
    local kind=terrain(b)
    if epoch>=6 and kind then return({electric='THUNDERBOLT',grassy='ENERGY_BALL',misty='MOONBLAST',psychic='PSYCHIC_M'})[kind]end
    local env=M.environment(b)
    if env=='grass'then return epoch>=6 and'ENERGY_BALL'or epoch>=4 and'SEED_BOMB'or'STUN_SPORE'
    elseif env=='long_grass'then return epoch>=6 and'ENERGY_BALL'or epoch>=4 and'SEED_BOMB'or'RAZOR_LEAF'
    elseif env=='sand'then return epoch>=6 and'EARTH_POWER'or'EARTHQUAKE'
    elseif env=='underwater'then return'HYDRO_PUMP'
    elseif env=='water'then return epoch>=4 and'HYDRO_PUMP'or'SURF'
    elseif env=='pond'then return epoch>=4 and'HYDRO_PUMP'or'BUBBLE_BEAM'
    elseif env=='mountain'then return epoch>=6 and'EARTH_POWER'or epoch>=5 and'EARTHQUAKE'or'ROCK_SLIDE'
    elseif env=='cave'then return epoch>=6 and'POWER_GEM'or epoch>=4 and'ROCK_SLIDE'or'SHADOW_BALL'
    elseif env=='plain'then return epoch>=6 and'TRI_ATTACK'or epoch>=4 and'EARTHQUAKE'or'SWIFT'
    elseif env=='snow'then return epoch>=7 and'ICE_BEAM'or epoch==6 and'FROST_BREATH'or'BLIZZARD'
    elseif env=='ice'then return'ICE_BEAM'elseif env=='marsh'then return'MUD_BOMB'elseif env=='bridge'then return'AIR_SLASH'end
    return epoch>=4 and'TRI_ATTACK'or'SWIFT'
  end
  local function fact(move)return move and opts.facts.data.moves[sources[move.id]or move.id]end
  local function definition(b,id)
    if b.data.moves[id]then return b.data.moves[id]end
    for _,alias in ipairs(opts.species.moveIds(id))do if b.data.moves[alias]then return b.data.moves[alias]end end
  end
  local function calledTarget(u,t,move)
    local f=fact(move);local target=move and(move.target or f and f.target)
    if target==3 or target==17 or not target then return end
    return(target==4 or target==5 or target==7 or target==13 or target==15)and u or t
  end
  function M.callable(b,kind,epoch,move,source,intrinsic)
    local f=fact(move);local rec=move and b:effectRecord(move.effect)
    if not f or f.generation>7 or not rec or move.effect:find('UNSUPPORTED',1,true)
        or move.isZ or move.isMax or move.isZOrMaxPowered or f.number>=622 and f.number<=658
        or f.number>=695 and f.number<=703 or f.number==719 or f.number>=723 and f.number<=728 then return false end
    local era=math.max(epoch,f.generation);local denied=forbidden[era]and forbidden[era][kind]
    if denied and denied[f.number]then return false end
    if intrinsic then return opts.rules.moveAvailable(move.id,epoch,b.data)end
    local raw=M.epoch(b);if not raw or not source then return false end
    return opts.rules.monMoveAvailable(b.game,source,move.id,raw,true)
  end
  function M.assistPool(b,u,epoch)
    local out={}
    for _,mon in ipairs(party(b,side(b,u),true)or{})do
      if mon~=u.mon and not(mon.isEgg or mon.egg or mon.is_egg or mon.eggSpecies)then
        for _,slot in ipairs(mon.moves or{})do local move=b:moveDef(slot)
          if M.callable(b,'ASSIST',epoch,move,mon)and calledTarget(u,b[u==b.player and'enemy'or'player'],move)then
            local heal=mod.exports.pokemonHealBlock67;local grounding=mod.exports.pokemonGrounding67
            local blocked=epoch==4 and(heal and heal.moveBlocked(b,u,move,calledTarget(u,b[u==b.player and'enemy'or'player'],move))
              or grounding and grounding.gravity(b)and grounding.blockedMove(b,u,move))
            if not blocked then out[#out+1]={move=move,mon=mon}end
          end
        end
      end
    end
    return out
  end
  local function actualAction(b,w,action)
    if not action or action.struggle then return end
    if action.special then
      if action.special=='bide'then return named(w,'BIDE')
      elseif action.special=='trapping'and type(w.trapMove)=='string'then return named(w,w.trapMove)end
      return
    end
    return slotIndex(w,action)and action or named(w,action.id)
  end
  function M.pending(b,w)
    local r=state(b);local row=r and r.pending and r.pending[side(b,w)]
    if row and row.turn==(b.turnCount or 0)and row.species==w.mon.species and row.party==index(b,w)then
      local slot=w.curMoves[row.slot];if slot and slot.id==row.move then
        local lock=mod.exports.pokemonMoveLock67;return lock and lock.override(b,w,slot)or slot
      end
    end
    local preview=previews[b]
    if preview and w==b.player and preview.mon==w.mon then return actualAction(b,w,preview.action)end
  end
  function M.plan(b,u,t,move)
    local epoch=M.epoch(b,u,move);if not epoch or not live(u)or not live(t)or not side(b,u)or not side(b,t)then return end
    local selected,source
    if move.id=='NATURE_POWER'then
      local id=M.natureMove(b,epoch);selected=definition(b,id)
      if not M.callable(b,'NATURE_POWER',epoch,selected,u.mon,true)then return end
    elseif move.id=='ASSIST'then return M.assistPool(b,u,epoch)
    elseif move.id=='COPYCAT'then
      local f=frames[b];local row=f and f.previousHistory or state(b)and state(b).history
      if not row then return end
      local mons=party(b,row.side);source=mons and mons[row.party]
      if not source or source.species~=row.species then return end
      selected=b.data.moves[row.move]
      if not M.callable(b,'COPYCAT',epoch,selected,source)then return end
      if epoch==4 then
        local heal=mod.exports.pokemonHealBlock67;local grounding=mod.exports.pokemonGrounding67
        if heal and heal.moveBlocked(b,u,selected,calledTarget(u,t,selected))
            or grounding and grounding.gravity(b)and grounding.blockedMove(b,u,selected)then return end
      end
    else
      if u==t or t.mustRecharge then return end
      local slot=M.pending(b,t);selected=slot and b:moveDef(slot);source=t.mon
      if not selected or selected.category=='status'or not M.callable(b,'ME_FIRST',epoch,selected,source)then return end
    end
    local target=calledTarget(u,t,selected);if not target then return end
    return{move=selected,target=target,epoch=epoch,source=source}
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,u,move)then return false end
    if move.id=='ME_FIRST'and not M.pending(b,t)then return false end -- unknown before a real queued action
    local p=M.plan(b,u,t,move);return not p or move.id=='ASSIST'and#p==0
  end
  function M.pick(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local p=M.plan(b,u,t,move)
    if move.id=='ME_FIRST'then
      local protection=assert(mod.exports.pokemonProtection67)
      if protection.blocks(ctx)then b:sayNext(protection.notice(ctx,true));return end
    end
    local priority=mod.exports.pokemonPriorityAbilities67
    if priority and priority.blocks(ctx)then b:sayNext(tr('The priority move was blocked!','Die Prioritäts-Attacke wurde blockiert!'));return end
    if p and move.id=='ASSIST'then
      local choice=#p>0 and p[ctx.rng(1,#p)]
      p=choice and{move=choice.move,source=choice.mon,target=calledTarget(u,t,choice.move),epoch=M.epoch(b,u,move)}
    end
    local f=frames[b]
    if not p or not f or f.user~=u or f.move.id~=move.id then b:sayNext(tr('But, it failed!','Doch es schlug fehl!'));return end
    if move.id=='NATURE_POWER'and not state(b,true).environment then
      state(b,true).environment={kind=M.environment(b),map=b.checkpointOrigin and b.checkpointOrigin.map}
    end
    f.plan=p;f.plan.meFirst=move.id=='ME_FIRST'
    local key,i=locate(b,p.source or u.mon)
    if key then f.plan.license={kind=move.id,move=p.move.id,side=key,party=i,species=(p.source or u.mon).species,epoch=p.epoch}end
    return p.move.id
  end
  -- Only a genuine synchronous native child can borrow its observed
  -- source's gift availability. This is NOT a tutor/learnset or global
  -- unlock. The shared rule owner consults it lazily after ordinary
  -- availability failed; outside this exact dispatch it returns false.
  function M.permission(game,mon,id,epoch,extensions)
    local f=currentFrame;local h=f and f.license;local b=f and f.battle
    if extensions==false or not h or f.checking or not b or b.game~=game or f.user.mon~=mon
        or f.move.id~=id or h.move~=id or epoch~=f.profile or not defs[h.kind]
        or not(f.called or f.continuation)or not M.epoch(b)then return false end
    local ps=party(b,h.side);local source=ps and ps[h.party]
    if not source or source.species~=h.species or h.epoch~=math.max(epoch,defs[h.kind].gen)
        or not M.epoch(b,f.user,b.data.moves[h.kind])then return false end
    if h.kind=='NATURE_POWER'then return opts.rules.moveAvailable(id,h.epoch,b.data)end
    f.checking=true;local out=pack(pcall(opts.rules.monMoveAvailable,game,source,id,epoch,true));f.checking=nil
    return out[1]and out[2]==true or false
  end
  local function integrity(row)local r=copy(row);r.proof=nil;return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(r))end
  local function saveCharge(b,u,slot,frame)
    if slotIndex(u,slot)or u.charging~=slot or not u.chargeReady or not frame.called or not frame.caller then return end
    local parent=frame.caller;local own=parent.slot and slotIndex(u,parent.slot)
    while parent and not own do parent=parent.caller;own=parent and parent.slot and slotIndex(u,parent.slot)end
    local caller=parent and b:effectRecord(parent.move.effect)
    if not own or not parent.used or not caller or type(caller.callsMove)~='function'or not fact(frame.move)then return end
    local row={move=slot.id,caller=parent.move.id,callerSlot=own,species=u.mon.species,party=index(b,u),
      profile=M.epoch(b),epoch=math.max(M.epoch(b),fact(frame.move).generation),applied=b.turnCount or 0}
    row.license=copy(frame.license)
    row.proof=integrity(row);state(b,true).charges[side(b,u)]=row
  end
  function M.observe(original,b,u,t,slot,called)
    if not M.epoch(b)or not live(u)or not slot or not side(b,u)then return original(b,u,t,slot,called)end
    local move=b:moveDef(slot);if not move then return original(b,u,t,slot,called)end
    if(depth[b]or 0)>=16 then b:sayNext(tr('But, it failed!','Doch es schlug fehl!'));return end
    local prior=frames[b];local p=called and prior and prior.user==u and prior.plan and prior.plan.move.id==move.id and prior.plan
    if p then t=p.target;prior.plan=nil end
    local row=state(b)and state(b).history
    local charge=state(b)and state(b).charges[side(b,u)];local continuation=charge and u.charging==slot and charge.move==move.id
    local f={battle=b,profile=M.epoch(b),user=u,move=move,slot=slot,called=called,caller=called and prior,
      license=copy(p and p.license or continuation and charge.license),continuation=not not continuation,
      used=false,previousHistory=copy(row),boost=p and p.meFirst and p.epoch or prior and prior.boost}
    local oldCurrent=currentFrame;frames[b]=f;currentFrame=f;depth[b]=(depth[b]or 0)+1
    local out=pack(pcall(original,b,u,t,slot,called));depth[b]=depth[b]-1;frames[b]=prior;currentFrame=oldCurrent
    if depth[b]==0 then depth[b]=nil end
    if not out[1]then error(out[2],0)end
    -- Escape/phazing may end the battle inside this genuine dispatch.
    -- A finished battle has no live epoch and must not write call history.
    if f.used and M.epoch(b)and index(b,u)then
      local r=state(b,true)
      -- Gen IV's runMove restores the outermost active move. V+ keeps the
      -- called move globally; a failed caller with no inner move is itself last.
      if not called and M.epoch(b)<=4 or not f.childUsed then
        r.history=fact(move)and{move=move.id,side=side(b,u),species=u.mon.species,party=index(b,u),
          profile=M.epoch(b),epoch=math.max(M.epoch(b),fact(move)and fact(move).generation or 1),
          turn=b.turnCount or 0,called=not not called}or nil
      end
      if prior then prior.childUsed=true end
      saveCharge(b,u,slot,f)
      local charge=r.charges[side(b,u)]
      if charge and not u.charging then r.charges[side(b,u)]=nil end
    end
    return unpack(out,2,out.n)
  end
  function M.used(ev)local f=ev and frames[ev.battle];if f and ev.user==f.user and ev.move and ev.move.id==f.move.id then f.used=true end end
  function M.damage(nextDamage,ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local f=frames[b];local p
    if defs[move.id]and move.id=='ME_FIRST'and M.epoch(b,u,move)then p=M.plan(b,u,t,move)end
    local boost=p and p.epoch or f and f.boost and f.user.mon==u.mon and f.move.id==move.id and f.boost
    if not boost then return nextDamage(ctx)end
    assert(Damage.kascCalledMoves67==M.OWNER,'Me First needs owned source-era shared modifier seam')
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.opts=copy(ctx.opts or{})
    if p then out.move=copy(p.move);out.target=p.target;out.opts.forceCrit=false;out.opts.rng=function(_,hi)return hi end end
    out.move=copy(out.move);out.move.kascMeFirst67=M.OWNER
    out.opts.kascMeFirst67=6144;out.opts.kascMeFirstEpoch67=boost
    local parent=mod.exports.pokemonParentalBond67
    if parent then parent.projected(b,u,out.target,move,out.move)end
    return nextDamage(out)
  end
  function M.begin(ev)
    local b=ev.battle;if not M.epoch(b)then return end;local r=state(b,true);r.pending={}
    for _,key in ipairs({'player','enemy'})do local w=b[key];local slot=actualAction(b,w,ev[key..'Action']);local i=slot and slotIndex(w,slot)
      if live(w)and i then r.pending[key]={species=w.mon.species,party=index(b,w),move=slot.id,slot=i,turn=b.turnCount or 0}end
    end
  end
  function M.execute(original,b,u,t,action,...)
    local instruct=mod.exports.pokemonInstruct67;local repeatAction=instruct and instruct.isRepeating and instruct.isRepeating(b)
    local r=state(b);if r and r.pending and not repeatAction then r.pending[side(b,u)]=nil end
    return original(b,u,t,action,...)
  end
  function M.resolve(original,b,action,...)
    local old=previews[b];previews[b]={action=action,mon=b.player.mon}
    local out=pack(pcall(original,b,action,...));previews[b]=old
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.clear(ev)local b=ev.battle;local r=state(b);if r and ev.battler then r.charges[side(b,ev.battler)]=nil
    if r.pending then r.pending[side(b,ev.battler)]=nil end
    elseif r then b.field.tokens[M.OWNER]=nil end end
  function M.validateCheckpoint(b)
    if frames[b]or previews[b]or depth[b]or capturing[b]then return false,'called_moves_unsettled'end
    local r=state(b);if not r then return true end
    if not M.epoch(b)or type(r)~='table'or type(r.charges)~='table'then return false,'invalid_called_moves_container'end
    for k in pairs(r)do if k~='charges'and k~='history'and k~='pending'and k~='environment'then return false,'unknown_called_moves_field'end end
    if r.environment then local e=r.environment
      if type(e)~='table'or not environments[e.kind]or e.map~=(b.checkpointOrigin and b.checkpointOrigin.map)then return false,'invalid_called_environment'end
      for k in pairs(e)do if k~='kind'and k~='map'then return false,'unknown_called_environment_field'end end
    end
    if r.history then local h=r.history;local ps=type(h)=='table'and party(b,h.side);local mon=ps and ps[h.party]
      if not mon or mon.species~=h.species or not b.data.moves[h.move]or not fact(b.data.moves[h.move])
          or h.profile~=M.epoch(b)or h.epoch~=math.max(M.epoch(b),fact(b.data.moves[h.move]).generation)
          or not integer(h.turn,0,b.turnCount or 0)or type(h.called)~='boolean'then return false,'invalid_called_history'end
      for k in pairs(h)do if k~='side'and k~='species'and k~='party'and k~='move'and k~='profile'and k~='epoch'and k~='turn'and k~='called'then return false,'unknown_called_history_field'end end
    end
    if r.pending then for key,h in pairs(r.pending)do local w=(key=='player'or key=='enemy')and b[key];local slot=type(h)=='table'and w and w.curMoves[h.slot]
      if not slot or h.move~=slot.id or h.species~=w.mon.species or h.party~=index(b,w)or h.turn~=(b.turnCount or 0)then return false,'invalid_called_pending_action'end
      for k in pairs(h)do if k~='move'and k~='species'and k~='party'and k~='turn'and k~='slot'then return false,'unknown_called_pending_field'end end
    end end
    for key,h in pairs(r.charges)do local w=(key=='player'or key=='enemy')and b[key];local slot=type(h)=='table'and w and w.curMoves[h.callerSlot]
      local move=type(h)=='table'and b.data.moves[h.move];local record=move and b:effectRecord(move.effect)
      local caller=slot and b:effectRecord(b:moveDef(slot).effect)
      if not w or not slot or slot.id~=h.caller or not caller or type(caller.callsMove)~='function'
          or not record or not record.charge or not fact(move)or h.profile~=M.epoch(b)
          or h.species~=w.mon.species or h.party~=index(b,w)or h.proof~=integrity(h)
          or not integer(h.applied,0,b.turnCount or 0)or h.epoch~=math.max(M.epoch(b),fact(move).generation)
          or not w.chargeReady or w.lastMove~=h.move or w.charging and(w.charging.id~=h.move or slotIndex(w,w.charging))then return false,'invalid_called_charge'end
      for k in pairs(h)do if k~='move'and k~='caller'and k~='callerSlot'and k~='species'and k~='party'and k~='profile'and k~='epoch'and k~='applied'and k~='proof'and k~='license'then return false,'unknown_called_charge_field'end end
      if h.license then local l=h.license;local ps=type(l)=='table'and party(b,l.side);local source=ps and ps[l.party]
        if not source or source.species~=l.species or l.kind~=h.caller or l.move~=h.move or not defs[l.kind]
            or l.epoch~=math.max(M.epoch(b),defs[l.kind].gen)then return false,'invalid_called_charge_license'end
        for k in pairs(l)do if k~='kind'and k~='move'and k~='side'and k~='party'and k~='species'and k~='epoch'then return false,'unknown_called_license_field'end end
      end
    end
    return true
  end
  function M.capture(original,game,b,...)
    local r=state(b);if not M.epoch(b)or not r or not next(r.charges or{})then return original(game,b,...)end
    assert(M.validateCheckpoint(b),'invalid owned called charge at capture')
    local refs={};for key,row in pairs(r.charges)do local w=b[key]
      if w.charging and not slotIndex(w,w.charging)then refs[#refs+1]={w=w,charging=w.charging};w.charging=nil end
    end
    capturing[b]=true;local out=pack(pcall(original,game,b,...));capturing[b]=nil
    for _,ref in ipairs(refs)do ref.w.charging=ref.charging end
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.resume(b)
    local r=state(b);if not r then return end
    assert(M.validateCheckpoint(b),'invalid owned called continuation')
    for key,row in pairs(r.charges)do local w=b[key]
      if not w.charging then w.charging={id=row.move,pp=1}end
    end
  end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.gen and f.category=='status'and f.power==0 and f.pp==20
      and f.priority==0 and f.type=='NORMAL','called move source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign called move owner '..id)
    local effect='KA_CALLED_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,callsMove=M.pick,kascCalledMoves67=M.OWNER})
    mod.content.moves:patch(id,{effect=effect,power=0,pp=20,accuracy=100,priority=0,type='NORMAL',category='status',target=d.target,
      backendMoveOwner=M.OWNER,backendMoveNumber=d.number,originGeneration=d.gen,backendLearnsetRevision=old.backendLearnsetRevision or 1,
      -- Gen VII inherits the Gen VI flag replacement, not the later
      -- base-source failencore/failmimic additions. Era-specific candidate
      -- exclusions above independently preserve older calling rules.
      flags={nosleeptalk=1,noassist=1,failcopycat=1,failmefirst=id=='ME_FIRST'and 1 or nil,
        protect=id=='ME_FIRST'and 1 or nil,bypasssub=id=='ME_FIRST'and 1 or nil},kascBypassSub67=id=='ME_FIRST'})
    local animation=copy(assert(mod.content.battle_anims:get('METRONOME')));animation.source=M.OWNER;mod.content.battle_anims:patch(id,animation)
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  function M.position(player,id)local animation=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not animation or animation.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local out={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;out[i]=q
    end;step.sprites=out end
  end
  function M.install()
    B._kascCalledMoves67=M;CP._kascCalledMoves67=M;Player._kascCalledMoves67=M
    if not B._kascCalledWrapped67 then local perform,execute,resolve=B.performMove,B.executeAction,B.resolveTurn
      B.performMove=function(...)return B._kascCalledMoves67.observe(perform,...)end
      B.executeAction=function(...)return B._kascCalledMoves67.execute(execute,...)end
      B.resolveTurn=function(...)return B._kascCalledMoves67.resolve(resolve,...)end
      B._kascCalledWrapped67=true end
    if not CP._kascCalledWrapped67 then local capture=CP.capture
      CP.capture=function(...)return CP._kascCalledMoves67.capture(capture,...)end;CP._kascCalledWrapped67=true end
    if not Player._kascCalledWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascCalledMoves67.position(self,id);return unpack(out,1,out.n)end
      Player._kascCalledWrapped67=true end
  end
  mod.events:on('battle.move_used',M.used,31001)
  -- The outer preview becomes a detached real attack BEFORE its own
  -- variable-power/ability/item projections. Actual child dispatch sees
  -- the same immutable Me First marker, never a changed Data.moves row.
  -- Select the actual child before typed weather, multi-hit and genetics
  -- gates, not after an outer Normal/status definition has passed them.
  mod.hooks:wrap('battle.damage',M.damage,60000)
  mod.events:on('battle.turn_started',M.begin,6001)
  mod.events:on('battle.turn_ended',function(ev)local r=state(ev.battle);if r then r.pending=nil end end,6001)
  mod.events:on('battle.battler_switched',M.clear,8000)
  mod.events:on('battle.ended',M.clear,8000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-called-dispatch-and-source-era-global-history',providerStatus='four-real-called-moves',
    buildReceiptId='docs/CALLED_MOVES_67.md',rollbackReceiptId='docs/CALLED_MOVES_67.md'})end
  return M
end
