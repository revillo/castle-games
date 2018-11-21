--http://localhost:4000/blocks.lua

--Scripts--
local Vec2 = require("lib/vec2")
function vec2(x, y) 
    return Vec2:new{x=x or 0, y=y or 0};
end

local Array = require("lib/array")
local Queue = require("lib/queue")
local Sound = require("lib/sound");
local TextAnimator = require("lib/TextAnimator")
local easing = require("https://raw.githubusercontent.com/EmmanuelOga/easing/master/lib/easing.lua")


--CONSTANTS--

local VOLUME = 0.1;
local PNG_SIZE = 256;
local RELOAD_DURATION = 0.5;
local POINT_SIZE = 1/200;
local GEM_SPEED = 23;
local GEM_SHEEN = 0.6;

local EASING = function(t) 

  local b = 0;
  local c = 1;
  local d = 1;
  
  
  return easing.inOutExpo(t,b,c,d);
  --return t * t;
end

--GLOBALS--
State = {
  paused = false;
}
Assets = {}
Class = {}

local LEVELS = {
    --colors | columns | scrollSpeed | scoreNeeded
    {  2,        5,        0.15,          2000 },
    {  2,        6,        0.17,          4500 },
    {  2,        7,        0.18,          9000 },
    {  2,        8,        0.19,         14000 },
    {  2,        9,        0.22,         19000 }, 
    
    {  2,        10,        0.23,        24000 }, 
    {  2,        11,        0.24,        29000 }, 
    {  2,        5,        0.3,          34000 }, 
    {  2,        7,       0.33,          39000 }, 
    {  2,        8,       0.34,          44000 }, 
    
    {  2,        10,       0.34,         49000 }, 
    {  3,        5,       0.15,          54000 },
    {  3,        6,       0.17,          59000 },
    {  3,        7,       0.20,          64000 },
    {  3,        8,       0.23,          69000 }
}


State.gfx = {

    pts = function(s)
        return State.unit * (s);
    end,
    
    tileSize = function(s)
        return State.gfx.pts(s * 11)
    end,
    
    tileOffsetX = function(s)
        return State.gfx.tileSize(s) + State.gfx.pts(30);
    end,
    
    tileOffsetY = function(s)
        return State.gfx.tileSize(s) + State.gfx.pts(-5);
    end,
    
    drawGem = function(gem, yOffset)
        
        love.graphics.setColor(gem.config.color);

        local shrink = gem.shrink;
        if (shrink == nil or shrink > 1) then
            shrink = 1;
        end
        
        
        
        local ox, oy = gem.c + (1-shrink) * 0.5 * gem.w, gem.r + (1-shrink) * 0.5 * gem.h + yOffset
        
        love.graphics.draw(Assets.images.gem,
           State.gfx.tileOffsetX(ox), 
           State.gfx.tileOffsetY(oy),
           0,
           State.gfx.tileSize(gem.w * shrink)/PNG_SIZE, State.gfx.tileSize(gem.h * shrink)/PNG_SIZE);
        
        love.graphics.setColor(1,1,1,GEM_SHEEN);

          
        love.graphics.draw(Assets.images.sheen,
           State.gfx.tileOffsetX(ox), 
           State.gfx.tileOffsetY(oy),
           0,
           State.gfx.tileSize(gem.w * shrink)/PNG_SIZE, State.gfx.tileSize(gem.h * shrink)/PNG_SIZE);
           
    end,
    
    drawIndicator = function(x, y, shrink)
      
          local clr = shrink;
          love.graphics.setColor(clr,clr,clr * 0.9,1);
        
         love.graphics.circle(
           "fill",
           State.gfx.tileOffsetX(x + 0.5), 
           State.gfx.tileOffsetY(y + 0.5),
           State.gfx.tileSize(0.1 * shrink),
           32
         );
    
    end,
    
    drawTile = function(x, y, shrink, isBomb)
        
        if (shrink == nil) then
            shrink = 1;
        end
        

        love.graphics.draw(Assets.images.gem,
           State.gfx.tileOffsetX(x + ((1-shrink) * 0.5)), 
           State.gfx.tileOffsetY(y + ((1-shrink) * 0.5)),
           0,
           State.gfx.tileSize(1 * shrink)/PNG_SIZE, State.gfx.tileSize(1 * shrink)/PNG_SIZE);
        
        

        if (isBomb) then        
        
          --todo
        
        end
        
        love.graphics.setColor(1,1,1,GEM_SHEEN);

        love.graphics.draw(Assets.images.sheen,
           State.gfx.tileOffsetX(x + ((1-shrink) * 0.5)), 
           State.gfx.tileOffsetY(y + ((1-shrink) * 0.5)),
           0,
           State.gfx.tileSize(1 * shrink)/PNG_SIZE, State.gfx.tileSize(1 * shrink)/PNG_SIZE);
           
    end,
    
    pixToOffset = function(x, y)
        return (x - State.gfx.pts(30)) / State.gfx.tileSize(1), (y - State.gfx.pts(-5)) / State.gfx.tileSize(1);
    end,
    
    rect = love.graphics.rectangle
}

