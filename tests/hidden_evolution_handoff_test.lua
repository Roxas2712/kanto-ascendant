-- Durable coloured-shrine -> shared-tablet hand-off contract.

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")

local wrapped
local handlers={}
local mod = { hooks = {
  wrap = function(_, name, fn, priority)
    assert(name == "warp.destination" and priority == 3000)
    wrapped = fn
    return function() wrapped = nil end
  end,
},events={on=function(_,name,fn,priority)
  handlers[name]={fn=fn,priority=priority}
end} }

local sharedId = "KA_HEVO_SHARED_SEALED_ANTECHAMBER"
local receipts, sealed = {}, {}
local existingHandoff
local shared = {
  ID = sharedId,
  RETURN_POINTS = {
    RED={map="KA_HEVO_RED_SHRINE"},
    BLUE={map="KA_HEVO_BLUE_KYOGRE_SHRINE"},
    GREEN={map="KA_HEVO_GREEN_RAYQUAZA_SHRINE"},
  },
  register=function() return true end, install=function() return true end,
  recordHandoff=function(_, character, payload)
    receipts[#receipts+1]={character=character,payload=payload}
    existingHandoff={character=character,stone=payload.stone,
      stoneStatus=payload.stoneStatus}
    return true
  end,
  handoff=function() return existingHandoff end,
  character=function() return nil end,
}
local function path(start, finish, stoneMethod)
  local p={IDS={threshold=start,shrine=finish},END_WARP={x=9,y=9},
    completeCalls=0,finalizeCalls=0,stoneCalls=0,
    register=function()return true end,install=function()return true end}
  p.complete=function(_, game)
    p.completeCalls=p.completeCalls+1;p.finalizeCalls=p.finalizeCalls+1
    sealed[p.key]=true;return true
  end
  p[stoneMethod]=function()
    p.stoneCalls=p.stoneCalls+1;return false,"claimed"
  end
  p.completionProgress=function() return p.progress end
  return p
end
local paths={
  RED=path("KA_HEVO_RED_UPPER","KA_HEVO_RED_SHRINE","claimMega"),
  BLUE=path("KA_HEVO_BLUE_FROST_THRESHOLD","KA_HEVO_BLUE_KYOGRE_SHRINE","claimSwampertite"),
  GREEN=path("KA_HEVO_GREEN_THRESHOLD","KA_HEVO_GREEN_RAYQUAZA_SHRINE","claimMega"),
}
for key,p in pairs(paths) do
  p.key=key
  p.progress=key=="RED"
    and {statues=5,boulders={A=true,B=true,C=true}}
    or key=="BLUE"
      and {statues=5,finalStatue=true,
        switches={HALL=true,ICE=true,DEPTHS=true}}
      or {statues=5,rootgate=true,canopy=true}
end
paths.BLUE.claimAll=function()
  paths.BLUE.finalizeCalls=paths.BLUE.finalizeCalls+1
  sealed.BLUE=true;return {"ELECTIVIRE"}
end

local tunnel={sites={},register=function()return true end,install=function()return true end}
local entries={RED={6,21},BLUE={26,21},GREEN={46,21}}
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  tunnel.sites[key]={tunnel="KA_HEVO_TUNNEL_ALL",branch={returnSlot=1,
    entry={x=entries[key][1],y=entries[key][2],facing="up"}}}
end
local noop={register=function()return true end,install=function()return true end}
local game={save={player={map=""}}}
local returnWarps={}
mod.world={warpTo=function(_,map,x,y,facing,options)
  returnWarps[#returnWarps+1]={map=map,x=x,y=y,facing=facing}
  if options and options.onDone then options.onDone();options.onDone() end
  return true
end}
local adapter={beyondActive=function()return true end}
local coordinator=assert(loadfile(root.."/hidden_evolution_story_coordinator.lua"))()(mod,{
  modules={shared=shared,hints=noop,tunnel=tunnel,
    RED=paths.RED,BLUE=paths.BLUE,GREEN=paths.GREEN},
  journey={currentHevoSeal=function(_,character)
    return sealed[character]==true,character
  end},
  legacyDungeonAdapter=adapter,
})
assert(coordinator.install(game) and type(wrapped)=="function")
assert(handlers["map.entered"] and handlers["map.entered"].priority==3000)
assert(handlers["player.warped"] and handlers["player.warped"].priority==3000)
assert(type(shared.ensureOwnHandoff)=="function",
  "shared black door lacks its bounded seal-recovery seam")
assert(type(shared.completionProgress)=="function"
    and type(shared.returnToTrialStart)=="function",
  "shared black door lacks progress/return seams")
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  assert(type(paths[key].finalizeEndSeal)=="function",
    key.." visible final seal lacks the bound completion seam")
end

-- Progress diagnostics are character-bound, add the shared Beyond gate and
-- return to the exact branch entry.  A pathological duplicate world callback
-- must still complete the outer interaction exactly once.
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  local report,why=shared.completionProgress(game,key)
  assert(report and not why and report.character==key and report.beyond==true,
    key.." shared progress report lost its route/Beyond identity")
  local doneCount=0
  assert(shared.returnToTrialStart(game,key,function()doneCount=doneCount+1 end))
  local warp=returnWarps[#returnWarps]
  assert(warp.map=="KA_HEVO_TUNNEL_ALL"
      and warp.x==entries[key][1] and warp.y==21 and warp.facing=="up"
      and doneCount==1,key.." progress return missed its exact tunnel entry")
end
local originalWarp=mod.world.warpTo
mod.world.warpTo=function()return nil,"storage"end
local nilWarpOk,nilWarpWhy=shared.returnToTrialStart(game,"RED",function()
  error("nil warp completed")
end)
assert(not nilWarpOk and nilWarpWhy=="storage",
  "nil WorldAPI result was accepted as a completed return")
mod.world.warpTo=originalWarp

local slots={RED=1,BLUE=2,GREEN=3}
local stones={RED="BLAZIKENITE",BLUE="SWAMPERTITE",GREEN="SCEPTILITE"}

-- Door/warp recovery cannot use physical topology as invisible authority.
-- The three public report fields are real preflight gates before a new seal
-- is finalized, while an already durable seal remains idempotent below.
local incomplete={
  RED={statues=5,boulders={A=true,B=true,C=false}},
  BLUE={statues=5,finalStatue=true,
    switches={HALL=true,ICE=false,DEPTHS=true}},
  GREEN={statues=5,rootgate=true,canopy=false},
}
local incompleteReasons={RED="gate",BLUE="sight",GREEN="statues"}
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  local path=paths[key]
  local ready=path.progress
  path.progress=incomplete[key]
  receipts={};existingHandoff=nil;sealed[key]=false
  local beforeFinalize,beforeStones=path.finalizeCalls,path.stoneCalls
  local ok,why=path.finalizeEndSeal(game)
  assert(not ok and why==incompleteReasons[key]
      and path.finalizeCalls==beforeFinalize
      and path.stoneCalls==beforeStones and #receipts==0,
    key.." topology prerequisite was only decorative in the report")
  path.progress=ready
end

for _,key in ipairs({"RED","BLUE","GREEN"}) do
  receipts={}; existingHandoff=nil; sealed[key]=false
  game.save.player.map=coordinator.CONTRACT.ends[key]
  local dm,dx,dy=wrapped(function(map,x,y)return map,x,y end,
    sharedId,15,21,{warp={destMap=sharedId,destWarp=slots[key]}})
  assert(dm==sharedId and dx==15 and dy==21)
  assert(sealed[key],key.." exit did not finalize its own seal")
  assert(#receipts==1 and receipts[1].character==key,
    key.." exit lost its identity receipt")
  assert(receipts[1].payload.sourceMap==coordinator.CONTRACT.ends[key]
      and receipts[1].payload.stone==stones[key]
      and receipts[1].payload.stoneStatus=="claimed",
    key.." receipt lost source/stone status")
end

-- The real engine emits this event while the source identity is still
-- explicit.  Prove every coloured last warp independently creates its own
-- receipt even if the destination hook could not infer save.player.map.
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  receipts={}; existingHandoff=nil; sealed[key]=false
  game.save.player.map="ALREADY_UPDATED_BY_RUNTIME"
  handlers["player.warped"].fn({
    fromMap=coordinator.CONTRACT.ends[key],toMap=sharedId,x=15,y=21,
    warp={destMap=sharedId,destWarp=slots[key]},
  })
  assert(sealed[key],key.." player.warped edge did not finalize its seal")
  assert(#receipts==1 and receipts[1].character==key
      and receipts[1].payload.sourceMap==coordinator.CONTRACT.ends[key],
    key.." player.warped edge lost its durable identity receipt")
end

receipts={}
existingHandoff=nil
handlers["player.warped"].fn({fromMap=coordinator.CONTRACT.ends.RED,
  toMap=sharedId,warp={destMap=sharedId,destWarp=2}})
assert(#receipts==0,"wrong shared arrival slot manufactured a RED receipt")

receipts={}
existingHandoff=nil
game.save.player.map="ROUTE_22"
wrapped(function(map,x,y)return map,x,y end,sharedId,15,21,
  {warp={destMap=sharedId,destWarp=1}})
assert(#receipts==0,"foreign warp manufactured a coloured handoff")

-- Compatibility for an already-imported RC save uses the three authored
-- landing cells, not an unreliable presentation-avatar identity.
for _,case in ipairs({{"RED",3},{"BLUE",15},{"GREEN",27}}) do
  receipts={}; existingHandoff=nil; sealed[case[1]]=false
  game.save.player={map=sharedId,x=case[2],y=21}
  handlers["map.entered"].fn({mapId=sharedId})
  assert(sealed[case[1]] and #receipts==1
      and receipts[1].character==case[1],
    case[1].." imported shared landing did not recover its identity")
end

-- Recovery for the exact broken-RC state: the RED seal is already durable,
-- but the first end-stone attempt persisted a failed character/unavailable
-- status. Reloading on Red's authored arrival pad must retry and upgrade it;
-- a successful receipt then remains idempotent on subsequent map events.
receipts={}
sealed.RED=true
existingHandoff={character="RED",stone="BLAZIKENITE",
  stoneStatus="character"}
local originalClaim=paths.RED.claimMega
paths.RED.claimMega=function() return true,"granted" end
game.save.player={map=sharedId,x=3,y=21}
handlers["map.entered"].fn({mapId=sharedId})
assert(#receipts==1 and receipts[1].character=="RED"
    and receipts[1].payload.stoneStatus=="granted",
  "stale legacy RED failure receipt was not upgraded on arrival reload")
handlers["map.entered"].fn({mapId=sharedId})
assert(#receipts==1,
  "successful recovered RED handoff was not idempotent")
paths.RED.claimMega=originalClaim

-- The same broken receipt can coexist with a stone already owned by the
-- player. In that case claimMega truthfully returns false,"claimed"; this is
-- still a verified terminal success and must stop the recovery loop.
receipts={}
existingHandoff={character="RED",stone="BLAZIKENITE",
  stoneStatus="unavailable"}
paths.RED.claimMega=function() return false,"claimed" end
handlers["map.entered"].fn({mapId=sharedId})
assert(#receipts==1 and receipts[1].payload.stoneStatus=="claimed",
  "already-owned legacy RED stone did not repair its stale receipt")
handlers["map.entered"].fn({mapId=sharedId})
assert(#receipts==1,
  "claimed recovered RED handoff retried indefinitely")
paths.RED.claimMega=originalClaim

-- Some released runtimes resume directly at the physical black door without
-- replaying either warp lifecycle hook.  The door's recovery seam must run
-- the exact same character-bound completion transaction, and it must remain
-- fail-closed for an unknown identity.
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  receipts={}; existingHandoff=nil; sealed[key]=false
  assert(shared.ensureOwnHandoff(game,key),
    key.." direct black-door recovery did not complete its own seal")
  assert(sealed[key] and #receipts==1
      and receipts[1].character==key
      and receipts[1].payload.sourceMap==coordinator.CONTRACT.ends[key],
    key.." direct black-door recovery lost its character-bound receipt")
end
local beforeUnknown=#receipts
local unknownOk,unknownWhy=shared.ensureOwnHandoff(game,"FUTURE")
assert(not unknownOk and unknownWhy=="character" and #receipts==beforeUnknown,
  "unknown character manufactured a black-door seal receipt")

-- The visible final seal itself is now the primary transaction boundary.
-- It must finish the exact route, retry the exact-once stone controller and
-- persist the receipt before either a warp hook or black-door recovery runs.
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  receipts={};existingHandoff=nil;sealed[key]=false
  local path=paths[key]
  local completesBefore,stonesBefore=path.finalizeCalls,path.stoneCalls
  local ok,receipt,stoneStatus=path.finalizeEndSeal(game)
  assert(ok and sealed[key] and #receipts==1
      and receipts[1].character==key and stoneStatus=="claimed",
    key.." visible end seal did not create its durable handoff directly")
  assert(path.finalizeCalls==completesBefore+1
      and path.stoneCalls==stonesBefore+1,
    key.." direct end seal skipped finalize or Mega claim")
  -- Already sealed means finalize is not replayed; the item controller is
  -- re-read and truthfully reports `claimed`, never a second grant.
  local completeOnce,stoneOnce=path.finalizeCalls,path.stoneCalls
  local again,_,againStatus=path.finalizeEndSeal(game)
  assert(again and againStatus=="claimed"
      and path.finalizeCalls==completeOnce
      and path.stoneCalls==stoneOnce+1,
    key.." repeated end-seal touch replayed finalize or lost claim idempotence")
end

-- Fail closed before any stone or receipt if the character-owned puzzle
-- authority rejects completion. This is the same outcome used for unfinished,
-- foreign, FUTURE and YELLOW saves by the real route/adapter pair.
for _,key in ipairs({"RED","BLUE","GREEN"}) do
  receipts={};existingHandoff=nil;sealed[key]=false
  local path=paths[key]
  local method=key=="BLUE" and "claimAll" or "complete"
  local original=path[method]
  local stonesBefore=path.stoneCalls
  path[method]=function() return key=="BLUE" and {} or false,"character" end
  local ok,why=path.finalizeEndSeal(game)
  path[method]=original
  assert(not ok and why=="character" and not sealed[key]
      and #receipts==0 and path.stoneCalls==stonesBefore,
    key.." rejected character authority was masked or minted a receipt")

  local foreignGameOk,foreignGameWhy=path.finalizeEndSeal({save={}})
  assert(not foreignGameOk and foreignGameWhy=="game",
    key.." end-seal seam accepted a foreign game authority")
end

print("hidden_evolution_handoff_test: PASS")
