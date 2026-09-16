-- W1 visual selection: keep Original static, but use the already bundled
-- identity-checked Neo rear master instead of a devamped silhouette.
-- Munchlax's mismatched purple normal front also uses its matching Neo frame.
-- No bitmap changes, animation registration or global scale.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-STATIC-REARS',selected={},pending={}}
  local approved={[349]='FEEBAS',[350]='MILOTIC',[366]='CLAMPERL',
    [367]='HUNTAIL',[368]='GOREBYSS',[406]='BUDEW',[433]='CHINGLING',[446]='MUNCHLAX'}
  local authoredApproved={[265]='WURMPLE',[266]='SILCOON',[267]='BEAUTIFLY',
    [268]='CASCOON',[269]='DUSTOX',[271]='LOMBRE',[272]='LUDICOLO',[274]='NUZLEAF',
    [275]='SHIFTRY',[290]='NINCADA',[291]='NINJASK',[292]='SHEDINJA',
    [298]='AZURILL',[300]='SKITTY',[301]='DELCATTY'}
  for runtimeDex,row in pairs(assert(opts.data)) do
    local dex=tonumber(row.sourceDex)
    local authored=authoredApproved[dex] and row.species==authoredApproved[dex]
    if authored or approved[dex] and row.species==approved[dex] then
      local old='assets/non_crystal_pixel_2d_67/gen2ified/'
      local neo=opts.neo[tostring(dex)] or opts.neo[dex]
      if authored then
        local native=opts.authored and opts.authored.native or {}
        neo=native[tostring(runtimeDex)] or native[runtimeDex]
      end
      local paths,valid={},row.provider=='jphyper-gen2ified-2d'
      if not authored then valid=valid and neo and neo.species==row.species end
      if authored then
        valid=valid and neo and neo.species==row.species and neo.sourceDex==dex
      end
      local sides=dex==446 and {'back','backShiny','front','frontShiny'} or {'back','backShiny'}
      for _,side in ipairs(sides) do
        local variant=side:find('Shiny',1,true) and 'shiny' or 'normal'
        local axis=side:find('front',1,true) and 'front' or 'back'
        local root='assets/neo_crystal_2d_67/'..axis..'/'..variant..'/'..dex
        if authored then
          root='assets/neo_crystal_2d_67/authored/nuuk/'..dex..'/'..axis..'/'..variant
        end
        local source=neo and neo[side]
        paths[side]=root..'/001.png'
        valid=valid and row[side]==old..side..'/'..dex..'.png'
          and source and source.root==root and mod:read(paths[side])~=nil
      end
      if valid then
        C.selected[#C.selected+1]={dex=dex,species=row.species,
          previousBack=row.back,previousBackShiny=row.backShiny,
          back=paths.back,backShiny=paths.backShiny,
          previousFront=paths.front and row.front,previousFrontShiny=paths.front and row.frontShiny,
          front=paths.front,frontShiny=paths.frontShiny}
        row.back,row.backShiny=paths.back,paths.backShiny
        if paths.front then row.front,row.frontShiny=paths.front,paths.frontShiny end
        row.rearLayout='upper32-of-48'
        row.rearProvider='gen2-neo-static-frame'
      else
        C.pending[#C.pending+1]={dex=dex,reason='source_missing_or_foreign_owner'}
      end
    end
  end
  return C
end
