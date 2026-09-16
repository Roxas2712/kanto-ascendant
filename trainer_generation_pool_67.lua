-- KASC-67-TRAINER-GENERATION-POOL. Trainer-only admission; no encounter edits.
return function(mod,opts)
  local catalog,species,rules=assert(opts.catalog),assert(opts.species),assert(opts.rules)
  local M={CARD_ID='KASC-67-TRAINER-GENERATION-POOL',OWNER='kasc.trainer-generation-pool/v1'}
  -- Legendary/mythical IDs from the pinned pokemon_species.csv used by the
  -- backend importer. Ultra Beasts retain special encounters, not ordinary
  -- field-trainer recruitment. Authored bosses/captures keep their own owner.
  local special={}
  for _,dex in ipairs({144,145,146,150,151,243,244,245,249,250,251,
      377,378,379,380,381,382,383,384,385,386,480,481,482,483,484,485,
      486,487,488,489,490,491,492,493,494,638,639,640,641,642,643,
      644,645,646,647,648,649,716,717,718,719,720,721,772,773,
      785,786,787,788,789,790,791,792,793,794,795,796,797,798,799,
      800,801,802,803,804,805,806,807,808,809})do special[dex]=true end
  local names={}
  for dex=1,809 do
    local row=catalog.entries['dex:'..dex]
    if row then names[row.identifier:upper():gsub('-','_')]='dex:'..dex end
  end
  function M.resolve(name)
    local key=species.bySpecies[name] or names[name]
    local row=key and catalog.entries[key]
    return row and row.isBase and species.byKey[key] or nil
  end
  function M.canonical(id,def)
    if type(def)~='table' or type(id)~='string' or def.id~=id then return false end
    local key=species.bySpecies[id]
    local row=key and catalog.entries[key]
    if not row or not row.isBase or species.byKey[key]~=id
        or def.isMega or def.isGigantamax or def.backendForm
        or def.regionalForm and def.regionalForm~='' then return false end
    return true
  end
  function M.ordinary(def)
    if not M.canonical(type(def)=='table' and def.id,def)then return false end
    local key=species.bySpecies[def.id]
    local row=catalog.entries[key]
    if row.nationalDex>809 or row.originGeneration>7 or special[row.nationalDex]then return false end
    -- Canonical backend registration was called giftOnly to avoid adding
    -- encounters. Allow that exact owner's base record for trainers; do not
    -- change the registry flag or admit arbitrary event/custom definitions.
    if def.giftOnly and not (def.backendOwner==species.OWNER and def.backendKey==key)then return false end
    return true
  end
  function M.available(game,id,def)
    return M.ordinary(def) and def.id==id and rules.speciesAvailable(game,id,def)==true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='canonical-backend-and-generation-rules',
      providerStatus='ordinary-gen1-7-trainer-pools',
      buildReceiptId='docs/TRAINER_GENERATION_POOL_67.md',
      rollbackReceiptId='docs/TRAINER_GENERATION_POOL_67.md'})
  end
  return M
end
