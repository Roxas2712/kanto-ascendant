-- Run with Lua 5.1+ from the mod root; KASC_ENGINE points at a local engine checkout.
local engine=assert(os.getenv('KASC_ENGINE'))
local function copy(v) if type(v)~='table' then return v end local r={} for k,x in pairs(v)do r[k]=copy(x)end return r end
local D=dofile('hunting_club_data.lua')
local base=dofile(engine..'/data/generated/pokemon.lua')
local moves=dofile(engine..'/data/generated/moves.lua')
local breed=dofile('breeding_data.lua')
local johto=dofile('johto_data.lua')
for id,def in pairs(johto.species)do base[id]=copy(def)end
local hoenn=dofile('hoenn_species_67_data.lua')
for id,row in pairs(hoenn.species)do
  local def={dex=row.runtimeDex,sourceDex=row.sourceDex,level1Moves={},learnset={}}
  for _,m in ipairs(row.sourceMoves)do if m.kind=='level' then
    def.learnset[#def.learnset+1]={level=m.level,move=m.move}
  end end
  base[id]=def
end
for dex,b in pairs(dofile('hoenn_species_67_runtime_data.lua').breeding)do breed[dex]=b end
local gen=dofile('generation_learnsets_67_data.lua')
local epoch=1;local blockedMove
local rules={resolve=function()return {activeEpoch=epoch}end,
  speciesAvailable=function(game,id,def)local dex=def.sourceDex or def.dex return dex<=(epoch==1 and 151 or epoch==2 and 251 or 386)end,
  moveAvailable=function(id)return id~=blockedMove end}
local saved,failSave,spawned={},false,0
local mod={save={get=function(_,k)return saved[k]end,set=function(_,k,v)if failSave then error('disk failure')end saved[k]=v end},
  content={map_scripts={register=function()end}},events={on=function()end},
  world={overworld=function()return nil end},ui={}}
local opts={data=D,generationRules=rules,breedingData=breed,placement={},random=function()return 1 end,
  Pokemon={new=function(_,id,l)return {species=id,level=l}end},stampOT=function()end,
  shinySystem={forceMon=function(mon)mon.shiny=true end},Bag={add=function(save,id,n)if save.full then return false end save.inventory[id]=(save.inventory[id]or 0)+n return true end}}
local H=dofile('hunting_club.lua')(mod,opts)
local checks=0
local function check(x,msg)checks=checks+1;assert(x,msg)end
local game={data={pokemon=copy(base),moves=copy(moves),items={}},save={inventory={},party={},pokedex={owned={}}}}
for _,id in ipairs({'RARE_CANDY','PP_UP','MAX_ELIXER','MASTER_BALL'})do game.data.items[id]={}end
local function unlock()
 for _,id in ipairs({'BOULDERBADGE','CASCADEBADGE','THUNDERBADGE','RAINBOWBADGE','SOULBADGE','MARSHBADGE','VOLCANOBADGE','EARTHBADGE'})do game.save.inventory[id]=1 end
end
check(#H.offers(game)==0,'eight badge lock')
unlock()
check(#H.offers(game)==0,'unacquired species excluded')
for id in pairs(base)do game.save.pokedex.owned[id]=true end
-- Validate the complete catalogue using real level-up records for each rules epoch.
local counts,ids,signatures={},{},{}
for _,row in ipairs(D.contracts)do
 check(not ids[row.id],'unique id');ids[row.id]=true
 local sig=table.concat(row.species,',');check(not signatures[sig],'unique species group');signatures[sig]=true
 counts[row.rank]=(counts[row.rank]or 0)+1
 check(#row.species<=3,'party cap')
end
check(counts.bronze==40 and counts.silver==35 and counts.gold==30 and counts.master==15,'rank totals')
for e=1,6 do
 epoch=e;game.data.pokemon=copy(base)
 -- Match the cumulative generation-learnset projection used by the game.
 for id,def in pairs(game.data.pokemon)do
   local dex=def.sourceDex or def.dex
   for _,r in ipairs(gen.byDex[dex]or {})do if r[1]<=e and r[2]=='L' then
     def.learnset=def.learnset or {};def.learnset[#def.learnset+1]={level=r[3],move=r[4]}; game.data.moves[r[4]]=game.data.moves[r[4]]or {name=r[4]}
   end end
 end
 for _,row in ipairs(D.contracts)do for _,id in ipairs(row.species)do
   local def=game.data.pokemon[id];check(def~=nil,'registered species '..id)
   if rules.speciesAvailable(game,id,def)then
     check(H.breedable(game,id),'breedable '..id)
     check(H.movesFor(game,id,row.level,row.moveCount)~=nil,'reachable moves '..id..' epoch '..e)
   end
 end end
end
local function makeMon(r)return {species=r.species,level=r.level+1,moves=(function()local t={}for _,m in ipairs(r.moves)do t[#t+1]={id=m}end return t end)()}end
saved={};epoch=1
local q=H.offers(game)[1];check(q~=nil,'offer')
check(H.accept(game,q.id),'accept');check(not H.accept(game,q.id),'one active')
local sealed=copy(H.status().active)
check(H.pause(game),'pause');check(H.accept(game,q.id),'resume')
check(H.status().active.requirements[1].moves[1]==sealed.requirements[1].moves[1],'requirements frozen')
game.save.party={makeMon(q.requirements[1])};game.save.party[1].isEgg=true
check(not H.present(game,1),'eggs rejected');game.save.party[1].isEgg=nil
local oldLevel=game.save.party[1].level;game.save.party[1].level=1
check(not H.present(game,1),'minimum level');game.save.party[1].level=oldLevel
blockedMove=q.requirements[1].moves[1];check(not H.present(game,1),'move generation revoked');blockedMove=nil
failSave=true;check(not pcall(H.present,game,1),'failed save reported');failSave=false
check(not game.save.party[1]._kascHuntingClub and H.status().completed==0,'save failure rollback')
check(H.present(game,1),'submit');check(H.status().completed==1,'one completion')
H=dofile('hunting_club.lua')(mod,opts)
check(H.status().completed==1,'reload preserves')
for i=1,45 do for _,r in ipairs(H.offers(game))do check(r.id~=q.id,'no repeated completed contract')end H.rotate(game)end
-- Complete the real 120-contract pool through public APIs, including split submissions.
epoch=6;saved={};local firstMon
for n=1,120 do
 local offers=H.offers(game);check(#offers>0,'progression cannot dead-end '..n)
 local contract=offers[1];check(H.accept(game,contract.id),'accept '..n)
 for i,r in ipairs(contract.requirements)do
  game.save.party={makeMon(r)}
  if not firstMon then firstMon=game.save.party[1]end
  check(H.present(game,1),'submit '..contract.id..'/'..i)
  check(not H.present(game,1),'same mon cannot resubmit')
 end
 H.sealRewards(game)
end
check(H.status().completed==120 and #H.offers(game)==0,'finite completion')
local points=H.status().points
check(H.buy(game,'MASTER_BALL'),'master ball reward');check(not H.buy(game,'MASTER_BALL'),'one master ball')
game.save.full=true;check(not H.buy(game,'RARE_CANDY'),'full bag');check(H.status().points==points-500,'no points lost');game.save.full=nil
failSave=true;local old=game.save.inventory.PP_UP;check(not pcall(H.buy,game,'PP_UP'),'shop save failure');failSave=false
check(game.save.inventory.PP_UP==old,'item rollback')
game.save.party={{},{},{},{},{},{}};check(not H.claimEgg(game,30),'full party retains egg')
game.save.party={};check(H.claimEgg(game,30),'claim egg');check(game.save.party[1].isEgg and game.save.party[1].shiny,'shiny egg')
check(not H.claimEgg(game,30),'no duplicate egg');H=dofile('hunting_club.lua')(mod,opts);check(not H.claimEgg(game,30),'no duplicate on reload')
check(not H.buy(game,'CHAMPION_OUTFIT'),'champion reward excluded')
print('HUNTING CLUB PASS: '..checks..' checks; 120 contracts; generation 1-6 catalogue; progression, persistence, capacity and rewards')
-- All Kanto contracts, including master contracts, finish without enabling Johto/Hoenn.
saved={};epoch=1;game.save.party={}
local expected=0
for _,row in ipairs(D.contracts)do
 local ok=true;for _,id in ipairs(row.species)do if not rules.speciesAvailable(game,id,game.data.pokemon[id])then ok=false end end
 if ok then expected=expected+1 end
end
for n=1,expected do
 local offer=H.offers(game)[1];check(offer~=nil,'Kanto progression '..n)
 check(H.accept(game,offer.id),'Kanto accept')
 for _,r in ipairs(offer.requirements)do game.save.party={makeMon(r)};check(H.present(game,1),'Kanto complete')end
end
check(H.status().completed==expected and #H.offers(game)==0,'Kanto finite count')
local s=H.readState();s.eggs={};s.claimed={};H.writeState(s)
opts.random=function(n)return 1 end;H=dofile('hunting_club.lua')(mod,opts);H.sealRewards(game)
check(H.readState().eggs['30']=='ARTICUNO','legendary egg admitted independently of breeding')
game.save.party={};check(H.claimEgg(game,30),'legendary egg claim');check(game.save.party[1].species=='ARTICUNO','legendary species')
local before=H.readState().eggs['60'];H.sealRewards(game);check(H.readState().eggs['60']==before,'sealed reward never rerolls')
print('ADDITIONAL PASS: '..checks..' cumulative checks; '..expected..' Kanto-only contracts including masters; legendary eggs')
