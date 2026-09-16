-- Authenticated content evidence for generation_rules.
--
-- Pokédex `seen`, trainer parties and renderer/vendor assets are deliberately
-- absent.  Only durable story receipts and Pokémon actually owned on an
-- authoritative storage surface may advance unlockedEpoch.

return function(mod, opts)
  opts = opts or {}
  local E = {}
  local surfaceProviders = {}

  -- National identities, not engine/ROM slot numbers. In particular, 7019
  -- (an Alola runtime slot) must not become an ordinary Gen-VI identity.
  local NATIONAL_LIMITS = { 151, 251, 386, 493, 649, 721, 809, 905, 1025 }

  function E.speciesEpoch(species, record)
    record = type(record) == "table" and record or {}
    local origin = tonumber(record.originGeneration or record.originEpoch)
    if origin and origin == math.floor(origin) and origin >= 1 and origin <= 9 then
      return origin
    end
    if record.formId == "ALOLA" or record.regionalForm == "ALOLA" then return 7 end
    local dex = tonumber(record.sourceDex or record.dex)
      or type(species) == "number" and species or nil
    if not dex or dex ~= math.floor(dex) or dex < 1 then return nil end
    for epoch, limit in ipairs(NATIONAL_LIMITS) do
      if dex <= limit then return epoch end
    end
    return nil
  end

  local function owner(save, create)
    if type(save) ~= "table" then return nil end
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local value = save.modData[mod.id]
    if type(value) ~= "table" then
      if not create then return nil end
      value = {}
      save.modData[mod.id] = value
    end
    return value
  end

  local function itemCount(save, id)
    local inventory = type(save.inventory) == "table" and save.inventory or {}
    local pcItems = type(save.pcItems) == "table" and save.pcItems or {}
    return math.max(0, tonumber(inventory[id]) or 0),
      math.max(0, tonumber(pcItems[id]) or 0)
  end

  local function speciesDex(game, mon)
    if type(mon) ~= "table" then return nil end
    local species = mon.eggSpecies or mon.species
    local data = game and game.data and game.data.pokemon
    local record = type(data) == "table" and data[species] or nil
    local dex = record and tonumber(record.sourceDex or record.dex)
    if not dex and type(species) == "number" then dex = species end
    return dex and math.floor(dex) or nil, species, record
  end

  local function addMonSurface(out, label, values, unhatched)
    if type(values) ~= "table" then return end
    if values.species or values.eggSpecies then
      out[#out + 1] = { label = label, mon = values, unhatched = unhatched }
      return
    end
    for key, value in pairs(values) do
      if type(value) == "table" then
        local mon = value.mon or value.pokemon
        if type(mon) == "table" and (mon.species or mon.eggSpecies) then
          out[#out + 1] = { label = label .. ":" .. tostring(key), mon = mon, unhatched = unhatched }
        elseif value.species or value.eggSpecies then
          out[#out + 1] = { label = label .. ":" .. tostring(key), mon = value, unhatched = unhatched }
        end
      end
    end
  end

  function E.ownedSurfaces(save, game)
    local out = {}
    addMonSurface(out, "party", save and save.party)
    addMonSurface(out, "legacy_box", save and save.box)
    for index, box in pairs(type(save and save.boxes) == "table"
        and save.boxes or {}) do
      addMonSurface(out, "box" .. tostring(index),
        type(box) == "table" and (box.mons or box.pokemon or box) or nil)
    end
    local daycare = type(save and save.daycare) == "table" and save.daycare
    if daycare then addMonSurface(out, "daycare", daycare.mon or daycare) end

    local bucket = owner(save, false)
    local plus = bucket and bucket.daycare_plus
    addMonSurface(out, "daycare_plus_parent",
      type(plus) == "table" and plus.parents)
    addMonSurface(out, "daycare_plus_egg",
      type(plus) == "table" and plus.reservedEggs, true)

    -- Old previews kept a save-local archive snapshot.  Current shared vaults
    -- are supplied through addSurfaceProvider below.
    for _, key in ipairs({ "legacy_archive", "legacy_bank", "transfer_bank" }) do
      local archive = bucket and bucket[key]
      addMonSurface(out, key,
        type(archive) == "table" and (archive.bank or archive.mons or archive)
          or nil)
    end
    for _, provider in ipairs(surfaceProviders) do
      local ok, rows = pcall(provider, save, game)
      if ok then addMonSurface(out, "provider", rows) end
    end
    return out
  end

  local function ownedEpoch(game, save, witnesses, content)
    local epoch = 1
    for _, row in ipairs(E.ownedSurfaces(save, game)) do
      -- KASC-67-EQUIPMENT-BANK-HATCHING: possession of an unrevealed egg is
      -- not acquisition of its future species. Reserved daycare rows do not
      -- yet have isEgg, so carry that provenance from the storage surface.
      local mon=row.mon
      if not row.unhatched and not (mon.isEgg or mon.egg or mon.eggSpecies
          or mon.species=="EGG") then
      local _, species, record = speciesDex(game, row.mon)
      local candidate
      local alola = row.mon.formId == "ALOLA" or row.mon.form == "ALOLA"
        or type(record) == "table" and (record.formId == "ALOLA"
          or record.regionalForm == "ALOLA")
      if alola then
        content.alolaForms = true
        witnesses[#witnesses + 1] = table.concat({
          "owned", "content-alola", row.label, tostring(species),
        }, ":")
        candidate = 7
      else candidate = E.speciesEpoch(species, record) end
      -- Later gifts remain supported content, not a request to implement
      -- Gen VIII/IX rules. Capability readiness is enforced by the controller.
      if candidate then candidate = math.min(7, candidate) end
      if candidate and candidate > epoch then epoch = candidate end
      if candidate then
        witnesses[#witnesses + 1] = table.concat({
          "owned", tostring(candidate), row.label, tostring(species),
        }, ":")
      end
      end
    end
    return epoch
  end

  local function hasHoennFieldAuthority(save, bucket)
    local honeyBag = itemCount(save, "HOENN_HONEY")
    local dexBag, dexPc = itemCount(save, "HOENN_DEX")
    local field = bucket and bucket.hoenn_field_access_67
    local honeyReceipt = type(field) == "table"
      and field.honeyOwned == true
    local dexReceipt = type(field) == "table" and field.dexOwned == true
    -- AUTO advances when the path has really been activated.  Carrying the
    -- Honey once is evidence; moving it to the PC later cannot lower the
    -- monotonic unlockedEpoch.
    return (honeyBag > 0 or honeyReceipt)
      and (dexBag > 0 or dexPc > 0 or dexReceipt)
  end

  local function discoveryEpoch(bucket, witnesses)
    local root = bucket and bucket.discovery_core
    local generations = type(root) == "table" and root.generations or nil
    local epoch = 1
    for key, generation in pairs(type(generations) == "table"
        and generations or {}) do
      local number = tonumber(tostring(key):match("^gen(%d+)$"))
      local families = type(generation) == "table" and generation.families
      if number and number >= 2 and number <= 7
          and type(families) == "table" then
        for family, receipt in pairs(families) do
          -- A trace is created by an authored rumor/access transaction. A
          -- mere sighting is intentionally insufficient evidence for AUTO.
          if type(receipt) == "table" and (receipt.trace == true
              or receipt.caught == true or receipt.unlocked == true) then
            epoch = math.max(epoch, number)
            witnesses[#witnesses + 1] = table.concat({
              "story", "discovery", "gen" .. tostring(number),
              tostring(family),
            }, ":")
            break
          end
        end
      end
    end
    return epoch
  end

  function E.collect(game, save)
    save = type(save) == "table" and save or game and game.save
    local bucket = owner(save, false)
    local witnesses = {}
    local content = { alolaForms = false }
    local epoch = 1

    local beyond = bucket and bucket.beyond_kanto
    if type(beyond) == "table" and beyond.active == true then
      epoch = 2
      witnesses[#witnesses + 1] = "story:beyond_kanto.active"
    end
    if hasHoennFieldAuthority(save or {}, bucket) then
      epoch = math.max(epoch, 3)
      witnesses[#witnesses + 1] = "story:HOENN_HONEY+HOENN_DEX"
    end

    local hevo = bucket and bucket.hidden_evolution_campaign
    local completedEvolution = type(hevo) == "table"
      and (hevo.playerEvolved == true or hevo.evolutionCompleted == true)
    if completedEvolution then
      epoch = math.max(epoch, 4)
      witnesses[#witnesses + 1] = "story:hevo_evolution_completed"
    end

    epoch = math.max(epoch, discoveryEpoch(bucket, witnesses))

    epoch = math.max(epoch, ownedEpoch(game, save or {}, witnesses, content))
    table.sort(witnesses)
    return { epoch = epoch, witnesses = witnesses, content = content }
  end

  function E.addSurfaceProvider(provider)
    assert(type(provider) == "function", "generation evidence provider missing")
    surfaceProviders[#surfaceProviders + 1] = provider
    return provider
  end

  E.owner = owner
  E.itemCount = itemCount
  E.speciesDex = speciesDex
  return E
end
