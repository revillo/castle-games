--http://localhost:4000/blocks_server.lua

local cs = require("https://raw.githubusercontent.com/expo/share.lua/master/cs.lua")
local server = cs.server


server.enabled = true
server.start('22122') -- Port of server


local share = server.share
local homes = server.homes

clients = {};

function server.connect(id) -- Called on connect from client with `id`


    print("client "..id.." connected")
    clients[id] = {};
    share.players[id] = {};
    
end

function server.disconnect(id) -- Called on disconnect from client with `id`
    print("client "..id.." disconnected")

    clients[id] = nil;
    share.players[id] = nil;

end

function server.receive(id, ...) -- Called when client with `id` does `client.send(...)`
    
    
end


-- Server only gets `.load`, `.update`, `.quit` Love events (also `.lowmemory` and `.threaderror`
-- which are less commonly used)

function server.load()
    share.players = {}
end

function server.update(dt)
    for id, home in pairs(server.homes) do -- Combine mouse info from clients into share
        share.players[id] = home;
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