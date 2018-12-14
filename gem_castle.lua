USE_CASTLE_CONFIG = true
if CASTLE_SERVER then
  require('blocks_server.lua')
else
  require('blocks.lua')
end