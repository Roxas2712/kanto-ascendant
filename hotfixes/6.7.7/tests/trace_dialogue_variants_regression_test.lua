local root=assert(os.getenv('TRACE_FIX_ROOT'))
local engine=assert(os.getenv('GEN1RECOMP_DIR'))
local fixtures=assert(os.getenv('GEN1RECOMP_TEST_DIR'))
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..fixtures..'/?.lua;'..fixtures..'/?/init.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local data=T.fixtures.fresh()
data.font=dofile(fixtures..'/data/generated/font.lua')
local Font=require('src.render.Font');Font.load(data)
local TextBox=require('src.render.TextBox')
local f=assert(io.open(root..'/legacy_wanderers.lua'));local source=f:read('*a');f:close()
local classes={};for id in source:gmatch('OPP_[A-Z0-9_]+')do classes[id]=true end
classes.OPP_UNKNOWN=true
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local previews={}
for _,lang in ipairs({'en','de'})do
 local mod={events={on=function()end}}
 local P=dofile(root..'/hoenn_trace_presentation_67.lua')(mod,{i18n={text=function(en,de)return lang=='de'and de or en end}})
 for class in pairs(classes)do
  local seen,texts={},{}
  for i=1,1000 do
   local battle={oppClass=class,trainer={name='WANDERER'},ascendantLegacyToken='voice:'..i,
    ascendantLegacyWanderer=true,kaHoennIntroductionResult={introduced=true,family='RALTS',mapId='ROUTE_24',
     habitat={map='ROUTE_24',terrain='grass',en='ROUTE 24',de='ROUTE 24'}}}
   local _,_,index=P.dialogueChoice(battle)
   if not seen[index]then
    local text=P.announcement(battle,battle.kaHoennIntroductionResult)
    check(text:find('RALTS',1,true)and text:find('ROUTE 24',1,true)and text:find('1-50',1,true),'every variant retains species/route/guarantee')
    check(text:find(lang=='de'and 'Gras'or'grass',1,true),'every route variant names terrain')
    check(not texts[text],'six distinct full texts per trainer class')
    local pages=TextBox.paginate(text,18)
    for _,page in ipairs(pages)do for _,line in ipairs(page)do
      check(Font.width(line)<=18*8,'native dialogue pagination does not overflow')
    end end
    texts[text]=true;seen[index]=true
    if class=='OPP_HIKER'or class=='OPP_SCIENTIST'or class=='OPP_YOUNGSTER'then
     previews[#previews+1]=lang..' / '..class..' / '..index..'\n'..text:gsub('\f','\n---\n')
    end
   end
  end
  local count=0;for _ in pairs(seen)do count=count+1 end
  check(count==6,'all six variants reachable for '..class)
 end
 -- Adjacent presentations of the same class cannot repeat a variant, even
 -- if two deterministic token hashes collide. No gameplay RNG is consumed.
 local battle={oppClass='OPP_HIKER',ascendantLegacyWanderer=true,ascendantLegacyToken='same',
  kaHoennIntroductionResult={introduced=true,family='CORPHISH',mapId='SEAFOAM_ISLANDS_B2F',
   habitat={map='SEAFOAM_ISLANDS_B2F',terrain='indoor',en='SEAFOAM ISLANDS B2F',de='SEESCHAUMINSELN UG2'}}}
 local last
 for i=1,12 do
  check(P.captureAnnouncement({battle=battle,result='win'}),'capture succeeds')
  check(P.pending.text~=last,'adjacent same-class dialogue does not repeat')
  check(not P.pending.text:lower():find('grass')and not P.pending.text:lower():find('gras'),'cave variants never send player into grass')
  last=P.pending.text
 end
end
local f=assert(io.open(root..'/dialogue-preview.txt','w'));f:write(table.concat(previews,'\n\n'));f:close()
print('DIALOGUE VARIANTS PASS: '..checks..' checks, 49 known classes + fallback, both languages, native paginator')
