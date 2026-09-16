-- KASC-67-GENERATION-BATTLE-GATE
--
-- Keeps save-resident Pokémon intact while preventing a species outside the
-- active generation profile from becoming a player battler.  This adapter is
-- deliberately confined to the battle constructor and battle Party picker;
-- storage, summaries, healing and profile upgrades retain the real Pokémon.

return function(mod, opts)
  opts = opts or {}
  local rules = assert(opts.generationRules, "generation rules missing")
  local G = { game = nil, installed = false }

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  local function eligible(game, mon)
    return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0
      and rules.monAvailable(game, mon) == true
  end

  local function firstEligible(game)
    for index, mon in ipairs(game and game.save and game.save.party or {}) do
      if eligible(game, mon) then return mon, index end
    end
  end

  local function blockText()
    return tr(
      "No POKéMON in the party\nfits the active generation.\f"
        .. "Change the generation\nsetting or your party.",
      "Kein POKéMON im Team\npasst zur aktiven Generation.\f"
        .. "Ändere die Generation\noder dein Team.")
  end

  local function pickName(mon, game)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon and mon.species]
    return mon and (mon.nickname or def and def.name or mon.species)
      or tr("This POKéMON", "Dieses POKéMON")
  end

  local function pickText(mon, game)
    local name = pickName(mon, game)
    return tr(
      tostring(name) .. " cannot fight\nunder this generation.",
      tostring(name) .. " kann in dieser\nGeneration nicht kämpfen.")
  end

  local function pickInlineText(mon, game)
    return tr(
      "Unavailable in this battle generation.",
      "In dieser Kampf-Generation nicht verfügbar.")
  end

  local function ownsFullscreenPresentation(menu)
    return type(menu) == "table" and (
      menu.__vascOrasPartyDecorated == true
      or menu.__kantoAscendantStyle == "oras-fullscreen-glass"
      or menu.__kascFullscreenOras == true)
  end

  function G.install(game, deps)
    G.game = game or G.game
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    local PartyMenu = deps.partyMenu or require("src.ui.PartyMenu")
    local TextBox = deps.textBox or require("src.render.TextBox")
    local Music = deps.music or require("src.core.Music")
    local Runtime = deps.runtime or require("src.mods.Runtime")

    -- Hot reloads update the active authority without stacking wrappers.
    BattleState._kascGenerationBattleGate67 = {
      rules = rules, firstEligible = firstEligible,
      equipmentCheckpoint = opts.equipmentCheckpoint,
      blockText = blockText, TextBox = TextBox,
      Music = Music, Runtime = Runtime,
    }
    if not BattleState._kascGenerationBattleGate67Wrapped then
      local originalWild = BattleState.newWild
      local originalTrainer = BattleState.newTrainer
      local originalEnter = BattleState.enter

      local function projectLead(activeGame, battle)
        local gate = BattleState._kascGenerationBattleGate67
        local current = battle and battle.player and battle.player.mon
        if not current or gate.rules.monAvailable(activeGame, current) == true then
          return battle
        end
        local mon, index = gate.firstEligible(activeGame)
        if mon then
          battle.player = BattleState.makeBattler(
            activeGame.data, mon, true, activeGame.save)
          battle.generationRulesLeadRedirected = {
            from = current.species, to = mon.species, partyIndex = index,
          }
        else
          battle.player = nil
          battle.dead = true
          battle.generationRulesBattleBlocked = true
        end
        return battle
      end

      BattleState.newWild = function(activeGame, ...)
        local gate = BattleState._kascGenerationBattleGate67
        if gate.equipmentCheckpoint then gate.equipmentCheckpoint(activeGame) end
        return projectLead(activeGame, originalWild(activeGame, ...))
      end
      BattleState.newTrainer = function(activeGame, ...)
        local gate = BattleState._kascGenerationBattleGate67
        if gate.equipmentCheckpoint then gate.equipmentCheckpoint(activeGame) end
        return projectLead(activeGame, originalTrainer(activeGame, ...))
      end
      BattleState.enter = function(self, ...)
        if not self.generationRulesBattleBlocked then
          return originalEnter(self, ...)
        end
        local gate = BattleState._kascGenerationBattleGate67
        self.result = "run"
        if self.game and self.game.stack and self.game.stack.pop then
          self.game.stack:pop()
        end
        if gate.Music and gate.Music.restoreMap then
          gate.Music.restoreMap(self.data)
        end
        if gate.Runtime and gate.Runtime.emit then
          gate.Runtime.emit("battle.ended", {
            battle = self, result = "run", skipped = true,
            reason = "generation_profile_party",
          })
        end
        local function done()
          if self.onFinish then self.onFinish("run") end
        end
        if self.game and self.game.stack and self.game.stack.push
            and gate.TextBox and gate.TextBox.new then
          self.game.stack:push(gate.TextBox.new(
            self.game, gate.blockText(), done))
        else
          done()
        end
      end
      BattleState._kascGenerationBattleGate67Wrapped = true
    end

    PartyMenu._kascGenerationBattleGate67 = {
      rules = rules, TextBox = TextBox, pickText = pickText,
      pickInlineText = pickInlineText,
    }
    if not PartyMenu._kascGenerationBattleGate67Wrapped then
      local originalNew = PartyMenu.new
      PartyMenu.new = function(activeGame, menuOpts)
        if type(menuOpts) ~= "table" or not menuOpts.battle
            or type(menuOpts.onSwitch) ~= "function" then
          return originalNew(activeGame, menuOpts)
        end
        local wrapped, original = {}, menuOpts.onSwitch
        local menu
        for key, value in pairs(menuOpts) do wrapped[key] = value end
        wrapped.onSwitch = function(mon, ...)
          local gate = PartyMenu._kascGenerationBattleGate67
          if gate.rules.monAvailable(activeGame, mon) == true then
            return original(mon, ...)
          end
          -- VASC/KASC already owns the complete fullscreen surface.  Keep the
          -- rejection inside that surface's footer instead of stacking the
          -- native Gen-I TextBox (the exact yellow/white overlay regression).
          if ownsFullscreenPresentation(menu) then
            menu.submenu, menu.subIndex = nil, nil
            menu.toast = {
              text = gate.pickInlineText(mon, activeGame),
              timer = 4,
              owner = "kasc.rules.battle-generation-profiles/v1",
            }
            return false, "generation_profile"
          end
          if activeGame and activeGame.stack and activeGame.stack.push
              and gate.TextBox and gate.TextBox.new then
            activeGame.stack:push(gate.TextBox.new(
              activeGame, gate.pickText(mon, activeGame)))
          end
          return false, "generation_profile"
        end
        menu = originalNew(activeGame, wrapped)
        return menu
      end
      PartyMenu._kascGenerationBattleGate67Wrapped = true
    end

    G.installed = true
    return true
  end

  G.eligible = eligible
  G.firstEligible = firstEligible
  return G
end
