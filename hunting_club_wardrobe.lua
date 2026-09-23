-- Uses registered authored recipes; never grants a Champion part through a mixed outfit.
return function(H,W,mod)
  local M={}; local eligible,parts,protected,championRecipes={},{},{},{}
  local rawGet=W and W.get
  if not W or not W.assets or not W.assets.packages then return M end
  -- Accessories belong to a complete reward bundle, never a random part roll.
  local extras={city={head={'league-cap','league-cap-backward'},eyewear={'glasses'}},
    trail={eyewear={'sunglasses'}},lotta={head={'lotta-cap-backward'}}}
  for key,record in pairs(W.assets.packages) do
    if key:match(':champion$') then
      local character=key:match('^(.-):');protected[character]={}
      for slot,part in pairs(record.recipe.parts) do
        if part~='original' then protected[character][slot..':'..part]=true end
      end
    end
  end
  for key,record in pairs(W.assets.packages) do
    local character,outfit=key:match('^(.-):(.*)$'); local valid=outfit~='original' and outfit~='champion'
    local needsChampion=false
    local garments={}
    for slot,part in pairs(record.recipe.parts) do
      if part:find('champion',1,true) or (protected[character]or {})[slot..':'..part] then needsChampion=true end
      if part~='original' then garments[slot..':'..part]=true end
    end
    if outfit=='champion' then championRecipes[key]=true end
    if valid then
      for slot,values in pairs(extras[outfit]or{})do
        for _,part in ipairs(values)do
          if record.pack.parts[slot]and record.pack.parts[slot][part]then garments[slot..':'..part]=true end
        end
      end
      local def=W.catalog.find(character,outfit)or {}
      eligible[key]={id=key,character=character,outfit=outfit,name=def.de or def.en or outfit,
        cost=100,required=10,parts=garments,requiresChampion=needsChampion}
      parts[character]=parts[character]or {}
      for part in pairs(garments)do parts[character][part]=true end
    end
  end
  local function characterId(id)id=tostring(id or 'RED'):upper();return W.catalog.characters[id] and id or 'RED' end
  local function state()
    local s=H.readState();s.clothes=s.clothes or {owned={},parts={}}
    s.clothes.owned=s.clothes.owned or {};s.clothes.parts=s.clothes.parts or {}
    return s
  end
  local function grant(s,row)
    s.clothes.owned[row.id]=true
    s.clothes.parts[row.character]=s.clothes.parts[row.character]or {}
    for part in pairs(row.parts)do s.clothes.parts[row.character][part]=true end
  end
  function M.migrate(game)
    game=game or H.game; if not game then return end
    local prior=H.readClothes()
    if prior and prior.migrated then
      if prior.bundleVersion~=2 then
        local s=state()
        for id,row in pairs(eligible)do if s.clothes.owned[id]then grant(s,row)end end
        s.clothes.bundleVersion=2;H.writeState(s)
      end
      return
    end
    local s=state();if s.clothes.migrated then return end
    -- Preserve currently worn outfits when importing a wardrobe save.
    for _,character in ipairs({'RED','BLUE','GREEN'})do
      local selected=rawGet(character);local row=eligible[character..':'..selected.outfit]
      if row then grant(s,row)end
      local record=W.assets.packages[character..':'..selected.outfit]
      local worn=record and record.recipe.parts or {}
      s.clothes.parts[character]=s.clothes.parts[character]or {}
      for _,field in ipairs({'upper','lower','footwear'})do
        local part=selected[field]=='preset'and worn[field]or selected[field]
        if part then s.clothes.parts[character][field..':'..part]=true end
      end
    end
    s.clothes.champions=s.clothes.champions or {}
    game=game or H.game
    if game and game.save and (#(game.save.hallOfFame or {})>0 or (game.save.flags or {}).EVENT_BEAT_CHAMPION_RIVAL) then
      s.clothes.champions[W.character()]=true
    end
    s.clothes.migrated=true;s.clothes.bundleVersion=2;H.writeState(s)
  end
  function M.rewards()
    M.migrate();local s=state();local out={}
    for id,row in pairs(eligible)do
      if row.character==W.character() and not s.clothes.owned[id]
        and(not row.requiresChampion or(s.clothes.champions or{})[row.character])then out[#out+1]=row end
    end
    table.sort(out,function(a,b)return a.id<b.id end);return out
  end
  function M.claim(game,id)
    if not H.unlocked(game)then return false,'locked'end
    M.migrate();local row=eligible[id];local s=state()
    if not row or s.clothes.owned[id]or H.completionCount(s)<row.required or s.points<row.cost then return false,'unavailable'end
    if row.character~=W.character()or(row.requiresChampion and not(s.clothes.champions or{})[row.character])then return false,'locked'end
    grant(s,row);s.points=s.points-row.cost;H.writeState(s);return true
  end
  function M.allowed(character,selection)
    character=characterId(character)
    M.migrate();local s={clothes=H.readClothes()or {owned={},parts={}}};local owned=s.clothes.parts[character]or {}
    local key=character..':'..tostring(selection.outfit)
    local champion=(s.clothes.champions or {})[character]==true
    if championRecipes[key] and not champion then return false end
    if eligible[key] and not s.clothes.owned[key]then return false end
    -- Check resolved garment IDs, not menu aliases (e.g. head=ash). Every
    -- surface uses these same parts, including a separately selected cap.
    local ok,resolved=pcall(W.assets.parts,character,selection)
    if not ok then return false end
    for field,part in pairs(resolved)do
      local token=field..':'..part
      local championPart=(protected[character]or {})[token]or part:find('champion',1,true)
      if championPart and not champion then return false end
      if not championPart and (parts[character]or {})[token] and not owned[token]then return false end
    end
    return true
  end
  local choose,rows,options=W.choose,W.rows,W.assets.options
  function W.choose(character,selection,game)
    character=characterId(character)
    if type(selection)~='table' then return choose(character,selection,game) end
    local merged=W.get(character);for key,v in pairs(selection or {})do merged[key]=v end
    if not M.allowed(character,merged)then return false,'hunting-club-locked'end
    return choose(character,selection,game)
  end
  function W.rows(character)
    character=characterId(character)
    local out={};M.migrate();local s={clothes=H.readClothes()or {owned={},parts={}}}
    for _,row in ipairs(rows(character))do
      local key=character..':'..row.id
      if row.id=='original'or(eligible[key]and s.clothes.owned[key]
        and(not eligible[key].requiresChampion or(s.clothes.champions or{})[character]))
        or(championRecipes[key]and(s.clothes.champions or{})[character])then out[#out+1]=row end
    end
    return out
  end
  if options then function W.assets.options(character,selection,field)
    local out={}
    for _,value in ipairs(options(character,selection,field))do
      local candidate={};for k,v in pairs(selection)do candidate[k]=v end;candidate[field]=value
      if field=='hairstyle'and value=='spiky'then candidate.head='none'end
      if field=='head'and value~='none'then candidate.hairstyle='standard'end
      if M.allowed(character,candidate)then out[#out+1]=value end
    end
    return out
  end end
  function M.recordChampion(game,character)
    M.migrate(game);local s=state();s.clothes.champions=s.clothes.champions or {}
    s.clothes.champions[character]=true;H.writeState(s)
  end
  function W.get(character)
    character=characterId(character)
    local selected=rawGet(character)
    if not M.allowed(character,selected) then
      selected.outfit='original';selected.upper='preset';selected.lower='preset';selected.footwear='preset'
      selected.head='classic';selected.bag='preset';selected.eyewear='none';selected.hairstyle='standard'
    end
    return selected
  end
  if mod and mod.hooks then
    mod.hooks:wrap('script.command',function(nextCommand,ctx,name,args)
      if name~='record_hall_of_fame' then return nextCommand(ctx,name,args) end
      local character=W.character();local before=#(ctx.save.hallOfFame or {})
      local result=nextCommand(ctx,name,args)
      if #(ctx.save.hallOfFame or {})>before then M.recordChampion(ctx.game,character) end
      return result
    end,275)
  end
  H.wardrobe=M;M.eligible=eligible;M.championRecipes=championRecipes
  return M
end
