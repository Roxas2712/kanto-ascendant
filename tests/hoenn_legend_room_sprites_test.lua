local root=assert(arg[1]);local records={}
local function bucket(name)
 records[name]={};local t={}
 function t:get(id)return records[name][id]end
 function t:register(id,value)assert(not records[name][id]);records[name][id]=value end
 function t:patch(id,value)records[name][id]=value end
 function t:each()return pairs(records[name])end
 return t
end
local content={};for _,key in ipairs({'maps','sprites','text','text_pointers','map_scripts','encounters','map_songs','tilesets'})do content[key]=bucket(key)end
content.tilesets:register('CAVERN',{})
local indices={KA_HEVO_GROUDON_CHAMBER=1984,KA_HEVO_KYOGRE_CHAMBER=1985,KA_HEVO_RAYQUAZA_CHAMBER=1986}
local P=assert(loadfile(root..'/hoenn_legend_portals_67.lua'))()({id='kanto_ascendant',path=root,content=content},{dex={},journey={},geometry={map=function(id)return{index=indices[id],width=12,height=10,blocks={},voxelRevision=5}end}})
P.bindShared({ID='KA_HEVO_SHARED_SEALED_ANTECHAMBER',doorInteraction=function()end});assert(P.register())
for _,mon in ipairs({'GROUDON','KYOGRE','RAYQUAZA'})do
 local id='KA_HEVO_'..mon..'_CHAMBER';local d=assert(records.maps[id]);local obj=d.objects[1]
 local sprite=assert(records.sprites[obj.sprite]);assert(sprite.frames==6 and sprite.walker and sprite.trueColor and sprite.pokemonSpecies==mon)
 local f=assert(io.open(sprite.image,'rb'));local png=f:read('*a');f:close();assert(png:sub(2,4)=='PNG')
 local function u32(n)local a,b,c,d=png:byte(n,n+3);return ((a*256+b)*256+c)*256+d end
 assert(u32(17)==16 and u32(21)==96,'native frame dimensions changed')
 assert(sprite.voxelChamberImage==root..'/assets/hoenn_legend_rooms/'..mon:lower()..'_front.png')
 f=assert(io.open(sprite.voxelChamberImage,'rb'));png=f:read('*a');f:close()
 assert(png:sub(2,4)=='PNG' and u32(17)==64 and u32(21)==64,'detailed chamber image missing or wrong dimensions')
 assert(obj.x==8 and obj.y==4 and obj.passable==false and obj.text=='TEXT_KA_HEVO_'..mon..'_CAPTURE')
 assert(records.map_scripts[id].talk[obj.text]and records.map_scripts[id].talk[d.signs[1].text],'encounter/return handlers lost')
 assert(#d.warps==0 and d.signs[1].x==8 and d.signs[1].y==13)
end
print('PASS three authentic bundled legend sheets, frame dimensions and preserved encounter/return ownership')
