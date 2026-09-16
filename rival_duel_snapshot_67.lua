-- Detached, deterministic presentation roster. Never construct a battle or
-- borrow the player's Pokémon; the visit owns its already-scaled team plans.
return function(mod, opts)
  opts=opts or {}
  local S={VERSION=1}
  local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,c in pairs(v)do out[k]=copy(c)end;return out
  end
  local function hash(text,seed)
    local h=seed or 104729
    for i=1,#text do h=(h*131+text:byte(i)+i)%2147483647 end
    return h
  end
  local function encode(v)
    if type(v)~='table' then return type(v)..':'..tostring(v)end
    local keys,out={},{}
    for k in pairs(v)do keys[#keys+1]=k end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    for _,k in ipairs(keys)do out[#out+1]=encode(k)..'='..encode(v[k])end
    return '{'..table.concat(out,';')..'}'
  end
  local heal={REST=true,RECOVER=true,SOFTBOILED=true,MILK_DRINK=true,
    ROOST=true,SLACK_OFF=true,SYNTHESIS=true,MORNING_SUN=true,MOONLIGHT=true,
    HEAL_ORDER=true,SHORE_UP=true}
  local protect={PROTECT=true,DETECT=true,ENDURE=true,KINGS_SHIELD=true,
    SPIKY_SHIELD=true,BANEFUL_BUNKER=true,WIDE_GUARD=true,QUICK_GUARD=true}
  local multi={FLY=true,DIG=true,DIVE=true,BOUNCE=true,PHANTOM_FORCE=true,
    SHADOW_FORCE=true,SKY_DROP=true}
  function S.semantic(id,def)
    if heal[id]then return 'HEAL'end
    if protect[id]then return 'PROTECT'end
    if multi[id]then return 'MULTIPHASE'end
    if id=='DOUBLE_TEAM' or id=='MINIMIZE'then return 'DODGE'end
    if id=='SOLARBEAM' or id=='SOLAR_BEAM' or id=='SOLAR_BLADE'
        or id=='SKULL_BASH' or id=='RAZOR_WIND'then return 'CHARGE'end
    if (tonumber(def.power)or 0)>0 or def.category=='PHYSICAL'
        or def.category=='SPECIAL' then
      return def.category=='SPECIAL' and 'RANGED' or 'MELEE'
    end
    -- Other status commands retain their actual move name. RANGED covers
    -- opponent-directed status; BOOST is reserved for self-directed effects.
    local effect=tostring(def.effect or '')
    if effect:find('UP',1,true) or id=='FOCUS_ENERGY' then return 'BOOST'end
    return 'RANGED'
  end
  function S.build(game,visit)
    if not(visit and visit.duel and #visit.actors==2)then return nil,'NOT_DUEL'end
    local resolved=opts.rules and opts.rules.resolve(game)or{activeEpoch=1}
    local epoch=resolved.activeEpoch or 1
    local text=encode({map=visit.mapId,token=visit.token,actors=visit.actors,epoch=epoch})
    local seed=hash(text);local digest={}
    for i=1,8 do digest[i]=string.format('%08x',hash(text,seed+i))end
    local scene='VISIT:'..tostring(visit.mapId)..':'..tostring(visit.token)
    local result={version=S.VERSION,sceneId=scene,opportunity=seed+1,
      pair={},snapshots={},mons={}}
    local newMon=opts.newMon or require('src.pokemon.Pokemon').new
    for index,row in ipairs(visit.actors)do
      local plan=row.duelPlan or row.battlePlan
      if not(plan and plan.actor==row.actor and type(plan.team)=='table')then
        return nil,'MISSING_TEAM'
      end
      local chosen
      -- Prefer the ace, but use another real team member if its moves cannot
      -- be represented in the currently active ruleset. No invented Tackle.
      for slot=#plan.team,1,-1 do
        local member=plan.team[slot]
        if game.data.pokemon[member.species]then
          local rngSeed=hash(row.actor..':'..slot,seed)
          local function rng(lo,hi)
            rngSeed=(rngSeed*48271)%2147483647
            return lo+rngSeed%(hi-lo+1)
          end
          local mon=newMon(game.data,member.species,member.level,rng)
          local moves,seen={},{}
          for position,m in ipairs(member.moves or mon.moves or {})do
            local id=type(m)=='table'and m.id or m
            local def=game.data.moves[id]
            local allowed=not opts.rules or opts.rules.monMoveAvailable(game,mon,id,
              epoch,resolved.extensionsEnabled)
            if position<=4 and def and allowed and not seen[id]then
              moves[#moves+1]={slot=position,moveId=id,semanticClass=S.semantic(id,def),
                legalAtSnapshot=true,source='SNAPSHOT_MOVESET'}
              seen[id]=true
            end
          end
          if #moves>0 then chosen={mon=mon,moves=moves,slot=slot};break end
        end
      end
      if not chosen then return nil,'NO_LEGAL_MOVES'end
      result.pair[index]=row.actor
      result.mons[row.actor]=copy(chosen.mon)
      result.snapshots[row.actor]={schema='rival.team-move-snapshot/v1',
        snapshotId='SNAP:'..row.actor..':'..seed,sceneId=scene,actor=row.actor,
        source='ACTIVE_STORY_TEAM',storyStateDigest=table.concat(digest),
        ruleSetId='KASC_GEN_'..epoch,capturedAtOpportunity=result.opportunity,
        pokemon={speciesId=chosen.mon.species,teamSlot=chosen.slot,level=chosen.mon.level,
          presentation={variant='FRONT',mirrored=index==1,facesOpponent=true},
          initialHpBand='FULL'},moves=chosen.moves,
        outcomePlan={seed=seed,resultCode='DRAW',actionCount=6}}
    end
    return result
  end
  return S
end
