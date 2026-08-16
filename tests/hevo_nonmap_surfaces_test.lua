-- Focused Authority-load contract for the non-map HEVO surfaces.
-- The renderer-backed driver owns Bag/Route-5 input and EvolutionState; this
-- test keeps the authoritative eligibility/result matrix cheap to regress.

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()
local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."
local run = T.sdk.loadMod(root, { data = Data, root = sdkRoot })
T.eq(#run.errors, 0, "Authority main.lua loads for HEVO non-map QA")
local api = assert(run.loader.exports.kanto_ascendant)
local packages = assert(api.hevoPackages)
local fieldTech = assert(api.fieldTech)
local ItemEffects = require("src.inventory.ItemEffects")
local Evolution = require("src.pokemon.Evolution")

T.eq(Data.moves.ROLLOUT.name, "ROLLOUT",
  "Authority EN runtime keeps Rollout's localized display name")
T.eq(Data.moves.ANCIENTPOWER.name, "ANCIENTPOWER",
  "Authority EN runtime keeps AncientPower's localized display name")
T.eq(Data.moves.DOUBLE_HIT.name, "DOUBLE HIT",
  "Authority EN runtime keeps Double Hit's localized display name")

local direct = {
  { "PROTECTOR", "protector", "RHYDON", "RHYPERIOR" },
  { "MAGMARIZER", "magmarizer", "MAGMAR", "MAGMORTAR" },
  { "ELECTIRIZER", "electirizer", "ELECTABUZZ", "ELECTIVIRE" },
  { "DUBIOUS_DISC", "dubious_disc", "PORYGON2", "PORYGON_Z" },
  { "RAZOR_FANG", "razor_fang", "GLIGAR", "GLISCOR" },
  { "RAZOR_CLAW", "razor_claw", "SNEASEL", "WEAVILE" },
  { "SHINY_STONE", "shiny_stone", "TOGETIC", "TOGEKISS" },
  { "DUSK_STONE", "dusk_stone", "MISDREAVUS", "MISMAGIUS" },
  { "DUSK_STONE", "dusk_stone", "MURKROW", "HONCHKROW" },
}
local knowledge = {
  { "rollout_knowledge", "ROLLOUT", "LICKITUNG", "LICKILICKY" },
  { "ancient_power_red", "ANCIENTPOWER", "PILOSWINE", "MAMOSWINE" },
  { "ancient_power_green", "ANCIENTPOWER", "TANGELA", "TANGROWTH" },
  { "ancient_power_green", "ANCIENTPOWER", "YANMA", "YANMEGA" },
  { "double_hit_knowledge", "DOUBLE_HIT", "AIPOM", "AMBIPOM" },
}

local unlocks = {}
for _, package in ipairs(packages.order) do unlocks[package.id] = true end
local save = {
  player = { name = "RED" }, flags = {}, inventory = {}, party = {},
  modData = { kanto_ascendant = { hevo_persistent = {
    packageUnlocks = unlocks,
  }, beyond_kanto = {
    version = 1, active = true, irreversible = true,
    decision = "test_fixture",
  } } },
}
packages.reconcile(save)
local game = { data = Data, save = save }

local uniqueItems = {}
for _, row in ipairs(direct) do
  local item, packageId, parent, target = unpack(row)
  uniqueItems[item] = true
  local def = assert(Data.items[item], "live item missing " .. item)
  T.eq(def.effect, packages.ITEM_EFFECT, item .. " uses shared effect")
  T.eq(def.needsTarget, true, item .. " requires real party target")

  local wrongResult, _, wrongExtra = ItemEffects.use(Data, save, item,
    { species = "PIKACHU", moves = {} }, false)
  T.eq(wrongResult, "failed", item .. " rejects wrong species")
  T.eq(wrongExtra and wrongExtra.reason, "species",
    item .. " reports authoritative species refusal")

  local mon = { species = parent, level = 50, moves = {} }
  local result, _, extra = ItemEffects.use(Data, save, item, mon, false)
  T.eq(result, "consumed", item .. " accepts authored parent")
  T.eq(extra and extra.evolveTo, target, item .. " resolves authored target")
  T.eq(extra and extra.hevoPackage, packageId,
    item .. " returns its source-of-truth package")
  local pending, evolution = Evolution.pendingFor(game, mon,
    { kind = "item", item = item })
  T.eq(pending, target, item .. " merged evolution method agrees with Bag")
  T.eq(evolution and evolution.method, packages.byId[packageId].method,
    item .. " uses package method, not a native-stone fallback")
end
local uniqueCount = 0
for _ in pairs(uniqueItems) do uniqueCount = uniqueCount + 1 end
T.eq(uniqueCount, 8, "exactly eight direct target items are covered")
T.eq(#direct, 9, "Dusk Stone's two direct targets are both covered")

local function hasRow(rows, id)
  for _, row in ipairs(rows or {}) do if row.id == id then return true end end
  return false
end
for _, row in ipairs(knowledge) do
  local packageId, move, parent, target = unpack(row)
  local mon = { species = parent, level = 60,
    moves = { { id = "TACKLE", pp = Data.moves.TACKLE.pp } } }
  T.check(hasRow(fieldTech.reminderMoves(game, mon), move),
    parent .. " receives " .. move .. " from the merged Reminder provider")
  local learned, learnErr = fieldTech.rememberMove(game, mon, move)
  T.check(learned and not learnErr and mon.moves[#mon.moves].id == move,
    parent .. " learns " .. move .. " through the production Reminder seam")
  local pending, evolution = Evolution.pendingFor(game, mon,
    { kind = "levelup" })
  T.eq(pending, target, move .. " level-up eligibility resolves " .. target)
  T.eq(evolution and evolution.method, packages.byId[packageId].method,
    move .. " level-up uses its package method")

  -- Once evolved, the authored target learnset remains Reminder-compatible.
  -- This is independent from the parent-only package provider and catches an
  -- evolved species that would otherwise lose its defining move on reload.
  local evolved = { species = target, level = 60,
    moves = { { id = "TACKLE", pp = Data.moves.TACKLE.pp } } }
  T.check(hasRow(fieldTech.reminderMoves(game, evolved), move),
    target .. " can re-learn " .. move .. " after evolution/reload")
end

T.finish("HEVO NON-MAP SURFACES")
