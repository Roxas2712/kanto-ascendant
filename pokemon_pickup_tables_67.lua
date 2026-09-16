-- Pure historical Pickup draw, conditional on the separate 10% ability roll.
-- KASC's era editions: Emerald, Platinum, B2W2, ORAS, USUM.
-- Runtime registration and effects belong to pokemon_pickup_67.lua.
local M={schema='kasc.pickup-tables/v1'}
local common3={'POTION','ANTIDOTE','SUPER_POTION','GREAT_BALL','REPEL','ESCAPE_ROPE',
  'X_ATTACK','FULL_HEAL','ULTRA_BALL','HYPER_POTION','RARE_CANDY','PROTEIN',
  'REVIVE','HP_UP','FULL_RESTORE','MAX_REVIVE','PP_UP','MAX_ELIXIR'}
local common4={'POTION','ANTIDOTE','SUPER_POTION','GREAT_BALL','REPEL','ESCAPE_ROPE',
  'FULL_HEAL','HYPER_POTION','ULTRA_BALL','REVIVE','RARE_CANDY','DUSK_STONE',
  'SHINY_STONE','DAWN_STONE','FULL_RESTORE','MAX_REVIVE','PP_UP','MAX_ELIXIR'}
local common56={'POTION','ANTIDOTE','SUPER_POTION','GREAT_BALL','REPEL','ESCAPE_ROPE',
  'FULL_HEAL','HYPER_POTION','ULTRA_BALL','REVIVE','RARE_CANDY','SUN_STONE',
  'MOON_STONE','HEART_SCALE','FULL_RESTORE','MAX_REVIVE','PP_UP','MAX_ELIXIR'}
-- TM names are move identities, NOT a modern TM number reinterpreted by
-- the Gen-I host (e.g. TM01 Focus Punch must not become Mega Punch).
local rare34={'HYPER_POTION','NUGGET','KINGS_ROCK','FULL_RESTORE','ETHER','WHITE_HERB',
  'TM_REST','ELIXIR','TM_FOCUS_PUNCH','LEFTOVERS','TM_EARTHQUAKE'}
local rare5={'RARE_CANDY','HYPER_POTION','NUGGET','KINGS_ROCK','ETHER','IRON_BALL',
  'PRISM_SCALE','ELIXIR','PRISM_SCALE','LEFTOVERS','PRISM_SCALE'}
local rare6={'HYPER_POTION','NUGGET','KINGS_ROCK','FULL_RESTORE','ETHER','IRON_BALL',
  'DESTINY_KNOT','ELIXIR','DESTINY_KNOT','LEFTOVERS','DESTINY_KNOT'}
