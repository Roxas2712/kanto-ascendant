-- Gorochu: Raichu's discarded final evolution, restored as an Ascendant
-- guest species. The historical description establishes only the intended
-- Raichu evolution, fangs, horns and thunder-god bearing. Stats, research
-- condition, Pokédex prose and art direction are original to this mod.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local G = {
    id = "GOROCHU",
    dex = 1026,
    method = "ASCENDANT_STORM_BOND",
    animationDurations = { 120, 80, 100, 120, 80, 100 },
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function champion(save)
    return save and ((type(save.hallOfFame) == "table"
      and #save.hallOfFame > 0)
      or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL == true))
      or false
  end

  local function knowsThunder(mon)
    for _, move in ipairs(mon and mon.moves or {}) do
      local id = type(move) == "table" and move.id or move
      if id == "THUNDER" then return true end
    end
    return false
  end

  local function bonded(game, mon)
    if math.max(0, tonumber(mon and mon.johtoBond) or 0) >= 100 then
      return true
    end
    return mon and mon._ascendantYellowPartner == true
      and math.max(0, tonumber(game and game.save
        and game.save.pikachuHappiness) or 0) >= 200
  end

  local function atPowerPlant(game)
    return game and game.overworld and game.overworld.map
      and game.overworld.map.id == "POWER_PLANT"
  end

  function G.qualifies(game, mon, trigger)
    return trigger and trigger.kind == "levelup"
      and mon and mon.species == "RAICHU"
      and champion(game and game.save)
      and bonded(game, mon)
      and knowsThunder(mon)
      and atPowerPlant(game)
      or false
  end

  mod.content.evolution_methods:register(G.method, {
    check = function(game, mon, _, trigger)
      return G.qualifies(game, mon, trigger)
    end,
    describe = function()
      return tr(
        "Hall of Fame + high bond + THUNDER at POWER PLANT",
        "Ruhmeshalle + hohes Band + DONNER im KRAFTWERK")
    end,
  })

  local raichu = mod.content.pokemon:get("RAICHU")
  if not raichu then
    G.available = false
    function G.installAudio() return 0, 0 end
    return G
  end
  G.available = true
  local tmhm = {}
  for _, move in ipairs(raichu.tmhm or {}) do tmhm[#tmhm + 1] = move end

  mod.content.pokemon:register(G.id, {
    id = G.id,
    name = "GOROCHU",
    dex = G.dex,
    types = { "ELECTRIC" },
    baseStats = {
      hp = 75, attack = 115, defense = 70, speed = 110, special = 115,
    },
    catchRate = 45,
    baseExp = 215,
    growthRate = raichu.growthRate,
    level1Moves = { "THUNDERSHOCK", "BITE", "THUNDER_WAVE", "AGILITY" },
    tmhm = tmhm,
    learnset = {
      { level = 50, move = "THUNDERBOLT" },
      { level = 60, move = "BITE" },
      { level = 70, move = "AGILITY" },
      { level = 80, move = "THUNDER" },
    },
    evolutions = {},
    spriteFront = mod.path .. "/assets/crystal/gorochu_front.png",
    spriteBack = mod.path .. "/assets/crystal/gorochu_back.png",
    frontSize = 7,
    battleScaleFront = 1,
    battleScaleBack = 1,
    trueColor = true,
    icon = raichu.icon or "QUADRUPED",
    dexEntry = {
      kind = tr("THUNDER GOD", "DONNERGOTT"),
      heightFt = 4,
      heightIn = 7,
      weight = 103.6,
      heightM = 1.4,
      weightKg = 47.0,
      text = tr(
        "Its horns call storms.\nIts fangs glow before\nthe sky begins to roar.",
        "Seine Hörner rufen\nStürme. Die Fangzähne\nglühen vor dem Donner."),
    },
  })
  mod.content.icons:register(G.id, raichu.icon or "QUADRUPED")

  local evolutions = {}
  local found = false
  for _, row in ipairs(raichu.evolutions or {}) do
    local copy = {}
    for key, value in pairs(row) do copy[key] = value end
    evolutions[#evolutions + 1] = copy
    if row.species == G.id and row.method == G.method then found = true end
  end
  if not found then
    evolutions[#evolutions + 1] = {
      method = G.method,
      species = G.id,
    }
  end
  mod.content.pokemon:patch("RAICHU", { evolutions = evolutions })

  G.audio = {
    fallback = {
      base = "RAICHU",
      pitch = 80,
      length = 176,
    },
  }

  function G.installAudio(game)
    local data = game and game.data or game
    if not data then return 0, 0 end
    data.audio = data.audio or {}
    data.audio.cries = data.audio.cries or {}
    data.audio._owners = data.audio._owners or {}
    data.audio._owners.cries = data.audio._owners.cries or {}
    local installed, preserved = 0, 0
    if data.audio.cries[G.id] == nil then
      data.audio.cries[G.id] = G.audio.fallback
      data.audio._owners.cries[G.id] = mod.manifest.id
      installed = 1
    else
      preserved = 1
    end
    local species = data.pokemon and data.pokemon[G.id]
    if species then species.cry = G.id end
    local okSound, Sound = pcall(require, "src.core.Sound")
    if okSound and Sound and type(Sound.invalidate) == "function" then
      Sound.invalidate("cry:" .. G.id)
    end
    return installed, preserved
  end

  return G
end
