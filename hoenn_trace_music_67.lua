-- Original Game Boy-style cue for KASC's optional Hoenn trace presentation.
-- It is deliberately code-native: no external audio file or third-party
-- melody enters the release package.

return function(mod)
  local ChipAsm = require("src.audio.ChipAsm")
  local M = { id = "Music_KA_HoennTrace67" }
  M.definition = ChipAsm.song{
    tempo = 0x108,
    channels = {
      { hw=1, program={
        {duty=2},{notetype={speed=6,volume=10,fade=2}},
        {vibrato={delay=3,depth=2,rate=4}},{octave=4},{label="lead"},
        {note="G",len=2},{note="A",len=2},{octave=5},{note="C",len=4},
        {note="D",len=2},{note="C",len=2},{octave=4},{note="A",len=4},
        {note="E",len=2},{note="G",len=2},{note="A",len=4},{rest=2},
        {note="G",len=2},{note="E",len=4},{note="D",len=4},{rest=2},
        {loop={count=0,to="lead"}},
      }},
      { hw=2, program={
        {duty=1},{notetype={speed=6,volume=7,fade=1}},
        {octave=3},{label="answer"},
        {note="C",len=4},{note="G",len=4},{note="A",len=4},{note="E",len=4},
        {note="F",len=4},{note="C",len=4},{note="G",len=4},{rest=4},
        {loop={count=0,to="answer"}},
      }},
    },
  }
  local registry = mod.content and mod.content.music
  if registry and type(registry.register) == "function" then
    local existing = type(registry.get) == "function" and registry:get(M.id)
      or nil
    if existing == nil then registry:register(M.id, M.definition)
    elseif existing ~= M.definition then
      error("Hoenn trace music registry conflict: " .. M.id)
    end
  end
  return M
end
