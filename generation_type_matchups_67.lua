-- Historical changes to existing matchup rows. No type/species/art import.
-- Gen II: pret/pokecrystal data/types/type_matchups.asm.
-- Gen I/V: smogon/pokemon-showdown data/mods/gen1,gen5/typechart.ts.
local M={CARD_ID='KASC-67-TYPE-MATCHUPS',OWNER='kasc.type-matchups/v1'}
local bases=setmetatable({},{__mode='k'})
local function copy(rows)
  local out={}
  for i,row in ipairs(rows)do local r={};for k,v in pairs(row)do r[k]=v end;out[i]=r end
  return out
end
function M.apply(data,epoch)
  local chart=data and data.type_chart
  if not(chart and type(chart.matchups)=='table'and type(chart.types)=='table')then return false end
  if not bases[chart]then bases[chart]=copy(chart.matchups)end
  local rows=copy(bases[chart])
  if epoch>=2 then
    local values={['GHOST>PSYCHIC_TYPE']=20,['GHOST>PSYCHIC']=20,
      ['BUG>POISON']=5,['POISON>BUG']=10,['ICE>FIRE']=5,
      ['GHOST>STEEL']=epoch>=6 and 10 or 5,['DARK>STEEL']=epoch>=6 and 10 or 5}
    local found={}
    for _,row in ipairs(rows)do
      local key=row.attacker..'>'..row.defender
      if values[key]~=nil then row.multiplier=values[key];found[key]=true end
    end
    local keys={};for key in pairs(values)do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys)do
      local a,d=key:match('^(.-)>(.-)$')
      if not found[key]and chart.types[a]and chart.types[d]then
        rows[#rows+1]={attacker=a,defender=d,multiplier=values[key]}
      end
    end
  end
  chart.matchups=rows
  -- The host keeps both an index and ordered rows. Refresh both, otherwise
  -- a settings change updates Data but damage/AI continue with cached Gen I.
  require('src.battle.TypeChart').load(data)
  return true
end
return M