--CLASSES--

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
    n = n % #LEVELS;
    
    local level = LEVELS[n];
    local config = {};
    
    self.levelNumber = n;
    self.danger = 0;
    
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
    self.offsetTime = 0;
    self.numRows = 0;

    for r = 1, self.config.maxRows do
        self:addRow();
    end
    
    self:recycle();
    self:recycle();
    
    self:dropOrphans();
    
    
    self.textAnim:addAnimation("Level ".. self.levelNumber, nil, {
        duration = 2,
        x = State.gfx.tileOffsetX(self.numCols * 0.5) ,
        y = State.gfx.tileOffsetY(self.numRows * 0.5),
        size = 2
    });
end

function Grid:init()
    self.numCols = 8;
    self.numRows = 0;
    self.yOffset = 0;
    self.offsetTime = 0;
    self.blocks = {};
    self.gems = {};
    self.gemID = 0;
    self.textAnim = TextAnimator:new();
    
    
    self.config = {
        blockConfigs = {BlockType.Blue, BlockType.Red},
        maxRows = 15,
        bombChance = 0.25
    }
    
    self:setLevel(1);

end

function Grid:updateEffects(state)

  local didPlay = false;
  local highestRow = -1;
  
  self:eachBlock(function(blk, r, c)
  
    if (blk.willBurst and blk.shrink < 1.0) then
        blk.willBurst = nil;
        
        State.score = State.score + 10;

        if (not didPlay) then
            didPlay = true;
            Assets.sounds.chip:play();
        end
        
        self.textAnim:addAnimation("+10", nil, {
            duration = 0.5,
            x = State.gfx.tileOffsetX(c + 0.2),
            y = State.gfx.tileOffsetY(r + 0.7),
            size = 1
        });
    end
    
    if (blk.status == 1 and r > highestRow) then
      highestRow = r;
    end
  
  end);
  
  self.danger = highestRow / self.numRows;

  didPlay = false;
  self:eachGem(function(gem)
  
    if (gem.willBurst and gem.shrink < 1.0) then
    
        if (not didPlay) then
            didPlay = true;
            Assets.sounds.glass:play();
        end
        
        local gmScore = self:gemScore(gem.w, gem.h);
    
        State.score = State.score + gmScore;
    
        gem.willBurst = nil;
        self.textAnim:addAnimation("+" .. gmScore, nil, {
            duration = 1.5,
            x = State.gfx.tileOffsetX(gem.c + 0.2 * gem.w),
            y = State.gfx.tileOffsetY(gem.r + 0.7 * gem.h),
            size = 2
        });
        
        local s = love.graphics.newParticleSystem(Assets.images.shard, 150);
        s:setParticleLifetime(0.5, 1.0) 
        s:setEmissionRate(0)
        s:setSizes(0.05, 0.03)
        s:setEmissionArea("uniform", State.gfx.tileSize(gem.w * 0.4), State.gfx.tileSize(gem.h * 0.4), 0, false);
        s:setRotation( -3, 3 )
        s:setSpin(-4.0, 4.0);
        s:setSizeVariation(1)
        
        s:setSpeed(-100, 100);
        s:setLinearDamping(0.11, 0.11);
        s:setColors(
          255, 255, 255, 180, 
          255, 255, 255, 0,
          255, 255, 255, 125,
          255, 255, 255, 0)
          
        s:emit(150);

        gem.shards = s;
        
    end
    
    if (gem.shards) then
      gem.shards:update(state.dt);
    end
    
  end);
