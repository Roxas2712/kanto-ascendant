-- Collectible Trainer Card variants for Kanto Ascendant 6.6.
--
-- This KASC 6.6 module owns collection data, save authority and a renderer-facing
-- 640x400 screen model.  It does not patch TrainerCard or register itself
-- with main.lua; integration can consume the UI contract without changing
-- unlock semantics.

return function(mod, opts)
  opts = opts or {}

  local Collection = {
    -- v2 adds the always-owned Classic HD/VASC default without changing any
    -- of the 61 existing ids.  A v1 rollback will therefore see a future
    -- schema and leave the user's new selection untouched.
    version = 2,
    saveKey = "trainer_card_collection",
    game = opts.game,
    readOnly = false,
    futureVersion = nil,
  }

  local i18n = opts.i18n
  local postgame = opts.postgame
  local ascendant = opts.ascendant
  local legacyHall = opts.legacyHall or opts.legacy_hall
  local worldRankTournament = opts.worldRankTournament
  local showWorldRankDialogue = opts.showWorldRankDialogue
  local hasWorldRank = type(worldRankTournament) == "table"
    and type(worldRankTournament.worldRankModel) == "function"

  local function tr(en, de)
    if i18n and type(i18n.text) == "function" then
      local ok, text = pcall(i18n.text, en, de)
      if ok and type(text) == "string" and text ~= "" then return text end
    end
    return en
  end

  local catalog, byId = {}, {}
  local materialIds = {
    "prism_foil", "retro_mosaic", "league_enamel",
    "obsidian_gold", "botanical_enamel",
  }

  local function authority(kind, key, backfill, extra)
    local value = { kind = kind, key = key, backfill = backfill }
    if type(extra) == "table" then
      for field, fieldValue in pairs(extra) do value[field] = fieldValue end
    end
    return value
  end

  local function add(id, tier, en, de, frame, motif, palette, unlock, hintEn,
      hintDe, layout, finish)
    local serial = #catalog + 1
    -- Five authored materials x ten procedural shells form 50 deterministic,
    -- non-colliding base combinations. Additional owner-bound cards cycle the
    -- same renderer-supported shell range; their unique frame/motif carries
    -- identity. Standard and Retro intentionally map to prism_foil/
    -- retro_mosaic respectively.
    local material = materialIds[((serial - 1) % #materialIds) + 1]
    local shell = (math.floor((serial - 1) / #materialIds) % 10) + 1
    local row = {
      serial = serial,
      id = id,
      tier = tier,
      name = { en = en, de = de },
      visual = {
        frame = frame,
        motif = motif,
        palette = palette,
        layout = layout,
        finish = finish,
        frameIdentity = frame,
        shell = shell,
        material = material,
        materialPath = "assets/trainer_card/collection/materials/"
          .. material .. ".png",
      },
      authority = unlock,
      hint = { en = hintEn, de = hintDe },
    }
    catalog[#catalog + 1] = row
    byId[id] = row
  end

  -- Tier I: origins and Kanto badges.  Standard is the modern replacement;
  -- Retro is intentionally a separate collectible, not a compatibility mode.
  add("standard", "origins", "ASCENDANT STANDARD", "ASCENDANT-STANDARD",
    "aurora-prism", "ascending sunrays", { "10233f", "35d6c7", "f4d35e" },
    authority("always"), "Available from the start.",
    "Von Anfang an verfügbar.", "modern", "holo-glass")
  add("retro", "origins", "PIXEL LEGACY", "PIXEL-VERMÄCHTNIS",
    "pixel-checker", "eight-bit checkerburst", { "0f380f", "8bac0f", "e0f8cf" },
    authority("always"), "Available from the start.",
    "Von Anfang an verfügbar.", "retro", "dithered-ink")
  add("badge_boulder", "badges", "PEWTER MONOLITH", "MARMORIA-MONOLITH",
    "pewter-basalt", "faceted boulder", { "292c35", "777b85", "d8d3c8" },
    authority("badge", "BOULDERBADGE", nil, { index = 1 }),
    "Earn the Boulder Badge.", "Erringe den Felsorden.", "crest", "stone-foil")
  add("badge_cascade", "badges", "CERULEAN CURRENT", "AZURIA-STRÖMUNG",
    "cerulean-wave", "split waterfall", { "082b5b", "268bd2", "b9f3ff" },
    authority("badge", "CASCADEBADGE", nil, { index = 2 }),
    "Earn the Cascade Badge.", "Erringe den Quellorden.", "crest", "water-foil")
  add("badge_thunder", "badges", "VERMILION DYNAMO", "ORANIA-DYNAMO",
    "vermilion-coil", "electric induction coil", { "3b2600", "e18d00", "fff06a" },
    authority("badge", "THUNDERBADGE", nil, { index = 3 }),
    "Earn the Thunder Badge.", "Erringe den Donnerorden.", "crest", "spark-foil")
  add("badge_rainbow", "badges", "CELADON CONSERVATORY", "PRISMANIA-GLASHAUS",
    "celadon-glass", "stained-glass petals", { "173b2b", "58a85c", "f2a7d7" },
    authority("badge", "RAINBOWBADGE", nil, { index = 4 }),
    "Earn the Rainbow Badge.", "Erringe den Farborden.", "crest", "floral-glass")
  add("badge_soul", "badges", "FUCHSIA SHADOW", "FUCHSANIA-SCHATTEN",
    "fuchsia-smoke", "crossed smoke scrolls", { "281330", "8d3c85", "eb9fdb" },
    authority("badge", "SOULBADGE", nil, { index = 5 }),
    "Earn the Soul Badge.", "Erringe den Seelenorden.", "crest", "smoke-lacquer")
  add("badge_marsh", "badges", "SAFFRON ORACLE", "SAFFRONIA-ORAKEL",
    "saffron-orbit", "nested psychic rings", { "35204f", "d15aab", "ffe1f3" },
    authority("badge", "MARSHBADGE", nil, { index = 6 }),
    "Earn the Marsh Badge.", "Erringe den Sumpforden.", "crest", "pearlescent")
  add("badge_volcano", "badges", "CINNABAR CALDERA", "ZINNOBER-KRATER",
    "cinnabar-magma", "caldera fault lines", { "3c0c0c", "d4431b", "ffc857" },
    authority("badge", "VOLCANOBADGE", nil, { index = 7 }),
    "Earn the Volcano Badge.", "Erringe den Vulkanorden.", "crest", "magma-foil")
  add("badge_earth", "badges", "VIRIDIAN KEYSTONE", "VERTANIA-SCHLUSSSTEIN",
    "viridian-keystone", "interlocking earth plates", { "142e22", "477a46", "d7c89a" },
    authority("badge", "EARTHBADGE", nil, { index = 8 }),
    "Earn the Earth Badge.", "Erringe den Erdorden.", "crest", "mineral-foil")

  -- Tier II: Hall of Fame and the eight Master Leader rematches.
  add("indigo_laureate", "master", "INDIGO LAUREATE", "INDIGO-LORBEER",
    "indigo-laurel", "laurel around Indigo Plateau", { "17152e", "514b9e", "d8c777" },
    authority("hall_of_fame"), "Enter the Hall of Fame.",
    "Betritt die Ruhmeshalle.", "laureate", "satin-gold")
  add("master_brock", "master", "BROCK: BEDROCK", "ROCKO: GRUNDSTEIN",
    "master-bedrock", "stratified rock pillars", { "201c19", "76523b", "d9bd8f" },
    authority("master", "brock", "master_circuit"),
    "Defeat Brock in the Master Circuit.", "Besiege Rocko im Meister-Zirkel.",
    "duel", "obsidian-emboss")
  add("master_misty", "master", "MISTY: PEARLWAKE", "MISTY: PERLENWOGE",
    "master-pearlwake", "pearl wake and spray", { "071d35", "247ba0", "f4fbff" },
    authority("master", "misty", "master_circuit"),
    "Defeat Misty in the Master Circuit.", "Besiege Misty im Meister-Zirkel.",
    "duel", "pearl-emboss")
  add("master_surge", "master", "SURGE: OVERCHARGE", "MAJOR BOB: ÜBERSPANNUNG",
    "master-overcharge", "arcing capacitor rails", { "241c00", "d8a300", "ffff9b" },
    authority("master", "surge", "master_circuit"),
    "Defeat Lt. Surge in the Master Circuit.",
    "Besiege Major Bob im Meister-Zirkel.", "duel", "charged-metal")
  add("master_erika", "master", "ERIKA: WISTERIA", "ERIKA: GLYZINIE",
    "master-wisteria", "hanging wisteria lattice", { "1d3024", "6b8f3d", "d9a4e8" },
    authority("master", "erika", "master_circuit"),
    "Defeat Erika in the Master Circuit.", "Besiege Erika im Meister-Zirkel.",
    "duel", "botanical-foil")
  add("master_koga", "master", "KOGA: NIGHTSCROLL", "KOGA: NACHTROLLE",
    "master-nightscroll", "unfurled poison scroll", { "17111e", "56305f", "c64f8c" },
    authority("master", "koga", "master_circuit"),
    "Defeat Koga in the Master Circuit.", "Besiege Koga im Meister-Zirkel.",
    "duel", "inked-lacquer")
  add("master_sabrina", "master", "SABRINA: ASTRAL", "SABRINA: ASTRAL",
    "master-astral", "concentric astral facets", { "21152f", "8055a5", "ffb4ed" },
    authority("master", "sabrina", "master_circuit"),
    "Defeat Sabrina in the Master Circuit.",
    "Besiege Sabrina im Meister-Zirkel.", "duel", "astral-foil")
  add("master_blaine", "master", "BLAINE: FORGEMARK", "PYRO: GLUTMAL",
    "master-forgemark", "hammered forge sigil", { "31120c", "ae321d", "ffad43" },
    authority("master", "blaine", "master_circuit"),
    "Defeat Blaine in the Master Circuit.", "Besiege Pyro im Meister-Zirkel.",
    "duel", "hammered-copper")
  add("master_giovanni", "master", "GIOVANNI: ONYX", "GIOVANNI: ONYX",
    "master-onyx", "onyx fault and crown", { "090b0c", "42474d", "9b875f" },
    authority("master", "giovanni", "master_circuit"),
    "Defeat Giovanni in the Master Circuit.",
    "Besiege Giovanni im Meister-Zirkel.", "duel", "polished-onyx")
  add("master_circuit", "master", "MASTER CIRCUIT", "MEISTER-ZIRKEL",
    "master-octagon", "eight linked leader seals", { "11151a", "52606d", "f0c96b" },
    authority("all_master", nil, "master_circuit"),
    "Defeat all eight Master Leaders.", "Besiege alle acht Meister-Leiter.",
    "circuit", "black-gold-holo")

  -- Tier III: Apex Elite Four and Champion.
  add("apex_lorelei", "apex", "LORELEI: POLAR CROWN", "LORELEI: POLARKRONE",
    "apex-polar", "crystalline polar diadem", { "082137", "5a9ec9", "e9fbff" },
    authority("apex", "OPP_LORELEI", "apex_champion"),
    "Defeat Lorelei in the Apex League.", "Besiege Lorelei in der Apex-Liga.",
    "elite", "frosted-holo")
  add("apex_bruno", "apex", "BRUNO: IRON TEMPLE", "BRUNO: EISENTEMPEL",
    "apex-iron", "iron temple gates", { "1b1b1a", "6c6457", "d8c7a5" },
    authority("apex", "OPP_BRUNO", "apex_champion"),
    "Defeat Bruno in the Apex League.", "Besiege Bruno in der Apex-Liga.",
    "elite", "brushed-iron")
  add("apex_agatha", "apex", "AGATHA: SÉANCE", "AGATHA: SÉANCE",
    "apex-seance", "spirit candles and veil", { "170d22", "613b77", "b7f0c1" },
    authority("apex", "OPP_AGATHA", "apex_champion"),
    "Defeat Agatha in the Apex League.", "Besiege Agatha in der Apex-Liga.",
    "elite", "spectral-foil")
  add("apex_lance", "apex", "LANCE: DRAGONSPIRE", "SIEGFRIED: DRACHENSPITZE",
    "apex-dragonspire", "coiled dragon spire", { "230d17", "8e2f43", "e7c9a8" },
    authority("apex", "OPP_LANCE", "apex_champion"),
    "Defeat Lance in the Apex League.", "Besiege Siegfried in der Apex-Liga.",
    "elite", "scale-holo")
  add("apex_champion", "apex", "APEX CHAMPION", "APEX-CHAMPION",
    "apex-radiance", "five-point Indigo radiance", { "101333", "5559b8", "fff2a6" },
    authority("apex_champion", "OPP_RIVAL3", "apex_champion"),
    "Defeat the Apex Champion.", "Besiege den Apex-Champion.",
    "champion", "prismatic-star")

  -- Tier IV: persistent Leader bonds and the no-faint achievement.
  add("bond_brock", "bonds", "BROCK'S FIELD NOTES", "ROCKOS FELDNOTIZEN",
    "folio-geology", "annotated rock sample", { "33271d", "a6815a", "efe0bd" },
    authority("bond", "brock", "leader_confidant"),
    "Complete Brock's personal mission.", "Beende Rockos persönliche Mission.",
    "folio", "kraft-paper")
  add("bond_misty", "bonds", "MISTY'S TIDE LOG", "MISTYS FLUTLOG",
    "folio-tide", "tide chart and droplets", { "102b3c", "4f9bb3", "e7f7f4" },
    authority("bond", "misty", "leader_confidant"),
    "Complete Misty's personal mission.", "Beende Mistys persönliche Mission.",
    "folio", "watermarked-paper")
  add("bond_surge", "bonds", "SURGE'S GRID REPORT", "MAJOR BOBS NETZBERICHT",
    "folio-grid", "electrical grid schematic", { "302900", "b59a17", "fff7b2" },
    authority("bond", "surge", "leader_confidant"),
    "Complete Lt. Surge's personal mission.",
    "Beende Major Bobs persönliche Mission.", "folio", "blueprint-paper")
  add("bond_erika", "bonds", "ERIKA'S HERBARIUM", "ERIKAS HERBARIUM",
    "folio-herbarium", "pressed flower specimen", { "23321f", "7d9a58", "f2e8c9" },
    authority("bond", "erika", "leader_confidant"),
    "Complete Erika's personal mission.", "Beende Erikas persönliche Mission.",
    "folio", "pressed-fibre")
  add("bond_koga", "bonds", "KOGA'S FIELD SCROLL", "KOGAS FELDROLLE",
    "folio-ninja", "cipher scroll and shuriken", { "211721", "74506f", "dec3d8" },
    authority("bond", "koga", "leader_confidant"),
    "Complete Koga's personal mission.", "Beende Kogas persönliche Mission.",
    "folio", "rice-paper")
  add("bond_sabrina", "bonds", "SABRINA'S ECHO", "SABRINAS ECHO",
    "folio-echo", "psychic waveform notes", { "2f1f3f", "9567aa", "f0d4f4" },
    authority("bond", "sabrina", "leader_confidant"),
    "Complete Sabrina's personal mission.",
    "Beende Sabrinas persönliche Mission.", "folio", "vellum-glow")
  add("bond_blaine", "bonds", "BLAINE'S LAB FILE", "PYROS LABORAKTE",
    "folio-lab", "laboratory tab and flame graph", { "3b2018", "bb6540", "f4e2bf" },
    authority("bond", "blaine", "leader_confidant"),
    "Complete Blaine's personal mission.", "Beende Pyros persönliche Mission.",
    "folio", "archive-stock")
  add("bond_giovanni", "bonds", "GIOVANNI'S DOSSIER", "GIOVANNIS DOSSIER",
    "folio-dossier", "sealed confidential dossier", { "171b19", "4f6257", "d6c8a6" },
    authority("bond", "giovanni", "leader_confidant"),
    "Complete Giovanni's personal mission.",
    "Beende Giovannis persönliche Mission.", "folio", "wax-sealed")
  add("leader_confidant", "bonds", "KANTO CONFIDANT", "KANTOS VERTRAUTER",
    "bond-rosette", "eight interwoven signatures", { "1d2630", "4f8a83", "f4d28b" },
    authority("all_bonds", nil, "leader_confidant"),
    "Complete all eight Leader missions.", "Beende alle acht Leiter-Missionen.",
    "rosette", "signature-holo")
  add("untouchable", "bonds", "UNTOUCHABLE", "UNBERÜHRT",
    "untouchable-aegis", "unbroken mirrored shield", { "111a24", "8ba9bd", "f8ffff" },
    authority("achievement", "untouchable"),
    "Win a qualifying Ascendant battle without a faint.",
    "Gewinne einen gewerteten Ascendant-Kampf ohne K. o.", "aegis", "mirror-foil")

  -- Tier V: individual Crown clears plus the two capstone achievements.
  add("crown_brock", "crown", "CROWN BOULDER", "KRONEN-FELS",
    "crown-boulder", "granite crown teeth", { "161515", "74685a", "e5cd9c" },
    authority("crown_gym", "brock", "crown_champion"),
    "Defeat Brock in the Crown Circuit.", "Besiege Rocko im Kronen-Zirkel.",
    "royal", "granite-gilt")
  add("crown_misty", "crown", "CROWN CASCADE", "KRONEN-KASKADE",
    "crown-cascade", "crowned tidal crest", { "061b2e", "287fa5", "d8f7ff" },
    authority("crown_gym", "misty", "crown_champion"),
    "Defeat Misty in the Crown Circuit.", "Besiege Misty im Kronen-Zirkel.",
    "royal", "sapphire-gilt")
  add("crown_surge", "crown", "CROWN THUNDER", "KRONEN-DONNER",
    "crown-thunder", "forked lightning crown", { "211b00", "c68b00", "fff487" },
    authority("crown_gym", "surge", "crown_champion"),
    "Defeat Lt. Surge in the Crown Circuit.",
    "Besiege Major Bob im Kronen-Zirkel.", "royal", "topaz-gilt")
  add("crown_erika", "crown", "CROWN RAINBOW", "KRONEN-REGENBOGEN",
    "crown-rainbow", "seven-petal crown", { "19331e", "579552", "f3bddf" },
    authority("crown_gym", "erika", "crown_champion"),
    "Defeat Erika in the Crown Circuit.", "Besiege Erika im Kronen-Zirkel.",
    "royal", "emerald-gilt")
  add("crown_koga", "crown", "CROWN SOUL", "KRONEN-SEELE",
    "crown-soul", "shadow crown and smoke", { "1e1223", "73396c", "eda8da" },
    authority("crown_gym", "koga", "crown_champion"),
    "Defeat Koga in the Crown Circuit.", "Besiege Koga im Kronen-Zirkel.",
    "royal", "amethyst-gilt")
  add("crown_sabrina", "crown", "CROWN MARSH", "KRONEN-SUMPF",
    "crown-marsh", "levitating psychic crown", { "26152f", "a24896", "ffd5f3" },
    authority("crown_gym", "sabrina", "crown_champion"),
    "Defeat Sabrina in the Crown Circuit.",
    "Besiege Sabrina im Kronen-Zirkel.", "royal", "opal-gilt")
  add("crown_blaine", "crown", "CROWN VOLCANO", "KRONEN-VULKAN",
    "crown-volcano", "molten crown vents", { "350c09", "c62b17", "ffca64" },
    authority("crown_gym", "blaine", "crown_champion"),
    "Defeat Blaine in the Crown Circuit.", "Besiege Pyro im Kronen-Zirkel.",
    "royal", "ruby-gilt")
  add("crown_giovanni", "crown", "CROWN EARTH", "KRONEN-ERDE",
    "crown-earth", "tectonic black crown", { "0c1110", "405d4e", "c6ad76" },
    authority("crown_gym", "giovanni", "crown_champion"),
    "Defeat Giovanni in the Crown Circuit.",
    "Besiege Giovanni im Kronen-Zirkel.", "royal", "onyx-gilt")
  add("crown_lorelei", "crown", "CROWN LORELEI", "KRONE: LORELEI",
    "crown-lorelei", "diamond ice tiara", { "071e31", "4e8bb1", "f1fdff" },
    authority("crown_elite", "OPP_LORELEI", "crown_champion"),
    "Defeat Lorelei in the Crown League.", "Besiege Lorelei in der Kronen-Liga.",
    "royal-elite", "diamond-frost")
  add("crown_bruno", "crown", "CROWN BRUNO", "KRONE: BRUNO",
    "crown-bruno", "iron laurel and columns", { "1d1a17", "736958", "dfc797" },
    authority("crown_elite", "OPP_BRUNO", "crown_champion"),
    "Defeat Bruno in the Crown League.", "Besiege Bruno in der Kronen-Liga.",
    "royal-elite", "platinum-brush")
  add("crown_agatha", "crown", "CROWN AGATHA", "KRONE: AGATHA",
    "crown-agatha", "spectral thorn diadem", { "180d1d", "684070", "c8f4c9" },
    authority("crown_elite", "OPP_AGATHA", "crown_champion"),
    "Defeat Agatha in the Crown League.", "Besiege Agatha in der Kronen-Liga.",
    "royal-elite", "ectoplasm-holo")
  add("crown_lance", "crown", "CROWN LANCE", "KRONE: SIEGFRIED",
    "crown-lance", "dragon-wing coronet", { "270c14", "8d2c3e", "e9c896" },
    authority("crown_elite", "OPP_LANCE", "crown_champion"),
    "Defeat Lance in the Crown League.", "Besiege Siegfried in der Kronen-Liga.",
    "royal-elite", "dragon-gilt")
  add("crown_champion", "crown", "CROWN CHAMPION", "KRONEN-CHAMPION",
    "crown-champion", "Indigo crown above five stars", { "101027", "504a9d", "ffe49a" },
    authority("crown_champion", "OPP_RIVAL3", "crown_champion"),
    "Defeat the Crown Champion.", "Besiege den Kronen-Champion.",
    "royal-champion", "imperial-holo")
  add("kanto_purist", "crown", "KANTO PURIST", "KANTO-PURIST",
    "purist-white", "unbroken Kanto map line", { "202020", "b7b7af", "fffef1" },
    authority("achievement", "purist"),
    "Defeat the Crown Champion without a Legendary Pokémon.",
    "Besiege den Kronen-Champion ohne Legendäres Pokémon.",
    "minimal", "white-gold")
  add("kanto_ascendant", "crown", "KANTO ASCENDANT", "KANTO ASCENDANT",
    "ascendant-celestial", "Kanto rising through a celestial crown",
    { "080b20", "7756c8", "58e0d0" }, authority("achievement", "ascendant"),
    "Earn the Kanto Ascendant achievement.",
    "Erringe den Erfolg Kanto Ascendant.", "ascendant", "celestial-holo")

  local worldRankCards = {
    { "verdant", "VERDANT SOVEREIGN", "GRÜNER SOUVERÄN", "1d4825", "70c875" },
    { "dynamo", "DYNAMO SOVEREIGN", "DYNAMO-SOUVERÄN", "493a08", "f2ce32" },
    { "dragon", "DRAGON CROWN", "DRACHENKRONE", "30134f", "b57aee" },
    { "inferno", "INFERNO SOVEREIGN", "INFERNO-SOUVERÄN", "56150f", "ef684d" },
    { "tidal_frost", "TIDAL SOVEREIGN", "FLUT-SOUVERÄN", "123d59", "73cce8" },
    { "bedrock", "BEDROCK SOVEREIGN", "FELS-SOUVERÄN", "443322", "c39a65" },
    { "mind_shadow", "SHADOW MIND", "SCHATTENGEIST", "241934", "a28ac8" },
    { "valor", "VALOR SOVEREIGN", "MUT-SOUVERÄN", "4b1a20", "dc7780" },
    { "wing_venom", "VENOM WING", "GIFTFLÜGEL", "203b24", "8acb72" },
    { "gold", "GOLD STANDARD", "GOLDSTANDARD", "4b3710", "edca52" },
    { "sinnoh", "SINNOH SUMMIT", "SINNOH-GIPFEL", "24283f", "9fa8dc" },
  }
  for index, row in ipairs(worldRankCards) do
    local id = "world_rank_" .. row[1]
    add(id, "world_rank", row[2], row[3], "world-rank-" .. row[1],
      "World Rank champion seal", { row[4], row[5], "f7f4df" },
      authority("world_rank", row[1], nil, { titleId = id, ngPlus = true }),
      "Become rank 1 in this World Rank tournament.",
      "Erreiche Rang 1 in diesem Weltrang-Turnier.",
      ({ "standard", "badge-focus", "portrait-led", "diagonal",
        "radial" })[(index - 1) % 5 + 1], "world-rank-foil")
    byId[id].rewardTitleId = id
  end

  -- Append-only 6.6 repair: the published Gold/Teal card still exists in
  -- trainer_card_hd_standard.lua, but the collection had made it reachable
  -- only as an error fallback.  Keep every existing serial stable and expose
  -- the original VASC default as its own selectable card.
  add("classic_hd", "origins", "VASC DEFAULT", "VASC-STANDARD",
    "classic-gold-teal", "Kanto league crest",
    { "071f27", "087f83", "efc75e" }, authority("always"),
    "Available from the start.", "Von Anfang an verfügbar.",
    "classic", "gold-teal-enamel")
  byId.classic_hd.visual.delegate = "classic_hd"
  byId.classic_hd.visual.designLanguage = "classic_gold_teal_hd"
  byId.classic_hd.visual.layoutFamily = "dual_panel"

  -- 66-ROCKET-RECOVERY-RAIDS owns four manual, receipt-backed cards. They
  -- occupy append-only serials and can only be awarded by the corresponding
  -- depot boss receipt; ordinary refresh/backfill never grants them.
  local rocketRaidCards = {
    { "rocket_raid_jessie_james", "ROCKET RELAY", "ROCKET-RELAIS",
      "rocket-relay", "crossed relay beams", { "26062f", "a327b8", "f2d448" },
      "Recover your Pokémon from Jessie and James in Celadon.",
      "Hole deine Pokémon bei Jessie und James in Prismania zurück." },
    { "rocket_raid_meowth", "MEOWTH'S LEDGER", "MAUZIS KASSENBUCH",
      "rocket-ledger", "claw-marked custody ledger", { "251b0a", "d5a323", "fff0a5" },
      "Clear the Lavender Rocket relay.",
      "Räume das Rocket-Relais in Lavandia." },
    { "rocket_raid_executive", "ROCKET CONTRABAND", "ROCKET-KONTRABANDE",
      "rocket-contraband", "sealed laboratory capsule", { "101b29", "4e8abf", "e7f6ff" },
      "Clear the Cerulean Cave Rocket relay.",
      "Räume das Rocket-Relais in der Azuria-Höhle." },
    { "rocket_raid_giovanni", "GIOVANNI: LAST VAULT", "GIOVANNI: LETZTES DEPOT",
      "rocket-command", "fractured command crest", { "160d0d", "8b2525", "d6b66d" },
      "Defeat Giovanni in the Viridian command vault.",
      "Besiege Giovanni im Vertania-Kommandodepot." },
  }
  for _, card in ipairs(rocketRaidCards) do
    add(card[1], "rocket", card[2], card[3], card[4], card[5], card[6],
      authority("manual", card[1]), card[7], card[8],
      "dual_panel", "rocket-foil")
  end

  if opts.baldCrew == true then
    add("bald_crew_champion", "crew", "THE SHINING DOME", "DIE GLANZKUPPEL",
      "crew-lunar-crown", "silver moon above eight stars", { "101827", "d7dfed", "65d5ca" },
      authority("manual", "bald_crew_champion"),
      "Complete the one-time Mt. Moon Crew trial.",
      "Bestehe die einmalige Crew-Prüfung im Mondberg.", "dual_panel", "lunar-foil")
  end
  local defaultCardId = "classic_hd"
  local catalogCount = #catalog
  assert(catalogCount == (opts.baldCrew == true and 67 or 66),
    "Trainer Card catalog must contain 62 existing plus four Rocket cards")

  -- Resolution-independent badge artwork.  Coordinates use a 100x100 view
  -- box and semantic colours resolved from the card palette by the renderer.
  -- These are the HD fallback even when no authored material PNG is present.
  local badgePrimitives = {
    BOULDERBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "polygon", fill = "shadow", points = { 18, 58, 31, 24, 68, 16, 86, 48, 68, 82, 31, 78 } },
        { kind = "polygon", fill = "base", points = { 18, 58, 31, 24, 52, 49, 31, 78 } },
        { kind = "polygon", fill = "accent", points = { 31, 24, 68, 16, 52, 49 } },
        { kind = "polygon", fill = "highlight", points = { 52, 49, 68, 16, 86, 48, 68, 82 } },
      },
    },
    CASCADEBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "ellipse", fill = "shadow", x = 11, y = 43, width = 78, height = 38 },
        { kind = "ellipse", fill = "base", x = 16, y = 46, width = 68, height = 27 },
        { kind = "polygon", fill = "accent", points = { 50, 8, 70, 40, 61, 62, 39, 62, 30, 40 } },
        { kind = "ellipse", fill = "highlight", x = 43, y = 28, width = 12, height = 21 },
      },
    },
    THUNDERBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "ellipse", fill = "shadow", x = 12, y = 12, width = 76, height = 76 },
        { kind = "ellipse", fill = "base", x = 19, y = 19, width = 62, height = 62 },
        { kind = "polygon", fill = "accent", points = { 55, 16, 30, 54, 48, 54, 40, 86, 72, 43, 54, 43 } },
        { kind = "polygon", fill = "highlight", points = { 54, 24, 39, 48, 51, 48 } },
      },
    },
    RAINBOWBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "ellipse", fill = "shadow", x = 35, y = 7, width = 30, height = 46 },
        { kind = "ellipse", fill = "base", x = 50, y = 20, width = 39, height = 34 },
        { kind = "ellipse", fill = "accent", x = 48, y = 48, width = 33, height = 40 },
        { kind = "ellipse", fill = "base", x = 11, y = 20, width = 39, height = 34 },
        { kind = "ellipse", fill = "accent", x = 19, y = 48, width = 33, height = 40 },
        { kind = "ellipse", fill = "highlight", x = 37, y = 37, width = 26, height = 26 },
      },
    },
    SOULBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "polygon", fill = "shadow", points = { 50, 7, 62, 30, 88, 28, 72, 51, 85, 76, 58, 69, 50, 93, 42, 69, 15, 76, 28, 51, 12, 28, 38, 30 } },
        { kind = "polygon", fill = "base", points = { 50, 16, 59, 36, 79, 34, 66, 51, 76, 69, 55, 63, 50, 83, 45, 63, 24, 69, 34, 51, 21, 34, 41, 36 } },
        { kind = "ellipse", fill = "accent", x = 35, y = 35, width = 30, height = 30 },
        { kind = "ellipse", fill = "highlight", x = 43, y = 40, width = 10, height = 10 },
      },
    },
    MARSHBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "ellipse", fill = "shadow", x = 9, y = 9, width = 82, height = 82 },
        { kind = "ellipse", fill = "base", x = 17, y = 17, width = 66, height = 66 },
        { kind = "ellipse", fill = "accent", x = 28, y = 28, width = 44, height = 44 },
        { kind = "ellipse", fill = "base", x = 38, y = 38, width = 24, height = 24 },
        { kind = "ellipse", fill = "highlight", x = 43, y = 32, width = 11, height = 17 },
      },
    },
    VOLCANOBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "polygon", fill = "shadow", points = { 50, 5, 88, 50, 50, 95, 12, 50 } },
        { kind = "polygon", fill = "base", points = { 50, 14, 79, 50, 50, 86, 21, 50 } },
        { kind = "polygon", fill = "accent", points = { 51, 27, 68, 59, 55, 75, 35, 59 } },
        { kind = "polygon", fill = "highlight", points = { 51, 38, 58, 59, 50, 68, 44, 57 } },
      },
    },
    EARTHBADGE = {
      viewBox = { 0, 0, 100, 100 },
      primitives = {
        { kind = "polygon", fill = "shadow", points = { 29, 8, 71, 8, 92, 29, 92, 71, 71, 92, 29, 92, 8, 71, 8, 29 } },
        { kind = "polygon", fill = "base", points = { 33, 17, 67, 17, 83, 33, 83, 67, 67, 83, 33, 83, 17, 67, 17, 33 } },
        { kind = "polygon", fill = "accent", points = { 50, 24, 70, 50, 50, 76, 30, 50 } },
        { kind = "polygon", fill = "highlight", points = { 50, 31, 50, 50, 37, 50 } },
      },
    },
  }

  local function persist(s)
    if s and not Collection.readOnly and mod and mod.save
        and type(mod.save.set) == "function" then
      mod.save:set(Collection.saveKey, s)
      return true
    end
    return false
  end

  local function state(create)
    local s
    if mod and mod.save and type(mod.save.get) == "function" then
      s = mod.save:get(Collection.saveKey)
    end
    if type(s) ~= "table" then
      Collection.readOnly, Collection.futureVersion = false, nil
      if create == false then return nil end
      s = {
        version = Collection.version,
        selected = defaultCardId,
        manualReceipts = {},
        unlocked = { standard = true, retro = true, classic_hd = true },
      }
      persist(s)
      return s
    end

    local version = math.max(1, math.floor(tonumber(s.version) or 1))
    if version > Collection.version then
      -- A newer build owns this table.  Do not normalize, select, unlock or
      -- persist any part of it: old code is strictly read-only.
      Collection.readOnly = true
      Collection.futureVersion = version
      return nil
    end

    Collection.readOnly, Collection.futureVersion = false, nil
    local changed = false
    if s.version ~= Collection.version then
      s.version = Collection.version
      changed = true
    end
    if type(s.unlocked) ~= "table" then
      s.unlocked = {}
      changed = true
    end
    if type(s.manualReceipts) ~= "table" then
      s.manualReceipts = {}
      changed = true
    end
    for _, id in ipairs({ "standard", "retro", "classic_hd" }) do
      if s.unlocked[id] ~= true then
        s.unlocked[id] = true
        changed = true
      end
    end
    if type(s.selected) ~= "string" or not byId[s.selected]
        or s.unlocked[s.selected] ~= true then
      s.selected = defaultCardId
      changed = true
    end
    -- Unknown keys are deliberately retained: collection unlock state remains
    -- append-only across schema migrations.
    if changed then persist(s) end
    return s
  end

  local function controllerState(controller)
    if type(controller) ~= "table" then return {} end
    if type(controller.state) ~= "function" then return controller end
    local ok, value = pcall(controller.state, false)
    return ok and type(value) == "table" and value or {}
  end

  local function truthy(value)
    if value == true then return true end
    return (tonumber(value) or 0) > 0
  end

  local fallbackBadges = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }

  local function canonicalBadgeItem(game, index, fallback)
    local ok, Badges = pcall(require, "src.inventory.Badges")
    if ok and type(Badges) == "table" and type(Badges.list) == "function"
        and type(Badges.itemFor) == "function" then
      local listOk, list = pcall(Badges.list, game and game.data)
      local entry = listOk and type(list) == "table" and list[index] or nil
      if entry then
        local itemOk, item = pcall(Badges.itemFor, entry)
        if itemOk and type(item) == "string" and item ~= "" then return item end
      end
    end
    return fallback or fallbackBadges[index]
  end

  local gymKeys = {
    "brock", "misty", "surge", "erika",
    "koga", "sabrina", "blaine", "giovanni",
  }
  local eliteKeys = { "OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE" }

  local function allTrue(bucket, keys, field)
    bucket = type(bucket) == "table" and bucket or {}
    for _, key in ipairs(keys) do
      local value = bucket[key]
      if field then value = type(value) == "table" and value[field] end
      if not truthy(value) then return false end
    end
    return true
  end

  local function hasHallOfFame(game)
    local save = game and game.save
    if postgame and type(postgame.hasHallOfFame) == "function" then
      local ok, result = pcall(postgame.hasHallOfFame, save)
      if ok then return result == true end
    end
    if type(save) ~= "table" then return false end
    local hall = save.hallOfFame
    return (type(hall) == "table" and next(hall) ~= nil)
      or (type(save.flags) == "table"
        and truthy(save.flags.EVENT_BEAT_CHAMPION_RIVAL))
      or false
  end

  local function achievement(ascendantState, id)
    return type(ascendantState.achievements) == "table"
      and ascendantState.achievements[id] == true
  end

  local function authoritySatisfied(rule, context)
    local p, a = context.postgame, context.ascendant
    local kind, key = rule.kind, rule.key
    if kind == "always" then return true end
    if kind == "badge" then
      local item = canonicalBadgeItem(context.game, rule.index, key)
      local inventory = context.game and context.game.save
        and context.game.save.inventory or {}
      return truthy(inventory and inventory[item])
    end
    if kind == "hall_of_fame" then return hasHallOfFame(context.game) end
    if kind == "world_rank" then
      local state = context.worldRank
      return type(state) == "table" and type(state.formats) == "table"
        and type(state.formats[key]) == "table"
        and state.formats[key].cardGranted == true
    end
    if kind == "master" then
      return truthy(p.masterWins and p.masterWins[key])
        or achievement(a, rule.backfill)
    end
    if kind == "all_master" then
      return allTrue(p.masterWins, gymKeys) or achievement(a, rule.backfill)
    end
    if kind == "apex" then
      return truthy(p.eliteApexWins and p.eliteApexWins[key])
        or achievement(a, rule.backfill)
    end
    if kind == "apex_champion" then
      return truthy(p.apexChampion) or achievement(a, rule.backfill)
    end
    if kind == "bond" then
      local quest = type(a.gymQuests) == "table" and a.gymQuests[key]
      return (type(quest) == "table" and quest.done == true)
        or achievement(a, rule.backfill)
    end
    if kind == "all_bonds" then
      return allTrue(a.gymQuests, gymKeys, "done")
        or achievement(a, rule.backfill)
    end
    if kind == "crown_gym" then
      return truthy(p.crownWins and p.crownWins[key])
        or achievement(a, rule.backfill)
    end
    if kind == "crown_elite" then
      return truthy(p.eliteCrownWins and p.eliteCrownWins[key])
        or achievement(a, rule.backfill)
    end
    if kind == "crown_champion" then
      return truthy(p.crownChampion) or achievement(a, rule.backfill)
    end
    if kind == "achievement" then return achievement(a, key) end
    if kind == "manual" then return false end
    return false
  end

  local uiState = {
    open = false, page = 1, previewId = nil,
    worldRankOpen = false, worldRankIndex = 1,
  }

  local function refresh(game)
    if game then Collection.game = game end
    game = game or Collection.game
    local s = state()
    if not s then return nil, {} end

    local evaluated
    if ascendant and type(ascendant.evaluateAchievements) == "function" then
      local ok, value = pcall(ascendant.evaluateAchievements, game)
      if ok and type(value) == "table" then evaluated = value end
    end
    local context = {
      game = game,
      postgame = controllerState(postgame),
      ascendant = evaluated or controllerState(ascendant),
      worldRank = hasWorldRank and type(worldRankTournament.state) == "function"
        and worldRankTournament.state(game) or nil,
    }
    local unlocked = {}
    for _, row in ipairs(catalog) do
      if s.unlocked[row.id] ~= true
          and authoritySatisfied(row.authority, context) then
        s.unlocked[row.id] = true
        unlocked[#unlocked + 1] = row.id
      end
    end
    if #unlocked > 0 then persist(s) end
    return s, unlocked
  end

  local function selectCard(id, game)
    if type(id) ~= "string" or not byId[id] then return false, "unknown-card" end
    local s = refresh(game)
    if not s then return false, "future-version" end
    if s.unlocked[id] ~= true then return false, "locked" end
    if s.selected ~= id then
      s.selected = id
      persist(s)
    end
    uiState.previewId = id
    return true, byId[id]
  end

  local function current(game)
    local s = refresh(game)
    if not s then return byId[defaultCardId], nil end
    return byId[s.selected] or byId[defaultCardId], s
  end

  local function title()
    if legacyHall and type(legacyHall.currentTitle) == "function" then
      local ok, id, text = pcall(legacyHall.currentTitle)
      if ok and type(text) == "string" and text ~= "" then return id, text end
    end
    -- Every presentation has a title, including fresh saves and saves from a
    -- future collection schema that this build must not modify.
    return nil, tr("TRAINER", "KANTO-TRAINER")
  end

  local function pact(game)
    game = game or Collection.game
    if legacyHall and type(legacyHall.pactCardText) == "function" then
      local ok, text = pcall(legacyHall.pactCardText,
        game and game.save or nil)
      if ok and type(text) == "string" and text ~= "" then return text end
    end
    return nil
  end

  local function copyArray(source)
    local out = {}
    for index, value in ipairs(source or {}) do out[index] = value end
    return out
  end

  local function leaderIdsFor(row)
    local rule = row.authority
    if rule.kind == "badge" then
      return gymKeys[rule.index] and { gymKeys[rule.index] } or {}
    end
    if rule.kind == "master" or rule.kind == "bond"
        or rule.kind == "crown_gym" then
      return { rule.key }
    end
    if rule.kind == "apex" or rule.kind == "crown_elite" then
      return { rule.key }
    end
    if rule.kind == "apex_champion" or rule.kind == "crown_champion" then
      return { "OPP_RIVAL3" }
    end
    if rule.kind == "hall_of_fame" then return copyArray(eliteKeys) end
    if rule.kind == "all_master" or rule.kind == "all_bonds" then
      return copyArray(gymKeys)
    end
    return {}
  end

  local function playerFor(game, row)
    local save = game and game.save or {}
    local raw = type(save.player) == "table" and save.player or {}
    local name = raw.name or save.playerName or save.name or "TRAINER"
    local identity = raw.identity or raw.id or raw.character or name
    local portrait
    if type(opts.portraitFor) == "function" then
      local ok, value = pcall(opts.portraitFor, game, row)
      if ok then portrait = value end
    end
    if portrait == nil then
      portrait = raw.portrait or raw.trainerPortrait or {
        source = "player",
        identity = tostring(identity),
      }
    end
    return {
      name = tostring(name),
      id = tostring(identity),
      portrait = portrait,
    }
  end

  -- Stable renderer-facing contract.  It keeps dynamic title and pact text
  -- out of catalog/save state while guaranteeing a non-empty title per card.
  -- model() already owns a refreshed state; accepting it here prevents two
  -- complete achievement evaluations for every rendered model.
  local function presentationWithState(game, id, s)
    local row = type(id) == "string" and byId[id] or nil
    if not row then row = s and byId[s.selected] or byId[defaultCardId] end
    local titleId, titleText = title()
    local player = playerFor(game or Collection.game, row)
    return {
      id = row.id,
      serial = row.serial,
      serialText = string.format("%02d/%02d", row.serial, catalogCount),
      tier = row.tier,
      cardName = tr(row.name.en, row.name.de),
      brand = "KANTO ASCENDANT",
      titleId = titleId,
      activeTitle = titleText,
      -- Backward-compatible alias for renderer prototypes; activeTitle is the
      -- canonical field and is independent of the fixed collection brand.
      title = titleText,
      pact = pact(game),
      player = player,
      portrait = player.portrait,
      leaderIds = leaderIdsFor(row),
      badgeIcon = row.authority.kind == "badge"
        and badgePrimitives[row.authority.key] or nil,
      unlocked = s and s.unlocked[row.id] == true
        or (not s and row.id == defaultCardId),
      selected = s and s.selected == row.id
        or (not s and row.id == defaultCardId),
      hint = tr(row.hint.en, row.hint.de),
      visual = row.visual,
      viewport = { width = 640, height = 400, scale = 1 },
    }
  end

  local function presentation(game, id)
    if game then Collection.game = game end
    return presentationWithState(game, id, refresh(game))
  end

  local pageSize = 20
  local pageCount = math.ceil(#catalog / pageSize)
  local function pageFor(row)
    return math.floor((row.serial - 1) / pageSize) + 1
  end

  local function cardSummary(row, s, activeTitle, titleId)
    return {
      id = row.id,
      serial = row.serial,
      serialText = string.format("%02d/%02d", row.serial, catalogCount),
      tier = row.tier,
      cardName = tr(row.name.en, row.name.de),
      brand = "KANTO ASCENDANT",
      activeTitle = activeTitle,
      title = activeTitle,
      titleId = titleId,
      hint = tr(row.hint.en, row.hint.de),
      unlocked = s and s.unlocked[row.id] == true or false,
      selected = s and s.selected == row.id or false,
      previewed = uiState.previewId == row.id,
      visual = row.visual,
      badgeIcon = row.authority.kind == "badge"
        and badgePrimitives[row.authority.key] or nil,
    }
  end

  local function worldRankModel(game)
    if not hasWorldRank then return nil end
    local ok, value = pcall(worldRankTournament.worldRankModel,
      game or Collection.game)
    if not (ok and type(value) == "table") then return nil end
    local count = #(value.formats or {})
    uiState.worldRankIndex = math.max(1,
      math.min(count > 0 and count or 1, uiState.worldRankIndex or 1))
    value.selectionIndex = uiState.worldRankIndex
    if value.formats and value.formats[uiState.worldRankIndex] then
      value.formats[uiState.worldRankIndex].selected = true
    end
    return value
  end

  local function showWorldRankLifecycle(game, formatId, intent)
    if not (hasWorldRank and type(formatId) == "string"
        and type(worldRankTournament.trainerCardPresentation) == "function") then
      return nil
    end
    local ok, receipt = pcall(worldRankTournament.trainerCardPresentation,
      game or Collection.game, formatId, intent)
    if not (ok and type(receipt) == "table"
        and type(receipt.text) == "string" and receipt.text ~= "") then
      return nil
    end
    if type(showWorldRankDialogue) == "function" then
      pcall(showWorldRankDialogue, game or Collection.game,
        receipt.text, nil, receipt)
    end
    return receipt
  end

  local function modelWithState(game, s)
    local selectedId = s and s.selected or defaultCardId
    local previewId = uiState.previewId or selectedId
    if not byId[previewId] then previewId = selectedId end
    uiState.previewId = previewId
    uiState.page = pageFor(byId[previewId] or byId[defaultCardId])

    local result = presentationWithState(game, previewId, s)
    result.galleryOpen = uiState.open
    result.worldRankOpen = uiState.worldRankOpen == true
    result.worldRank = worldRankModel(game)
    result.page = uiState.page
    result.pageCount = pageCount
    result.pageId = string.format("%02d-%02d",
      (uiState.page - 1) * pageSize + 1,
      math.min(#catalog, uiState.page * pageSize))
    result.cards = {}
    result.pageCards = {}
    for _, row in ipairs(catalog) do
      local summary = cardSummary(row, s, result.activeTitle, result.titleId)
      result.cards[#result.cards + 1] = summary
      if pageFor(row) == uiState.page then
        result.pageCards[#result.pageCards + 1] = summary
      end
    end
    return result
  end

  local function model(game)
    if game then Collection.game = game end
    return modelWithState(game, refresh(game))
  end

  local function move(delta)
    delta = math.floor(tonumber(delta) or 0)
    if delta == 0 then return model(Collection.game) end
    local s = state()
    local currentId = uiState.previewId or (s and s.selected) or defaultCardId
    local index = byId[currentId] and byId[currentId].serial or 1
    index = ((index - 1 + delta) % #catalog) + 1
    uiState.previewId = catalog[index].id
    uiState.page = pageFor(catalog[index])
    return model(Collection.game)
  end

  local function page(delta)
    delta = math.floor(tonumber(delta) or 0)
    if delta ~= 0 then
      uiState.page = ((uiState.page - 1 + delta) % pageCount) + 1
      for _, row in ipairs(catalog) do
        if pageFor(row) == uiState.page then
          uiState.previewId = row.id
          break
        end
      end
    end
    return model(Collection.game)
  end

  local function toggleGallery(force)
    uiState.worldRankOpen = false
    if type(force) == "boolean" then uiState.open = force
    else uiState.open = not uiState.open end
    return uiState.open, model(Collection.game)
  end

  local function selectedWorldRankRow(value)
    value = value or worldRankModel(Collection.game)
    return value and value.formats
      and value.formats[value.selectionIndex or uiState.worldRankIndex]
  end

  local function toggleWorldRank(force, game)
    if game then Collection.game = game end
    if not hasWorldRank then return false, model(Collection.game) end
    if type(force) == "boolean" then uiState.worldRankOpen = force
    else uiState.worldRankOpen = not uiState.worldRankOpen end
    if uiState.worldRankOpen then
      uiState.open = false
      local row = selectedWorldRankRow()
      if row then showWorldRankLifecycle(Collection.game, row.id, "open") end
    end
    return uiState.worldRankOpen, model(Collection.game)
  end

  local function moveWorldRank(delta, game)
    if game then Collection.game = game end
    local rank = worldRankModel(Collection.game)
    local rows = rank and rank.formats or {}
    if #rows > 0 then
      uiState.worldRankIndex = ((uiState.worldRankIndex - 1
        + math.floor(tonumber(delta) or 0)) % #rows) + 1
    end
    local updated = model(Collection.game)
    local row = selectedWorldRankRow(updated.worldRank)
    if row then showWorldRankLifecycle(Collection.game, row.id, "open") end
    return updated
  end

  local function registerWorldRank(game)
    if game then Collection.game = game end
    if not hasWorldRank then return nil, "unavailable", model(Collection.game) end
    local rank = worldRankModel(Collection.game)
    local row = selectedWorldRankRow(rank)
    if not (row and row.available == true) then
      if row then showWorldRankLifecycle(Collection.game, row.id, "open") end
      return nil, "unavailable", model(Collection.game)
    end
    local ok, token, reason = pcall(worldRankTournament.register,
      Collection.game, row.id)
    if not ok or not token then
      return nil, reason or "rejected", model(Collection.game)
    end
    showWorldRankLifecycle(Collection.game, row.id, "confirmed")
    return token, model(Collection.game)
  end

  local function begin(game)
    if game then Collection.game = game end
    local s = refresh(game)
    uiState.previewId = s and s.selected or defaultCardId
    uiState.open = false
    uiState.worldRankOpen = false
    uiState.worldRankIndex = 1
    return modelWithState(game, s)
  end

  -- A renderer may be injected now; otherwise draw() returns the complete
  -- model for a future native TrainerCard collection screen.
  local function draw(game, id, renderer)
    if id then uiState.previewId = byId[id] and id or uiState.previewId end
    local renderModel = model(game)
    if type(renderer) == "function" then return renderer(renderModel) end
    if type(renderer) == "table" and type(renderer.draw) == "function" then
      return renderer:draw(renderModel)
    end
    return renderModel
  end

  local function screen(game, screenOpts)
    screenOpts = screenOpts or {}
    if game then Collection.game = game end
    local Screen = {
      game = game or Collection.game,
      renderer = screenOpts.renderer,
      width = 640,
      height = 400,
      isOpaque = true,
      active = false,
    }
    function Screen:uiSize() return self.width, self.height end
    function Screen:enter()
      self.active = true
      begin(self.game)
      toggleGallery(true)
    end
    function Screen:exit()
      self.active = false
      toggleGallery(false)
    end
    function Screen:model() return model(self.game) end
    function Screen:draw()
      local renderModel = self:model()
      if type(self.renderer) == "function" then
        return self.renderer(renderModel, self)
      end
      if type(self.renderer) == "table" then
        if type(self.renderer.drawCollection) == "function" then
          return self.renderer:drawCollection(renderModel, self)
        end
        if type(self.renderer.draw) == "function" then
          return self.renderer:draw(renderModel, self)
        end
      end
      return renderModel
    end
    function Screen:move(delta) return move(delta) end
    function Screen:page(delta) return page(delta) end
    function Screen:select(id)
      id = id or uiState.previewId
      return selectCard(id, self.game)
    end
    function Screen:toggleGallery(force) return toggleGallery(force) end
    function Screen:toggleWorldRank(force)
      return toggleWorldRank(force, self.game)
    end
    function Screen:moveWorldRank(delta)
      return moveWorldRank(delta, self.game)
    end
    function Screen:registerWorldRank()
      return registerWorldRank(self.game)
    end
    function Screen:close()
      toggleGallery(false)
      if screenOpts.pop ~= false and self.game and self.game.stack
          and type(self.game.stack.pop) == "function" then
        self.game.stack:pop()
      end
      if type(screenOpts.onClose) == "function" then screenOpts.onClose() end
    end
    function Screen:update()
      local input = self.game and self.game.input
      if not (input and type(input.wasPressed) == "function") then return end
      if uiState.worldRankOpen then
        if input:wasPressed("up") then self:moveWorldRank(-1)
        elseif input:wasPressed("down") then self:moveWorldRank(1)
        elseif input:wasPressed("a") then self:registerWorldRank()
        elseif input:wasPressed("select") or input:wasPressed("b") then
          self:toggleWorldRank(false)
        end
      elseif input:wasPressed("left") then self:move(-1)
      elseif input:wasPressed("right") then self:move(1)
      elseif input:wasPressed("up") then self:page(-1)
      elseif input:wasPressed("down") then self:page(1)
      elseif input:wasPressed("a") then self:select()
      elseif input:wasPressed("b") or input:wasPressed("start") then
        self:close()
      end
    end
    return Screen
  end

  Collection.catalog = catalog
  Collection.state = state
  Collection.refresh = refresh
  Collection.select = selectCard
  Collection.current = current
  Collection.title = title
  Collection.pact = pact
  Collection.presentation = presentation
  Collection.model = model
  Collection.move = move
  Collection.page = page
  Collection.toggleGallery = toggleGallery
  Collection.toggleWorldRank = toggleWorldRank
  Collection.moveWorldRank = moveWorldRank
  Collection.registerWorldRank = registerWorldRank
  Collection.begin = begin
  Collection.draw = draw
  Collection.screen = screen
  Collection.byId = function(id) return byId[id] end
  Collection.award = function(id, reason, game)
    local card = type(id) == "string" and byId[id] or nil
    if not card then return false, "unknown-card" end
    if card.authority.kind ~= "manual" then return false, "not-manual-card" end
    local s = state()
    if not s then return false, "future-version" end
    if s.unlocked[id] == true then return true, "already-awarded" end
    s.unlocked[id] = true
    s.manualReceipts[id] = {
      reason = tostring(reason or "manual"),
      cardId = id,
    }
    persist(s)
    return true, "awarded"
  end
  Collection.install = function(game)
    Collection.game = game
    return refresh(game)
  end
  Collection.ui = {
    version = 2,
    canvas = { width = 640, height = 400 },
    nativeScale = 4,
    materialRoot = "assets/trainer_card/collection/materials",
    badgePrimitives = badgePrimitives,
    gallery = { columns = 5, rows = 4, pageSize = 20, pageCount = 4 },
    worldRank = {
      available = hasWorldRank,
      controls = { open = "select", format = "up-down", register = "a" },
    },
    invariants = {
      brand = "KANTO ASCENDANT",
      activeTitle = "always-visible",
    },
    classic = {
      id = "classic_hd",
      sides = { "front" },
      controls = { browse = "d-pad", equip = "a" },
    },
    defaultCard = defaultCardId,
    counterFormat = string.format("%%02d/%02d", catalogCount),
  }

  return Collection
end
