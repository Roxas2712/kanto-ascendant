-- Observe the native renderer's preparation; do not build a second cache.
local M={}
function M.attach(card,resolve)
 card:add('destination-scene',function(game)
  local exports=resolve()
  if not exports then return true end
  if exports.generation==2 then
   -- Oak creates the Gen-2 world only after name/clock/gender selection.
   -- Keep that order intact; the intro itself is warmed by native drawing.
   if not(game.world and game.world.map)then return true end
   local status=exports.voxelStatus and exports.voxelStatus()
   if not status or not status.configuredVoxel then return true end
   if status.lastError or status.meshError or status.neighborWarmupError then
    error(status.lastError or status.meshError or status.neighborWarmupError)
   end
   return status.currentMapPresented==true
    and status.currentMapId==game.world.map.id
    and not status.neighborWarmupPending
    and (not status.openWorld or status.neighborDirectComplete)
    and (status.openWorldPendingBuilds or 0)==0
  end
  if require('src.render.Pipelines').worldPipeline()~='voxel'then return true end
  local lib=exports.lib
  local scene=lib and lib.require and lib.require('VoxelScene')
  if not scene or type(scene.readyForReveal)~='function'then return true end
  return scene.readyForReveal(game.overworld)==true
 end,true)
end
return M
