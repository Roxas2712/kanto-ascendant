-- Gen-3-only composition; the previous repair data remains a rollback source.
return function(previous, selected)
  assert(type(previous)=='table' and type(selected)=='table')
  assert(selected.schema=='kasc.gen3-crystal/v1')
  local count=0
  for key,row in pairs(selected.entries or {})do
    local dex=tonumber(key)
    assert(dex and dex%1==0 and dex>=252 and dex<=386,'outside Gen 3')
    assert(type(row)=='table' and type(row.native)=='table')
    for _,side in ipairs({'front','back','frontShiny','backShiny'})do
      local art=row.native[side]
      assert(type(art)=='table' and type(art.durations)=='table' and #art.durations>=(side:sub(1,5)=='front' and 2 or 1),
        'missing Gen 3 front animation or rear portrait')
    end
    count=count+1
  end
  assert(count==135,'incomplete Gen 3 selection')
  local result={schema=previous.schema,entries={}}
  for key,row in pairs(previous.entries or {})do result.entries[key]=row end
  for key,row in pairs(selected.entries)do result.entries[key]=row end
  return result
end
