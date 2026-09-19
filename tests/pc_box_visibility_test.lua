-- Run with GEN1RECOMP_DIR pointing at the released engine and
-- TRAINER_REMATCH_MOD_DIR pointing at the mod checkout. Graphics deliberately
-- rejects unavailable paths like LOVE; storage and asset resolution are real.
local engine = assert(os.getenv('GEN1RECOMP_DIR'))
local root = os.getenv('TRAINER_REMATCH_MOD_DIR') or '.'
package.path = engine .. '/?.lua;' .. package.path
local options = { modern_storage_ui = true, pc_interface_style = 'firered',
  box_grid_icon_style = 'current', fast_box_switch = true }
local images, draws, balls = {}, {}, 0
local path = 'assets/generated/battle/front/pikachu.png'
local derived = 'save/mod-derived/test/battle/front/pikachu.png'
local walker = 'vendor/wilds_1_12_2/assets/bundled_runtime/followsprites_runtime/025-normal.png'
local available = { [derived] = true, [walker] = true }
local function noop() end
love = { graphics = {setColor=noop, rectangle=noop, polygon=noop, arc=noop,
  push=noop, pop=noop, scale=noop, translate=noop,
  circle=function(mode, _, _, radius) if mode=='fill' and radius==5 then balls=balls+1 end end,
  newQuad=function(...)return {...}end,
  newImage=function(p)
    local atlas=p=='atlas'
    assert(atlas or available[p], 'missing image: '..tostring(p))
    local image={path=p,getWidth=function()return atlas and 641 or p==walker and 16 or 56 end,
      getHeight=function()return atlas and 1240 or p==walker and 96 or 56 end,setFilter=noop}
    images[#images+1]=image
    return image
  end,
  draw=function(image,...)draws[#draws+1]={image=image,args={...}}end,
}, filesystem={getInfo=function(p)return available[p] and {type='file'} or nil end} }
package.preload['src.render.Font']=function()return {
  width=function(s)return #tostring(s or '')*6 end,draw=noop,drawCode=noop,
  split=function(s)local r={}for i=1,#s do r[i]={from=i,to=i}end return r end,
  spansFitting=function(s,w)return math.min(#s,math.floor(w/6))end,
}end
package.preload['src.core.Strings']=function()return function(s,...)return string.format(s,...)end end
package.preload['src.ui.Theme']=function()return {cursor=1,cursorHollow=2}end
package.preload['src.render.PaletteFX']=function()return {trueColorZone=function()return{}end}end
local ListMenu={new=function(game,title,items)return{game=game,title=title,items=items,index=1}end}
local BoxMenu={new=function(game)return{game=game,items={},index=1}end}
for name,t in pairs({ListMenu=ListMenu,BoxMenu=BoxMenu,BagMenu={new=function(game)return{game=game}end},Menu={new=function(game,items)return{game=game,items=items,index=1}end}})do
 package.preload['src.ui.'..name]=function()return t end
end
local Assets=require('src.render.Assets')
Assets.loader={overrideOrder=function()return{}end,derivedPath=function(_,rel)
 if rel=='battle/front/pikachu.png' and available[derived] then return derived end
end}
local Runtime=require('src.mods.Runtime')
local selectedPath
Runtime.install({emit=noop},{chains={['pokemon.sprite']=true},call=function(_,_,_,p)
 if selectedPath=='error' then error('temporary provider error')end
 return selectedPath or p
end})
local mod={id='kanto_ascendant',exports={},options={get=function(_,key)return options[key]end},
  assets={path=function(_,p)return p=='assets/ui/frlg_pc/interface.png' and 'atlas' or p end},read=function(_,p)
    if p=='assets/ui/frlg_pc/interface.png' or available[p] then return 'png' end
  end,find=function()return nil end}
assert(loadfile(root..'/modern_storage_ui.lua'))()(mod,{i18n={isGerman=function()return false end,text=function(en)return en end}})
local Boxes=require('src.pokemon.Boxes')
local game={data={pokemon={PIKACHU={name='PIKACHU',dex=25,spriteFront=path}}},
 save={party={},boxes={},currentBox=1,options={modOptions={kanto_ascendant=options}}}}
for i=1,12 do game.save.boxes[i]={}end
local box=Boxes.active(game.save)
local items={}
for i=1,20 do box[i]={species='PIKACHU',level=12};items[i]={value=i,label='PIKACHU'}end
local originalMon=box[1]
local checks,failed=0,0
local function check(ok,msg)checks=checks+1;if not ok then failed=failed+1;print('FAIL '..msg)end end
local function render(menu)
 draws={};balls=0;menu:draw()
 local n=0;for _,v in ipairs(draws)do if v.image.path~='atlas' then n=n+1 end end
 return n
end
for _,style in ipairs({'firered','firered_wide'})do
 options.pc_interface_style=style
 local menu=BoxMenu.new(game)
 selectedPath=nil;available[derived]=true;Assets.invalidate()
 check(render(menu)==20,style..': all 20 occupied slots use derived artwork')
 local loaded=#images;render(menu)
 check(#images==loaded,style..': successful image is cached by engine')
 local first=images[#images]
 Assets.invalidate();render(menu)
 check(images[#images]~=first,style..': asset invalidation refreshes image')
 selectedPath='other-art.png';available[selectedPath]=true
 check(render(menu)==20 and draws[#draws].image~=nil,style..': live alternate art rendered')
 local found=false;for _,v in ipairs(draws)do if v.image.path==selectedPath then found=true end end
 check(found,style..': same-species appearance change does not reuse stale art')
 selectedPath='recovering.png';available[selectedPath]=nil
 check(render(menu)==0 and balls==20,style..': missing artwork keeps all occupied slots visible')
 available[selectedPath]=true
 check(render(menu)==20,style..': failed load recovers without restart or option change')
 selectedPath='error'
 check(render(menu)==0 and balls==20,style..': provider error keeps occupied slots visible')
 selectedPath='recovered-provider.png';available[selectedPath]=true
 check(render(menu)==20,style..': provider recovers on next draw')
 -- Selection screen: left preview + the same 20-slot grid.
 local list=ListMenu.new(game,'WITHDRAW POKéMON',items)
 check(render(list)==21,style..': withdrawal preview and grid both visible')
 options.box_grid_icon_style='hgss_walker'
 check(render(list)==21,style..': HGSS grid retains the large front preview')
 local walkers=0;for _,v in ipairs(draws)do if v.image.path==walker then walkers=walkers+1 end end
 check(walkers==20,style..': exactly 20 HGSS grid icons')
 options.box_grid_icon_style='current'
 local removed=table.remove(box);check(render(menu)==19,style..': empty slot has no phantom icon')
 box[20]=removed
 check(Boxes.active(game.save)==box and #box==20 and box[1]==originalMon,
   style..': drawing preserves storage identity and contents')
end
print(('PC BOX VISIBILITY: %d/%d passed'):format(checks-failed,checks))
assert(failed==0, 'PC box visibility regressions: '..failed)
