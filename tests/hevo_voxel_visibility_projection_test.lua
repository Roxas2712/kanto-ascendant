-- Camera-space regression: the adjacent cell used to fall behind the camera
-- in the GREEN shrine, causing an entirely opaque frame.
local root=(arg and arg[1]) or '.'
local state={angle=math.pi/2}
local first={cardBlend=function()return 1 end,cardYaw=function()return math.pi/2 end}
local factor=2
local near=true
local projector={project=function(x,y,z)
  if near and z>=31 then return nil end
  return x*4,(100-y+z)*4
end}
local modules={Voxel3D=projector,VoxelState=state,FirstPerson=first,
  VoxelScene={groundAt=function()return 3 end},AntiAlias={factor=function()return factor end}}
local V=assert(loadfile(root..'/hidden_evolution_visibility_compat.lua'))()({},
 {routes={},voxelRenderer={module=function(_,name)return modules[name] end}})
local ow={map={id='KA_HEVO_GREEN_RAYQUAZA_SHRINE'},player={px=16,py=16,facing='down'}}
local canvas={getDimensions=function()return 1000,700 end}
local g=V.pipelineGeometry({},ow,canvas,{pipeline='voxel'})
assert(g.centerX==48 and g.centerY==226,'mask must follow the upright card midpoint')
assert(g.cellPixels==32,'scene AA must be folded into final canvas coordinates')
assert(g.projection=='legacy-voxel-card-midpoint')
for _,facing in ipairs({'up','down','left','right'})do
 ow.player.facing=facing;local p=V.pipelineGeometry({},ow,canvas,{})
 assert(p.cellPixels==g.cellPixels,'circle radius must not change when player turns')
 assert(p.facing[1]^2+p.facing[2]^2>0,'RED cone must keep a valid direction')
end
first.cardBlend=function()return .5 end;state.angle=0
local p=V.pipelineGeometry({},ow,canvas,{})
local dz=8*math.sin(-math.pi/4)
assert(math.abs(p.centerX-(24+dz*math.sin(math.pi/4))*2)<1e-8,'orbit yaw must rotate leaned card center')
projector.project=function()return nil end
assert(not V.pipelineGeometry({},ow,canvas,{}).centerX,'unprojectable points stay fail-closed')
print('PASS HEVO voxel visibility: midpoint, near plane, AA, direction independence, yaw, fail closed')
-- A camera inside the player's card must still have a native-cell radius.
local depth={};local inverse={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
projector.visibilityDepth=function()return depth,inverse end
local world=V.pipelineGeometry({},ow,canvas,{})
assert(world.sceneDepth==depth and world.inverseVP==inverse)
assert(world.cellPixels==16 and world.centerX==24 and world.centerY==24)
assert(world.projection=='voxel-depth-world-distance')
print('PASS depth-backed visibility preserves native world radius even when player cannot be projected')
