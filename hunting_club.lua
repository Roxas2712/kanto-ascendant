-- PKMN Hunting Club: finite contracts, generation-safe requirements and rewards.
return function(mod, opts)
  local D, rules = assert(opts.data), assert(opts.generationRules)
  local H = { total = D.total }
  local KEY, MAP, NPC, TEXT = 'hunting_club', 'CELADON_CITY',
    'KANTO_ASCENDANT_HUNTING_LEAD', 'MOD_KANTO_ASCENDANT_HUNTING_CLUB'
  local SPRITE = 'SPRITE_KA_MIRA_WALK'
  if mod.content.sprites then
    mod.content.sprites:register(SPRITE, {
      id=SPRITE, image=mod.path..'/assets/hunting_club/mira_walk.png',
      frames=6, walker=true, trueColor=false,
    })
  end
  local badges = {'BOULDERBADGE','CASCADEBADGE','THUNDERBADGE','RAINBOWBADGE',
    'SOULBADGE','MARSHBADGE','VOLCANOBADGE','EARTHBADGE'}
  local byId = {}
  for _, row in ipairs(D.contracts) do assert(not byId[row.id]); byId[row.id] = row end
  local ranks = {bronze=0, silver=10, gold=30, master=45}
  local shop = {
    {id='RARE_CANDY', cost=30}, {id='PP_UP', cost=60},
    {id='MAX_ELIXER', cost=40}, {id='MASTER_BALL', cost=500, limit=1},
  }
  local function tr(en,de) return opts.i18n and opts.i18n.text(en,de) or en end
  local function copy(v)
    if type(v)~='table' then return v end
    local out={} for k,x in pairs(v) do out[k]=copy(x) end return out
  end
  local function state()
    local s=copy(mod.save:get(KEY) or {})
    s.version=1; s.done=s.done or {}; s.used=s.used or {}; s.points=s.points or 0
    s.claimed=s.claimed or {}; s.purchases=s.purchases or {}; s.serial=s.serial or 0
    s.cursor=s.cursor or 0; s.sealed=s.sealed or {}
    -- Older saves already contain accepted work; do not reintroduce Mira.
    s.acceptedOnce=s.acceptedOnce or s.active~=nil or next(s.done)~=nil or next(s.sealed)~=nil
    return s
  end
  local function persist(s) local ok,why=mod.save:set(KEY,s); if ok==false then error(why or 'club save failed') end end
  local function completed(s)
    local n=0 for id,yes in pairs(s.done) do if yes and byId[id] then n=n+1 end end return n
  end
  function H.unlocked(game)
    local save=game and game.save or {}; local bag=save.inventory or {}
    for _,id in ipairs(badges) do
      if not (bag[id]==true or (tonumber(bag[id])or 0)>0 or save[id]==true) then return false end
    end
    return true
  end
  local function owned(game,id)
    -- Requiring a previously acquired species also excludes inaccessible event-only sources.
    return game.save.pokedex and game.save.pokedex.owned and game.save.pokedex.owned[id]
  end
  local function breedable(game,id)
    local def=game.data.pokemon[id]
    if not def or not rules.speciesAvailable(game,id,def) then return false end
    local dex=def.dex
    local b=opts.breedingData[dex]
    if not b or not b.groups or #b.groups==0 then return false end
    for _,g in ipairs(b.groups) do if g=='no-eggs' or g=='ditto' then return false end end
    return not (def.legendary or def.mythical)
  end
  local function available(game,id) return breedable(game,id) and owned(game,id) end
  local function movesFor(game,id,level,count)
    local def=game.data.pokemon[id]; if not def then return nil end
    local candidates={}
    for _,m in ipairs(def.level1Moves or {}) do
      candidates[#candidates+1]={level=1,move=type(m)=='table' and (m.id or m.move) or m}
    end
    for _,m in ipairs(def.learnset or {}) do candidates[#candidates+1]=m end
    table.sort(candidates,function(a,b)
      if a.level==b.level then return tostring(a.move)<tostring(b.move) end
      return a.level<b.level
    end)
    local epoch=rules.resolve(game).activeEpoch
    local learned={}
    for _,m in ipairs(candidates) do
      if m.level<=level and game.data.moves[m.move] and rules.moveAvailable(m.move,epoch,game.data) then
        for i=#learned,1,-1 do if learned[i]==m.move then table.remove(learned,i) end end
        learned[#learned+1]=m.move
      end
    end
    count=count or #learned
    if #learned<count then return nil end
    local result={} for i=#learned-count+1,#learned do result[#result+1]=learned[i] end
    return result
  end
  local function requirementAvailable(game,r)
    if not available(game,r.species) then return false end
    local can={}
    for _,move in ipairs(movesFor(game,r.species,r.level) or {})do can[move]=true end
    for _,move in ipairs(r.moves)do if not can[move]then return false end end
    return true
  end
  local function build(game,row)
    local q={id=row.id,rank=row.rank,points=row.points,requirements={},shown={}}
    for _,id in ipairs(row.species) do
      if not available(game,id) then return nil end
      local moves=movesFor(game,id,row.level,row.moveCount)
      if not moves then return nil end
      q.requirements[#q.requirements+1]={species=id,level=row.level,moves=moves}
    end
    return q
  end
  function H.offers(game)
    if not H.unlocked(game) then return {} end
    local s=state(); local out={}; local n=completed(s)
    for step=1,#D.contracts do
      local row=D.contracts[(s.cursor+step-1)%#D.contracts+1]
      if not s.done[row.id] and (not s.active or s.active.id~=row.id) and n>=ranks[row.rank] then
        local q=s.sealed[row.id] or build(game,row)
        if q then
          local valid=true
          for _,r in ipairs(q.requirements) do
            if not requirementAvailable(game,r) then valid=false end
            for _,m in ipairs(r.moves) do
              if not rules.moveAvailable(m,rules.resolve(game).activeEpoch,game.data) then valid=false end
            end
          end
          if valid then out[#out+1]=copy(q) end
        end
        if #out==3 then break end
      end
    end
    return out
  end
  function H.accept(game,id)
    if not H.unlocked(game) then return false,'locked' end
    local s=state(); if s.active then return false,'active' end
    for _,q in ipairs(H.offers(game)) do
      if q.id==id then s.active=q; s.acceptedOnce=true; s.sealed[id]=copy(q); persist(s); return true end
    end
    return false,'unavailable'
  end
  function H.rotate(game)
    if not H.unlocked(game) then return false end
    local s=state(); if s.active then return false end
    s.cursor=(s.cursor+3)%#D.contracts; persist(s); return true
  end
  function H.pause(game)
    if not H.unlocked(game) then return false end
    local s=state(); if not s.active then return false end
    s.sealed[s.active.id]=copy(s.active); s.active=nil; persist(s); return true
  end
  local function matches(game,mon,r)
    if not mon or mon.isEgg or mon.eggSpecies or mon.species~=r.species
      or (tonumber(mon.level)or 0)<r.level or not available(game,r.species) then return false end
    local have={} for _,m in ipairs(mon.moves or {}) do have[type(m)=='table' and m.id or m]=true end
    local epoch=rules.resolve(game).activeEpoch
    for _,m in ipairs(r.moves) do if not have[m] or not rules.moveAvailable(m,epoch,game.data) then return false end end
    return true
  end
  function H.present(game,partyIndex)
    if not H.unlocked(game) then return false,'locked' end
    local s=state(); local q=s.active; if not q or s.done[q.id] then return false,'inactive' end
    for _,r in ipairs(q.requirements) do
      if not requirementAvailable(game,r) then return false,'unavailable' end
      for _,m in ipairs(r.moves)do if not rules.moveAvailable(m,rules.resolve(game).activeEpoch,game.data)then return false,'unavailable'end end
    end
    local mon=(game.save.party or {})[partyIndex]
    if not mon then return false,'missing' end
    if mon._kascHuntingClub or (mon._kascHuntingId and s.used[mon._kascHuntingId]) then return false,'used' end
    for i,r in ipairs(q.requirements) do
      if not q.shown[i] and matches(game,mon,r) then
        s.serial=s.serial+1; local token='HC-MON-'..s.serial
        s.used[token]=q.id; q.shown[i]=true
        local finished=true for j=1,#q.requirements do if not q.shown[j] then finished=false end end
        if finished then
          s.done[q.id]=true; s.points=s.points+q.points; s.active=nil; s.sealed[q.id]=nil
        else s.sealed[q.id]=copy(q) end
        persist(s)
        mon._kascHuntingId=token; mon._kascHuntingClub=q.id
        return true,finished and 'complete' or 'registered'
      end
    end
    return false,'requirements'
  end
  function H.buy(game,id)
    if not H.unlocked(game) then return false,'locked' end
    local s=state()
    for _,row in ipairs(shop) do if row.id==id then
      if not game.data.items[id] or s.points<row.cost or (row.limit and (s.purchases[id]or 0)>=row.limit) then return false,'unavailable' end
      local old=copy(game.save.inventory)
      local Bag=opts.Bag or require('src.inventory.Bag')
      if not Bag.add(game.save,id,1,game.data) then return false,'bag_full' end
      s.points=s.points-row.cost; s.purchases[id]=(s.purchases[id]or 0)+1
      local ok,err=pcall(persist,s)
      if not ok then game.save.inventory=old; error(err) end
      return true
    end end
    return false,'unknown'
  end
  local function eggPool(game,legendary)
    local out={}
    for _,id in ipairs(legendary and D.legendaryEggPool or D.eggPool) do
      local def=game.data.pokemon[id]
      if def and rules.speciesAvailable(game,id,def) then out[#out+1]=id end
    end
    return out
  end
  -- Seal rewards before claiming, so re-entering the menu cannot reroll them.
  function H.sealRewards(game)
    if not H.unlocked(game) then return end
    local s=state(); local pool=eggPool(game); if #pool==0 then return end
    local n=completed(s); s.eggs=s.eggs or {}; local changed=false
    for _,threshold in ipairs({30,60,90,120}) do
      local key=tostring(threshold)
      if n>=threshold and not s.eggs[key] then
        local random=opts.random or math.random
        local legends=eggPool(game,true)
        local chosen=(#legends>0 and random(D.legendaryEggOdds)==1) and legends or pool
        s.eggs[key]=chosen[random(#chosen)]; changed=true
      end
    end
    if changed then persist(s) end
  end
  function H.claimEgg(game,threshold)
    if not H.unlocked(game) then return false,'locked' end
    H.sealRewards(game)
    local s=state(); local key=tostring(threshold); local id=s.eggs and s.eggs[key]
    if not id or s.claimed[key] or not game.data.pokemon[id]
      or not rules.speciesAvailable(game,id,game.data.pokemon[id]) then return false,'unavailable' end
    if #(game.save.party or {})>=6 then return false,'party_full' end
    local Pokemon=opts.Pokemon or require('src.pokemon.Pokemon')
    local mon=Pokemon.new(game.data,id,5)
    if opts.stampOT then opts.stampOT(game.save,mon)
    else require('src.battle.BattleState').stampOT(game.save,mon) end
    opts.shinySystem.forceMon(mon,game.data.pokemon[id])
    mon.isEgg=true; mon.eggSpecies=id; mon.eggStepsRemaining=5120; mon.eggTotalSteps=5120
    mon.eggOrigin='PKMN HUNTING CLUB'; mon.nickname='EGG'; mon.hp=0; mon.status=nil
    s.claimed[key]=true; persist(s); table.insert(game.save.party,mon)
    return true
  end
  function H.status() local s=state(); return {completed=completed(s),points=s.points,active=s.active,total=D.total} end
  local function monName(game,id) return (game.data.pokemon[id] or {}).name or id end
  local function details(game,q)
    local lines={}
    for i,r in ipairs(q.requirements) do
      lines[#lines+1]=(q.shown[i] and '[OK] ' or '')..monName(game,r.species)..' Lv. '..r.level..'+'
      local moves={}
      for _,m in ipairs(r.moves) do moves[#moves+1]=((game.data.moves[m]or {}).name or m) end
      lines[#lines+1]=table.concat(moves,', ')
    end
    return table.concat(lines,'\n')
  end
  local function contractLabel(game,q)
    local label=monName(game,q.requirements[1].species)
    if #q.requirements>1 then label=label..' +'..(#q.requirements-1) end
    return label
  end
  local function box(game,text,done) game.stack:push(require('src.render.TextBox').new(game,text,done)) end
  local function menu(game,title,rows,done)
    local screen=(mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,title,rows,{
      onCancel=done or function()end,
      onChoose=function(item,m) if item.action then item.action(m) end end,
    })
    -- Refreshing a board is a new choice, not a return to its old PAUSE row.
    screen.index,screen.scroll=1,0
    screen.__vascHeaderLabel='PKMN HUNTING CLUB'
    game.stack:push(screen)
    return screen
  end
  -- Only earned/affordable rewards enter the UI. Future milestones and their
  -- contents remain a surprise; the reward ledger itself is unchanged.
  local function rewardRows(game)
    local s=state();local n=completed(s);local rows={}
    if H.wardrobe then
      for _,entry in ipairs(H.wardrobe.rewards()) do
        local reward=entry
        if n>=reward.required and s.points>=reward.cost then
          rows[#rows+1]={label=reward.name,right=reward.cost..' CP',claim=function()
            return H.wardrobe.claim(game,reward.id)
          end,message=tr('Outfit unlocked!','Outfit freigeschaltet!')}
        end
      end
    end
    for _,item in ipairs(shop) do
      local row=item
      if game.data.items[row.id] and s.points>=row.cost
          and (not row.limit or (s.purchases[row.id]or 0)<row.limit) then
        rows[#rows+1]={label=game.data.items[row.id].name or row.id,right=row.cost..' CP',claim=function()
          return H.buy(game,row.id)
        end,message=tr('Reward received!','Belohnung erhalten!')}
      end
    end
    for _,threshold in ipairs({30,60,90,120}) do
      local milestone=threshold;local key=tostring(milestone)
      local id=s.eggs and s.eggs[key]
      if n>=milestone and id and not s.claimed[key] and game.data.pokemon[id]
          and rules.speciesAvailable(game,id,game.data.pokemon[id]) then
        rows[#rows+1]={label=tr('COLLECT GIFT','GESCHENK ABHOLEN'),claim=function()
          return H.claimEgg(game,milestone)
        end,message=tr('An EGG for you!','Ein EI für dich!')}
      end
    end
    return rows
  end
  function H.open(game,done)
    if not H.unlocked(game) then if done then done()end;return false end
    H.sealRewards(game)
    local s=state();local rows={}
    local function board() H.open(game,done) end
    local function replace(screen,nextScreen)
      screen:close()
      nextScreen()
    end
    if s.active then
      local q=s.active
      rows[#rows+1]={label=contractLabel(game,q),right='+'..q.points..' CP',help=details(game,q),action=function(screen)
        local party={}
        for i,mon in ipairs(game.save.party or {}) do
          local index=i
          party[#party+1]={label=mon.nickname or monName(game,mon.species),right='Lv. '..mon.level,action=function(current)
            local ok,why=H.present(game,index)
            if ok then H.sealRewards(game) end
            local messages={complete=tr('Contract complete!','Auftrag abgeschlossen!')..'\n+'..q.points..' CP',
              registered=tr('Partner registered!','Partner registriert!'),used=tr('Already registered.','Bereits registriert.'),
              requirements=tr('Level or moves do not match.','Level oder Attacken passen nicht.'),
              inactive=tr('No active contract.','Kein aktiver Auftrag.')}
            if ok then replace(current,function()box(game,messages[why],board)end)
            else box(game,messages[why] or tr('Unavailable.','Nicht verfügbar.')) end
          end}
        end
        replace(screen,function()menu(game,tr('SHOW POKéMON','POKéMON VORZEIGEN'),party,board)end)
      end}
      rows[#rows+1]={label=tr('PAUSE CONTRACT','AUFTRAG PAUSIEREN'),action=function(screen)
        H.pause(game);replace(screen,board)
      end}
    else
      for _,offer in ipairs(H.offers(game)) do
        local q=offer
        rows[#rows+1]={label=contractLabel(game,q),right='+'..q.points..' CP',help=details(game,q),action=function(screen)
          if H.accept(game,q.id) then replace(screen,board)
          else box(game,tr('Unavailable.','Nicht verfügbar.')) end
        end}
      end
      if #rows==0 then
        rows[#rows+1]={label=completed(s)==D.total and tr('ALL DONE','ALLES ERLEDIGT') or tr('NO CONTRACTS','KEINE AUFTRÄGE')}
      else
        rows[#rows+1]={label=tr('OTHER CONTRACTS','ANDERE AUFTRÄGE'),action=function(screen)
          H.rotate(game);replace(screen,board)
        end}
      end
    end
    if #rewardRows(game)>0 then
      local function rewards()
        local entries=rewardRows(game)
        if #entries==0 then board();return end
        for _,entry in ipairs(entries)do
          local reward=entry
          reward.action=function(screen)
            local ok,why=reward.claim()
            if ok then replace(screen,function()box(game,reward.message,rewards)end)
            else box(game,why=='party_full' and tr('Make room in your party.','Mach Platz in deinem Team.')
              or why=='bag_full' and tr('Your Bag is full.','Dein Beutel ist voll.')
              or tr('Unavailable.','Nicht verfügbar.')) end
          end
        end
        menu(game,tr('REWARDS','BELOHNUNGEN')..' - '..state().points..' CP',entries,board)
      end
      rows[#rows+1]={label=tr('COLLECT REWARDS','PRÄMIEN ABHOLEN'),action=function(screen)replace(screen,rewards)end}
    end
    menu(game,(s.active and tr('ACTIVE CONTRACT','AKTIVER AUFTRAG') or tr('CONTRACTS','AUFTRÄGE'))..' - '..s.points..' CP',rows,done)
    return true
  end
  local greetingIndex={}
  local function greeting()
    local s=state()
    if not s.acceptedOnce then
      return tr("Badges look nice. But I\nwant to see what your\npartners can really do.\fPick something off the\nboard and show me. Your\npartners stay with you!",
        "Orden glänzen hübsch.\nMich interessiert, was\ndeine Partner draufhaben.\fSuch dir was von der Tafel\nund zeig's mir. Deine\nPartner bleiben bei dir!")
    end
    local key=s.active and 'active' or 'ready'
    local lines=s.active and {
      {"Back already? Let's see\nwhat you've got!", "Schon zurück? Na, dann\nzeig mal, was ihr könnt!"},
      {"That look says you've\ngot something for me.", "Der Blick sagt mir:\nDu hast was für mich."},
      {"My clipboard is ready.\nAre your partners?", "Mein Klemmbrett ist bereit.\nDeine Partner auch?"},
    } or {
      {"Still hungry? Good.\nThe board's right here.", "Noch nicht genug? Gut.\nDie Tafel hängt noch."},
      {"There you are! I was\nstarting to get bored.", "Da bist du ja! Mir wurde\nschon fast langweilig."},
      {"I've got the contracts.\nYou bring the surprises.", "Ich hab die Aufträge.\nDu sorgst für Überraschungen."},
    }
    greetingIndex[key]=(greetingIndex[key]or 0)%#lines+1
    local line=lines[greetingIndex[key]]
    return tr(line[1],line[2])
  end
  local function refresh(game)
    if not game or not mod.world then return end
    local ow=mod.world:overworld(); if not ow or not ow.map or ow.map.id~=MAP then return end
    for _,obj in ipairs((game.data.maps[MAP] or {}).objects or {}) do if obj.name==NPC then return end end
    if not H.unlocked(game) then return end
    local x,y=opts.placement.findWideRandom(ow,{{30,10},{31,10},{29,10}})
    if x then mod.world:spawnNpc(MAP,{name=NPC,sprite=SPRITE,movement='STAY',range='DOWN',text=TEXT,x=x,y=y}) end
  end
  mod.content.map_scripts:register(MAP,{priority=2400,talk={[TEXT]=function(game,ow,npc)
    if not H.unlocked(game) then return false end
    npc.frozen=true; npc:facePlayer(ow.player)
    box(game,greeting(),function()
      H.open(game,function()npc.frozen=false end)
    end)
    return true
  end}})
  mod.events:on('map.entered',function(ev) refresh(ev and ev.game or H.game) end)
  mod.events:on('save.loaded',function() refresh(H.game) end)
  function H.install(game) H.game=game; if H.wardrobe then H.wardrobe.migrate() end; refresh(game) end
  H.catalog=D; H.breedable=breedable; H.movesFor=movesFor
  H.readState=state; H.writeState=persist; H.completionCount=completed
  H.readClothes=function()local s=mod.save:get(KEY);return s and s.clothes end
  return H
end
