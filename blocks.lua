--http://localhost:4000/blocks.lua

local VOLUME = 0.5
local PNG_SIZE = 32

local Vec2 = require("lib/vec2")
function vec2(x, y) 
    return Vec2:new{x=x or 0, y=y or 0};
end

local Array = require("lib/array")
local Queue = require("lib/queue")

State = {}
Assets = {}
local PIXEL = 1/200

Class = {}

local LEVELS = {
    --colors  --columns --scrollSpeed --scoreNeeded
    {  2,        5,        0.15,           1000 },
    {  2,        6,        0.16,           2000 },
    {  2,        7,        0.17,          4000 },
    {  2,        8,        0.19,          7000 },
    {  2,        9,        0.22,         10000 },
    {  2,        10,       0.24,         15000 }, 
    {  3,        10,       0.2,          1000000 }
}


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
        color = {0, 0.5, 1.0, 1.0} 
    },
    
    Red = {
        color = {1, 0, 0, 1}
    },
    
    Yellow = {
        color = {1, 1, 0, 1}
    },
    
    Green = {
        color = {0, 0.75, 0, 1}
    }

}

function Grid:nextLevel()
    
    self:setLevel( (self.levelNumber or 0) + 1 );

end

function Grid:setLevel(n)

    local level = LEVELS[n];
    local config = {};
    
    self.levelNumber = n;
    
    config.maxRows = 15;
    config.bombChance = 0.25;
    
    if (level[1] == 2) then
        config.blockConfigs = {BlockType.Blue, BlockType.Red};
    elseif(level[1] == 3) then
        config.blockConfigs = {BlockType.Blue, BlockType.Red, BlockType.Green};
    elseif(level[1] == 4) then
        config.blockConfigs = {BlockType.Blue, BlockType.Red, BlockType.Green, BlockType.Yellow};
    end
    
    config.scrollSpeed = level[3];
    config.scoreNeeded = level[4];
    
    self.numCols = level[2];
    self.blocks = {};
        
    self.config = config;
    self.blocks = {};
    self.gems = {};
    self.yOffset = 0;
    self.numRows = 0;

    for r = 1, self.config.maxRows do
        self:addRow();
    end
    
    for r = 1, 2 do
        self:recycle();
    end
    
    self:dropOrphans();
end

function Grid:init()
    self.numCols = 8;
    self.numRows = 0;
    self.yOffset = 0;
    self.blocks = {};
    self.gems = {};
    self.gemID = 0;
    
    self.config = {
        blockConfigs = {BlockType.Blue, BlockType.Red},
        maxRows = 15,
        bombChance = 0.25
    }
    
    self.totalTime = 0;
    self:setLevel(1);

end

function Grid:draw(state)
    local gfx = state.gfx;
    local clr = love.graphics.setColor;
    
    love.graphics.setLineWidth(state.unit);
    love.graphics.setColor(0.1, 0.1, 0.1, 1.0);

    
    gfx.rect("fill", 
        gfx.tileOffset(1), gfx.tileOffset(2), 
        gfx.tileSize(self.numCols), gfx.tileSize(self.config.maxRows - 1)
    );
    
    
    --draw blocks
    self:eachBlock(function(blk,r , c)
        
        clr(blk.config.color);
        
        if (blk.gem) then
        
        elseif (blk.status == 1) then
            
            gfx.drawTile(c, r + self.yOffset);
                        
        elseif (blk.shrink) then
        
            gfx.drawTile(c, r + self.yOffset, math.min(1, blk.shrink / 10));
            blk.shrink = blk.shrink - state.dt * 100.0;
            if (blk.shrink < 0) then
                blk.shrink = nil;
            end
        end   
    end);
    
    --draw gems
    for k,gem in pairs(self.gems) do
        if (gem) then
    
            gfx.drawGem(gem, self.yOffset);
            
            if (gem.shrink ~= nil) then
                gem.shrink = gem.shrink - state.dt * 100.0;
                if (gem.shrink < 0) then
                    self.gems[gem.id] = nil;
                end
            end
        end
    end
    
    love.graphics.setColor(0.0, 0.8, 1.0, 1.0);

    
    gfx.rect("line", 
        gfx.tileOffset(1), gfx.tileOffset(2), 
        gfx.tileSize(self.numCols), gfx.tileSize(self.config.maxRows - 1)
    );
    
    love.graphics.setColor(0.0, 0.0, 0.0, 1.0);
    gfx.rect("fill", 
        gfx.tileOffset(0.5), gfx.tileOffset(1), 
        gfx.tileSize(self.numCols + 1), gfx.tileSize(1)
    );
    
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



