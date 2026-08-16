local source = debug.getinfo(1, "S").source
local dir = source:sub(1, 1) == "@"
  and assert(source:sub(2):match("^(.*[/\\])")) or "tools/"
local Q = assert(loadfile(dir .. "legacy_manual_qa_setup_common.lua"))()

return function(game)
  return Q.freshLab(game, {
    identity = "legacy_yellow_one_ball",
    slot = "slotrc65yellowball",
    version = "yellow", character = "RED",
    sourcePlayerId = 65041, playerId = 65042,
  })
end
