local source = debug.getinfo(1, "S").source
local dir = source:sub(1, 1) == "@"
  and assert(source:sub(2):match("^(.*[/\\])")) or "tools/"
local Q = assert(loadfile(dir .. "legacy_manual_qa_setup_common.lua"))()

return function(game)
  return Q.freshLab(game, {
    identity = "legacy_fresh_lab_red",
    slot = "slotrc65freshred",
    version = "red", character = "RED",
    sourcePlayerId = 65021, playerId = 65022,
  })
end
