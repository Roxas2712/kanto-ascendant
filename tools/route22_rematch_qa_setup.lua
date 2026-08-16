-- Immutable package-gate prerequisite builder for the Route 22 rival
-- lifecycle.  It writes two isolated native slots per cell:
--
--   * first: Pokédex owned, Brock not yet beaten, first rival still armed
--   * late:  first rival/Brock/Giovanni complete, second rival still armed
--
-- FRESH starts from SaveData.newGame.  ALT starts from the exact immutable
-- BLITZ snapshot pinned by the final orchestrator, retaining its unrelated
-- historical Authority buckets while replacing only the bounded Route 22
-- prerequisite surface.  The runtime driver earns every tested loss/win and
-- never writes a story flag, party, result, or rematch record itself.
return function(game)
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path required")
  local U = dofile(utilPath)
  local SaveData = require("src.core.SaveData")
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")

  local edition = tostring(assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION required")):lower()
  local variant = tostring(assert(os.getenv("ROUTE22_QA_VARIANT"),
    "ROUTE22_QA_VARIANT required")):upper()
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "isolated POKEPORT_IDENTITY required")
  assert((edition == "red" or edition == "blue" or edition == "yellow")
      and (variant == "FRESH" or variant == "ALT"),
    "Route22 setup requires Red/Blue/Yellow and FRESH/ALT")
  local expectedIdentity = ("ka65-final-route22-%s-%s")
    :format(edition, variant:lower())
  assert(identity == expectedIdentity,
    "refusing non-orchestrated Route22 identity " .. tostring(identity))

  local harnessRoot = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR package harness required")
  local source = assert(os.getenv("KA_SOURCE_SAVE"),
    "KA_SOURCE_SAVE required")
  local sourceSha = assert(os.getenv("KA_SOURCE_SAVE_SHA256"),
    "KA_SOURCE_SAVE_SHA256 required")
  local gateSha = assert(os.getenv("KA_PACKAGE_GATE_RECEIPT_SHA256"),
    "KA_PACKAGE_GATE_RECEIPT_SHA256 required")
  local expectedSource = harnessRoot
    .. "/immutable_inputs/source_snapshot/slot7_original_readonly.lua"

  local function validSha(value)
    return type(value) == "string" and #value == 64
      and value:match("^[0-9a-f]+$") ~= nil
  end
  local function fileSha256(path)
    local file = assert(io.open(path, "rb"),
      "immutable Route22 source cannot be opened")
    local body = file:read("*a")
    file:close()
    local digest = love.data.hash("sha256", body)
    if type(digest) == "userdata" and digest.getString then
      digest = digest:getString()
    end
    return love.data.encode("string", "hex", digest):lower()
  end

  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing Route22 setup outside the immutable package gate")
  for _, path in ipairs({ harnessRoot, utilPath }) do
    assert(path:sub(1, 1) == "/"
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package setup evidence: " .. path)
  end
  local installed = assert(game.mods and game.mods.mods
      and game.mods.mods.kanto_ascendant,
    "installed Authority package missing during Route22 setup")
  local installedPath = tostring(installed.path or "")
  assert(installedPath ~= ""
      and not installedPath:find(".worktrees", 1, true)
      and not installedPath:find("/Documents/Recompile/", 1, true)
      and not installedPath:find("/tests/", 1, true)
      and not installedPath:find("/tools/", 1, true),
    "source/worktree path is not installed-package setup evidence: "
      .. installedPath)
  assert(validSha(sourceSha) and validSha(gateSha),
    "Route22 source/package receipt SHA is malformed")
  assert(source == expectedSource,
    "refusing Route22 source outside materialized immutable inputs")
  assert(not source:find("Application Support/pokemon-love2d/saves", 1, true),
    "refusing the player's live save directory")
  assert(fileSha256(source) == sourceSha,
    "orchestrator-pinned Route22 ALT source SHA drifted")

  local charactersByEdition = {
    red = { player = "RED", rival = "BLUE", third = "GREEN" },
    blue = { player = "BLUE", rival = "GREEN", third = "RED" },
    -- The reported regression boundary: Casey/Green must keep Red as the
    -- authored rival after a loss and native reload.
    yellow = { player = "GREEN", rival = "RED", third = "BLUE" },
  }
  local character = charactersByEdition[edition]
  local loaded
  local originKind
  if variant == "FRESH" then
    local boot = {}
    for key, value in pairs(game:bootConfig() or {}) do boot[key] = value end
    boot.version = edition
    boot.playerName = character.player == "GREEN" and "CASEY"
      or character.player
    boot.rivalName = character.rival
    loaded = SaveData.newGame(boot)
    assert(loaded.version == edition and loaded.money == 3000
        and #(loaded.party or {}) == 0
        and next(loaded.flags or {}) == nil
        and #(loaded.hallOfFame or {}) == 0,
      "native Fresh Route22 skeleton already contains campaign progress")
    assert(not (loaded.modData and loaded.modData.kanto_ascendant),
      "native Fresh Route22 skeleton already contains Authority state")
    originKind = "native-save-new-game"
  else
    loaded = assert(loadfile(source))()
    assert(type(loaded) == "table" and loaded.version == "red"
        and loaded.flags and loaded.flags.EVENT_BEAT_BROCK == true
        and loaded.flags.EVENT_BEAT_GIOVANNI == true
        and loaded.flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE == true
        and loaded.flags.EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE == true
        and loaded.modData and loaded.modData.kanto_ascendant,
      "immutable ALT source lost its real completed Route22 migration shape")
    originKind = edition == "red" and "immutable-blitz-save"
      or "immutable-blitz-cross-edition-clone"
  end

  loaded.version = edition
  loaded.player = loaded.player or {}
  loaded.player.name = character.player == "GREEN" and "CASEY"
    or character.player
  loaded.player.rival = character.rival
  loaded.player.map, loaded.player.x, loaded.player.y = "ROUTE_22", 28, 4
  loaded.player.facing, loaded.player.surfing = "right", false
  loaded.flags = loaded.flags or {}
  loaded.flags.EVENT_GOT_STARTER = true
  loaded.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true
  loaded.flags.EVENT_GOT_POKEDEX = true
  loaded.flags.EVENT_BEAT_BROCK = nil
  loaded.flags.EVENT_BEAT_GIOVANNI = nil
  loaded.flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE = nil
  loaded.flags.EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE = nil
  loaded.flags.EVENT_CHOSE_CHARMANDER = edition ~= "yellow" and true or nil
  loaded.flags.EVENT_CHOSE_BULBASAUR = nil
  loaded.flags.EVENT_CHOSE_SQUIRTLE = nil
  loaded.flags.EVENT_CHOSE_PIKACHU = edition == "yellow" and true or nil
  loaded.rivalStarter = edition == "yellow" and 1 or loaded.rivalStarter
  loaded.defeatedTrainers = loaded.defeatedTrainers or {}
  for _, key in ipairs({
    "ROUTE22_RIVAL1", "ROUTE_22_obj_1",
    "ROUTE22_RIVAL2", "ROUTE_22_obj_2",
  }) do
    loaded.defeatedTrainers[key] = nil
  end
  local authority = loaded.modData and loaded.modData.kanto_ascendant
  if authority and type(authority.trainers) == "table" then
    for _, key in ipairs({
      "ROUTE22_RIVAL1", "ROUTE_22_obj_1",
      "ROUTE22_RIVAL2", "ROUTE_22_obj_2",
    }) do
      authority.trainers[key] = nil
    end
  end

  -- One legal level-100 Mewtwo gives both outcomes to ordinary battle input:
  -- SELFDESTRUCT causes a real loss while the rival still has reserve mons;
  -- the three accurate attacks win the retry without injecting damage.
  local mon = Pokemon.new(game.data, "MEWTWO", 100, function() return 15 end)
  mon.dvs = { hp = 15, attack = 15, defense = 15, speed = 15, special = 15 }
  mon.statExp = {
    hp = 65535, attack = 65535, defense = 65535,
    speed = 65535, special = 65535,
  }
  mon.stats = Stats.calc(game.data.pokemon.MEWTWO, 100,
    mon.dvs, mon.statExp, mon)
  mon.hp = mon.stats.hp
  mon.moves = {
    { id = "SELFDESTRUCT", pp = 5 },
    { id = "PSYCHIC_M", pp = 20 },
    { id = "THUNDERBOLT", pp = 15 },
    { id = "ICE_BEAM", pp = 10 },
  }
  loaded.party = { mon }
  loaded.repelSteps = 9999
  -- A physical loss must enter the real blackout path before the driver
  -- restores its pre-loss slot.  Keep the disposable cell deterministic and
  -- map-valid without treating the blackout landing as lifecycle evidence.
  loaded.lastHeal = { map = "PALLET_TOWN", x = 5, y = 6 }
  loaded.lastOutdoor = { id = "ROUTE_22", x = 28, y = 4 }
  loaded.options = SaveData.loadOptions()
  loaded.options.textSpeed = 1
  loaded.meta = SaveData.buildMeta(assert(game.modStatus and game.modStatus.loaded,
    "active Route22 package closure missing"), loaded.meta)

  local firstSlot = "slot65route22_" .. variant:lower() .. "_first"
  local lateSlot = "slot65route22_" .. variant:lower() .. "_late"
  assert(SaveData.setActiveSlot(edition, firstSlot) == firstSlot,
    "could not reserve Route22 first native slot")

  -- Restore once through the real engine so the current package owns the
  -- selected identity bucket; no direct extended-character save schema is
  -- duplicated in this fixture builder.
  game:restoreSave(loaded, false)
  U.wait(24)
  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Route22 setup cannot reach installed Authority exports")
  local characters = assert(api.extendedCharacters,
    "Route22 setup cannot select an extended character")
  local selected = characters.select(character.player)
  characters.refreshVisuals(game)
  assert(selected.player_character == character.player
      and selected.rival_character == character.rival
      and selected.third_character == character.third,
    "Route22 setup selected the wrong character matrix")
  game.save.qaRoute22Origin = {
    version = 1,
    variant = variant,
    kind = originKind,
    sourceSha256 = sourceSha,
    packageGateReceiptSha256 = gateSha,
    playerCharacter = character.player,
    rivalCharacter = character.rival,
    thirdCharacter = character.third,
    stage = "first",
  }
  assert(game:writeSave(),
    "could not persist Route22 first prerequisite through native SAVE")
  local first = assert(SaveData.load(edition),
    "could not reload Route22 first prerequisite")
  assert(first.player and first.player.map == "ROUTE_22"
      and first.player.x == 28 and first.player.y == 4
      and first.flags.EVENT_GOT_POKEDEX == true
      and first.flags.EVENT_BEAT_BROCK ~= true
      and first.flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE ~= true,
    "Route22 first prerequisite changed during native persistence")

  local encoded = assert(SaveData.encode(first))
  local late = assert(SaveData.decode(encoded))
  late.flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE = true
  late.flags.EVENT_BEAT_BROCK = true
  late.flags.EVENT_BEAT_GIOVANNI = true
  late.flags.EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE = nil
  late.player.map, late.player.x, late.player.y = "ROUTE_22", 28, 4
  late.player.facing, late.player.surfing = "right", false
  late.lastOutdoor = { id = "ROUTE_22", x = 28, y = 4 }
  late.qaRoute22Origin.stage = "late"
  assert(SaveData.setActiveSlot(edition, lateSlot) == lateSlot,
    "could not reserve Route22 late native slot")
  assert(SaveData.writeSlot(edition, lateSlot, late),
    "could not persist Route22 late prerequisite")
  local verifiedLate = assert(SaveData.load(edition),
    "could not reload Route22 late prerequisite")
  assert(verifiedLate.flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE == true
      and verifiedLate.flags.EVENT_BEAT_BROCK == true
      and verifiedLate.flags.EVENT_BEAT_GIOVANNI == true
      and verifiedLate.flags.EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE ~= true
      and verifiedLate.qaRoute22Origin.stage == "late",
    "Route22 late prerequisite changed during slot persistence")

  assert(SaveData.setActiveSlot(edition, firstSlot) == firstSlot,
    "could not restore Route22 first slot as CONTINUE target")
  local verifiedFirst = assert(SaveData.load(edition),
    "Route22 first CONTINUE target disappeared")
  assert(verifiedFirst.qaRoute22Origin.stage == "first"
      and verifiedFirst.qaRoute22Origin.kind == originKind
      and verifiedFirst.qaRoute22Origin.sourceSha256 == sourceSha
      and verifiedFirst.qaRoute22Origin.packageGateReceiptSha256 == gateSha,
    "Route22 first CONTINUE target lost immutable provenance")

  U.log(("ROUTE22 PACKAGE SETUP PASS edition=%s variant=%s origin=%s")
    :format(edition, variant, originKind))
  love.event.quit(0)
end
