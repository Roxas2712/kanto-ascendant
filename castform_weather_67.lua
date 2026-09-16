-- Temporary Castform presentation; saved Pokemon identities never change.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local C={OWNER='kasc.castform-weather/v1',ready=false}
  local selection=opts.selection(opts)
  local aliases,active={},setmetatable({},{__mode='k'})
  local states=setmetatable({},{__mode='k'})
  local rosters=setmetatable({},{__mode='k'})
  local payload={schema='kasc.backend-gift-art/v1',entries={}}
  for _,id in ipairs({10013,10014,10015})do
    local key='form:'..id;assert(opts.art[key])
    local root='assets/sprite_repair_67/gen3-forms/'..id..'/'
    local p={front=root..'front/normal/001.png',frontShiny=root..'front/shiny/001.png',
      back=root..'back/normal/001.png',backShiny=root..'back/shiny/001.png',
      voxelFront=root..'voxel/normal/001.png',voxelFrontShiny=root..'voxel/shiny/001.png'}
    local alias='KA_GIFT_CASTFORM_WEATHER_'..id
    local slot=86000+id-10000
    aliases[key]={artAlias=alias,artSlot=slot,sourceFormId=id,animated=true}
    local timing=({[10013]={1800,360,1200},[10014]={1400,180,180,900},[10015]={1000,200,200,200,1000}})[id]
    local function track(side,variant)return {root=root..side..'/'..variant,durations=timing,animated=true,scale=1}end
    payload.entries[tostring(slot)]={species=alias,heightM=0.3,voxelSize=64,
      pixel={front=p.front,frontShiny=p.frontShiny,back=p.back,backShiny=p.backShiny,
        preferPixel2D=true,rearLayout='upper32-of-48'},
      fallback={front=p.voxelFront,frontShiny=p.voxelFrontShiny,scale=1},
      native={front=track('front','normal'),frontShiny=track('front','shiny')},
      voxel={variants={normal=track('voxel','normal'),shiny=track('voxel','shiny')}}}
  end
  assert(opts.sprites.registerAdditionalArt(payload)==3,'Castform form art registration failed')
  function C.artFor(mon,species)
    if mon and species==selection.baseSpecies and mon.species==species then return active[mon] end
  end
  opts.sprites.setCastformProvider(C.artFor)
  opts.fronts.setCastformProvider(C.artFor)
  local function refresh(b,who)
    opts.sprites.selected[who.mon]=nil
    who.__ascendantCrystalAnimation=nil
    who.sprite=Battle.makeBattler(b.data,who.mon,who==b.player,b.game and b.game.save).sprite
  end
  function C.sync(b)
    if not C.ready or not b or not b.player or not b.enemy then return end
    local prior=rosters[b] or {}
    for _,who in ipairs(prior)do
      if who~=b.player and who~=b.enemy then
        local old=states[who];if old then active[old.mon]=nil;states[who]=nil end
      end
    end
    rosters[b]={b.player,b.enemy}
    for _,who in ipairs({b.player,b.enemy})do
      local old=states[who]
      if old and old.mon~=who.mon then active[old.mon]=nil;old=nil;states[who]=nil end
      local row=selection.resolve(b,who)
      if row then
        if not old or old.key~=row.key then
          active[who.mon]=aliases[row.key]
          who.curTypes={row.type}
          states[who]={mon=who.mon,key=row.key}
          if old or row.key~='dex:351' then refresh(b,who)end
        end
      elseif old then
        active[old.mon]=nil;states[who]=nil
        if who.mon.species==selection.baseSpecies and not who.__ascendantCrystalTransformed
            and not who.mon._ascMegaForm and not who.mon.ascMegaForm and not b.result then
          who.curTypes={'NORMAL'};refresh(b,who)
        end
      end
    end
  end
  function C.clear(b)
    for _,who in ipairs(rosters[b] or {})do
      local old=states[who];if old then active[old.mon]=nil;states[who]=nil end
    end
    rosters[b]=nil
    for _,who in ipairs({b and b.player,b and b.enemy})do
      local old=states[who]
      if old then active[old.mon]=nil;states[who]=nil end
    end
  end
  local function pack(...)return {n=select('#',...),...}end
  local function wrap(name,before,after)
    local original=assert(Battle[name])
    Battle[name]=function(b,...)
      if before then before(b)end
      local result=pack(original(b,...))
      if after then after(b)end
      return unpack(result,1,result.n)
    end
  end
  wrap('update',C.sync,C.sync)
  wrap('performMove',C.sync,C.sync)
  wrap('resumeCheckpoint',nil,C.sync)
  wrap('finish',C.clear,nil)
  for _,name in ipairs({'set','abilityChanged'})do
    local original=assert(opts.weather[name])
    opts.weather[name]=function(b,...)
      local result=pack(original(b,...));C.sync(b);return unpack(result,1,result.n)
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascForecastOwner67=C.OWNER})
  C.ready=true
  return C
end
