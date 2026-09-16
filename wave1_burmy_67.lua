-- Bounded Burmy family owner. Cosmetic art addresses are NOT Pokemon IDs.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-BURMY',ready=false,pending={}}
  local rules=assert(opts.rules)
  local art=assert(opts.art)
  assert(art.schema=='kasc.burmy-cloak-art/v1')
  local species=assert(opts.species)
  local gender=assert(opts.gender)
  local registry=mod.content.pokemon
  local methods=mod.content.evolution_methods
  local method='KA_BURMY_CLOAK_LEVEL'
  local burmy=species.byKey['dex:412']
  local targets,rows={},{}
  for _,key in ipairs({'dex:413','form:10004','form:10005','dex:414'})do
    local id=species.byKey[key]
    local def=id and registry:get(id)
    if not def or def.backendOwner~=species.OWNER or def.backendKey~=key
        or def.isMega or def.isGigantamax then
      C.pending[#C.pending+1]='unavailable_target:'..key
    else targets[key]=id;rows[#rows+1]={method=method,species=id,level=20} end
  end
  local parent=burmy and registry:get(burmy)
  if burmy~='KA_GIFT_NAT_412' or not parent or parent.backendOwner~=species.OWNER
      or parent.backendKey~='dex:412' or parent.formId or #(parent.evolutions or {})~=0 then
    C.pending[#C.pending+1]='parent_owner_or_evolutions_changed'
  end
  if methods:get(method) then C.pending[#C.pending+1]='method_owner_exists' end
  local sprites,fronts=opts.sprites,opts.fronts
  if not sprites or not sprites.registerAdditionalArt or not sprites.setBurmyCloakProvider
      or not fronts or not fronts.setBurmyCloakProvider then
    C.pending[#C.pending+1]='presentation_capability_missing'
  end
  if #C.pending>0 then return C end
  for cloak,row in pairs(art.cloaks)do
    assert((cloak=='sandy' and row.sourceFormId==10034 and row.artSlot==90034)
      or (cloak=='trash' and row.sourceFormId==10035 and row.artSlot==90035))
    assert(row.pokemonId==412 and not registry:get(row.artAlias),
      'cosmetic art alias must not be a Pokemon')
  end
  assert(art.cloaks.sandy and art.cloaks.trash)
  local count,why=sprites.registerAdditionalArt(art.payload)
  if count~=2 then C.pending[1]='art_registration:'..tostring(why);return C end
  function C.artFor(mon,requestedSpecies)
    if not C.ready or not mon or requestedSpecies~=burmy or mon.species~=burmy then return nil end
    return art.cloaks[rules.read(mon)]
  end
  sprites.setBurmyCloakProvider(C.artFor)
  fronts.setBurmyCloakProvider(C.artFor)
  local function exact(evo)
    if type(evo)~='table' or evo.method~=method or evo.level~=20
        or evo.item or evo.move or evo.partySpecies then return false end
    for _,row in ipairs(rows)do if row.species==evo.species then return true end end
    return false
  end
  methods:register(method,{
    check=function(game,mon,evo,trigger)
      if not C.ready or not exact(evo) then return false end
      local key=rules.evolutionKey(mon,gender.getMonGender(mon,game),trigger)
      return key and targets[key]==evo.species or false
    end,
    describe=function()
      return opts.i18n.text('Level 20; gender and cloak','Level 20; Geschlecht und Umhang')
    end,
  })
  registry:patch(burmy,{evolutions=rows})
  local previous=species.giftEvolutionAllowed
  species.giftEvolutionAllowed=function(game,mon,evo)
    if C.ready and mon and mon.species==burmy and exact(evo) and rules.read(mon) then
      local archive=mod.exports and mod.exports.eventArchive
      local valid,_,profile
      if archive then valid,_,profile=archive.battleCompatibleGift(mon) end
      if valid and profile and profile.species==burmy and profile.backendKey=='dex:412'
          and not profile.formId and not profile.megaFormId and not profile.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  local caveTilesets={CAVERN=true,KA_MOLTRES_VOLCANO_67=true,
    KA_HABITAT_STONE=true,KA_HABITAT_MYSTIC=true}
  function C.worldTerrain(game)
    local ow=game and game.overworld
    local map=ow and ow.map
    local def=map and map.def
    if not def or type(def.tileset)~='string' then return nil end
    if caveTilesets[def.tileset] then return 'cave' end
    local p=ow.player
    if p and type(p.cellX)=='number' and type(p.cellY)=='number' then
      if p.surfing and map.isWaterCell and map:isWaterCell(p.cellX,p.cellY) then return 'water' end
      if map.isGrassCell and map:isGrassCell(p.cellX,p.cellY) then return 'grass' end
    end
    if def.tileset=='FOREST' or def.tileset=='KA_HOENN_SKY_67' then return 'grass' end
    if def.outdoor==true or def.outdoor==nil and def.tileset=='OVERWORLD' then return 'plain' end
    -- Unknown private tilesets require an explicit outdoor/indoor authority.
    if def.outdoor==false or game.data and game.data.tilesets
        and game.data.tilesets[def.tileset] and not def.tileset:match('^KA_') then return 'building' end
    return nil
  end
  local battles=setmetatable({},{__mode='k'})
  mod.events:on('battle.started',function(ev)
    local b=ev and ev.battle
    local game=b and b.game
    if not C.ready or not game then return end
    local state=rules.begin(ev.kind,C.worldTerrain(game),game.save and game.save.party,
      {link=b.kind=='link',safari=b.safari,demo=b.demo,frontier=b.frontier,palPark=b.palPark})
    battles[b]=state
    rules.participate(state,b.player)
  end,700)
  mod.events:on('battle.battler_switched',function(ev)
    if ev then rules.participate(battles[ev.battle],ev.battler) end
  end,700)
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle
    if not b then return end
    local game=b.game
    rules.finish(battles[b],game and game.save and game.save.party,ev.skipped)
    battles[b]=nil
  end,700)
  mod.events:on('pokemon.evolved',function(ev)
    if not ev or ev.fromSpecies~=burmy or ev.via~=method or not ev.mon
        or ev.mon.species~=ev.toSpecies then return end
    local accepted=false
    for _,id in pairs(targets)do if id==ev.toSpecies then accepted=true end end
    if not accepted then return end
    local def=registry:get(ev.toSpecies)
    ev.mon.formId=def.formId;ev.mon.form=def.formId
    ev.mon.baseSpecies=def.baseSpecies
    ev.mon[rules.FIELD]=nil
  end,900)
  function C.staticSprite(path,requested,ctx)
    -- Battle selection must reach the shared controller so its front/rear
    -- geometry ownership markers are populated, even for a static cloak.
    if not ctx or ctx.kind=='battle' or path~=requested then return nil end
    local row=C.artFor(ctx.mon,ctx.species)
    if not row then return nil end
    local side=ctx.side=='back' and 'back' or 'front'
    if requested~=(side=='back' and parent.spriteBack or parent.spriteFront) then return nil end
    local shiny=mod.exports and mod.exports.shinySystem
    local useShiny=shiny and shiny.isShiny(ctx.mon)
      and not (mod.options and mod.options:get('shiny_effects')==false)
    return mod.path..'/'..row.paths[side..(useShiny and 'Shiny' or '')]
  end
  C.ready=true
  return C
end
