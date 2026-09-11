local make=assert(loadfile("pokemon_equipment_67.lua"))()
local n=0
local function check(v,m)n=n+1;assert(v,m)end
local function scenario(fail)
 local mon={species="BULBASAUR"}
 local game={save={meta={playthroughId="trace-save"},modData={kanto_ascendant={discovery_core={pity=25}},other={preserved=true}}},mods={}}
 function game:adoptSave(save)self.mods.modSave=save.modData end
 game:adoptSave(game.save)
 local original=game.save.modData
 local boundAtWrite
 local M=make({owned=function()return {{mon=mon}}end,item=function()return {}end,generation=function()return 3 end,
 writeSave=function(g)
  boundAtWrite=g.mods.modSave==g.save.modData
  return not fail
 end,canEdit=function()return true end,canWrite=function()return true end,digest=function(x)return x end,bag={}})
 local ok=M.bind(game)
 check(boundAtWrite,"staged save is bound to mod API")
 check(game.mods.modSave==game.save.modData,"binding preserved on success and rollback")
 if fail then check(not ok and game.save.modData==original and not mon._kascEquipmentHandle,"rollback restores metadata and identity")
 else check(ok,"bind succeeds")end
 game.mods.modSave.kanto_ascendant.discovery_core={pity=26}
 check(game.save.modData.kanto_ascendant.discovery_core.pity==26,"later trace progress reaches saved state")
 check(game.save.modData.other.preserved,"other mod namespace preserved")
end
scenario(false);scenario(true)
print("EQUIPMENT SAVE BINDING PASS: "..n.." checks")
