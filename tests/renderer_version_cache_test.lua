local engine=assert(os.getenv('QA_ENGINE_ROOT'))
local S=assert(loadfile(engine..'/src/mods/Semver.lua'))()
local parses,checks=0,0
local parse,satisfies=S.parse,S.satisfies
S.parse=function(...)parses=parses+1;return parse(...)end
S.satisfies=function(...)checks=checks+1;return satisfies(...)end
package.loaded['src.mods.Semver']=S
local actual=assert(loadfile('voxel_renderer_compat.lua'))()
local reference=assert(loadfile(assert(os.getenv('QA_COMPAT_REFERENCE'))))()
local probes=0
local function exported(version)
 return {apiVersion=1,version=version,renderer={id='VOXEL_ASCENDANT',version=version,pipeline='voxel',cameraProfile='orbit-only'},
  capabilities={voxelWorld=true,wallDecals=1,diskCache=false,stadium=false,vr=false,battleCards={'MAP','DISCS'}},
  lib={require=function()probes=probes+1;return nil end}}
end
local calls=0;local live={id='VOXEL_ASCENDANT',version='3.0.4',exports=exported('3.0.4')}
local owner={find=function(id)calls=calls+1;if id=='VOXEL_ASCENDANT'then return live end end}
local R=actual(owner)
assert(R.find(owner)==live)
local oldParses,oldChecks=parses,checks;local oldProbes=probes
for i=1,1000 do assert(R.find(owner)==live)end
assert(parses==oldParses and checks==oldChecks,'reparsed stable admission')
assert(probes-oldProbes==1000 and calls==4004,'live discovery/capability probe bypassed')
live.exports.capabilities.wallDecals=0;assert(R.find(owner)==nil,'stale capability admitted')
live.exports.capabilities.wallDecals=1
live.github='wrong/repo';assert(R.find(owner)==nil,'stale provenance admitted');live.github=nil
local originalRequire=live.exports.lib.require
live.exports.lib.require=function()return{}end;assert(R.find(owner)==nil,'private authority exposed')
live.exports.lib.require=originalRequire
R.approvedVersionRanges.VOXEL_ASCENDANT.range='<1.0.0';assert(R.find(owner)==nil,'policy change ignored')
R.approvedVersionRanges.VOXEL_ASCENDANT.range='>=3.0.0';assert(R.find(owner)==live)
live=nil;assert(R.find(owner)==nil,'unloaded renderer retained')
local a,b=actual(),reference()
local versions={'0.0.1','0.1.0-rc.1','0.1.1','3.0.0-rc.12','3.0.0-rc.13','3.0.0-rc.15.1','3.0.4','4.0.0','bad','3.0.4+build'}
for i=1,100 do versions[#versions+1]='3.0.'..i end -- exceed the bounded cache
for repeatPass=1,2 do
 for _,version in ipairs(versions)do
  local ex=exported(version)
  for _,range in ipairs{'>=0.1.0-rc.1 <3.0.0-0 || >=3.0.0-rc.15.1','<1.0.0','>=3.0.0','invalid-range',''}do
   a.approvedVersionRanges.VOXEL_ASCENDANT.range=range;b.approvedVersionRanges.VOXEL_ASCENDANT.range=range
   local x,id,why=a.resolve({VOXEL_ASCENDANT=ex});local y,j,reason=b.resolve({VOXEL_ASCENDANT=ex})
   assert(x==y and id==j and why==reason,'admission mismatch: '..version..' / '..range)
  end
 end
end
print('PASS renderer version cache: 1000 stable lookups without reparsing; live discovery, capabilities, provenance, private-module rejection, unload, changed policy and 1100 reference comparisons')
