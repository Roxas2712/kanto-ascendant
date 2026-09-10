-- P0 Hoenn Mega runtime contract.  This exercises the real profile/resolver
-- module with a minimal ModKit-shaped host; the full main-load suite is also
-- covered in trainer_rematch_test.lua when the Authority branch compiles.
local source=debug.getinfo(1,"S").source:sub(2)
local root=os.getenv("TRACE_FIX_ROOT") or source:match("^(.*)/tests/[^/]+$") or "."
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

local checks=0
for _,mode in ipairs({"all","bosses"}) do
 options.mega_evolution=true;options.mega_opponents=mode
 for _,species in ipairs({"MAWILE","MANECTRIC","BLAZIKEN"}) do
  for _,level in ipairs({18,79,80,90}) do
   local battle={kind="trainer",oppClass="OPP_LANCE",ascendantLegacyWanderer=true,
    game={save={hallOfFame={{}}}},enemyParty={{species=species,level=level,hp=1}}}
   battle.enemy={mon=battle.enemyParty[1]}
   eq(mega.opponentEligible(battle),false,"generic class/level/mode cannot bypass planner")
   local activated,why=mega.activate(battle,battle.enemy,"enemy")
   eq(activated,false,"direct activation cannot bypass rejected plan")
   eq(why,"wanderer-plan","activation denial comes from Wanderer authority")
   events:emit("battle.started",{battle=battle})
   eq(battle._ascMegaEnemyPending,nil,"rejected plan cannot arm automatic Mega")
   battle.ascendantSurpriseMega=true
   battle.ascendantEnemyMegaSpecies=species
   battle.ascendantEnemyMegaForm=species
   eq(mega.opponentEligible(battle),level>=80,"approved plan keeps level boundary")
   events:emit("battle.started",{battle=battle})
   eq(battle._ascMegaEnemyPending,level>=80 and true or nil,"only approved late plan arms Mega")
   checks=checks+6
  end
 end
end
options.mega_opponents="bosses"
yes(mega.opponentEligible({kind="trainer",oppClass="OPP_LANCE"}),"ordinary boss remains eligible")
options.mega_opponents="off"
eq(mega.opponentEligible({kind="trainer",oppClass="OPP_LANCE"}),false,"global off remains respected")
print("WANDERER MEGA GATE PASS: "..(checks+2).." checks")
