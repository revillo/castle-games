--file://C:\castle\space\main2.lua
--http://localhost:4000/main2.lua

local GAME_WIDTH = 600
local GAME_HEIGHT = 600
local PIXEL = 1/200
local UP = {0,1,0}
local LEFT = {1, 0, 0}

function enum(v)
    local r = {};
    
    for k,v in pairs(v) do
        r[v] = v;
    end
    
    return r;
end


GameModes = enum({"FLYING", "ON_PLANET"});

local Vec2 = require("lib/vec2")
function vec2(x, y) 
    return Vec2:new{x=x or 0, y=y or 0};
end

local Mat3 = require("lib/mat3")

local Safe = require("lib/safe")

Node = {}
UUID = 0;

function Node:new(o)
    o = o or {};

    UUID = UUID + 1;
    o.uuid = UUID;
    o.children = {};
    
    setmetatable(o, self);
    self.__index = self;
    
    return o;
end

function Node:setParent(parent)
    --todo unparent current
    
    --parent.children[self.uuid] = self;
    --self.parent = parent;
    
end

function Node:update(args) 
    self:updateSelf(args);

    for k,v in pairs(self.children) do
        v.update(args);
    end
end

function Node:draw(args)
    self:drawSelf(args);
    --print (self.a)
    
    for k,v in pairs(self.children) do
        v:draw(args);
    end
end


Planet = Node:new()

function Planet:drawSelf(state)
    love.graphics.setShader(state.shaders.planet);
    
    local x = state.center.x - state.player.position.x;
    local y = state.center.y - state.player.position.y;
    local radius = state.unit * 50;
    
    state.shaders.planet:send("rotation", self.rotation);
    
    love.graphics.draw(state.meshes.quad, 
        x, 
        y
    );
    
    love.graphics.setShader();
end


function Planet:rotate(dir)
  

end

function Planet:foo()
   print(self.a);
end


Enemy = Node:new();

FlyControls = Node:new();

function FlyControls:move(dir) 
    dir:mult(100);
    self.player.position:add(dir)
end
function FlyControls:handleKeypress(k)

    self.keyHandlers = self.keyHandlers or {
        
        t = function() 
            self.player.controls = self.player.groundControls
        end
    }
    
    Safe.call(self.keyHandlers, k);

end


GroundControls = Node:new();

function GroundControls:move(dir)
    State.planet.rotation:rotateAxisAngle(UP, -dir.x);
    State.planet.rotation:rotateAxisAngle(LEFT, dir.y);
    State.planet.rotation:orthonormalize();
end
function GroundControls:handleKeypress(k)

    self.keyHandlers = self.keyHandlers or {
        
        t = function() 
            self.player.controls = self.player.flyControls;
        end
    }
    
    Safe.call(self.keyHandlers, k);
    
end


Player = Node:new();

function Player:init() 
    self.health = 100;
    self.maxHealth = 100;
    self.flyControls = FlyControls:new{player = self};
    self.groundControls = GroundControls:new{player = self};
    
    self.controls = self.flyControls;
    self.position = vec2();
    self.velocity = vec2();
    self.isActive = true;
end

function Player:drawSelf(state)

    love.graphics.setColor(1.0, 0.0, 0.0, 1.0)
    
    love.graphics.circle("fill", 
        state.center.x, 
        state.center.y,
        state.unit * 5, 32
    );

end


function Player:updateSelf(state) 
    
    if (not self.isActive) then return end;

    local dir = vec2();
    local keys = state.keyboard;
    
    dir:addY((keys.s or 0) - (keys.w or 0));
    dir:addX((keys.d or 0) - (keys.a or 0));
    dir:mult(state.dt);
    self.controls:move(dir);
    
end

function Player:handleKeypress(k)
    if (not self.isActive) then return end;

    self.controls:handleKeypress(k);
end

State = {
    width = GAME_WIDTH,
    height = GAME_HEIGHT,
    center = vec2(GAME_WIDTH / 2, GAME_HEIGHT / 2),
    unit = GAME_WIDTH * PIXEL,
    keyboard = {},
    shaders = {},
    meshes = {},
    
}

function love.resize(w, h)
    State.width = w;
    State.height = h;
    State.unit = math.min(w * PIXEL, h * PIXEL);
    State.center:set(w/2, h/2);
end

function love.load()
    State.player = Player:new();
    State.player:init();
    
    State.planet = Planet:new{
        rotation = Mat3:new()
    };      
    
    local shaders = require("shaders/shaders");
    
    State.shaders.planet = shaders.planetShader(love);
    State.meshes.quad = shaders.quadMesh(love);
end

function love.update(dt)
    State.dt = dt;
    State.player:update(State);
end

function drawUI(state)

    local pix = function(s)
        return state.unit * (s or 0);
    end
   
    local rect = love.graphics.rectangle;
    
    local outlineBox = function(x,y,w,h, p)
        rect("line", pix(x), pix(y), pix(w), pix(h));
        rect("fill", pix(x), pix(y), pix(w * p), pix(h));
    end

    love.graphics.setLineWidth(state.unit);
    love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
    outlineBox(1, 1, 50, 6, 0.3);
    love.graphics.setColor(0.9, 1.0, 0.65, 1.0);
    outlineBox(1, 8, 50, 6, 0.9);
    
end

function love.draw()
  State.planet:draw(State);
  State.player:draw(State);
  drawUI(State);
end

function love.keypressed(k)
    State.keyboard[k] = 1;
    State.player:handleKeypress(k);
end

function love.keyreleased(k)
    State.keyboard[k] = 0;
end
