-- KASC-67-POKEMON-EQUIPMENT: local ownership and atomic inventory commands.
-- Battle effects, wild acquisition and shared-vault journals have separate
-- owners. UI consumers receive copies and never receive a live mon pointer.
return function(opts)
  local owned=assert(opts.owned,'local owned-mon surface adapter required')
  local describeItem=assert(opts.item,'item authority required')
  local generation=assert(opts.generation,'generation authority required')
  local persist=assert(opts.writeSave,'atomic save adapter required')
  local canEdit=assert(opts.canEdit,'battle/ownership edit guard required')
  local canWrite=assert(opts.canWrite,'safe save checkpoint guard required')
  local digest=assert(opts.digest,'stable digest required')
  local Bag=assert(opts.bag,'bag authority required')
  local modId=opts.modId or 'kanto_ascendant'
  local M={CARD_ID='KASC-67-POKEMON-EQUIPMENT',OWNER='kasc.pokemon-equipment/v1',
    schema='kasc.pokemon-equipment-view/v1',version=1}
  local busy=setmetatable({},{__mode='k'})
  local listeners={}
  local function copy(v)
    if type(v)~='table' then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  local function state(game)
    local bucket=game and game.save and game.save.modData
    bucket=bucket and bucket[modId]
    return bucket and bucket.pokemon_equipment_67
  end
  local function validState(value)
    return type(value)=='table' and value.version==1
      and type(value.requests)=='table' and type(value.serial)=='number'
      and value.serial>=0 and value.serial%1==0 and type(value.revision)=='number'
      and value.revision>=0 and value.revision%1==0
  end
  local function egg(mon)
    return mon.isEgg or mon.egg or mon.eggSpecies or mon.species=='EGG'
  end
  local function held(mon)
    local chosen
    for _,field in ipairs({'item','heldItem'})do
      local value=mon[field]
      if value~=nil and value~=false and value~=0 and value~='' and value~='NO_ITEM' then
        if type(value)~='string' then return nil,'invalid_item_encoding' end
        value=value:upper()
        if chosen and chosen~=value then return nil,'conflicting_item_aliases' end
        chosen=value
      end
    end
    return chosen or false
  end
  M.held=held
  local function rows(game)
    local result,seen={},{}
    for _,row in ipairs(owned(game) or {})do
      local mon=row.mon
      if type(mon)=='table' and mon.species and not seen[mon] then
        result[#result+1]={mon=mon,location=row.location or row.label}
        seen[mon]=true
      end
    end
    return result
  end
  local function find(game,handle)
    local found
    for _,row in ipairs(rows(game))do
      if row.mon._kascEquipmentHandle==handle then
        if found then return nil,'ambiguous_mon_handle' end
        found=row
      end
    end
    if not found then return nil,'mon_not_owned' end
    return found
  end
  local function metadata(save,nextState)
    local modData={};for k,v in pairs(save.modData or {})do modData[k]=v end
    local bucket={};for k,v in pairs(modData[modId] or {})do bucket[k]=v end
    bucket.pokemon_equipment_67=nextState;modData[modId]=bucket
    return modData
  end
  -- Metadata transactions replace the root table. Rebind the engine's mod
  -- save API on both staging and rollback so subsequent progress is saved.
  local function setMetadata(game, value)
    game.save.modData=value
    if type(game.adoptSave)=='function' then game:adoptSave(game.save) end
  end
  local function save(game)
    local ok,wrote=pcall(persist,game)
    return ok and wrote==true
  end
  function M.subscribe(listener)
    assert(type(listener)=='function','equipment listener must be a function')
    listeners[listener]=true
    return function()listeners[listener]=nil end
  end
  -- Explicit migration boundary, not a side effect of reading a snapshot.
  -- Identity allocation never rolls wild items or changes existing aliases.
  function M.bind(game,forceCommit)
    if busy[game] then return nil,'transaction_busy' end
    if not (game and type(game.save)=='table') then return nil,'save_unavailable' end
    local writable,writeReason=canWrite(game)
    if not writable then return nil,writeReason or 'unsafe_save_checkpoint' end
    local before=state(game)
    if before and not validState(before) then return nil,'unsupported_equipment_schema' end
    local nextState=copy(before or {version=1,serial=0,revision=0,requests={}})
    local identity=game.save.meta and (game.save.meta.playthroughId or game.save.meta.saveIdentity)
      or game.save.playthroughId
    if type(identity)~='string' or identity=='' then return nil,'save_identity_missing' end
    local changed={};local seen={}
    for _,row in ipairs(rows(game))do
      local mon=row.mon;local handle=mon._kascEquipmentHandle
      if handle~=nil and (type(handle)~='string' or handle=='') then return nil,'invalid_mon_handle' end
      if handle and seen[handle] then return nil,'ambiguous_mon_handle' end
      if handle then seen[handle]=true end
    end
    for _,row in ipairs(rows(game))do
      if not row.mon._kascEquipmentHandle then
        local handle
        repeat
          nextState.serial=nextState.serial+1
          handle='eq-'..digest(identity..':'..nextState.serial):sub(1,32)
        until not seen[handle]
        seen[handle]=true;changed[#changed+1]={mon=row.mon,handle=handle}
      end
    end
    local extra={}
    if opts.prepareMon then
      local handles={};for _,row in ipairs(changed)do handles[row.mon]=row.handle end
      for _,row in ipairs(rows(game))do
        local plan,reason=opts.prepareMon(game,row.mon,
          row.mon._kascEquipmentHandle or handles[row.mon],generation(game))
        if plan==nil then return nil,reason or 'invalid_mon_plan' end
        if plan then
          local old={}
          for key in pairs(plan)do old[key]=row.mon[key]end
          extra[#extra+1]={mon=row.mon,plan=plan,old=old}
        end
      end
    end
    if before and #changed==0 and #extra==0 and not forceCommit then return true end
    nextState.revision=nextState.revision+1
    local oldMetadata=game.save.modData
    for _,row in ipairs(changed)do row.mon._kascEquipmentHandle=row.handle end
    for _,row in ipairs(extra)do for key,value in pairs(row.plan)do row.mon[key]=value end end
    setMetadata(game,metadata(game.save,nextState));busy[game]=true
    local wrote=save(game);busy[game]=nil
    if not wrote then
      setMetadata(game,oldMetadata)
      for _,row in ipairs(changed)do row.mon._kascEquipmentHandle=nil end
      for _,row in ipairs(extra)do for key in pairs(row.plan)do row.mon[key]=row.old[key]end end
      return nil,'save_failed'
    end
    return true
  end
  local function identityToken(st,row,gen,item,ability)
    return digest(table.concat({st.revision,row.mon._kascEquipmentHandle,
      tostring(row.location),row.mon.species,tostring(item),tostring(gen),
      tostring(egg(row.mon) and true or false),tostring(ability.id or false),
      tostring(ability.slot or false)},'|'))
  end
  local function descriptor(id,gen,game)
    if not id then return {id=false,active=false,reasonCode='no_item'} end
    local item=describeItem(id,gen,game)
    if not item then return {id=id,active=false,reasonCode='unknown_item'} end
    local result=copy(item);result.id=id
    -- Capability belongs to the effect owner, not to metadata presence.
    result.active=gen>=math.max(2,item.generation or 2) and item.effectSupported==true
    result.reasonCode=false
    if not result.active then
      result.reasonCode=gen<math.max(2,item.generation or 2)
        and 'inactive_generation' or 'effect_not_implemented'
    end
    return result
  end
  function M.snapshot(game,handle)
    local st=state(game)
    if not st then return nil,'equipment_not_initialized' end
    if not validState(st) then return nil,'unsupported_equipment_schema' end
    if type(handle)~='string' then return nil,'invalid_mon_handle' end
    local row,reason=find(game,handle);if not row then return nil,reason end
    local item,itemErr=held(row.mon);if item==nil then return nil,itemErr end
    local gen=generation(game)
    local ability={id=false,active=false,reasonCode='no_ability'}
    if not egg(row.mon) and opts.ability then
      ability=copy(opts.ability(game,row.mon,gen) or ability)
    end
    local snapshot={schema=M.schema,owner=M.OWNER,handle=handle,generation=gen,
      item=descriptor(item,gen,game),ability=ability,isEgg=egg(row.mon) and true or false,
      commands={details=true,give=false,take=false,swap=false}}
    snapshot.revision=identityToken(st,row,gen,item,ability)
    local allowed,editReason=canEdit(game,row.mon,row.location)
    local writable,writeReason=canWrite(game)
    if not writable then allowed,editReason=false,writeReason or 'unsafe_save_checkpoint' end
    if not snapshot.isEgg and allowed and snapshot.item.reasonCode~='unknown_item' then
      snapshot.commands.give=item==false
      snapshot.commands.take=item~=false
      snapshot.commands.swap=item~=false
    else snapshot.reasonCode=snapshot.isEgg and 'egg' or editReason or 'unknown_item' end
    if snapshot.isEgg then
      -- No future species or ability is present in an egg view.
      snapshot.ability={id=false,active=false,reasonCode='egg_unrevealed'}
    end
    return snapshot
  end
  function M.command(game,request)
    if busy[game] then return nil,'transaction_busy' end
    local st=state(game)
    if not validState(st) then return nil,'equipment_not_initialized' end
    if type(request)~='table' or type(request.requestId)~='string'
        or #request.requestId>128 or not request.requestId:match('^[%w_-]+$') then
      return nil,'invalid_request'
    end
    if type(request.handle)~='string' or type(request.expectedRevision)~='string'
        or not ({give=true,take=true,swap=true})[request.action] then return nil,'invalid_request' end
    if request.action~='take' and type(request.itemId)~='string' then return nil,'invalid_item' end
    local signature=digest(table.concat({request.handle,request.expectedRevision,
      request.action,tostring(request.itemId or false)},'|'))
    local previous=st.requests[request.requestId]
    if previous then
      if previous.signature~=signature then return nil,'request_id_conflict' end
      return copy(previous.result)
    end
    local snapshot,reason=M.snapshot(game,request.handle)
    if not snapshot then return nil,reason end
    if snapshot.revision~=request.expectedRevision then return nil,'stale_revision' end
    if not snapshot.commands[request.action] then return nil,snapshot.reasonCode or 'command_not_allowed' end
    local row=assert(find(game,request.handle));local oldItem=snapshot.item.id
    local nextItem=request.action~='take' and request.itemId:upper() or false
    if nextItem==oldItem then return nil,'same_item' end
    if nextItem then
      local definition=describeItem(nextItem,snapshot.generation,game)
      if not definition then return nil,'unknown_item' end
      if definition.holdable~=true then return nil,'item_not_holdable' end
    end
    local staged={inventory=copy(game.save.inventory or {}),bagOrder=copy(game.save.bagOrder)}
    if nextItem then
      if (tonumber(staged.inventory[nextItem]) or 0)<1 then return nil,'item_not_owned' end
      Bag.remove(staged,nextItem,1)
    end
    if oldItem and not Bag.add(staged,oldItem,1,game.data) then return nil,'bag_full' end
    local nextState=copy(st);nextState.revision=nextState.revision+1
    local result={committed=true,requestId=request.requestId,handle=request.handle,
      action=request.action,itemId=nextItem,returnedItemId=oldItem,
      revision=identityToken(nextState,row,snapshot.generation,nextItem,snapshot.ability)}
    nextState.requests[request.requestId]={signature=signature,result=copy(result)}
    local oldInventory,oldOrder,oldMetadata=game.save.inventory,game.save.bagOrder,game.save.modData
    local oldAlias1,oldAlias2=row.mon.item,row.mon.heldItem
    game.save.inventory,game.save.bagOrder=staged.inventory,staged.bagOrder
    setMetadata(game,metadata(game.save,nextState))
    row.mon.item=nextItem or nil;row.mon.heldItem=nextItem or nil
    busy[game]=true;local wrote=save(game);busy[game]=nil
    if not wrote then
      game.save.inventory,game.save.bagOrder=oldInventory,oldOrder
      setMetadata(game,oldMetadata)
      row.mon.item,row.mon.heldItem=oldAlias1,oldAlias2
      return nil,'save_failed'
    end
    if opts.changed then pcall(opts.changed,game,copy(result))end
    local notify={};for listener in pairs(listeners)do notify[#notify+1]=listener end
    for _,listener in ipairs(notify)do
      if listeners[listener] then pcall(listener,copy(result))end
    end
    return result
  end
  return M
end
