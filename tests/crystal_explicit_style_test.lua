-- Encounter-local VASC Crystal must override the saved KASC Classic choice.
local savedStyle, colorMode, voxel = 'classic', 'redpp', 7
local palette = {mode=colorMode}
package.loaded['src.render.PaletteFX']=palette
package.loaded['src.render.Pipelines']={level=function()return voxel end}
love={image={},graphics={newImage=function(path)
 return {path=path,setFilter=function()end}
end}}
local data={pokemon={GOROCHU={dex=1026},BULBASAUR={dex=1}}}
local mon={species='GOROCHU'}
local values={crystal_animation=true}
local mod={path='pack',events={on=function()end},options={get=function(_,key)
 if key=='pokemon_sprite_style'then return savedStyle end
 return values[key]
end},info=function()return{type='file',size=1}end,read=function()return'png'end}
local A=assert(loadfile('crystal_animation.lua'))()(mod,{
 guestDexes={[1026]=true},classicGuestDexes={[1026]=true},
 shinySystem={isShiny=function(m)return m and m.shiny end},
 animationData={normal={['1026']={100,100}},shiny={['1026']={100,100}}}})
for _,side in ipairs{'front','back'}do
 for _,shiny in ipairs{false,true}do
  mon.shiny=shiny
  local expected=shiny and'shiny'or'normal'
  local ctx={data=data,species=mon.species,mon=mon,kind='battle',forceStyle=true}
  local path,tc=A.staticFrameOne(ctx,side,expected)
  assert(path:find('/'..expected..'/',1,true) and tc,'explicit static Crystal became grayscale: '..path)
  local state=assert(A.presentationAnimation(mon.species,mon,side,'battle',{data=data,forceStyle=true}))
  assert(state.variant==expected and state.trueColor,'explicit animated Crystal became grayscale')
  A.advancePresentation(state,.15,{data=data})
  assert(state.path:find('/'..expected..'/',1,true),'animation switched back to Classic')
  ctx.forceStyle=nil
  assert(A.staticFrameOne(ctx,side,expected):find('/grayscale/',1,true),'saved Classic lost its monochrome art')
  assert(not A.presentationAnimation(mon.species,mon,side,'battle',{data=data}),'AUTO ignored saved Classic')
 end
end
savedStyle='crystal';mon.shiny=false
assert(A.presentationAnimation(mon.species,mon,'front','battle',{data=data}).variant=='normal')
voxel=0;palette.mode='dmg'
assert(A.presentationAnimation(mon.species,mon,'front','battle',{data=data,forceStyle=true}).variant=='grayscale','native monochrome palette lost')
assert(A.staticFrameOne({data=data,species=mon.species,mon=mon,kind='box'},'front','shiny'):find('/shiny/',1,true),'menu shiny lost')
print('PASS explicit Crystal normal/shiny, front/back, advancing frames; saved Classic/AUTO, native palettes and menus retained')
