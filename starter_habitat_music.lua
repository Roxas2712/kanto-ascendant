-- Original looping Game Boy cues for the three starter habitat biomes.
-- Registered during content construction so normal map/battle/surf restoration
-- owns playback; no per-frame override can interrupt battles or jingles.
local ChipAsm = require('src.audio.ChipAsm')
local themes = {
  PLANT = { id='Music_KA_HabitatGrove', tempo=0x120,
    lead={'E','G','A','B','A','G','D','E'}, bass={'C','G','F','G'} },
  FIRE = { id='Music_KA_HabitatEmber', tempo=0x108,
    lead={'D','F','A','G','F','E','C','D'}, bass={'D','A','C','A'} },
  WATER = { id='Music_KA_HabitatTide', tempo=0x138,
    lead={'G','A','D','E','D','A','B','G'}, bass={'G','D','C','D'} },
}
return function(mod)
  local ids = {}
  for _, category in ipairs({'PLANT','FIRE','WATER'}) do
    local theme = themes[category]
    local lead = {{duty=2},{notetype={speed=12,volume=8,fade=2}},
      {vibrato={delay=5,depth=1,rate=3}},{octave=4},{label='lead'}}
    for _, note in ipairs(theme.lead) do
      lead[#lead+1]={note=note,len=6}; lead[#lead+1]={rest=2}
    end
    lead[#lead+1]={loop={count=0,to='lead'}}
    local bass = {{duty=1},{notetype={speed=12,volume=5,fade=2}},
      {octave=3},{label='bass'}}
    for _, note in ipairs(theme.bass) do
      bass[#bass+1]={note=note,len=12}; bass[#bass+1]={rest=4}
    end
    bass[#bass+1]={loop={count=0,to='bass'}}
    mod.content.music:register(theme.id, ChipAsm.song{
      tempo=theme.tempo, channels={{hw=1,program=lead},{hw=2,program=bass}},
    })
    ids[category]=theme.id
  end
  return ids
end
