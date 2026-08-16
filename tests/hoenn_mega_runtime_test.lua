-- P0 Hoenn Mega runtime contract.  This exercises the real profile/resolver
-- module with a minimal ModKit-shaped host; the full main-load suite is also
-- covered in trainer_rematch_test.lua when the Authority branch compiles.
local source=debug.getinfo(1,"S").source:sub(2)
local root=source:match("^(.*)/tests/[^/]+$") or "."
local make=assert(loadfile(root.."/mega_evolution.lua"))()
local function yes(v,m) assert(v,m) end
local function eq(a,b,m) assert(a==b,m..": "..tostring(a).." ~= "..tostring(b)) end
local function registry() local r={};function r:register(k,v)assert(not self[k],"duplicate "..k);self[k]=v end;return r end
local saved,options,hooks={}, {kanto_crystal_art=true,crystal_animation=true}, {}
-- Keep the real priority semantics used by src.mods.Events.  This focused
-- host remains package-independent while still proving that the production
-- Mega listener (-10) observes a roster reservation finalized at priority 0.
local eventRows={}
local events={}
function events:on(name,callback,priority)
  local rows=eventRows[name] or {};eventRows[name]=rows
  rows[#rows+1]={callback=callback,priority=priority or 0}
  table.sort(rows,function(a,b)return a.priority>b.priority end)
end
function events:emit(name,payload)
  for _,row in ipairs(eventRows[name] or {}) do row.callback(payload) end
end
local mod={path=root,save={get=function(_,k)return saved[k]end,set=function(_,k,v)saved[k]=v end},options={get=function(_,k)return options[k]end},content={items=registry(),battle_sprite_scales=registry()},hooks={wrap=function(_,name,fn)hooks[name]=fn end},events=events}
function mod:read(relative) local f=io.open(root.."/"..relative,"rb");if f then f:close();return true end return false end
local animationData=assert(loadfile(root.."/mega_animation_data.lua"))()
local postgame={hasHallOfFame=function(save)
  return type(save)=="table" and type(save.hallOfFame)=="table"
    and next(save.hallOfFame)~=nil
end}
local mega=make(mod,{animationData=animationData,postgame=postgame})
local rows={
  {species="BLAZIKEN",id="BLAZIKEN",stone="BLAZIKENITE",asset="mega_blaziken"},
  {species="SWAMPERT",id="SWAMPERT",stone="SWAMPERTITE",asset="mega_swampert"},
  {species="SCEPTILE",id="SCEPTILE",stone="SCEPTILITE",asset="mega_sceptile",types={"GRASS","DRAGON"}},
}
for _,row in ipairs(rows) do
  local profile=mega.formsBySpecies[row.species][1]
  eq(profile.id,row.id,row.species.." profile");eq(profile.stone,row.stone,row.species.." stone")
  eq(#mega.formsBySpecies[row.species],1,row.species.." exposes only its final Mega profile")
  eq(profile.staticOnly,false,row.species.." opts into documented authored motion")
  local sides=assert(mega.animationData[row.id],row.species.." has timing data")
  for _,shiny in ipairs({false,true}) do
    local suffix=shiny and "_shiny" or ""
    local frontFile=assert(io.open(root.."/assets/mega/"..row.asset.."_front"..suffix..".png","rb"))
    local backFile=assert(io.open(root.."/assets/mega/"..row.asset.."_back"..suffix..".png","rb"))
    local front=frontFile:read("*a");frontFile:close()
    local back=backFile:read("*a");backFile:close()
    yes(front~=back,row.species.." has an independent non-mirrored "..(shiny and "shiny" or "normal").." back master")
  end
  yes(mod.content.items[row.stone],row.species.." Stone Case item registers")
  yes(mega.grantStone(row.stone),row.species.." stone persists");eq(mega.profileFor({species=row.species},false).id,row.id,row.species.." resolver honors owned stone")
  for _,side in ipairs({"front","back"}) do for _,shiny in ipairs({false,true}) do
    local suffix=shiny and "_shiny" or ""; local mon={species=row.species,_ascMegaForm=row.id,shiny=shiny,_ascMegaAnimationFrame=3}
    for _,dir in ipairs({"assets/mega/","assets/mega_runtime/","assets/mega_gen1_runtime/"}) do yes(mod:read(dir..row.asset.."_"..side..suffix..".png"),row.species.." packages "..dir..side..suffix) end
    local timings=assert(sides[side][shiny and "shiny" or "normal"],row.species.." has "..side.." timing")
    eq(#timings,5,row.species.." has five authored "..side.." keys")
    local seen={}
    for frame=1,#timings do
      local animated=("assets/mega_animated/%s/%s/%s/%03d.png"):format(row.asset,side,shiny and "shiny" or "normal",frame)
      local runtime=("assets/mega_animated_runtime/%s/%s/%s/%03d.png"):format(row.asset,side,shiny and "shiny" or "normal",frame)
      yes(mod:read(animated),row.species.." packages authored "..side.." key "..frame)
      yes(mod:read(runtime),row.species.." packages runtime "..side.." key "..frame)
      local f=assert(io.open(root.."/"..animated,"rb"));local bytes=f:read("*a");f:close()
      yes(not seen[bytes],row.species.." has no duplicate dummy "..side.." key "..frame);seen[bytes]=true
    end
    local ctx={mon=mon,side=side,kind="battle",trueColor=false}
    local crystal=hooks["pokemon.sprite"](function(path)return path end,"fallback.png",ctx)
    yes(crystal:find(("assets/mega_animated_runtime/%s/%s/%s/003.png"):format(row.asset,side,shiny and "shiny" or "normal"),1,true),row.species.." Crystal animation "..side..suffix);yes(ctx.trueColor,row.species.." Crystal true-color")
    options.kanto_crystal_art=false;options.crystal_animation=false
    ctx={mon=mon,side=side,kind="battle",trueColor=true}
    local gen1=hooks["pokemon.sprite"](function(path)return path end,"fallback.png",ctx)
    yes(gen1:find("assets/mega_gen1_runtime/"..row.asset.."_"..side..suffix..".png",1,true),row.species.." Gen-I "..side..suffix);eq(ctx.trueColor,false,row.species.." Gen-I palette path")
    options.kanto_crystal_art=true;options.crystal_animation=true
  end end
  if row.types then
    eq(profile.types[1],row.types[1],"Sceptile Grass");eq(profile.types[2],row.types[2],"Sceptile Dragon")
  end
end

-- Legacy imports target the save-local Stone Case ledger, never a phantom
-- Bag count.  The rollback token reverses only a provisional grant; importing
-- an already-owned unique receipt is successful and idempotent.
local legacyState=mega.state()
legacyState.case=true
local legacyReceipt,legacyErr=mega.importLegacyStone("VENUSAURITE")
yes(legacyReceipt and legacyErr==nil and legacyReceipt.added==true,
  "Legacy import stages one unowned official Mega Stone")
yes(mega.hasStone("VENUSAURITE"),
  "Legacy import writes the save-local Stone Case ledger")
yes(mega.rollbackLegacyStone(legacyReceipt),
  "failed game-save path can roll back the provisional stone")
eq(mega.hasStone("VENUSAURITE"),false,
  "rollback removes only the provisional Legacy stone")
local committedReceipt=assert(mega.importLegacyStone("VENUSAURITE"))
yes(committedReceipt.added==true and mega.hasStone("VENUSAURITE"),
  "retry can commit the unique Legacy stone")
local duplicateReceipt=assert(mega.importLegacyStone("VENUSAURITE"))
eq(duplicateReceipt.added,false,
  "an already-owned Legacy stone produces no duplicate")
yes(mega.rollbackLegacyStone(duplicateReceipt),
  "rolling back an idempotent no-op is safe")
yes(mega.hasStone("VENUSAURITE"),
  "no-op rollback preserves the already-owned stone")
-- Save/NG+ reload uses the canonical persistent Stone Case table. Recreate
-- the controller with fresh registries but the same save backend; this is the
-- relevant boundary rather than merely re-reading a live controller's cache.
local reloadHooks={}
local reloadMod={path=root,save={get=function(_,k)return saved[k]end,set=function(_,k,v)saved[k]=v end},options={get=function(_,k)return options[k]end},content={items=registry(),battle_sprite_scales=registry()},hooks={wrap=function(_,name,fn)reloadHooks[name]=fn end},events={on=function()end}}
function reloadMod:read(relative) local f=io.open(root.."/"..relative,"rb");if f then f:close();return true end return false end
local reloaded=make(reloadMod,{animationData={}})
for _,row in ipairs(rows) do
  yes(reloaded.hasStone(row.stone),row.species.." Stone Case survives save/NG+ reload")
  eq(reloaded.profileFor({species=row.species},false).id,row.id,
    row.species.." reload resolver retains its final Mega form")
end

-- A late Wanderer is an ordinary trainer battle, not a synthetic boss flag.
-- The real controller therefore keys eligibility from any developed party
-- member at level 80+, then its existing used-bit permits exactly one Mega.
options.mega_evolution=true;options.mega_opponents="bosses"
-- Register the same priority-0 reservation boundary used by postgame.lua
-- after the Mega controller. Sorting, rather than registration order, must
-- still let the real Mega listener see the finalized carrier and arm it.
events:on("battle.started",function(ev)
  ev.battle.ascendantEnemyMegaSpecies="SLOWBRO"
end,0)
local orderedLeagueBattle={kind="trainer",oppClass="OPP_LORELEI",
  game={save={hallOfFame={{}}}},
  enemy={mon={species="DEWGONG",level=100}},
  enemyParty={{species="DEWGONG",level=100,hp=1},
    {species="SLOWBRO",level=100,hp=1}}}
events:emit("battle.started",{battle=orderedLeagueBattle})
eq(orderedLeagueBattle.ascendantEnemyMegaSpecies,"SLOWBRO",
  "priority-0 League finalizer reserves Slowbro")
eq(orderedLeagueBattle._ascMegaEnemyPending,true,
  "production priority--10 Mega listener observes finalized League party")
eq(mega.enemyMegaTargetReady(orderedLeagueBattle),false,
  "automatic Mega waits while the reserved Slowbro is not active")

local wandererBattle={kind="trainer",oppClass="OPP_YOUNGSTER",
  ascendantLegacyWanderer=true,
  enemy={mon={species="RATTATA",level=75}},
  enemyParty={{species="RATTATA",level=75},{species="BLAZIKEN",level=85}},
  trainer={name="WANDERER"},game={save={player={name="RED"}}},
  say=function(self,text)self.lastSay=text end,
  act=function(self,callback)self.pendingAct=callback end}
yes(mega.opponentEligible(wandererBattle),
  "late Wanderer is Mega-eligible from a level-85 party member")
local lanceBattle={kind="trainer",oppClass="OPP_LANCE",
  ascendantEnemyMegaSpecies="DRAGONITE",
  enemy={mon={species="AERODACTYL",level=100}},
  enemyParty={{species="AERODACTYL",level=100,hp=1},
    {species="DRAGONITE",level=100,hp=1}}}
yes(mega.enemyMegaTargetAvailable(lanceBattle),
  "Lance's reserved Dragonite Mega target exists in the live party")
eq(mega.enemyMegaTargetReady(lanceBattle),false,
  "Lance does not spend his one Mega Evolution on Aerodactyl")
lanceBattle.enemy.mon=lanceBattle.enemyParty[2]
yes(mega.enemyMegaTargetReady(lanceBattle),
  "Lance's automatic Mega Evolution unlocks when Dragonite enters")
local firstBattler={name="BLAZIKEN",mon=wandererBattle.enemyParty[2]}
local activated,reason=mega.activate(wandererBattle,firstBattler,"enemy")
yes(activated and reason==nil,
  "registered Blaziken profile queues one legal enemy Mega")
yes(wandererBattle._ascMegaEnemyUsed,
  "real Mega controller records the enemy-side use immediately")
local secondBattler={name="SCEPTILE",mon={species="SCEPTILE",level=90}}
local secondActivated,secondReason=mega.activate(
  wandererBattle,secondBattler,"enemy")
eq(secondActivated,false,"second enemy Mega cannot activate in one battle")
eq(secondReason,"used","second enemy Mega is rejected by the real used-bit")

-- Gold owns a narrowly-scoped story exception: his selected Typhlosion may
-- awaken into the Ascendant form even before the player's Basalt Core quest.
-- No ordinary trainer or player path receives this flag.
local goldBattle={kind="trainer",oppClass="KA_JOHTO_GOLD",johtoPassage=true,
  ascendantEnemyMegaSpecies="TYPHLOSION",
  ascendantEnemySecretForm="TYPHLOSION_ASCENDANT",
  trainer={name="GOLD"},game={save={hallOfFame={{}},player={name="RED"}}},
  say=function(self,text)self.lastSay=text end,
  act=function(self,callback)self.pendingAct=callback end}
local goldBattler={name="TYPHLOSION",isPlayer=false,
  mon={species="TYPHLOSION",level=100,hp=200,stats={hp=200}},
  curStats={hp=200,attack=200,defense=200,speed=200,special=200}}
local goldActivated,goldReason=mega.activate(goldBattle,goldBattler,"enemy")
yes(goldActivated and goldReason==nil,
  "Gold's Johto passage queues Ascendant Typhlosion")
yes(goldBattle.lastSay and goldBattle.lastSay:find("ASCENDANT",1,true),
  "Gold receives the explicit Ascendant transformation text")
goldBattle.pendingAct()
eq(goldBattler.mon._ascMegaForm,"TYPHLOSION_ASCENDANT",
  "Gold applies the Ascendant Typhlosion form")
local unmarkedBattle={kind="trainer",trainer={name="OTHER"},
  say=function()end,act=function()end}
local denied,deniedReason=mega.activate(unmarkedBattle,
  {name="TYPHLOSION",mon={species="TYPHLOSION",level=100}},"enemy")
eq(denied,false,"ordinary enemy Typhlosion cannot use Gold's exception")
eq(deniedReason,"ineligible","ordinary enemy Typhlosion stays ineligible")
print("hoenn_mega_runtime_test: PASS")
