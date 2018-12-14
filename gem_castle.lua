local foo = require

USE_CASTLE_CONFIG = true
if CASTLE_SERVER then
  foo('blocks_server.lua')
else
  foo('blocks.lua')
end