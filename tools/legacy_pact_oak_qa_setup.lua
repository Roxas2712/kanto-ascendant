local source = debug.getinfo(1, "S").source
local dir = source:sub(1, 1) == "@"
  and assert(source:sub(2):match("^(.*[/\\])")) or "tools/"
local Q = assert(loadfile(dir .. "legacy_manual_qa_setup_common.lua"))()

return function(game)
  return Q.preJourney(game, {
    identity = "legacy_pact_oak_red",
    slot = "slotrc65pactoak",
    version = "red", character = "RED", playerId = 65011,
  })
end
