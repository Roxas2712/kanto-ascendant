-- Small event-driven support recorder. Never serializes saves or event tables.
-- Two bounded snapshots (current/previous) live only in this mod's storage.
return function(mod)
  local S = { OWNER="KASC-SUPPORT-EXPORT/v1", ENABLED=true, ALWAYS_ON=true,
    SCHEMA="ascendant-support-session-log/v1", MAX_BYTES=1024*1024,
    MAX_SESSIONS=2, RETENTION_SECONDS=0 }
  local chunks, bytes, started, storage, previous = {}, 0, false, nil, nil
  local lastFlush, dropped = 0, 0
  local session = tostring(os.time())
  local keys = {version=true, generation=true, mapId=true, status=true,
    reason=true, code=true, action=true, stage=true, mode=true,
    cardId=true, providerStatus=true, dependencyStatus=true}
  local function clean(value)
    return tostring(value or ""):gsub("[%c]", " ")
      :gsub("/Users/[^ /]+", "/Users/[redacted]")
      :gsub("/home/[^ /]+", "/home/[redacted]")
      :gsub("https?://%S+", "[url]"):sub(1, 800)
  end
  local function body()
    return "KASC support session " .. session .. "\n"
      .. "Dropped older records: " .. dropped .. "\n" .. table.concat(chunks)
  end
  local function bind()
    if storage then return storage end
    local api = mod.storage
    local game = mod.world and mod.world.game
    if not (api and type(api.shared) == "function" and game) then return nil end
    local ok, bound = pcall(api.shared, api, game)
    if not ok or type(bound) ~= "table" then return nil end
    storage = bound
    if type(storage.readBytes) == "function" then
      local readOK, old = pcall(storage.readBytes, storage, "support_export/current")
      if readOK and type(old) == "string" and #old <= S.MAX_BYTES then
        previous = old
        pcall(storage.writeBytes, storage, "support_export/previous", old)
      end
    end
    return storage
  end
  function S.finalize()
    local target = bind()
    if not target or type(target.writeBytes) ~= "function" then
      return false, "storage-unavailable"
    end
    local ok, done = pcall(target.writeBytes, target, "support_export/current", body())
    lastFlush = os.time()
    return ok and done == true
  end
  function S.write(event, fields)
    local parts = { clean(event) }
    for key in pairs(keys) do
      local value = type(fields) == "table" and fields[key]
      if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
        parts[#parts+1] = key .. "=" .. clean(value)
      end
    end
    table.sort(parts, function(a,b) return a < b end)
    local line = tostring(os.time()) .. " " .. table.concat(parts, " ") .. "\n"
    chunks[#chunks+1], bytes = line, bytes + #line
    while bytes > S.MAX_BYTES - 256 and #chunks > 1 do
      bytes = bytes - #table.remove(chunks,1); dropped=dropped+1
    end
    local name = tostring(event):lower()
    if os.time() - lastFlush >= 5 or name:find("error",1,true)
        or name:find("warn",1,true) then S.finalize() end
    return true
  end
  function S.registerSegment(fields) S.write("segment", fields); return true end
  function S.markRepro(state) return S.write("repro", {status=state}) end
  function S.mirrorModLog(level, message)
    return S.write("host-" .. clean(level), {reason=message})
  end
  function S.boot()
    if started then return true end
    started=true
    S.write("session-start", {version=mod.version or (mod.manifest and mod.manifest.version) or "6.7.2+support-export"})
    for _, level in ipairs({"warn", "error"}) do
      local original = mod.log and mod.log[level]
      if type(original) == "function" then
        mod.log[level] = function(self, fmt, ...)
          local ok, message = pcall(string.format, tostring(fmt), ...)
          -- Logging must never turn a handled warning into a gameplay failure.
          pcall(S.mirrorModLog, level, ok and message or tostring(fmt))
          return original(self, fmt, ...)
        end
      end
    end
    return true
  end
  function S.sessionId() return session end
  function S.sessionFile() return "support_export/current" end
  function S.status()
    return {enabled=true, alwaysOn=true, bytes=bytes, maxBytes=S.MAX_BYTES,
      maxSessions=S.MAX_SESSIONS, recording=storage and "PERSISTED" or "MEMORY"}
  end
  function S.deleteOwnLogs()
    local target = bind()
    if target and type(target.delete) == "function" then
      pcall(target.delete,target,"support_export/current")
      pcall(target.delete,target,"support_export/previous")
    end
    chunks,bytes,previous,dropped={},0,nil,0
    S.write("logs-cleared")
    return true
  end
  function S.supportPayload()
    S.finalize()
    local payload=body()
    if previous then payload=previous .. "\n--- CURRENT SESSION ---\n" .. payload end
    return payload
  end
  local sender
  function S.openSupportSend(game, de)
    if not sender then
      local source=assert(mod:read("support_send.lua"))
      sender=assert((loadstring or load)(source,"@support_send"))().new(mod,S.supportPayload)
    end
    return sender.open(game,de)
  end
  function S.open(game,tr) return S.openSupportSend(game,tr("en","de")=="de") end
  return S
end
