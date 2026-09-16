-- KASC 6.7 Hoenn finale Dex authority.
--
-- The prerequisite is every Hoenn identity #252-386 except Jirachi itself.
-- Deoxys is deliberately required.  Current-save ownership, the durable
-- Legacy lineage set, old archive Bank rows and the shared 6.7 vault are
-- merged read-only into one report; no consumer may invent another count.

return function(mod, opts)
  opts = opts or {}
  local source = assert(opts.data, "Hoenn species data missing")
  local journey = opts.journey
  local generationRules = opts.generationRules
  local D = { REQUIRED_MIN=252, REQUIRED_MAX=386, EXCLUDED="JIRACHI" }
  D.order, D.bySpecies = {}, {}
  for _, species in ipairs(source.order or {}) do
    local row = assert(source.species and source.species[species],
      "Hoenn Dex source row missing "..tostring(species))
    local dex = tonumber(row.sourceDex)
    if dex and dex >= D.REQUIRED_MIN and dex <= D.REQUIRED_MAX then
      D.bySpecies[species] = dex
      if species ~= D.EXCLUDED then D.order[#D.order+1] = species end
    end
  end
  table.sort(D.order,function(a,b)return D.bySpecies[a]<D.bySpecies[b]end)
  assert(#D.order==134,"Hoenn finale prerequisite must contain 134 species")
  assert(D.bySpecies.DEOXYS==386 and D.bySpecies.JIRACHI==385,
    "Hoenn finale endpoint identity drift")
  D.portalLegends = {
    GROUDON="KA_LEGEND_CAPTURE_GROUDON",
    KYOGRE="KA_LEGEND_CAPTURE_KYOGRE",
    RAYQUAZA="KA_LEGEND_CAPTURE_RAYQUAZA",
  }
  D.foundationOrder = {}
  for _, species in ipairs(D.order) do
    if not D.portalLegends[species] and species ~= "DEOXYS" then
      D.foundationOrder[#D.foundationOrder + 1] = species
    end
  end
  assert(#D.foundationOrder == 130,
    "Hoenn portal foundation must contain 130 species")

  local function copy(value,seen)
    if type(value)~="table"then return value end
    seen=seen or{};if seen[value]then return seen[value]end
    local out={};seen[value]=out
    for k,v in pairs(value)do out[copy(k,seen)]=copy(v,seen)end
    return out
  end

  local function bucket(save,create)
    if type(save)~="table"then return nil end
    if type(save.modData)~="table"then
      if not create then return nil end
      save.modData={}
    end
    local out=save.modData[mod.id]
    if type(out)~="table"then
      if not create then return nil end
      out={};save.modData[mod.id]=out
    end
    out.hevo_persistent = type(out.hevo_persistent) == "table"
      and out.hevo_persistent or (create and {} or nil)
    if not out.hevo_persistent then return nil end
    out.hevo_persistent.hoennDexOwned=
      type(out.hevo_persistent.hoennDexOwned)=="table"
      and out.hevo_persistent.hoennDexOwned or (create and {} or nil)
    return out.hevo_persistent
  end

  local function accept(set,species)
    species=type(species)=="string"and species:upper()or nil
    if species and D.bySpecies[species] then set[species]=true end
  end

  local function addMons(set,rows)
    for _,row in ipairs(type(rows)=="table"and rows or{})do
      local mon=type(row)=="table"and(row.mon or row)or nil
      accept(set,mon and mon.species)
    end
  end

  local function profile()
    if journey and type(journey.profile)=="function"then
      local ok,value=pcall(journey.profile)
      if ok and type(value)=="table"then return value end
    end
    return{}
  end

  local function scan(game)
    local set={}
    local save=game and game.save or{}
    local localPersistent=bucket(save,false)
    for species,owned in pairs(localPersistent
        and localPersistent.hoennDexOwned or{})do
      if owned==true then accept(set,species)end
    end
    local legacyProfile=profile()
    for species,owned in pairs(legacyProfile.hoennDexOwned or{})do
      if owned==true then accept(set,species)end
    end
    for species,owned in pairs(save.pokedex and save.pokedex.owned or{})do
      if owned==true then accept(set,species)end
    end
    addMons(set,save.party)
    for _,box in ipairs(save.boxes or{})do addMons(set,box)end

    local archive=journey and journey.archive
    if archive and type(archive.availableMons)=="function"then
      local ok,rows=pcall(archive.availableMons,save)
      if ok then addMons(set,rows)end
    end
    local bridge=type(opts.bankBridge)=="function"and opts.bankBridge()
      or opts.bankBridge
    if bridge and type(bridge.load)=="function"then
      local ok,vault=pcall(bridge.load,game)
      if ok and type(vault)=="table"then addMons(set,vault.pokemon)end
    end
    return set,legacyProfile
  end

  local function generationReady(game)
    return not generationRules
      or type(generationRules.shouldUseEpoch)~="function"
      or generationRules.shouldUseEpoch(game,3,false)==true
  end

  function D.report(game)
    local owned,legacyProfile=scan(game)
    local missing={};local count=0
    for _,species in ipairs(D.order)do
      if owned[species]then count=count+1 else missing[#missing+1]=species end
    end
    local paths=type(legacyProfile.completedPaths)=="table"
      and legacyProfile.completedPaths or{}
    local profilesComplete=paths.red==true and paths.blue==true
      and paths.green==true
    local complete=#missing==0
    local foundationMissing={}
    for _,species in ipairs(D.foundationOrder)do
      if not owned[species]then foundationMissing[#foundationMissing+1]=species end
    end
    local localPersistent=bucket(game and game.save,false)
    local receipts={}
    for id,value in pairs(legacyProfile.secretUnlocks or{})do
      if value==true then receipts[id]=true end
    end
    for id,value in pairs(localPersistent and localPersistent.secretUnlocks or{})do
      if value==true then receipts[id]=true end
    end
    local portalCaptures={};local allPortalCaptures=true
    for species,id in pairs(D.portalLegends)do
      portalCaptures[species]=receipts[id]==true
      if not portalCaptures[species]then allPortalCaptures=false end
    end
    local readyGeneration=generationReady(game)
    local foundationComplete=#foundationMissing==0
    return{
      required=#D.order,owned=count,missing=missing,ownedSet=copy(owned),
      complete=complete,generationReady=readyGeneration,
      profilesComplete=profilesComplete,
      foundationRequired=#D.foundationOrder,
      foundationMissing=foundationMissing,
      foundationComplete=foundationComplete,
      portalReady=foundationComplete and readyGeneration,
      portalCaptures=portalCaptures,
      allPortalCaptures=allPortalCaptures,
      birthIslandReady=foundationComplete and readyGeneration
        and profilesComplete and allPortalCaptures,
      jirachiDexReady=complete and profilesComplete and allPortalCaptures,
      deoxysOwned=owned.DEOXYS==true,jirachiExcluded=true,
    }
  end

  function D.record(game,species)
    species=type(species)=="string"and species:upper()or nil
    if not(species and D.bySpecies[species])then return false,"not-hoenn"end
    local persistent=bucket(game and game.save,true)
    if persistent.hoennDexOwned[species]==true then return false,"recorded"end
    persistent.hoennDexOwned[species]=true
    local synced=true
    if journey and type(journey.syncHevoPersistent)=="function"then
      local ok,result=pcall(journey.syncHevoPersistent,game.save)
      synced=ok and result~=false
    end
    return true,synced and"recorded"or"local-only"
  end

  function D.sync(game)
    if not(game and game.save)then return false,"save"end
    D.game = game
    local owned=scan(game)
    local persistent=bucket(game.save,true)
    local changed=false
    for species in pairs(owned)do
      if persistent.hoennDexOwned[species]~=true then
        persistent.hoennDexOwned[species],changed=true,true
      end
    end
    if changed and journey and type(journey.syncHevoPersistent)=="function"then
      pcall(journey.syncHevoPersistent,game.save)
    end
    return true,changed
  end

  if mod.events and type(mod.events.on)=="function"then
    mod.events:on("pokemon.caught",function(ev)
      local game=ev and(ev.game or ev.battle and ev.battle.game)
      local species=ev and(ev.species or ev.mon and ev.mon.species)
      if game and species then D.record(game,species)end
    end,3890)
    mod.events:on("pokemon.evolved",function(ev)
      local game=ev and(ev.game or ev.battle and ev.battle.game) or D.game
      local species=ev and(ev.toSpecies or ev.newSpecies or ev.species
        or ev.mon and ev.mon.species)
      if game and species then D.record(game,species)end
    end,3890)
    for _,event in ipairs({"save.loaded","game.ready"})do
      mod.events:on(event,function(ev)
        local game=ev and ev.game
        if game then D.sync(game)end
      end,3880)
    end
  end
  return D
end
