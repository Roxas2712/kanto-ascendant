-- Dedicated 128px FULL-Voxel opponent standees.
--
-- Native 2D uses the edition-original Gen-I trainer fronts. This table is
-- presentation-only and prevents a Voxel renderer from enlarging those
-- compact cards into pale or low-detail FULL-Voxel standees.

return function(mod, opts)
  opts = opts or {}
  local M = {}
  local GameVersion = require("src.core.GameVersion")
  local ROOT = "assets/characters/frlg_trainers/"
  local APPROVED_PROVENANCE_SHA =
    "dbb193b6df0bf295b4567f56b90d16922bc85031d140ea96a6ebdcdae66d0892"
  local APPROVED_ASSET_SHA = {
    voxel64 =
      "07fca69290146b89461746bf03777126cb0c65ff151a8a7846972481b0dbd164",
    voxel128 =
      "8b57885bdb1775bb2a43486af129976583229ca3a462e3c596943d8c55e5eb01",
    failSafe =
      "c6c086d954fe828be6f407438e0c6203d19c6d32a427c4fc2773a4ec9d65e46f",
  }
  local JESSIE_JAMES = {
    id = "YELLOW_JESSIE_JAMES_MEOWTH",
    class = "OPP_ROCKET",
    path = "assets/yellow_jessie_james/battle/"
      .. "jessie_james_meowth_voxel_front_hd.png",
    fallback = "assets/yellow_jessie_james/battle/"
      .. "jessie_james_meowth_voxel_front.png",
    failSafe = "assets/crystal_v15/trainers/normal/jessie_james.png",
    provenance = "assets/yellow_jessie_james/PROVENANCE.json",
    authored = true,
    approvedVersion = "MAINTAINER_APPROVED_2026_08_20",
    assetContract = {
      schema = "kanto-ascendant-yellow-jessie-james-battle/v1",
      requires = { jessie = true, james = true, meowth = true },
      sourceSha256 =
        "8d4b4af1515b304cb6b1121bceb00078b142706558e589790d6dca5ce137736a",
      provenance = {
        path = "assets/yellow_jessie_james/PROVENANCE.json",
        sha256 = APPROVED_PROVENANCE_SHA,
        schema = "kanto-ascendant-yellow-jessie-james-battle/v1",
        approved = true,
        decision = "approved",
        date = "2026-08-20",
        scope = "jessie-james-meowth-voxel64-voxel128",
      },
      assets = {
        voxel64 = {
          path = "assets/yellow_jessie_james/battle/"
            .. "jessie_james_meowth_voxel_front.png",
          sha256 = APPROVED_ASSET_SHA.voxel64,
        },
        voxel128 = {
          path = "assets/yellow_jessie_james/battle/"
            .. "jessie_james_meowth_voxel_front_hd.png",
          sha256 = APPROVED_ASSET_SHA.voxel128,
        },
        failSafe = {
          path = "assets/crystal_v15/trainers/normal/jessie_james.png",
          sha256 = APPROVED_ASSET_SHA.failSafe,
        },
      },
    },
  }

  local function shaReceipt(value)
    return type(value) == "string" and #value == 64
      and value:match("^[0-9a-f]+$") ~= nil
  end

  -- LÖVE owns SHA-256 in the installed game. The official Modkit's headless
  -- sandbox intentionally omits love.data, so retain the same compact
  -- LuaJIT-bit verifier used by the sealed World Rank guest authority. No
  -- path, length or decoder success is accepted as a substitute for bytes.
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
        words[index] = tobit(a * 0x1000000 + b * 0x10000
          + c * 0x100 + d)
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
        local encoded, hex = pcall(love.data.encode,
          "string", "hex", digest)
        if encoded and shaReceipt(type(hex) == "string" and hex:lower()) then
          return hex:lower()
        end
      end
    end
    return portableSha256(body)
  end
  local sha256 = opts.sha256 or defaultSha256
  local function versionFor(classId)
    -- Oak's CURRENT pair won the explicit user approval.  Every other
    -- ordinary Kanto trainer uses the approved versioned V2 redraw.
    return classId == "OPP_PROF_OAK" and "v1" or "v2"
  end
  local STEMS = {
    OPP_BEAUTY = "beauty",
    OPP_BIKER = "biker",
    OPP_BIRD_KEEPER = "bird_keeper",
    OPP_BLACKBELT = "black_belt",
    OPP_BLAINE = "leader_blaine",
    OPP_BROCK = "leader_brock",
    OPP_BUG_CATCHER = "bug_catcher",
    OPP_BURGLAR = "burglar",
    OPP_CHANNELER = "channeler",
    OPP_COOLTRAINER_F = "cool_trainer_f",
    OPP_COOLTRAINER_M = "cool_trainer_m",
    OPP_CUE_BALL = "cue_ball",
    OPP_ENGINEER = "engineer",
    OPP_ERIKA = "leader_erika",
    OPP_FISHER = "fisherman",
    OPP_GAMBLER = "gamer",
    OPP_GENTLEMAN = "gentleman",
    OPP_GIOVANNI = "leader_giovanni",
    OPP_HIKER = "hiker",
    OPP_JR_TRAINER_F = "picnicker",
    OPP_JR_TRAINER_M = "camper",
    OPP_JUGGLER = "juggler",
    OPP_KOGA = "leader_koga",
    OPP_LASS = "lass",
    OPP_LT_SURGE = "leader_lt_surge",
    OPP_MISTY = "leader_misty",
    OPP_POKEMANIAC = "pokemaniac",
    OPP_PROF_OAK = "professor_oak",
    OPP_PSYCHIC_TR = "psychic_m",
    OPP_ROCKER = "rocker",
    OPP_ROCKET = "rocket_grunt_m",
    OPP_SABRINA = "leader_sabrina",
    OPP_SAILOR = "sailor",
    OPP_SCIENTIST = "scientist",
    OPP_SUPER_NERD = "super_nerd",
    OPP_SWIMMER = "swimmer_m",
    OPP_TAMER = "tamer",
    OPP_YOUNGSTER = "youngster",
  }

  local function spec(classId, stem)
    local version = versionFor(classId)
    return {
      id = "KANTO_" .. classId:gsub("^OPP_", ""),
      class = classId,
      path = ROOT .. stem .. "_voxel_front_hd_" .. version .. ".png",
      fallback = ROOT .. stem .. "_voxel_front_" .. version .. ".png",
      authored = true,
      approvedVersion = version,
    }
  end

  function M.spec(classId)
    if classId == "KA_OAK_BETA" then classId = "OPP_PROF_OAK" end
    local stem = STEMS[classId]
    if not stem then return nil end
    local result = spec(classId, stem)
    if classId == "OPP_PROF_OAK" then result.id = "KANTO_PROFESSOR_OAK" end
    return result
  end

  -- Yellow keeps Jessie and James inside OPP_ROCKET.  Their only canonical
  -- discriminator is the original IsFightingJessieJames boundary
  -- (wTrainerNo >= $2a), plus the Yellow-only picJessieJames record.  Bind
  -- the exact live registry object as well: a copied/spoofed class row must
  -- never acquire this identity or its approved art.
  function M.jessieJamesAuthority(battle)
    if type(battle) ~= "table" or battle.oppClass ~= "OPP_ROCKET"
        or GameVersion.get() ~= "yellow" then
      return nil, "not-yellow-jessie-james"
    end
    local partyIndex = battle.partyIndex
    if type(partyIndex) ~= "number" or partyIndex ~= math.floor(partyIndex)
        or partyIndex < 42 then
      return nil, "party-index"
    end
    local game = battle.game
    local trainer = game and game.data and game.data.trainers
      and game.data.trainers.OPP_ROCKET
    if type(trainer) ~= "table" or battle.trainer ~= trainer
        or trainer.id ~= "OPP_ROCKET"
        or type(trainer.picJessieJames) ~= "string"
        or trainer.picJessieJames == ""
        or type(trainer.parties) ~= "table"
        or type(trainer.parties[partyIndex]) ~= "table" then
      return nil, "live-trainer"
    end
    return {
      schema = "ka-yellow-jessie-james-battle/v1",
      live = true,
      edition = "yellow",
      class = "OPP_ROCKET",
      partyIndex = partyIndex,
      trainerRecord = trainer,
      nativePortrait = trainer.picJessieJames,
      assetContract = JESSIE_JAMES.assetContract,
    }
  end

  function M.specForBattle(battle)
    local authority = M.jessieJamesAuthority(battle)
    if not authority then return M.spec(battle and battle.oppClass) end
    local result = spec(JESSIE_JAMES.class, "rocket_grunt_m")
    for key, value in pairs(JESSIE_JAMES) do result[key] = value end
    result.authority = authority
    return result
  end

  local function read(relative)
    if type(relative) ~= "string" or type(mod.read) ~= "function" then
      return nil, "mod-read"
    end
    local ok, bytes, problem = pcall(mod.read, mod, relative)
    if not ok or type(bytes) ~= "string" or #bytes == 0 then
      return nil, problem or bytes or "missing"
    end
    return bytes
  end

  -- Resolve only the three sealed contract paths, in quality order.  A
  -- damaged package with no authored trio still gets the bundled exact duo;
  -- if even that is absent the renderer stage is declined by the caller so
  -- BattleState can draw trainer.picJessieJames natively.
  function M.resolveJessieJamesAssets(specification)
    if type(specification) ~= "table"
        or specification.id ~= JESSIE_JAMES.id
        or type(specification.authority) ~= "table"
        or specification.authority.schema
          ~= "ka-yellow-jessie-james-battle/v1"
        or specification.authority.assetContract
          ~= specification.assetContract then
      return nil, "authority"
    end
    local contract = specification.assetContract
    local provenance = type(contract) == "table" and contract.provenance
    if contract ~= JESSIE_JAMES.assetContract
        or contract.schema
          ~= "kanto-ascendant-yellow-jessie-james-battle/v1"
        or type(contract.requires) ~= "table"
        or contract.requires.jessie ~= true
        or contract.requires.james ~= true
        or contract.requires.meowth ~= true
        or type(provenance) ~= "table"
        or provenance.path ~= specification.provenance
        or not shaReceipt(provenance.sha256)
        or provenance.sha256 ~= APPROVED_PROVENANCE_SHA
        or provenance.schema ~= contract.schema
        or provenance.approved ~= true
        or provenance.decision ~= "approved"
        or provenance.date ~= "2026-08-20"
        or provenance.scope
          ~= "jessie-james-meowth-voxel64-voxel128" then
      return nil, "provenance-contract"
    end
    local provenanceBytes, provenanceReadProblem = read(provenance.path)
    if not provenanceBytes then
      return nil, "provenance:" .. tostring(provenanceReadProblem)
    end
    local provenanceDigest, provenanceHashProblem = sha256(provenanceBytes)
    if provenanceDigest ~= APPROVED_PROVENANCE_SHA then
      return nil, provenanceDigest and "provenance-sha256"
        or tostring(provenanceHashProblem or "sha256-unavailable")
    end

    local available = {}
    local rejected = {}
    for _, row in ipairs({
      {
        role = "voxel128", path = specification.path,
        manifestRole = "voxel128",
      },
      {
        role = "voxel64", path = specification.fallback,
        manifestRole = "voxel64",
      },
      {
        role = "exact-duo-failsafe", path = specification.failSafe,
        manifestRole = "failSafe",
      },
    }) do
      local manifest = type(contract.assets) == "table"
        and contract.assets[row.manifestRole]
      local expected = APPROVED_ASSET_SHA[row.manifestRole]
      local problem
      if type(manifest) ~= "table" or manifest.path ~= row.path then
        problem = "asset-contract:" .. row.role
      elseif not shaReceipt(manifest.sha256) then
        problem = "asset-sha256-receipt:" .. row.role
      elseif manifest.sha256 ~= expected then
        problem = "asset-contract-sha256:" .. row.role
      else
        local bytes, readProblem = read(row.path)
        if not bytes then
          problem = "asset:" .. row.role .. ":" .. tostring(readProblem)
        else
          local digest, hashProblem = sha256(bytes)
          if not digest then
            problem = tostring(hashProblem or "sha256-unavailable")
              .. ":" .. row.role
          elseif digest ~= expected then
            problem = "asset-sha256:" .. row.role
          else
            row.sha256 = digest
            row.verified = true
            available[#available + 1] = row
          end
        end
      end
      if problem then rejected[#rejected + 1] = problem end
    end
    if #available == 0 then
      return nil, rejected[1] or "approved-assets-missing"
    end
    return {
      primary = available[1].path,
      fallback = (available[2] or available[1]).path,
      failSafe = available[#available].path,
      role = available[1].role,
      candidates = available,
      rejected = rejected,
      verified = true,
      contract = contract,
      provenance = specification.provenance,
      provenanceSha256 = provenanceDigest,
    }
  end

  M.stems = STEMS
  M.count = 38
  return M
end
