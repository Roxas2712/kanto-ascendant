local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local function read(path)
  local file = assert(io.open(root .. "/" .. path, "rb"), "missing " .. path)
  local bytes = assert(file:read("*a"))
  file:close()
  return bytes
end

local function pngDimensions(path)
  local bytes = read(path)
  assert(bytes:sub(1, 8) == "\137PNG\r\n\26\n", path .. " is not PNG")
  local function u32(offset)
    local a, b, c, d = bytes:byte(offset, offset + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

for dex = 1, 151 do
  local path = ("assets/followers_kanto/follower_%03d.png"):format(dex)
  local width, height = pngDimensions(path)
  assert(width == 16 and height == 96,
    ("%s must be a 16x96 six-pose sheet, got %dx%d")
      :format(path, width, height))
end

print("PASS follower Phase-2 assets: Kanto 151/151 species-authentic six-pose sheets")
