-- One read-only decision for Castform's temporary battle type and art owner.
-- Callers supply the existing effective-weather and bound-ability services.
return function(opts)
  local base=assert(opts.species.byKey['dex:351'])
  local forms={sun={key='form:10013',type='FIRE'},
    rain={key='form:10014',type='WATER'},hail={key='form:10015',type='ICE'}}
  for _,row in pairs(forms)do
    local c=assert(opts.catalog.entries[row.key])
    assert(c.nationalDex==351 and c.isBase==false and c.types[1]==row.type)
    local p=assert(opts.art[row.key]).paths
    for _,side in ipairs({'front','back','frontShiny','backShiny','voxelFront','voxelFrontShiny'})do assert(p[side])end
  end
  local M={baseSpecies=base}
  function M.resolve(b,who)
    if not b or b.result or b.demo or b.kind=='link' or not who
        or who~=b.player and who~=b.enemy or not who.mon
        or who.mon.species~=base or who.mon.isEgg
        or who.__ascendantCrystalTransformed
        or who.mon._ascMegaForm or who.mon.ascMegaForm then return nil end
    local epoch=opts.weather.epoch(b)
    if not epoch or epoch<3 or epoch>7 then return nil end
    if opts.abilities.activeAbility(b,who)~='FORECAST' then return nil end
    local weather=opts.weather.current(b)
    local form=forms[weather]
    -- Return new values; callers cannot mutate the catalogue through this result.
    return {species=base,key=form and form.key or 'dex:351',
      type=form and form.type or 'NORMAL',weather=weather}
  end
  return M
end
