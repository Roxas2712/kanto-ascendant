local root = os.getenv("KASC_SOURCE") or "."
local makeHall = assert(loadfile(root .. "/legacy_hall.lua"))()
package.preload["src.render.TextBox"] = function()
  return {new = function(_, text) return {text = text} end}
end
local count = 0
for _, lang in ipairs({"en", "de"}) do
  for _, ngplus in ipairs({true, false}) do
    for _, champion in ipairs({false, true}) do
      local hooks, screens, data = {}, {}, {}
      local achievements = {achievements = {}}
      local game = {save = {ngplus = ngplus, champion = champion}}
      game.stack = {push = function(_, menu) game.menu = menu end}
      local mod = {
        exports = {},
        save = {get = function(_, k) return data[k] end,
          set = function(_, k, v) data[k] = v end},
        hooks = {wrap = function(_, k, fn) hooks[k] = fn end},
        events = {on = function() end},
        content = {screens = {register = function(_, k, v) screens[k] = v end}},
        ui = {
          ListMenu = {new = function(_, title, rows, options)
            return {title = title, rows = rows, options = options}
          end},
          insertBefore = function(rows, _, item) table.insert(rows, 1, item) return rows end,
          push = function(g, screen) g.stack:push(screens[screen].new(g)) end,
        },
      }
      local hall = makeHall(mod, {
        ascendant = {state = function() return achievements end},
        ascendantData = {achievements = {{id = "earned", title = {en = "EARNED", de = "VERDIENT"}},
          {id = "locked", title = {en = "LOCKED", de = "GESPERRT"}}}},
        i18n = {text = function(en, de) return lang == "de" and de or en end},
        postgame = {hasHallOfFame = function(save) return save.champion end},
        legacyJourney = {isActive = function(save) return save.ngplus end},
      })
      local hook = hooks["ui.start_menu.items"]
      local rows = hook(function(_, items) return items end, game, {{label = "SAVE"}})
      assert((#rows == 2) == (ngplus or champion),
        "NG+ title menu must be available before Hall of Fame: " .. lang)
      assert(hook(function() return nil end, game, {}) == nil)
      if ngplus or champion then
        assert(rows[1].ascendantOrder == 80 and rows[1].ascendantMenu)
        rows[1].onSelect()
        assert(game.menu.rows[1].value == "titles")
        game.menu.options.onChoose(game.menu.rows[1])
        assert(game.menu.title == (lang == "de" and "TITEL WÄHLEN" or "SELECT TITLE"))
        assert(game.menu.rows[1].value == false, "empty NG+ titles remain accessible without granting titles")
        achievements.achievements.earned = true
        mod.ui.push(game, "AscendantTitles")
        local titleMenu = game.menu
        assert(#titleMenu.rows == 1 and titleMenu.rows[1].value == "earned")
        titleMenu.close = function() end
        titleMenu.options.onChoose(titleMenu.rows[1], titleMenu)
        assert(data.legacy_hall.selectedTitle == "earned")
        assert(achievements.selectedTitle == "earned")
        assert(hall.currentTitle() == "earned")
        assert(not hall.selectTitle("locked"), "menu access must not unlock titles")
      end
      count = count + 1
    end
  end
end
print("title-menu NG+ regression: " .. count .. " scenarios passed")
