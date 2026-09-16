-- Exact World Rank guest registration and authority receipts.
--
-- Cynthia and Ash are never inferred from a trainer class. Each identity is
-- enabled independently only when its four approved project surfaces, public
-- provenance receipt, content registrations and live runtime rows all agree.

return function(mod, opts)
  opts = opts or {}
  local json = assert(opts.json, "World Rank guest JSON decoder required")
  local G = { registered = false }
  local ROOT = "assets/world_rank/"
  local PROVENANCE = ROOT .. "PROVENANCE.json"
  local COMPLETE_VISUAL_STATUS = "approved-by-maintainer-2026-08-20"
  local ASSET_VISUAL_STATUS = {
    walk = COMPLETE_VISUAL_STATUS,
    front = "approved-by-maintainer-2026-08-19",
    voxel64 = "approved-by-maintainer-2026-08-19",
    voxel128 = "approved-by-maintainer-2026-08-19",
  }

  local SPECS = {
    CYNTHIA = {
      class = "OPP_CYNTHIA_KA",
      character = "CYNTHIA",
      sprite = "SPRITE_KA_WORLD_RANK_CYNTHIA",
      team = "KA_WORLD_RANK_CYNTHIA_TEAM_V1",
      name = { en = "CYNTHIA", de = "CYNTHIA" },
      stem = "cynthia",
      -- Deliberately a Kanto Ascendant Retro team using only Gen I-III.
      -- It is not represented as Cynthia's canonical Generation-IV roster.
      recipe = {
        { species = "GENGAR", preferredMoves = {
          "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "DREAM_EATER" } },
        { species = "TOGETIC", preferredMoves = {
          "FLY", "PSYCHIC_M", "DOUBLE_EDGE", "CONFUSE_RAY" } },
        { species = "ARCANINE", preferredMoves = {
          "FIRE_BLAST", "BODY_SLAM", "DIG", "REFLECT" } },
        { species = "LAPRAS", preferredMoves = {
          "SURF", "BLIZZARD", "THUNDERBOLT", "BODY_SLAM" } },
        { species = "DRAGONITE", preferredMoves = {
          "BLIZZARD", "THUNDER", "SURF", "HYPER_BEAM" } },
        { species = "SCEPTILE", preferredMoves = {
          "MEGA_DRAIN", "AGILITY", "SLAM", "EARTHQUAKE" } },
      },
    },
    ASH = {
      class = "OPP_ASH_KA",
      character = "ASH",
      sprite = "SPRITE_KA_WORLD_RANK_ASH",
      team = "KA_WORLD_RANK_ASH_TEAM_V1",
      name = { en = "ASH", de = "ASH" },
      stem = "ash",
      recipe = {
        { species = "PIKACHU", preferredMoves = {
          "THUNDERBOLT", "QUICK_ATTACK", "THUNDER_WAVE", "BODY_SLAM" } },
        { species = "CHARIZARD", preferredMoves = {
          "FIRE_BLAST", "SWORDS_DANCE", "SLASH", "EARTHQUAKE" } },
        { species = "BULBASAUR", preferredMoves = {
          "RAZOR_LEAF", "SLEEP_POWDER", "BODY_SLAM", "LEECH_SEED" } },
        { species = "SQUIRTLE", preferredMoves = {
          "SURF", "ICE_BEAM", "BODY_SLAM", "WITHDRAW" } },
        { species = "SNORLAX", preferredMoves = {
          "BODY_SLAM", "REST", "EARTHQUAKE", "HYPER_BEAM" } },
        { species = "HERACROSS", preferredMoves = {
          "PIN_MISSILE", "COUNTER", "EARTHQUAKE", "TAKE_DOWN" } },
      },
    },
  }

  for _, spec in pairs(SPECS) do
    spec.assets = {
      walk = ROOT .. "field/" .. spec.stem .. "_walk.png",
      front = ROOT .. "battle/" .. spec.stem .. "_front.png",
      voxel64 = ROOT .. "battle/" .. spec.stem .. "_voxel_front.png",
      voxel128 = ROOT .. "battle/" .. spec.stem .. "_voxel_front_hd.png",
    }
  end

  local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[clone(key, seen)] = clone(child, seen) end
    return result
  end

  local function runtimePath(relative)
    return mod.path .. "/" .. relative
  end

  local function read(relative)
    if type(mod.read) ~= "function" then return nil, "mod-read" end
    local ok, bytes, problem = pcall(mod.read, mod, relative)
    if not ok or bytes == nil or bytes == false then
      return nil, problem or bytes or "missing"
    end
    return bytes
  end

  local function shaReceipt(value)
    return type(value) == "string" and #value == 64
      and value:match("^[0-9a-f]+$") ~= nil
  end

  -- LÖVE provides SHA-256 in the shipped game, but the official Modkit
  -- sandbox deliberately exposes no `love.data` helper. Keep one compact
  -- LuaJIT-bit implementation here so the exact same byte receipt is checked
  -- in installed games, package validation and both supported engine suites.
  -- This is a verifier only: it never accepts a size/name substitute for the
  -- manifest's full SHA-256 digest.
  local portableBit
  local function portableSha256(body)
    if type(body) ~= "string" then return nil, "sha256-input" end
    local bitlib = portableBit
    if not bitlib then
      bitlib = type(bit) == "table" and bit or nil
      if not bitlib and type(require) == "function" then
        local ok, loaded = pcall(require, "bit")
        if ok and type(loaded) == "table" then bitlib = loaded end
      end
      if not (bitlib and type(bitlib.band) == "function"
          and type(bitlib.bxor) == "function"
          and type(bitlib.bnot) == "function"
          and type(bitlib.rshift) == "function"
          and type(bitlib.ror) == "function"
          and type(bitlib.tobit) == "function") then
        return nil, "sha256-unavailable"
      end
      portableBit = bitlib
    end

    local band, bxor, bnot = bitlib.band, bitlib.bxor, bitlib.bnot
    local rshift, ror, tobit = bitlib.rshift, bitlib.ror, bitlib.tobit
    local function add32(...)
      local sum = 0
      for index = 1, select("#", ...) do
        sum = sum + select(index, ...)
      end
      return tobit(sum)
    end
    local constants = {
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
      0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
      0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
      0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
      0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
      0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    }
    local digest = {
      tobit(0x6a09e667), tobit(0xbb67ae85),
      tobit(0x3c6ef372), tobit(0xa54ff53a),
      tobit(0x510e527f), tobit(0x9b05688c),
      tobit(0x1f83d9ab), tobit(0x5be0cd19),
    }

    local bitLength = #body * 8
    local high = math.floor(bitLength / 4294967296)
    local low = bitLength - high * 4294967296
    local function lengthByte(value, shift)
      return band(rshift(value, shift), 0xff)
    end
    local zeroes = (56 - ((#body + 1) % 64)) % 64
    local padded = body .. string.char(0x80) .. string.rep("\0", zeroes)
      .. string.char(
        lengthByte(high, 24), lengthByte(high, 16),
        lengthByte(high, 8), lengthByte(high, 0),
        lengthByte(low, 24), lengthByte(low, 16),
        lengthByte(low, 8), lengthByte(low, 0))

    for offset = 1, #padded, 64 do
      local words = {}
      for index = 0, 15 do
        local cursor = offset + index * 4
        local a, b, c, d = padded:byte(cursor, cursor + 3)
        words[index] = tobit(a * 0x1000000 + b * 0x10000 + c * 0x100 + d)
      end
      for index = 16, 63 do
        local s0 = bxor(ror(words[index - 15], 7),
          ror(words[index - 15], 18), rshift(words[index - 15], 3))
        local s1 = bxor(ror(words[index - 2], 17),
          ror(words[index - 2], 19), rshift(words[index - 2], 10))
        words[index] = add32(words[index - 16], s0,
          words[index - 7], s1)
      end

      local a, b, c, d = digest[1], digest[2], digest[3], digest[4]
      local e, f, g, h = digest[5], digest[6], digest[7], digest[8]
      for index = 0, 63 do
        local upperE = bxor(ror(e, 6), ror(e, 11), ror(e, 25))
        local choose = bxor(band(e, f), band(bnot(e), g))
        local temp1 = add32(h, upperE, choose,
          constants[index + 1], words[index])
        local upperA = bxor(ror(a, 2), ror(a, 13), ror(a, 22))
        local majority = bxor(band(a, b), band(a, c), band(b, c))
        local temp2 = add32(upperA, majority)
        h, g, f, e, d, c, b, a =
          g, f, e, add32(d, temp1), c, b, a, add32(temp1, temp2)
      end
      digest[1], digest[2], digest[3], digest[4] =
        add32(digest[1], a), add32(digest[2], b),
        add32(digest[3], c), add32(digest[4], d)
      digest[5], digest[6], digest[7], digest[8] =
        add32(digest[5], e), add32(digest[6], f),
        add32(digest[7], g), add32(digest[8], h)
    end

    local result = {}
    for index, value in ipairs(digest) do
      if value < 0 then value = value + 4294967296 end
      result[index] = ("%08x"):format(value)
    end
    return table.concat(result)
  end

  local function defaultSha256(body)
    if love and love.data and type(love.data.hash) == "function"
        and type(love.data.encode) == "function" then
      local ok, digest = pcall(love.data.hash, "sha256", body)
      if ok then
        if type(digest) == "userdata" and digest.getString then
          digest = digest:getString()
        end
        local encoded, hex = pcall(love.data.encode, "string", "hex", digest)
        if encoded and shaReceipt(type(hex) == "string" and hex:lower()) then
          return hex:lower()
        end
      end
    end
    return portableSha256(body)
  end
  local sha256 = opts.sha256 or defaultSha256

  local function provenance()
    local raw, problem = read(PROVENANCE)
    if type(raw) ~= "string" then return nil, problem or "provenance" end
    local ok, receipt = pcall(json.decode, raw)
    if not ok or type(receipt) ~= "table"
        or receipt.schema ~= "kanto-ascendant-world-rank-guests/v1"
        or receipt.approved ~= true
        or receipt.visualStatus ~= COMPLETE_VISUAL_STATUS
        or receipt.ownership
          ~= "credited-mixed-authority-derivative-with-imagegen-battle-art"
        or type(receipt.maintainerApproval) ~= "table"
        or receipt.maintainerApproval.decision ~= "approved"
        or receipt.maintainerApproval.date ~= "2026-08-20"
        or receipt.maintainerApproval.scope
          ~= "cynthia-ash-all-four-surfaces"
        or type(receipt.guests) ~= "table" then
      return nil, "provenance"
    end
    return receipt
  end

  local function approved(spec, manifest)
    local row = manifest and manifest.guests
      and manifest.guests[spec.character]
    if type(row) ~= "table" or row.approved ~= true
        or row.visualStatus ~= COMPLETE_VISUAL_STATUS
        or row.class ~= spec.class or row.character ~= spec.character
        or row.team ~= spec.team or type(row.assets) ~= "table" then
      return nil, "provenance-identity"
    end
    for role, relative in pairs(spec.assets) do
      local asset = row.assets[role]
      if type(asset) ~= "table" or asset.path ~= relative
          or asset.approved ~= true
          or asset.visualStatus ~= ASSET_VISUAL_STATUS[role]
          or not shaReceipt(asset.sha256) then
        return nil, "provenance-asset:" .. role
      end
      local bytes = read(relative)
      if not bytes then return nil, "asset:" .. role end
      local digest, digestReason = sha256(bytes)
      if not digest then
        return nil, (digestReason or "sha256-unavailable") .. ":" .. role
      end
      if digest ~= asset.sha256 then return nil, "asset-sha256:" .. role end
    end
    return clone(row)
  end

  local function registryValue(registry, id)
    if not (registry and type(registry.get) == "function") then return nil end
    local ok, value = pcall(registry.get, registry, id)
    if ok and type(value) == "table" then return value end
  end

  -- Content registries do not expose a rollback operation. Check both exact
  -- live ids before the first write so a trainer-only collision cannot leave
  -- an orphaned World Rank walker (and the inverse cannot leave a trainer).
  -- Mod loading is single-threaded, so this is an atomic collision preflight
  -- for the supported registry contract.
  local function registrationPreflight(spec)
    local sprites = mod.content and mod.content.sprites
    local trainers = mod.content and mod.content.trainers
    if not (sprites and type(sprites.get) == "function"
        and type(sprites.register) == "function"
        and trainers and type(trainers.get) == "function"
        and type(trainers.register) == "function") then
      return nil, "registration"
    end
    local spriteOk, sprite = pcall(sprites.get, sprites, spec.sprite)
    local trainerOk, trainer = pcall(trainers.get, trainers, spec.class)
    if not spriteOk or not trainerOk or sprite ~= nil or trainer ~= nil then
      return nil, "registration"
    end
    return true
  end

  local function ownsMove(definition, moveId)
    for _, source in ipairs({ definition.level1Moves, definition.learnset,
        definition.tmhm }) do
      for _, row in ipairs(type(source) == "table" and source or {}) do
        if row == moveId or type(row) == "table" and row.move == moveId then
          return true
        end
      end
    end
    return false
  end

  -- A portrait cannot authorize an empty or invented team.  Seal each guest
  -- only after all six exact Gen-I--III species, both battle sides and every
  -- authored move priority exist in the same merged content registries that
  -- the tournament builder will consume.  This check is per identity: one
  -- incomplete recipe never suppresses the other guest.
  local function teamAuthority(spec)
    if type(spec.recipe) ~= "table" or #spec.recipe ~= 6 then
      return nil, "team-size"
    end
    local pokemon = mod.content and mod.content.pokemon
    local moves = mod.content and mod.content.moves
    local used = {}
    for _, member in ipairs(spec.recipe) do
      local species = type(member) == "table" and member.species or nil
      if type(species) ~= "string" or species == "" or used[species] then
        return nil, "team-species"
      end
      used[species] = true
      local definition = registryValue(pokemon, species)
      if not definition then return nil, "team-species:" .. species end
      local dex = tonumber(definition.nationalDex or definition.sourceDex
        or definition.dexNumber or definition.dex)
      if not dex or dex < 1 or dex > 386 then
        return nil, "team-generation:" .. species
      end
      if type(definition.spriteFront) ~= "string"
          or definition.spriteFront == ""
          or type(definition.spriteBack) ~= "string"
          or definition.spriteBack == "" then
        return nil, "team-battle-art:" .. species
      end
      if type(member.preferredMoves) ~= "table"
          or #member.preferredMoves ~= 4 then
        return nil, "team-moves:" .. species
      end
      local seenMoves = {}
      for _, moveId in ipairs(member.preferredMoves) do
        if type(moveId) ~= "string" or moveId == "" or seenMoves[moveId]
            or not registryValue(moves, moveId)
            or not ownsMove(definition, moveId) then
          return nil, "team-move:" .. species .. ":" .. tostring(moveId)
        end
        seenMoves[moveId] = true
      end
    end
    return true
  end

  local function teamBuilder(spec)
    return function(_, context)
      context = type(context) == "table" and context or {}
      local size = tonumber(context.size)
      if not size or size ~= math.floor(size) or size < 1 or size > 6 then
        return nil, "team-size"
      end
      local members = {}
      for index = 1, size do members[index] = clone(spec.recipe[index]) end
      return { id = spec.team, members = members }
    end
  end

  local registrations = {}
  local status = { schema = "ka-world-rank-guests/status-v1", guests = {} }

  function G.register()
    if G.registered then
      return next(registrations) ~= nil,
        next(registrations) and nil or "no-approved-guests"
    end
    G.registered = true
    local manifest, manifestReason = provenance()
    for _, character in ipairs({ "CYNTHIA", "ASH" }) do
      local spec = SPECS[character]
      local receipt, reason
      if manifest then receipt, reason = approved(spec, manifest)
      else reason = manifestReason end
      if receipt then
        local complete, teamReason = teamAuthority(spec)
        if not complete then receipt, reason = nil, teamReason end
      end
      if receipt then
        local sprite = {
          id = spec.sprite,
          image = runtimePath(spec.assets.walk),
          frames = 6, walker = true, trueColor = true,
        }
        local baseline = {}
        for index, member in ipairs(spec.recipe) do
          baseline[index] = { species = member.species, level = 80 }
        end
        local trainer = {
          id = spec.class,
          name = opts.i18n and opts.i18n.text(spec.name.en, spec.name.de)
            or spec.name.en,
          pic = runtimePath(spec.assets.front),
          trueColor = true, baseMoney = 0,
          battleTheme = opts.battleTheme or "Music_KA_GSC_RivalBattle",
          parties = { baseline },
        }
        -- Validate both slots before either registry mutates. The previous
        -- sprite-first write left an orphaned walker when only the trainer
        -- class was occupied by another mod.
        local readyToRegister, registrationReason =
          registrationPreflight(spec)
        local registered = readyToRegister and pcall(function()
          mod.content.sprites:register(spec.sprite, sprite)
          mod.content.trainers:register(spec.class, trainer)
        end)
        if registered then
          registrations[spec.class] = {
            spec = spec, receipt = receipt, sprite = sprite, trainer = trainer,
            teamBuilder = teamBuilder(spec),
          }
          status.guests[character] = { ready = true, class = spec.class,
            sprite = spec.sprite, team = spec.team }
        else
          status.guests[character] = { ready = false, class = spec.class,
            reason = registrationReason or "registration" }
        end
      else
        status.guests[character] = { ready = false, class = spec.class,
          reason = reason or "unapproved" }
      end
    end
    return next(registrations) ~= nil,
      next(registrations) and nil or "no-approved-guests"
  end

  function G.authority(classId, game)
    local row = registrations[classId]
    if not row then return nil, "guest-unregistered" end
    local data = game and game.data
    local trainer = data and data.trainers and data.trainers[classId]
    local sprite = data and data.sprites and data.sprites[row.spec.sprite]
    local expectedPortrait = runtimePath(row.spec.assets.front)
    local expectedWalker = runtimePath(row.spec.assets.walk)
    if trainer ~= row.trainer or type(trainer) ~= "table"
        or trainer.id ~= classId
        or trainer.pic ~= expectedPortrait or trainer.trueColor ~= true
        or type(trainer.parties) ~= "table" or type(trainer.parties[1]) ~= "table"
        or #trainer.parties[1] < 1 then
      return nil, "live-trainer"
    end
    if sprite ~= row.sprite or type(sprite) ~= "table"
        or sprite.id ~= row.spec.sprite
        or sprite.image ~= expectedWalker or sprite.frames ~= 6
        or sprite.walker ~= true or sprite.trueColor ~= true then
      return nil, "live-sprite"
    end
    return {
      schema = "ka-world-rank-guest-authority/v1",
      live = true,
      class = classId,
      trainerRecord = trainer,
      teamBuilder = row.teamBuilder,
      team = { id = row.spec.team, registered = true, projectOwned = true },
      battlePortrait = {
        id = expectedPortrait, registered = true, projectOwned = true,
      },
      overworldSprite = {
        id = row.spec.sprite, registered = true, projectOwned = true,
      },
      character = {
        id = row.spec.character, registered = true, projectOwned = true,
      },
      provenance = clone(row.receipt),
    }
  end

  function G.status()
    return clone(status)
  end

  function G.spec(classId)
    for _, spec in pairs(SPECS) do
      if spec.class == classId then return clone(spec) end
    end
  end

  G.SPECS = SPECS
  G.PROVENANCE = PROVENANCE
  return G
end
