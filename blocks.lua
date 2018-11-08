--http://localhost:4000/blocks.lua

local Vec2 = require("lib/vec2")
function vec2(x, y) 
    return Vec2:new{x=x or 0, y=y or 0};
end

local Array = require("lib/array")

State = {}
Assets = {}
local PIXEL = 1/200

Class = {}

function Class:new(o)
    o = o or {};
    
    setmetatable(o, self);
    self.__index = self;
    
    if (o.init) then
        o:init();
    end
    
    return o;
end

Grid = Class:new();

BlockType = {
    
    Blue = {
        color = {0, 0.2, 1.0, 1.0} 
    },
    
    
    Red = {
        color = {1, 0, 0, 1}
    }

}

function Grid:init()
    self.numCols = 11;
    self.numRows = 0;
    self.yOffset = 0;
    self.blocks = {};
    self.config = {
        blockConfigs = {BlockType.Blue, BlockType.Red},
        maxRows = 15
    }
    
    self.totalTime = 0;
    
    for r = 1, self.config.maxRows do
        self:addRow();
    end
    
    for r = 1, 4 do
        self:recycle();
    end
    
    self:dropOrphans();
end


function Grid:draw(state)
    local gfx = state.gfx;
    local clr = love.graphics.setColor;
    
    love.graphics.setLineWidth(state.unit);
    love.graphics.setColor(0.0, 0.8, 1.0, 1.0);
    
    
    gfx.rect("line", 
        gfx.tileOffset(1), gfx.tileOffset(1), 
        gfx.tileSize(self.numCols), gfx.tileSize(self.config.maxRows)
    );

    for r = 1, self.numRows do 
    for c = 1, self.numCols do
        
        local blk = self.blocks[r][c];
        clr(blk.config.color);
        
        if (blk.status == 1) then
            gfx.drawTile(c, r);
        elseif (blk.shrink) then
            gfx.drawTile(c, r, math.min(1, blk.shrink / 10));
            blk.shrink = blk.shrink - state.dt * 50.0;
            if (blk.shrink < 0) then
                blk.shrink = nil;
            end
        end
        
    end 
    end
    
end

