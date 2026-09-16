-- Persistent Gmax-factor ownership is separate from temporary battle state.
return function(opts)
  local C={CARD_ID='KASC-67-BACKEND-GIGANTAMAX',byKey={},pending={},
    activationReady=false,activationPending='battle_controller_and_max_move_effects'}
  C.maxMoveFacts=assert(opts.metadata.moves)
  for key,meta in pairs(assert(opts.metadata).entries)do
    local row=assert(opts.catalog.entries[key])
    local species=opts.species.byKey[meta.baseKey]
    local art=opts.art[key]
    local ready=species and art and art.paths
    for _,side in ipairs({'front','back','frontShiny','backShiny','voxelFront','voxelFrontShiny'})do
      local path=art and art.paths and art.paths[side]
      ready=ready and type(path)=='string' and path:sub(1,7)=='assets/'
        and not path:find('..',1,true)
        and (opts.read(path)~=nil or opts.declaredImage and opts.declaredImage(path)==true)
    end
    if ready then
      C.byKey[key]={id='BACKEND_GMAX_'..row.pokeapiId,sourceKey=key,
        species=species,baseKey=meta.baseKey,signatureMove=meta.signatureMove,art=art}
    else C.pending[key]=species and 'missing_art' or 'missing_base_owner' end
  end
  function C.profile(mon)
    local factor=type(mon)=='table' and mon._kascGigantamax67
    if type(factor)~='table' or factor.schema~='kasc.gigantamax-factor/v1' then return nil end
    local row=C.byKey[factor.sourceKey]
    if row and row.id==factor.formId and row.species==mon.species
        and factor.baseSpecies==mon.species then return row end
  end
  return C
end
