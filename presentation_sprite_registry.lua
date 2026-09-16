-- Additive presentation sprite-provider registry.
--
-- This API deliberately sits above the existing Ascendant/engine sprite
-- resolvers.  A provider may supply a runtime image for a named presentation
-- surface; nil, malformed output or an exception always yields to the current
-- caller-owned fallback.  Pokemon and trainer providers are separate kinds.

return function(mod, opts)
  opts = opts or {}
  local R = {
    apiVersion = 1,
    kinds = { POKEMON = "pokemon", TRAINER = "trainer" },
    providers = {},
    titlePools = {},
    lastReceipt = nil,
  }
  local registrationOrder = 0
  local validKinds = { pokemon = true, trainer = true }

  local function copy(value)
    local out = {}
    for key, item in pairs(type(value) == "table" and value or {}) do
      out[key] = item
    end
    return out
  end

  local function copyList(value)
    local out = {}
    for index, item in ipairs(type(value) == "table" and value or {}) do
      out[index] = item
    end
    return out
  end

  local function safeId(value)
    return type(value) == "string" and value ~= ""
      and value:match("^[a-z0-9][a-z0-9_.%-]*$") ~= nil
  end

  local function safeSpecies(value)
    return type(value) == "string" and value ~= ""
      and value:match("^[A-Z0-9_]+$") ~= nil
  end

  local function warn(message)
    if mod and mod.log and type(mod.log.warn) == "function" then
      pcall(mod.log.warn, mod.log, tostring(message))
    end
  end

  local function providerRows(kind)
    local rows = {}
    for _, row in pairs(R.providers) do
      if not kind or row.kind == kind then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b)
      if a.priority ~= b.priority then return a.priority > b.priority end
      if a.order ~= b.order then return a.order < b.order end
      return a.id < b.id
    end)
    return rows
  end

  function R:register(kind, id, provider)
    if not validKinds[kind] then return false, "invalid provider kind" end
    if not safeId(id) then return false, "invalid provider id" end
    if self.providers[id] then return false, "duplicate provider id" end
    if type(provider) ~= "table" or type(provider.resolve) ~= "function" then
      return false, "provider must implement resolve"
    end
    if provider.supports ~= nil and type(provider.supports) ~= "function" then
      return false, "provider supports must be a function"
    end
    local priority = tonumber(provider.priority) or 0
    if priority ~= priority or priority == math.huge or priority == -math.huge then
      return false, "invalid provider priority"
    end
    registrationOrder = registrationOrder + 1
    self.providers[id] = {
      id = id, kind = kind, priority = priority,
      order = registrationOrder, owner = provider.owner,
      supports = provider.supports, resolve = provider.resolve,
    }
    return true
  end

  function R:registerPokemon(id, provider)
    return self:register(self.kinds.POKEMON, id, provider)
  end

  function R:registerTrainer(id, provider)
    return self:register(self.kinds.TRAINER, id, provider)
  end

  function R:list(kind)
    if kind ~= nil and not validKinds[kind] then return {} end
    local out = {}
    for _, row in ipairs(providerRows(kind)) do
      out[#out + 1] = {
        id = row.id, kind = row.kind, priority = row.priority,
        order = row.order, owner = row.owner,
      }
    end
    return out
  end

  local function validResult(result)
    if type(result) ~= "table" or result.image == nil then
      return false, "provider result must contain image"
    end
    if result.trueColor ~= nil and type(result.trueColor) ~= "boolean" then
      return false, "provider trueColor must be boolean"
    end
    if result.advance ~= nil and type(result.advance) ~= "function" then
      return false, "provider advance must be a function"
    end
    return true
  end

  function R:resolve(kind, request)
    if not validKinds[kind] then
      return nil, { status = "invalid", reason = "invalid provider kind",
        errors = {}, attempts = {} }
    end
    if type(request) ~= "table" then
      return nil, { status = "invalid", reason = "request must be a table",
        errors = {}, attempts = {} }
    end
    local receipt = { status = "unresolved", kind = kind,
      surface = request.surface, errors = {}, attempts = {} }
    for _, provider in ipairs(providerRows(kind)) do
      local supported = true
      if provider.supports then
        local probe = copy(request)
        local ok, value = pcall(provider.supports, probe)
        if not ok then
          supported = false
          receipt.errors[#receipt.errors + 1] = {
            providerId = provider.id, stage = "supports", reason = tostring(value),
          }
          warn("presentation provider " .. provider.id
            .. " supports failed: " .. tostring(value))
        else
          supported = value == true
        end
      end
      if supported then
        receipt.attempts[#receipt.attempts + 1] = provider.id
        local probe = copy(request)
        local ok, result = pcall(provider.resolve, probe)
        if not ok then
          receipt.errors[#receipt.errors + 1] = {
            providerId = provider.id, stage = "resolve", reason = tostring(result),
          }
          warn("presentation provider " .. provider.id
            .. " resolve failed: " .. tostring(result))
        elseif result ~= nil then
          local valid, why = validResult(result)
          if valid then
            local resolved = copy(result)
            resolved.providerId = provider.id
            resolved.kind = kind
            resolved.surface = request.surface
            receipt.status = "resolved"
            receipt.providerId = provider.id
            self.lastReceipt = receipt
            return resolved, receipt
          end
          receipt.errors[#receipt.errors + 1] = {
            providerId = provider.id, stage = "result", reason = why,
          }
          warn("presentation provider " .. provider.id
            .. " yielded invalid result: " .. tostring(why))
        end
      end
    end
    self.lastReceipt = receipt
    return nil, receipt
  end

  function R:resolvePokemon(request)
    return self:resolve(self.kinds.POKEMON, request)
  end

  function R:resolveTrainer(request)
    return self:resolve(self.kinds.TRAINER, request)
  end

  function R:advance(result, dt, context)
    if type(result) ~= "table" or result.image == nil then
      return nil, { status = "invalid", reason = "invalid provider state" }
    end
    if type(result.advance) ~= "function" then
      return result.image, { status = "static", providerId = result.providerId }
    end
    local ok, image = pcall(result.advance, result, tonumber(dt) or 0,
      type(context) == "table" and copy(context) or {})
    if not ok or image == nil then
      warn("presentation provider " .. tostring(result.providerId)
        .. " advance failed: " .. tostring(image))
      return result.image, { status = "yielded", providerId = result.providerId,
        reason = tostring(image) }
    end
    result.image = image
    return image, { status = "advanced", providerId = result.providerId }
  end

  function R:registerTitlePool(id, species, meta)
    if not safeId(id) then return false, "invalid title pool id" end
    if self.titlePools[id] then return false, "duplicate title pool id" end
    if type(species) ~= "table" or #species == 0 then
      return false, "title pool must contain species"
    end
    local seen, list = {}, {}
    for _, value in ipairs(species) do
      if not safeSpecies(value) then return false, "invalid title species" end
      if seen[value] then return false, "duplicate title species" end
      seen[value] = true
      list[#list + 1] = value
    end
    self.titlePools[id] = { id = id, species = list, meta = copy(meta) }
    return true
  end

  function R:titlePool(id)
    local pool = self.titlePools[id]
    return pool and copyList(pool.species) or nil
  end

  function R:composeTitlePool(base, poolIds)
    if type(base) ~= "table" then return nil, "base title pool must be a table" end
    if type(poolIds) == "string" then poolIds = { poolIds } end
    if type(poolIds) ~= "table" then return nil, "title pool ids must be a table" end
    local out, seen = {}, {}
    for _, species in ipairs(base) do
      if safeSpecies(species) and not seen[species] then
        seen[species] = true
        out[#out + 1] = species
      end
    end
    local before = #out
    for _, id in ipairs(poolIds) do
      local pool = self.titlePools[id]
      if not pool then return nil, "unknown title pool: " .. tostring(id) end
      for _, species in ipairs(pool.species) do
        if not seen[species] then
          seen[species] = true
          out[#out + 1] = species
        end
      end
    end
    return out, { status = "composed", base = before,
      added = #out - before, total = #out }
  end

  for id, species in pairs(type(opts.titlePools) == "table"
      and opts.titlePools or {}) do
    local ok, why = R:registerTitlePool(id, species)
    assert(ok, "invalid built-in title pool " .. tostring(id)
      .. ": " .. tostring(why))
  end

  return R
end
