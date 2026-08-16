-- Original Game Boy cave piece for the Hidden Evolution Dungeon.  The
-- pulsing minor ostinato and syncopated answer evoke the uneasy, mechanical
-- cave character of later generations without copying an existing melody.
local ChipAsm = require("src.audio.ChipAsm")

return ChipAsm.song{
  tempo = 0x118,
  channels = {
    { hw=1, program={
      {duty=2},{notetype={speed=12,volume=10,fade=2}},{vibrato={delay=4,depth=2,rate=3}},
      {octave=4},{label="echo"},
      {note="D",len=3},{note="D#",len=1},{note="A",len=4},{rest=2},
      {note="G#",len=2},{note="F",len=4},{note="E",len=2},
      {octave=3},{note="B",len=4},{octave=4},{note="F",len=2},{note="D#",len=2},
      {note="D",len=6},{rest=2},
      {note="A",len=2},{note="G#",len=2},{note="F",len=4},{note="D#",len=4},
      {loop={count=0,to="echo"}},
    }},
    { hw=2, program={
      {duty=1},{notetype={speed=12,volume=7,fade=1}},
      {octave=2},{label="pulse"},
      {note="D",len=4},{rest=2},{note="A",len=2},
      {note="D#",len=4},{rest=2},{note="B",len=2},
      {note="D",len=4},{note="C",len=4},
      {octave=3},{note="D",len=2},{rest=2},{note="C",len=2},{rest=2},
      {octave=2},{note="A",len=4},{note="D",len=4},
      {loop={count=0,to="pulse"}},
    }},
  },
}
