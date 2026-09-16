-- One era for automatic level-up; backward-compatible teacher/TM access.
-- Historical learning never changes saved moves or gift delivery receipts.
return function(opts)
  local species,rules=assert(opts.species),assert(opts.rules)
  local eggs=assert(opts.eggMoves)
  local L={CARD_ID='KASC-67-BACKEND-LIVE-LEARNSETS',audit={}}
  local cache,historyCache={},{}
  local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function epoch(game,forced)
    return math.max(1,math.min(7,math.floor(tonumber(forced)
      or rules.resolve(game).activeEpoch)))
  end
  function L.owns(id)return species.bySpecies[id]~=nil end
  local function projected(game,id,active)
    local key=species.bySpecies[id];if not key then return nil,'unowned' end
    local source=opts.catalog.entries[key]
    local effective=math.max(active,source.originGeneration)
    local group
    if effective==1 and opts.edition then
      group=opts.edition(game)=='yellow' and 2 or 1
    end
    local slot=key..':'..effective..':'..tostring(group or 'default')
    if not cache[slot] then
      local row,why=species.projectLearnset(key,effective,group)
      if not row then return nil,why end
      cache[slot]=row
    end
    return cache[slot]
  end
  local function history(game,id,active)
    local key=species.bySpecies[id]
    local effective=math.max(active,opts.catalog.entries[key].originGeneration)
    local slot=key..':'..effective
    if not historyCache[slot] then
      historyCache[slot]=species.historicalLearnsets(key,effective)
    end
    return historyCache[slot]
  end
  function L.rowsFor(game,monOrSpecies,method,forced)
    -- AUS remains the native R/B/Y fallback, distinct from selecting GEN I.
    if not forced and rules.resolve(game).extensionsEnabled==false then return nil end
    local id=type(monOrSpecies)=='table' and
      (monOrSpecies.species or monOrSpecies.eggSpecies) or monOrSpecies
    if not L.owns(id) then return nil end
    local source=projected(game,id,epoch(game,forced))
    if not source then return {} end
    local out,seen={},{}
    local function add(move,kind,level,learnSource)
      if (not method or method==kind) and game.data.moves[move] then
        local slot=kind..':'..move..':'..(level or 0)
        if seen[slot] then return end
        seen[slot]=true
        local origin=learnSource or source
        out[#out+1]={id=move,method=kind,level=level or 0,
          generation=origin.generation,versionGroup=origin.versionGroup}
      end
    end
    for _,id in ipairs(source.level1Moves)do add(id,'L',1)end
    for _,r in ipairs(source.learnset)do add(r.move,'L',r.level)end
    for _,id in ipairs(source.tmhm)do add(id,'M')end
    for _,id in ipairs(source.tutor)do add(id,'T')end
    for _,id in ipairs(source.egg)do add(id,'E')end
    -- Machines remain compatible with every older legal machine source.
    -- The teacher also recovers older level/tutor moves, without flattening
    -- their levels into the automatic level-up schedule. Egg-only sources
    -- remain breeding-only rather than becoming universal tutor moves.
    local level=type(monOrSpecies)=='table' and tonumber(monOrSpecies.level) or 1
    for _,old in ipairs(history(game,id,epoch(game,forced)))do
      for _,move in ipairs(old.tmhm)do add(move,'M',0,old);add(move,'T',0,old)end
      for _,move in ipairs(old.tutor)do add(move,'T',0,old)end
      for _,move in ipairs(old.level1Moves)do add(move,'T',0,old)end
      for _,r in ipairs(old.learnset)do
        if r.level<=(level or 1) then add(r.move,'T',0,old)end
      end
    end
    return out
  end
  -- Caller must separately verify the durable gift receipt and ownership.
  -- Include legal inherited egg moves, but never borrow another form's list
  -- or promote a future level-up move merely because it has an effect owner.
  function L.giftMoveCompatible(game,mon,move,active)
    if type(mon)~='table' or not game.data.moves[move] then return false end
    -- An older species may itself receive a new signature move later:
    -- Heatmor is Gen V, Fire Lash Gen VII. Validate that exact move's own
    -- learning era, not only the species' introduction era. The caller
    -- still owns receipt/identity checks; this never unlocks ordinary mons.
    local learningEra=math.max(epoch(game,active),rules.moveEpoch(move,game.data))
    for _,row in ipairs(L.rowsFor(game,mon,nil,learningEra) or {})do
      if row.id==move and (row.method~='L' or row.level<=(tonumber(mon.level) or 1)) then
        return true
      end
    end
    -- Retain a gift's actual saved, legal learned move when its learning
    -- source existed later than the move itself (e.g. Xatu Magic Coat).
    -- This is only compatibility of an existing slot, not an enumeration
    -- of future teacher candidates or a flattened level-up schedule. The
    -- caller still authenticates this exact gift and authoritative owner.
    local known=false
    for _,slot in ipairs(type(mon.moves)=='table'and mon.moves or{})do
      if type(slot)=='table'and slot.id==move then known=true;break end
    end
    if known then for era=learningEra+1,7 do
      for _,row in ipairs(L.rowsFor(game,mon,nil,era)or{})do
        if row.id==move and(row.method~='L'or row.level<=(tonumber(mon.level)or 1))then return true end
      end
    end end
    return false
  end
  -- Enumerate teacher candidates separately from the live level schedule.
  -- The caller authenticates the gift receipt. Each candidate is then
  -- checked in that move's own learning era, not a blanket Gen-VII union.
  -- An egg-only source does not become a teacher source by being gifted.
  function L.giftReminderRows(game,mon,active)
    if type(mon)~='table' or not L.owns(mon.species) then return {} end
    local out,seen={},{}
    for _,candidate in ipairs(L.rowsFor(game,mon,nil,7) or {})do
      local id=candidate.id
      if not seen[id] then
        seen[id]=true
        local learningEra=math.max(epoch(game,active),rules.moveEpoch(id,game.data))
        for _,row in ipairs(L.rowsFor(game,mon,nil,learningEra) or {})do
          if row.id==id and (row.method=='T' or row.method=='M'
              or row.method=='L' and row.level<=(tonumber(mon.level) or 1)) then
            out[#out+1]={id=id,source='event'}
            break
          end
        end
      end
    end
    return out
  end
  function L.apply(game,forced)
    local active=epoch(game,forced)
    local audit={activeEpoch=active,species=0,pending={},unavailableMoves={}}
    for id,key in pairs(species.bySpecies)do
      local def=game.data.pokemon[id]
      if def then
        local row,why=projected(game,id,active)
        if not row then audit.pending[key]=why
        else
          def.level1Moves=copy(row.level1Moves);def.learnset=copy(row.learnset)
          def.tmhm={}
          for _,machine in ipairs(L.rowsFor(game,id,'M',active))do
            def.tmhm[#def.tmhm+1]=machine.id
          end
          -- Keep the explicitly authored KASC signature-machine contracts,
          -- not an arbitrary union of historical learnsets.
          local field=opts.fieldTech
          local function extra(move,family)
            if not rules.moveAvailable(move,active,game.data) then return end
            for _,member in ipairs(family or {})do
              if member==id then
                for _,known in ipairs(def.tmhm)do if known==move then return end end
                def.tmhm[#def.tmhm+1]=move;return
              end
            end
          end
          if field then
            for move,family in pairs(field.starterFamilies or {})do extra(move,family)end
            if field.goldTM then extra(field.goldTM.move,field.tm54Family)end
          end
          if def.dex then eggs[def.dex]=copy(row.egg)end
          audit.species=audit.species+1
          for move in pairs(row.unavailable)do audit.unavailableMoves[move]=true end
        end
      end
    end
    L.audit=audit
    return not next(audit.pending),audit
  end
  return L
end
