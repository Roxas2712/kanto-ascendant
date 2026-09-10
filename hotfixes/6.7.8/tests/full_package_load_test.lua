local root=assert(os.getenv('TRACE_FIX_ROOT'));local engine=assert(os.getenv('GEN1RECOMP_DIR'))
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..(assert(os.getenv('GEN1RECOMP_TEST_DIR'), 'Set GEN1RECOMP_TEST_DIR to the engine source checkout')..'/?.lua;'..os.getenv('GEN1RECOMP_TEST_DIR')..'/?/init.lua;./?/init.lua;')..package.path
local T=require('tests.modkit')
local Data=require('src.core.Data');Data:load()
local sink=dofile(os.getenv('TRACE_TEST_ROOT')..'/tests/headless_modkit_asset_sink.lua')(T,root,{
 derivedPrefix='save/mod-derived/kanto_ascendant/',bridgeLove=true})
local run=T.sdk.loadMod(root,{data=Data,root='/'})
assert(#run.errors==0,table.concat(run.errors,' | '))
for _,id in ipairs({'FOCUS_PUNCH','SUCKER_PUNCH','GIGA_IMPACT','BLAST_BURN','HYDRO_CANNON','FRENZY_PLANT','ROCK_WRECKER','ROAR_OF_TIME','FREEZE_SHOCK','ICE_BURN'})do
 local move=assert(Data.moves[id],id)
 assert(move.effect~='NO_ADDITIONAL_EFFECT',id..' lost its effect during full main load')
 local effect=assert(Data.move_effects[move.effect],move.effect)
 assert(effect.gate or effect.afterDamage or effect.charge,id..' missing required mechanic')
end
assert(run.loader.exports.kanto_ascendant,'missing live mod export')
print('FULL PACKAGE LOAD PASS: complete release archive and ten move effect owners')
