-- Yellow's four Jessie/James encounters share OPP_ROCKET with ordinary
-- grunts.  The duo identity is therefore the exact live Yellow trainer
-- record plus the original party-index boundary, never a class-name skin.

local root = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
local edition = "yellow"
package.loaded["src.core.GameVersion"] = {
  get = function() return edition end,
}

local checks = 0
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, ("FAIL: %s (got %s, expected %s)")
    :format(message, tostring(actual), tostring(expected)))
end
local function check(value, message)
  checks = checks + 1
  assert(value, "FAIL: " .. message)
end

local portraits = assert(loadfile(root .. "/trainer_voxel_portraits.lua"))()({
  path = root,
})
check(type(portraits.specForBattle) == "function",
  "portrait authority exposes a battle-aware resolver")

local rocket = {
  id = "OPP_ROCKET",
  pic = "/engine/yellow/rocket.png",
  picJessieJames = "/engine/yellow/jessie-james.png",
  parties = {
    [42] = {}, [43] = {}, [44] = {}, [45] = {},
  },
}
local game = { data = { trainers = { OPP_ROCKET = rocket } } }
local function battle(index, trainer)
  return {
    game = game,
    trainer = trainer == nil and rocket or trainer,
    oppClass = "OPP_ROCKET",
    partyIndex = index,
    showEnemyTrainer = true,
  }
end

for partyIndex = 42, 45 do
  local spec = assert(portraits.specForBattle(battle(partyIndex)),
    "Jessie/James party " .. partyIndex .. " has no portrait spec")
  eq(spec.id, "YELLOW_JESSIE_JAMES_MEOWTH",
    "each Yellow story party resolves the trio identity")
  eq(spec.class, "OPP_ROCKET", "the original trainer class is preserved")
  eq(spec.path,
    "assets/yellow_jessie_james/battle/"
      .. "jessie_james_meowth_voxel_front_hd.png",
    "the 128px trio contract is explicit")
  eq(spec.fallback,
    "assets/yellow_jessie_james/battle/"
      .. "jessie_james_meowth_voxel_front.png",
    "the independent 64px trio contract is explicit")
  eq(spec.failSafe,
    "assets/crystal_v15/trainers/normal/jessie_james.png",
    "the exact bundled duo remains the final safe surface")
  eq(spec.assetContract.requires.jessie, true,
    "the authored contract requires Jessie")
  eq(spec.assetContract.requires.james, true,
    "the authored contract requires James")
  eq(spec.assetContract.requires.meowth, true,
    "the authored contract requires Meowth")
  eq(spec.authority.schema, "ka-yellow-jessie-james-battle/v1",
    "the live route carries an inspectable authority receipt")
  eq(spec.authority.partyIndex, partyIndex,
    "the receipt binds the exact story party")
  eq(spec.authority.trainerRecord, rocket,
    "the receipt binds the live trainer registry object")
  eq(spec.authority.nativePortrait, rocket.picJessieJames,
    "the receipt binds Yellow's native duo portrait")
end

eq(portraits.specForBattle(battle(41)).id, "KANTO_ROCKET",
  "the last ordinary Rocket party remains the generic grunt")

local copied = {
  id = rocket.id, pic = rocket.pic, picJessieJames = rocket.picJessieJames,
  parties = rocket.parties,
}
eq(portraits.specForBattle(battle(42, copied)).id, "KANTO_ROCKET",
  "a copied trainer record cannot adopt the duo identity")

local originalPic = rocket.picJessieJames
rocket.picJessieJames = nil
eq(portraits.specForBattle(battle(42)).id, "KANTO_ROCKET",
  "missing native Jessie/James authority fails closed")
rocket.picJessieJames = originalPic

local party45 = rocket.parties[45]
rocket.parties[45] = nil
eq(portraits.specForBattle(battle(45)).id, "KANTO_ROCKET",
  "a nonexistent party cannot cross the Yellow duo threshold")
rocket.parties[45] = party45

edition = "red"
eq(portraits.specForBattle(battle(42)).id, "KANTO_ROCKET",
  "Red cannot infer Jessie/James from the party number")
edition = "blue"
eq(portraits.specForBattle(battle(42)).id, "KANTO_ROCKET",
  "Blue cannot infer Jessie/James from the party number")

print(("jessie_james_battle_identity_test: PASS (%d checks)"):format(checks))