end

function Grid:getPercentFinished()

  local prevLevel = LEVELS[self.levelNumber - 1];
  local base = 0;
  
  if (prevLevel ~= nil) then
      base = prevLevel[4];
  end
  
  return (State.score - base) / (LEVELS[self.levelNumber][4] - base);
  
end

function Grid:drawProgressBar(state)
    
    local dangerThresh = 0.55;
    local dangerFlash = math.max((self.danger - dangerThresh) * 2.0, 0.0); 
    dangerFlash = math.abs(0.5 * dangerFlash * math.cos(State.clock * 6.0));

    self.dangerFlash = dangerFlash;

    local gfx = state.gfx;
    local clr = love.graphics.setColor;
    local w = 0.25;
    local o = 0.5;

    love.graphics.setLineWidth(state.unit);
    
    clr(0.1, 0.1, 0.1, 1);

    gfx.rect("fill", 
        gfx.tileOffsetX(o), gfx.tileOffsetY(2), 
        gfx.tileSize(w), gfx.tileSize(self.config.maxRows - 1)
    );
    
    clr(1, 1, 1, 0.95);

    gfx.rect("fill", 
        gfx.tileOffsetX(o), gfx.tileOffsetY(2), 
        gfx.tileSize(w), gfx.tileSize(self.config.maxRows - 1) * math.min(1.0, self:getPercentFinished())
    );
    
    love.graphics.setColor(0.5 + dangerFlash, 0.5 - dangerFlash * 0.5, 0.5 - dangerFlash, 0.5 + dangerFlash);
    
    gfx.rect("line", 
        gfx.tileOffsetX(o), gfx.tileOffsetY(2), 
        gfx.tileSize(w), gfx.tileSize(self.config.maxRows - 1)
    );

end


