-- KASC-67-EQUIPMENT-REWARDS. Pure, shared ordinary reward pool.
-- An item definition is not an effect implementation. The equipment owner
-- publishes reward readiness only after registering the applicable effect.
local M={CARD_ID='KASC-67-EQUIPMENT-REWARDS',schema='kasc.equipment-rewards/v1'}
local groups={
  {category='berry',weight=12,qty=2,items={
    {2,'BERRY'},{2,'GOLD_BERRY'},{2,'PSNCUREBERRY'},
    {2,'PRZCUREBERRY'},{2,'BURNT_BERRY'},{2,'ICE_BERRY'},
    {2,'BITTER_BERRY'},{2,'MINT_BERRY'},{2,'MIRACLEBERRY'},
    {2,'MYSTERYBERRY'},
    {3,'ORAN_BERRY'},{3,'SITRUS_BERRY'},{3,'CHERI_BERRY'},
    {3,'CHESTO_BERRY'},{3,'PECHA_BERRY'},{3,'RAWST_BERRY'},
    {3,'ASPEAR_BERRY'},{3,'LEPPA_BERRY'},{3,'PERSIM_BERRY'},{3,'LUM_BERRY'},
  }},
  {category='held_boost',weight=4,qty=1,items={
    {2,'CHARCOAL'},{2,'MYSTIC_WATER'},{2,'MIRACLE_SEED'},
    {2,'MAGNET'},{2,'NEVERMELTICE'},{2,'BLACK_BELT'},
    {2,'POISON_BARB'},{2,'SOFT_SAND'},{2,'SHARP_BEAK'},
    {2,'TWISTEDSPOON'},{2,'SILVERPOWDER'},{2,'HARD_STONE'},
    {2,'SPELL_TAG'},{2,'DRAGON_FANG'},{2,'BLACKGLASSES'},
    {2,'METAL_COAT'},{2,'PINK_BOW'},
    {3,'SILK_SCARF'},
  }},
  {category='held_rare',weight=1,qty=1,premium=true,items={
    {6,'BLUE_ORB'},{6,'RED_ORB'},{7,'ULTRANECROZIUM_Z'},
    {2,'LEFTOVERS'},{2,'SCOPE_LENS'},{2,'QUICK_CLAW'},
    {2,'LUCKY_PUNCH'},{2,'STICK'},{4,'RAZOR_CLAW'},
    {2,'LIGHT_BALL'},{2,'THICK_CLUB'},{2,'METAL_POWDER'},
    {3,'DEEP_SEA_TOOTH'},{3,'DEEP_SEA_SCALE'},{3,'SOUL_DEW'},
    {2,'FOCUS_BAND'},{4,'FOCUS_SASH'},
    {2,'SMOKE_BALL'},
    {3,'SHELL_BELL'},{3,'CHOICE_BAND'},
    {4,'CHOICE_SPECS'},{4,'CHOICE_SCARF'},
    {4,'QUICK_POWDER'},
    {5,'ROCKY_HELMET'},
    {5,'EVIOLITE'},
    {4,'LIFE_ORB'},
    {4,'BIG_ROOT'},{4,'LIGHT_CLAY'},
    {5,'NORMAL_GEM'},{5,'FIRE_GEM'},{5,'WATER_GEM'},{5,'ELECTRIC_GEM'},
    {5,'GRASS_GEM'},{5,'ICE_GEM'},{5,'FIGHTING_GEM'},{5,'POISON_GEM'},
    {5,'GROUND_GEM'},{5,'FLYING_GEM'},{5,'PSYCHIC_GEM'},{5,'BUG_GEM'},
    {5,'ROCK_GEM'},{5,'GHOST_GEM'},{5,'DRAGON_GEM'},{5,'DARK_GEM'},
    {5,'STEEL_GEM'},{6,'FAIRY_GEM'},
    {4,'FIST_PLATE'},{4,'SKY_PLATE'},{4,'TOXIC_PLATE'},{4,'EARTH_PLATE'},
    {4,'STONE_PLATE'},{4,'INSECT_PLATE'},{4,'SPOOKY_PLATE'},{4,'IRON_PLATE'},
    {4,'FLAME_PLATE'},{4,'SPLASH_PLATE'},{4,'MEADOW_PLATE'},{4,'ZAP_PLATE'},
    {4,'MIND_PLATE'},{4,'ICICLE_PLATE'},{4,'DRACO_PLATE'},{4,'DREAD_PLATE'},
    {6,'PIXIE_PLATE'},
    {7,'FIGHTING_MEMORY'},{7,'FLYING_MEMORY'},{7,'POISON_MEMORY'},{7,'GROUND_MEMORY'},
    {7,'ROCK_MEMORY'},{7,'BUG_MEMORY'},{7,'GHOST_MEMORY'},{7,'STEEL_MEMORY'},
    {7,'FIRE_MEMORY'},{7,'WATER_MEMORY'},{7,'GRASS_MEMORY'},{7,'ELECTRIC_MEMORY'},
    {7,'PSYCHIC_MEMORY'},{7,'ICE_MEMORY'},{7,'DRAGON_MEMORY'},{7,'DARK_MEMORY'},
    {7,'FAIRY_MEMORY'},
  }},
}
function M.registerSupport(log)
  if log and log.registerSegment then
    log.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,version='1.0.0',
      schema='kasc.optional-feature-card/v1',owner='kasc.equipment-rewards/v1',
      active=true,dependencyStatus='effect-readiness-gated',providerStatus='shared-pool-loaded',
      buildReceiptId='docs/EQUIPMENT_REWARDS_67.md',
      rollbackReceiptId='disable-new-draws-preserve-sealed-receipts'})
  end
