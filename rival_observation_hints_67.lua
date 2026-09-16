-- Read-only encounter observations, one frozen rare hint per ordinary stay.
-- No encounter.roll calls, copied quest flags, roamer movement or rewards.
return function(mod,opts)
  local M={CARD_ID='KASC-67-RIVAL-OBSERVATIONS',OWNER='kasc.rival-observations/v1',PERCENT=5}
  local actors={RED=true,BLUE=true,GREEN=true}
  local sources={hoenn_roamer=true,postgame_roamer=true,mythic_signals=true}
  local clues={
    LATIAS={'a red shape flying low','einen roten Schatten im Tiefflug'},
    LATIOS={'a blue shape crossing the sky','einen blauen Schatten am Himmel'},
    ENTEI={'a great beast with a smoke-like mane','ein großes Tier mit einer rauchigen Mähne'},
    RAIKOU={'a yellow beast racing past','ein gelbes Tier im Vorbeirennen'},
    SUICUNE={'a blue beast with flowing ribbons','ein blaues Tier mit wehenden Bändern'},
    MEW={'a small pink silhouette','eine kleine rosa Gestalt'},
    CELEBI={'a little green silhouette','eine kleine grüne Gestalt'},
  }
  local function tr(en,de)return opts.i18n and opts.i18n.text(en,de) or en end
  local function route(mapId)
    return type(mapId)=='string' and (mapId:match('^ROUTE_%d+$') or mapId=='VIRIDIAN_FOREST')
  end
  local function grassActive(game,mapId)
    local data=game and game.data
    local def=data and data.encounters and data.encounters[mapId]
    local pool=def and def.grass
    if not pool or not data.pokemon or (tonumber(pool.rate) or 0)<=0 or type(pool.slots)~='table' then return false end
    local buckets=pool.buckets or data.field and data.field.constants
      and data.field.constants.encounterBuckets or {51,102,141,166,191,216,229,242,253,256}
    local previous=0
    for i,row in ipairs(pool.slots)do
      local edge=tonumber(buckets[i]) or previous
      if math.min(edge,256)>previous and type(row)=='table' and data.pokemon[row.species]then return true end
      previous=math.max(previous,edge)
    end
    return false
  end
  local function key(row)return row.source..':'..row.kind..':'..row.species end
  function M.pool(game,mapId)
    local out,seen={},{}
    if not route(mapId) or not grassActive(game,mapId)
        or not opts.rules or not opts.rules.peekSpeciesAvailable then return out end
    for _,source in ipairs(opts.sources or {})do
      if type(source.observations)=='function' then
        local ok,rows=pcall(source.observations,game,mapId)
        if ok and type(rows)=='table' then for _,row in ipairs(rows)do
          if type(row)=='table' and clues[row.species] and row.mapId==mapId and sources[row.source]
              and (row.kind=='roamer' or row.kind=='echo' or row.kind=='manifestation')
              and game.data.pokemon[row.species]
              and opts.rules.peekSpeciesAvailable(game,row.species,game.data.pokemon[row.species])then
            local id=key(row)
            if not seen[id]then
              out[#out+1]={species=row.species,mapId=mapId,source=row.source,kind=row.kind}
              seen[id]=true
            end
          end
        end end
      end
    end
    table.sort(out,function(a,b)return key(a)<key(b)end)
    return out
  end
  function M.prepare(game,mapId,visitors,token,rng)
    if not visitors or #visitors==0 then return false end
    local pool=M.pool(game,mapId)
    if #pool==0 or rng(1,100,'visit_rare_hint')>M.PERCENT then return false end
    local row=pool[rng(1,#pool,'visit_hint_source')]
    local actor=visitors[rng(1,#visitors,'visit_hint_actor')].actor
    if not actors[actor]then return false end
    row.version,row.actor,row.token=1,actor,token
    return row
  end
  function M.dialogue(game,actor,mapId,receipt)
    if type(receipt)~='table' or receipt.version~=1 or receipt.actor~=actor
        or not actors[actor] or receipt.mapId~=mapId or not clues[receipt.species]
        or not sources[receipt.source] or type(receipt.kind)~='string' then return nil end
    local valid=false
    for _,row in ipairs(M.pool(game,mapId))do
      if key(row)==key(receipt)then valid=true;break end
    end
    if not valid then return nil end
    local clue=clues[receipt.species]
    local en,de
    if receipt.kind=='roamer' then
      if actor=='BLUE' then
        en="BLUE: I spotted %s here.\fIt was fast.\nNext time, I'll be ready."
        de="BLUE: Ich sah hier %s.\fEs war schnell.\nNächstes Mal bin ich bereit."
      elseif actor=='GREEN' then
        en="GREEN: I noticed %s here.\fI'm checking the tracks.\nWant to keep an eye out?"
        de="GREEN: Ich bemerkte hier %s.\fIch suche nach Spuren.\nHältst du auch die Augen offen?"
      else
        en="RED: I saw %s here.\fIt passed quickly.\nStay alert."
        de="RED: Ich sah hier %s.\fEs war schnell vorbei.\nBleib aufmerksam."
      end
    elseif receipt.kind=='echo' then
      if actor=='BLUE' then
        en="BLUE: They say you can glimpse %s here.\fI'm not wasting a ball on an echo.\fI'll find the real one."
        de="BLUE: Hier soll man %s sehen können.\fFür ein Echo verschwende ich keinen Ball.\fIch finde das echte Pokémon."
      elseif actor=='GREEN' then
        en="GREEN: You might glimpse %s here.\fIt could just be an echo.\fLook closely before trying to catch anything."
        de="GREEN: Vielleicht siehst du hier %s.\fDas könnte nur ein Echo sein.\fSieh genau hin, bevor du einen Fang versuchst."
      else
        en="RED: Watch for %s here.\fCould be an echo.\nWait for a real sighting."
        de="RED: Achte hier auf %s.\fVielleicht nur ein Echo.\nWarte auf eine echte Spur."
      end
    else
      if actor=='BLUE' then
        en="BLUE: Keep an eye out for %s here.\fIt might really be here now.\fLet's see who finds it first."
        de="BLUE: Halte hier nach %s Ausschau.\fVielleicht ist es diesmal wirklich da.\fMal sehen, wer es zuerst findet."
      elseif actor=='GREEN' then
        en="GREEN: Look for %s here.\fThe traces could lead to a real encounter now.\fTell me if you find anything."
        de="GREEN: Such hier nach %s.\fDie Spuren könnten diesmal zu einem echten Pokémon führen.\fSag Bescheid, wenn du etwas findest."
      else
        en="RED: Watch for %s here.\fThe traces are promising.\nI'll keep looking."
        de="RED: Achte hier auf %s.\fDie Spuren sehen gut aus.\nIch suche weiter."
      end
    end
    local function pages(text)
      local out={}
      for page in (text..'\f'):gmatch('(.-)\f')do
        local lines={}
        for line in (page..'\n'):gmatch('(.-)\n')do
          local current=''
          for word in line:gmatch('%S+')do
            local joined=current=='' and word or current..' '..word
            if #joined:gsub('[\128-\191]','')>26 and current~='' then
              lines[#lines+1]=current;current=word
            else current=joined end
          end
          if current~='' then lines[#lines+1]=current end
        end
        for i=1,#lines,2 do out[#out+1]=lines[i]..(lines[i+1] and '\n'..lines[i+1] or '')end
      end
      return table.concat(out,'\f')
    end
    en,de=pages(en:format(clue[1])),pages(de:format(clue[2]))
    return {id='rival_observation_'..actor:lower()..'_'..key(receipt),
      category='observation',kind='observation',species=receipt.species,mapId=mapId,
      en=en,de=de,text=tr(en,de)}
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='read-only-encounter-owners',providerStatus='visit-bound-revalidated-hints',
      buildReceiptId='qa/gen6-wave15-alignment-20260909/RIVAL-OBSERVATIONS-REVIEW.md',
      rollbackReceiptId='qa/gen6-wave15-alignment-20260909/RIVAL-OBSERVATIONS-REVIEW.md'})
  end
  return M
end
