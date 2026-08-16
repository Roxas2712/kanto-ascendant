-- One-shot prerequisite-save builder for the package-only connected Johto
-- acceptance run.  BLITZ imports only the orchestrator-pinned immutable save;
-- FRESH begins with the engine's real SaveData.newGame result.  The latter
-- records one explicit Hall-of-Fame prerequisite because this bounded proof
-- starts at the post-League host -- the same driver's later League re-clear is
-- still earned physically and is the only cadence receipt claimed by QA.
--
-- Both variants may strengthen the disposable party and select a safe Indigo
-- starting location.  Neither creates/changes passages nor invokes a Johto
-- controller.  From title CONTINUE onward they use the identical physical
-- tools/johto_masters_passages_pure_qa.lua path.
--
-- The Hall record, badge, visit flag, deterministic party and Indigo position
-- are documented prerequisite state, not traversal evidence.  Everything
-- after title CONTINUE -- including the new Hall row used for farm cadence --
-- is earned through the production maps, battles, credits, save and Fly UI.
return function(game)
  local U=dofile(os.getenv("KA_TEST_UTIL")
    or (os.getenv("GEN1RECOMP_DIR") or ".").."/tests/drivers/util.lua")
  local SaveData=require("src.core.SaveData")
  local Pokemon=require("src.pokemon.Pokemon")
  local Stats=require("src.pokemon.Stats")
  local version=assert(os.getenv("POKEPORT_VERSION"),"POKEPORT_VERSION required")
  local identity=assert(os.getenv("POKEPORT_IDENTITY"),"isolated POKEPORT_IDENTITY required")
  local variant=tostring(assert(os.getenv("JOHTO_QA_VARIANT"),
    "JOHTO_QA_VARIANT required")):upper()
  local renderer=tostring(assert(os.getenv("QA_RENDERER"),
    "QA_RENDERER required")):upper()
  assert(variant=="BLITZ" or variant=="FRESH",
    "JOHTO_QA_VARIANT must be BLITZ or FRESH")
  assert(renderer=="2D" or renderer=="FULL",
    "QA_RENDERER must be 2D or FULL")
  local expectedIdentity=("ka65-final-johto-connected-%s-%s")
    :format(variant:lower(),renderer:lower())
  local source=assert(os.getenv("KA_SOURCE_SAVE"),"KA_SOURCE_SAVE required")
  local sourceSha=assert(os.getenv("KA_SOURCE_SAVE_SHA256"),
    "KA_SOURCE_SAVE_SHA256 required")
  local gateSha=assert(os.getenv("KA_PACKAGE_GATE_RECEIPT_SHA256"),
    "KA_PACKAGE_GATE_RECEIPT_SHA256 required")
  local harnessRoot=assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR package harness required")
  local expectedSource=harnessRoot
    .."/immutable_inputs/source_snapshot/slot7_original_readonly.lua"
  local function validSha(value)
    return type(value)=="string" and #value==64
      and value:match("^[0-9a-f]+$")~=nil
  end
  local function fileSha256(path)
    local file=assert(io.open(path,"rb"),"immutable source cannot be opened")
    local body=file:read("*a");file:close()
    local digest=love.data.hash("sha256",body)
    if type(digest)=="userdata" and digest.getString then
      digest=digest:getString()
    end
    return love.data.encode("string","hex",digest):lower()
  end
  assert(os.getenv("KA_PACKAGE_GATE")=="1",
    "refusing a Johto setup outside the immutable package gate")
  assert(identity==expectedIdentity,
    "refusing non-orchestrated identity "..tostring(identity))
  assert(validSha(sourceSha) and validSha(gateSha),
    "immutable source/package receipt SHA is malformed")
  assert(not source:find("Application Support/pokemon-love2d/saves",1,true),
    "refusing the player's live save directory")
  assert(source==expectedSource,
    "refusing source outside the materialized immutable-input root")
  assert(fileSha256(source)==sourceSha,
    "orchestrator-pinned BLITZ source SHA drifted")

  local loaded
  if variant=="BLITZ" then
    loaded=assert(loadfile(source))()
    assert(type(loaded)=="table" and loaded.modData
        and loaded.modData.kanto_ascendant
        and loaded.modData.kanto_ascendant.johto_masters,
      "BLITZ source has no Johto migration bucket")
    local old=loaded.modData.kanto_ascendant.johto_masters
    assert(old.version==2 and old.clears==4 and old.gifts==4
        and old.passages and old.passages.silver.status=="locked"
        and old.passages.kris.status=="locked"
        and old.passages.gold.status=="locked",
      "BLITZ source no longer represents the reported missing-host save")
    assert(loaded.inventory and loaded.inventory.THUNDERBADGE
        and loaded.visited and loaded.visited.INDIGO_PLATEAU,
      "immutable BLITZ save no longer supports the legal post-credits FLY return")
  else
    local boot={}
    for key,value in pairs(game:bootConfig() or {}) do boot[key]=value end
    boot.version,boot.playerName,boot.rivalName=version,"FRESH","BLUE"
    loaded=SaveData.newGame(boot)
    assert(loaded.version==version and loaded.player
        and loaded.player.name=="FRESH" and loaded.money==3000
        and #(loaded.party or {})==0
        and not (loaded.flags and loaded.flags.EVENT_BEAT_CHAMPION_RIVAL)
        and #(loaded.hallOfFame or {})==0,
      "native Fresh skeleton already contains story/postgame progress")
    local bucket=loaded.modData and loaded.modData.kanto_ascendant
    assert(not (bucket and bucket.johto_masters),
      "native Fresh skeleton already contains Johto progression")
    loaded.meta=SaveData.buildMeta(assert(game.modStatus and game.modStatus.loaded,
      "active Fresh package closure missing"),loaded.meta)
    loaded.flags=loaded.flags or {}
    loaded.flags.EVENT_GOT_STARTER=true
    loaded.flags.EVENT_GOT_POKEDEX=true
    loaded.flags.EVENT_BEAT_CHAMPION_RIVAL=true
    -- Explicit bounded-test prerequisite, not a claimed traversal receipt.
    -- The driver records initialHall and later proves the next row only by
    -- physically clearing Lorelei, Bruno, Agatha, Lance and the Champion.
    loaded.hallOfFame={{{species="CHARIZARD",level=80}}}
    loaded.inventory=loaded.inventory or {}
    loaded.inventory.THUNDERBADGE=1
    loaded.visited=loaded.visited or {}
    loaded.visited.INDIGO_PLATEAU=true
  end
  loaded.qaJohtoConnectedOrigin={
    version=1,variant=variant,
    kind=variant=="FRESH" and "native-save-new-game"
      or "immutable-blitz-migration",
    sourceSha256=sourceSha,packageGateReceiptSha256=gateSha,
  }
  local slot="slotjohto65connected_"..variant:lower()
  assert(SaveData.setActiveSlot(version,slot)==slot)
  -- SaveData.save persists the live option table too; reload it after the
  -- slot API has registered the isolated slot so that write cannot replace
  -- the slot registry with this boot's pre-registration options snapshot.
  loaded.options=SaveData.loadOptions()
  loaded.options.textSpeed=1

  -- A legal high-level Mewtwo party makes the deterministic menu driver
  -- repeatable.  First battle starts each member at 1 HP and selects the
  -- legal BARRIER slot for an actual loss; passage-local retry healing then
  -- lets the same party select its strongest legal coverage move on the
  -- real rematch.
  loaded.party={}
  for index=1,6 do
    -- Five Mewtwo carry the connected-arena retries.  The final Dragonite
    -- keeps a legal FLY field move so the same physical run can return from
    -- the post-credits Pallet landing to Indigo and observe the respawned
    -- host; no QA teleport or forged Hall receipt is needed.
    local species=index==6 and "DRAGONITE" or "MEWTWO"
    local mon=Pokemon.new(game.data,species,100,function()return 15 end)
    mon.dvs={hp=15,attack=15,defense=15,speed=15,special=15}
    mon.statExp={hp=65535,attack=65535,defense=65535,speed=65535,special=65535}
    mon.stats=Stats.calc(game.data.pokemon[species],100,mon.dvs,mon.statExp,mon)
    mon.moves=index==6 and {
      {id="AGILITY",pp=30},{id="ICE_BEAM",pp=10},
      {id="FLY",pp=15},{id="THUNDERBOLT",pp=15},
    } or {
      {id="BARRIER",pp=30},{id="PSYCHIC_M",pp=20},
      {id="THUNDERBOLT",pp=15},{id="BLIZZARD",pp=5},
    }
    mon.hp=1
    loaded.party[#loaded.party+1]=mon
  end
  loaded.player.map="INDIGO_PLATEAU_LOBBY"
  loaded.player.x,loaded.player.y,loaded.player.facing=9,7,"down"
  loaded.lastHeal={map="INDIGO_PLATEAU_LOBBY",x=9,y=7,
    outdoor={id="INDIGO_PLATEAU",x=9,y=5}}
  -- LAST_MAP must point at the real outdoor door.  Pointing it at the lobby
  -- itself would make the authored Gate Hall return warp recursively reload
  -- an interior cell and would not prove the physical League route.
  loaded.lastOutdoor={id="INDIGO_PLATEAU",x=9,y=5}
  -- Target the registered isolated slot explicitly.  At the title screen a
  -- boot session can still hold the prior world's version field, so the
  -- generic active-save writer is not a sufficient proof that this is the
  -- slot CONTINUE will consume.  writeSlot is the public SaveData API used
  -- by launcher import/export and preserves the atomic tmp/backup protocol.
  loaded.version=version
  assert(SaveData.writeSlot(version,slot,loaded),
    "could not persist isolated QA prerequisite save")
  local saved=assert(SaveData.load())
  assert(saved.player and saved.player.map=="INDIGO_PLATEAU_LOBBY",
    "isolated prerequisite slot did not retain the documented Indigo start")
  assert(saved.lastOutdoor and saved.lastOutdoor.id=="INDIGO_PLATEAU",
    "isolated prerequisite slot lost the real outdoor LAST_MAP return")
  local origin=assert(saved.qaJohtoConnectedOrigin,
    "isolated prerequisite slot lost its QA origin receipt")
  assert(origin.variant==variant and origin.sourceSha256==sourceSha
      and origin.packageGateReceiptSha256==gateSha,
    "isolated prerequisite slot changed its pinned origin receipt")
  local preserved=saved.modData and saved.modData.kanto_ascendant
    and saved.modData.kanto_ascendant.johto_masters
  if variant=="BLITZ" then
    assert(preserved.version==2 and preserved.clears==4
        and preserved.passages.gold.status=="locked",
      "setup itself migrated or fabricated BLITZ Johto progression")
  else
    assert(preserved==nil,
      "Fresh setup fabricated Johto progression before package reload")
  end
  U.log(("JOHTO CONNECTED SETUP PASS variant=%s renderer=%s origin=%s")
    :format(variant,renderer,origin.kind))
  love.event.quit(0)
end
