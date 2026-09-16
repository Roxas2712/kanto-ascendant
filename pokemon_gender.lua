-- Generation-II Pokémon gender.
--
-- This is the only owner of Pokémon gender in Kanto Ascendant.  Gender is
-- derived from a species' female-rate class and the existing Attack DV; it never
-- rewrites legacy DVs or gender. New backend gifts use a separate saved
-- gender binding, because the Gen-II shiny DV restriction must not make
-- later-generation female-only evolutions impossible for shiny gifts.

return function(mod, opts)
  opts = opts or {}
  local breedingData = opts.breedingData or {}
  local backendGender = opts.backendGender
  if backendGender then
    assert(backendGender.schema == 'kasc.wave1-backend-gender/v1')
  end
  local voxelRenderer = opts.voxelRenderer
  local rendererOwnsCompleteHud
  local M = {
    MALE = "MALE", FEMALE = "FEMALE", GENDERLESS = "GENDERLESS",
  }
  -- These pre-existing native Hoenn/Sinnoh owners are also gift targets.
  -- Only new receipt-backed gifts get independent gender, just like the
  -- backend owners. Otherwise every shiny Kirlia would be female forever.
  -- Explicit identities/ancestry avoid treating private form slots as bases.
  local dawnGiftFamilies = {
    RALTS={dex=280,origins={[280]=true}},
    KIRLIA={dex=281,origins={[280]=true,[281]=true}},
    GARDEVOIR={dex=282,origins={[280]=true,[281]=true,[282]=true}},
    GALLADE={dex=475,origins={[280]=true,[281]=true,[475]=true}},
    SNORUNT={dex=361,origins={[361]=true}},
    GLALIE={dex=362,origins={[361]=true,[362]=true}},
    FROSLASS={dex=478,origins={[361]=true,[478]=true}},
  }
  -- Native Gen3 gift families with reviewed female artwork. Ancestors retain
  -- the original receipt gender through evolution; unbound saves still use DVs.
  local gen3GiftFamilies = {
    TORCHIC={dex=255,origins={[255]=true}},
    COMBUSKEN={dex=256,origins={[255]=true,[256]=true}},
    BLAZIKEN={dex=257,origins={[255]=true,[256]=true,[257]=true}},
    WURMPLE={dex=265,origins={[265]=true}},
    SILCOON={dex=266,origins={[265]=true,[266]=true}},
    BEAUTIFLY={dex=267,origins={[265]=true,[266]=true,[267]=true}},
    CASCOON={dex=268,origins={[265]=true,[268]=true}},
    DUSTOX={dex=269,origins={[265]=true,[268]=true,[269]=true}},
    LOTAD={dex=270,origins={[270]=true}},
    LOMBRE={dex=271,origins={[270]=true,[271]=true}},
    LUDICOLO={dex=272,origins={[270]=true,[271]=true,[272]=true}},
    SEEDOT={dex=273,origins={[273]=true}},
    NUZLEAF={dex=274,origins={[273]=true,[274]=true}},
    SHIFTRY={dex=275,origins={[273]=true,[274]=true,[275]=true}},
    MEDITITE={dex=307,origins={[307]=true}},
    MEDICHAM={dex=308,origins={[307]=true,[308]=true}},
    ROSELIA={dex=315,origins={[315]=true}},
    GULPIN={dex=316,origins={[316]=true}},
    SWALOT={dex=317,origins={[316]=true,[317]=true}},
    NUMEL={dex=322,origins={[322]=true}},
    CAMERUPT={dex=323,origins={[322]=true,[323]=true}},
    CACNEA={dex=331,origins={[331]=true}},
    CACTURNE={dex=332,origins={[331]=true,[332]=true}},
    FEEBAS={dex=349,origins={[349]=true}},
    MILOTIC={dex=350,origins={[349]=true,[350]=true}},
    RELICANTH={dex=369,origins={[369]=true}},
  }
  for species,family in pairs(gen3GiftFamilies)do
    family.preserveUnbound=true;dawnGiftFamilies[species]=family
  end
  local function nativeGiftFamily(mon,def)
    local family=mon and dawnGiftFamilies[mon.species]
    if family and def and not def.backendOwner
        and (def.dex==family.dex or family.preserveUnbound and def.dex==3000+family.dex)
        and def.sourceDex==family.dex and not def.form and not def.formId
        and not def.isMega and not def.isGigantamax then return family end
  end
  -- Reviewed mixed-sex family bodies retain their real species ratio and
  -- new-gift gender binding. Private form IDs must never index breedingData.
  local function reviewedFamilyForm(mon,def)
    local pid=tonumber((mon and mon.species or ''):match('^KA_GIFT_FORM_(%d+)$'))
    local row=({[10027]={710,'KA_GIFT_NAT_710',4},[10028]={710,'KA_GIFT_NAT_710',4},
      [10029]={710,'KA_GIFT_NAT_710',4},[10030]={711,'KA_GIFT_NAT_711',4},
      [10031]={711,'KA_GIFT_NAT_711',4},[10032]={711,'KA_GIFT_NAT_711',4},
      [10126]={745,'KA_GIFT_NAT_745',4},[10151]={744,'KA_GIFT_NAT_744',4},
      [10152]={745,'KA_GIFT_NAT_745',4},[10161]={52,'MEOWTH',4},[10168]={122,'MR_MIME',4},
      [10173]={222,'CORSOLA',6},[10174]={263,'ZIGZAGOON',4},[10175]={264,'LINOONE',4},
      [10176]={554,'KA_GIFT_NAT_554',4},[10177]={555,'KA_GIFT_NAT_555',4},
      [10191]={892,'KA_GIFT_NAT_892',1},
      [10166]={83,'FARFETCHD',4},[10234]={211,'QWILFISH',4},[10235]={215,'SNEASEL',4},
      [10238]={570,'KA_GIFT_NAT_570',1},[10239]={571,'KA_GIFT_NAT_571',1},
      [10253]={194,'WOOPER',4}})[pid]
    if row and def and def.backendOwner=='kasc.backend.gift-species/v1'
        and def.backendKey=='form:'..pid and def.sourceDex==row[1]
        and def.formId=='BACKEND_'..pid and def.baseSpecies==row[2]
        and not def.isMega and not def.isGigantamax then return row end
  end

  local function dataFor(gameOrData)
    if type(gameOrData) ~= "table" then return nil end
    return gameOrData.data or gameOrData
  end

  local function attackDv(mon)
    local value = mon and mon.dvs and tonumber(mon.dvs.attack) or 0
    return math.max(0, math.min(15, math.floor(value)))
  end

  -- `gender` is the canonical Gen-II female-rate class used by the existing
  -- 251-entry breeding table: 0, 1, 2, 4, 6, 8 or -1 (genderless).
  function M.getGenderRatio(mon, gameOrData)
    local data = dataFor(gameOrData)
    local def = data and data.pokemon and mon and data.pokemon[mon.species]
    local family=nativeGiftFamily(mon,def)
    local reviewed=reviewedFamilyForm(mon,def)
    if reviewed and backendGender then
      local ratio=backendGender.ratios[reviewed[1]]
        or (breedingData[reviewed[1]] and tonumber(breedingData[reviewed[1]].gender))
      return ratio==reviewed[3] and ratio or -1
    end
    if family and backendGender and (not family.preserveUnbound or mon._kascGender67~=nil) then
      local ratio=backendGender.ratios[family.dex]
      if type(ratio)=='number' and ratio==math.floor(ratio) and ratio>=-1 and ratio<=8 then
        return ratio
      end
      return -1
    end
    -- These four species have distinct permanent male/female Pokemon rows.
    -- Species-level 50/50 rates must not label a male body as female, or
    -- mistake a female form's private ABI address for a genderless species.
    if backendGender and def and def.backendOwner=='kasc.backend.gift-species/v1'
        and not def.isMega and not def.isGigantamax then
      for _,pair in ipairs({{678,10025},{876,10186},{902,10248},{916,10254}})do
        if def.sourceDex==pair[1] then
          if mon.species=='KA_GIFT_NAT_'..pair[1] and def.backendKey=='dex:'..pair[1]
              and not def.form and not def.formId then return 0 end
          if mon.species=='KA_GIFT_FORM_'..pair[2] and def.backendKey=='form:'..pair[2]
              and def.formId=='BACKEND_'..pair[2] and def.baseSpecies=='KA_GIFT_NAT_'..pair[1] then return 8 end
        end
      end
    end
    -- Wormadam's reviewed permanent cloaks share the base species' female-
    -- only ratio. These are Pokemon IDs 10004/10005, NOT Burmy's cosmetic
    -- source-form IDs 10034/10035. Match every identity field before using
    -- the base ratio; do not open the remaining private form catalogue.
    if backendGender and def and def.backendOwner == 'kasc.backend.gift-species/v1'
        and def.sourceDex == 413 and not def.isMega and not def.isGigantamax
        and def.baseSpecies == 'KA_GIFT_NAT_413'
        and ((mon.species == 'KA_GIFT_FORM_10004' and def.backendKey == 'form:10004'
          and def.formId == 'BACKEND_10004')
        or (mon.species == 'KA_GIFT_FORM_10005' and def.backendKey == 'form:10005'
          and def.formId == 'BACKEND_10005')) then
      return backendGender.ratios[413] == 8 and 8 or -1
    end
    -- Backend ABI slots (20000+Dex) are not National IDs. Only explicitly
    -- owned base identities may consume this source; authored private slots,
    -- Gorochu and forms keep their existing gender owner unchanged.
    if backendGender and def and def.backendOwner == 'kasc.backend.gift-species/v1'
        and not def.form and not def.formId and not def.isMega and not def.isGigantamax
        and type(def.sourceDex) == 'number' and def.sourceDex > 251
        and def.sourceDex <= 1025 and def.sourceDex == math.floor(def.sourceDex)
        and def.backendKey == 'dex:' .. def.sourceDex then
      local ratio = backendGender.ratios[def.sourceDex]
      if type(ratio) == 'number' and ratio == math.floor(ratio)
          and ratio >= -1 and ratio <= 8 then return ratio end
      return -1
    end
    local row = def and breedingData[def.dex]
    local ratio = row and tonumber(row.gender)
    if ratio == nil then return -1 end
    return math.max(-1, math.min(8, math.floor(ratio)))
  end

  -- Equivalent to pokecrystal's GetGender comparison.  In the original
  -- byte comparison, the ratio boundaries end in $f, so this is exactly the
  -- same as comparing Attack DV against twice the female-rate class.
  function M.getMonGender(mon, gameOrData)
    local illusion=mod.exports and mod.exports.pokemonIllusion67
    if illusion and illusion.renderMon then mon=illusion.renderMon(mon)end
    local ratio = M.getGenderRatio(mon, gameOrData)
    if ratio < 0 then return M.GENDERLESS end
    if ratio == 0 then return M.MALE end
    if ratio >= 8 then return M.FEMALE end
    local data=dataFor(gameOrData)
    local def=data and data.pokemon and mon and data.pokemon[mon.species]
    local family=nativeGiftFamily(mon,def)
    if ((def and def.backendOwner=='kasc.backend.gift-species/v1'
        and not def.form and not def.formId and not def.isMega and not def.isGigantamax
        and def.backendKey=='dex:'..tostring(def.sourceDex)) or family or reviewedFamilyForm(mon,def))
        and mon._kascGender67~=nil then
      local saved=mon._kascGender67
      local originAllowed=not family
      if family then for dex in pairs(family.origins)do
        if mon.backendKey=='dex:'..dex then originAllowed=true end
      end end
      if type(saved)=='table' and saved.schema=='kasc.backend-gift-gender/v1'
          and saved.originKey==mon.backendKey and originAllowed
          and (saved.gender==M.MALE or saved.gender==M.FEMALE) then return saved.gender end
      return M.GENDERLESS
    end
    return attackDv(mon) < ratio * 2 and M.FEMALE or M.MALE
  end

  -- Called only while constructing a new, receipt-backed gift, before it is
  -- stored. Replay/old-save paths never call this and never reroll gender.
  function M.bindGift(game,mon,receipt)
    local def=game and game.data and game.data.pokemon and mon and game.data.pokemon[mon.species]
    local family=nativeGiftFamily(mon,def)
    local native=family and mon.backendKey=='dex:'..family.dex
    local reviewed=reviewedFamilyForm(mon,def) and mon.backendKey==def.backendKey
    if not (backendGender and def and (native or reviewed or (def.backendOwner=='kasc.backend.gift-species/v1'
        and not def.form and not def.formId and not def.isMega and not def.isGigantamax
        and type(def.sourceDex)=='number' and backendGender.ratios[def.sourceDex]~=nil
        and def.backendKey=='dex:'..def.sourceDex and mon.backendKey==def.backendKey))) then return true end
    if mon._kascGender67~=nil then return false,'gender_already_bound' end
    if type(opts.digest)~='function' or type(receipt)~='table'
        or type(receipt.digest)~='string' or #receipt.digest~=64
        or not receipt.digest:match('^[0-9a-f]+$') then return false,'gender_receipt_missing' end
    local ratio=native and family.preserveUnbound and backendGender.ratios[family.dex]
      or M.getGenderRatio(mon,game)
    if ratio==-1 then return true end
    local seed=opts.digest('backend-gender:'..receipt.digest..':'
      ..tostring(game.save and game.save.player and game.save.player.id or 0))
    local roll=tonumber(seed:sub(1,8),16)%8
    mon._kascGender67={schema='kasc.backend-gift-gender/v1',originKey=mon.backendKey,
      gender=(ratio==8 or roll<ratio) and M.FEMALE or M.MALE}
    return true
  end

  M.get = M.getMonGender

  function M.symbol(mon, gameOrData)
    local gender = M.getMonGender(mon, gameOrData)
    if gender == M.MALE then return "♂" end
    if gender == M.FEMALE then return "♀" end
    return nil
  end

  -- Development-only diagnostic seam. It is exported for tests/console
  -- inspection and deliberately has no normal-gameplay menu entry.
  function M.inspect(mon, gameOrData)
    local data = dataFor(gameOrData)
    local def = data and data.pokemon and mon and data.pokemon[mon.species]
    return {
      species = mon and mon.species or nil,
      dex = def and def.dex or nil,
      attackDv = attackDv(mon),
      genderRatio = M.getGenderRatio(mon, gameOrData),
      gender = M.getMonGender(mon, gameOrData),
    }
  end

  local function isPokemonList(title)
    title = tostring(title or "")
    return title:find("WITHDRAW", 1, true)
      or title:find("DEPOSIT", 1, true)
      or title:find("RELEASE", 1, true)
      or title:find("ABHEBEN", 1, true)
      or title:find("ABLEGEN", 1, true)
      or title:find("FREILASSEN", 1, true)
  end

  local function monForList(game, list, item)
    if not (game and list and item) then return nil end
    local title = tostring(list.title or "")
    if title:find("PARTY", 1, true) or title:find("TEAM", 1, true) then
      return game.save and game.save.party and game.save.party[item.value]
    end
    local Boxes = require("src.pokemon.Boxes")
    local box = game.save and Boxes.active(game.save)
    return box and box[item.value]
  end

  local function presentationSymbol(mon, game, name)
    local symbol = M.symbol(mon, game)
    -- NIDORAN♀/NIDORAN♂ already carry the same glyph in their species name.
    -- Gen-II-style presentation must not turn that into a doubled marker.
    name = tostring(name or "")
    if symbol and name:sub(-#symbol) == symbol then return nil end
    return symbol
  end

  local function enemyHudVisible(battle, slide)
    local enemy = battle and battle.enemy
    return enemy and not battle.showEnemyTrainer and not battle.enemySendingOut
      and not (battle.growInScale and battle:growInScale(enemy))
      and slide == 0 and not battle.introBalls and not enemy.fainted
  end

  local function playerHudVisible(battle, slide)
    return battle and battle.player and not (battle.safari or battle.demo)
      and not battle.showPlayerBack and slide == 0
  end

  -- Crystal puts the symbols on the level/status row. Keep these coordinates
  -- available as a diagnostic seam and for renderer-backed acceptance tests.
  function M.drawBattleHUD(battle, slide)
    if rendererOwnsCompleteHud(battle) then return end
    local Font = require("src.render.Font")
    if enemyHudVisible(battle, slide) then
      local identity=mod.exports and mod.exports.pokemonBattleIdentity67
      local mon = identity and identity.presentationMon and identity.presentationMon(battle,battle.enemy)or battle.enemy.mon
      -- Unlike the inline Party/Summary suffix, Crystal's battle cell is a
      -- dedicated field. NIDORAN♀/♂ therefore still get their inherent sex
      -- here even though the species name already contains the same glyph.
      local symbol = M.symbol(mon, battle.game or battle)
      if symbol then Font.draw(symbol, 72, 8) end
    end
    if playerHudVisible(battle, slide) then
      local identity=mod.exports and mod.exports.pokemonBattleIdentity67
      local mon = identity and identity.presentationMon and identity.presentationMon(battle,battle.player)or battle.player.mon
      local symbol = M.symbol(mon, battle.game or battle)
      -- x=136 is part of the player's three-digit level/status field.  A
      -- permanent, separate cell at x=104 remains clear for Lv.1 through
      -- Lv.100 and for every three-letter status label in both renderers.
      if symbol then Font.draw(symbol, 104, 64) end
    end
  end

  local function installBattleLayout()
    local BattleState = require("src.battle.BattleState")
    if BattleState.__ascendantPokemonGender then return end
    BattleState.__ascendantPokemonGender = true
    -- The renderer itself needs no coordinate interception now: the gender
    -- glyph has a genuinely independent cell (see drawBattleHUD above).
  end

  local function installPresentation()
    local Font = require("src.render.Font")
    local PartyMenu = require("src.ui.PartyMenu")
    if not PartyMenu.__ascendantPokemonGender then
      PartyMenu.__ascendantPokemonGender = true
      local originalDraw = PartyMenu.draw
      PartyMenu.draw = function(self)
        originalDraw(self)
        local party = self.party or (self.game.save and self.game.save.party) or {}
        for i, mon in ipairs(party) do
          local def = self.game.data.pokemon[mon.species] or {}
          local name = mon.nickname or def.name or mon.species
          local symbol = presentationSymbol(mon, self.game, name)
          local x = 24 + Font.width(name)
          -- The authentic Gen-I row reserves its remaining space for level
          -- and status. Never overwrite those fields for a 10-glyph nickname.
          if symbol and x + Font.width(symbol) <= 104 then
            Font.draw(symbol, x, PartyMenu.entryY(i))
          end
        end
      end
    end

    local SummaryMenu = require("src.ui.SummaryMenu")
    if not SummaryMenu.__ascendantPokemonGender then
      SummaryMenu.__ascendantPokemonGender = true
      local originalDraw = SummaryMenu.draw
      SummaryMenu.draw = function(self)
        originalDraw(self)
        local def = self.game.data.pokemon[self.mon.species] or {}
        local name = self.mon.nickname or def.name or self.mon.species
        local symbol = presentationSymbol(self.mon, self.game, name)
        local x = 72 + Font.width(name)
        if symbol and x + Font.width(symbol) <= 160 then Font.draw(symbol, x, 8) end
      end
    end

    local ListMenu = require("src.ui.ListMenu")
    if not ListMenu.__ascendantPokemonGender then
      ListMenu.__ascendantPokemonGender = true
      local originalNew = ListMenu.new
      ListMenu.new = function(game, title, items, listOpts)
        local list = originalNew(game, title, items, listOpts)
        if not isPokemonList(title) then return list end
        if list.__ascendantBoxGrid then
          -- modern_storage_ui owns a dedicated gender row.  A late overlay
          -- here used to write through the level digits.
          return list
        end
        for _, item in ipairs(list.items or {}) do
          local mon = monForList(game, list, item)
          local def = mon and game.data.pokemon[mon.species] or {}
          local name = mon and (mon.nickname or def.name or mon.species)
          local symbol = presentationSymbol(mon, game, name)
          if symbol then item.label = tostring(item.label or "") .. symbol end
        end
        return list
      end
    end
  end

  -- Main registers its storage/UI integrations first. Install after that
  -- shared lifecycle point so the optional modern PC keeps its own renderer.
  local activeHudHost
  local function refreshHudHost(game)
    activeHudHost = voxelRenderer and type(voxelRenderer.module) == "function"
      and voxelRenderer.module(game, "OverworldBattle") or nil
  end
  mod.events:once("mods.loaded", function(ev)
    installPresentation()
    installBattleLayout()
    refreshHudHost(ev and ev.game)
  end)
  mod.events:on("game.ready", function(ev)
    refreshHudHost(ev and ev.game)
  end)

  -- A complete renderer-owned replacement such as VASC's ORAS HUD consumes
  -- KASC's public gender data itself. Observe only the renderer's public
  -- frame-local receipt; never wrap or draw into its private HUD texture.
  rendererOwnsCompleteHud = function(battle)
    local qualityOfLife = type(mod.exports) == "table"
      and mod.exports.qualityOfLife or nil
    local battleOverlays = type(qualityOfLife) == "table"
      and qualityOfLife.battle or nil
    if type(battleOverlays) == "table"
        and type(battleOverlays.externalHudOwned) == "function" then
      local ok, owned = pcall(
        battleOverlays.externalHudOwned, battleOverlays, battle)
      -- The shared service is authoritative when installed. Errors and
      -- negative receipts fail open to KASC's native 2D presentation.
      return ok and owned == true
    end
    if not activeHudHost and voxelRenderer
        and type(voxelRenderer.module) == "function" then
      local found, host = pcall(voxelRenderer.module,
        battle and battle.game, "OverworldBattle")
      if found then activeHudHost = host end
    end
    if not (activeHudHost
        and type(activeHudHost.hudSnapReceipt) == "function") then
      return false
    end
    local ok, receipt = pcall(activeHudHost.hudSnapReceipt, battle)
    local shot = type(battle) == "table"
      and rawget(battle, "voxelAscendantShot") or nil
    if type(activeHudHost.shot) == "function" then
      local okShot, current = pcall(activeHudHost.shot, battle)
      if not okShot or current ~= shot then return false end
    end
    return ok and type(shot) == "table" and type(receipt) == "table"
      and receipt.schema == "voxel-ascendant/hud-snap/v1"
      and receipt.shot == shot and receipt.snapped == true
      and (receipt.owner == "voxel_ascendant.oras"
        or receipt.owner == "kanto_ascendant.oras")
  end

  mod.hooks:wrap("battle.overlay", function(nextDraw, battle)
    local result = nextDraw(battle)
    -- Suppress the native glyph only after the renderer proves that a complete
    -- replacement HUD owns this exact frame. Ordinary 2D and fail-open frames
    -- retain KASC's native Crystal-style cells.
    if battle and not battle.blankForAskName
        and not rendererOwnsCompleteHud(battle) then
      love.graphics.setColor(0, 0, 0, 1)
      M.drawBattleHUD(battle, (battle.introSlide or 0) * 4)
      love.graphics.setColor(1, 1, 1, 1)
    end
    return result
  end, 70)
  return M
end
