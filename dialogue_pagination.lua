-- Kanto Ascendant dialogue pagination guard.
--
-- Gen-I TextBox pages have two visible rows. A third ordinary `\n` row is
-- scrolled automatically, which makes authored additions look as if they
-- were skipping dialogue. `\f` clears the box only after A/B; `\v` is the
-- cartridge CONT command and also waits for A/B before it scrolls. This
-- guard inserts explicit waits into Ascendant-owned speaking text. Player
-- builds receive a per-mod require proxy; the engine and every other mod keep
-- the native TextBox table. The small native seam below exists only for
-- content strings that the engine opens after their KASC registration.

return function(mod, opts)
  opts = opts or {}
  local requiredTextBox = opts.TextBox or require("src.render.TextBox")
  -- A hot reload may execute this factory after the KASC sandbox require was
  -- already scoped. Always build the new controller against the native table,
  -- never against the previous controller's proxy.
  local TextBox = requiredTextBox._kascNativeTextBox or requiredTextBox
  local unpackValues = unpack or table.unpack
  local helperSource = debug and debug.getinfo
    and debug.getinfo(1, "S").source or nil
  local controller = {
    owned = {},
    path = tostring(mod and mod.path or ""),
    hasSourceDebug = debug and debug.getinfo and true or false,
    nativeTextBox = TextBox,
  }

  local function returnedValues(fn, ...)
    local values = { fn(...) }
    return values, #values
  end

  function controller.track(text)
    if type(text) == "string" then controller.owned[text] = true end
    return text
  end

  -- Every localized KASC line passes one of these helpers. Recording the
  -- selected result also covers content text that the engine opens later,
  -- when the active Lua stack no longer contains an Ascendant source file.
  function controller.wrapLocalization(i18n)
    for _, key in ipairs({ "text", "rematch", "decline", "warning", "rest" }) do
      local original = i18n and i18n[key]
      if type(original) == "function" then
        i18n[key] = function(...)
          local values, count = returnedValues(original, ...)
          for index = 1, count do controller.track(values[index]) end
          return unpackValues(values, 1, count)
        end
      end
    end
    return i18n
  end

  -- Content-backed map dialogue is normally invoked by the engine's script
  -- runner, not by the module function that registered it. Track those
  -- values at registration as a second, independent ownership signal.
  function controller.wrapRegistry(registry)
    if type(registry) ~= "table" then return false end
    registry._kascDialoguePagination = controller
    if registry._kascDialoguePaginationWrapped then return true end
    for _, key in ipairs({ "register", "override" }) do
      local original = registry[key]
      if type(original) == "function" then
        registry[key] = function(self, id, value, ...)
          local current = self._kascDialoguePagination
          if current then current.track(value) end
          return original(self, id, value, ...)
        end
      end
    end
    registry._kascDialoguePaginationWrapped = true
    return true
  end

  local function sourceOwned()
    if controller.path == "" or not (debug and debug.getinfo) then
      return false
    end
    for level = 3, 14 do
      local info = debug.getinfo(level, "S")
      if not info then break end
      local source = tostring(info.source or "")
      -- Ignore this guard's own helper/wrapper frames. The first external
      -- caller is the ownership authority; looking deeper would misclassify
      -- a vanilla TextBox opened by a test/tool that happens to live beneath
      -- the mod directory.
      if source:sub(1, 1) == "@" and source ~= helperSource then
        return source:find(controller.path .. "/", 1, true) ~= nil
      end
    end
    return false
  end

  function controller.isOwned(text)
    if controller.owned[text] == true then return true end
    if controller.hasSourceDebug then return sourceOwned() end
    -- Player builds intentionally remove the debug library. An unattributable
    -- string is therefore unowned, never a licence to alter engine/other-mod
    -- timing. Direct KASC calls are owned by the sandbox require proxy; this
    -- exact table is only for content the engine opens later.
    return false
  end

  -- TextBox.paginate can measure raw UTF-8 glyphs without expanding tokens.
  -- It returns byte-exact slices whose concatenation is the source row. A
  -- boundary inside {...} is deliberately skipped so token syntax can never
  -- be torn apart; native TextBox.new remains the one expansion authority.
  local function rawRows(line)
    local pages = TextBox.paginate(line)
    return pages[1] or { line }
  end

  local function tokenOpenAt(line, byteIndex)
    local depth = 0
    for index = 1, byteIndex do
      local char = line:sub(index, index)
      if char == "{" then depth = depth + 1
      elseif char == "}" and depth > 0 then depth = depth - 1 end
    end
    return depth > 0
  end

  local function gatedRaw(text, rowWait, delimiterWait, visibleLimit)
    if type(text) ~= "string" then return text end
    visibleLimit = visibleLimit or 1
    local out, pos = {}, 1
    local visibleRows = 0
    local pendingWait = nil
    while true do
      local controlAt = text:find("[\n\v\f]", pos)
      local line = controlAt and text:sub(pos, controlAt - 1)
        or text:sub(pos)
      local rows, consumed = rawRows(line), 0
      for index, row in ipairs(rows) do
        -- A raw slice inside an unexpanded {TOKEN} is not a rendered-row
        -- boundary. Rejoin it byte-exactly and let native substitution be
        -- the single authority that measures the eventual replacement.
        local renderedBoundary = index == 1
          or not tokenOpenAt(line, consumed)
        if renderedBoundary then
          local waitBefore = pendingWait
          if visibleRows >= visibleLimit and not waitBefore then
            out[#out + 1] = rowWait
            waitBefore = rowWait
          end

          if waitBefore == "\f" then
            -- A page break clears both rows before this row is rendered.
            visibleRows = 1
          elseif waitBefore == "\v" then
            -- CONT waits before scrolling the incoming row. The box stays
            -- full when it already had two rows; otherwise one row is added.
            visibleRows = math.min(visibleLimit, visibleRows + 1)
          else
            visibleRows = math.min(visibleLimit, visibleRows + 1)
          end
          pendingWait = nil
        end
        out[#out + 1] = row
        consumed = consumed + #row
      end
      if not controlAt then break end
      local delimiter = text:sub(controlAt, controlAt)
      local emitted = delimiterWait[delimiter] or delimiter
      out[#out + 1] = emitted
      if emitted == "\f" then
        visibleRows = 0
        pendingWait = nil
      elseif emitted == "\v" then
        pendingWait = "\v"
      end
      pos = controlAt + 1
    end
    return table.concat(out)
  end

  -- Fill the two rows the native Gen-I box actually exposes, then insert a
  -- page wait before a third row could auto-scroll. This keeps the safety
  -- guarantee without making every ordinary two-line sentence need an extra
  -- click. A single long authored row is still wrapped safely.
  function controller.gateText(_, text)
    return gatedRaw(text, "\f", {}, 2)
  end

  -- BattleState has its own parser and never calls TextBox.new. CONT is its
  -- native A/B wait marker, so Grand Tour intro rows need an explicit seam.
  function controller.gateBattleText(text)
    return gatedRaw(text, "\v", {
      ["\n"] = "\v", ["\f"] = "\v",
    }, 1)
  end

  local function timingOwned(boxOpts)
    return not (boxOpts and (boxOpts.auto or boxOpts.instant or boxOpts.stay))
  end

  function controller.makeTextBox(game, text, onDone, boxOpts, direct)
    if timingOwned(boxOpts) and (direct or controller.isOwned(text)) then
      text = controller.gateText(game, text)
    end
    -- Read dynamically: Yellow's partner adapter intentionally wraps the
    -- native constructor later in boot and must still see engine-created and
    -- KASC-created text alike.
    return controller.nativeTextBox.new(game, text, onDone, boxOpts)
  end

  local proxy = setmetatable({
    _kascNativeTextBox = TextBox,
  }, { __index = TextBox })
  proxy.new = function(game, text, onDone, boxOpts)
    return controller.makeTextBox(game, text, onDone, boxOpts, true)
  end
  controller.TextBox = proxy

  -- The shared wrapper is deliberately narrow. It covers exact strings that
  -- KASC registered into engine content, plus source-attributed KASC calls in
  -- debug/headless tests. No-debug unknown strings always pass byte-exact.
  function controller.installNativeSeam()
    local state = rawget(TextBox, "_kascDialoguePaginationState")
    if type(state) ~= "table" then
      state = { originalNew = TextBox.new }
      state.wrapper = function(game, text, onDone, boxOpts)
        local current = state.controller
        if current and timingOwned(boxOpts) and current.isOwned(text) then
          text = current.gateText(game, text)
        end
        return state.originalNew(game, text, onDone, boxOpts)
      end
      rawset(TextBox, "_kascDialoguePaginationState", state)
      TextBox.new = state.wrapper
    end
    state.controller = controller
    return true
  end

  -- Sandbox.envFor gives every mod one private _G and binds every loadstring
  -- child to it. Replacing only that table's require therefore reaches nested
  -- HEVO chunks without touching the engine or another mod. Debug/headless
  -- keeps the raw require and uses source attribution above.
  function controller.installSandboxRequire()
    if controller.hasSourceDebug then return false end
    local env = _G
    local state = rawget(env, "_kascDialogueRequireState")
    if type(state) ~= "table" then
      state = { nativeRequire = assert(env.require,
        "KASC dialogue pagination needs sandbox require") }
      state.wrapper = function(name, ...)
        if name == "src.render.TextBox" then
          return state.controller.TextBox
        end
        return state.nativeRequire(name, ...)
      end
      rawset(env, "_kascDialogueRequireState", state)
      env.require = state.wrapper
    end
    state.controller = controller
    return true
  end

  controller.wrapRegistry(mod and mod.content and mod.content.text)
  controller.installNativeSeam()
  controller.installSandboxRequire()
  return controller
end
