-- Authoritative 15-package/17-target HEVO runtime contract.
-- Run from Gen1 Recomp with KA_HEVO_MOD pointing at this worktree.
package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HEVO_MOD"), "KA_HEVO_MOD required")
local make = assert(loadfile(root .. "/hevo_packages.lua"))()
local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function count(map) local n=0; for _ in pairs(map or {}) do n=n+1 end; return n end

local function registry(seed)
  local r = { values = seed or {} }
  function r:get(id) return self.values[id] end
  function r:register(id, row) assert(not self.values[id], "duplicate "..id); self.values[id]=row end
  function r:patch(id, row)
    self.values[id] = self.values[id] or {}
    for k,v in pairs(row) do self.values[id][k]=v end
  end
  return r
end
local mod = { id="kanto_ascendant", path=root, exports={}, content={
  item_effects=registry(), items=registry(), evolution_methods=registry(),
  maps=registry(), text=registry(), map_scripts=registry(),
  text_pointers={patch=function() end},
} }
local syncs = 0
local journey = {
  activeCharacter=function(save) return save.character end,
  syncHevoPersistent=function() syncs=syncs+1; return true end,
}
local P = make(mod, { journey=journey, i18n={text=function(en)return en end} })

eq(#P.order, 15, "exact package count")
eq(P.audit.registeredTargets, 17, "exact target count")
eq(#P.byCharacter.RED, 5, "RED owns five packages")
eq(#P.byCharacter.BLUE, 5, "BLUE owns five packages")
eq(#P.byCharacter.GREEN, 5, "GREEN owns five packages")
local targetCounts, kinds = {RED=0,BLUE=0,GREEN=0}, {}
for _, pkg in ipairs(P.order) do
  kinds[pkg.kind]=(kinds[pkg.kind] or 0)+1
  targetCounts[pkg.character]=targetCounts[pkg.character]+#pkg.targets
  eq(pkg.unlockKey, "hevo_package_"..pkg.id, pkg.id.." stable unlock key")
  eq(pkg.repeatableSource, "legacy_workshop", pkg.id.." repeatable source")
  check(pkg.characterWhitelist[pkg.character], pkg.id.." character whitelist")
  if pkg.item then
    local def=mod.content.items:get(pkg.item)
    check(def.lootExcluded and def.progressionItem and def.needsTarget,
      pkg.item.." is target progression loot-excluded")
    eq(pkg.reacquirePrice, 9800, pkg.item.." fixed replacement price")
  end
end
eq(targetCounts.RED,5,"RED target share")
eq(targetCounts.BLUE,5,"BLUE target share")
eq(targetCounts.GREEN,7,"GREEN target share")
eq(kinds.item,8,"eight consumable item packages")
eq(kinds.field,3,"three field packages")
eq(kinds.knowledge,4,"four knowledge packages")
check(P.byId.ancient_power_green.targets[1].target=="TANGROWTH"
  and P.byId.ancient_power_green.targets[2].target=="YANMEGA",
  "green AncientPower is one dual-target package")
check(P.byId.dusk_stone.targets[1].target=="MISMAGIUS"
  and P.byId.dusk_stone.targets[2].target=="HONCHKROW",
  "Dusk Stone is one dual-target package")

local function save(character, cap)
  return { character=character, flags={}, inventory={}, bagOrder={}, party={},
    money=20000, modData={}, _cap=cap }
end
local data = { constants={bagSize=20}, moves={
  ROLLOUT={}, ANCIENTPOWER={}, DOUBLE_HIT={},
}, items=mod.content.items.values }
P.install({ data=data, save=save("RED") })

local red=save("RED")
P.activeGame={data=data,save=red}
local tx=assert(P.stageCharacter(red,"RED"))
eq(#tx.packages,5,"production RED stages all five packages")
local rp=P.persistent(red,false)
eq(count(rp.packageUnlocks),5,"five RED package flags staged")
eq(count(rp.evolutionUnlocks),5,"five RED target compatibility flags derived")
eq(count(red.inventory),3,"RED receives exactly its three item first grants")
check(not rp.packageUnlocks.electirizer,"RED grant cannot leak BLUE")
check(not rp.packageUnlocks.dusk_stone,"RED grant cannot leak GREEN")
local rejected, reason=P.stageRecovery(red,"RED",{"electirizer"},false)
check(not rejected and reason=="character","recovery rejects cross-character package")

local game={save=red,data=data,writes=0,writeSave=function(self)self.writes=self.writes+1;return true end}
check(P.commit(game,tx),"staged packages commit through game then archive")
eq(syncs,1,"archive synchronization occurs once")
local again=assert(P.stageCharacter(red,"RED"))
eq(red.inventory.PROTECTOR,1,"repeat staging never duplicates first grant")
P.restore(again)

local full=save("GREEN"); full.inventory.FILL=1
local tiny={constants={bagSize=1},moves=data.moves,items=data.items}
P.activeGame={data=tiny,save=full}
assert(P.stageCharacter(full,"GREEN"))
local fp=P.persistent(full,false)
eq(fp.pendingItems.SHINY_STONE,1,"full bag queues Shiny Stone")
eq(fp.pendingItems.DUSK_STONE,1,"full bag queues Dusk Stone")
full.inventory.FILL=nil; full.bagOrder={}
local pendingGame={save=full,data=tiny,writeSave=function()return true end}
local claimed, list=P.claimPending(pendingGame)
check(claimed and #list==1,"pending claim fills only available slot")
eq(count(P.persistent(full,false).pendingItems),1,"unclaimed pending item remains durable")

local locked=save("RED")
local result=P.useItemEffect(data,locked,"PROTECTOR",{species="RHYDON"},false)
eq(result,"failed","locked direct item fails")
P.activeGame={data=data,save=locked}; assert(P.stageRecovery(locked,"RED",{"protector"},false))
result=P.useItemEffect(data,locked,"PROTECTOR",{species="MAGMAR"},false)
eq(result,"failed","wrong target fails without consumption")
result=P.useItemEffect(data,locked,"PROTECTOR",{species="RHYDON"},true)
eq(result,"failed","HEVO item refuses battle use")
local extra; result,_,extra=P.useItemEffect(data,locked,"PROTECTOR",{species="RHYDON"},false)
eq(result,"consumed","eligible target item succeeds")
eq(extra.evolveTo,"RHYPERIOR","item resolves target from package")
eq(extra.evolveVia,"ITEM","item evolution is non-cancelable engine path")

local knowledge=save("RED"); P.activeGame={data=data,save=knowledge}
assert(P.stageRecovery(knowledge,"RED",{"rollout_knowledge"},false))
local lick={species="LICKITUNG",moves={}}
eq(#P.reminderRows({save=knowledge,data={moves={}}},lick),0,
  "missing move dependency fails closed")
eq(#P.reminderRows({save=knowledge,data=data},lick),1,
  "unlocked Route 5 knowledge row is legal")
local ok,why=P.eligibility(knowledge,lick,"rollout_knowledge","levelup",{data=data})
check(not ok and why=="knowledge","knowing move is required at level-up")
lick.moves={{id="ROLLOUT"}}
ok,why=P.eligibility(knowledge,lick,"rollout_knowledge","levelup",{data={moves={}}})
check(not ok and why=="move-missing",
  "knowledge evolution fails closed when its move dependency is absent")
check(P.eligibility(knowledge,lick,"rollout_knowledge","levelup",{data=data}),
  "knowledge evolution becomes eligible at next level-up")

local blue=save("BLUE"); P.activeGame={data=data,save=blue}
assert(P.stageRecovery(blue,"BLUE",{"magnetic_field","electirizer"},false))
mod.content.maps:register("KA_HEVO_TEST_ALTAR", { objects = {} })
check(P.registerFieldAltar("KA_HEVO_TEST_ALTAR", "TEXT_KA_HEVO_TEST_ALTAR",
  "magnetic_field", { x=1, y=2 }), "field altar registers")
local altarObject=mod.content.maps:get("KA_HEVO_TEST_ALTAR").objects[1]
eq(altarObject.sprite,"SPRITE_POKE_BALL",
  "field altar is an item marker and cannot masquerade as a sixth quiz statue")
local magneton={species="MAGNETON",moves={}}
check(P.eligibility(blue,magneton,"magnetic_field","field",
  {field="KA_HEVO_MAGNETIC_ALTAR",data=data}),"field altar eligibility")
local fieldGame={save=blue,data=data}
local fieldOk,fieldTarget=P.useFieldAltar(fieldGame,"magnetic_field",magneton,nil,{
  request=function(_,_,trigger) check(trigger.kind=="hevo_field","field trigger kind"); return "MAGNEZONE" end,
})
check(fieldOk and fieldTarget=="MAGNEZONE","field altar evolves immediately and remains reusable")

blue.inventory.ELECTIRIZER=1
local electabuzz={species="ELECTABUZZ",moves={}}
local row={mon=electabuzz,package=P.byId.electirizer,item="ELECTIRIZER"}
local dayGame={save=blue,data=data}
local dayOk=P.evolveAtDaycare(dayGame,row,nil,{evolve=function()return false end})
check(not dayOk and blue.inventory.ELECTIRIZER==1,"Day-Care failure never consumes")
dayOk=P.evolveAtDaycare(dayGame,row,nil,{evolve=function()return true end})
check(dayOk and not blue.inventory.ELECTIRIZER,"Day-Care success consumes exactly once")
local mismatch=P.eligibility(blue,magneton,"magnetic_field","daycare",{data=data})
check(not mismatch,"Day-Care cannot trigger field packages")

blue.money=20000
local shop={save=blue,data=data,writeSave=function()return true end}
check(not P.purchase(shop,"electirizer",false),"workshop cancel is side-effect free")
check(not P.purchase(shop,"electirizer",nil),"workshop requires explicit confirmation")
eq(blue.money,20000,"cancel keeps money")
check(P.purchase(shop,"electirizer",true),"unlocked item can be reacquired")
eq(blue.money,10200,"workshop charges exactly 9800")
eq(blue.inventory.ELECTIRIZER,1,"workshop grants item")
local beforeMoney=blue.money
shop.writeSave=function()return false end
local bought,saveErr=P.purchase(shop,"electirizer",true)
check(not bought and saveErr=="save","workshop save failure reports error")
eq(blue.money,beforeMoney,"workshop save failure rolls back money")
eq(blue.inventory.ELECTIRIZER,1,"workshop save failure rolls back item")

local failSave=save("RED"); P.activeGame={data=data,save=failSave}
local failTx=assert(P.stageCharacter(failSave,"RED"))
local failGame={save=failSave,data=data,writeSave=function()return false end}
local committed,commitErr=P.commit(failGame,failTx)
check(not committed and commitErr=="save","grant save failure is reported")
local rolledBackPersistent=P.persistent(failSave,false)
eq(count(rolledBackPersistent and rolledBackPersistent.packageUnlocks or {}),0,
  "grant save failure rolls back unlocks")
eq(count(failSave.inventory),0,"grant save failure rolls back first items")

local fresh=save("GREEN")
fresh.modData.kanto_ascendant={hevo_persistent={
  packageUnlocks={dusk_stone=true}, evolutionUnlocks={}, permanentItems={},
  firstGrants={dusk_stone=true}, pendingItems={}, meta={},dex={},questionIds={},
}}
P.reconcile(fresh)
check(P.unlocked(fresh,"dusk_stone"),"fresh save restores permanent package")
check(P.persistent(fresh,false).evolutionUnlocks.MISMAGIUS
  and P.persistent(fresh,false).evolutionUnlocks.HONCHKROW,
  "fresh save derives both dual-package targets")

print(("HEVO PACKAGES PASS: %d assertions"):format(assertions))
