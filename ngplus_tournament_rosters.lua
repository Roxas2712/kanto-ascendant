-- Deterministic, authority-filtered Gen I-III opponent roster builder for the
-- post-RC2 World Rank tournaments.

return function(opts)
  opts = opts or {}
  local data = assert(opts.data, "tournament data required")
  local tournament = assert(opts.tournament, "tournament controller required")
  local generationRules = opts.generationRules
  local B = {}

  local SPECIAL_CHARACTER = {
    OPP_CYNTHIA_KA = "CYNTHIA",
    OPP_ASH_KA = "ASH",
  }
  local SPECIAL_TEAM = {
    OPP_CYNTHIA_KA = "KA_WORLD_RANK_CYNTHIA_TEAM_V1",
    OPP_ASH_KA = "KA_WORLD_RANK_ASH_TEAM_V1",
  }

  local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[clone(key, seen)] = clone(child, seen) end
    return out
  end

  local function hash(value)
    if type(tournament.hash) == "function" then return tournament.hash(value) end
    local h, source = 17, tostring(value or "")
    for index = 1, #source do
      h = (h * 131 + source:byte(index)) % 2147483647
    end
    return h
  end

  local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, first, second = pcall(fn, ...)
    if ok then return first, second end
  end

  local function assetProof(value, projectOwned)
    if type(value) ~= "table" or type(value.id) ~= "string"
        or value.id == "" or value.registered ~= true then return false end
    return not projectOwned or value.projectOwned == true
  end

  local function trainerRecord(game, classId, proof)
    local registry = game and game.data and game.data.trainers
    local live = type(registry) == "table" and registry[classId] or nil
    if type(proof) == "table" and proof.trainerRecord ~= nil
        and proof.trainerRecord ~= live then return nil end
    return live
  end

  local function hasPartyAuthority(record, proof)
    local parties = type(record) == "table" and record.parties or nil
    if type(parties) ~= "table" then return false end
    for _, party in ipairs(parties) do
      if type(party) == "table" and #party > 0 then return true end
    end
    return false
  end

  local function trainerProof(game, classId)
    if type(classId) ~= "string" or classId == "" then
      return nil, "trainer-class"
    end
    local proof = call(opts.trainerAuthority, classId, game)
    -- A truthy promise proves nothing. Selection needs the concrete registry
    -- and asset receipts that the battle and overworld will actually use.
    if type(proof) ~= "table"
        or (proof.class or proof.classId) ~= classId then
      return nil, "trainer-proof"
    end
    local record = trainerRecord(game, classId, proof)
    if not hasPartyAuthority(record, proof) then
      return nil, "trainer-team"
    end
    if not assetProof(proof.battlePortrait, false) then
      return nil, "trainer-portrait"
    end
    if type(record.pic) ~= "string" or record.pic == ""
        or proof.battlePortrait.id ~= record.pic then
      return nil, "trainer-portrait-record"
    end
    if not assetProof(proof.overworldSprite, false) then
      return nil, "trainer-overworld"
    end
    local expected = SPECIAL_CHARACTER[classId]
    if expected then
      if not assetProof(proof.character, true)
          or proof.character.id ~= expected
          or not assetProof(proof.battlePortrait, true)
          or not assetProof(proof.overworldSprite, true)
          or not assetProof(proof.team, true)
          or proof.team.id ~= SPECIAL_TEAM[classId]
          or type(proof.teamBuilder) ~= "function" then
        return nil, "trainer-character-assets"
      end
    end
    return {
      class = classId,
      trainerRecord = record,
      teamBuilder = proof.teamBuilder,
      battlePortrait = clone(proof.battlePortrait),
      overworldSprite = clone(proof.overworldSprite),
      character = expected and clone(proof.character) or nil,
      team = expected and clone(proof.team) or nil,
    }
  end

  function B.trainerProof(game, classId)
    return trainerProof(game, classId)
  end

  local function candidateSet(format)
    local result = {}
    for _, classId in ipairs(format.opponentClasses or {}) do result[classId] = true end
    return result
  end

  function B.formatAuthority(game, formatId)
    local format = type(formatId) == "table" and formatId or data.byId[formatId]
    if type(format) ~= "table" then return nil, "format" end
    local accepted, proofs, rejected = {}, {}, {}
    for _, classId in ipairs(format.opponentClasses or {}) do
      local proof, reason = trainerProof(game, classId)
      if proof then
        accepted[#accepted + 1], proofs[classId] = classId, proof
      else
        rejected[#rejected + 1] = { class = classId, reason = reason }
      end
    end
    local champions, champion = {}, nil
    for _, classId in ipairs(format.championCandidates
        or (format.champion and { format.champion }) or {}) do
      if proofs[classId] then
        champions[#champions + 1] = classId
        if not champion then champion = classId end
      end
    end
    local minimum = math.max(1,
      math.floor(tonumber(format.minimumAuthorizedOpponents) or 1))
    return {
      id = format.id,
      available = #accepted >= minimum and champion ~= nil,
      minimumAuthorizedOpponents = minimum,
      opponentClasses = accepted,
      championCandidates = champions,
      champion = champion,
      proofs = proofs,
      rejected = rejected,
      authored = format,
    }
  end

  function B.authoritySnapshot(game)
    local snapshot = { formats = {}, available = {}, unavailable = {} }
    for _, format in ipairs(data.formats or {}) do
      local report = assert(B.formatAuthority(game, format))
      snapshot.formats[format.id] = report
      local bucket = report.available and snapshot.available or snapshot.unavailable
      bucket[#bucket + 1] = format.id
    end
    return snapshot
  end

  -- Controller wiring calls this before sealing an encounter. It is the only
  -- selection path: incomplete trainer rows never enter the hash input pool.
  function B.opponentClass(game, formatId, rank, token)
    local report, reason = B.formatAuthority(game, formatId)
    if not report then return nil, reason end
    if not report.available then return nil, "format-authority" end
    if tonumber(rank) and tonumber(rank) <= 2 then return report.champion, report end
    local count = #report.opponentClasses
    if count == 0 then return nil, "format-authority" end
    local index = hash(tostring(token) .. ":class") % count + 1
    return report.opponentClasses[index], report
  end

  local function typesFor(definition)
    local types = {}
    for _, value in ipairs(type(definition.types) == "table"
        and definition.types or {}) do
      local normalized = data.normalizeType and data.normalizeType(value)
        or tostring(value):upper()
      if normalized then types[normalized] = true end
    end
    for _, key in ipairs({ "type", "type1", "type2" }) do
      if type(definition[key]) == "string" then
        local normalized = data.normalizeType
          and data.normalizeType(definition[key]) or definition[key]:upper()
        if normalized then types[normalized] = true end
      end
    end
    return types
  end

  local function canonicalDex(definition)
    for _, key in ipairs({ "nationalDex", "sourceDex", "dexNumber", "dex" }) do
      local value = tonumber(type(definition) == "table" and definition[key])
      if value and value == math.floor(value) and value > 0 then return value end
    end
  end

  local function generationAllowed(definition)
    if type(definition) ~= "table" then return false end
    if definition.originGeneration ~= nil then
      local generation = tonumber(definition.originGeneration)
      if not generation or generation ~= math.floor(generation)
          or generation < 1 or generation > (generationRules and 9 or 3) then return false end
    end
    if definition.regionalForm ~= nil and definition.regionalForm ~= false
        and tostring(definition.regionalForm) ~= "" then return false end
    return true
  end

  local function speciesRegistry(game)
    local rows, conflicts = {}, {}
    local gameData = game and game.data or {}
    local registries = { [1] = gameData.species, [2] = gameData.pokemon }
    for index = 1, 2 do
      local registry = registries[index]
      if type(registry) == "table" then
        for species, definition in pairs(registry) do
          if type(species) == "string" and type(definition) == "table" then
            local previous = rows[species]
            if previous and previous ~= definition then
              local a = canonicalDex(previous)
              local b = canonicalDex(definition)
              if a ~= b then conflicts[species] = true end
            elseif not previous then
              rows[species] = definition
            end
          end
        end
      end
    end
    for species in pairs(conflicts) do rows[species] = nil end
    return rows
  end

  local function speciesRows(game, format)
    local allowed, rows, dexOwners, duplicateDex = {}, {}, {}, {}
    for _, typeId in ipairs(format.allowedTypes or {}) do
      local normalized = data.normalizeType and data.normalizeType(typeId)
        or tostring(typeId):upper()
      if normalized then allowed[normalized] = true end
    end
    for species, definition in pairs(speciesRegistry(game)) do
      -- Extended species use private ABI slots in `dex`. National identity is
      -- always resolved before that implementation detail.
      local dex = canonicalDex(definition)
      local profileAllowed = type(generationRules) ~= "table"
        or type(generationRules.speciesAvailable) ~= "function"
        or generationRules.speciesAvailable(game, species, definition) == true
      local canonicalAllowed = not opts.canonicalSpecies
        or opts.canonicalSpecies(species,definition)==true
      if profileAllowed and canonicalAllowed and generationAllowed(definition) and dex
          and dex >= 1 and dex <= (generationRules and 1025 or 386)
          and not definition.isMega and not definition.isGigantamax then
        local owner = dexOwners[dex]
        if owner and owner ~= species then
          duplicateDex[owner], duplicateDex[species] = true, true
        else
          dexOwners[dex] = species
        end
        local types, matches = typesFor(definition), false
        for typeId in pairs(allowed) do if types[typeId] then matches = true end end
        if format.johtoOnly then
          matches = (dex >= 152 and dex <= 251) or matches
        end
        if matches then
          rows[#rows + 1] = {
            species = species, dex = dex, definition = definition,
          }
        end
      end
    end
    local filtered = {}
    for _, row in ipairs(rows) do
      if not duplicateDex[row.species] then filtered[#filtered + 1] = row end
    end
    table.sort(filtered, function(a, b)
      if a.dex ~= b.dex then return a.dex < b.dex end
      return a.species < b.species
    end)
    return filtered
  end

  local function moveDefinition(game, moveId)
    local registry = game and game.data and game.data.moves
    if type(registry) ~= "table" then return nil end
    local definition = registry[moveId]
    if type(definition) == "table" then return definition end
    if type(registry.get) == "function" then
      definition = call(registry.get, registry, moveId)
      if type(definition) == "table" then return definition end
    end
  end

  local function legalMoves(game, definition, level)
    local allowed, ordered = {}, {}
    local resolved = type(generationRules) == "table"
        and type(generationRules.resolve) == "function"
        and generationRules.resolve(game) or nil
    local function add(moveId)
      local profileAllowed = type(generationRules) ~= "table"
        or type(generationRules.moveAvailable) ~= "function"
        or generationRules.moveAvailable(moveId,
          resolved and resolved.activeEpoch or 1, game.data) == true
      if profileAllowed and type(moveId) == "string" and moveId ~= ""
          and not allowed[moveId] and moveDefinition(game, moveId) then
        allowed[moveId] = true
        ordered[#ordered + 1] = moveId
      end
    end
    for _, moveId in ipairs(type(definition.level1Moves) == "table"
        and definition.level1Moves or {}) do add(moveId) end
    for _, row in ipairs(type(definition.learnset) == "table"
        and definition.learnset or {}) do
      if type(row) == "table" and tonumber(row.level)
          and tonumber(row.level) <= level then add(row.move) end
    end
    for _, moveId in ipairs(type(definition.tmhm) == "table"
        and definition.tmhm or {}) do add(moveId) end
    return allowed, ordered
  end

  local function resolvedMoves(game, row, level, format, rank, token,
      preferredMoves)
    local recipe = data.moveRecipes
      and data.moveRecipes[format.moveRecipeId or format.id]
    if type(recipe) ~= "table" or type(recipe.priorities) ~= "table" then
      return nil, "move-recipe"
    end
    local allowed, fallback = legalMoves(game, row.definition, level)
    local selected, seen = {}, {}
    local function add(moveId)
      if #selected >= 4 or not allowed[moveId] or seen[moveId] then return end
      seen[moveId], selected[#selected + 1] = true, moveId
    end
    for _, moveId in ipairs(type(preferredMoves) == "table"
        and preferredMoves or {}) do add(moveId) end
    for _, moveId in ipairs(recipe.priorities) do add(moveId) end
    local injected = call(opts.movesFor, game, row.species, rank, token)
    for _, value in ipairs(type(injected) == "table" and injected or {}) do
      add(type(value) == "table" and value.id or value)
    end
    table.sort(fallback, function(a, b)
      local ah = hash(tostring(token) .. ":move:" .. row.species .. ":" .. a)
      local bh = hash(tostring(token) .. ":move:" .. row.species .. ":" .. b)
      if ah ~= bh then return ah < bh end
      return a < b
    end)
    for _, moveId in ipairs(fallback) do add(moveId) end
    if #selected == 0 then return nil, "move-authority" end
    local function damage(id)
      local def=moveDefinition(game,id)
      return def and ((tonumber(def.power) or 0)>0
        or def.effect=='SPECIAL_DAMAGE_EFFECT' or def.effect=='SUPER_FANG_EFFECT'
        or def.effect=='OHKO_EFFECT')
    end
    local hasDamage=false
    for _,id in ipairs(selected)do if damage(id) then hasDamage=true break end end
    if not hasDamage then
      for _,id in ipairs(fallback)do
        if damage(id) then selected[math.min(4,#selected+1)]=id;hasDamage=true;break end
      end
    end
    if not hasDamage then return nil,'no-damaging-move' end
    return selected
  end

  function B.movesFor(game, species, level, formatId, rank, token)
    local format = type(formatId) == "table" and formatId or data.byId[formatId]
    local definition = speciesRegistry(game)[species]
    if not format or not definition then return nil, "species" end
    return resolvedMoves(game, { species = species, definition = definition },
      math.max(1, math.min(100, math.floor(tonumber(level) or 1))),
      format, rank, token)
  end

  local function shuffled(rows, seed)
    local copy = {}
    for index, row in ipairs(rows) do copy[index] = row end
    for index = #copy, 2, -1 do
      local other = hash(seed .. ":shuffle:" .. index) % index + 1
      copy[index], copy[other] = copy[other], copy[index]
    end
    return copy
  end

  function B.build(game, encounter, playerParty)
    if type(encounter) ~= "table" or type(encounter.opponent) ~= "table" then
      return nil, "encounter"
    end
    local rank = tonumber(encounter.rank)
    if not rank or rank ~= rank or rank < 1 or rank > 50
        or rank ~= math.floor(rank) then return nil, "rank" end
    if type(encounter.token) ~= "string" or encounter.token == "" then
      return nil, "token"
    end
    local format = data.byId[encounter.formatId]
    if not format then return nil, "format" end
    if not candidateSet(format)[encounter.opponent.class] then
      return nil, "trainer-format"
    end
    local authority = trainerProof(game, encounter.opponent.class)
    if not authority then return nil, "trainer-authority" end
    local pool = speciesRows(game, format)
    if #pool == 0 then return nil, "species-pool" end
    local size = math.max(1, math.min(6,
      type(playerParty) == "table" and #playerParty or 0))
    local levels = tournament.scaledLevels(game, rank,
      encounter.token, size)
    if type(levels) ~= "table" or #levels < size then
      return nil, "level-authority"
    end

    -- Exact guests own fixed, versioned species recipes. The recipe may only
    -- choose species and legal-move priorities; levels remain exclusively
    -- owned by the same tournament scaler as every ordinary opponent.
    if type(authority.teamBuilder) == "function" then
      local ok, recipe, builderReason = pcall(authority.teamBuilder, game, {
        class = encounter.opponent.class,
        formatId = encounter.formatId,
        format = format,
        rank = rank,
        token = encounter.token,
        size = size,
        levels = clone(levels),
      })
      if not ok or type(recipe) ~= "table" then
        return nil, builderReason or "team-builder"
      end
      if not authority.team or recipe.id ~= authority.team.id
          or type(recipe.members) ~= "table" or #recipe.members ~= size then
        return nil, "team-receipt"
      end
      local available = {}
      for _, row in ipairs(pool) do available[row.species] = row end
      local team, used, megaSlot, megaAuthority = {}, {}, nil, nil
      for index, member in ipairs(recipe.members) do
        if type(member) ~= "table" or type(member.species) ~= "string"
            or member.species == "" or member.level ~= nil
            or member.item ~= nil or member.heldItem ~= nil
            or member.moves ~= nil
            or (member.preferredMoves ~= nil
              and type(member.preferredMoves) ~= "table")
            or used[member.species] then
          return nil, "team-member"
        end
        local row = available[member.species]
        if not row then return nil, "team-species" end
        local level = tonumber(levels[index])
        if not level or level ~= level then return nil, "level-authority" end
        level = math.max(1, math.min(100, math.floor(level)))
        local moves = resolvedMoves(game, row, level, format, rank,
          encounter.token, member.preferredMoves)
        if not moves then return nil, "move-authority" end
        team[index] = { species = member.species, level = level, moves = moves }
        used[member.species] = true
        if not megaSlot and format.megaMode == "authority_only" and rank <= 10 then
          local proof = call(opts.megaAuthority, game, member.species)
          if type(proof) == "table" and type(proof.stone) == "string"
              and proof.stone ~= "" and type(proof.form) == "string"
              and proof.form ~= "" then
            megaSlot, megaAuthority = index, proof
          end
        end
      end
      return {
        class = encounter.opponent.class,
        team = team,
        authority = authority,
        presentation = {
          battlePortrait = authority.battlePortrait.id,
          overworldSprite = authority.overworldSprite.id,
          character = authority.character and authority.character.id or nil,
        },
        mega = megaSlot and {
          slot = megaSlot,
          species = team[megaSlot].species,
          stone = megaAuthority.stone,
          form = megaAuthority.form,
        } or nil,
        policy = {
          noItems = true,
          noMega = format.megaMode == "forbidden",
          megaMode = format.megaMode,
        },
      }
    end

    local ordered = shuffled(pool, tostring(encounter.token))

    local megaRow, megaAuthority
    if format.megaMode == "authority_only" and rank <= 10 then
      for _, row in ipairs(ordered) do
        local proof = call(opts.megaAuthority, game, row.species)
        if type(proof) == "table" and type(proof.stone) == "string"
            and proof.stone ~= "" and type(proof.form) == "string"
            and proof.form ~= "" then
          megaRow, megaAuthority = row, proof
          break
        end
      end
    end

    local selected, used = {}, {}
    if megaRow then selected[1], used[megaRow.species] = megaRow, true end
    local cursor = hash(tostring(encounter.token) .. ":cursor") % #ordered + 1
    while #selected < size do
      local row = ordered[cursor]
      if not used[row.species] or #pool < size then
        selected[#selected + 1] = row
        used[row.species] = true
      end
      cursor = cursor % #ordered + 1
    end
    selected = shuffled(selected, tostring(encounter.token) .. ":order")
    local team, megaSlot = {}, nil
    for index, row in ipairs(selected) do
      local level = tonumber(levels[index])
      if not level then return nil, "level-authority" end
      level = math.max(1, math.min(100, math.floor(level)))
      local moves = resolvedMoves(game, row, level, format,
        rank, encounter.token)
      if not moves then return nil, "move-authority" end
      team[index] = { species = row.species, level = level, moves = moves }
      if megaRow and row.species == megaRow.species then megaSlot = index end
    end
    return {
      class = encounter.opponent.class,
      team = team,
      authority = authority,
      presentation = {
        battlePortrait = authority.battlePortrait.id,
        overworldSprite = authority.overworldSprite.id,
        character = authority.character and authority.character.id or nil,
      },
      mega = megaSlot and {
        slot = megaSlot,
        species = megaRow.species,
        stone = megaAuthority.stone,
        form = megaAuthority.form,
      } or nil,
      policy = {
        noItems = true,
        noMega = format.megaMode == "forbidden",
        megaMode = format.megaMode,
      },
    }
  end

  B.speciesRows = speciesRows
  return B
end
