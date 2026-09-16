-- Owner-scoped KASC consumer for VASC's public PokemonUi Host-v1 seam.
--
-- This is deliberately not an `ascendant.card/v1` descriptor: VASC's RC11
-- card host is read-only and does not accept external registration.  KASC
-- owns this small local lifecycle and consumes only the documented
-- `mod.find("VOXEL_ASCENDANT").exports.pokemonUi` capability.  Storage/save
-- authority never crosses this boundary; failure leaves callers on their
-- existing KASC/native presentation path.

local CARD_SCHEMA = "kanto-ascendant/consumer-card/v1"
local HEALTH_SCHEMA = "kanto-ascendant/consumer-card-health/v1"
local BINDING_SCHEMA = "kanto-ascendant/pokemon-ui-binding/v1"
local CARD_ID = "kasc.storage.legacy_bank.pokemon_ui_host_v1"
local VASC_MOD_ID = "VOXEL_ASCENDANT"
local HOST_ID = "kanto_ascendant_legacy_bank_gen1"
local SURFACE = "legacy_bank"
local VIEWPORT_WIDTH = 512
local VIEWPORT_HEIGHT = 288

local SCHEMAS = {
  host = "voxel-ascendant/pokemon-ui-host/v1",
  model = "voxel-ascendant/pokemon-ui-model/v1",
  action = "voxel-ascendant/pokemon-ui-action/v1",
  actionResult = "voxel-ascendant/pokemon-ui-action-result/v1",
  event = "voxel-ascendant/pokemon-ui-event/v1",
}

local function copyArray(items)
  if type(items) ~= "table" then return nil end
  local out, count = {}, 0
  for key, value in pairs(items) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0
        or type(value) ~= "string" or value == "" then
      return nil
    end
    count = count + 1
  end
  if count ~= #items then return nil end
  for index, value in ipairs(items) do out[index] = value end
  return out
end

local function hasAction(actions, expected)
  for _, action in ipairs(type(actions) == "table" and actions or {}) do
    if action == expected then return true end
  end
  return false
end

