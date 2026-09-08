local root=assert(os.getenv('BALL_QA_ROOT'))
local picker,box,requests,doneCount=nil,nil,0,0
package.loaded['src.ui.Screens']={push=function(_,id,opts)assert(id=='PartyMenu');picker=opts;return opts end}
package.loaded['src.render.TextBox']={new=function(_,text,done)return {text=text,onDone=done}end}
local german=false;local beyond=true;local era=true
local P=assert(loadfile(root..'/kasc-candidate/hevo_packages.lua'))()({id='kanto_ascendant'}, {enabled=false,bag={},i18n={text=function(en,de)return german and de or en end},beyondKanto={isActive=function()return beyond end},generationRules={shouldUseEpoch=function()return era end}})
local game={save={party={},inventory={POTION=3}},data={},stack={push=function(_,value)box=value end}}
local mon={species='EEVEE'}
local function done()doneCount=doneCount+1 end
local request=function(_,selected,trigger,callback)requests=requests+1;assert(selected==mon and trigger.kind=='hevo_field');callback();return true end
for _,id in ipairs({'moss_field','ice_field','magnetic_field'})do
 for _,lang in ipairs({false,true})do
  german=lang
  local function select(reason,expected)
   local oldDone=doneCount;box=nil
   assert(P.useFieldAltar(game,id,nil,done,{request=request}))
   picker.onSwitch(mon)
   assert(box and box.text:find(expected,1,true),reason)
   assert(doneCount==oldDone,'callback before feedback closed')
   box.onDone();assert(doneCount==oldDone+1)
  end
  beyond=false;select('beyond',german and 'Epoche' or 'era');beyond=true
  select('locked',german and 'versiegelt' or 'sealed')
  P.persistent(game.save,true).packageUnlocks[id]=true
  local wrong={species='DIGLETT'};local old=mon;mon=wrong
  select('species',german and 'entwickeln' or 'cannot');mon=old
  if id~='magnetic_field' then era=false;select('era',german and 'Epoche' or 'era');era=true end
  local saved=P.persistent(game.save,true);saved.packageUnlocks[id]=nil;saved.evolutionUnlocks={}
 end
end
P.persistent(game.save,true).packageUnlocks.moss_field=true
local before=doneCount;box=nil
assert(P.useFieldAltar(game,'moss_field',nil,done,{request=request}));picker.onSwitch(mon)
assert(requests==1 and doneCount==before+1 and box==nil,'successful evolution changed')
assert(P.useFieldAltar(game,'moss_field',nil,done,{request=request}));picker.onCancel();assert(doneCount==before+2)
assert(game.save.inventory.POTION==3 and #game.save.party==0)
print('Field feedback: EN/DE gates, wrong species, success, cancel, callback and inventory preservation PASS')

for _,requestFailure in ipairs({
 function(_,_,_,callback) callback();return nil end,
 function()return false end,
 function()error('provider declined')end,
}) do
 local before=doneCount;box=nil
 P.useFieldAltar(game,'moss_field',nil,done,{request=requestFailure});picker.onSwitch(mon)
 assert(box and doneCount==before,'declined request silently released the field interaction')
 box.onDone();assert(doneCount==before+1)
end
local callback;local before=doneCount;box=nil
P.useFieldAltar(game,'moss_field',nil,done,{request=function(_,_,_,cb)callback=cb;return 'LEAFEON'end});picker.onSwitch(mon)
assert(box==nil and doneCount==before,'field completed before evolution')
callback();callback();assert(doneCount==before+1,'completion delivered more than once')
print('Field request decline and asynchronous completion: PASS')
