mjpeg-player-for-LOVE-engine
============================

This is a mjpeg player for LÖVE engine (http://love2d.org/). 

How to use
------------

<pre>require "mjpegplayer"

function love.load()
  mplayer = VideoPlayer.create("path_to_your_movie_folder")
  mplayer:start()
end

function love.update(dt)
  mplayer:play()
end

function love.draw()
  mplayer:draw()
end</pre>


Files:
---------

mjpegplayer.lua - single-threaded version.

mjpegplayermt.lua - multi-threaded version.

mjpegdecoder.lua - decoder thread for mjpegplayermt.lua.
