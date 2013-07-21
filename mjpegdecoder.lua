require "love.filesystem"
require "love.image"

local d = love.thread.getThread()
local q = false

function decodeFrame(vfile, pos)
  if not pos or not vfile then
    return nil
  end
  vfile:seek(pos)
  return love.image.newImageData(vfile)
end

while not q do

	local f = d:get("frame")
	local v = d:get("file")
  local p = d:get("pos")

	if f ~= "quit" then
		if v and p then
      d:set("working", true)
      d:set("decoded", decodeFrame(v,p))
    end
	else
		q = true
	end

end