local common={[3]=common3,[4]=common4,[5]=common56,[6]=common56}
local rare={[3]=rare34,[4]=rare34,[5]=rare5,[6]=rare6}
local thresholds={30,40,50,60,70,80,90,94,98}
local modern={
  {{'POTION',25},{'ANTIDOTE',10},{'SUPER_POTION',10},{'GREAT_BALL',10},{'REPEL',10},
    {'ESCAPE_ROPE',10},{'FULL_HEAL',10},{'HYPER_POTION',5},{'NUGGET',5},
    {'ULTRA_BALL',3},{'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'ANTIDOTE',25},{'SUPER_POTION',10},{'GREAT_BALL',10},{'REPEL',10},{'ESCAPE_ROPE',10},
    {'FULL_HEAL',10},{'HYPER_POTION',5},{'ULTRA_BALL',3},{'PRISM_SCALE',3},
    {'SUN_STONE',3},{'MOON_STONE',3},{'NUGGET',3},{'REVIVE',2},{'BALM_MUSHROOM',1},
    {'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'SUPER_POTION',25},{'GREAT_BALL',10},{'REPEL',10},{'ESCAPE_ROPE',10},{'FULL_HEAL',10},
    {'HYPER_POTION',5},{'ULTRA_BALL',5},{'SUN_STONE',5},{'MOON_STONE',5},
    {'RARE_CANDY',3},{'PRISM_SCALE',3},{'BALM_MUSHROOM',3},{'REVIVE',2},
    {'FULL_RESTORE',1},{'PEARL_STRING',1},{'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'GREAT_BALL',25},{'REPEL',10},{'ESCAPE_ROPE',10},{'FULL_HEAL',10},{'HYPER_POTION',10},
    {'ULTRA_BALL',5},{'REVIVE',5},{'SUN_STONE',5},{'MOON_STONE',5},{'PEARL_STRING',4},
    {'RARE_CANDY',3},{'PRISM_SCALE',3},{'ETHER',1},{'FULL_RESTORE',1},{'BIG_NUGGET',1},
    {'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'REPEL',20},{'ESCAPE_ROPE',10},{'FULL_HEAL',10},{'HYPER_POTION',10},{'ULTRA_BALL',10},
    {'SUN_STONE',10},{'MOON_STONE',10},{'REVIVE',5},{'BIG_NUGGET',4},{'RARE_CANDY',3},
    {'PRISM_SCALE',3},{'FULL_RESTORE',2},{'ETHER',1},{'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'ESCAPE_ROPE',20},{'FULL_HEAL',10},{'HYPER_POTION',10},{'ULTRA_BALL',10},
    {'SUN_STONE',10},{'MOON_STONE',10},{'RARE_CANDY',8},{'REVIVE',7},{'BIG_NUGGET',5},
    {'FULL_RESTORE',3},{'PRISM_SCALE',3},{'ETHER',1},{'HEART_SCALE',1},
    {'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'FULL_HEAL',20},{'HYPER_POTION',10},{'ULTRA_BALL',10},{'REVIVE',10},
    {'SUN_STONE',10},{'MOON_STONE',10},{'RARE_CANDY',8},{'FULL_RESTORE',5},
    {'BIG_NUGGET',5},{'HEART_SCALE',4},{'ELIXIR',3},{'PRISM_SCALE',3},
    {'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'HYPER_POTION',20},{'ULTRA_BALL',10},{'REVIVE',10},{'HEART_SCALE',10},
    {'SUN_STONE',10},{'MOON_STONE',10},{'RARE_CANDY',8},{'ELIXIR',5},
    {'FULL_RESTORE',5},{'BIG_NUGGET',5},{'PRISM_SCALE',3},{'MAX_REVIVE',2},
    {'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'ULTRA_BALL',20},{'REVIVE',10},{'HEART_SCALE',10},{'FULL_RESTORE',10},
    {'MAX_REVIVE',10},{'SUN_STONE',10},{'MOON_STONE',10},{'RARE_CANDY',8},
    {'BIG_NUGGET',5},{'PRISM_SCALE',3},{'MAX_ELIXIR',1},{'PP_UP',1},
    {'DESTINY_KNOT',1},{'LEFTOVERS',1}},
  {{'REVIVE',20},{'FULL_RESTORE',15},{'HEART_SCALE',10},{'MAX_REVIVE',10},
    {'SUN_STONE',10},{'MOON_STONE',10},{'RARE_CANDY',8},{'BIG_NUGGET',5},
    {'PP_UP',4},{'MAX_ELIXIR',3},{'PRISM_SCALE',3},{'DESTINY_KNOT',1},{'LEFTOVERS',1}},
}
function M.draw(gen,level,roll)
  if type(gen)~='number'or gen%1~=0 or gen<3 or gen>7
      or type(level)~='number'or level%1~=0 or level<1
      or type(roll)~='number'or roll%1~=0 or roll<0 or roll>99 then return nil end
  local band=math.min(9,math.floor((level-1)/10))
  if gen==7 then
    local limit=0
    for _,row in ipairs(modern[band+1])do
      limit=limit+row[2];if roll<limit then return row[1]end
    end
  else
    if roll==99 then return rare[gen][band+1]end
    if roll==98 then return rare[gen][band+2]end
    for index,limit in ipairs(thresholds)do
      if roll<limit then return common[gen][band+index]end
    end
  end
end
function M.items()
  local set,out={},{}
  for gen=3,7 do for level=1,100,10 do for roll=0,99 do
    local id=assert(M.draw(gen,level,roll),'incomplete Pickup probability table')
    if not set[id]then set[id]=true;out[#out+1]=id end
  end end end
  table.sort(out);return out
end
return M
