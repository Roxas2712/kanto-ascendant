-- Engine-0.1.86 title regression without starting the desktop app.
--
-- 0.1.86 resolves the generated title logo through every loaded override.
-- An edition-inactive deutsch-gelb can therefore supply its full Yellow logo
-- to Red/Blue, whose separate ribbon is still correct.  Exercise the exact
-- resolver shape, the six edition/language cells, an already-created screen,
-- direct install-over-install and the old boolean receipt.  `debug` remains
-- absent for the complete product call, matching src/mods/Sandbox.lua.

local MOD_DIR = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local savedDebug, savedLove = debug, love
local savedLoaded = {}
local MODULES = {
  "src.ui.TitleState", "src.render.Assets", "src.render.Font",
  "src.core.GameVersion", "src.core.Logger",
}
for _, name in ipairs(MODULES) do savedLoaded[name] = package.loaded[name] end

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local CYCLE = {
  "CHARMANDER", "SQUIRTLE", "BULBASAUR", "WEEDLE", "NIDORAN_M",
  "SCYTHER", "PIKACHU", "CLEFAIRY", "RHYDON", "ABRA", "GASTLY",
  "DITTO", "PIDGEOTTO", "ONIX", "PONYTA", "MAGIKARP",
}

local function image(path, width, height)
  local out = { path = path, width = width or 56, height = height or 56 }
  function out:getDimensions() return self.width, self.height end
  return out
end

local function loadFactory()
  local chunk = assert(loadfile(MOD_DIR .. "/title_intro.lua"))
  local factory = assert(chunk())
  return factory
end

