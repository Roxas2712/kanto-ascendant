-- Generation-II Pokémon gender.
--
-- This is the only owner of Pokémon gender in Kanto Ascendant.  Gender is
-- derived from a species' Gen-II ratio and the existing Attack DV; it never
-- writes a random/persistent gender field to a Pokémon or a save.

return function(mod, opts)
  opts = opts or {}
  local breedingData = opts.breedingData or {}
  local voxelRenderer = opts.voxelRenderer
  local rendererBattleHud = opts.rendererBattleHud
    or mod.exports and mod.exports.rendererBattleHud
  local M = {
    MALE = "MALE", FEMALE = "FEMALE", GENDERLESS = "GENDERLESS",
  }

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
    local row = def and breedingData[def.dex]
    local ratio = row and tonumber(row.gender)
    if ratio == nil then return -1 end
    return math.max(-1, math.min(8, math.floor(ratio)))
  end

  -- Equivalent to pokecrystal's GetGender comparison.  In the original
  -- byte comparison, the ratio boundaries end in $f, so this is exactly the
  -- same as comparing Attack DV against twice the female-rate class.
  function M.getMonGender(mon, gameOrData)
    local ratio = M.getGenderRatio(mon, gameOrData)
    if ratio < 0 then return M.GENDERLESS end
    if ratio == 0 then return M.MALE end
    if ratio >= 8 then return M.FEMALE end
    return attackDv(mon) < ratio * 2 and M.FEMALE or M.MALE
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
    local Font = require("src.render.Font")
    if enemyHudVisible(battle, slide) then
      local mon = battle.enemy.mon
      -- Unlike the inline Party/Summary suffix, Crystal's battle cell is a
      -- dedicated field. NIDORAN♀/♂ therefore still get their inherent sex
      -- here even though the species name already contains the same glyph.
      local symbol = M.symbol(mon, battle.game or battle)
      if symbol then Font.draw(symbol, 72, 8) end
    end
    if playerHudVisible(battle, slide) then
      local mon = battle.player.mon
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

  -- Reviewed Voxel renderers render the two classic HUD bands into an
  -- off-screen texture and then snap those bands to the window edges. A late
  -- battle.overlay glyph remains in the old GB-frame position, which is why
  -- the foe's symbol appeared alone near the screen centre. Decorate the HUD
  -- texture itself so each symbol travels with its own name/level panel.
  local function installRendererBattleHUD(game)
    local overworldBattle = voxelRenderer
      and voxelRenderer.module(game, "OverworldBattle")
    if type(overworldBattle) ~= "table" then return false end
    if overworldBattle.__ascendantPokemonGender then return true end
    local originalHudTexture = overworldBattle.hudTexture
    if type(originalHudTexture) ~= "function" then return false end
    overworldBattle.hudTexture = function(
        battle, slide, dark, inverted, colorShadow, ...)
      -- Battle Art 1.9.0 uses all five named arguments for COLOR/INVERTED and
      -- shadow presentation. Forward them byte-for-byte, plus any future tail.
      local layer = originalHudTexture(
        battle, slide, dark, inverted, colorShadow, ...)
      if not layer then return layer end
      local g = love.graphics
      local previous = g.getCanvas()
      local blend, alpha = g.getBlendMode()
      local r, green, b, a = g.getColor()
      local drawn, err = pcall(function()
        g.setCanvas(layer)
        g.setBlendMode("alpha")
        g.setColor(0, 0, 0, 1)
        M.drawBattleHUD(battle, slide)
      end)
      if previous then g.setCanvas(previous) else g.setCanvas() end
      g.setBlendMode(blend or "alpha", alpha)
      g.setColor(r or 1, green or 1, b or 1, a or 1)
      if not drawn then error(err, 0) end
      return layer
    end
    overworldBattle.__ascendantPokemonGender = true
    return true
  end

  -- Main registers its storage/UI integrations first. Install after that
  -- shared lifecycle point so the optional modern PC keeps its own renderer.
  mod.events:once("mods.loaded", function(ev)
    installPresentation()
    installBattleLayout()
    installRendererBattleHUD(ev and ev.game)
  end)
  mod.events:on("game.ready", function(ev)
    installRendererBattleHUD(ev and ev.game)
  end)

  local function rendererHudSnapped(battle)
    if not (rendererBattleHud
        and type(rendererBattleHud.context) == "function") then
      return false
    end
    local ok, context = pcall(rendererBattleHud.context, battle)
    return ok and type(context) == "table"
      and context.schema == rendererBattleHud.contextSchema
  end

  mod.hooks:wrap("battle.overlay", function(nextDraw, battle)
    local result = nextDraw(battle)
    -- Suppress the in-frame glyph only after the bridge validates a successful
    -- snap receipt for this exact shot. Battle Art intentionally keeps
    -- dramaticShapeShot on iOS and on snap failure; those fallback frames need
    -- the native gender overlay.
    if battle and not battle.blankForAskName
        and not rendererHudSnapped(battle) then
      love.graphics.setColor(0, 0, 0, 1)
      M.drawBattleHUD(battle, (battle.introSlide or 0) * 4)
      love.graphics.setColor(1, 1, 1, 1)
    end
    return result
  end, 70)
  return M
end
