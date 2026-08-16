-- Focused release contract for the three-path convergence room.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD pointing at the RC worktree.
package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local Data = require("src.core.Data")
Data:load()
local RuntimeMap = require("src.world.Map")

local function registry(base)
  local r = { values = {}, base = base or {} }
  function r:get(id) return self.values[id] or self.base[id] end
  function r:register(id, value)
    assert(not self.values[id], "duplicate " .. tostring(id))
    self.values[id] = value
    return value
  end
  function r:patch(id, partial)
    local value = self.values[id] or self.base[id] or {}
    self.values[id] = value
    for key, incoming in pairs(partial) do value[key] = incoming end
    return value
  end
  return r
end

local saved = {}
local mod = {
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  content = {
    maps = registry(), sprites = registry(), text = registry(),
    encounters = registry(), map_scripts = registry(), map_songs = registry(),
    text_pointers = { patch = function() end },
  },
}

local shown, blackouts, sequence = {}, {}, {}
local sealComplete = false
local shared = assert(loadfile(root .. "/hidden_evolution_shared_story.lua"))()(mod, {
  activeCharacter = function() return "RED" end,
  showText = function(_, text, done)
    sequence[#sequence + 1] = (text:find("BLACK DOOR",1,true)
      or text:find("SEAL SYSTEM ERROR",1,true))
      and "locked" or (text:find("Stone Case",1,true) and "stone" or "epilogue")
    shown[#shown + 1] = text
    if done then done() end
    return true
  end,
  blackout = function(_, payload, done)
    sequence[#sequence + 1] = "not-yet"
    blackouts[#blackouts + 1] = payload
    if done then done() end
    return true
  end,
  journey = {
    currentHevoSeal = function(_, character)
      return sealComplete, character
    end,
    notifyHevoSeal = function(_, character, done)
      assert(character == "RED"
          and saved.hidden_evolution_story_campaign.doorVisits.RED == true,
        "Oak unlock ran before the matching shared-door visit persisted")
      sequence[#sequence + 1] = "oak-call"
      if done then done() end
      return true
    end,
  },
})
assert(shared.register())

local def = assert(mod.content.maps:get(shared.ID), "shared antechamber missing")
assert(def.index == 1948 and def.tileset == "CAVERN")
assert(def.width == 16 and def.height == 16 and #def.blocks == 256,
  "shared room must keep the expanded 16x16 framed composition")
assert(def.borderBlock == 125 and def.voxelMode == "FULL" and def.voxelRevision == 3)
assert(def.outdoor == false and #(def.connections or {}) == 0)
assert(mod.content.map_songs:get(shared.ID) == "Music_KA_DeepEvolution",
  "shared room can inherit unrelated route music after a direct load")

local allowedBlocks = { [21] = true, [25] = true, [124] = true, [125] = true }
local blockCounts = {}
for _, block in ipairs(def.blocks) do
  assert(allowedBlocks[block], "shared room uses a non-native authored block: " .. tostring(block))
  blockCounts[block] = (blockCounts[block] or 0) + 1
end
assert(blockCounts[125] >= 180,
  "shared room regressed to the rejected almost-map-sized empty carpet")
assert(blockCounts[25] >= 30 and blockCounts[25] <= 60,
  "shared room needs compact but traversable pilgrimage arms")
assert(blockCounts[21] == 6, "shared room glint landmarks drifted")
assert(blockCounts[124] == 3, "shared room needs exactly three native return pads")

package.loaded["src.render.TileRenderer"] = { new = function() return {} end }
local runtime = RuntimeMap.new(def, assert(Data.tilesets.CAVERN))
local expectedWarps = {
  { x = 3, y = 21, map = "KA_HEVO_RED_SHRINE" },
  { x = 15, y = 21, map = "KA_HEVO_BLUE_KYOGRE_SHRINE" },
  { x = 27, y = 21, map = "KA_HEVO_GREEN_RAYQUAZA_SHRINE" },
}
assert(#def.warps == #expectedWarps)
for index, want in ipairs(expectedWarps) do
  local warp = def.warps[index]
  assert(warp.x == want.x and warp.y == want.y and warp.destMap == want.map
      and warp.destWarp == 1, "shared return slot " .. index .. " drifted")
  assert(runtime:isWalkableCell(warp.x, warp.y),
    "shared return slot " .. index .. " is not walkable")
  assert(runtime:isWarpTileCell(warp.x, warp.y),
    "shared return slot " .. index .. " lacks its native CAVERN trigger")
end

assert(#def.objects == 1 and def.objects[1].name == shared.DOOR,
  "shared room must contain only the sealed story door")
local door = def.objects[1]
assert(door.x == 15 and door.y == 5 and door.passable == false,
  "sealed door coordinate/collision drifted")
assert(not runtime:isWalkableCell(door.x, door.y),
  "sealed door must remain embedded in the northern rock wall")
assert(runtime:isWalkableCell(15, 6),
  "sealed door needs a direct southern interaction cell")

local function component(start)
  local queue, seen, head = { { start.x, start.y } }, {}, 1
  seen[start.x .. ":" .. start.y] = true
  while queue[head] do
    local at = queue[head]
    head = head + 1
    for _, step in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
      local x, y = at[1] + step[1], at[2] + step[2]
      local key = x .. ":" .. y
      if not seen[key] and runtime:inBounds(x, y) and runtime:isWalkableCell(x, y) then
        seen[key] = true
        queue[#queue + 1] = { x, y }
      end
    end
  end
  return seen, #queue
end

local doorApproaches = { "15:6" }
local canonicalSize
for index, warp in ipairs(def.warps) do
  local seen, size = component(warp)
  canonicalSize = canonicalSize or size
  assert(size == canonicalSize and size >= 150 and size <= 230,
    "return alcove " .. index .. " is isolated or the room reopened into an empty carpet")
  local reachesDoor = false
  for _, key in ipairs(doorApproaches) do reachesDoor = reachesDoor or seen[key] end
  assert(reachesDoor, "return alcove " .. index .. " cannot reach the sealed door")
  for other, target in ipairs(def.warps) do
    assert(seen[target.x .. ":" .. target.y],
      "return alcove " .. index .. " cannot reach alcove " .. other)
  end
end

-- The old 16x12 room exposed the blank outside world below a huge orange
-- carpet.  Every return is now at least ten cells from the lower camera edge,
-- and the door is framed by rock above it rather than sitting at map y=0.
for _, warp in ipairs(def.warps) do
  assert(runtime.heightCells - 1 - warp.y >= 10,
    "return pad is too close to the lower camera edge")
end
assert(door.y >= 4, "sealed door is too close to the upper camera edge")

local lockedDone=false
assert(shared.doorInteraction({data={}},nil,nil,function()lockedDone=true end))
assert(lockedDone and table.concat(sequence,",")=="locked"
    and saved.hidden_evolution_story_campaign==nil,
  "shared black door accepted or persisted a visit before path completion")
shown,sequence={},{}
sealComplete=true

assert(shared.recordHandoff(nil,"RED",{
  sourceMap="KA_HEVO_RED_SHRINE", stone="BLAZIKENITE",
  stoneStatus="granted",
}))

-- A transient pre-fix failed stone result for this same seal can be repaired
-- after either a verified new grant or an already-owned (`claimed`) result,
-- but must never downgrade or switch character.
local campaign=saved[shared.RUN_STATE]
campaign.handoff.stoneStatus="unavailable"
campaign.handoff.stone=nil
campaign.handoff.stoneAnnounced=true
assert(shared.recordHandoff(nil,"RED",{
  sourceMap="KA_HEVO_RED_SHRINE",stone="BLAZIKENITE",
  stoneStatus="claimed",
}))
assert(campaign.handoff.stoneStatus=="claimed"
    and campaign.handoff.stone=="BLAZIKENITE"
    and campaign.handoff.stoneAnnounced==false,
  "same-character handoff did not repair an already-owned stone")
assert(shared.recordHandoff(nil,"RED",{
  sourceMap="KA_HEVO_RED_SHRINE",stone="BLAZIKENITE",
  stoneStatus="character",
}))
assert(campaign.handoff.stoneStatus=="claimed",
  "later failed retry downgraded an already-owned stone receipt")
campaign.handoff.stoneStatus="character"
campaign.handoff.stone=nil
campaign.handoff.stoneAnnounced=true
assert(shared.recordHandoff(nil,"RED",{
  sourceMap="KA_HEVO_RED_SHRINE",stone="BLAZIKENITE",
  stoneStatus="granted",
}))
assert(campaign.handoff.stoneStatus=="granted"
    and campaign.handoff.stone=="BLAZIKENITE"
    and campaign.handoff.stoneAnnounced==false,
  "same-character handoff did not monotonically repair a verified grant")
assert(shared.recordHandoff(nil,"RED",{
  sourceMap="KA_HEVO_RED_SHRINE",stone="BLAZIKENITE",
  stoneStatus="character",
}))
assert(campaign.handoff.stoneStatus=="granted",
  "later failed retry downgraded an existing stone grant")

local oldSound=package.loaded["src.core.Sound"]
local cry
local completedRecoveryAttempts=0
shared.ensureOwnHandoff=function()
  completedRecoveryAttempts=completedRecoveryAttempts+1
  return false,"unexpected-recovery"
end
package.loaded["src.core.Sound"]={playCry=function(_,species)
  sequence[#sequence + 1] = "cry"
  cry=species
end}
local finished=false
assert(shared.doorInteraction({data={}},nil,nil,function() finished=true end))
package.loaded["src.core.Sound"]=oldSound
assert(cry=="GROUDON" and #blackouts==1
    and blackouts[1].teaser=="RED",
  "shared door lost its character-specific cry/blackout")
assert(completedRecoveryAttempts==0,
  "door retried recovery despite the end seal's existing durable authority")
assert(blackouts[1].text:find("time is not yet right",1,true),
  "shared door lost the explicit not-yet-ready beat")
assert(table.concat(sequence, ",")=="stone,cry,not-yet,oak-call,epilogue",
  "shared door must acknowledge the secured stone, then order cry, not-yet text, real Oak call, and epilogue")
assert(finished and #shown==2
    and shown[1]:find("BLAZIKENITE",1,true)
    and shown[1]:find("Stone Case",1,true)
    and shown[2]:find("TORCHIC",1,true)
    and shown[2]:find("OAK's left ball",1,true)
    and shown[2]:find("return path",1,true),
  "shared door lacks the clean next-Journey starter/return epilogue")
assert(saved[shared.RUN_STATE].doorVisits.RED==true,
  "shared door visit is not persisted in the run campaign")

shown,sequence={},{}
package.loaded["src.core.Sound"]={playCry=function()
  sequence[#sequence+1]="cry"
end}
assert(shared.doorInteraction({data={}},nil,nil,function() end))
package.loaded["src.core.Sound"]=oldSound
assert(table.concat(sequence,",")=="cry,not-yet,oak-call,epilogue"
    and #shown==1 and not shown[1]:find("BLAZIKENITE",1,true),
  "shared door repeated the exact-once stone acknowledgement")

-- A direct load/resume at the real door can miss both runtime warp events.
-- The door gets exactly one coordinator retry, re-reads Journey authority,
-- and only then persists the visit.  A retry that cannot prove the seal must
-- still show the locked text and leave no campaign authority behind.
local recoverySaved,recoveryShown,recoveryBlackouts={}, {}, 0
local recoverySeal,recoveryAttempts=false,0
local recoveryMod={save={
  get=function(_,key)return recoverySaved[key]end,
  set=function(_,key,value)recoverySaved[key]=value end,
}}
local recovery=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(recoveryMod,{
  activeCharacter=function()return "RED"end,
  showText=function(_,message,done)
    recoveryShown[#recoveryShown+1]=message
    if done then done() end
    return true
  end,
  blackout=function(_,_,done)
    recoveryBlackouts=recoveryBlackouts+1
    if done then done() end
    return true
  end,
  journey={
    currentHevoSeal=function(_,character)return recoverySeal,character end,
    notifyHevoSeal=function(_,_,done)if done then done()end;return true end,
  },
})
recovery.ensureOwnHandoff=function(_,character)
  recoveryAttempts=recoveryAttempts+1
  assert(character=="RED","door recovery changed character")
  recoverySeal=true
  return recovery.recordHandoff(nil,"RED",{
    sourceMap="KA_HEVO_RED_SHRINE",stone="BLAZIKENITE",
    stoneStatus="claimed",
  })
end
package.loaded["src.core.Sound"]={playCry=function()end}
assert(recovery.doorInteraction({data={},save={}}))
package.loaded["src.core.Sound"]=oldSound
assert(recoveryAttempts==1 and recoveryBlackouts==1
    and recoverySaved[recovery.RUN_STATE].doorVisits.RED==true,
  "physical black door did not recover and persist the proven RED seal")

local rejectedSaved,rejectedShown={},{}
local rejectedMod={save={
  get=function(_,key)return rejectedSaved[key]end,
  set=function(_,key,value)rejectedSaved[key]=value end,
}}
local rejected=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(rejectedMod,{
  activeCharacter=function()return "RED"end,
  showText=function(_,message,done)
    rejectedShown[#rejectedShown+1]=message
    if done then done() end
    return true
  end,
  journey={currentHevoSeal=function(_,character)return false,character end},
})
local rejectedAttempts=0
rejected.ensureOwnHandoff=function()rejectedAttempts=rejectedAttempts+1;return false,"gate"end
assert(rejected.doorInteraction({data={},save={}}))
assert(rejectedAttempts==1 and #rejectedShown==1
    and rejectedShown[1]:find("SEAL SYSTEM ERROR",1,true)
    and rejectedSaved[rejected.RUN_STATE]==nil,
  "missing progress seam was not treated as a safe technical failure")

-- Ordinary unfinished routes receive one character-specific, live report.
-- The return starts only after the report is dismissed, targets the bound
-- character branch, and cannot complete the outer callback twice.
local progressCases={
  RED={reason="gate",report={statues=4,boulders={A=true,B=true,C=false},
      beyond=true},fragments={"GROUDON TRIAL","KNOWLEDGE STATUES\n4/5",
      "BOULDER C\nMISSING","BEYOND KANTO:\nACTIVE","FISSURE PATH"}},
  BLUE={reason="sight",report={statues=3,finalStatue=false,
      switches={HALL=true,ICE=false,DEPTHS=true},beyond=false},
    fragments={"KYOGRE TRIAL","FROST STATUES\n3/5",
      "EAST DEPTHS STATUE\nMISSING","HALL SWITCH\nOK","ICE SWITCH\nMISSING",
      "DEPTHS SWITCH\nOK","BEYOND KANTO:\nMISSING","FISSURE PATH"}},
  GREEN={reason="statues",report={statues=2,rootgate=true,canopy=false,
      beyond=true},fragments={"RAYQUAZA TRIAL","LEAF STATUES\n2/5",
      "ROOT GATE: OK","CANOPY: MISSING","BEYOND KANTO:\nACTIVE",
      "FISSURE PATH"}},
}
for character,case in pairs(progressCases) do
  local texts,pending,returns,doneCount={},nil,0,0
  local progressMod={save={get=function()end,set=function()end}}
  local progress=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(progressMod,{
    activeCharacter=function()return character end,
    showText=function(_,message,callback)
      texts[#texts+1]=message;pending=callback;return true
    end,
    journey={currentHevoSeal=function(_,key)return false,key end},
  })
  progress.ensureOwnHandoff=function(_,key)
    assert(key==character);return false,case.reason
  end
  progress.completionProgress=function(_,key)
    assert(key==character);return case.report
  end
  progress.returnToTrialStart=function(_,key,callback)
    assert(key==character);returns=returns+1
    callback();callback();return true
  end
  assert(progress.doorInteraction({data={},save={}},nil,nil,
    function()doneCount=doneCount+1 end))
  assert(#texts==1 and returns==0 and doneCount==0 and type(pending)=="function",
    character.." report teleported before dismissal")
  for _,fragment in ipairs(case.fragments) do
    assert(texts[1]:find(fragment,1,true),
      character.." report omitted "..fragment)
  end
  pending()
  assert(returns==1 and doneCount==1,
    character.." report return/done callback was not exact-once")
end
local beyondTexts,beyondPending,beyondReturns,beyondDone={},nil,0,0
local beyondOnly=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(
  {save={get=function()end,set=function()end}}, {
    activeCharacter=function()return "GREEN"end,
    showText=function(_,message,callback)
      beyondTexts[#beyondTexts+1]=message;beyondPending=callback;return true
    end,
    journey={currentHevoSeal=function(_,key)return false,key end},
  })
beyondOnly.ensureOwnHandoff=function()return false,"beyond-kanto-sealed"end
beyondOnly.completionProgress=function()
  return {statues=5,rootgate=true,canopy=true,beyond=false}
end
beyondOnly.returnToTrialStart=function(_,key,callback)
  assert(key=="GREEN");beyondReturns=beyondReturns+1;callback();return true
end
assert(beyondOnly.doorInteraction({data={},save={}},nil,nil,
  function()beyondDone=beyondDone+1 end))
assert(#beyondTexts==1 and beyondReturns==0 and beyondDone==0
    and beyondTexts[1]:find("LEAF STATUES\n5/5",1,true)
    and beyondTexts[1]:find("ROOT GATE: OK",1,true)
    and beyondTexts[1]:find("CANOPY: OK",1,true)
    and beyondTexts[1]:find("BEYOND KANTO:\nMISSING",1,true),
  "Beyond-only block was not distinguished from route/archive failure")
beyondPending()
assert(beyondReturns==1 and beyondDone==1,
  "Beyond-only report did not return exactly once after dismissal")
local germanShared=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(
  {save={get=function()end,set=function()end}},
  {i18n={text=function(_,de)return de end}})
local germanReport=germanShared.progressText("BLUE",{
    statues=4,finalStatue=false,
    switches={HALL=true,ICE=false,DEPTHS=true},beyond=false,
  })
assert(germanReport:find("FROSTSTATUEN\n4/5",1,true)
    and germanReport:find("TIEFEN-OSTSTATUE\nFEHLT",1,true)
    and germanReport:find("SCHALTER HALLE\nOK",1,true)
    and germanReport:find("SCHALTER EIS\nFEHLT",1,true)
    and germanReport:find("JENSEITS VON KANTO\nFEHLT",1,true)
    and germanReport:find("BLAUEN\nRISSPFAD",1,true),
  "German BLUE report lost a required status or return message")
local TextBox=require("src.render.TextBox")
local pageTexts={}
for character,case in pairs(progressCases) do
  pageTexts[#pageTexts+1]={"EN "..character,
    shared.progressText(character,case.report)}
  pageTexts[#pageTexts+1]={"DE "..character,
    germanShared.progressText(character,case.report)}
end
for _,reason in ipairs({"character","warp","save","adapter"}) do
  pageTexts[#pageTexts+1]={"EN technical "..reason,
    shared.technicalFailureText(reason)}
  pageTexts[#pageTexts+1]={"DE technical "..reason,
    germanShared.technicalFailureText(reason)}
end
for _,row in ipairs(pageTexts) do
  for index,page in ipairs(TextBox.paginate(row[2],18)) do
    assert(#page<=2,row[1].." page "..index
      .." scrolls "..#page.." lines before confirmation")
  end
end

-- Save/archive/integration reasons, character mismatches and unknown results
-- are never converted into an ordinary report or a teleport.
for _,reason in ipairs({"save","rollback-save","archive","adapter","game",
    "character","seal","claimed","storage","package-stage","unknown"}) do
  local texts,queries,returns,doneCount={},0,0,0
  local technical=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(
    {save={get=function()end,set=function()end}}, {
      activeCharacter=function()return "RED"end,
      showText=function(_,message,callback)
        texts[#texts+1]=message;if callback then callback()end;return true
      end,
      journey={currentHevoSeal=function(_,key)return false,key end},
    })
  technical.ensureOwnHandoff=function()return false,reason end
  technical.completionProgress=function()queries=queries+1;return {} end
  technical.returnToTrialStart=function()returns=returns+1;return true end
  assert(technical.doorInteraction({data={},save={}},nil,nil,
    function()doneCount=doneCount+1 end))
  assert(#texts==1 and texts[1]:find("REMAIN HERE",1,true)
      and queries==0 and returns==0 and doneCount==1,
    reason.." failure was misclassified as ordinary incomplete progress")
end

local function thrownSeamCase(label,configure,expectedTexts)
  local localSaved,texts,doneCount,blackouts={}, {}, 0, 0
  local localMod={save={get=function(_,key)return localSaved[key]end,
    set=function(_,key,value)localSaved[key]=value end}}
  local options={
    activeCharacter=function()return "RED"end,
    showText=function(_,message,callback)
      texts[#texts+1]=message;if callback then callback()end;return true
    end,
    blackout=function()blackouts=blackouts+1;return true end,
  }
  configure(options)
  local instance=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(localMod,options)
  if options.configureInstance then options.configureInstance(instance) end
  assert(instance.doorInteraction({data={},save={}},nil,nil,
    function()doneCount=doneCount+1 end))
  assert(#texts==expectedTexts and doneCount==1 and blackouts==0
      and localSaved[instance.RUN_STATE]==nil
      and texts[#texts]:find("REMAIN HERE",1,true),
    label.." did not fail closed at the shared seal")
end
thrownSeamCase("missing currentHevoSeal",function(options)
  options.journey={}
end,1)
thrownSeamCase("throwing currentHevoSeal",function(options)
  options.journey={currentHevoSeal=function()error("read")end}
end,1)
thrownSeamCase("throwing recovery",function(options)
  options.journey={currentHevoSeal=function(_,key)return false,key end}
  options.configureInstance=function(instance)
    instance.ensureOwnHandoff=function()error("recover")end
  end
end,1)
thrownSeamCase("throwing report",function(options)
  options.journey={currentHevoSeal=function(_,key)return false,key end}
  options.configureInstance=function(instance)
    instance.ensureOwnHandoff=function()return false,"gate"end
    instance.completionProgress=function()error("report")end
  end
end,1)
thrownSeamCase("throwing return",function(options)
  options.journey={currentHevoSeal=function(_,key)return false,key end}
  options.configureInstance=function(instance)
    instance.ensureOwnHandoff=function()return false,"gate"end
    instance.completionProgress=function()
      return {statues=4,boulders={A=true,B=true,C=false},beyond=true}
    end
    instance.returnToTrialStart=function()error("warp")end
  end
end,2)

-- A report may be shown successfully while the WorldAPI later refuses the
-- return.  That second failure gets clear feedback and still stays at the
-- final seal; nil is not a successful warp receipt.
local failedTexts,failedCallbacks,failedDone={}, {}, 0
local failedReturn=assert(loadfile(root.."/hidden_evolution_shared_story.lua"))()(
  {save={get=function()end,set=function()end}}, {
    activeCharacter=function()return "RED"end,
    showText=function(_,message,callback)
      failedTexts[#failedTexts+1]=message
      failedCallbacks[#failedCallbacks+1]=callback
      return true
    end,
    journey={currentHevoSeal=function(_,key)return false,key end},
  })
failedReturn.ensureOwnHandoff=function()return false,"gate"end
failedReturn.completionProgress=function()
  return {statues=4,boulders={A=true,B=true,C=false},beyond=true}
end
failedReturn.returnToTrialStart=function()return nil,"storage"end
assert(failedReturn.doorInteraction({data={},save={}},nil,nil,
  function()failedDone=failedDone+1 end))
assert(#failedTexts==1 and failedDone==0)
failedCallbacks[1]()
assert(#failedTexts==2 and failedTexts[2]:find("REMAIN HERE",1,true)
    and failedDone==0,"failed return lacked its stay-at-seal warning")
failedCallbacks[2]()
assert(failedDone==1,"failed return did not finish exactly once")

-- The runtime fallback is a real opaque state, not a TextBox.  Its original
-- single Font.draw call could neither lay out newlines nor contrast reliably
-- on the black fill, producing a completely blank acceptance screenshot.
-- Exercise that native state with a render recorder: the authored bytes stay
-- intact, while the four source rows wrap into individually drawn box lines.
local savedLove, savedFont = _G.love, package.loaded["src.render.Font"]
local savedSound = package.loaded["src.core.Sound"]
local receipts = { colors = {}, lines = {} }
_G.love = { graphics = {
  setColor = function(...)
    receipts.colors[#receipts.colors + 1] = { ... }
  end,
  rectangle = function(mode, x, y, w, h)
    receipts.background = { mode, x, y, w, h }
  end,
} }
package.loaded["src.render.Font"] = {
  width = function(text)
    local glyphs = #tostring(text):gsub("[\128-\191]", "")
    return glyphs * 8
  end,
  drawBox = function(tx, ty, tw, th)
    receipts.box = { tx, ty, tw, th }
  end,
  draw = function(text, x, y)
    receipts.lines[#receipts.lines + 1] = { text, x, y }
  end,
}
package.loaded["src.core.Sound"] = { playCry = function() end }

local nativeSaved, nativeState = {}, nil
local nativeMod = { save = {
  get = function(_, key) return nativeSaved[key] end,
  set = function(_, key, value) nativeSaved[key] = value end,
} }
local native = assert(loadfile(root .. "/hidden_evolution_shared_story.lua"))()(nativeMod, {
  activeCharacter = function() return "RED" end,
  i18n = { text = function(_, de) return de end },
  journey = {
    currentHevoSeal = function(_, character) return true, character end,
    notifyHevoSeal = function() error("blackout was skipped") end,
  },
})
local nativeGame = {
  data = {}, save = {},
  stack = { push = function(_, state) nativeState = state end },
}
assert(native.doorInteraction(nativeGame),
  "native shared-door blackout did not open")
assert(nativeState and nativeState.isOpaque == true
    and nativeState.text == native.TEASERS.RED.de,
  "native blackout did not retain the authored German teaser bytes")
assert(type(nativeState.lines) == "table" and #nativeState.lines >= 4
    and table.concat(nativeState.lines, "\n"):gsub("%s+", " "):find(
      "Zeit ist noch nicht reif", 1, true),
  "native blackout did not wrap the visible German not-yet beat")
for _, line in ipairs(nativeState.lines) do
  assert(package.loaded["src.render.Font"].width(line) <= 18 * 8,
    "native blackout line exceeds the Game Boy text box")
end
nativeState:draw()
assert(receipts.background and receipts.background[1] == "fill"
    and receipts.background[4] == 160 and receipts.background[5] == 144,
  "native blackout lost its full black field")
assert(receipts.box and receipts.box[1] == 0 and receipts.box[3] == 20,
  "native blackout lacks its readable Game Boy text box")
assert(#receipts.lines == #nativeState.lines,
  "native blackout did not draw every wrapped teaser line separately")

_G.love = savedLove
package.loaded["src.render.Font"] = savedFont
package.loaded["src.core.Sound"] = savedSound

print("hidden_evolution_shared_antechamber_test: PASS")
