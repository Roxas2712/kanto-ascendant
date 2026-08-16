-- KA-INTERNAL: LEGACY-JOURNEY-002
--
-- The three Hoenn starter families are a deliberately narrow National-Dex
-- extension.  They exist only as earned Legacy starter choices; no Hoenn
-- region, filler Dex range or wild encounter table is implied.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local H = {
    order = {
      "TREECKO", "GROVYLE", "SCEPTILE",
      "TORCHIC", "COMBUSKEN", "BLAZIKEN",
      "MUDKIP", "MARSHTOMP", "SWAMPERT",
    },
    bySeal = { red = "TORCHIC", blue = "MUDKIP", green = "TREECKO" },
    byKantoStarter = {
      CHARMANDER = { seal = "red", species = "TORCHIC" },
      SQUIRTLE = { seal = "blue", species = "MUDKIP" },
      BULBASAUR = { seal = "green", species = "TREECKO" },
    },
  }

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  local rows = {
    TREECKO = {
      dex = 252, name = "TREECKO", de = "GECKARBOR", types = { "GRASS" },
      stats = { hp = 40, attack = 45, defense = 35, speed = 70, special = 60 },
      catch = 45, exp = 62, height = 0.5, weight = 5.0,
      level1 = { "POUND", "LEER" },
      learn = { { 6, "ABSORB" }, { 11, "QUICK_ATTACK" },
        { 21, "MEGA_DRAIN" }, { 31, "AGILITY" }, { 41, "SLAM" } },
      evo = { 16, "GROVYLE" }, kind = { "WOOD GECKO", "WALDGECKO" },
      text = { "Its hooked feet grip bark, letting it race across tall trees.",
        "Seine Hakenfüße finden Halt, selbst wenn es hohe Bäume hinaufeilt." },
      icon = "GRASS",
    },
    GROVYLE = {
      dex = 253, name = "GROVYLE", de = "REPTAIN", types = { "GRASS" },
      stats = { hp = 50, attack = 65, defense = 45, speed = 95, special = 75 },
      catch = 45, exp = 142, height = 0.9, weight = 21.6,
      level1 = { "POUND", "LEER", "ABSORB", "QUICK_ATTACK" },
      learn = { { 21, "MEGA_DRAIN" }, { 31, "AGILITY" }, { 41, "SLAM" } },
      evo = { 36, "SCEPTILE" }, kind = { "WOOD GECKO", "WALDGECKO" },
      text = { "Leaflike growths hide it among dense branches while it watches below.",
        "Blattartige Triebe tarnen es in dichten Kronen, während es hinabblickt." },
      icon = "GRASS",
    },
    SCEPTILE = {
      dex = 254, name = "SCEPTILE", de = "GEWALDRO", types = { "GRASS" },
      stats = { hp = 70, attack = 85, defense = 65, speed = 120, special = 95 },
      catch = 45, exp = 239, height = 1.7, weight = 52.2,
      level1 = { "POUND", "LEER", "ABSORB", "QUICK_ATTACK" },
      learn = { { 21, "MEGA_DRAIN" }, { 31, "AGILITY" },
        { 41, "SLAM" }, { 51, "SOLARBEAM" } },
      kind = { "FOREST", "DSCHUNGEL" },
      text = { "It protects old forests and strikes before an intruder can react.",
        "Es schützt alte Wälder und greift an, ehe ein Eindringling reagieren kann." },
      icon = "GRASS",
    },
    TORCHIC = {
      dex = 255, name = "TORCHIC", de = "FLEMMLI", types = { "FIRE" },
      stats = { hp = 45, attack = 60, defense = 40, speed = 45, special = 60 },
      catch = 45, exp = 62, height = 0.4, weight = 2.5,
      level1 = { "SCRATCH", "GROWL" },
      learn = { { 7, "FOCUS_ENERGY" }, { 10, "EMBER" }, { 16, "PECK" },
        { 25, "SAND_ATTACK" }, { 34, "SLASH" }, { 43, "FIRE_SPIN" } },
      evo = { 16, "COMBUSKEN" }, kind = { "CHICK", "KÜKEN" },
      text = { "A warm flame burns inside it and flares when danger draws near.",
        "In seinem Inneren brennt eine warme Flamme, die bei Gefahr aufflackert." },
      icon = "BIRD",
    },
    COMBUSKEN = {
      dex = 256, name = "COMBUSKEN", de = "JUNGGLUT", types = { "FIRE", "FIGHTING" },
      stats = { hp = 60, attack = 85, defense = 60, speed = 55, special = 72 },
      catch = 45, exp = 142, height = 0.9, weight = 19.5,
      level1 = { "SCRATCH", "GROWL", "EMBER", "PECK" },
      learn = { { 20, "DOUBLE_KICK" }, { 28, "SAND_ATTACK" },
        { 36, "SLASH" }, { 44, "FIRE_SPIN" } },
      evo = { 36, "BLAZIKEN" }, kind = { "YOUNG FOWL", "KLEINHAHN" },
      text = { "Constant training hardens its legs and sharpens its fiery kicks.",
        "Ständiges Training kräftigt seine Beine und schärft seine Feuertritte." },
      icon = "BIRD",
    },
    BLAZIKEN = {
      dex = 257, name = "BLAZIKEN", de = "LOHGOCK", types = { "FIRE", "FIGHTING" },
      stats = { hp = 80, attack = 120, defense = 70, speed = 80, special = 90 },
      catch = 45, exp = 239, height = 1.9, weight = 52.0,
      level1 = { "SCRATCH", "GROWL", "EMBER", "DOUBLE_KICK" },
      learn = { { 28, "SAND_ATTACK" }, { 36, "SLASH" },
        { 44, "FIRE_SPIN" }, { 52, "FIRE_BLAST" } },
      kind = { "BLAZE", "GROSSBRAND" },
      text = { "Flames stream from its wrists when its powerful kicks reach full force.",
        "Flammen strömen aus seinen Handgelenken, wenn seine Tritte volle Kraft erreichen." },
      icon = "BIRD",
    },
    MUDKIP = {
      dex = 258, name = "MUDKIP", de = "HYDROPI", types = { "WATER" },
      stats = { hp = 50, attack = 70, defense = 50, speed = 40, special = 50 },
      catch = 45, exp = 62, height = 0.4, weight = 7.6,
      level1 = { "TACKLE", "GROWL" },
      learn = { { 6, "MUD_SLAP" }, { 10, "WATER_GUN" }, { 19, "BIDE" },
        { 28, "TAKE_DOWN" }, { 37, "HYDRO_PUMP" } },
      evo = { 16, "MARSHTOMP" }, kind = { "MUD FISH", "SCHLAMMFISCH" },
      text = { "Its head fin senses currents and warns it of nearby movement.",
        "Seine Kopfflosse spürt Strömungen und warnt es vor Bewegungen in der Nähe." },
      icon = "WATER",
    },
    MARSHTOMP = {
      dex = 259, name = "MARSHTOMP", de = "MOORABBEL", types = { "WATER", "GROUND" },
      stats = { hp = 70, attack = 85, defense = 70, speed = 50, special = 65 },
      catch = 45, exp = 142, height = 0.7, weight = 28.0,
      level1 = { "TACKLE", "GROWL", "MUD_SLAP", "WATER_GUN" },
      learn = { { 19, "BIDE" }, { 28, "TAKE_DOWN" },
        { 37, "HYDRO_PUMP" }, { 46, "EARTHQUAKE" } },
      evo = { 36, "SWAMPERT" }, kind = { "MUD FISH", "SCHLAMMFISCH" },
      text = { "It moves more freely through mud than across dry, solid ground.",
        "Durch Schlamm bewegt es sich leichter als über trockenen, festen Boden." },
      icon = "WATER",
    },
    SWAMPERT = {
      dex = 260, name = "SWAMPERT", de = "SUMPEX", types = { "WATER", "GROUND" },
      stats = { hp = 100, attack = 110, defense = 90, speed = 60, special = 88 },
      catch = 45, exp = 241, height = 1.5, weight = 81.9,
      level1 = { "TACKLE", "MUD_SLAP", "WATER_GUN", "BIDE" },
      learn = { { 28, "TAKE_DOWN" }, { 37, "HYDRO_PUMP" },
        { 46, "EARTHQUAKE" } },
      kind = { "MUD FISH", "SCHLAMMFISCH" },
      text = { "It reads approaching storms through subtle changes in waves and wind.",
        "Kommende Stürme erkennt es an feinen Veränderungen von Wellen und Wind." },
      icon = "WATER",
    },
  }
  H.species = rows

  -- Register the bundled cries before the Pokemon rows reference them.  The
  -- content validator resolves registry references during the merge, so a
  -- late game.ready assignment would make an otherwise valid package fail
  -- before the first save can load.
  for _, id in ipairs(H.order) do
    mod.content.cries:register(id, {
      file = mod.path .. "/assets/audio/legacy_hoenn_cries/"
        .. tostring(rows[id].dex) .. ".ogg",
    })
  end

  local function moveExists(id)
    return mod.content.moves:get(id) ~= nil
  end

  -- RBY machine compatibility projected onto the three earned Hoenn lines.
  -- Every id is filtered through the live registry below so a minimal SDK
  -- fixture never receives a dangling move reference.
  local grassMachines = {
    "SWORDS_DANCE", "TOXIC", "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE",
    "MEGA_DRAIN", "SOLARBEAM", "EARTHQUAKE", "DIG", "MIMIC",
    "DOUBLE_TEAM", "REFLECT", "BIDE", "SWIFT", "REST", "ROCK_SLIDE",
    "SUBSTITUTE", "CUT", "STRENGTH", "FLASH",
  }
  local fireMachines = {
    "TOXIC", "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE", "MIMIC",
    "DOUBLE_TEAM", "BIDE", "FIRE_BLAST", "SWIFT", "REST", "SUBSTITUTE",
    "STRENGTH",
  }
  local fightingFireMachines = {
    "MEGA_PUNCH", "MEGA_KICK", "SWORDS_DANCE", "TOXIC", "BODY_SLAM",
    "TAKE_DOWN", "DOUBLE_EDGE", "SUBMISSION", "COUNTER", "SEISMIC_TOSS",
    "EARTHQUAKE", "DIG", "MIMIC", "DOUBLE_TEAM", "BIDE", "FIRE_BLAST",
    "SWIFT", "REST", "ROCK_SLIDE", "SUBSTITUTE", "STRENGTH",
  }
  local waterMachines = {
    "TOXIC", "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE", "BUBBLEBEAM",
    "WATER_GUN", "ICE_BEAM", "BLIZZARD", "HYPER_BEAM", "EARTHQUAKE",
    "FISSURE", "DIG", "MIMIC", "DOUBLE_TEAM", "BIDE", "REST",
    "ROCK_SLIDE", "SUBSTITUTE", "SURF", "STRENGTH",
  }
  local machineProfiles = {
    TREECKO = grassMachines, GROVYLE = grassMachines, SCEPTILE = grassMachines,
    TORCHIC = fireMachines, COMBUSKEN = fightingFireMachines,
    BLAZIKEN = fightingFireMachines,
    MUDKIP = waterMachines, MARSHTOMP = waterMachines,
    SWAMPERT = waterMachines,
  }
  H.machineProfiles = machineProfiles

  for _, id in ipairs(H.order) do
    local row = rows[id]
    local textId = "_KantoAscendantLegacyDex" .. id
    mod.content.text:register(textId, tr(row.text[1], row.text[2]))
    local learnset = {}
    for _, entry in ipairs(row.learn or {}) do
      if moveExists(entry[2]) then
        learnset[#learnset + 1] = { level = entry[1], move = entry[2] }
      end
    end
    local level1 = {}
    for _, move in ipairs(row.level1) do
      if moveExists(move) then level1[#level1 + 1] = move end
    end
    local tmhm = {}
    for _, move in ipairs(machineProfiles[id] or {}) do
      if moveExists(move) then tmhm[#tmhm + 1] = move end
    end
    -- A deliberately tiny SDK fixture can contain none of the authored
    -- moves.  An empty list is valid and is safer than inventing an
    -- unresolved TACKLE reference; production data retains the real moves.
    local evolutions = row.evo and {
      { method = "LEVEL", level = row.evo[1], species = row.evo[2] },
    } or {}
    local heightInches = math.floor(row.height * 39.3700787 + 0.5)
    mod.content.pokemon:register(id, {
      id = id, name = tr(row.name, row.de), dex = row.dex,
      types = row.types, baseStats = row.stats, catchRate = row.catch,
      baseExp = row.exp, growthRate = "MEDIUM_SLOW",
      level1Moves = level1, learnset = learnset, evolutions = evolutions,
      tmhm = tmhm, cry = id,
      spriteFront = mod.path .. "/assets/legacy_hoenn/front/"
        .. tostring(row.dex) .. ".png",
      spriteBack = mod.path .. "/assets/legacy_hoenn/back/"
        .. tostring(row.dex) .. ".png",
      frontSize = 7, battleScaleBack = 1, icon = row.icon,
      dexEntry = {
        kind = tr(row.kind[1], row.kind[2]), text = textId,
        heightFt = math.floor(heightInches / 12),
        heightIn = heightInches % 12,
        weight = math.floor(row.weight * 22.0462262 + 0.5),
        heightM = row.height, weightKg = row.weight,
      },
    })
    mod.content.icons:register(id, row.icon)
  end
  mod.content.constants:patch("dexSize", 260)
  mod.content.constants:patch("dexDigits", 3)

  function H.install(game)
    local data = game and game.data
    if not data then return false end
    data.audio = data.audio or {}
    data.audio.cries = data.audio.cries or {}
    data.audio._owners = data.audio._owners or {}
    data.audio._owners.cries = data.audio._owners.cries or {}
    for _, id in ipairs(H.order) do
      local dex = rows[id].dex
      local path = mod.path .. "/assets/audio/legacy_hoenn_cries/"
        .. tostring(dex) .. ".ogg"
      if data.audio.cries[id] == nil then
        data.audio.cries[id] = { file = path }
        data.audio._owners.cries[id] = mod.id
      end
      if data.pokemon[id] then data.pokemon[id].cry = id end
    end
    return true
  end

  return H
end