function Grid:draw(state)

        
    local gfx = state.gfx;
    local clr = love.graphics.setColor;
    
    self:drawProgressBar(state);
    
    love.graphics.setLineWidth(state.unit);
    love.graphics.setColor(0.1, 0.1, 0.1, 1.0);

    love.graphics.setScissor( gfx.tileOffsetX(1), gfx.tileOffsetY(2), gfx.tileSize(self.numCols), gfx.tileSize(self.config.maxRows - 1))

    
    gfx.rect("fill", 
        gfx.tileOffsetX(1), gfx.tileOffsetY(2), 
        gfx.tileSize(self.numCols), gfx.tileSize(self.config.maxRows - 1)
    );
    
    self.animating = false;
    
    --draw blocks
    self:eachBlock(function(blk,r , c)
        
        clr(blk.config.color);
        
        if (blk.gem) then
        
        elseif (blk.status == 1) then
            
            gfx.drawTile(c, r + self.yOffset);
                        
        elseif (blk.shrink) then
        
            gfx.drawTile(c, r + self.yOffset, math.min(1, blk.shrink));
            blk.shrink = blk.shrink - state.dt * 10.0;
            self.animating = true;
            
            if (blk.shrink < 0) then
                blk.shrink = nil;
                blk.willBurst = nil;
            end
        end   
    end);
    
    --draw gems
    for k,gem in pairs(self.gems) do
        if (gem) then
    
            gfx.drawGem(gem, self.yOffset);
            
            if (gem.shrink ~= nil) then
                
                self.animating = true;

                if (gem.shrink > 1) then
                    gem.shrink = gem.shrink - state.dt * 10.0;
                elseif (gem.shrink < 0) then
                    gem.shrink = nil;
                    self.gems[gem.id] = nil;
                else
                    --gem.shrink = gem.shrink - state.dt * 10.0 / math.min(gem.w, gem.h);
                    gem.shrink = gem.shrink - state.dt * 10.0 / math.min(gem.w, gem.h);
                end
            end
        end
    end
    
    
    love.graphics.setScissor(0, 0, State.width, State.height);
    
    local dangerFlash = self.dangerFlash;
    love.graphics.setColor(0.5 + dangerFlash, 0.5 - dangerFlash * 0.5, 0.5 - dangerFlash, 0.5 + dangerFlash);

    gfx.rect("line", 
        gfx.tileOffsetX(1), gfx.tileOffsetY(2), 
        gfx.tileSize(self.numCols), gfx.tileSize(self.config.maxRows - 1)
    );
    
    self:eachGem(function(gem) 
      
      love.graphics.setColor(gem.config.color);
    
       if (gem.shards) then        
          love.graphics.draw(gem.shards, 
            State.gfx.tileOffsetX(gem.c + gem.w * 0.5),
            State.gfx.tileOffsetY(gem.r + gem.h * 0.5 + self.yOffset) 
          );
        end  
    end);
    love.graphics.setColor(1,1,1,1);

    --[[
    love.graphics.setColor(0.0, 0.0, 0.0, 1.0);
    gfx.rect("fill", 
        gfx.tileOffsetX(0.5), gfx.tileOffsetY(1), 
        gfx.tileSize(self.numCols + 1), gfx.tileSize(1)
    );
    ]]
    
    self.textAnim:draw();
    
    
    
    
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
    --Assets.sounds.bomb:play();

    local config = self.blocks[br][bc].config;
    local toCheck = Queue:new{};
    
    self.animating = true;
    
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
                        blk.gem.shrink = blk.gem.shrink or (1 + dist);
                        blk.gem.willBurst = true;
                        local score = self:gemScore(blk.gem.w, blk.gem.h);
                        --State.score = State.score + score;
                    else
                        dist = dist - 1;
                    end
                    
                    
                else
                    --State.score = State.score + 10;
                    blk.shrink = 1 + dist;
                    blk.willBurst = true;
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
    
    return math.min(w,h) * 100 + math.max(w,h) * math.max(w,h);
    
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
  
    while(self:constructLargestGem() and stopper < 100) do
        stopper = stopper + 1;
    end;
    
    if (stopper > 100) then
        print ("Gem Overflow")
    end
    
    --self:constructLargestGem();
    
end

function Grid:insertProjectile(proj)

    local pfc, pfr = proj.position.x, proj.position.y - self.yOffset;
    
    local pc, pr = math.floor(pfc + 0.5), math.floor(pfr + 0.5);
    
    local bc , br, bd = -1, -1, 1000
    
    
    for c = pc - 1, pc + 1 do
    for r = pr - 1, pr + 1 do
    
        if (self.blocks[r] and self.blocks[r][c]) then
            local blk = self.blocks[r][c];
            if (blk.status == 0 and blk.canBeFilled) then  
                local d = math.abs(pfc - c) + math.abs(pfr - r);
                
                if (d < bd) then
                    bd = d;
                    bc, br = c, r;
                end
            end
        end
    
    end end
    
    if (br >= self.numRows) then
        
        self.didLose = true;
    
    elseif (self.blocks[br] and self.blocks[br][bc]) then

        self.blocks[br][bc] = {
            status = 1,
            config = proj.config
        };
        
    end
    
    
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
  
    if(proj.position.y  - self.yOffset < 1) then
        
        if(not proj.isBomb) then
            self:insertProjectile(proj);
        end
        
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

    self:eachGem(function(gem) 
      gem.r = gem.r + 1;
    end);
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
            --todo
            block.shrink = 2;
        end
    end);
    
    
    self:constructGems();

end

