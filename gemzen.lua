local foo = require

USE_CASTLE_CONFIG = true
if CASTLE_SERVER then
  foo('blocks_server.lua')
else

if CASTLE_PREFETCH then
    CASTLE_PREFETCH({
        'lib/vec2.lua',
        'lib/queue.lua',
        'lib/ui.lua',
        'lib/sound.lua',
        'shaders/gem_shaders.lua',
        'lib/ui.lua',
        'lib/TextAnimator.lua',
        'share/cs.lua',
        'share/state.lua',
       'sounds/pop.mp3',
       'sounds/bomb2.mp3',
      'sounds/chip2.wav',
      'sounds/bounce.wav',
      'sounds/ping.wav',
      'sounds/drop_orphans.mp3',
      'sounds/fuse.ogg',
      'sounds/glass2.wav',
      'sounds/lose.wav',
      'sounds/win.wav',
     'sounds/music.mp3',
     'images/shard.png',
     'images/gypsum.png',
     'fonts/OpenSans-ExtraBold.ttf'
    })
end

  foo('blocks.lua')
end