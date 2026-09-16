-- Support-safe inventory for the independently switchable Hoenn runtime
-- surfaces selected for KASC 6.6. The actual gates stay in their owning
-- modules; this file gives each one a stable Card/owner identity and makes
-- the release rollback boundary visible without reading or mutating saves.

return function(mod, opts)
  opts = opts or {}
  local C = {
    schema = "kasc-hoenn-optional-card-inventory/v1",
    cards = {
      {
        id="KASC-66-HOENN-ENCOUNTERS", option="hoenn_encounters",
        owner="kasc.hoenn.encounters/v1", provider="hoennFieldAccess",
      },
      {
        id="KASC-66-HOENN-TRACE-PRESENTATION",
        option="hoenn_trace_presentation",
        owner="kasc.hoenn.trace-presentation/v1",
        provider="hoennTracePresentation67",
      },
      {
        id="KASC-66-EON-ROAMERS", option="hoenn_roamers",
        owner="kasc.hoenn.eon-roamers/v1", provider="hoennRoamers67",
      },
      {
        id="KASC-66-REGI-SANCTUMS", option="hoenn_regi_sanctums",
        owner="kasc.hoenn-regi-sanctum-puzzles/v2",
        provider="hoennResearchSanctums67",
      },
      {
        id="KASC-66-MOLTRES-VOLCANO", option="hoenn_moltres_volcano",
        owner="kasc.hoenn-moltres-volcano/v4",
        provider="hoennMoltresVolcano67",
      },
      {
        id="KASC-66-HOENN-ENDGAME-ACCESS",
        option="hoenn_endgame_access_puzzles",
        owner="kasc.hoenn-endgame-access-puzzles/v1",
        provider="hoennEndgameAccess67",
      },
      {
        id="KASC-66-HOENN-LEGEND-PORTALS", option="hoenn_legend_portals",
        owner="kasc.hoenn.legend-portals/v1",
        provider="hoennLegendPortals67",
      },
      {
        id="KASC-66-BIRTH-ISLAND-DEOXYS", option="hoenn_birth_island",
        owner="kasc.hoenn.birth-island-deoxys/v1",
        provider="hoennBirthIsland67",
      },
      {
        id="KASC-66-JIRACHI-FINALE", option="hoenn_jirachi_finale",
        owner="kasc.hoenn.jirachi-finale/v1",
        provider="hoennJirachiFinale67",
      },
    },
  }

  local function enabled(card)
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, card.option)
      if ok and value == false then return false end
    end
    return true
  end

  function C.isEnabled(id)
    for _, card in ipairs(C.cards) do
      if card.id == id then return enabled(card) end
    end
    return nil, "unknown-card"
  end

  function C.inventory()
    local rows = {}
    for _, card in ipairs(C.cards) do
      rows[#rows + 1] = {
        cardId=card.id, option=card.option, owner=card.owner,
        provider=card.provider, active=enabled(card),
      }
    end
    return rows
  end

  local support = opts.supportLog
  if support and type(support.registerSegment) == "function" then
    for _, card in ipairs(C.cards) do
      local active = enabled(card)
      support.registerSegment({
        segmentId=card.id, cardId=card.id, version="1.0.0",
        schema="kasc.optional-feature-card/v1", owner=card.owner,
        active=active, dependencyStatus="local-reviewed",
        providerStatus=active and "runtime-loaded" or "cold-disabled",
        buildReceiptId="docs/HOENN_OPTIONAL_CARDS_67.md",
        rollbackReceiptId="select-" .. card.option .. "-off",
      })
    end
  end

  return C
end
