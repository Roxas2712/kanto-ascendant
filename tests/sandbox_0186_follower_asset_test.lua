-- A stale external Followers-EX/PokePC path must never reach SpriteRenderer.
-- Engine Assets.exists selects the first real fallback in the no-debug
-- 0.1.86 path.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local existing = {
  ["mods/ext/assets/sprites/follower_CHARMANDER.png"] = true,
}
package.loaded["src.render.Assets"] = nil
package.preload["src.render.Assets"] = function()
  return { exists = function(path) return existing[path] == true end }
end

local rendered
local SpriteRenderer = { new = function(def)
  rendered = {
    image = def.image, frames = def.frames,
    walker = def.walker, trueColor = def.trueColor,
  }
  return rendered
end }
package.loaded["src.render.SpriteRenderer"] = nil
package.preload["src.render.SpriteRenderer"] = function() return SpriteRenderer end

local mon = { species = "CHIKORITA", hp = 20 }
local api = {
  activeMon = function() return mon end,
  assetPath = function(species)
    return "mods/ext/assets/sprites/follower_" .. species .. ".png"
  end,
}
local game = {
  save = { party = { mon } },
  data = {
    pokemon = { CHIKORITA = { dex = 152, types = { "GRASS" } } },
    sprites = { SPRITE_PIKACHU = {
      id = "SPRITE_PIKACHU", image = "stale-external", frames = 6,
    } },
  },
  mods = { exports = { FOLLOWERS_EX = api } },
}
local mod = {
  path = root,
  read = function() return nil end,
  find = function(id)
    return id == "FOLLOWERS_EX" and { id = id, exports = api } or nil
  end,
  log = { info = function() end },
}

local savedDebug = debug
_G.debug = nil
local compat = assert(loadfile(root .. "/follower_compat.lua"))()(mod, {
  spriteAssets = { follower = function() return nil end },
})
assert(compat.install(game), "no-debug renderer guard did not install")
SpriteRenderer.new(game.data.sprites.SPRITE_PIKACHU, 1)
assert(rendered.image == "mods/ext/assets/sprites/follower_CHARMANDER.png",
  "missing species/proxy path did not use the first existing Kanto fallback")
assert(rendered.frames == 6 and rendered.walker and rendered.trueColor,
  "valid external fallback lost six-pose renderer metadata")

existing["mods/ext/assets/sprites/follower_CHARMANDER.png"] = nil
game.data.sprites.SPRITE_PIKACHU.image = "known-safe-existing-renderer"
SpriteRenderer.new(game.data.sprites.SPRITE_PIKACHU, 2)
assert(rendered.image == "known-safe-existing-renderer",
  "all-missing external paths replaced the existing renderer with a bad path")

compat.restore()
_G.debug = savedDebug

print("PASS sandbox 0.1.86 follower assets: stale external paths fail closed")
