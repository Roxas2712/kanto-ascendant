-- Package-only reverse runtime closure for every module group in
-- MODULE_ACCEPTANCE_MAP.tsv.  L09 runs after L00-L08.  It accepts their
-- fixed receipts only when all candidate hashes match, then exercises the
-- three runtime groups which have no owning package lane of their own.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")

  local function sha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end

  local hashes = {
    engine_payload_sha256 = sha("KA_ENGINE_PAYLOAD_SHA256"),
    authority_package_sha256 = sha("KA_AUTHORITY_PACKAGE_SHA256"),
    deutsch_package_sha256 = sha("KA_DEUTSCH_PACKAGE_SHA256"),
    package_gate_receipt_sha256 = sha("KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }

  local runtimeSource = love.filesystem.getSource()
  local loaded = assert(game.mods and game.mods.mods
      and game.mods.mods.kanto_ascendant,
    "installed Kanto Ascendant package is missing")
  local authorityPath = tostring(loaded.path or "")
  for _, path in ipairs({ tostring(runtimeSource or ""), authorityPath }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end

  local function parent(path)
    return assert(path:match("^(.*)/[^/]+/?$"),
      "SHOT_DIR must have a package-evidence parent")
  end
  local evidenceRoot = parent(dir)
  assert(dir == evidenceRoot .. "/L09_REVERSE_MODULE_SURFACES",
    "L09 SHOT_DIR must be the fixed package-evidence lane directory")
  local receiptRoot = evidenceRoot .. "/compat_receipts"
  local moduleMapPath = assert(os.getenv("KA_MODULE_ACCEPTANCE_MAP"),
    "KA_MODULE_ACCEPTANCE_MAP is required")
  local moduleMapSha = sha("KA_MODULE_ACCEPTANCE_MAP_SHA256")

  local function readFile(path)
    local file = assert(io.open(path, "rb"), path .. " is missing")
    local body = assert(file:read("*a"), path .. " is unreadable")
    file:close()
    return body
  end
  local function bodySha256(body)
    local digest = love.data.hash("sha256", body)
    return love.data.encode("string", "hex", digest):lower()
  end
  local moduleMapBody = readFile(moduleMapPath)
  assert(bodySha256(moduleMapBody) == moduleMapSha,
    "MODULE_ACCEPTANCE_MAP SHA drifted")
  assert(not moduleMapBody:find("\r", 1, true)
      and moduleMapBody:sub(-1) == "\n",
    "MODULE_ACCEPTANCE_MAP is not canonical LF-delimited TSV")
  local mapHeader = assert(moduleMapBody:match("^([^\n]+)\n"),
    "MODULE_ACCEPTANCE_MAP is empty")
  assert(mapHeader == "module\tacceptance_group",
    "MODULE_ACCEPTANCE_MAP header drifted")
  local mappedModules, mappedGroups = {}, {}
  local rowIndex = 0
  for line in moduleMapBody:gmatch("([^\n]+)\n") do
    rowIndex = rowIndex + 1
    if rowIndex > 1 then
    local module, group = line:match("^([^\t]+)\t([^\t]+)$")
    assert(module and group and module:match("^[A-Za-z0-9_]+%.lua$")
        and group:match("^[a-z0-9_]+$")
        and not mappedModules[module],
      "MODULE_ACCEPTANCE_MAP row malformed/duplicate: " .. tostring(line))
    mappedModules[module] = true
    mappedGroups[group] = true
    end
  end
  local mappedModuleCount, mappedGroupCount = 0, 0
  for _ in pairs(mappedModules) do mappedModuleCount = mappedModuleCount + 1 end
  for _ in pairs(mappedGroups) do mappedGroupCount = mappedGroupCount + 1 end
  assert(mappedModuleCount == 148 and mappedGroupCount == 20,
    "MODULE_ACCEPTANCE_MAP cardinality drifted")

  local packageModules = {}
  local packageItems = assert(love.filesystem.getDirectoryItems(authorityPath),
    "cannot enumerate installed Authority package")
  for _, name in ipairs(packageItems) do
    if name:match("%.lua$") then
      local info = assert(love.filesystem.getInfo(authorityPath .. "/" .. name),
        "installed Authority module disappeared: " .. name)
      assert(info.type == "file" and name:match("^[A-Za-z0-9_]+%.lua$")
          and not packageModules[name],
        "installed Authority module enumeration malformed/duplicated: " .. name)
      packageModules[name] = true
    end
  end
  local packageModuleCount = 0
  for module in pairs(packageModules) do
    packageModuleCount = packageModuleCount + 1
    assert(mappedModules[module], "unmapped installed Authority module: " .. module)
  end
  for module in pairs(mappedModules) do
    assert(packageModules[module], "mapped Authority module absent from package: " .. module)
  end
  assert(packageModuleCount == mappedModuleCount,
    "installed Authority module count drifted")

  local function parseReceipt(path)
    local file = assert(io.open(path, "rb"), "missing prior lane receipt: " .. path)
    local values = {}
    for line in file:lines() do
      local key, value = line:match("^([a-z0-9_]+)=([^\r\n]+)$")
      assert(key and not values[key], "malformed/duplicate receipt row: " .. line)
      values[key] = value
    end
    file:close()
    return values
  end

  local lanes = {
    "L00_RUNTIME_CLOSURE",
    "L01_BOOT_UPGRADE_RULES",
    "L02_PRESENTATION_MOTION",
    "L03_HEVO_MATRIX",
    "L04_NGPLUS_LEGACY",
    "L05_JOHTO_LEAGUE",
    "L06_WANDERERS_REMATCH",
    "L07_BALLS_TMS_ITEM_UI",
    "L08_OAK_MEW_ROUTE22",
  }
  local laneReceipts = {}
  for _, lane in ipairs(lanes) do
    local path = receiptRoot .. "/" .. lane .. ".receipt"
    local receipt = parseReceipt(path)
    assert(receipt.receipt_contract == "BLITZ_PACKAGE_RECEIPT_V1",
      lane .. " uses an unknown receipt contract")
    assert(receipt.lane_id == lane and receipt.status == "PASS",
      lane .. " is not a successful fixed lane receipt")
    assert(type(receipt.lane_evidence_sha256) == "string"
        and #receipt.lane_evidence_sha256 == 64
        and receipt.lane_evidence_sha256:match("^[0-9a-f]+$"),
      lane .. " does not bind its canonical lane evidence")
    for key, expected in pairs(hashes) do
      assert(receipt[key] == expected,
        lane .. " does not belong to the same frozen package: " .. key)
    end
    laneReceipts[lane] = receipt
  end

  local owners = {
    boot_migration_language = "L01_BOOT_UPGRADE_RULES",
    ascendant_ui_help = "L07_BALLS_TMS_ITEM_UI",
    bag_pc_capture = "L07_BALLS_TMS_ITEM_UI",
    comfort_features = "L07_BALLS_TMS_ITEM_UI",
    battle_qol = "L07_BALLS_TMS_ITEM_UI",
    character_trainer_art = "L02_PRESENTATION_MOTION",
    shiny_mega_runtime = "L02_PRESENTATION_MOTION",
    field_tech_movement = "L07_BALLS_TMS_ITEM_UI",
    wilds_visibility = "L02_PRESENTATION_MOTION",
    follower_runtime = "L02_PRESENTATION_MOTION",
    postgame_core = "L05_JOHTO_LEAGUE",
    difficulty_run_rules = "L01_BOOT_UPGRADE_RULES",
    compatibility_closure = "L00_RUNTIME_CLOSURE",
    hidden_evolution = "L03_HEVO_MATRIX",
    legacy_ngplus = "L04_NGPLUS_LEGACY",
    rematch_progression = "L06_WANDERERS_REMATCH",
    ball_systems = "L07_BALLS_TMS_ITEM_UI",
  }

  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "loaded Authority export is missing")
  local pass, fail = 0, 0
  local report = {
    "scope=DRV-MODULE-REVERSE-RUNTIME",
    "receipt_contract=BLITZ_PACKAGE_RECEIPT_V1",
    "status=RUNNING",
    "runtime_source=" .. tostring(runtimeSource),
    "authority_runtime_path=" .. authorityPath,
  }
  for key, value in pairs(hashes) do report[#report + 1] = key .. "=" .. value end

  local function check(group, proof, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", group, proof)
    report[#report + 1] = (value and "PASS" or "FAIL")
      .. "\t" .. group .. "\t" .. proof
    return value
  end

  for group, lane in pairs(owners) do
    check(group, "prior_same_hash_receipt=" .. lane, laneReceipts[lane] ~= nil)
  end

  -- Real residual surface 1: breeding/daycare.  This uses two actual engine
  -- Pokemon and the installed compatibility calculation, not a loaded-module
  -- inventory or a fabricated result table.
  local daycare = assert(api.daycare, "installed Day-Care controller missing")
  local female = Pokemon.new(game.data, "PIKACHU", 18)
  local male = Pokemon.new(game.data, "PIKACHU", 18)
  female.dvs.attack, male.dvs.attack = 0, 15
  female.otId, male.otId = 65001, 65002
  local compatible, compatibility = daycare.compatible(game, female, male)
  check("breeding_daycare", "real_parent_compatibility",
    compatible == true and compatibility == 255
      and daycare.babyFor(game, "PIKACHU") == "PICHU")

  -- Real residual surface 2: Johto and Mythic.  Open both installed list
  -- menus and capture their actual rendered rows before returning to field.
  local hub = assert(api.signalsHub, "installed Signals Hub missing")
  local johtoMenu = hub.openJohto(game)
  U.wait(3)
  check("johto_mythic", "real_johto_menu",
    johtoMenu and game.stack:top() == johtoMenu
      and type(johtoMenu.items) == "table" and #johtoMenu.items >= 4)
  check("johto_mythic", "johto_menu_capture",
    U.shot(game, dir .. "/01_johto_signals.png"))
  game.stack:pop()
  local mythicMenu = hub.openMythic(game)
  U.wait(3)
  check("johto_mythic", "real_mythic_menu",
    mythicMenu and game.stack:top() == mythicMenu
      and type(mythicMenu.items) == "table" and #mythicMenu.items == 3)
  check("johto_mythic", "mythic_menu_capture",
    U.shot(game, dir .. "/02_mythic_signals.png"))
  game.stack:pop()

  -- Real residual surface 3: the shared World list plus both independent
  -- stateful consumers which are not owned by another package lane.
  local worldMenu = hub.openWorld(game)
  U.wait(3)
  local worldEvents = assert(api.worldEvents, "World Events controller missing")
  local grandTour = assert(api.grandTour, "Grand Tour controller missing")
  local eventArchive = assert(api.eventArchive, "Event Archive controller missing")
  local eventData = assert(api.eventData and api.eventData.profiles,
    "Event Archive data missing")
  local archiveText = eventArchive.details(game, assert(eventData.profiles[1]))
  check("world_events_tour", "real_world_menu",
    worldMenu and game.stack:top() == worldMenu
      and type(worldMenu.items) == "table" and #worldMenu.items >= 3)
  check("world_events_tour", "stateful_status_surfaces",
    type(worldEvents.statusText(game)) == "string"
      and type(grandTour.statusText()) == "string"
      and type(archiveText) == "string")
  check("world_events_tour", "world_menu_capture",
    U.shot(game, dir .. "/03_world_status.png"))
  game.stack:pop()

  local expectedGroups = mappedGroupCount
  local seenGroups = {}
  for _, line in ipairs(report) do
    local group = line:match("^[A-Z]+\t([^\t]+)\t")
    if group then seenGroups[group] = true end
  end
  local groupCount = 0
  for _ in pairs(seenGroups) do groupCount = groupCount + 1 end
  local groupsMatch = groupCount == expectedGroups
  for group in pairs(seenGroups) do
    groupsMatch = groupsMatch and mappedGroups[group] == true
  end
  for group in pairs(mappedGroups) do
    groupsMatch = groupsMatch and seenGroups[group] == true
  end
  check("reverse_runtime_summary", "all_mapped_groups", groupsMatch)

  report[#report + 1] = "status=" .. (fail == 0 and "PASS" or "FAIL")
  report[#report + 1] = "mapped_modules=" .. tostring(mappedModuleCount)
  report[#report + 1] = "acceptance_groups=" .. tostring(groupCount)
  report[#report + 1] = "pass=" .. tostring(pass)
  report[#report + 1] = "fail=" .. tostring(fail)
  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write(table.concat(report, "\n"), "\n")
  result:close()
  love.event.quit(fail == 0 and 0 or 1)
end
