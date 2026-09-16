-- Bounded rear replacement before additive backend species registration.
-- No existing animation, front, form, protected owner or published asset edit.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-BACKEND-REARS',selected={},pending={}}
  local function png48(path)
    if type(path)~='string' or not path:match('^assets/wave1_backend_rears_67/%d+/[a-z]+/001%.png$') then return false end
    local raw=mod:read(path)
    return type(raw)=='string' and raw:sub(1,8)=='\137PNG\r\n\26\n'
      and raw:sub(13,24)=='IHDR'..string.char(0,0,0,48,0,0,0,48)
  end
  for _,dex in ipairs({412,413,414,415,416,427,428,447,448,527,528,541,542,554,555,570,571,627,628,665,666,674,675,696,697,698,699,705,734,739,740,757,758,790,884,935,936,937,974,975,1018}) do
    local key='dex:'..dex
    local row=opts.art[key]
    local selected=opts.selected[tostring(dex)]
    local old='assets/backend_national_catalog_67/battle/'..dex..'/'
    local new='assets/wave1_backend_rears_67/'..dex..'/'
    if row and row.key==key and row.paths and selected
        and selected.back==new..'normal/001.png' and selected.backShiny==new..'shiny/001.png'
        and row.paths.back==old..'back.png' and row.paths.backShiny==old..'backShiny.png'
        and png48(selected.back) and png48(selected.backShiny) then
      row.paths.back=selected.back;row.paths.backShiny=selected.backShiny
      row.animations=row.animations or {}
      for _,side in ipairs({'back','backShiny'}) do
        if not row.animations[side] then
          row.animations[side]={root=selected[side]:gsub('/001%.png$',''),
            durations={1000},animated=false,scale=1}
        end
      end
      C.selected[#C.selected+1]=key
    else C.pending[#C.pending+1]={key=key,reason='missing_or_changed_source'} end
  end
  return C
end
