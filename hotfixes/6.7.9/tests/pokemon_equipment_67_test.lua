local root=os.getenv('KANTO_ASCENDANT_MOD_DIR') or '.'
local engine=os.getenv('GEN1RECOMP_DIR') or '.'
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
local Bag=require('src.inventory.Bag')
local Serializer=require('src.core.SaveSerializer')
local sha=dofile(root..'/legacy_bank_sha256.lua')
local function copy(v)return assert(Serializer.decode(assert(Serializer.encode(v))))end
local function equal(a,b)return Serializer.encode(a)==Serializer.encode(b)end
local make=dofile(root..'/pokemon_equipment_67.lua')
local saved,fail,locked,notifications=false,false,false,0
local gen=1;local writes=0;local callback
local definitions={BERRY={generation=2,holdable=true,effectSupported=true},
  LEFTOVERS={generation=2,holdable=true,effectSupported=true},
  POTION={generation=1,holdable=true,effectSupported=false},
  BICYCLE={generation=1,holdable=false}}
local function surfaces(game)
  local out={}
  for i,mon in ipairs(game.save.party or {})do out[#out+1]={mon=mon,location='party:'..i}end
  for i,mon in ipairs(game.save.box or {})do out[#out+1]={mon=mon,location='box:'..i}end
  return out
end
local opts={owned=surfaces,item=function(id)return definitions[id]end,
  generation=function()return gen end,bag=Bag,digest=sha,
  canEdit=function()return not locked,'battle_active' end,
  canWrite=function()return not locked,'battle_active' end,
  ability=function()return {id='OVERGROW',slot=1,active=gen>=3}end,
  writeSave=function(game)
    assert(game.mods.modSave==game.save.modData,"command staged metadata binding")
    writes=writes+1
    if callback then callback(game)end
    if fail then return false end
    saved=copy(game.save);return true
  end,
  changed=function()notifications=notifications+1 end}
local M=make(opts)
local notices=0
local unsubscribe=M.subscribe(function(result)
  notices=notices+1;result.itemId='OBSERVER_MUTATION'
end)
M.subscribe(function()error('consumer failed after commit')end)
local game={save={meta={playthroughId='fixture-run'},inventory={BERRY=2,LEFTOVERS=1,BICYCLE=1},
  party={{species='TREECKO'},{species='TREECKO',isEgg=true,eggSpecies='TREECKO'}},
  box={{species='PIKACHU',item='BERRY'}}},data={constants={bagSize=3}}}
game.mods={}
function game:adoptSave(save)self.mods.modSave=save.modData end
game:adoptSave(game.save)
local original=copy(game.save)
assert(select(2,M.snapshot(game,'missing'))=='equipment_not_initialized')
assert(equal(original,game.save),'snapshot mutated unbound save')
fail=true;assert(select(2,M.bind(game))=='save_failed')
assert(equal(original,game.save),'failed identity migration retconned save')
fail=false;assert(M.bind(game))
local handle=game.save.party[1]._kascEquipmentHandle
assert(type(handle)=='string' and #handle>20)
assert(game.save.party[1].item==nil and game.save.box[1].item=='BERRY','migration rolled/changed items')
local beforeWrites=writes;assert(M.bind(game));assert(writes==beforeWrites,'migration repeated write')
local egg=M.snapshot(game,game.save.party[2]._kascEquipmentHandle)
assert(egg.ability.id==false and egg.isEgg and not egg.species and not egg.commands.give)
local snap=assert(M.snapshot(game,handle))
assert(snap.item.id==false and snap.commands.give and not snap.commands.take)
snap.item.id='MUTATED';assert(M.snapshot(game,handle).item.id==false)
local serial=0
local function request(action,itemId,who)
  serial=serial+1;who=who or handle
  return {requestId='fixture-'..serial,handle=who,
    expectedRevision=assert(M.snapshot(game,who)).revision,action=action,itemId=itemId}
end
local give=request('give','BERRY')
local result=assert(M.command(game,give))
assert(notices==1 and result.itemId=='BERRY','listener broke or changed committed result')
assert(result.committed and game.save.inventory.BERRY==1 and game.save.party[1].item=='BERRY')
assert(game.save.party[1].heldItem=='BERRY')
assert(result.revision==M.snapshot(game,handle).revision,'commit lacks next view revision')
assert(M.snapshot(game,handle).item.reasonCode=='inactive_generation')
assert(not M.snapshot(game,handle).item.active)
local after=copy(game.save);local n=notifications;beforeWrites=writes
result.itemId='MUTATED';assert(M.command(game,give).itemId=='BERRY')
assert(equal(after,game.save) and notifications==n and writes==beforeWrites,'retry duplicated mutation/event/save')
assert(notices==1,'retry re-emitted committed event');unsubscribe()
local conflict=copy(give);conflict.itemId='LEFTOVERS'
assert(select(2,M.command(game,conflict))=='request_id_conflict')
local stale=request('take');gen=2
assert(select(2,M.command(game,stale))=='stale_revision','generation change retained stale UI token')
assert(M.snapshot(game,handle).item.active)
local swap=request('swap','LEFTOVERS')
fail=true;after=copy(game.save)
assert(select(2,M.command(game,swap))=='save_failed')
assert(equal(after,game.save),'failed swap lost/duplicated inventory or held item')
fail=false
callback=function(g)
  assert(select(2,M.command(g,swap))=='transaction_busy','reentrant mutation allowed')
end
assert(M.command(game,swap));callback=nil
assert(notices==1,'unsubscribed UI still received changes')
assert(game.save.inventory.BERRY==2 and not game.save.inventory.LEFTOVERS)
assert(game.save.party[1].item=='LEFTOVERS')
-- A one-item swap first frees its bag slot, so a full bag is not a false block.
game.save.inventory={BERRY=1,POTION=1,BICYCLE=1}
assert(M.command(game,request('swap','BERRY')))
assert(not game.save.inventory.BERRY and game.save.inventory.LEFTOVERS==1)
local take=request('take');after=copy(game.save)
assert(select(2,M.command(game,take))=='bag_full')
assert(equal(after,game.save),'full-bag failure changed save')
game.save.inventory.POTION=nil
assert(M.command(game,request('take')))
assert(not game.save.party[1].item and game.save.inventory.BERRY==1)
assert(select(2,M.command(game,request('give','BICYCLE')))=='item_not_holdable')
assert(select(2,M.command(game,request('give','UNKNOWN')))=='unknown_item')
game.save.inventory.BERRY=nil
assert(select(2,M.command(game,request('give','BERRY')))=='item_not_owned')
game.save.inventory.BERRY=1
locked=true;assert(not M.snapshot(game,handle).commands.give)
assert(select(2,M.bind(game))=='battle_active','migration wrote during battle')
assert(select(2,M.command(game,request('give','BERRY')))=='battle_active');locked=false
local moved=request('give','BERRY')
game.save.box[#game.save.box+1]=table.remove(game.save.party,1)
assert(select(2,M.command(game,moved))=='stale_revision','moved target used stale UI slot')
assert(M.command(game,request('give','BERRY')))
local target=game.save.box[#game.save.box]
target.heldItem='LEFTOVERS'
assert(select(2,M.snapshot(game,handle))=='conflicting_item_aliases')
target.heldItem='BERRY'
-- Persisted request receipts survive reload and still cannot duplicate items.
game.save=copy(saved);game:adoptSave(game.save);local restarted=make(opts)
after=copy(game.save);beforeWrites=writes
assert(restarted.command(game,give).itemId=='BERRY')
assert(equal(after,game.save) and writes==beforeWrites)
game.save.party[#game.save.party+1]=copy(game.save.box[#game.save.box])
assert(select(2,restarted.bind(game))=='ambiguous_mon_handle')
print('POKEMON EQUIPMENT PASS: persistent handles, no retcon, eggs hidden, give/take/swap, capacity, stale/duplicate/reentrant requests, save rollback and reload retry')

assert(game.mods.modSave==game.save.modData,"command completion/rollback binding")