function Grid:checkLose()
    local didLose = self.didLose or false;
        
    self:eachBlockInRow(self.numRows, function(block)
      if (block.status == 1) then
        didLose = true;
      end
    end);
    
    if (didLose) then
        self.didLose = false;
        Assets.sounds.lose:play();
        local prevLevel = LEVELS[self.levelNumber - 1];
        if (prevLevel ~= nil) then
            State.score = prevLevel[4];
        else
            State.score = 0;
        end
        self:setLevel(self.levelNumber);
    end      
    
    return didLose;

end

function Grid:pause()
    self.paused = true;
end

function Grid:update(state)
    self:updateEffects(state);
    self.textAnim:update(state.dt);
    
    if (self.paused) then
        return
    end;
    
    if (self:checkLose()) then
    
    
    else
        self.offsetTime = self.offsetTime + state.dt * self.config.scrollSpeed;
        self.yOffset = EASING(self.offsetTime);
        
        --self.yOffset = self.yOffset + state.dt * self.config.scrollSpeed;

        if (self.offsetTime > 1.0) then
            self:recycle();
            self:dropOrphans();
            self.offsetTime = 0.0;
            self.yOffset = 0.0;
        end
    end
end

Projectile = Class:new();

function Projectile:update(state) 
    
    self.position:addScaled(self.direction, state.dt * GEM_SPEED);
    
end

function Projectile:draw(state)
    gfx = state.gfx;
    
    if (self.isBomb) then
        love.graphics.setColor(1, 1, 1, 1);
    else
        love.graphics.setColor(self.config.color);
    end
    
    gfx.drawTile(self.position.x, self.position.y, nil, self.isBomb);

end


Launcher = Class:new();

function Launcher:init()
    
    
    self.indicatorDelta = vec2(0, 1);
    self.indicatorTemp = vec2(0,0);
    self.reloadTime = 0;
        
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
        position = vec2(self.position.x, self.position.y + 1.5)
    });
    
    if (math.random() < self.grid.config.bombChance) then
        projectile.isBomb = true;
    else
        projectile.config = self.grid:sampleBlockConfigs();
    end
    
    return projectile;
    
end

function Launcher:fire(x, y) 

    if (self.paused or self.reloadTime < 1.0) then
        return
    end

    self.reloadTime = 0;
    
    Assets.sounds.zap:play();
    
    local projectile = self.nextProjectile;
    
    projectile.direction = vec2(x - self.position.x, y - self.position.y);  
    
    projectile.direction:normalize();
    projectile.direction.y = math.min(projectile.direction.y, -0.5);
    projectile.direction:normalize();

    projectile.position = vec2(self.position.x, self.position.y);    
    projectile.uuid = self.projectileUUID;

    
    self.projectiles[self.projectileUUID] = projectile;
    self.projectileUUID = self.projectileUUID + 1;
    
    self.nextProjectile = self.projectileOnDeck;
    self.nextProjectile.position:set(self.position.x, self.position.y + 0.5);
    self.projectileOnDeck = self:createProjectile();
    
end

function Launcher:eachProjectile(fn)

    for uuid, proj in pairs(self.projectiles) do
        if proj then
            fn(proj);
        end
    end
    
end

function Launcher:setTarget(x, y)


  local cx, cy = self.indicatorDelta.x, self.indicatorDelta.y;
  
  self.indicatorDelta:set(x, y);
  self.indicatorDelta:sub(self.position);
  self.indicatorDelta:normalize();
  
  if (self.indicatorDelta.y > -0.3) then
    self.indicatorDelta:set(cx, cy);
    return;
  end
    
end

function Launcher:drawIndicator(state)
  
  if (self.reloadTime < 1.0) then
    return;
  end
  
  local cycleT = state.clock % 1.0 - 1.0;
  --cycleT = 0;
  
  for i = 1, 4 do
  
    --cycle = (cycle + 0.4) % 1.2;
    
    local increment = i;    

    self.indicatorTemp:set(self.position.x, self.position.y);
    self.indicatorTemp:addScaled(self.indicatorDelta, increment * 0.4);
    
    state.gfx.drawIndicator(self.indicatorTemp.x, self.indicatorTemp.y, (math.sin(-state.clock * 10.0 + i) * 0.1 + 0.8) * (2.0 - (i * 0.4)));
    
  end

