-- Asset-free visual title palette themes.
--
-- This module is intentionally a pure palette adapter.  It does not wrap a
-- title state, draw anything, load assets, handle input, or persist options.
-- Callers retain ownership of composition and pass their already-resolved
-- palette zones through applyTitlePalettes().  Classic and every failure path
-- return that exact input object; successful transforms work on a deep clone.

return function(mod)
  local M = {
    owner = "kasc.visual-title-themes/v1",
    schema = "kanto-ascendant-visual-title-themes/v1",
    optionKey = "title_visual_theme",
    defaultId = "classic",
    ids = { "classic", "trio", "mono" },
    catalog = {
      classic = {
        id = "classic", default = true, transform = "none",
        description = "Caller-owned title palettes without modification",
      },
      trio = {
        id = "trio", default = false, transform = "identity-ramp",
        identities = { "RED", "GREEN", "BLUE", "YELLOW" },
        yellowTreatment = "amber",
      },
      mono = {
        id = "mono", default = false, transform = "source-luminance",
      },
    },
    capability = {
      paletteOnly = true,
      codeNative = true,
      assetPaths = {},
      audioPaths = {},
      inputHooks = false,
      mutatesInput = false,
      optionKey = "title_visual_theme",
      optionWrites = false,
      readerFailureScope = "boot-local-circuit-breaker",
    },
  }

  local RAMPS = {
    RED = {
      { 255, 255, 255 }, { 255, 156, 156 },
      { 168, 48, 48 }, { 0, 0, 0 },
    },
    GREEN = {
      { 255, 255, 255 }, { 164, 224, 156 },
      { 44, 128, 60 }, { 0, 0, 0 },
    },
    BLUE = {
      { 255, 255, 255 }, { 156, 204, 255 },
      { 44, 76, 176 }, { 0, 0, 0 },
    },
    -- Yellow has no Red/Blue/Green trainer identity cycle.  Its native fixed
    -- Pikachu composition receives a warm, high-contrast amber ramp instead.
    YELLOW = {
      { 255, 252, 224 }, { 255, 216, 88 },
      { 176, 108, 20 }, { 0, 0, 0 },
    },
  }

  local readerCircuitOpen = false
  local readerProblem
  local readerCalls = 0
  local sessionFallbackReason
  local sessionProblem

  function M.failSession(reason, problem)
    if sessionFallbackReason == nil then
      sessionFallbackReason = tostring(reason or "theme-circuit-open")
      sessionProblem = problem and tostring(problem) or nil
    end
    return sessionFallbackReason
  end

  local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
      result[clone(key, seen)] = clone(child, seen)
    end
    return result
  end

  local function receipt(status, requested, applied, reason, problem)
    return {
      schema = M.schema,
      owner = M.owner,
      status = status,
      requestedId = requested,
      appliedId = applied,
      transformed = status == "applied",
      reason = reason,
      problem = problem and tostring(problem) or nil,
      inputPreserved = true,
    }
  end

  local function selectedId()
    if sessionFallbackReason ~= nil then
      return nil, sessionFallbackReason, sessionProblem
    end
    if readerCircuitOpen then
      return nil, "option-reader-circuit-open", readerProblem
    end
    local options = mod and mod.options
    if type(options) ~= "table" or type(options.get) ~= "function" then
      return nil, "option-reader-unavailable"
    end
    readerCalls = readerCalls + 1
    local ok, value = pcall(options.get, options, M.optionKey)
    if not ok then
      readerCircuitOpen = true
      readerProblem = tostring(value)
      M.failSession("option-reader-circuit-open", readerProblem)
      return nil, "option-reader-error", readerProblem
    end
    if value == nil then return nil, "option-missing" end
    if type(value) ~= "string" or M.catalog[value] == nil then
      return value, "option-invalid"
    end
    return value
  end

  local function assertPalette(colors)
    if type(colors) ~= "table" or #colors ~= 4 then
      error("title palette must contain exactly four colors")
    end
    for index = 1, 4 do
      local color = colors[index]
      if type(color) ~= "table" then
        error("title palette color " .. index .. " is not a table")
      end
      for channel = 1, 3 do
        local value = color[channel]
        if type(value) ~= "number" or value ~= value
            or value == math.huge or value == -math.huge
            or value < 0 or value > 255 then
          error("title palette color " .. index .. " has an invalid channel")
        end
      end
    end
  end

  local function eachColoredZone(zones, transform)
    if type(zones) ~= "table" then
      error("title palette zones must be a table")
    end
    local result = clone(zones)
    for _, zone in ipairs(result) do
      if type(zone) == "table" and type(zone.colors) == "table" then
        assertPalette(zone.colors)
        zone.colors = transform(zone.colors)
      end
      -- A zone without a color table (including colors=false true-color
      -- zones) remains present and otherwise byte-for-byte equivalent.
    end
    return result
  end

  local function trio(zones, context)
    if type(context) ~= "table" then
      error("trio title theme requires a context table")
    end
    local identity = context.identity
    if identity == nil and context.yellowLayout == true then
      identity = "YELLOW"
    end
    if type(identity) ~= "string" then
      error("trio title theme requires context.identity")
    end
    identity = identity:upper()
    local ramp = RAMPS[identity]
    if not ramp then
      error("unsupported trio title identity: " .. identity)
    end
    return eachColoredZone(zones, function()
      return clone(ramp)
    end)
  end

  local function mono(zones)
    return eachColoredZone(zones, function(colors)
      local result = clone(colors)
      for index = 1, 4 do
        local color = result[index]
        -- Integer Rec. 601 luma keeps the source palette's actual shade
        -- spacing instead of replacing it with an unrelated fixed ramp.
        local gray = math.floor((299 * color[1] + 587 * color[2]
          + 114 * color[3] + 500) / 1000)
        color[1], color[2], color[3] = gray, gray, gray
      end
      return result
    end)
  end

  function M.applyTitlePalettes(zones, context)
    local requested, why, problem = selectedId()
    if why then
      return zones, receipt("classic", requested, "classic", why, problem)
    end
    if requested == "classic" then
      return zones, receipt("classic", requested, "classic", "explicit")
    end

    local transform = requested == "trio" and trio
      or requested == "mono" and mono or nil
    if not transform then
      return zones, receipt("classic", requested, "classic", "option-invalid")
    end
    local ok, transformed = pcall(transform, zones, context)
    if not ok then
      M.failSession("transform-circuit-open", transformed)
      return zones, receipt("classic", requested, "classic",
        "transform-error", transformed)
    end
    return transformed, receipt("applied", requested, requested)
  end

  function M.readerState()
    return {
      calls = readerCalls,
      circuitOpen = readerCircuitOpen,
      problem = readerProblem,
      sessionFallbackReason = sessionFallbackReason,
      sessionProblem = sessionProblem,
    }
  end

  return M
end