end
function M.pool(data,ctx)
  local epoch=tonumber(ctx and ctx.activeEpoch) or 1
  if epoch<2 then return {} end
  local out={}
  for _,group in ipairs(groups)do
    local eligible={}
    for _,entry in ipairs(group.items)do
      local id=entry[2];local def=data and data.items and data.items[id]
      local readiness=def and def.kascEquipmentRewardEpochs
      if epoch>=entry[1] and type(readiness)=='table' and readiness[epoch]==true
          and def.lootExcluded~=true and def.progressionItem~=true
          and not def.keyItem then
        eligible[#eligible+1]=id
      end
    end
    table.sort(eligible)
    for _,id in ipairs(eligible)do
      out[#out+1]={item=id,qty=group.qty,weight=group.weight/#eligible,
        category=group.category,premium=group.premium or false,
        sourceCard=M.CARD_ID}
    end
  end
  return out
end
-- Scalar receipt fields are shared with the existing tournament/archive
-- journal. No dynamic catalog lookup is needed to preserve old reservations.
function M.validReceiptItem(id,qty,epoch)
  if id==nil and qty==nil and epoch==nil then return true end
  if type(epoch)~='number' or epoch%1~=0 or epoch<2 or epoch>7 then return false end
  for _,group in ipairs(groups)do
    for _,row in ipairs(group.items)do
      if row[2]==id then return qty==group.qty and epoch>=row[1] end
    end
  end
  return false
end

-- Sealed activities (raids / championships) have no ordinary weighted item
-- slot. Resolve one 25% bonus from their unique completion identity, then let
-- their existing journal own delivery. Retries never draw fresh randomness.
function M.pick(data,ctx,seed)
  if type(seed)~='string' or seed=='' then return nil end
  local pool=M.pool(data,ctx);if #pool==0 then return nil end
  local function hash(value)
    local n=173
    for i=1,#value do n=(n*131+value:byte(i))%2147483647 end
    return n
  end
  if hash('drop:'..seed)%10000>=2500 then return nil end
  local total=0;for _,row in ipairs(pool)do total=total+row.weight end
  local point=(hash('item:'..seed)%1000000)/1000000*total
  for _,row in ipairs(pool)do
    point=point-row.weight
    if point<0 then return row end
  end
  return pool[#pool]
end
return M
