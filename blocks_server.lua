--http://localhost:4000/blocks_server.lua
--castle://localhost:4000/blocks_server.lua

local cs = require("share/cs")
local array = require("lib/array");
local server = cs.server

if USE_CASTLE_CONFIG then
    server.useCastleConfig()
else
    server.enabled = true
    server.start('22122') -- Port of server
end

local share = server.share
local homes = server.homes

local playerCount = 0;
local waitQueue = array:new();

function startMatch()

    share.match = {
      round = 0,
      points = {}
    }
    
    for pid, v in pairs(share.players) do
      share.match.points[pid] = 0; 
    end
      
end

function winMatch(id) 
  
   startMatch();
  
   server.send('all', {
      win = id
    });
    
end

function maybeStartPlaying(id)
        
    if (playerCount >= 2) then
    
      waitQueue:push(id);
      
      server.send(id, {
        queue = 1
      });
    
      return;
    
    else
      
      playerCount = playerCount + 1;

      server.send(id, {
        ackstart = 1
      });
      
    end
    
    share.players[id] = {};
    
    if (playerCount == 2) then
      startMatch()
        
      server.send('all', {
        reset = 1
      });
    
    end

end

function server.connect(id) -- Called on connect from client with `id`
    print("client "..id.." connected");
    
end

function server.disconnect(id) -- Called on disconnect from client with `id`
    print("client "..id.." disconnected")
    
    --Was queued
    waitQueue:removeValue(id);
    
    
    --Was playing
    if (share.players[id]) then
       playerCount = playerCount - 1;
      share.players[id] = nil;
      share.match = nil;
      
        server.send('all', {
          disc = 1
        });
        
        
        --Dequeue waiting players
        if (waitQueue:first()) then
          maybeStartPlaying(waitQueue:first());
          waitQueue:shift();
        end
    end

end

function server.receive(id, msg) -- Called when client with `id` does `client.send(...)`
    
    if (msg.start) then
      maybeStartPlaying(id);
    end
    
    if (msg.lost_round and share.match) then
            
      share.match.round = share.match.round + 1
      
      for pid, v in pairs(share.match.points) do
        if (pid ~= id) then
          share.match.points[pid] = share.match.points[pid] + 1;
          if (share.match.points[pid] == 5) then
              winMatch(pid);
          else
            --Send lost round
              server.send('all', msg);
          end
        end
      end
    
    end
    
    
end


-- Server only gets `.load`, `.update`, `.quit` Love events (also `.lowmemory` and `.threaderror`
-- which are less commonly used)

function server.load()
    share.players = {};
    share.match = nil;
end

function server.update(dt)
    for id, home in pairs(server.homes) do -- Combine mouse info from clients into share
    
        if (share.players and share.players[id] ~= nil) then
          share.players[id] = home;
        end
    end
    
    --[[
    for id, home in pairs(rooms[roomIndex].players) do
        
        server.send(id, {
            id = id,
            room = room
        });
    end
    ]]
end 