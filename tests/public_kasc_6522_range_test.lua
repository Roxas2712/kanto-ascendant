local Json=require('src.link.Json')
local Semver=require('src.mods.Semver')
local f=assert(io.open(assert(arg[1]),'rb'));local m=assert(Json.decode(f:read('*a')));f:close()
assert(m.version=='6.5.22')
local resolver=assert(loadfile(assert(arg[2])))()({find=function()end})
local range=resolver.approvedVersionRanges.VOXEL_ASCENDANT.range
local function allowed(v)
  local yes=false
  for _,rule in ipairs(m.exclusive.allow_packages)do
    for _,repo in ipairs(rule.repositories)do
      if repo=='Roxas2712/voxel-ascendant' and Semver.satisfies(v,rule.version)then yes=true end
    end
  end
  for _,rule in ipairs(m.conflicts)do
    local id,r=rule:match('^([^@]+)@(.+)$')
    if id=='VOXEL_ASCENDANT' and Semver.satisfies(v,r) then return false end
  end
  return yes and Semver.satisfies(v,range)
end
for _,v in ipairs({'0.1.0-rc.1','2.0.2','3.0.0-rc.12','3.0.0-rc.13','3.0.0-rc.14','3.0.0-rc.15'})do assert(allowed(v),v)end
for _,v in ipairs({'0.0.1','3.0.0-rc.11','3.0.0-rc.14.1','3.0.0-rc.15.1','3.0.0-rc.16','3.0.0','4.0.0'})do assert(not allowed(v),v)end
print('PASS KASC6.5.22 exact RC66g manifest/runtime admission; preceding public hotfixes retained')