function Grid:triggerBlock(br, bc)
    local config = self.blocks[br][bc].config;
    local toCheck = Queue:new{};
    
    Assets.sounds.explode:play();
    
    toCheck:pushright({br, bc, 0});
    
    while(not toCheck:isEmpty()) do
        
        local current = toCheck:popleft();
        local r,c = current[1], current[2];
        local dist = current[3];
        
        if (self.blocks[r] and self.blocks[r][c]) then
            blk = self.blocks[r][c];
            if (blk.status == 1 and blk.config == config) then
            
                blk.status = 0;
                
                if (blk.gem) then
                
                    if (blk.gem.shrink == nil) then
                        blk.gem.shrink = blk.gem.shrink or (10 + dist * 10);
                        local score = self:gemScore(blk.gem.w, blk.gem.h);
                        State.score = State.score + score;
                    end
                    
                    
                else
                    State.score = State.score + 10;
                    blk.shrink = 10 + dist * 10;
                end
                
                toCheck:pushright{r-1, c, dist+1};
                toCheck:pushright{r+1, c, dist+1};
                toCheck:pushright{r, c+1, dist+1};
                toCheck:pushright{r, c-1, dist+1};
            
            end        
        end
    
    end
end

function Grid:gemScore(w, h)
    
    if (w <= 1 or h <= 1) then
        return 0;
    end
    
    return math.min(w,h) * 100 + math.max(w,h);
    
end

function Grid:eachBlockInGem(gem, fn)

    for r = gem.r, (gem.r+gem.h-1) do for c = gem.c, gem.c+gem.w-1 do
        fn(self.blocks[r][c]);
    end end

end

function Grid:constructLargestGem()
    for r = 1, self.numRows do
        
        local count = 0;
        local cfg = nil;
        
        for c = self.numCols, 1, -1 do 
            local blk = self.blocks[r][c];
            if (blk.status == 1 and (blk.gem == nil)) then
            
                if (cfg == nil) then
                    cfg = blk.config;
                end
            
                if (blk.config == cfg) then
                    count = count + 1;
                else
                    count = 1;
                    cfg = blk.config;
                end
                
                blk.largestWidth = count;
            else
                count = 0;
                cfg = nil;
                blk.largestWidth = 0;
            end
        end
    end
    
    local bestGem = {
        w = 0,
        h = 0,
        r = -1,
        c = -1,
        config = nil
    }

    self:eachBlock(function(blk, br, bc)
        
        if (blk.status == 0 or blk.largestWidth < 1) then
            return;
        end
       
        local cw, ch = blk.largestWidth, 1;
 
        for r = br + 1, self.numRows do
            
            local blk2 = self.blocks[r][bc];
            
            if (blk2.status == 1 and blk2.config == blk.config and blk2.largestWidth > 1) then
        
                cw, ch = math.min(cw, blk2.largestWidth), ch + 1;
                                
                if (self:gemScore(bestGem.w, bestGem.h) < self:gemScore(cw, ch)) then
                    bestGem.w, bestGem.h = cw, ch;
                    bestGem.r, bestGem.c = br, bc;
                    bestGem.config = blk.config;
                end
                
            else
                
                break;
            
            end
        end
    end);
    
    if (bestGem.config == nil) then
        return false;
    else
        self.gemID = self.gemID + 1;
        bestGem.id = self.gemID;
        self.gems[self.gemID] = bestGem;
    end
    
    self:eachBlockInGem(bestGem, function(block)
        block.gem = bestGem;
    end);

    return true;
    
end

function Grid:eachGem(fn)
    for k, gem in pairs(self.gems) do
        if (gem ~= nil) then
            fn(gem)
        end
    end
end

function Grid:constructGems()
  
    self:eachBlock(function(blk)
        blk.gem = nil;
        blk.largestWidth = 0;
    end);
    
    self:eachGem(function(gem) 

        if (gem.shrink == nil) then
            self.gems[gem.id] = nil;
        end
        
        --self.gems[gem.id] = nil;
    end);
    
    local stopper = 0;
  
    while(self:constructLargestGem() and stopper < 20) do
        stopper = stopper + 1;
    end;
    
    if (stopper > 20) then
        print ("sadness")
    end
    
    --self:constructLargestGem();
    
end

function Grid:insertProjectile(proj)

    local pc, pr = math.floor(proj.position.x + 0.5), math.floor(proj.position.y + 0.5 - self.yOffset);
    
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

function Grid:projectileTouchesBlock(proj, r, c)
    
    local pc, pr = proj.position.x, proj.position.y - self.yOffset;
    
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

function Grid:considerProjectile(proj)
  
    if(proj.position.y < 0) then
        --todo
        return true;
    end
  
    local pc, pr = math.floor(proj.position.x + 0.5), math.floor(proj.position.y + 0.5 - self.yOffset);
   
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
        proj.position.x = 1 + (1 - proj.position.x)
        proj.direction.x = -proj.direction.x;
        Assets.sounds.bounce:play();
    end
  
    if (proj.position.x > self.numCols) then
        proj.position.x = self.numCols - (proj.position.x - self.numCols)
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
        fn(self.blocks[r][c], r, c)
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
    
    
    self:constructGems();

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
    difficulty = difficulty ^ 0.5;
    
    self.totalTime = self.totalTime + state.dt;
    
    self.yOffset = self.yOffset + state.dt * self.config.scrollSpeed;
    
    if (self.yOffset > 1.0) then
        
        local didLose = false;
        
        self:eachBlockInRow(self.numRows, function(block)
          if (block.status == 1) then
            didLose = true;
          end
        end);
        
        if (didLose) then
          self:clear();
        end
        
        
        self:recycle();
        self:dropOrphans();
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
    
    self:reset();
    