return function(mod)
  assert(type(mod) == "table", "vasc_legacy_bank_card requires mod")
  local owner = assert(type(mod.id) == "string" and mod.id ~= "" and mod.id,
    "vasc_legacy_bank_card requires the actual mod.id owner")

  local installed = false
  local state = "new"
  local api, handle, activeRequirement
  local clearSelection = false
  local lastReason

  local Card = {}
  Card.__index = Card

  local function publicId(foundApi, key, fallback)
    local value = type(foundApi) == "table" and type(foundApi.ids) == "table"
      and foundApi.ids[key] or nil
    return type(value) == "string" and value ~= "" and value or fallback
  end

  local function metadata()
    return {
      schema=CARD_SCHEMA,
      id=CARD_ID,
      version="1.0.0",
      owner=owner,
      dependency="soft",
      requires={},
      optionalRequires={ SCHEMAS.host },
      consumes={ SCHEMAS.host },
      provides={},
      saveNamespace=false,
      lifecycle={ "install", "activate", "deactivate", "abort", "health" },
      tests={
        "tests/vasc_legacy_bank_card_test.lua",
        "tests/frlg_pc_interface_test.lua",
      },
      docs={ "docs/RC11_KASC_POKEMON_UI_CONSUMER.md" },
      impact={
        runtimeOwners={ "pokemon_ui.host." .. HOST_ID },
        saveWrites={},
        publicHooks={ "mod.exports.pokemonUi.registerHost" },
        files={
          "main.lua",
          "vasc_legacy_bank_card.lua",
          "modern_storage_ui.lua",
        },
      },
    }
  end

  local function invalidApi(reason)
    return nil, "vasc-pokemon-ui-" .. reason
  end

  local function discover()
    if type(mod.find) ~= "function" then return invalidApi("unavailable") end
    local ok, found = pcall(mod.find, VASC_MOD_ID)
    if not ok or type(found) ~= "table"
        or type(found.exports) ~= "table" then
      return invalidApi("unavailable")
    end
    local foundApi = found.exports.pokemonUi
    if type(foundApi) ~= "table" then return invalidApi("unavailable") end
    if foundApi.hostSchema ~= SCHEMAS.host
        or foundApi.modelSchema ~= SCHEMAS.model
        or foundApi.actionSchema ~= SCHEMAS.action
        or foundApi.actionResultSchema ~= SCHEMAS.actionResult
        or foundApi.eventSchema ~= SCHEMAS.event
        or foundApi.apiVersion ~= 1
        or foundApi.hostGeneration ~= 1
        or foundApi.controllerGeneration ~= 1
        or type(foundApi.registerHost) ~= "function" then
      return invalidApi("incompatible-host-v1")
    end
    local raw = type(foundApi.requirements) == "table"
      and foundApi.requirements[SURFACE] or nil
    local modes = raw and copyArray(raw.modes)
    local actions = raw and copyArray(raw.actions)
    local events = raw and copyArray(raw.events)
    if type(raw) ~= "table" or raw.selection ~= "multi_cross_box"
        or not modes or not actions or not events then
      return invalidApi("incompatible-legacy-bank")
    end
    return foundApi, {
      selection=raw.selection,
      modes=modes,
      actions=actions,
      events=events,
    }
  end

  local function clearBinding()
    api, handle, activeRequirement, clearSelection = nil, nil, nil, false
  end

  local function retire(reason)
    if not handle then
      clearBinding()
      state = installed and "installed" or "new"
      if reason then lastReason = tostring(reason) end
      return true
    end
    local owned = handle
    local ok, result = pcall(function() return owned:unregister() end)
    if not ok then
      state = "degraded"
      lastReason = "host-unregister-error:" .. tostring(result)
      return false, lastReason
    end
    -- `false` means VASC had already retired this opaque handle.  Either way,
    -- KASC no longer owns a live registration and may forget the token.
    clearBinding()
    state = installed and "installed" or "new"
    if reason then lastReason = tostring(reason) end
    return true
  end

  local function receiptFor(foundApi, requirement, includeClear)
    local actions = copyArray(requirement.actions)
    if includeClear and not hasAction(actions, "clear_selection") then
      actions[#actions + 1] = "clear_selection"
    end
    return {
      schema=foundApi.hostSchema,
      apiVersion=foundApi.apiVersion,
      id=HOST_ID,
      owner=owner,
      hostGeneration=foundApi.hostGeneration,
      surfaces={
        [SURFACE]={
          controllerGeneration=foundApi.controllerGeneration,
          viewports={ { width=VIEWPORT_WIDTH, height=VIEWPORT_HEIGHT } },
          schemas={
            model=foundApi.modelSchema,
            action=foundApi.actionSchema,
            actionResult=foundApi.actionResultSchema,
            event=foundApi.eventSchema,
          },
          modes=copyArray(requirement.modes),
          actions=actions,
          events=copyArray(requirement.events),
          claims={
            model="immutable_snapshot",
            actions="authoritative",
            input="exclusive",
            commit="atomic",
            fallback="whole_surface_next_frame",
            selection=requirement.selection,
          },
        },
      },
    }
  end

  local function register(foundApi, requirement, includeClear)
    local retired, retireWhy = retire("host-rebind")
    if not retired then return nil, retireWhy end
    local receipt = receiptFor(foundApi, requirement, includeClear)
    local called, registered, why = pcall(foundApi.registerHost, receipt)
    if not called then
      state = "installed"
      lastReason = "host-register-error:" .. tostring(registered)
      return nil, lastReason
    end
    if type(registered) ~= "table"
        or type(registered.resolve) ~= "function"
        or type(registered.begin) ~= "function"
        or type(registered.unregister) ~= "function" then
      if type(registered) == "table"
          and type(registered.unregister) == "function" then
        pcall(registered.unregister, registered)
      end
      state = "installed"
      lastReason = "host-register-rejected:" .. tostring(why)
      return nil, lastReason
    end
    api, handle, activeRequirement = foundApi, registered, requirement
    clearSelection = includeClear == true
    state, lastReason = "active", nil
    return registered
  end

  local function resolve(ownedHandle)
    if type(ownedHandle) ~= "table"
        or type(ownedHandle.resolve) ~= "function" then
      return nil, "host-handle-unavailable"
    end
    local ok, value = pcall(ownedHandle.resolve, ownedHandle, SURFACE)
    if not ok then return nil, "host-resolve-error:" .. tostring(value) end
    if type(value) ~= "table" then return nil, "host-resolve-invalid" end
    return value
  end

  local function providerSupportsClear(resolved)
    local gameDefault = publicId(api, "gameDefault", "game_default")
    if type(resolved) ~= "table" or resolved.effective == gameDefault then
      return false
    end
    local surface = resolved.provider and resolved.provider.surfaces
      and resolved.provider.surfaces[SURFACE]
    return hasAction(surface and surface.actions, "clear_selection")
  end

  local function confirmRegistration(registered)
    local resolved, why = resolve(registered)
    if resolved and type(resolved.effective) == "string"
        and resolved.effective ~= ""
        and resolved.reason ~= "invalid-or-stale-host-handle" then
      return resolved
    end
    why = why or resolved and resolved.reason or "host-resolve-invalid"
    local retired, retireWhy = retire(why)
    if not retired then return nil, retireWhy end
    state, lastReason = "installed", why
    return nil, why
  end

  local card = setmetatable({}, Card)

  function Card:metadata()
    return metadata()
  end

  function Card:install()
    if installed then return true, "already-installed" end
    installed, state, lastReason = true, "installed", nil
    return true, "installed"
  end

  function Card:activate()
    if not installed then self:install() end
    local foundApi, requirementOrWhy = discover()
    if not foundApi then
      if handle then
        local retired, retireWhy = retire(requirementOrWhy)
        if not retired then return false, retireWhy end
      end
      state, lastReason = "installed", requirementOrWhy
      return false, requirementOrWhy
    end
    local requirement = requirementOrWhy

    if api == foundApi and handle then
      local resolved, why = resolve(handle)
      if resolved and resolved.reason ~= "invalid-or-stale-host-handle" then
        local supportsClear = providerSupportsClear(resolved)
        if supportsClear == clearSelection
            or resolved.effective == "game_default"
              and resolved.reason ~= "provider-host-incompatible" then
          state, lastReason = "active", nil
          return true, "already-active"
        end
      elseif why then
        lastReason = why
      end
    end

    -- Bind the baseline Host first so all published Host-v1 providers remain
    -- compatible.  Upgrade only if the selected provider advertises the
    -- optional clear-selection action.
    local registered, why = register(foundApi, requirement, false)
    if not registered then return false, why end
    local resolved
    resolved, why = confirmRegistration(registered)
    if not resolved then return false, why end
    if providerSupportsClear(resolved) then
      registered, why = register(foundApi, requirement, true)
      if not registered then return false, why end
      resolved, why = confirmRegistration(registered)
      if not resolved then return false, why end
    end
    return true, "active"
  end

  function Card:deactivate(reason)
    if not installed then return true, "not-installed" end
    local ok, why = retire(reason or "deactivated")
    if not ok then return false, why end
    return true, "deactivated"
  end

  function Card:abort(reason)
    if not installed then return true, "not-installed" end
    local ok, why = retire(reason or "aborted")
    if not ok then return false, why end
    return true, "aborted"
  end

  function Card:binding()
    local ok, why = self:activate()
    if not ok then return nil, why end
    local resolved
    resolved, why = confirmRegistration(handle)
    if not resolved then return nil, why end
    local ownedHandle = handle
    local binding = {
      schema=BINDING_SCHEMA,
      card=CARD_ID,
      owner=owner,
      capability=SCHEMAS.host,
      surface=SURFACE,
      host=HOST_ID,
      clearSelection=clearSelection,
      contract={
        apiVersion=api.apiVersion,
        hostGeneration=api.hostGeneration,
        controllerGeneration=api.controllerGeneration,
        schemas={
          model=api.modelSchema,
          action=api.actionSchema,
          actionResult=api.actionResultSchema,
          event=api.eventSchema,
        },
        events=copyArray(activeRequirement.events),
        ids={
          ascBox=publicId(api, "ascBox", "asc_box"),
          gameDefault=publicId(api, "gameDefault", "game_default"),
        },
      },
    }
    function binding:resolve()
      return resolve(ownedHandle)
    end
    function binding:begin(request)
      local called, controller, receipt = pcall(
        ownedHandle.begin, ownedHandle, request)
      if not called then
        return nil, "host-begin-error:" .. tostring(controller)
      end
      return controller, receipt
    end
    return binding
  end

  function Card:health()
    local registered = state == "active" and api ~= nil and handle ~= nil
    local reason = lastReason
    local resolution
    if registered then
      resolution, reason = resolve(handle)
      if not resolution
          or resolution.reason == "invalid-or-stale-host-handle" then
        registered = false
      else
        reason = resolution.reason
      end
    end
    local gameDefault = publicId(api, "gameDefault", "game_default")
    local active = registered and resolution.effective ~= gameDefault
    return {
      schema=HEALTH_SCHEMA,
      card=metadata(),
      state=state,
      ok=state ~= "degraded",
      installed=installed,
      registered=registered,
      active=active,
      fallback=not active,
      reason=reason,
      surface=SURFACE,
      host=HOST_ID,
      capability=SCHEMAS.host,
      clearSelection=active and clearSelection or false,
      effective=resolution and resolution.effective or "game_default",
    }
  end

  return card
end
