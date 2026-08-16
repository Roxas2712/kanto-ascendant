-- L04 connected Legacy package cells which replace the single blocked-driver
-- placeholder.  The pre-existing Pact 4x4 and three-Journey cells remain
-- authoritative and are intentionally not repeated here.  Every row uses a
-- fresh identity, an installed-package gate and explicit result substrings.

local cells = {}

local function storyCell(edition, locale, yellowPath)
  local id = ("l04-connected-%s-%s"):format(edition, locale)
  local identity = ("ka65-final-legacy-connected-%s-%s")
    :format(edition, locale)
  cells[#cells + 1] = {
    id = id,
    identity = identity,
    edition = edition,
    closure = "base_deutsch",
    driver = "tests/legacy_story_partner_fresh_e2e_driver.lua",
    timeout_seconds = 3600,
    env = {
      QA_LANGUAGE = locale,
      QA_YELLOW_PATH = yellowPath,
    },
    passes = {
      {
        name = "language-setup",
        driver = "tests/legacy_connected_language_setup_driver.lua",
        timeout_seconds = 300,
      },
      {
        name = "connected-story-partner",
        driver = "tests/legacy_story_partner_fresh_e2e_driver.lua",
        timeout_seconds = 3600,
      },
    },
    result = {
      path = "driver_result.txt",
      contains = {
        "status=PASS",
        "scope=LEGACY-CONNECTED-FRESH-LAB",
        "edition=" .. edition,
        "locale=" .. locale,
        "path=" .. yellowPath,
        "physical_lab_pc=PASS",
        "fresh_confirm_default_no=2/2",
        "partner_confirm_default_no=2/2",
        "rival_ball_boundary=1/1",
        "mid_phase_native_reload=1/1",
        "physical_lab_exit_lock=1/1",
        "partner_rival_durable=1/1",
        "native_save_reload=midphase+partner",
        "archive_transaction=1/1",
        "engine_payload_sha256=",
        "authority_package_sha256=",
        "deutsch_package_sha256=",
        "package_gate_receipt_sha256=",
        "fail=0",
      },
    },
    images = { min_count = 20, min_bytes = 1000 },
  }
end

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  storyCell(edition, "en", "catalog")
  -- Split Yellow across both authored physical choices without adding a
  -- seventh story cell: EN covers Catalogue and DE covers Pikachu.
  storyCell(edition, "de", edition == "yellow" and "pikachu" or "catalog")
end

cells[#cells + 1] = {
  id = "l04-archive-transaction",
  identity = "ka65-final-legacy-archive-transaction",
  edition = "red",
  closure = "base_deutsch",
  driver = "tools/legacy_archive_transaction_package_driver.lua",
  timeout_seconds = 600,
  result = {
    path = "driver_result.txt",
    contains = {
      "status=PASS",
      "scope=LEGACY-ARCHIVE-TRANSACTION",
      "installed_archive_factory=1/1",
      "failed_witness_rollback=1/1",
      "source_save_unchanged=2/2",
      "committed_witness_recovery=1/1",
      "same_source_retry_exact_once=1/1",
      "v1_to_v7_migration=1/1",
      "migration_persist_exact_once=1/1",
      "engine_payload_sha256=",
      "authority_package_sha256=",
      "deutsch_package_sha256=",
      "package_gate_receipt_sha256=",
      "fail=0",
    },
  },
  images = { exact_count = 0, min_bytes = 1 },
}

cells[#cells + 1] = {
  id = "l04-archive-daycare-de",
  identity = "ka65-final-legacy-daycare-de",
  edition = "red",
  closure = "base_deutsch",
  driver = "tests/legacy_archive_daycare_visual_driver.lua",
  timeout_seconds = 1800,
  env = { QA_LANGUAGE = "de" },
  result = {
    path = "driver_result.txt",
    contains = {
      "status=PASS",
      "scope=LEGACY-ARCHIVE-DAYCARE",
      "edition=red",
      "locale=de",
      "vanilla_daycare_block=1/1",
      "daycare_plus_block=1/1",
      "blocked_retry_side_effect_free=1/1",
      "fresh_handoff=1/1",
      "native_save_reload=1/1",
      "engine_payload_sha256=",
      "authority_package_sha256=",
      "deutsch_package_sha256=",
      "package_gate_receipt_sha256=",
      "fail=0",
    },
  },
  -- Five evidence frames plus one deliberately consumed back-buffer file.
  images = { exact_count = 6, min_bytes = 1000 },
}

cells[#cells + 1] = {
  id = "l04-workshop-full",
  identity = "ka65-final-legacy-workshop-product-full",
  edition = "red",
  closure = "dramaless_fp",
  driver = "tools/ngplus_legacy_workshop_e2e_driver.lua",
  timeout_seconds = 2400,
  result = {
    path = "driver_result.txt",
    contains = {
      "status=PASS",
      "scope=LEGACY-WORKSHOP-PRODUCT",
      "edition=red",
      "renderer=2D+DRAMALESS_FULL",
      "curator_entry=1/1",
      "seal_states=0/1/2/3",
      "native_save_reload=4/4",
      "unsolved_resonance_gate=3/3",
      "ledger_purchase=1/1",
      "physical_gallery_return=1/1",
      "engine_payload_sha256=",
      "authority_package_sha256=",
      "deutsch_package_sha256=",
      "dramaless_package_sha256=",
      "first_person_package_sha256=",
      "package_gate_receipt_sha256=",
      "fail=0",
    },
  },
  images = { exact_count = 12, min_bytes = 1000 },
}

cells[#cells + 1] = {
  id = "l04-workshop-resonance-2d",
  identity = "ka65-final-legacy-workshop-resonance-2d",
  edition = "red",
  closure = "base_deutsch",
  driver = "tools/ngplus_legacy_workshop_resonance_e2e_driver.lua",
  timeout_seconds = 3000,
  result = {
    path = "driver_result.txt",
    contains = {
      "status=PASS",
      "scope=LEGACY-WORKSHOP-RESONANCE",
      "edition=red",
      "renderer=2D",
      "characters=RED,BLUE,GREEN",
      "unsolved_gate=3/3",
      "ready_default_no=3/3",
      "native_save_reload=10/10",
      "walkable_resonance_destination=3/3",
      "physical_return=3/3",
      "return_token_exact_once=3/3",
      "engine_payload_sha256=",
      "authority_package_sha256=",
      "deutsch_package_sha256=",
      "package_gate_receipt_sha256=",
      "fail=0",
    },
  },
  images = { exact_count = 12, min_bytes = 1000 },
}

cells[#cells + 1] = {
  id = "l04-title-archive-card-de",
  identity = "ka65-final-legacy-title-card-de",
  edition = "red",
  closure = "base_deutsch",
  driver = "tests/legacy_wanderer_title_visual_driver.lua",
  timeout_seconds = 1800,
  result = {
    path = "driver_result.txt",
    contains = {
      "status=PASS",
      "scope=LEGACY-TITLE-ARCHIVE-CARD",
      "edition=red",
      "locale=de",
      "archive_title_handoff=1/1",
      "native_save_reload=1/1",
      "trainer_card_title=FABRIK-ARCHITEKT",
      "trainer_card_pact=PAKT:VERM.",
      "wanderer_title_reaction=1/1",
      "committed_partner_reaction=1/1",
      "engine_payload_sha256=",
      "authority_package_sha256=",
      "deutsch_package_sha256=",
      "package_gate_receipt_sha256=",
      "fail=0",
    },
  },
  images = { exact_count = 4, min_bytes = 1000 },
}

assert(#cells == 11, "connected Legacy matrix must contain exactly 11 cells")
return cells
