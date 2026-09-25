local stored,handler={},nil
local stack={screens={}}
function stack:push(s)self.screens[#self.screens+1]=s end
function stack:pop()return table.remove(self.screens)end
function stack:top()return self.screens[#self.screens]end
local function list(game,title,items,opts)
 return {title=title,items=items,onCancel=opts.onCancel,onChoose=opts.onChoose,
 close=function(self)assert(stack:top()==self);stack:pop()end}
end
package.loaded['src.render.TextBox']={new=function(_,text,done)return {text=text,done=done}end}
local D=dofile('hunting_club_data.lua')
local mod={save={get=function(_,k)return stored[k]end,set=function(_,k,v)stored[k]=v end},
 content={map_scripts={register=function(_,_,def)handler=def.talk.MOD_KANTO_ASCENDANT_HUNTING_CLUB end}},
 events={on=function()end},ui={ListMenu={new=list}}}
local game={stack=stack,save={inventory={},pokedex={owned={}},party={}},data={pokemon={},moves={TACKLE={name='TACKLE'}},items={RARE_CANDY={name='RARE CANDY'},MASTER_BALL={name='MASTER BALL'}}}}
for _,id in ipairs({'BOULDERBADGE','CASCADEBADGE','THUNDERBADGE','RAINBOWBADGE','SOULBADGE','MARSHBADGE','VOLCANOBADGE','EARTHBADGE'})do game.save.inventory[id]=1 end
for i,id in ipairs({'PIDGEY','RATTATA','SPEAROW'})do
 game.save.pokedex.owned[id]=true;game.data.pokemon[id]={name=id,dex=i,level1Moves={'TACKLE'}}
end
local H=dofile('hunting_club.lua')(mod,{data=D,generationRules={speciesAvailable=function()return true end,resolve=function()return {activeEpoch=1}end,moveAvailable=function()return true end},breedingData={{groups={'field'}},{groups={'field'}},{groups={'field'}}}})
local function choose(index)local m=stack:top();m.onChoose(m.items[index],m)end
local function cancel()local m=stack:pop();m.onCancel()end
local function finishText()local t=stack:pop();assert(t.text);if t.done then t.done()end end
local function noSpoilers(m)
 for _,row in ipairs(m.items)do assert(not row.label:find('SHINY') and not row.label:find('EGG') and not row.label:find('RULES'))end
end
local exited=0
H.open(game,function()exited=exited+1 end)
local m=stack:top();assert(m.items[1].label=='PIDGEY' and m.items[1].right=='+10 CP')
assert(m.items[1].help:find('Lv. 30+') and m.items[1].help:find('TACKLE'))
assert(#m.items==4);noSpoilers(m)
choose(1);assert(H.status().active and #stack.screens==1,'accept left stale menu')
assert(#stack:top().items==2,'active contract should be compact')
choose(2);assert(not H.status().active and #stack.screens==1,'pause failed to refresh')
choose(1);game.save.party={{species='PIDGEY',level=30,moves={{id='TACKLE'}}}}
choose(1);assert(stack:top().title=='SHOW POKéMON' and #stack.screens==1)
choose(1);assert(stack:top().text:find('+10 CP'));finishText()
assert(H.status().completed==1 and H.status().points==10 and #stack.screens==1)
assert(stack:top().items[1].label~='PIDGEY','completed contract remains on board')
cancel();assert(exited==1 and #stack.screens==0)
-- No future eggs/outfits/items. Affordable items appear; reached, unclaimed
-- milestone gifts keep their contents hidden even once collection is offered.
H.wardrobe={rewards=function()return {{id='OUTFIT',name='SECRET OUTFIT',required=10,cost=100}}end}
local s=H.readState();s.points=30;H.writeState(s);H.open(game)
choose(#stack:top().items);m=stack:top();assert(#m.items==1 and m.items[1].label=='RARE CANDY');noSpoilers(m)
cancel();cancel()
s=H.readState();s.points=0;for i=1,30 do s.done[D.contracts[i].id]=true end;s.eggs={['30']='PIDGEY'};H.writeState(s)
H.open(game);choose(#stack:top().items);assert(#stack:top().items==1 and stack:top().items[1].label=='COLLECT GIFT');noSpoilers(stack:top());cancel();cancel()
-- The explanation belongs to the NPC, and closing the board releases her.
local npc={facePlayer=function()end};assert(handler(game,{player={}},npc));assert(npc.frozen and stack:top().text)
assert(not stack:top().text:find('shiny') and not stack:top().text:find('EGG'))
finishText();assert(stack:top().items);cancel();assert(not npc.frozen and #stack.screens==0)
print('PASS: concise board, points/requirements, accept/pause/submit refresh, reward secrecy, NPC dialogue and clean cancellation')
-- Mira repeats the opening only until an actual acceptance, not merely a visit.
local function talkText()
 assert(handler(game,{player={}},npc))
 local text=stack:top().text;finishText();cancel();return text
end
H.writeState({})
local opening=talkText();assert(opening:find('Badges') and opening:find('\f'))
assert(talkText()==opening,'opening vanished before first acceptance')
local offer=H.offers(game)[1];assert(H.accept(game,offer.id));assert(H.pause(game))
local quip=talkText();assert(not quip:find('Badges') and not quip:find('\f'))
assert(talkText()~=quip,'Mira repeats the same quip every visit')
local saved=H.readState();assert(saved.acceptedOnce and not saved.active)
H.writeState({sealed={[offer.id]=offer}})
assert(not talkText():find('Badges'),'older paused contract triggers introduction')
H.writeState({done={[offer.id]=true}})
assert(not talkText():find('Badges'),'older completed work triggers introduction')
print('PASS: introduction lasts until acceptance; returning quips vary; pause and older saves retain familiarity')
