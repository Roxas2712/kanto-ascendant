-- Local, bounded diagnostics. Never persist URLs, receipt tickets or bodies.
local M={PATH="KASC-HD-DOWNLOAD-LOG.txt",PREVIOUS="KASC-HD-DOWNLOAD-LOG-VORHER.txt"}
local LIMIT,ROWS=32768,80
local ERRORS={
  ["Network unavailable in this engine"]="transport_unavailable",
  ["Network unavailable"]="network_unavailable",
  ["Network polling failed"]="poll_failed",
  ["Public download source not configured"]="source_not_configured",
  ["Response exceeds content limit"]="response_too_large",
  ["Invalid content catalog"]="invalid_catalog",
  ["Catalog downgrade rejected"]="catalog_downgrade",
  ["Manifest does not match catalog"]="manifest_mismatch",
  ["Package size mismatch"]="package_size_mismatch",
  ["Truncated chunk"]="truncated_chunk",
}
local function token(value)
  return tostring(value or "unknown"):gsub("[^%w_.%-]","_"):sub(1,80)
end
function M.error(reason)
  local raw=tostring(reason or "")
  local lower=raw:lower()
  local result={error_kind="transport_error"}
  result.http_code=tonumber(raw:match("HTTP (%d%d%d)"))
  result.curl_code=tonumber(raw:match("curl: %((%d+)%)"))
  if ERRORS[raw]then result.error_kind=ERRORS[raw]
  elseif raw:find("\137PNG",1,true)then result.error_kind="png_in_transport_error"
  elseif result.http_code then result.error_kind="http_error"
  elseif result.curl_code==28 or lower:find("timeout",1,true) or lower:find("timed out",1,true)then result.error_kind="timeout"
  elseif result.curl_code==6 or lower:find("resolve",1,true)then result.error_kind="dns"
  elseif result.curl_code==60 or lower:find("ssl",1,true) or lower:find("certificate",1,true)then result.error_kind="tls"
  elseif raw:match("^[a-z_]+$")then result.error_kind=token(raw)
  end
  return result
end
function M.new(d)
  local self={path=M.PATH,saved=false,failed=false,active=false}
  local cache=d.cache
  local rows,header={},""
  local clock=d.now or function()return os.time()end
  local function now()
    local ok,n=pcall(clock)
    return ok and type(n)=="number" and n==n and n~=math.huge and n~=-math.huge and n or 0
  end
  local started=0
  local function write(path,body)
    if not cache or type(cache.write)~="function"then return false end
    local ok,yes=pcall(cache.write,cache,path,body)
    return ok and yes==true
  end
  local function flush()
    local body=header..table.concat(rows,"\n").."\n"
    while #body>LIMIT and #rows>1 do table.remove(rows,1);body=header..table.concat(rows,"\n").."\n"end
    self.saved=write(M.PATH,body);self.failed=not self.saved
  end
  function self:begin(action,transport)
    -- Rotate on explicit attempts, never merely by starting/closing the game.
    if cache and type(cache.read)=="function"then
      local ok,old=pcall(cache.read,cache,M.PATH)
      if ok and type(old)=="string" and #old<=LIMIT and old:match("^KASC HD download log v1\n")then
        write(M.PREVIOUS,old)
      end
    end
    started=now();rows={};self.active=true
    local ok,utc=pcall(function()return os.date("!%Y-%m-%dT%H-%M-%SZ")end)
    header="KASC HD download log v1\nbuild=kasc-6.7.4-hd-download utc="..token(ok and utc or nil).."\nmod_version="..token(d.version)
      .." engine_version="..token(d.engineVersion).." platform="..token(d.platform)
      .." transport="..token(transport).."\n"
    self:event("begin",{action=action})
  end
  function self:event(event,fields)
    if not self.active then return end
    local line=string.format("t=%.3f event=%s",math.max(0,now()-started),token(event))
    local keys={"action","source","step","package","chunk","expected_bytes","received_bytes",
      "elapsed_ms","done_bytes","error_kind","http_code","curl_code","status"}
    for _,key in ipairs(keys)do
      local v=fields and fields[key]
      if v~=nil then line=line.." "..key.."="..token(v)end
    end
    rows[#rows+1]=line
    if #rows>ROWS then table.remove(rows,1)end
    flush()
  end
  return self
end
return M
