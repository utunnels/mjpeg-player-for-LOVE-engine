-- A movie player for LÖVE engine 0.8.0, version 2
-- Coded by utunnels (utunnels@hotmail.com)

-- Example:
--[[

require "mplayer"

function love.load()
  mplayer = VideoPlayer.create("path_to_your_movie_folder")
  mplayer:start()
end

function love.update(dt)
  mplayer:play()
end

function love.draw()
  mplayer:draw()
end

]]--

--[[
Files in movie folder:

audio.ogg -- optional
video.mjpeg -- it should be a renamed avi file encoded using mjpeg, without audio
conf.lua -- optional, it is executed after the player is created
]]--


VideoPlayer = {}
VideoPlayer.__index = VideoPlayer

function VideoPlayer.create(vidPath)
  local self = {}
  setmetatable(self, VideoPlayer)
  self.vidPath = vidPath
  self.movieFps = 15
  local ok, mconf
  ok, mconf = pcall(love.filesystem.load, self.vidPath.."/conf.lua")
  if ok and mconf then
    mconf(self)
  end
  return self
end

function bytes_to_int(s)
  local b1,b2,b3,b4  = s:byte(1,4)
  local n = b1 + b2*256 + b3*65536 + b4*16777216
  n = (n > 2147483647) and (n - 4294967296) or n
  return n
end

--http://msdn.microsoft.com/en-us/library/windows/desktop/dd318189(v=vs.85).aspx
function VideoPlayer:parseAVI()
  local f = self.videoSource
  f:seek(0)
  while true do
    local b,s = f:read(4)
    if s~=4 then
      break
    elseif b=="avih" then
      local _,_=f:read(4) --skip size
      local n,_=f:read(4)
      self.movieFps = 1000000/bytes_to_int(n)
      local _,_=f:read(12) --skip size
      local l,_=f:read(4)
      self.totalFrames = bytes_to_int(l)
    elseif b=="movi" then
      f:seek(f:tell()-8)
      local n,_=f:read(4)
      local l = bytes_to_int(n)
      local st = f:tell()+8
      local ft = f:tell()+l+8
      self.frameTable = {}
      for i=1,self.totalFrames do
        f:seek(ft+16*(i-1)+8)
        local o,_=f:read(4)
        self.frameTable[i]=bytes_to_int(o)+st
      end
      break
    end
  end
end

function VideoPlayer:start()
  self.videoSource = love.filesystem.newFile(self.vidPath.."/video.mjpeg")
  self.videoSource:open("r")
  self:parseAVI()
  self.currentFrame = 0
  self.videoFrame = nil
  self.stopped = false
  local apath = self.vidPath.."/audio.ogg"
  if love.filesystem.exists(apath) then
    self.audioSource = love.audio.newSource(apath, "stream")
    self.audioSource:play()
  end
  self.movieStartTime = love.timer.getTime()

  self.loader = love.thread.newThread( "loader", "mjpegdecoder.lua")
  self.loader:start()
  self:request(1)
end

function VideoPlayer:stop()
  if self.audioSource then
    self.audioSource:stop()
    self.audioSource = nil
  end
  self.videoSource:close()
  self.stopped = true
  self.videoFrame = nil
  self.lastDecoded = nil
  if self.loader then
    self.loader:set("frame", "quit")
  end
  self.loader = nil
end

function VideoPlayer:cleanBuffer()
  if (not self.gcThreshold) or self.gcThreshold<collectgarbage("count") then
    collectgarbage("collect")
  end
end

function VideoPlayer.newPaddedImage(source)
    if not love.graphics.isSupported("npot") then
      local w, h = source:getWidth(), source:getHeight()
      
      -- Find closest power-of-two.
      local wp = math.pow(2, math.ceil(math.log(w)/math.log(2)))
      local hp = math.pow(2, math.ceil(math.log(h)/math.log(2)))
      
      -- Only pad if needed:
      if wp ~= w or hp ~= h then
          if not padded then
            padded = love.image.newImageData(wp, hp)
          end
          padded:paste(source, 0, 0)
          return love.graphics.newImage(padded)
      end
    end
    return love.graphics.newImage(source)
end

function VideoPlayer:updateVideoFrame(frm)
  if not self.videoFrame or not self.videoFrame.refresh then
    self.videoFrame = VideoPlayer.newPaddedImage(frm)
  else
    self.videoFrame:getData():paste(frm,0,0)
    self.videoFrame:refresh()
  end
end

function VideoPlayer:request(f)
  self.loader:set("frame", f)
  self.loader:set("file", self.videoSource)
  self.loader:set("pos", self.frameTable[f])
end

function VideoPlayer:play()
  if self.stopped then
    return
  end

  local mtime = 0
  if not self.audioSource or self.audioSource:isStopped() then
    mtime = love.timer.getTime() - self.movieStartTime
  else
    mtime = self.audioSource:tell("seconds")
  end
  local f = math.floor(mtime*self.movieFps)

  self:cleanBuffer()

  if f>self.currentFrame then
    if self.loader:get("working") then
      local frm = self.loader:demand("decoded")

      if frm then
        self:updateVideoFrame(frm)
        self.lastDecoded = frm
      end
    end
    
    self:request(f+2)
    self.currentFrame = f
  end
end

function VideoPlayer:draw(x, y, size)
  local frm = self.lastDecoded
  if frm and self.videoFrame then
    love.graphics.draw(self.videoFrame, x or 0, y or 0,0,size or love.graphics.getWidth()/frm:getWidth(), size or love.graphics.getHeight()/frm:getHeight())
    --love.graphics.draw(videoFrame,0,0)
    love.graphics.print(string.format("fps: %d", love.timer.getFPS()), 10, 10)
  end
end
