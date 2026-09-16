-- Pure LuaJIT-compatible SHA-256 used by Legacy Bank portable packages.
-- The engine's runtime can hash through love.data, but keeping this tiny
-- data-only implementation inside KASC gives headless migration tools and the
-- game the exact same byte contract.

local function makeDigest()
  local bit = require("bit")
  local band, bor, bxor = bit.band, bit.bor, bit.bxor
  local bnot, rshift, lshift = bit.bnot, bit.rshift, bit.lshift

  local K = {
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

  local function add(...)
    local sum = 0
    for index = 1, select("#", ...) do
      sum = (sum + (select(index, ...) % 0x100000000)) % 0x100000000
    end
    return bit.tobit(sum)
  end

  local function rotr(value, amount)
    return bor(rshift(value, amount), lshift(value, 32 - amount))
  end

  local function be32(value)
    value = value % 0x100000000
    return string.char(
      math.floor(value / 0x1000000) % 256,
      math.floor(value / 0x10000) % 256,
      math.floor(value / 0x100) % 256,
      value % 256)
  end

  local function digest(message)
    assert(type(message) == "string", "SHA-256 input must be a string")
    local byteLength = #message
    local bitLength = byteLength * 8
    local padding = (56 - ((byteLength + 1) % 64)) % 64
    message = message .. "\128" .. string.rep("\0", padding)
      .. be32(math.floor(bitLength / 0x100000000))
      .. be32(bitLength)

    local h = {
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    }
    local w = {}
    for offset = 1, #message, 64 do
      for index = 0, 15 do
        local a, b, c, d = message:byte(offset + index * 4,
          offset + index * 4 + 3)
        w[index] = bit.tobit(((a * 256 + b) * 256 + c) * 256 + d)
      end
      for index = 16, 63 do
        local x, y = w[index - 15], w[index - 2]
        local s0 = bxor(rotr(x, 7), rotr(x, 18), rshift(x, 3))
        local s1 = bxor(rotr(y, 17), rotr(y, 19), rshift(y, 10))
        w[index] = add(w[index - 16], s0, w[index - 7], s1)
      end

      local a, b, c, d = h[1], h[2], h[3], h[4]
      local e, f, g, hh = h[5], h[6], h[7], h[8]
      for index = 0, 63 do
        local s1 = bxor(rotr(e, 6), rotr(e, 11), rotr(e, 25))
        local choose = bxor(band(e, f), band(bnot(e), g))
        local t1 = add(hh, s1, choose, K[index + 1], w[index])
        local s0 = bxor(rotr(a, 2), rotr(a, 13), rotr(a, 22))
        local majority = bxor(band(a, b), band(a, c), band(b, c))
        local t2 = add(s0, majority)
        hh, g, f, e = g, f, e, add(d, t1)
        d, c, b, a = c, b, a, add(t1, t2)
      end
      h[1], h[2], h[3], h[4] = add(h[1], a), add(h[2], b),
        add(h[3], c), add(h[4], d)
      h[5], h[6], h[7], h[8] = add(h[5], e), add(h[6], f),
        add(h[7], g), add(h[8], hh)
    end

    local out = {}
    for index = 1, 8 do out[index] = bit.tohex(h[index], 8) end
    return table.concat(out)
  end

  return digest
end

return makeDigest()