end

function Launcher:reset()

    self.projectiles = {};
    self.position = vec2(self.grid.numCols / 2 + 0.5, self.grid.config.maxRows);
    self.projectileUUID = 1;
    
    self.nextProjectile = self:createProjectile();
    self.nextProjectile.position:addY(-1);
    self.projectileOnDeck = self:createProjectile();
    
end

function Launcher:createProjectile()
    
    local projectile = Projectile:new({
        position = vec2(self.position.x, self.position.y + 2)
    });
    
    if (math.random() < self.grid.config.bombChance) then
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
      explode = love.audio.newSource("sounds/explosion.wav", "static"),
      bounce = love.audio.newSource("sounds/bounce.wav", "static"),
      attach = love.audio.newSource("sounds/attach.wav", "static")
    }  
    
    for k,v in pairs(Assets.sounds) do
        v:setVolume(VOLUME);
    end
    
    Assets.images = {
      gem =  love.graphics.newImage("images/gem.png"),
      sheen =  love.graphics.newImage("images/sheen.png")
    }
    
    State.score = 0;
    State.grid = Grid:new();
    State.launcher = Launcher:new{grid = State.grid};
   
end

function love.update(dt)
    State.dt = dt;
    State.launcher:update(State);
    State.grid:update(State);
    
    if (State.score > State.grid.config.scoreNeeded) then
        State.grid:nextLevel();
        State.launcher:reset();
    end
    
end


State.gfx = {

    pts = function(s)
        return State.unit * (s);
    end,
    
    tileSize = function(s)
        return State.gfx.pts(s * 11)
    end,
    
    tileOffset = function(s)
        return State.gfx.tileSize(s) + State.gfx.pts(-5);
    end,
    
    drawGem = function(gem, yOffset)
        
        love.graphics.setColor(gem.config.color);
        
        --[[State.gfx.rect("fill", 
            State.gfx.tileOffset(gem.c), 
            State.gfx.tileOffset(gem.r),
            State.gfx.tileSize(gem.w),
            State.gfx.tileSize(gem.h));
        ]]
            
        local shrink = gem.shrink;
        if (shrink == nil or shrink > 10) then
            shrink = 1;
        else
            shrink = shrink / 10;
        end
        
        local ox, oy = gem.c + (1-shrink) * 0.5 * gem.w, gem.r + (1-shrink) * 0.5 * gem.h + yOffset
        
        love.graphics.draw(Assets.images.gem,
           State.gfx.tileOffset(ox), 
           State.gfx.tileOffset(oy),
           0,
           State.gfx.tileSize(gem.w * shrink)/PNG_SIZE, State.gfx.tileSize(gem.h * shrink)/PNG_SIZE);
        
        love.graphics.setColor(1,1,1,1);
        
        love.graphics.draw(Assets.images.sheen,
           State.gfx.tileOffset(ox), 
           State.gfx.tileOffset(oy),
           0,
           State.gfx.tileSize(gem.w * shrink)/PNG_SIZE, State.gfx.tileSize(gem.h * shrink)/PNG_SIZE);
                  
            
        
    end,
    
    drawTile = function(x, y, shrink)
        if (shrink == nil) then
            shrink = 1;
        end
        
        --[[
        State.gfx.rect("fill", 
            State.gfx.tileOffset(x + ((1-shrink) * 0.5)), 
            State.gfx.tileOffset(y + ((1-shrink) * 0.5)),
            State.gfx.tileSize(1 * shrink),
            State.gfx.tileSize(1 * shrink));
           ]] 
        love.graphics.draw(Assets.images.gem,
           State.gfx.tileOffset(x + ((1-shrink) * 0.5)), 
           State.gfx.tileOffset(y + ((1-shrink) * 0.5)),
           0,
           State.gfx.tileSize(1 * shrink)/PNG_SIZE, State.gfx.tileSize(1 * shrink)/PNG_SIZE);
        
        love.graphics.setColor(1,1,1,1);
        
        love.graphics.draw(Assets.images.sheen,
           State.gfx.tileOffset(x + ((1-shrink) * 0.5)), 
           State.gfx.tileOffset(y + ((1-shrink) * 0.5)),
           0,
           State.gfx.tileSize(1 * shrink)/PNG_SIZE, State.gfx.tileSize(1 * shrink)/PNG_SIZE);
            
    end,
    
    pixToOffset = function(x, y)
        return (x - State.gfx.pts(1)) / State.gfx.tileSize(1), (y - State.gfx.pts(1)) / State.gfx.tileSize(1);
    end,
    
    rect = love.graphics.rectangle
}

function drawUI(state)
    
    love.graphics.setColor(1,1,1,1);
    
    love.graphics.print("Score: " .. State.score .. " / " .. State.grid.config.scoreNeeded, 0, 0, 0, 1, 1);
    
end

function love.draw()
  
  love.graphics.setBlendMode("alpha")

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
    
    if (k == "w") then
        State.grid:nextLevel();
        State.launcher:reset();
    end

end

function love.keyreleased(k)
    --State.keyboard[k] = 0;
end
