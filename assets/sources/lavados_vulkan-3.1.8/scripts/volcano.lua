-- Quest logic and dialogue for the Cinnabar Volcano.
--
-- Plain dialogue is data: it goes into the text registry and is bound to a
-- TEXT_* constant through text_pointers.  Only the entries that need state --
-- the four lava blockages, the ruby pickups, the boss Magmar and the Victory
-- Road Moltres removal -- are scripts.
--
-- questData.rocks[].blocks rows are { bx, by, blockId } in block coordinates,
-- generated from pureRGB scripts/CinnabarVolcano.asm.
--
-- Dialogue stays ASCII: the extracted Red charmap has no umlaut glyphs, and
-- Font.encode draws an unmapped character as a space.  Line breaks are the
-- markers TextBox.paginate splits on -- "\n" is the box's second line and "\f"
-- a new page, the same pair pokered's `line` and `para` produce.  "#" is not
-- one of them; it is not in the charmap at all, which is why every box drew as
-- one wrapped run-on line before 3.0.4.
return function(mod, questData)
  local VOLCANO = "CINNABAR_VOLCANO"
  local VOLCANO_WEST = "CINNABAR_VOLCANO_WEST"
  local VICTORY_ROAD = "VICTORY_ROAD_2F"
  local VICTORY_ROAD_MOLTRES = "VICTORYROAD2F_MOLTRES"
  local FLAG_MOLTRES_MOVED = "MOD_LV_MOLTRES_MOVED"

  -- ------------------------------------------------------------------ text

  local texts = {
    _LvRoute21VolcanoSign =
      "WARNUNG!\fVulkanhoehle -\nBetreten auf\feigene Gefahr!",
    -- The prospector's hand-over, from text/CinnabarVolcano.asm:
    -- _CinnabarVolcanoProspectorGreetingNotMetText -> ...StrongMonsText ->
    -- ...LavaSuitText -> ...LetsGo, the four boxes
    -- CinnabarVolcanoProspectorText prints around the sprite change.
    _LvProspectorGreeting =
      "He, Kleiner!\fHier ist es\ngefaehrlich!\fWas machst du\nhier?\fHuh! Du hast ja\nstarke POKEMON!",
    _LvProspectorStrongMons =
      "Im VULKAN ist es\nzu heiss fuer\vnormale Forscher.\fVielleicht kannst\ndu uns helfen!\fAber zuerst\nbrauchst du so\vein Teil hier-",
    _LvProspectorLavaSuit =
      "Das ist ein\nLAVA-ANZUG!\fEr schuetzt dich\nvor der Hitze!\fDa drin ist es\nwie im Backofen!\fHier, zieh den\nmal an!",
    _LvProspectorLetsGo = "Sieht gut aus!\fAlso los,\nfolge mir!",
    -- _VolcanoProspectorAfterMessage, the line he keeps once he has helped
    _LvProspector =
      "Ich suche hier\nnach Rubinen.\fAngeblich gluehen\nsie wie Lava.",
    _LvBlaine =
      "PYRO: Du hier?\fDieser Vulkan ist\nmein Trainings-\vplatz.\fTief unten soll\nein Vogel aus\vFeuer nisten.\fLAVADOS!",
    _LvArcanine = "ARKANI: Wuff!",
    _LvMoltres = "LAVADOS: Gwaaah!",
    _LvSurfingRhydon = "RIZEROS: Groarr!\fEs surft seelen-\nruhig auf der Lava.",
    _LvRhydonMakesWay =
      "Es rueckt zur Seite\nund gibt den Weg\vauf den Lavasee\vfrei.",
    _LvRhydonGone = "Der Abstieg zum\nLavasee ist frei.",
    _LvHungryGraveler = "GEOROK: Grrmpf...\fEs hat wohl Hunger.",
    _LvSickRhydon = "RIZEROS: Roechel...\fIhm ist von den\nDaempfen schlecht.",
    -- pureRGB renames ruby 2 and 3 to rock salts and limestone on the crater
    -- floor and trades them for a free lane (CinnabarVolcanoHungryGravelerText,
    -- CinnabarVolcanoSickRhydonText).
    _LvGravelerFed =
      "Du gibst GEOROK\neinen Rubin.\fEs knabbert zu-\nfrieden und rueckt\vaus dem Weg.",
    _LvGravelerNoFood =
      "GEOROK: Grrmpf...\fEs hat Hunger und\nruehrt sich nicht.\fVielleicht mag es\nGestein?",
    _LvGravelerFull = "GEOROK: Grmmm...\fEs kaut zufrieden.",
    _LvRhydonHealed =
      "Du zerreibst einen\nRubin zu Pulver.\fRIZEROS schluckt\nes und kriecht\vzur Seite.",
    _LvRhydonNoCure =
      "RIZEROS: Roechel...\fEs braucht etwas\ngegen den Magen\vund blockiert\vsolange den Weg.",
    _LvRhydonBetter = "RIZEROS: Rooo!\fEs geht ihm besser.",
    _LvWestMagmar = "MAGMAR: Maaag!",
    _LvWestLavaFlow =
      "Der Lavastrom\nfliesst nach Osten\vin den Hauptkrater.",
    _LvRubyTaken = "Hier lag ein Rubin.",
    _LvRubyFound = "Ein gluehend roter\nRubin liegt hier!",
    _LvRubyTwoMore = "Noch zwei Rubine\nfehlen fuer den\nBohrer.",
    _LvRubyOneMore = "Noch ein Rubin\nfehlt fuer den\nBohrer.",
    _LvRubyAllThree = "Alle drei Rubine!\fDer Bohrer ist\naufgeladen!",
    _LvDrillNoFuel =
      "Der Bohrer hat\nkeinen Treibstoff!\fFinde drei Rubine\nzum Auftanken!",
    _LvDrillLavaBlocked =
      "Noch ist Lava im\nunteren Bereich,\fBohren noch nicht\nmoeglich!",
    _LvDrillOpened = "Der Bohrer oeffnet\ndas Loch!",
    _LvRockCleared = "Der Weg ist frei.\fDie Lava fliesst\nwieder.",
    -- pureRGB _VolcanoBlockagesGone / _VolcanoGoBackMainFloor, the message
    -- VolcanoBlowWallOpen prints once the last blockage is down.
    _LvAllBlockagesGone =
      "Alle vier Sperren\nsind beseitigt!\fDie Lava sackt ab...",
    _LvGoBackMainFloor =
      "Im Hauptkrater ist\nein Steg aus dem\vGestein aufge-\vtaucht.\fGeh zurueck nach\noben!",
  }

  local function pointer(label)
    return { text = label }
  end

  local textPointers = {
    Route21 = {
      TEXT_MOD_LV_ROUTE21_VOLCANO_SIGN = pointer("_LvRoute21VolcanoSign"),
    },
    CinnabarVolcano = {
      TEXT_CINNABAR_VOLCANO_PROSPECTOR = pointer("_LvProspector"),
      TEXT_CINNABAR_VOLCANO_BLAINE = pointer("_LvBlaine"),
      TEXT_CINNABAR_VOLCANO_ARCANINE = pointer("_LvArcanine"),
      TEXT_CINNABAR_VOLCANO_MOLTRES = pointer("_LvMoltres"),
      TEXT_CINNABAR_VOLCANO_HUNGRY_GRAVELER = pointer("_LvHungryGraveler"),
      TEXT_CINNABAR_VOLCANO_SICK_RHYDON = pointer("_LvSickRhydon"),
    },
    CinnabarVolcanoWest = {
      TEXT_CINNABAR_VOLCANO_WEST_MAGMAR1 = pointer("_LvWestMagmar"),
      TEXT_CINNABAR_VOLCANO_WEST_MAGMAR2 = pointer("_LvWestMagmar"),
      TEXT_CINNABAR_VOLCANO_WEST_MAGMAR3 = pointer("_LvWestMagmar"),
      TEXT_CINNABAR_VOLCANO_WEST_MAGMAR4 = pointer("_LvWestMagmar"),
      TEXT_CINNABAR_VOLCANO_WEST_MAGMAR5 = pointer("_LvWestMagmar"),
      TEXT_CINNABAR_VOLCANO_WEST_LAVA_FLOW = pointer("_LvWestLavaFlow"),
    },
  }

  -- ------------------------------------------------------- block stamping

  -- One renderer rebuild for the whole batch: rock #4 alone rewrites ~170
  -- blocks, and replaceBlock rebuilds on every call.
  local function stampBlocks(ow, rows, rebuild)
    local map = ow and ow.map
    if not map or not map.setBlock then return end
    for _, row in ipairs(rows) do
      local bx, by, block = row[1], row[2], row[3]
      if bx >= 0 and by >= 0 and bx < map.def.width and by < map.def.height then
        map:setBlock(bx, by, block)
      end
    end
    if rebuild and map.renderer and map.renderer.rebuild then
      map.renderer:rebuild()
    end
  end

  local function npcByName(ow, name)
    for _, entity in ipairs((ow and ow.npcs) or {}) do
      if entity.def and entity.def.name == name then return entity end
    end
    return nil
  end

  -- Drop an NPC on a cell with no walk animation, the way pureRGB's map load
  -- writes wSprite<n>StateData2MapX/Y straight into the sprite's slot.
  local function placeNpc(ow, name, cellX, cellY)
    local entity = npcByName(ow, name)
    if not entity then return end
    entity.cellX, entity.cellY = cellX, cellY
    entity.px, entity.py = cellX * 16, cellY * 16
    entity.targetX, entity.targetY = nil, nil
    entity.moving, entity.progress = false, 0
  end

  -- ---------------------------------------------------------- the lava suit

  -- In pureRGB the suit is a player STATE, not an item and not a key to the
  -- lava: CinnabarVolcanoProspectorText sets wWalkBikeSurfState =
  -- WEARING_LAVA_SUIT and copies LavaSuitSprite over the player's tiles,
  -- CinnabarVolcanoOnMapLoad restores both on every volcano entry, and
  -- scripts/Route21.asm puts WALKING and the walking sprite back "if we just
  -- exited the volcano".  Lava itself never becomes walkable -- it is absent
  -- from Volcano_Coll and present in LavaSurfTiles, so it is ridden either way
  -- (LoadSurfingPlayerSpriteGraphics swaps the SEEL for a RHYDON in here).
  -- So the whole mechanic is the pair of sprites, which is exactly what this
  -- does.
  local suit = questData.lavaSuit
  local SUIT_FLAG = suit.flag
  local suitMaps = {}
  for _, id in ipairs(suit.maps) do suitMaps[id] = true end

  -- Player:pose picks player.sprite on foot and player.surfSprite on the
  -- water, both built once in Player.new from field.playerSprites.  There is no
  -- registry for "what the player wears on this map", so the swap is those two
  -- fields.  SpriteRenderer comes off the live instance's own metatable rather
  -- than a src.* require, and the originals are captured before anything
  -- overwrites them -- keyed weakly, so a reloaded save gets its own pair.
  local spriteSets = setmetatable({}, { __mode = "k" })

  local function spriteSet(game, player)
    local entry = spriteSets[player]
    if entry then return entry end
    local class = player.sprite and getmetatable(player.sprite)
    local walk = game.data.sprites[suit.sprites.walk]
    local surf = game.data.sprites[suit.sprites.surf]
    if not (class and class.new and walk and surf) then return nil end
    entry = {
      normal = { walk = player.sprite, surf = player.surfSprite },
      suited = { walk = class.new(walk, "player"),
                 surf = class.new(surf, "player") },
    }
    spriteSets[player] = entry
    return entry
  end

  local function wearLavaSuit(game, ow, on)
    local player = ow and ow.player
    if not player then return end
    local set = spriteSet(game, player)
    if not set then return end
    local pick = on and set.suited or set.normal
    player.sprite, player.surfSprite = pick.walk, pick.surf
  end

  -- CinnabarVolcanoOnMapLoad re-dresses the player on every volcano load and
  -- Route21 undresses on the way out.  Both are map loads, so one listener
  -- covers them -- and every other way out of the volcano too (FLY, a blackout,
  -- a dungeon warp), where the original would leave the suit on.
  -- One OverworldState serves every map, so the pair captured on the first
  -- volcano load stays valid for the walk back out to Route 21.
  local liveGame, liveOw = nil, nil

  local function rememberWorld(game, ow)
    liveGame, liveOw = game, ow
  end

  mod.events:on("map.entered", function(payload)
    if not (liveGame and liveOw) then return end
    local mapId = payload and payload.mapId
    wearLavaSuit(liveGame, liveOw,
                 (suitMaps[mapId] and liveGame.save.flags[SUIT_FLAG]) and true
                 or false)
  end)

  local function prospectorHandler(game, ow, npc, onDone)
    local done = onDone or function() end
    if game.save.flags[SUIT_FLAG] then
      ow.runner:run({ { "show_text", texts._LvProspector } },
                    { npc = npc, onDone = done })
      return
    end
    ow.runner:run({
      { "show_text", texts._LvProspectorGreeting },
      { "show_text", texts._LvProspectorStrongMons },
      { "show_text", texts._LvProspectorLavaSuit },
      { "set_flag", SUIT_FLAG },
      { "show_text", texts._LvProspectorLetsGo },
    }, {
      npc = npc,
      onDone = function()
        wearLavaSuit(game, ow, true)
        done()
      end,
    })
  end

  -- CheckForceTalkToProspector .firstStep: at wYCoord 2 / wXCoord 3 the player
  -- is turned left and the conversation opens itself.  The entrance room is a
  -- corridor and the prospector plugs the column beside it, so this cell is the
  -- only way to the warps out -- build_mod.py's verify_lava_suit proves that
  -- rather than trusting it, which is what makes a suitless player impossible.
  local function forceProspectorTalk(game, ow, cellX, cellY)
    if game.save.flags[SUIT_FLAG] then return false end
    if cellX ~= suit.trigger.x or cellY ~= suit.trigger.y then return false end
    if ow.runner and ow.runner:isRunning() then return false end
    rememberWorld(game, ow)
    local npc = npcByName(ow, suit.npc)
    ow.player.facing = "left"
    if npc then npc.facing = "right" end
    prospectorHandler(game, ow, npc)
    return true
  end

  -- ------------------------------------------------------------- the rocks

  local rockTexts = {
    [1] = "Ein Lavapfropfen\nversperrt den Weg.\f...Er broeckelt\nund gibt nach!",
    [2] = "Erkaltete Lava\nblockiert den Gang.\f...Sie zerfaellt\nzu Asche!",
    [3] = "Ein Felsbrocken\nstaut den Lavasee.\f...Er kippt in\ndie Glut!",
    [4] = "Der letzte Pfrop-\nfen vor dem Krater.\f...Der Berg bebt --\ndie Lava bricht\vdurch!",
  }

  -- ------------------------------------------------------- the crater path

  -- pureRGB gates the four blockages behind each other (DrilledFloor<n>Ladder
  -- refuses to dig until the floor above is bombed), so the wall only ever
  -- blows open on the fourth one.  This port bakes the drill holes into the
  -- map, so the flags are what enforces "all four" here.
  local bridge = questData.bridge

  -- justCleared spares the caller any assumption about when the runner's
  -- set_flag lands relative to its onDone.
  local function allRocksCleared(game, justCleared)
    for _, rock in ipairs(questData.rocks) do
      if not (game.save.flags[rock.flag] or rock.flag == justCleared) then
        return false
      end
    end
    return true
  end

  local function rockHandler(rock)
    return function(game, ow, npc, onDone)
      local done = onDone or function() end
      if game.save.flags[rock.flag] then
        ow.runner:run({ { "show_text", texts._LvRockCleared } },
                      { npc = npc, onDone = done })
        return
      end
      local script = {
        { "show_text", rockTexts[rock.floor] or "Der Weg ist frei." },
        { "set_flag", rock.flag },
        { "hide_object", VOLCANO, rock.name },
      }
      -- pureRGB walks the player four cells clear before the crater is sealed
      -- (CinnabarVolcanoBombRockText .floor4 queues four PAD_UP presses, and
      -- only then does CheckWaitForVolcanoSpriteWalk.easternWall run
      -- VolcanoBlowWallOpen).  Without it the new walls close around whoever
      -- is standing next to the fourth blockage.
      if rock.escape then
        script[#script + 1] = { "move_player", rock.escape.dir, rock.escape.tiles }
      end
      ow.runner:run(script, {
        npc = npc,
        onDone = function()
          stampBlocks(ow, rock.blocks, true)
          if rock.floor and rock.floor < 4 and not floorHoleOpen(game, rock.floor) then
            reshowRubies(game, ow, rock.floor)
          end
          latchDugHoles(game, ow)
          stampBlocks(ow, drillHoleRows(game), true)
          if not allRocksCleared(game, rock.flag) then
            done()
            return
          end
          -- All four floors are one map, so the crater path can be stamped
          -- from down here; onEnter re-stamps it from the flag afterwards.
          ow.runner:run({
            { "show_text", texts._LvAllBlockagesGone },
            { "set_flag", bridge.flag },
            { "show_text", texts._LvGoBackMainFloor },
          }, {
            npc = npc,
            onDone = function()
              stampBlocks(ow, bridge.blocks, true)
              done()
            end,
          })
        end,
      })
    end
  end

  -- The blast walls off the crater lake for good, so anyone whose save puts
  -- them down there -- a save written before this build shipped the escape
  -- walk, or a blackout landing -- comes back to a sealed pool.  pureRGB's
  -- answer is the forced walk in VolcanoBlowWallOpen; this is the same exit,
  -- applied on load.
  local SEALED_CRATER_Y = 62
  local CRATER_EXIT = { x = 48, y = 61 }

  local function rescueFromSealedCrater(game, ow)
    local last = questData.rocks[#questData.rocks]
    if not (last and last.escape and game.save.flags[last.flag]) then return end
    local player = ow and ow.player
    if not player or player.cellY < SEALED_CRATER_Y then return end
    player.cellX, player.cellY = CRATER_EXIT.x, CRATER_EXIT.y
    player.px, player.py = CRATER_EXIT.x * 16, CRATER_EXIT.y * 16
    player.targetX, player.targetY = nil, nil
    player.moving, player.progress = false, 0
    if ow.camera and game.renderer and game.renderer.worldViewSize then
      ow.camera:follow(player.px, player.py, game.renderer:worldViewSize())
    end
  end

  -- Progress the player already made: the layout changes live in the save as
  -- flags, so they have to be re-stamped on every entry.
  local function restoreVolcanoLayout(game, ow)
    -- map.entered fires before this hook, so the very first volcano load has
    -- nothing for the listener to work with; this is where it gets it.
    rememberWorld(game, ow)
    wearLavaSuit(game, ow, game.save.flags[SUIT_FLAG] and true or false)
    local rows = {}
    for _, rock in ipairs(questData.rocks) do
      if game.save.flags[rock.flag] then
        for _, row in ipairs(rock.blocks) do rows[#rows + 1] = row end
      end
    end
    -- Older saves reached the fourth blockage before the flag existed.
    if game.save.flags[bridge.flag] or allRocksCleared(game) then
      game.save.flags[bridge.flag] = true
      for _, row in ipairs(bridge.blocks) do rows[#rows + 1] = row end
    end
    if #rows > 0 then stampBlocks(ow, rows, true) end
    stampBlocks(ow, drillHoleRows(game), false)
    latchRubyReshownFlags(game)
    -- pureRGB ShowRubies runs once per rock bomb (floors 1–3); RepositionRubies
    -- on map load keeps objectToggles=false (collected) hidden.  Old saves that
    -- bombed rock 2 before reshowRubies existed never got that reset — reshow once.
    local reshowFloor = needsRubyReshow(game)
    if reshowFloor then
      reshowRubies(game, ow, reshowFloor)
    else
      repositionRubies(game, ow)
    end
    -- .floor4 rewrites the two crater Pokemon's MapY on every load, so their
    -- lane stays open once they have been paid.
    for _, move in ipairs(questData.npcMoves or {}) do
      if game.save.flags[move.flag] then
        placeNpc(ow, move.name, move.x, move.y)
      end
    end
    rescueFromSealedCrater(game, ow)
  end

  local drillData = questData.drillHoles or {}
  local rubyNames = drillData.rubies or {
    "CINNABAR_VOLCANO_RUBY1", "CINNABAR_VOLCANO_RUBY2", "CINNABAR_VOLCANO_RUBY3",
  }
  local rubyDefaults = drillData.rubyDefaults or {}
  local rubyFloors = drillData.rubyFloors or {}
  local drillHoles = drillData.holes or {}

  local okCommands, Commands = pcall(require, "src.script.Commands")

  local function togglesFor(mapId, game)
    local save = (game and game.save) or (liveGame and liveGame.save)
    if not save then return nil end
    save.objectToggles = save.objectToggles or {}
    local mapToggles = save.objectToggles[mapId]
    if not mapToggles then
      mapToggles = {}
      save.objectToggles[mapId] = mapToggles
    end
    return mapToggles
  end

  local function rubyHeld(game, name)
    local toggles = togglesFor(VOLCANO, game)
    return toggles and toggles[name] == false
  end

  local function countHeldRubies(game)
    local n = 0
    for _, name in ipairs(rubyNames) do
      if rubyHeld(game, name) then n = n + 1 end
    end
    return n
  end

  local function rubyStage(game)
    if game.save.flags["MOD_LV_DUG_FLOOR4"] then return 4 end
    if game.save.flags["MOD_LV_DUG_FLOOR3"] then return 3 end
    if game.save.flags["MOD_LV_DUG_FLOOR2"] then return 2 end
    return 1
  end

  local function rubyPos(name, stage)
    if stage == 1 then
      local d = rubyDefaults[name]
      return d and d.x, d and d.y
    end
    local floor = rubyFloors[tostring(stage)]
    if not floor then return nil end
    local entry = floor[name]
    return entry and entry.x, entry and entry.y
  end

  local function visibleRubies(stage)
    if stage == 4 then
      return { "CINNABAR_VOLCANO_RUBY2", "CINNABAR_VOLCANO_RUBY3" }
    end
    return rubyNames
  end

  local function allRubiesHeld(game)
    if rubyStage(game) == 4 then return false end
    return countHeldRubies(game) >= 3
  end

  local function latchDugHoles(game, ow)
    local dugNew = false
    for _, hole in ipairs(drillHoles) do
      if hole.dug and not game.save.flags[hole.dug]
         and game.save.flags[hole.needs] and allRubiesHeld(game) then
        game.save.flags[hole.dug] = true
        dugNew = true
        if hole.dug == "MOD_LV_DUG_FLOOR4" then
          local toggles = togglesFor(VOLCANO, game)
          if toggles then
            toggles["CINNABAR_VOLCANO_RUBY2"] = nil
            toggles["CINNABAR_VOLCANO_RUBY3"] = nil
          end
        end
      end
    end
    -- pureRGB RepositionRubies runs when a dug-floor event is set; without
    -- this the three sprites stay on the previous floor's coords until reload.
    if dugNew and ow then repositionRubies(game, ow) end
  end

  local function showRuby(game, ow, name)
    local toggles = togglesFor(VOLCANO, game)
    if toggles then toggles[name] = nil end
    if ow and ow.queueScript then
      ow:queueScript({ { "show_object", VOLCANO, name } })
    end
  end

  -- show_object spawns at the object list's default cell.  RepositionRubies
  -- writes sprite X/Y directly in pureRGB; here we have to spawn synchronously
  -- and place, or a post-bomb reshow leaves all three rubies on floor 1 while
  -- the player is hunting them on floor 2.
  local function showRubyAt(game, ow, name, cellX, cellY)
    local toggles = togglesFor(VOLCANO, game)
    local wasHidden = toggles and toggles[name] == false
    if toggles then toggles[name] = nil end
    if ow then
      if not npcByName(ow, name) and okCommands and Commands.show_object then
        Commands.show_object(
          { game = game, save = game.save, overworld = ow },
          VOLCANO, name)
      elseif wasHidden and ow.queueScript then
        ow:queueScript({ { "show_object", VOLCANO, name } })
      end
    end
    if cellX and cellY then
      placeNpc(ow, name, cellX, cellY)
    end
  end

  local function hideRuby(game, ow, name)
    local toggles = togglesFor(VOLCANO, game)
    if toggles then toggles[name] = false end
    if ow and ow.queueScript then
      ow:queueScript({ { "hide_object", VOLCANO, name } })
    end
  end

  local function repositionRubies(game, ow)
    local stage = rubyStage(game)
    local toggles = togglesFor(VOLCANO, game)
    for _, name in ipairs(visibleRubies(stage)) do
      local x, y = rubyPos(name, stage)
      if x and y then
        if toggles and toggles[name] == false then
          hideRuby(game, ow, name)
        else
          showRubyAt(game, ow, name, x, y)
        end
      end
    end
    if stage >= 4 then
      hideRuby(game, ow, "CINNABAR_VOLCANO_RUBY1")
    end
  end

  local function rubyReshownFlag(stage)
    return "MOD_LV_RUBIES_RESHOWN_FLOOR" .. stage
  end

  local DUG_FLAG_BY_FLOOR = {
    [1] = "MOD_LV_DUG_FLOOR2",
    [2] = "MOD_LV_DUG_FLOOR3",
    [3] = "MOD_LV_DUG_FLOOR4",
  }

  local function floorHoleOpen(game, floor)
    local dug = DUG_FLAG_BY_FLOOR[floor]
    return dug and game.save.flags[dug]
  end

  local function latchRubyReshownFlags(game)
    -- Older saves may have drilled down without ever running ShowRubies for
    -- the floor they left; stamp those floors done so reload cannot respawn
    -- rubies on a tier whose hole is already open.
    for floor = 1, 3 do
      if floorHoleOpen(game, floor) then
        game.save.flags[rubyReshownFlag(floor)] = true
      end
    end
  end

  local function needsRubyReshow(game)
    -- Mirrors pureRGB VolcanoBombableRockDone: ShowRubies while floor 4 open.
    if game.save.flags["MOD_LV_BOMBED_FLOOR4"] then return nil end
    for floor = 1, 3 do
      if game.save.flags["MOD_LV_BOMBED_FLOOR" .. floor]
         and not game.save.flags[rubyReshownFlag(floor)]
         and not floorHoleOpen(game, floor) then
        return floor
      end
    end
    return nil
  end

  local function reshowRubies(game, ow, forFloor)
    -- pureRGB ShowRubies after floors 1–3: un-hide every ruby at the current
    -- RepositionRubies coords, even if the player already picked them up on
    -- an earlier floor.  repositionRubies alone keeps objectToggles[name]=false
    -- (collected) and leaves all three invisible on floor 2 after rock 2.
    --
    -- On floor 1 the coords do not move yet (rubyStage follows dug, not bombed),
    -- so clearing held toggles here only erased drill fuel after "aufgeladen"
    -- when the player bombed rock 1 with all three rubies already picked up.
    -- From floor 2 onward the sprites move down a floor and held must reset.
    -- Once the drill hole for this floor is open, rubies must not respawn here.
    local stage = forFloor or rubyStage(game)
    if floorHoleOpen(game, stage) then return end
    local toggles = togglesFor(VOLCANO, game)
    local preserveHeld = (stage == 1)
    for _, name in ipairs(visibleRubies(stage)) do
      local x, y = rubyPos(name, stage)
      if x and y then
        if preserveHeld and toggles and toggles[name] == false then
          hideRuby(game, ow, name)
        else
          if toggles then toggles[name] = nil end
          showRubyAt(game, ow, name, x, y)
        end
      end
    end
    if stage >= 4 then hideRuby(game, ow, "CINNABAR_VOLCANO_RUBY1") end
    if stage >= 1 and stage <= 3 then
      game.save.flags[rubyReshownFlag(stage)] = true
    end
  end

  local function drillHoleRows(game)
    local rows = {}
    for _, hole in ipairs(drillHoles) do
      if hole.dug and game.save.flags[hole.dug] then
        for _, row in ipairs(hole.blocks or {}) do rows[#rows + 1] = row end
      end
    end
    return rows
  end

  local closedHoleCells = {}
  for _, hole in ipairs(drillHoles) do
    if hole.cell then
      closedHoleCells[hole.cell.x .. "," .. hole.cell.y] = hole
    end
  end

  -- ------------------------------------------------------------ the rubies

  local function rubyHandler(objName)
    return function(game, ow, npc, onDone)
      local done = onDone or function() end
      if rubyHeld(game, objName) then
        ow.runner:run({ { "show_text", texts._LvRubyTaken } },
                      { npc = npc, onDone = done })
        return
      end
      local held = countHeldRubies(game) + 1
      local counter = texts._LvRubyAllThree
      if held == 1 then counter = texts._LvRubyTwoMore
      elseif held == 2 then counter = texts._LvRubyOneMore end
      ow.runner:run({
        { "show_text", texts._LvRubyFound },
        { "play_sound", "Get_Item1" },
        { "show_text", counter },
        { "hide_object", VOLCANO, objName },
      }, {
        npc = npc,
        onDone = function()
          local toggles = togglesFor(VOLCANO, game)
          if toggles then toggles[objName] = false end
          latchDugHoles(game, ow)
          if game.save.flags["MOD_LV_DUG_FLOOR4"] then
            repositionRubies(game, ow)
          end
          stampBlocks(ow, drillHoleRows(game), true)
          done()
        end,
      })
    end
  end

  local function tryDrillHole(game, ow, cellX, cellY)
    local hole = closedHoleCells[cellX .. "," .. cellY]
    if not hole then return false end
    if hole.dug and game.save.flags[hole.dug] then return false end
    if ow.runner and ow.runner:isRunning() then return false end
    if allRubiesHeld(game) and game.save.flags[hole.needs] then
      game.save.flags[hole.dug] = true
      if hole.dug == "MOD_LV_DUG_FLOOR4" then
        local toggles = togglesFor(VOLCANO, game)
        if toggles then
          toggles["CINNABAR_VOLCANO_RUBY2"] = nil
          toggles["CINNABAR_VOLCANO_RUBY3"] = nil
        end
      end
      repositionRubies(game, ow)
      stampBlocks(ow, hole.blocks, true)
      ow.runner:run({
        { "play_sound", "Get_Item1" },
        { "show_text", texts._LvDrillOpened },
        { "move_player", "up", 1 },
      })
      return true
    end
    local denied = texts._LvDrillNoFuel
    if allRubiesHeld(game) then denied = texts._LvDrillLavaBlocked end
    ow.runner:run({
      { "play_sound", "Denied" },
      { "show_text", denied },
    })
    return true
  end

  -- ------------------------------------------------------ the lava ferryman

  -- The surfing Rhydon sits on the single lava cell that connects the crater
  -- ledge to the lava lake, so in pureRGB it is not scenery: you ride it
  -- (CinnabarVolcanoSurfingRhydonText hands the player a SURFBOARD and calls
  -- HideExtraObject) and that is how you get down to Magmar and the last
  -- blockage.  Surf does the ferrying here, so talking to it just makes it
  -- move aside -- without that the crater floor is a dead end.
  local RHYDON = "CINNABAR_VOLCANO_SURFING_RHYDON"
  local FLAG_RHYDON_MOVED = "MOD_LV_RHYDON_MOVED"

  local function surfingRhydonHandler(game, ow, npc, onDone)
    local done = onDone or function() end
    if game.save.flags[FLAG_RHYDON_MOVED] then
      ow.runner:run({ { "show_text", texts._LvRhydonGone } },
                    { npc = npc, onDone = done })
      return
    end
    ow.runner:run({
      { "show_text", texts._LvSurfingRhydon },
      { "show_text", texts._LvRhydonMakesWay },
      { "set_flag", FLAG_RHYDON_MOVED },
      { "hide_object", VOLCANO, RHYDON },
    }, { npc = npc, onDone = done })
  end

  -- ------------------------------------------- the two lava-lane squatters

  -- The hungry GRAVELER and the sick RHYDON plug the only two gaps in the
  -- crater's y61 lava lane.  pureRGB does not let you shove past them: you hand
  -- over a mineral and they step one cell down (SlideSpriteDown /
  -- GenericMoveDown), and .floor4 rewrites their MapY on every map load so the
  -- gap stays open.  The minerals are rubies 2 and 3 -- RepositionRubies drops
  -- them on this floor as "rock salts" and "limestone".
  local npcMoveTexts = {
    CINNABAR_VOLCANO_HUNGRY_GRAVELER = {
      idle = texts._LvHungryGraveler,
      refuse = texts._LvGravelerNoFood,
      give = texts._LvGravelerFed,
      after = texts._LvGravelerFull,
    },
    CINNABAR_VOLCANO_SICK_RHYDON = {
      idle = texts._LvSickRhydon,
      refuse = texts._LvRhydonNoCure,
      give = texts._LvRhydonHealed,
      after = texts._LvRhydonBetter,
    },
  }

  local function npcMoveHandler(move)
    local lines = npcMoveTexts[move.name] or {}
    return function(game, ow, npc, onDone)
      local done = onDone or function() end
      if game.save.flags[move.flag] then
        ow.runner:run({ { "show_text", lines.after } },
                      { npc = npc, onDone = done })
        return
      end
      if not rubyHeld(game, move.needsRuby) then
        ow.runner:run({ { "show_text", lines.refuse } },
                      { npc = npc, onDone = done })
        return
      end
      local script = {
        { "show_text", lines.idle },
        { "show_text", lines.give },
        { "set_flag", move.flag },
      }
      local entity = npcByName(ow, move.name)
      if entity and entity.def and entity.def.index then
        script[#script + 1] = { "move_npc", entity.def.index, move.dir, 1 }
      end
      ow.runner:run(script, {
        npc = npc,
        onDone = function()
          placeNpc(ow, move.name, move.x, move.y)
          done()
        end,
      })
    end
  end

  -- ----------------------------------------------------------- the current

  -- CheckForceSurfDirection (pureRGB scripts/CinnabarVolcano.asm): standing on
  -- flowing lava while surfing queues one simulated joypad press, so the stream
  -- carries the player a cell at a time and the crater floor becomes a matter
  -- of entering the right stream.  $24 flows down on every floor; the other
  -- three only answer below y = 53.
  --
  -- The original re-queues the press every frame, which means a stream running
  -- into a wall pins the player there for good.  Here the push only happens on
  -- a completed step and only when the target cell is actually free, so a
  -- blocked stream simply hands control back.
  local currents = questData.currents or {}
  local currentDirs = {}
  for tileId, dir in pairs(currents.tiles or {}) do
    currentDirs[tonumber(tileId) or tileId] = dir
  end
  local CURRENT_FREE_TILE = currents.freeTile
  local CURRENT_FLOOR_Y = currents.floorY or 0
  local MAX_RIDE = 64

  local okCollision, Collision = pcall(require, "src.world.Collision")
  if not okCollision then Collision = nil end

  local STEP = {
    up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
  }

  -- Collision.canMove is the engine's own verdict (bounds, tile, surf rule,
  -- entities, ledge pairs) and the one to trust; the fallback repeats the parts
  -- of it that matter here rather than let a failed require silence the
  -- current.
  local function canDrift(ow, dir)
    local player = ow.player
    if Collision then
      return Collision.canMove(ow.map, ow.entities, player, dir) == true
    end
    local map, step = ow.map, STEP[dir]
    local nx, ny = player.cellX + step[1], player.cellY + step[2]
    if map.inBounds and not map:inBounds(nx, ny) then return false end
    local open = map.isWalkableCell and map:isWalkableCell(nx, ny)
    if not open then
      open = player.surfing and map.isWaterCell and map:isWaterCell(nx, ny)
    end
    if not open then return false end
    for _, entity in ipairs(ow.entities or {}) do
      if entity ~= player and not entity.passable
         and ((entity.cellX == nx and entity.cellY == ny)
              or (entity.targetX == nx and entity.targetY == ny)) then
        return false
      end
    end
    return true
  end

  local function currentDirAt(map, cellX, cellY)
    if not (map and map.cellTile) then return nil end
    local tileId = map:cellTile(cellX, cellY)
    if tileId == nil then return nil end
    if tileId ~= CURRENT_FREE_TILE and cellY < CURRENT_FLOOR_Y then return nil end
    return currentDirs[tileId]
  end

  local function lavaCurrent(game, ow, cellX, cellY)
    local player = ow and ow.player
    -- CheckForceSurfDirection opens with `cp SURFING`.  Riding is the only way
    -- onto a current tile (they are lava, and lava is not in Volcano_Coll), so
    -- this is the same test -- and the reason the suit does not need to appear
    -- in it: the suit is what the player wears on the rock, never on the flow.
    if not (player and player.surfing) then return false end
    if ow.runner and ow.runner:isRunning() then return false end
    local dir = currentDirAt(ow.map, cellX, cellY)
    if not dir then
      ow.lavaRide = nil
      return false
    end
    local ride = (ow.lavaRide or 0) + 1
    if ride > MAX_RIDE then
      ow.lavaRide = nil
      return false
    end
    if not canDrift(ow, dir) then
      ow.lavaRide = nil
      return false
    end
    ow.lavaRide = ride
    -- re-entering the landing pipeline keeps the ride going and still runs
    -- warps and encounters on every cell, the way runSpinnerMoves does
    ow:scriptMove(player, dir, 1, function() ow:onStepComplete() end)
    return true
  end

  -- ------------------------------------------------------------- the maps

  local volcanoTalk = {
    TEXT_CINNABAR_VOLCANO_PROSPECTOR = prospectorHandler,
    TEXT_CINNABAR_VOLCANO_SURFING_RHYDON = surfingRhydonHandler,
    TEXT_CINNABAR_VOLCANO_RUBY1 = rubyHandler("CINNABAR_VOLCANO_RUBY1"),
    TEXT_CINNABAR_VOLCANO_RUBY2 = rubyHandler("CINNABAR_VOLCANO_RUBY2"),
    TEXT_CINNABAR_VOLCANO_RUBY3 = rubyHandler("CINNABAR_VOLCANO_RUBY3"),
    TEXT_CINNABAR_VOLCANO_BOSS_MAGMAR = {
      { "show_text", "MAGMAR: Maaagmar!\fEs versperrt den\nKraterrand!" },
      { "static_battle", "MAGMAR", 50, "MOD_LV_BEAT_BOSS_MAGMAR" },
    },
  }
  for _, rock in ipairs(questData.rocks) do
    volcanoTalk[rock.text] = rockHandler(rock)
  end
  for _, move in ipairs(questData.npcMoves or {}) do
    volcanoTalk["TEXT_" .. move.name] = npcMoveHandler(move)
  end

  -- pureRGB moves Moltres out of Victory Road; the toggle is written straight
  -- to the save (WorldAPI:toggleObject would re-enter setMap from inside its
  -- own onEnter) and the live NPC is removed through the script runner.
  local function retireVictoryRoadMoltres(game, ow)
    local save = game.save
    save.objectToggles = save.objectToggles or {}
    local toggles = save.objectToggles[VICTORY_ROAD] or {}
    save.objectToggles[VICTORY_ROAD] = toggles
    if toggles[VICTORY_ROAD_MOLTRES] == false then return end
    toggles[VICTORY_ROAD_MOLTRES] = false
    save.flags[FLAG_MOLTRES_MOVED] = true
    if ow and ow.queueScript then
      ow:queueScript({ { "hide_object", VICTORY_ROAD, VICTORY_ROAD_MOLTRES } })
    end
  end

  -- CinnabarVolcano_Script runs CheckForceTalkToProspector before
  -- CheckForceSurfDirection, and the forced conversation swallows the step.
  local function volcanoStep(game, ow, cellX, cellY)
    if forceProspectorTalk(game, ow, cellX, cellY) then return true end
    if tryDrillHole(game, ow, cellX, cellY) then return true end
    return lavaCurrent(game, ow, cellX, cellY)
  end

  local maps = {
    [VOLCANO] = {
      onEnter = restoreVolcanoLayout,
      onStep = volcanoStep,
      talk = volcanoTalk,
    },
    -- CinnabarVolcanoWest_Script calls CheckForceSurfDirection too
    [VOLCANO_WEST] = {
      onEnter = function(game, ow)
        rememberWorld(game, ow)
        wearLavaSuit(game, ow, game.save.flags[SUIT_FLAG] and true or false)
      end,
      onStep = lavaCurrent,
      talk = {},
    },
    [VICTORY_ROAD] = {
      onEnter = retireVictoryRoadMoltres,
    },
  }

  return { texts = texts, textPointers = textPointers, maps = maps }
end