end

function Launcher:draw(state)
    
    self:eachProjectile(function(proj) proj:draw(state) end);
    
    self.nextProjectile:draw(state);
    self.projectileOnDeck:draw(state);
    self:drawIndicator(state);
end

function Launcher:pause()
    self.paused = true;
end

function Launcher:update(state)

    self.reloadTime = self.reloadTime + state.dt / RELOAD_DURATION;

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
    State.unit = math.min(w * POINT_SIZE, h * POINT_SIZE)
end


function love.resize(w, h)
    resize(w,h);
end

function love.load()
    local w, h = love.graphics.getDimensions();
    resize(w,h);
    
    love.graphics.setBackgroundColor( 0.05, 0.05, 0.05 )

    Assets.sounds = {
      zap =     Sound:new("sounds/whoosh.wav", 3),
      chip = Sound:new("sounds/chip2.wav",  15),
      bounce =  Sound:new("sounds/bounce.wav",  5),
      attach =  Sound:new("sounds/ping.wav",  2),
      glass = Sound:new("sounds/glass2.wav",  15),
      lose = Sound:new("sounds/lose.wav"),
      win = Sound:new("sounds/win.wav"),
      --bomb = Sound:new("sounds/bomb.wav", 2)
    }  
    
    for k,v in pairs(Assets.sounds) do
        v:setVolume(VOLUME);
    end
    
    Assets.sounds.zap:setVolume(0.5);
    Assets.sounds.attach:setVolume(VOLUME);
    --Assets.sounds.bomb:setVolume(VOLUME * 0);
    
    Assets.images = {
      gem =  love.graphics.newImage("images/gem.png"),
      sheen =  love.graphics.newImage("images/sheen.png"),
      shard =  love.graphics.newImage("images/shard.png"),
    }
    
    State.score = 0;
    State.clock = 0;
    State.grid = Grid:new();
    State.launcher = Launcher:new{grid = State.grid};
   
end

function goNextLevel()
    State.grid:nextLevel();
    State.launcher:reset();
    Assets.sounds.win:play();
end

function love.update(dt)
    if (State.paused) then
      return
    end

    State.dt = dt;
    State.clock = State.clock + dt;
    State.launcher:update(State);
    State.grid:update(State);
    
    if (State.score > State.grid.config.scoreNeeded) then
        State.grid:pause();
        State.launcher:pause();
        
        if (not State.grid.animating) then
            State.grid.paused = false;
            State.launcher.paused = false;
            goNextLevel();
        end
        
    end
    
end

function drawUI(state)

    love.graphics.setColor(1,1,1,1);

    love.graphics.print("Score: " .. State.score .. " / " .. State.grid.config.scoreNeeded, 0, 0, 0, 1, 1);
    love.graphics.print("Level: " .. State.grid.levelNumber, 0, 15, 0, 1, 1);
    
end

function love.draw()
  
  --love.graphics.setBlendMode("alpha")
  
  drawUI(State);
  
  
  State.grid:draw(State);
  State.launcher:draw(State);
  
end

function love.mousemoved( x, y )

  local tx, ty = State.gfx.pixToOffset(x, y);
  State.launcher:setTarget(tx - 0.5, ty - 0.5);
  
end


function love.mousepressed( x, y, button, istouch, presses )
    
    local tx, ty = State.gfx.pixToOffset(x, y);
    
    State.launcher:fire(tx - 0.5, ty - 0.5);

end

function love.keypressed(k)
    State.grid:addRow();
    
    --Debugging
    if (k == "w") then
        State.grid:nextLevel();
        State.launcher:reset();
        Assets.sounds.win:play();
    end
    
    if (k == "p") then
        State.paused = not State.paused;
    end

end

function love.keyreleased(k)
end