function Grid:sampleBlockConfigs()
    return self.config.blockConfigs[math.random(#self.config.blockConfigs)];
end

function Grid:makeRandomBlock()
    return {
        config = self:sampleBlockConfigs(),
        status = 1
    }
end

function Grid:addRow() 
    self.numRows = self.numRows + 1;
    self.blocks[self.numRows] = {}
    for c = 1, self.numCols do
        self.blocks[self.numRows][c] = self:makeRandomBlock(); 
        self.blocks[self.numRows][c].status = 0;
    end
end

function Grid:projectileTouchesBlock(proj, r, c)
    
    local pc, pr = proj.position.x, proj.position.y
    
    if (self.blocks[r] and self.blocks[r][c]) then
        local blk = self.blocks[r][c];
        
        if (blk.status == 1) then    
            if (math.abs(r - pr) < 0.75 and math.abs(c - pc) < 0.75) then
                return true;
            end
           
        end
    end

    return false;
    
end

function Grid:triggerBlock(br, bc)
    local config = self.blocks[br][bc].config;
    local toCheck = Array:new{};
    
    Assets.sounds.explode:play();
    
    toCheck:push({br, bc, 0});
    
    while(toCheck[1] ~= nil) do
        
        local current = toCheck:pop();
        local r,c = current[1], current[2];
        local dist = current[3];
        
        if (self.blocks[r] and self.blocks[r][c]) then
            blk = self.blocks[r][c];
            if (blk.status == 1 and blk.config == config) then
                blk.status = 0;
                blk.shrink = 10 + dist;
                
                toCheck:push{r-1, c, dist+1};
                toCheck:push{r+1, c, dist+1};
                toCheck:push{r, c+1, dist+1};
                toCheck:push{r, c-1, dist+1};
            
            end        
        end
    
    end
end

function Grid:insertProjectile(proj)

    local pc, pr = math.floor(proj.position.x + 0.5), math.floor(proj.position.y + 0.5);
    
    local bc , br, bd = -1, -1, 1000
    
    
    for c = pc - 1, pc + 1 do
    for r = pr - 1, pr + 1 do
    
        if (self.blocks[r] and self.blocks[r][c]) then
            local blk = self.blocks[r][c];
            if (blk.status == 0 and blk.canBeFilled) then  
                local d = math.abs(pc - c) + math.abs(pr - r);
                
                if (d < bd) then
                    bd = d;
                    bc, br = c, r;
                end
            end
        end
    
    end end
    
    self.blocks[br][bc].status = 1;
    self.blocks[br][bc].shrink = nil;
    self.blocks[br][bc].config = proj.config;    
    
    Assets.sounds.attach:play();
end

function Grid:considerProjectile(proj)
  
    if(proj.position.y < 0) then
        --todo
        return true;
    end
  
    local pc, pr = math.floor(proj.position.x + 0.5), math.floor(proj.position.y + 0.5);
   
    for c = pc - 1, pc + 1 do for r = pr-1, pr do
        if (self:projectileTouchesBlock(proj, r, c)) then
            
            --self.blocks[pr+1][pc].status = 1;
            if (proj.isBomb) then
                self:triggerBlock(r,c);
            else
                self:insertProjectile(proj);
            end
            
            self:dropOrphans();
            --self:recycle();
            
            return true
            
        end
    end end
   
  
    if (proj.position.x < 1) then
        proj.direction.x = -proj.direction.x;
        Assets.sounds.bounce:play();
    end
  
    if (proj.position.x > self.numCols) then
        proj.direction.x = -proj.direction.x;
        Assets.sounds.bounce:play();
    end
  
    return false;

end

function Grid:recycle()
    local tmpRow = self.blocks[self.numRows];
        
    for c = 1, self.numCols do
        tmpRow[c] = self:makeRandomBlock(); 
    end
    
    table.remove(self.blocks, self.numRows);
    table.insert(self.blocks, 1, tmpRow);
end

function Grid:eachBlock(fn)
    for r = 1, self.numRows do for c = 1, self.numCols do
        fn(self.blocks[r][c])
    end end
end

function Grid:eachBlockInRow(r, fn)
    for c = 1, self.numCols do
        fn(self.blocks[r][c])
    end
end

function Grid:dropOrphans()
    
    local toCheck = Array:new{};
    
    self:eachBlock(function(block)
        block.checked = false;
        block.canBeFilled = false;
    end);
    
    for i = 1, self.numCols do
        toCheck:push({1, i});
    end
    
    while(toCheck[1] ~= nil) do
        
        local current = toCheck:pop();
        local r,c = current[1], current[2];
        
        if (self.blocks[r] and self.blocks[r][c]) then
            blk = self.blocks[r][c];
            if (blk.status == 1 and not blk.checked) then
            
                blk.checked = true;
                
                toCheck:push{r-1, c};
                toCheck:push{r+1, c};
                toCheck:push{r, c+1};
                toCheck:push{r, c-1};
            
            elseif (blk.status == 0 and not blk.checked) then
                blk.canBeFilled = true;
            end
        end
    
    end
    
    self:eachBlock(function(block)
        if (not block.checked and block.status == 1) then
            block.status = 0;
            block.shrink = 10;
        end
    end);

end

function Grid:clear()
  
  self.totalTime = 0;
  
  self:eachBlock(function(block)
    
    block.status = 0;
    
  end);
  
  self:dropOrphans();
  
end

function Grid:update(state)
    
    
    local difficulty = math.floor(self.totalTime) / 10.0;
    
    self.totalTime = self.totalTime + state.dt;
    
    self.yOffset = self.yOffset + state.dt * (0.2 + (difficulty * 0.05));
    
    if (self.yOffset > 1.0) then
        
        local didLose = false;
        
        self:eachBlockInRow(self.numRows, function(block)
          if (block.status == 1) then
            didLose = true;
          end
        end);
        
        if (didLose) then
          print("clear");
          self:clear();
        end
        
        
        self:recycle();
        self.yOffset = 0.0;
    end

end

Projectile = Class:new();

function Projectile:update(state) 
    
    self.position:addScaled(self.direction, state.dt * 15);
    
end

function Projectile:draw(state)
    gfx = state.gfx;
    
    if (self.isBomb) then
        love.graphics.setColor(1, 1, 1, 1);
    else
        love.graphics.setColor(self.config.color);
    end
    
    gfx.drawTile(self.position.x, self.position.y);

end


Launcher = Class:new();

function Launcher:init()
    
    self.projectiles = {};
    self.position = vec2(self.grid.numCols / 2 + 0.5, self.grid.config.maxRows);
    self.projectileUUID = 1;
    
    self.nextProjectile = self:createProjectile();
    self.nextProjectile.position:addY(1);
    self.projectileOnDeck = self:createProjectile();
end

function Launcher:createProjectile()
    
    local projectile = Projectile:new({
        position = vec2(self.position.x, self.position.y + 2)
    });
    
    if (math.random() < 0.2) then
        projectile.isBomb = true;
    else
        projectile.config = self.grid:sampleBlockConfigs();
    end
    
    return projectile;
    
end

function Launcher:fire(x, y) 


    Assets.sounds.zap:play();
    
    local projectile = self.nextProjectile;
    
    projectile.direction = vec2(x - self.position.x, y - self.position.y);  
    projectile.direction.y = math.min(projectile.direction.y, -0.5);
    
    projectile.position = vec2(self.position.x, self.position.y);    
    projectile.direction:normalize();
    projectile.uuid = self.projectileUUID;

    
    self.projectiles[self.projectileUUID] = projectile;
    self.projectileUUID = self.projectileUUID + 1;
    
    self.nextProjectile = self.projectileOnDeck;
    self.nextProjectile.position:set(self.position.x, self.position.y+1);
    self.projectileOnDeck = self:createProjectile();
    
end

function Launcher:eachProjectile(fn)

    for uuid, proj in pairs(self.projectiles) do
        if proj then
            fn(proj);
        end
    end
    
end

function Launcher:draw(state)
    
    self:eachProjectile(function(proj) proj:draw(state) end);
    
    self.nextProjectile:draw(state);
    self.projectileOnDeck:draw(state);

end

function Launcher:update(state)

    self:eachProjectile(function(proj) 
        proj:update(state)

        if self.grid:considerProjectile(proj) then
            --table.remove(self.projectiles, proj.uuid)
            self.projectiles[proj.uuid] = nil;
        end
        
    end);

end

function resize(w, h)
    State.width = w;
    State.height = h;
    State.unit = math.min(w * PIXEL, h * PIXEL)
end


function love.resize(w, h)
    resize(w,h);
end

function love.load()
    local w, h = love.graphics.getDimensions();
    resize(w,h);
    
    Assets.sounds = {
      zap = love.audio.newSource("sounds/laser.wav", "static"),
      explode = love.audio.newSource("sounds/explosion.wav", "static");
      bounce = love.audio.newSource("sounds/bounce.wav", "static"),
      attach = love.audio.newSource("sounds/attach.wav", "static")
    }  
    
    State.grid = Grid:new();
    State.launcher = Launcher:new{grid = State.grid};
   
end

function love.update(dt)
    State.dt = dt;
    State.launcher:update(State);
    State.grid:update(State);
end


State.gfx = {

    pts = function(s)
        return State.unit * (s);
    end,
    
    tileSize = function(s)
        return State.gfx.pts(s * 10)
    end,
    
    tileOffset = function(s)
        return State.gfx.tileSize(s) + State.gfx.pts(1);
    end,
    
    drawTile = function(x, y, shrink)
        if (shrink == nil) then
            shrink = 1;
        end
    
        return State.gfx.rect("fill", 
            State.gfx.tileOffset(x + ((1-shrink) * 0.5)), 
            State.gfx.tileOffset(y + ((1-shrink) * 0.5)),
            State.gfx.tileSize(1 * shrink),
            State.gfx.tileSize(1 * shrink));
    end,
    
    pixToOffset = function(x, y)
        return (x - State.gfx.pts(1)) / State.gfx.tileSize(1), (y - State.gfx.pts(1)) / State.gfx.tileSize(1);
    end,
    
    rect = love.graphics.rectangle
}

function drawUI(state)
    
    love.graphics.setColor(1,1,1,1);
    
    love.graphics.print("Score: 000", 0, 0, 0, 1, 1);
    
end

function love.draw()
  drawUI(State);
  State.grid:draw(State);
  State.launcher:draw(State);
end

function love.mousepressed( x, y, button, istouch, presses )
    
    local tx, ty = State.gfx.pixToOffset(x, y);
    
    State.launcher:fire(tx - 0.5, ty - 0.5);

end

function love.keypressed(k)
    --State.keyboard[k] = 1;
    State.grid:addRow();

end

function love.keyreleased(k)
    --State.keyboard[k] = 0;
end