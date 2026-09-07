local calls = 0
local forbidden = setmetatable({}, {__index=function(_, key)
  error("disabled diagnostics touched " .. tostring(key))
end})
love = forbidden
local info = function() calls = calls + 1 end
local logger = {info=info, warn=info, error=info}
local support = assert(loadfile("support_session_log.lua"))()({log=logger})
assert(support.boot())
assert(support.ALWAYS_ON == false and support.ENABLED == false)
assert(support.open == nil, "repro marker menu is still exposed")
local payload = setmetatable({}, {__pairs=function() error("payload inspected") end,
  __tostring=function() error("payload formatted") end})
for i=1,100000 do
  assert(support.write("kasc.world.step", payload) == false)
  assert(support.registerSegment(payload))
end
assert(support.markRepro("begin") == false)
assert(support.deleteOwnLogs() == false)
assert(support.mirrorModLog() == false)
assert(support.finalize())
assert(support.sessionId() == nil and support.sessionFile() == nil)
assert(support.status().alwaysOn == false)
assert(logger.info == info and logger.warn == info and logger.error == info)
assert(calls == 0)
logger:warn("normal host warning")
assert(calls == 1)
print("PASS: 100000 disabled marker calls, no filesystem/graphics access, no logger wrapping, host warnings preserved")
