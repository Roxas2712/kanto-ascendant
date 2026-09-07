-- Public performance build: diagnostic recording is removed.
-- Keep the interface used by gameplay modules, without touching the filesystem,
-- wrapping the host logger, retaining event payloads or exposing repro markers.
return function(mod)
  local function disabled() return false, "diagnostics-disabled" end
  return {
    OWNER = "KASC-SUPPORT-DISABLED/v1",
    SCHEMA = "ascendant-support-session-log/v1",
    ALWAYS_ON = false,
    ENABLED = false,
    MAX_SESSIONS = 0,
    MAX_BYTES = 0,
    RETENTION_SECONDS = 0,
    boot = function() return true end,
    registerSegment = function() return true end,
    write = disabled,
    mirrorModLog = disabled,
    markRepro = disabled,
    finalize = function() return true end,
    sessionFile = function() return nil end,
    sessionId = function() return nil end,
    deleteOwnLogs = disabled,
    status = function()
      return { enabled=false, alwaysOn=false, bytes=0, maxBytes=0,
        maxSessions=0, retentionSeconds=0, export="DISABLED" }
    end,
  }
end
