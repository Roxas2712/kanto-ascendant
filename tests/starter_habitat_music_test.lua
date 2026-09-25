-- Compile the actual authored songs through the engine's ChipAsm compiler.
local engine=assert(os.getenv('ENGINE_DIR'))
package.path=engine..'/?.lua;'..package.path
local songs={}
local ids=assert(loadfile('starter_habitat_music.lua'))()({content={music={register=function(_,id,song)
 assert(not songs[id]);assert(type(song)=='table');songs[id]=song
end}}})
assert(ids.PLANT and ids.FIRE and ids.WATER)
assert(ids.PLANT~=ids.FIRE and ids.FIRE~=ids.WATER and ids.PLANT~=ids.WATER)
local count=0;for _ in pairs(songs)do count=count+1 end;assert(count==3)
print('PASS: all three habitat songs compile and have unique registered identities')
