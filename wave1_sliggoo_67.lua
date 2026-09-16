-- PokeAPI evolution row 358: ordinary Sliggoo -> Goodra, level 50 in
-- overworld rain. Gen7 additionally accepts overworld fog. Battle weather
-- and presentation-only sky overrides are deliberately not consulted.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-SLIGGOO',ready=false,pending={}}
  local S=assert(opts.species);local reg=mod.content.pokemon
  local method='KA_WAVE1_RAIN_LEVEL'
  local ids,defs={},{}
  for _,dex in ipairs({704,705,706})do
    local key='dex:'..dex;local id=S.byKey[key];local def=id and reg:get(id)
    ids[dex],defs[dex]=id,def
    if id~='KA_GIFT_NAT_'..dex or not def or def.backendOwner~=S.OWNER
        or def.backendKey~=key or def.sourceDex~=dex or def.form or def.formId
        or def.baseSpecies or def.isMega or def.isGigantamax then
      C.pending[#C.pending+1]='identity:'..dex
    end
  end
  local birth=defs[704] and defs[704].evolutions or {}
  if #birth~=1 or birth[1].method~='KA_BACKEND_LEVEL' or birth[1].level~=40
      or birth[1].species~=ids[705] or birth[1].item then
    C.pending[#C.pending+1]='goomy_chain'
  end
  if defs[705] and #(defs[705].evolutions or {})>0 then C.pending[#C.pending+1]='existing_edges'end
  if mod.content.evolution_methods:get(method)then C.pending[#C.pending+1]='method_owner'end
  if not opts.renderer or type(opts.renderer.resolve)~='function'then
    C.pending[#C.pending+1]='weather_boundary'
  end
  if not opts.rules or type(opts.rules.resolve)~='function'then
    C.pending[#C.pending+1]='rules_boundary'
  end
  if #C.pending>0 then return C end
  local function member(game,mon)
    local n=0
    for _,m in ipairs(game and game.save and game.save.party or {})do if m==mon then n=n+1 end end
    return n==1
  end
  local function exact(mon,evo)
    return type(mon)=='table' and mon.species==ids[705]
      and not mon.form and not mon.formId and not mon.baseSpecies
      and not mon.cosmeticForm and not mon.cosmeticFormId
      and not mon._ascMegaForm and not mon.ascMegaForm
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and type(mon.level)=='number' and mon.level==math.floor(mon.level)
      and mon.level>=50 and mon.level<=100
      and type(evo)=='table' and evo.method==method and evo.species==ids[706]
      and evo.level==50 and not evo.item and not evo.move and not evo.partySpecies
  end
  function C.fieldWeather(game)
    local map=game and game.overworld and game.overworld.map
    if type(map)~='table' or type(map.def)~='table' then return nil,'map_unavailable'end
    -- Only the admitted renderer's public API. Never inspect game.mods,
    -- loader internals or private Weather modules, nor cache rain across maps.
    local ok,exports,id=pcall(opts.renderer.resolve)
    if not ok or id~='VOXEL_ASCENDANT' or type(exports)~='table' then
      return nil,'weather_unavailable'
    end
    local weather=exports.weather
    if type(weather)~='table' or weather.apiVersion~=1 or type(weather.mode)~='function'then
      return nil,'weather_unavailable'
    end
    local read,mode=pcall(weather.mode,map)
    if not read or type(mode)~='string'then return nil,'weather_unavailable'end
    -- Public mode() already owns indoor/outdoor classification, including
    -- Safari/forest exceptions. AUTO and explicitly selected field weather
    -- both count; sky recolouring and Rain Dance do not change this API.
    return mode
  end
  mod.content.evolution_methods:register(method,{
    check=function(game,mon,evo,trigger)
      if not(C.ready and exact(mon,evo) and member(game,mon)
          and mon.item~='EVERSTONE' and mon.heldItem~='EVERSTONE'
          and not(mon.item and mon.heldItem and mon.item~=mon.heldItem)
          and trigger and trigger.kind=='levelup')then return false end
      local mode=C.fieldWeather(game)
      if mode=='rain' or mode=='storm'then return true end
      local rules=opts.rules.resolve(game)
      return mode=='fog' and rules and rules.activeEpoch==7 or false
    end,
    describe=function()return opts.i18n.text(
      'Level up from 50 in field rain/storm (Gen7: also fog). Not Rain Dance.',
      'Levelaufstieg ab 50 bei Feldregen/Gewitter (Gen7: auch Nebel). Kein Regentanz.')end,
  })
  reg:patch(ids[705],{evolutions={{method=method,species=ids[706],level=50}}})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if C.ready and exact(mon,evo) and member(game,mon) and archive then
      local valid,_,p=archive.battleCompatibleGift(mon)
      if valid and p and not p.formId and not p.baseSpecies
          and not p.megaFormId and not p.gigantamaxFormId then
        for _,dex in ipairs({704,705})do
          if p.backendKey=='dex:'..dex and p.species==ids[dex]then return true end
        end
      end
    end
    return previous and previous(game,mon,evo) or false
  end
  C.ready=true;C.ids=ids;C.method=method;return C
end
