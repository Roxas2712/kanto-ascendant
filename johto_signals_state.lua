-- Versioned save state for Johto Signals.
--
-- The public mod owns this key directly.  Runtime-only battle, prompt and
-- menu state belongs in the controller modules and is deliberately removed
-- if an older development save happened to persist it.

local Module = {
  SAVE_KEY = "johto_signals",
  SCHEMA_VERSION = 2,
}

local SECTIONS = {
  earlyJohto = true,
  resonance = true,
  prismGrotto = true,
}

local TRANSIENT_KEYS = {
  capsulePromptOpen = true,
  confirmationOpen = true,
  dialogOpen = true,
  menuOpen = true,
  pendingBattle = true,
  pendingEncounter = true,
  pendingSpecies = true,
  promptOpen = true,
}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[copy(key, seen)] = copy(child, seen)
  end
  return out
end

local function scrubSection(section)
  local changed = false
  if type(section) ~= "table" then
    section = {}
    changed = true
  end
  for key in pairs(TRANSIENT_KEYS) do
    if section[key] ~= nil then
      section[key] = nil
      changed = true
    end
  end
  return section, changed
end

local function normalize(raw)
  local changed = false
  if type(raw) ~= "table" then
    raw = {}
    changed = true
  end

  -- Early development snapshots used snake_case for the first section.
  -- Accept it once, then write only the stable public shape.
  local early = raw.earlyJohto
  if type(early) ~= "table" and type(raw.early_johto) == "table" then
    early = raw.early_johto
    changed = true
  end
  local resonance = raw.resonance
  local prismGrotto = raw.prismGrotto

  local earlyChanged, resonanceChanged, prismChanged
  early, earlyChanged = scrubSection(early)
  resonance, resonanceChanged = scrubSection(resonance)
  prismGrotto, prismChanged = scrubSection(prismGrotto)
  changed = changed or earlyChanged or resonanceChanged or prismChanged

  if raw.version ~= Module.SCHEMA_VERSION then changed = true end
  raw.version = Module.SCHEMA_VERSION
  if raw.earlyJohto ~= early then changed = true end
  if raw.resonance ~= resonance then changed = true end
  if raw.prismGrotto ~= prismGrotto then changed = true end
  raw.earlyJohto = early
  raw.resonance = resonance
  raw.prismGrotto = prismGrotto

  for key in pairs(raw) do
    if key ~= "version" and not SECTIONS[key] then
      raw[key] = nil
      changed = true
    end
  end
  return raw, changed
end

function Module.create(mod, opts)
  assert(mod and mod.save, "Johto Signals requires mod.save")
  opts = opts or {}

  local S = {
    game = nil,
    registered = false,
    SAVE_KEY = Module.SAVE_KEY,
    SCHEMA_VERSION = Module.SCHEMA_VERSION,
  }

  local function read(create)
    local raw = mod.save:get(Module.SAVE_KEY)
    if type(raw) ~= "table" and create == false then return nil end

    local root, changed = normalize(raw)
    if changed then mod.save:set(Module.SAVE_KEY, root) end
    return root
  end

  function S.root(create)
    return read(create)
  end

  function S.section(name, create)
    assert(SECTIONS[name], "unknown Johto Signals section: " .. tostring(name))
    local root = read(create)
    return root and root[name] or nil
  end

  function S.persist()
    local root = mod.save:get(Module.SAVE_KEY)
    -- normalize() works in place when the root is already a table, keeping
    -- live section identities intact for controller code.
    root = normalize(root)
    mod.save:set(Module.SAVE_KEY, root)
    return root
  end

  function S.install(game)
    S.game = game or S.game
    S.persist()
    return true
  end

  function S.register()
    if S.registered then return false, "already registered" end
    S.registered = true
    if mod.events and mod.events.on then
      mod.events:on("save.loaded", function(ev)
        S.install(ev and ev.game or S.game)
      end, 1000)
      mod.events:on("game.ready", function(ev)
        S.install(ev and ev.game or S.game)
      end, 1000)
    end
    return true
  end

  function S.status()
    local root = read(false)
    return {
      saveKey = Module.SAVE_KEY,
      schemaVersion = Module.SCHEMA_VERSION,
      installed = S.game ~= nil,
      present = root ~= nil,
      earlyJohto = root and copy(root.earlyJohto) or {},
      resonance = root and copy(root.resonance) or {},
      prismGrotto = root and copy(root.prismGrotto) or {},
    }
  end

  S.copy = copy
  S.register()
  if opts.game then S.install(opts.game) end
  return S
end

return Module