local function context(edition, language, resolverMode)
  local drawCalls = {}
  local assets = {}
  local foreign = "mods/deutsch-gelb/overrides/title/pokemon_logo.png"
  function assets.resolve(path)
    if resolverMode == "near" and path == "assets/generated/title/pokemon_logo.png" then
      return "mods/not-deutsch-gelb/overrides/title/pokemon_logo.png"
    end
    if language == "de" and edition ~= "yellow"
        and path == "assets/generated/title/pokemon_logo.png" then
      return foreign
    end
    return path
  end

  love = {
    graphics = {
      newImage = function(source)
        if type(source) == "table" then return image("image-data") end
        local width, height = 56, 56
        if tostring(source):find("pokemon_logo", 1, true) then
          width, height = 128, 56
        elseif tostring(source):find("version", 1, true) then
          width, height = 80, 8
        elseif tostring(source):find("player", 1, true) then
          width, height = 40, 56
        end
        return image(source, width, height)
      end,
      draw = function(pic)
        drawCalls[#drawCalls + 1] = pic
      end,
      setColor = function() end,
    },
    image = {
      newImageData = function(path)
        return { path = path, mapPixel = function() end }
      end,
    },
  }

  local font = {
    width = function(text) return #tostring(text or "") * 8 end,
    draw = function() end,
  }
  local gameVersion = {
    get = function() return edition end,
  }
  local titleState = {}
  titleState.__index = titleState

  local function path(entry)
    return type(entry) == "table" and entry.path or entry
  end
  function titleState.new(game)
    local title = game.data.field.title
    local self = setmetatable({
      game = game,
      title = title,
      cycleSpecies = title.cycleSpecies,
      cycleIndex = 1,
      timer = 0,
      phase = "loop",
      scrollPhase = "hold",
      logo = love.graphics.newImage(assets.resolve(path(title.logo))),
      version = title.versionRibbon
        and love.graphics.newImage(path(title.versionRibbon)) or nil,
      versionFull = title.versionRibbon ~= nil,
      player = love.graphics.newImage("assets/generated/title/player.png"),
      yellow = edition == "yellow",
      yellowLayout = edition == "yellow",
      yellowPikachu = edition == "yellow" and image("native-yellow-pikachu") or nil,
    }, titleState)
    return self
  end
  function titleState:update()
    self.timer = self.timer + 1
    if self.timer >= 240 then
      self.timer = 0
      self.cycleIndex = self.cycleIndex % #self.cycleSpecies + 1
    end
  end
  function titleState:currentSprite()
    return image("crystal:" .. self.cycleSpecies[self.cycleIndex]), true
  end
  function titleState:sgbPalettes()
    return { { colors = { { 1 }, { 2 }, { 3 }, { 4 } } } }
  end
  function titleState:draw()
    if self.failDraw then error("injected native title failure") end
    love.graphics.draw(self.logo)
    if self.yellowLayout then
      love.graphics.draw(self.yellowPikachu)
      return
    end
    -- 0.1.86 owns the continuous ribbon, then the older German wrapper
    -- redraws it unless Ascendant temporarily suppresses that compatibility
    -- bit.  The final frame must contain exactly one copy.
    if self.version then love.graphics.draw(self.version) end
    local mon = self:currentSprite()
    if mon then love.graphics.draw(mon) end
    if self.player then love.graphics.draw(self.player) end
    if self.title.germanFullVersionRibbon and self.version then
      love.graphics.draw(self.version)
    end
  end

  for _, name in ipairs(MODULES) do package.loaded[name] = nil end
  package.loaded["src.ui.TitleState"] = titleState
  package.loaded["src.render.Assets"] = assets
  package.loaded["src.render.Font"] = font
  package.loaded["src.core.GameVersion"] = gameVersion
  package.loaded["src.core.Logger"] = { warn = function() end }

  local logoPath = edition == "yellow" and language == "de"
      and foreign or "assets/generated/title/pokemon_logo.png"
  local title = {
    logo = { path = logoPath, width = 128, height = 56 },
    versionRibbon = edition ~= "yellow"
      and ("mods/deutsch/overrides/title/" .. edition .. "_version.png")
      or nil,
    germanFullVersionRibbon = language == "de" and edition ~= "yellow",
    copyrightText = "KANTO ASCENDANT",
    cycleSpecies = CYCLE,
  }
  local game = { data = { field = { title = title } } }
  local characters = {
    definition = function(id)
      return { visuals = { front = { path = "assets/" .. id:lower() .. ".png" } } }
    end,
  }
  local mod = { path = "mods/kanto_ascendant" }
  return {
    TitleState = titleState,
    Assets = assets,
    game = game,
    title = title,
    mod = mod,
    characters = characters,
    drawCalls = drawCalls,
    foreign = foreign,
    rawLogo = "assets/generated/title/pokemon_logo.png",
  }
end

local function countDraws(draws, target)
  local count = 0
  for _, value in ipairs(draws) do if value == target then count = count + 1 end end
  return count
end

local function matrixCell(edition, language)
  local c = context(edition, language)
  local factory = loadFactory()
  local product
  local ok, why = pcall(function()
    product = factory(c.mod, c.characters)
  end)
  check(ok, edition .. "/" .. language .. " sandbox install failed: "
    .. tostring(why))
  local screen = c.TitleState.new(c.game)
  if edition == "yellow" then
    eq(screen.logo.path,
      language == "de" and c.foreign or c.rawLogo,
      "Yellow logo changed")
    check(screen.kaTitleLogoRecovered ~= true,
      "Yellow was marked as foreign-logo recovery")
    check(screen.kaTitleTrainers == nil,
      "Yellow entered the Red/Blue trainer cycle")
  else
    eq(screen.logo.path, c.rawLogo,
      edition .. "/" .. language .. " did not keep its neutral logo")
    eq(screen.kaTitleLogoRecovered == true, language == "de",
      edition .. "/" .. language .. " recovery receipt mismatch")
    eq(#screen.cycleSpecies, 16, "native title list length changed")
    for index, species in ipairs(CYCLE) do
      eq(screen.cycleSpecies[index], species,
        edition .. " native cycle slot " .. index .. " changed")
    end
    eq(screen.kaTitleTrainerId, "GREEN", "first trainer is not Green")
    eq(screen.kaTitleSpecies, "CHARMANDER", "first species changed")
  end
  screen:draw()
  eq(countDraws(c.drawCalls, screen.version), edition == "yellow" and 0 or 1,
    edition .. "/" .. language .. " edition ribbon draw count")
  if edition ~= "yellow" then
    local prior = screen.kaTitlePairId
    screen.timer = 239
    screen:update(1 / 60)
    check(screen.kaTitlePairId ~= prior, "natural species edge did not rotate")
    eq(screen.kaTitleTrainerId, "BLUE", "natural edge skipped Blue")
    eq(screen.kaTitleSpecies, "SQUIRTLE", "natural edge species mismatch")
    local mon = screen:currentSprite()
    eq(mon.path, "crystal:SQUIRTLE",
      "edition ribbon replaced the Crystal title species")
  end
  return c, product, screen
end

local function run()
  debug = nil
  for _, edition in ipairs({ "red", "blue", "yellow" }) do
    for _, language in ipairs({ "en", "de" }) do
      matrixCell(edition, language)
    end
  end

  -- Existing screen: 0.1.86 created it with deutsch-gelb before UPDATE6 was
  -- imported.  The first post-import draw repairs that same object.
  do
    local c = context("red", "de")
    local existing = c.TitleState.new(c.game)
    eq(existing.logo.path, c.foreign, "pre-import witness is not mixed")
    local product = loadFactory()(c.mod, c.characters)
    check(product.installed, "hot-import product did not install")
    existing:draw()
    eq(existing.logo.path, c.rawLogo,
      "draw-time hot import did not repair existing Red screen")
    eq(countDraws(c.drawCalls, existing.version), 1,
      "hot-import Red screen drew a duplicate ribbon")
  end

  -- Direct install-over-install: the versioned receipt restores a directly
  -- owned install before replacing it, so one native edge advances once.
  do
    local c = context("blue", "de")
    local first = loadFactory()(c.mod, c.characters)
    local second = loadFactory()(c.mod, c.characters)
    eq(first.installed, true, "first direct install failed")
    eq(second.upgraded, nil, "direct reinstall unnecessarily used legacy mode")
    local state = rawget(c.TitleState, "__kantoAscendantTitleIntroState")
    eq(state and state.version, 2, "versioned title receipt missing")
    eq(state and state.mode, "full", "direct reinstall stacked legacy mode")
    local screen = c.TitleState.new(c.game)
    screen.timer = 239
    screen:update(1 / 60)
    eq(screen.kaTitleTrainerId, "BLUE",
      "direct reinstall stacked the trainer-cycle update")
  end

  -- A later Crystal wrapper prevents surgical removal of the older complete
  -- install.  UPDATE6 must preserve it and add only new/draw recovery.
  do
    local c = context("red", "de")
    loadFactory()(c.mod, c.characters)
    local priorUpdate = c.TitleState.update
    local crystalCalls = 0
    c.TitleState.update = function(screen, dt)
      crystalCalls = crystalCalls + 1
      return priorUpdate(screen, dt)
    end
    local upgraded = loadFactory()(c.mod, c.characters)
    eq(upgraded.upgraded, true, "late Crystal wrapper was not preserved")
    local screen = c.TitleState.new(c.game)
    screen.timer = 239
    screen:update(1 / 60)
    eq(crystalCalls, 1, "Crystal wrapper was duplicated or bypassed")
    eq(screen.kaTitleTrainerId, "BLUE",
      "legacy upgrade stacked the trainer-cycle update")
  end

  -- UPDATE5's boolean alone used to make every newer module return early.
  -- The same already-created Red screen is now repairable, and a second
  -- UPDATE6 import replaces (rather than stacks) the narrow upgrade.
  do
    local c = context("red", "de")
    local existing = c.TitleState.new(c.game)
    local nativeDraw = c.TitleState.draw
    c.TitleState.draw = function(screen, ...)
      local full = screen.title.germanFullVersionRibbon
      screen.title.germanFullVersionRibbon = false
      local ok, result = pcall(nativeDraw, screen, ...)
      screen.title.germanFullVersionRibbon = full
      if not ok then error(result, 0) end
      return result
    end
    rawset(c.TitleState, "__kantoAscendantTrainerCycle", true)
    local first = loadFactory()(c.mod, c.characters)
    eq(first.upgraded, true, "old boolean blocked UPDATE6")
    local firstDraw = c.TitleState.draw
    local second = loadFactory()(c.mod, c.characters)
    eq(second.upgraded, true, "legacy upgrade reinstall failed")
    check(c.TitleState.draw ~= firstDraw,
      "legacy upgrade did not replace its owned wrapper")
    existing:draw()
    eq(existing.logo.path, c.rawLogo,
      "old boolean path did not repair existing screen")
    eq(countDraws(c.drawCalls, existing.version), 1,
      "legacy upgrade drew a duplicate edition ribbon")
  end

  -- A similarly named path is not the inactive German Yellow translation.
  do
    local c = context("red", "de", "near")
    local product = loadFactory()(c.mod, c.characters)
    local screen = c.TitleState.new(c.game)
    eq(screen.logo.path,
      "mods/not-deutsch-gelb/overrides/title/pokemon_logo.png",
      "near-match witness was not loaded")
    check(screen.kaTitleLogoRecovered ~= true,
      "non-exact Yellow override path was rejected")
    check(product.recoverForeignYellowLogo(screen) == false,
      "non-exact Yellow path was recovered")
  end

  -- The footer/ribbon transaction remains exception-safe without debug.
  do
    local c = context("blue", "de")
    loadFactory()(c.mod, c.characters)
    local screen = c.TitleState.new(c.game)
    local footer = screen.title.copyrightText
    local ribbon = screen.title.germanFullVersionRibbon
    screen.failDraw = true
    local ok, why = pcall(function() screen:draw() end)
    check(not ok and tostring(why):find("injected native title failure", 1, true),
      "sandbox-safe draw error was not propagated")
    eq(screen.title.copyrightText, footer, "footer was not restored after error")
    eq(screen.title.germanFullVersionRibbon, ribbon,
      "ribbon flag was not restored after error")
  end
end

local ok, why = pcall(run)
debug = savedDebug
love = savedLove
for _, name in ipairs(MODULES) do package.loaded[name] = savedLoaded[name] end
if not ok then error(why, 0) end
print(("title intro 0.1.86 edition/hot-import: %d assertions"):format(assertions))
