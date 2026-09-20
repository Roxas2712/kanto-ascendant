local root=assert(arg[1]);local pipeline
package.preload['src.render.Pipelines']=function()return{worldPipeline=function()return pipeline end}end
local factory=assert(loadfile(root..'/hoenn_battle_surrounds_67.lua'))()
local mod={id='kanto_ascendant',options={get=function()return true end}}
local C=factory(mod,{})
local game={overworld={map={id='KA_MOLTRES_VOLCANO'}}}
game.stack={top=function()return game.overworld end}
assert(C.mapViewTarget(game).kind=='volcano','lost classical surround')
for _,id in ipairs({'voxel','other-world-renderer'})do pipeline=id;assert(C.mapViewTarget(game)==nil,'2D padding overlays a projected world')end
pipeline=nil;assert(C.mapViewTarget(game).kind=='volcano','2D switch does not restore surround')
game.overworld.map.id='KA_HEVO_RAYQUAZA_CHAMBER';assert(C.mapViewTarget(game).kind=='sky')
pipeline='voxel';assert(not C.mapViewTarget(game))
pipeline=nil;game.stack.top=function()return{isBattle=true}end;assert(not C.mapViewTarget(game),'battle regression')
print('PASS KASC 2D surroundings preserved, projected world padding suppressed, battle exclusion retained')
