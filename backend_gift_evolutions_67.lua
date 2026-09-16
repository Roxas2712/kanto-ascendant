-- WAVE1-GIFT-EVOLUTION. Reviewed level/stone edges; no global generation unlock.
return function(mod,opts)
  local species=assert(opts.species)
  local data=assert(opts.data)
  assert(data.schema=='kasc.wave1-evolution-block/v1')
  local registry=assert(mod.content.pokemon)
  local methods=assert(mod.content.evolution_methods)
  local C={CARD_ID='KASC-WAVE1-GIFT-EVOLUTIONS',registered={},reused={},pending={}}
  local approved,plans={},{}
  -- The native evolution schema has no move field. Keep requirements in
  -- this reviewed owner's private tables, never in an invalid registry row.
  local requiredMoves,requiredByTarget={},{}
  local friendshipOwners={}
  local timedLevelOwners={}
  local femaleLevelOwners={}
  local darkPartyOwners={}
  -- CSV level rows alone do not describe Waumpel's personality branch.
  -- Reuse only the complete existing Hoenn pair, never invent two LEVEL paths.
  local wurmpleTargets={[266]='SILCOON',[268]='CASCOON'}
  local function wurmpleSource(source)
    local target=wurmpleTargets[source.toDex]
    return source.fromDex==265 and target and source.level==7
      and source.method=='KA_HOENN_WURMPLE_'..target
      and not source.item and not source.move and not source.partySpecies
      and not source.friendship and not source.timeOfDay and not source.heldItem
      and not source.gender and not source.partyType
  end
  local function completeWurmplePair()
    if species.byKey['dex:265']~='WURMPLE' then return false end
    local parent=registry:get('WURMPLE')
    if not parent or parent.formId or parent.isMega or parent.isGigantamax
        or #(parent.evolutions or {})~=2 then return false end
    local seen,count={},0
    for _,source in ipairs(data.edges)do
      if source.fromDex==265 then
        if not wurmpleSource(source) or seen[source.toDex] then return false end
        seen[source.toDex]=true;count=count+1
        local target=wurmpleTargets[source.toDex]
        if species.byKey['dex:'..source.toDex]~=target then return false end
        local def=registry:get(target)
        local method=methods:get(source.method)
        if not def or def.formId or def.isMega or def.isGigantamax
            or not method or type(method.check)~='function' then return false end
        local matches=0
        for _,row in ipairs(parent.evolutions)do
          if row.species==target and row.method==source.method and row.level==7
              and not row.item and not row.move and not row.partySpecies then matches=matches+1 end
        end
        if matches~=1 then return false end
      end
    end
    return count==2 and seen[266] and seen[268]
  end
  local wurmpleReady=completeWurmplePair()
  -- Preserve the three explicitly adapted native Hoenn ITEM routes. A
  -- Clamperl branch is approved only with both original targets present.
  local hoennItemFamilies={
    [349]={name='FEEBAS',targets={[350]={'MILOTIC','PRISM_SCALE'}}},
    [366]={name='CLAMPERL',targets={[367]={'HUNTAIL','DEEP_SEA_TOOTH'},
      [368]={'GOREBYSS','DEEP_SEA_SCALE'}}},
  }
  local function completeHoennItems(dex,family)
    if species.byKey['dex:'..dex]~=family.name then return false end
    local parent=registry:get(family.name)
    local method=methods:get('ITEM')
    if not parent or parent.backendOwner or parent.formId or parent.isMega
        or parent.isGigantamax or not method or type(method.check)~='function' then return false end
    local expected=0;for _ in pairs(family.targets)do expected=expected+1 end
    if #(parent.evolutions or {})~=expected then return false end
    local seen,count={},0
    for _,source in ipairs(data.edges)do if source.fromDex==dex then
      local target=family.targets[source.toDex]
      if not target or seen[source.toDex] or source.item~=target[2]
          or source.method or source.level or source.move or source.partySpecies
          or source.friendship or source.timeOfDay or source.heldItem
          or source.gender or source.partyType then return false end
      if species.byKey['dex:'..source.toDex]~=target[1] then return false end
      local def=registry:get(target[1])
      if not def or def.backendOwner or def.formId or def.isMega or def.isGigantamax
          or not mod.content.items or not mod.content.items:get(target[2]) then return false end
      local matches=0
      for _,evo in ipairs(parent.evolutions)do
        if evo.species==target[1] and evo.method=='ITEM' and evo.item==target[2]
            and not evo.level and not evo.move and not evo.partySpecies then matches=matches+1 end
      end
      if matches~=1 then return false end
      seen[source.toDex]=true;count=count+1
    end end
    return count==expected
  end
  local hoennItemsReady={}
  for dex,family in pairs(hoennItemFamilies)do
    hoennItemsReady[dex]=completeHoennItems(dex,family)
  end
  -- Mixed LEVEL/ITEM branches require their complete original native pair.
  -- Never replace Kirlia's Gardevoir or Snorunt's Glalie path with a stone.
  local dawnFamilies={
    [281]={name='KIRLIA',level=30,levelDex=282,levelName='GARDEVOIR',
      target=475,targetName='GALLADE',gender='MALE'},
    [361]={name='SNORUNT',level=42,levelDex=362,levelName='GLALIE',
      target=478,targetName='FROSLASS',gender='FEMALE'},
  }
  local function dawnSource(source,family)
    return source.toDex==family.target and source.item=='DAWN_STONE'
      and source.gender==family.gender and not source.level and not source.method
      and not source.move and not source.partySpecies and not source.friendship
      and not source.timeOfDay and not source.heldItem and not source.partyType
  end
  local function completeDawnFamily(dex,family)
    local provider=opts.dawn
    if not provider or type(provider.supportsDawnEvolution)~='function'
        or not provider.supportsDawnEvolution(family.name,family.targetName,family.gender)
        or species.byKey['dex:'..dex]~=family.name then return false end
    local parent=registry:get(family.name)
    if not parent or parent.backendOwner or parent.form or parent.formId
        or parent.isMega or parent.isGigantamax or #(parent.evolutions or {})~=2 then return false end
    local seen,count={},0
    for _,source in ipairs(data.edges)do if source.fromDex==dex then
      local isDawn=dawnSource(source,family)
      local isLevel=source.toDex==family.levelDex and source.level==family.level
        and not source.item and not source.method and not source.gender
        and not source.move and not source.partySpecies and not source.friendship
        and not source.timeOfDay and not source.heldItem and not source.partyType
      if not (isDawn or isLevel) or seen[source.toDex] then return false end
      local name=isDawn and family.targetName or family.levelName
      local method=isDawn and 'ITEM' or 'LEVEL'
      local def=registry:get(name)
      if species.byKey['dex:'..source.toDex]~=name or not def or def.backendOwner
          or def.form or def.formId or def.isMega or def.isGigantamax
          or not methods:get(method) then return false end
      local matches=0
      for _,evo in ipairs(parent.evolutions)do
        if evo.species==name and evo.method==method and evo.level==source.level
            and evo.item==source.item and not evo.move and not evo.partySpecies then matches=matches+1 end
      end
      if matches~=1 then return false end
      seen[source.toDex]=true;count=count+1
    end end
    return count==2
  end
  local dawnReady={}
  for dex,family in pairs(dawnFamilies)do dawnReady[dex]=completeDawnFamily(dex,family) end
  local sourceCounts,branchItems,branchTargets,branchInvalid,branchUnavailable={},{},{},{},{}
  for _,source in ipairs(data.edges)do
    sourceCounts[source.fromDex]=(sourceCounts[source.fromDex] or 0)+1
    local from=source.fromDex
    branchItems[from]=branchItems[from] or {};branchTargets[from]=branchTargets[from] or {}
    if type(source.item)~='string' or source.level or source.method
        or branchItems[from][source.item] or branchTargets[from][source.toDex] then
      branchInvalid[from]=true
    else
      branchItems[from][source.item]=true;branchTargets[from][source.toDex]=true
      local parent=species.byKey['dex:'..from]
      local target=species.byKey['dex:'..source.toDex]
      parent=parent and registry:get(parent);target=target and registry:get(target)
      if not parent or not target or parent.backendOwner~=species.OWNER
          or parent.formId or target.formId or parent.isMega or target.isMega
          or parent.isGigantamax or target.isGigantamax
          or not mod.content.items or not mod.content.items:get(source.item) then
        branchUnavailable[from]=true
      end
      for _,existing in ipairs(parent and parent.evolutions or {})do
        if existing.species==species.byKey['dex:'..source.toDex]
            and (existing.method~='ITEM' or existing.item~=source.item or existing.level) then
          branchUnavailable[from]=true
        end
      end
    end
  end
  -- Only explicit distinct item/target branches are unambiguous. Weather,
  -- version, nature and form branches need their own reviewed conditions.
  local function approvedRule(from,evo)
    if type(evo)~='table' then return nil end
    for _,row in ipairs(approved[from] or {})do
      if row.species==evo.species and row.method==evo.method
          and row.level==evo.level and row.item==evo.item
          and row.move==evo.move and row.partySpecies==evo.partySpecies then return row end
    end
  end
  local function approve(from,row)
    approved[from]=approved[from] or {};approved[from][#approved[from]+1]=row
  end
  local itemPlans={}
  local function copy(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
  end
  local function healthy(mon)
    return type(mon)=='table' and not mon.isEgg and not mon.eggSpecies
      and not mon.egg and (tonumber(mon.hp) or 0)>0
  end
  local function matches(left,right)
    return left and right and left.species==right.species
      and left.method==right.method and left.level==right.level and left.item==right.item
      and left.move==right.move and left.partySpecies==right.partySpecies
  end
  for _,source in ipairs(data.edges)do
    local azurill=source.fromDex==298 and source.toDex==183
      and source.method=='FRIENDSHIP' and source.friendship==true
      and not source.level and not source.item and not source.timeOfDay
      and not source.move and not source.partySpecies and not source.heldItem
      and not source.gender and not source.partyType
    local marill=source.fromDex==183 and source.toDex==184 and source.level==18
      and not source.method and not source.friendship and not source.item
      and not source.timeOfDay and not source.move and not source.partySpecies
      and not source.heldItem and not source.gender and not source.partyType
    local ancestral=source.fromDex==113 and source.toDex==242
      and source.method=='KA_WAVE1_CHANSEY_FRIENDSHIP'
    assert(type(source.fromDex)=='number' and (source.fromDex>251 or ancestral or marill)
      and source.fromDex<=1025 and type(source.toDex)=='number'
      and source.toDex>=1 and source.toDex<=1025)
    local conditional=(source.method=='KA_BABY_MIMIC' and source.move=='MIMIC'
        and not source.partySpecies)
      or (source.method=='KA_BABY_REMORAID' and source.partySpecies=='REMORAID'
        and not source.move)
    local known=source.method=='KA_BACKEND_KNOWN_MOVE' and type(source.move)=='string'
      and not source.partySpecies and not source.friendship and not source.timeOfDay and not source.heldItem
    local backendFriendship=source.friendship==true and not source.move and not source.partySpecies
      and not source.heldItem and not source.item and not source.level
      and ((source.method=='KA_BACKEND_FRIENDSHIP' and not source.timeOfDay)
        or (source.method=='KA_BACKEND_FRIENDSHIP_NIGHT' and source.timeOfDay=='night'))
    local friendship=source.friendship==true and not source.move and not source.partySpecies
      and ((source.method=='KA_BABY_FRIENDSHIP' and not source.timeOfDay)
        or (ancestral and not source.timeOfDay)
        or (source.method=='KA_BABY_FRIENDSHIP_DAY' and source.timeOfDay=='day')
        or (source.method=='KA_BABY_FRIENDSHIP_NIGHT' and source.timeOfDay=='night')
        or backendFriendship or azurill)
    local heldDay=source.fromDex==440 and source.toDex==113
      and source.method=='KA_HAPPINY_OVAL_DAY' and source.heldItem=='OVAL_STONE'
      and source.timeOfDay=='day' and not source.friendship and not source.move and not source.partySpecies
    local timedLevel=not source.friendship and not source.move and not source.partySpecies
      and not source.heldItem and not source.item and type(source.level)=='number'
      and source.level==math.floor(source.level) and source.level>1 and source.level<=100
      and ((source.method=='KA_BACKEND_LEVEL_DAY' and source.timeOfDay=='day')
        or (source.method=='KA_BACKEND_LEVEL_NIGHT' and source.timeOfDay=='night'))
    local femaleLevel=source.method=='KA_BACKEND_LEVEL_FEMALE' and source.gender=='FEMALE'
      and not source.friendship and not source.move and not source.partySpecies
      and not source.heldItem and not source.item and not source.timeOfDay
      and type(source.level)=='number' and source.level==math.floor(source.level)
      and source.level>1 and source.level<=100
    local darkParty=source.fromDex==674 and source.toDex==675
      and source.method=='KA_BACKEND_LEVEL_DARK_PARTY' and source.level==32 and source.partyType=='DARK'
      and not source.friendship and not source.move and not source.partySpecies
      and not source.heldItem and not source.item and not source.timeOfDay and not source.gender
    assert(not source.partyType or darkParty,'unreviewed party-type condition')
    local dawn=dawnFamilies[source.fromDex] and dawnSource(source,dawnFamilies[source.fromDex])
    assert(not source.gender or femaleLevel or dawn,'unreviewed gender condition')
    assert(not source.heldItem or heldDay,'unreviewed held-item condition')
    conditional=conditional or friendship or heldDay or known
    local wurmple=wurmpleSource(source)
    assert(wurmple or darkParty or femaleLevel or timedLevel or (conditional and not source.level and not source.item)
      or (not source.method and not source.move and not source.partySpecies
        and not source.friendship and not source.timeOfDay and
        ((type(source.level)=='number' and source.level>1 and source.level<=100 and not source.item)
        or (type(source.item)=='string' and source.item~='' and not source.level))))
    local nativeMethod=source.method or (source.item and 'ITEM' or 'LEVEL')
    local method=(backendFriendship or timedLevel or femaleLevel or darkParty) and source.method or known and 'KA_BACKEND_KNOWN_MOVE'
      or source.item and 'KA_BACKEND_ITEM' or 'KA_BACKEND_LEVEL'
    local requiredMove=known and species.moveId(source.move) or nil
    local from=species.byKey['dex:'..source.fromDex]
    local into=species.byKey['dex:'..source.toDex]
    local parent,target=from and registry:get(from),into and registry:get(into)
    local key='dex:'..source.fromDex
    local why
    if dawnFamilies[source.fromDex] and sourceCounts[source.fromDex]>1 and not dawnReady[source.fromDex] then why='incomplete_dawn_family'
    elseif dawn and not dawnReady[source.fromDex] then why='incomplete_dawn_family'
    elseif hoennItemFamilies[source.fromDex] and not hoennItemsReady[source.fromDex] then why='incomplete_hoenn_item_family'
    elseif (azurill and (from~='AZURILL' or into~='MARILL'))
        or (marill and (from~='MARILL' or into~='AZUMARILL')) then why='family_identity_mismatch'
    elseif wurmple and not wurmpleReady then why='incomplete_wurmple_branch'
    elseif sourceCounts[source.fromDex]>1 and branchInvalid[source.fromDex]
        and not dawnReady[source.fromDex] and not (wurmple and wurmpleReady) then why='ambiguous_branch'
    elseif sourceCounts[source.fromDex]>1 and branchUnavailable[source.fromDex]
        and not hoennItemsReady[source.fromDex] and not dawnReady[source.fromDex] then why='incomplete_item_branch'
    elseif not parent or not target then why='missing_species'
    elseif source.item and not mod.content.items:get(source.item) then why='missing_item'
    elseif known and not requiredMove then why='missing_required_move'
    elseif backendFriendship and not methods:get(source.timeOfDay and 'FRIENDSHIP_NIGHT' or 'FRIENDSHIP') then
      why='missing_friendship_owner'
    elseif timedLevel and (type(opts.timeMode)~='function' or not methods:get('LEVEL')) then
      why='missing_timed_level_owner'
    elseif femaleLevel and (not opts.gender or type(opts.gender.getMonGender)~='function'
        or opts.gender.FEMALE~='FEMALE' or not methods:get('LEVEL')) then
      why='missing_gender_owner'
    elseif darkParty and not methods:get('LEVEL') then why='missing_level_owner'
    elseif parent.formId or target.formId or parent.isMega or target.isMega
        or parent.isGigantamax or target.isGigantamax then why='not_base_species'
    else
      local existing,conflict
      for _,row in ipairs(parent.evolutions or {})do
        if row.species==into then
          if matches(row,{species=into,method=nativeMethod,level=source.level,item=source.item}) then existing=row
          else conflict=true end
        end
      end
      if conflict then why='existing_rule_conflict'
      elseif existing and not methods:get(nativeMethod) then why='missing_method'
      elseif existing then
        -- Existing Hoenn owners are left byte-for-byte intact.
        approve(from,copy(existing))
        C.reused[#C.reused+1]={from=from,to=into,level=source.level,item=source.item}
        if source.item then itemPlans[source.item]=true end
      elseif wurmple or marill or (conditional and not known and not backendFriendship) then why='missing_condition_rule'
      elseif parent.backendOwner~=species.OWNER then why='protected_owner'
      else
        local row={method=method,species=into,level=source.level,item=source.item}
        approve(from,row)
        plans[#plans+1]={from=from,row=row,evolutions=copy(parent.evolutions or {})}
        C.registered[#C.registered+1]={from=from,to=into,level=source.level,item=source.item}
        if source.item then itemPlans[source.item]=true end
      end
    end
    if known and not why and approved[from] then
      requiredMoves[from]=requiredMove;requiredByTarget[into]=requiredMove
    end
    if (backendFriendship or azurill) and not why and approved[from] then friendshipOwners[from]=source.method end
    if timedLevel and not why and approved[from] then timedLevelOwners[from]=source.timeOfDay end
    if femaleLevel and not why and approved[from] then femaleLevelOwners[from]=true end
    if darkParty and not why and approved[from] then darkPartyOwners[from]=true end
    if why then C.pending[#C.pending+1]={key=key,target='dex:'..source.toDex,reason=why}end
  end
  if #plans>0 then
    if next(darkPartyOwners) then
      local native=assert(methods:get('LEVEL'))
      -- Capture authored permanent identities at registration. The live
      -- registry records are later projected into the selected battle era:
      -- Gen1 removes DARK, but must not erase this species' evolution rule.
      local permanentTypes={}
      for id,def in registry:each()do permanentTypes[id]=copy(def.types or {}) end
      methods:register('KA_BACKEND_LEVEL_DARK_PARTY',{
        check=function(game,mon,evo,trigger)
          local level=mon and mon.level
          if not healthy(mon) or not darkPartyOwners[mon.species]
              or not approvedRule(mon.species,evo) or evo.method~='KA_BACKEND_LEVEL_DARK_PARTY'
              or type(level)~='number' or level~=math.floor(level) or level<1 or level>100
              or not trigger or trigger.kind~='levelup' or not native.check(game,mon,evo,trigger) then
            return false
          end
          -- Use the current permanent species/form, not a birth receipt,
          -- nickname, temporary battle type or a private National-ID guess.
          -- Presence is sufficient: the partner itself may be fainted.
          for _,partner in ipairs(game and game.save and game.save.party or {})do
            if type(partner)=='table' and type(partner.species)=='string' and partner~=mon and not partner.isEgg
                and not partner.egg and not partner.eggSpecies then
              for _,kind in ipairs(permanentTypes[partner.species] or {})do
                if kind=='DARK' then return true end
              end
            end
          end
          return false
        end,
        describe=function(evo,gameData)
          local text=opts.i18n and opts.i18n.text
          return native.describe(evo,gameData)..(text
            and text(' with a Dark-type in the party',' mit Unlicht-Pokémon im Team')
            or ' with a Dark-type in the party')
        end,
      })
    end
    if opts.gender and type(opts.gender.getMonGender)=='function' and methods:get('LEVEL') then
      local native=methods:get('LEVEL')
      methods:register('KA_BACKEND_LEVEL_FEMALE',{
        check=function(game,mon,evo,trigger)
          local level=mon and mon.level
          local dv=mon and mon.dvs and mon.dvs.attack
          return healthy(mon) and femaleLevelOwners[mon.species]
            and approvedRule(mon.species,evo) and evo.method=='KA_BACKEND_LEVEL_FEMALE'
            and type(level)=='number' and level==math.floor(level) and level>=1 and level<=100
            and type(dv)=='number' and dv==math.floor(dv) and dv>=0 and dv<=15
            and trigger and trigger.kind=='levelup'
            and opts.gender.getMonGender(mon,game)==opts.gender.FEMALE
            and native.check(game,mon,evo,trigger) or false
        end,
        describe=function(evo,gameData)
          local text=opts.i18n and opts.i18n.text
          return native.describe(evo,gameData)
            ..(text and text(' (female only)',' (nur weiblich)') or ' (female only)')
        end,
      })
    end
    if type(opts.timeMode)=='function' and methods:get('LEVEL') then
      local native=methods:get('LEVEL')
      for _,time in ipairs({'day','night'})do
        local name='KA_BACKEND_LEVEL_'..time:upper()
        methods:register(name,{
          check=function(game,mon,evo,trigger)
            local level=mon and mon.level
            return healthy(mon) and timedLevelOwners[mon.species]==time
              and approvedRule(mon.species,evo) and evo.method==name
              and type(level)=='number' and level==math.floor(level) and level>=1 and level<=100
              and trigger and trigger.kind=='levelup' and opts.timeMode()==time
              and native.check(game,mon,evo,trigger) or false
          end,
          describe=function(evo,gameData)
            local text=opts.i18n and opts.i18n.text
            local suffix=time=='day' and (text and text(' by day',' tagsüber') or ' by day')
              or (text and text(' at night',' nachts') or ' at night')
            return native.describe(evo,gameData)..suffix
          end,
        })
      end
    end
    for _,name in ipairs({'FRIENDSHIP','FRIENDSHIP_NIGHT'})do
      local native=methods:get(name)
      if native then methods:register('KA_BACKEND_'..name,{
        check=function(game,mon,evo,trigger)
          local bond=mon and mon.johtoBond or 0
          return healthy(mon) and friendshipOwners[mon.species]=='KA_BACKEND_'..name
            and approvedRule(mon.species,evo) and evo.method=='KA_BACKEND_'..name
            and type(bond)=='number' and bond==math.floor(bond) and bond>=0 and bond<=255
            and trigger and trigger.kind=='levelup' and native.check(game,mon,evo,trigger) or false
        end,
        describe=native.describe,
      })end
    end
    methods:register('KA_BACKEND_KNOWN_MOVE',{
      check=function(game,mon,evo,trigger)
        if not healthy(mon) or not approvedRule(mon.species,evo)
            or evo.method~='KA_BACKEND_KNOWN_MOVE' or not trigger or trigger.kind~='levelup'
            or not requiredMoves[mon.species] or not game.data.moves[requiredMoves[mon.species]] then return false end
        for _,move in ipairs(mon.moves or {})do
          if type(move)=='table' and move.id==requiredMoves[mon.species] then return true end
        end
        return false
      end,
      describe=function(evo,gameData)
        local required=requiredByTarget[evo.species]
        local name=gameData and gameData.moves and gameData.moves[required]
        local text=opts.i18n and opts.i18n.text
        return (text and text('Level up knowing ','Levelaufstieg mit ') or 'Level up knowing ')
          .. (name and name.name or required or '?')
      end,
    })
    for _,kind in ipairs({'LEVEL','ITEM'})do
      local native=assert(methods:get(kind),'native evolution method unavailable '..kind)
      methods:register('KA_BACKEND_'..kind,{
        check=function(game,mon,evo,trigger)
          return healthy(mon) and approvedRule(mon.species,evo)
            and evo.method=='KA_BACKEND_'..kind and native.check(game,mon,evo,trigger) or false
        end,
        describe=native.describe,consumesItem=native.consumesItem,
      })
    end
    local combined={}
    for _,plan in ipairs(plans)do
      local rows=combined[plan.from] or plan.evolutions
      rows[#rows+1]=copy(plan.row);combined[plan.from]=rows
    end
    for from,rows in pairs(combined)do
      registry:patch(from,{evolutions=rows})
    end
  end
  -- Reserve walking uses the existing cadence owner, never a second event
  -- listener. Only reviewed, registered base-family routes participate.
  function C.walkFriendshipEligible(mon)
    return healthy(mon) and friendshipOwners[mon.species]~=nil or false
  end
  -- An original gift receipt is immutable. Grant the next approved edge only
  -- when the current species is reachable from that gift's original identity.
  -- This also supports a saved middle stage without creating new receipts.
  local previous=species.giftEvolutionAllowed
  function C.giftEvolutionAllowed(game,mon,evo)
    if not healthy(mon) or type(evo)~='table' then return false end
    if not approvedRule(mon.species,evo) then return false end
    local archive=mod.exports and mod.exports.eventArchive
    if not archive then return false end
    local valid,_,profile=archive.battleCompatibleGift(mon)
    if not valid or not profile or profile.formId or profile.megaFormId
        or profile.gigantamaxFormId then return false end
    local original=species.byKey[profile.backendKey]
    if not original or original~=profile.species then return false end
    local seen,queue={}, {original}
    while #queue>0 do
      local current=table.remove(queue)
      if current==mon.species then return true end
      if not seen[current] then
        seen[current]=true
        for _,step in ipairs(approved[current] or {})do queue[#queue+1]=step.species end
      end
    end
    return false
  end
  species.giftEvolutionAllowed=function(game,mon,evo)
    return C.giftEvolutionAllowed(game,mon,evo)
      or previous and previous(game,mon,evo) or false
  end
  -- The native stone effect scans ITEM rows directly and does not call
  -- evolution.check. Route only our owned rows through the guarded dispatch.
  -- Other Pokemon retain the exact previous item/effect definition.
  for item in pairs(itemPlans)do
    local original=copy(mod.content.items:get(item))
    local effect='KA_BACKEND_EVOLUTION_'..item
    mod.content.item_effects:register(effect,{
      field=true,battle=false,needsTarget=true,
      use=function(ctx)
        local mon=ctx.target
        local row
        for _,candidate in ipairs(mon and approved[mon.species] or {})do
          if candidate.item==ctx.itemId then row=candidate;break end
        end
        if row and (row.method=='KA_BACKEND_ITEM' or row.method=='ITEM') then
          if not ctx.battle and healthy(mon) and row.item==ctx.itemId then
            local game={data=ctx.data,save=ctx.save,overworld=ctx.overworld}
            local target=require('src.pokemon.Evolution').pendingFor(game,mon,{kind='item',item=ctx.itemId})
            if target==row.species then return 'consumed',nil,{evolveTo=target,evolveVia='ITEM'} end
          end
          local en="It won't have\nany effect."
          return 'failed',{opts.i18n and opts.i18n.text and opts.i18n.text(en,
            'Es hat keine\nWirkung.') or en}
        end
        local fallback={};for k,v in pairs(ctx.data)do fallback[k]=v end
        fallback.items={};for k,v in pairs(ctx.data.items)do fallback.items[k]=v end
        fallback.items[item]=original
        return require('src.inventory.ItemEffects').use(fallback,ctx.save,ctx.itemId,
          ctx.target,ctx.battle,ctx.moveIndex,ctx.overworld)
      end,
    })
    -- BagMenu checks the item-level flag before its registered effect.
    -- Johto's original stone metadata explicitly says false; leaving that
    -- value in place skips the party picker despite our targeted effect.
    -- Keep both contracts explicit, including older two-argument wrappers.
    mod.content.items:patch(item,{effect=effect,needsTarget=true})
  end
  function C.status()
    return {registered=copy(C.registered),reused=copy(C.reused),pending=copy(C.pending),
      sourceCommit=data.sourceCommit,completeWave1=false}
  end
  return C
end
