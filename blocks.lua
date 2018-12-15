--http://localhost:4000/blocks.lua
--castle://localhost:4000/blocks.lua
--Scripts--

--[[
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
       'sounds/whoosh.wav',
      'sounds/chip2.wav',
      'sounds/bounce.wav',
      'sounds/ping.wav',
      'sounds/glass2.wav',
      'sounds/lose.wav',
      'sounds/win.wav',
     'sounds/music.mp3',
     'images/shard.png',
     'images/gypsum.png',
     'fonts/OpenSans-ExtraBold.ttf'
    })
end
]]

local cs = require("share/cs");

client = cs.client;

--useCastleConfig must be called right away with this API
if USE_CASTLE_CONFIG then
    client.useCastleConfig()
else
    client.enabled = true
end

local Vec2 = require("lib/vec2")


function vec2(x, y) 
    return Vec2:new{x=x or 0, y=y or 0};
end

local randFloat = function(lo, hi) 
    return lo + (math.random() * (hi-lo));
end

local Shaders = require("shaders/gem_shaders");
local Array = require("lib/array")
local Queue = require("lib/queue")
local Sound = require("lib/sound")
local UI = require("lib/ui")
local TextAnimator = require("lib/TextAnimator")
--local easing = require("https://raw.githubusercontent.com/EmmanuelOga/easing/master/lib/easing.lua")
local easing = {};
--local cs = require("https://raw.githubusercontent.com/expo/share.lua/master/cs.lua");



easing.inOutExpo = function(t,b,c,d)
  if t == 0 then return b end
  if t == d then return b + c end
  t = t / d * 2
  if t < 1 then
    return c / 2 * math.pow(2, 10 * (t - 1)) + b - c * 0.0005
  else
    t = t - 1
    return c / 2 * 1.0005 * (-math.pow(2, -10 * t) + 2) + b
  end
end

easing.inOutQuad = function(t, b, c, d)
  t = t / d * 2
  if t < 1 then
    return c / 2 * math.pow(t, 4) + b
  else
    t = t - 2
    return -c / 2 * (math.pow(t, 4) - 2) + b
  end
end

easing.outBack = function(t, b, c, d, s)
  if not s then s = 1.70158 end
  t = t / d - 1
  return c * (t * t * ((s + 1) * t + s) + 1) + b
end

math.sign = function(x) 
  
  if (x >= 0.0) then 
    return 1 
  else 
    return -1 
  end
  
end

--CONSTANTS--

local VOLUME = 0.5;
local PNG_SIZE = 256;
local RELOAD_DURATION = 0.5;
local POINT_SIZE = 1/220;
local GEM_SPEED = 23;
local SPAM_INCREMENT = 100.0;
local GEM_SHEEN = 0.5;

local EASING = function(t) 

  local b = 0;
  local c = 1;
  local d = 1;
  
  
  return easing.inOutExpo(t,b,c,d);
  --return t * t;
end

--GLOBALS--
State = {
  paused = false,
  keyboard = {}
}
Assets = {}
Class = {}

Themes = {
  RedBlue = 2,
  GoldSilver = 1,
  RGB = 3,
  XMAS = 4,
  PurpleYellow = 5,
  PinkCyan = 6,
  Fire = 7,
  HunterCream = 8,
  Fire3 = 9,
  Olympic = 10
}

local LEVELS = {
    --colors | columns | scrollSpeed | scoreNeeded
    --{  2,        7,        0.15,          100000 },
    {  Themes.RedBlue,        5,        0.15,            1800 },
    {  Themes.PinkCyan,        6,        0.17,           5000 },
    {  Themes.PurpleYellow,        7,        0.18,       9000 },
    {  Themes.Fire,        8,        0.19,               14000 },
    {  Themes.HunterCream,        9,        0.22,        19000 }, 
    
    {  Themes.RedBlue,        10,        0.23,           24000 }, 
    {  Themes.PinkCyan,        11,        0.24,          34000 }, 
    {  Themes.PurpleYellow,        5,        0.3,        39000 }, 
    {  Themes.Fire,        7,       0.33,                44000 }, 
    {  Themes.HunterCream,        8,       0.34,         49000 }, 
    
    {  Themes.GoldSilver,        10,       0.34,         54000 }, 
    {  Themes.RGB,        5,       0.14,                 59000 },
    {  Themes.XMAS,        6,       0.15,                64000 },
    {  Themes.Fire3,        7,       0.16,               70000 },
    {  Themes.Olympic,        8,       0.16,             76000 }  
}

LEVELS.multi = {  Themes.RedBlue, 7,  0.18, -1 };

for i = 3,15 do
  LEVELS[i][4] = LEVELS[i-1][4] + 7000; 
end


function generateGfxContext(scale, dx, dy) 
    
    local pts = function(s)
        return State.unit * (s) * scale;
    end
    
    
    
    local tileSize = function(s)
        return pts(s * 12)
    end
    
    local tileOffsetX = function(s)
        return tileSize(s) + pts(dx);
    end
        
    local tileOffsetY = function(s)
        return tileSize(s) + pts(dy);
    end
    
    
    return {
        pts = pts,
        tileSize = tileSize,
        
        tileOffsetX = tileOffsetX,
        tileOffsetY = tileOffsetY,
        
        fontScale = function(s)
          return pts(0.1 * s)
        end,
        
        drawGem = function(gem, yOffset)
            
            love.graphics.setColor(gem.config.color);

            local shrink = gem.shrink;
            if (shrink == nil or shrink > 1) then
                shrink = 1;
            end

            local ox, oy = gem.c + (1-shrink) * 0.5 * gem.w, gem.r + (1-shrink) * 0.5 * gem.h + yOffset
       
            Assets.shaders.gem:send("scale", {tileSize(shrink * gem.w),tileSize(shrink * gem.h)});
            Assets.shaders.gem:send("dimensions", {gem.w,gem.h});
            Assets.shaders.gem:send("facets", 4);
            
            love.graphics.draw(Assets.meshes.quad, 
               tileOffsetX(ox), 
               tileOffsetY(oy)
            );
            
        end,
        
        drawIndicator = function(x, y, shrink)
          
              local clr = shrink;
              love.graphics.setColor(clr,clr,clr * 0.9,1);
             
             local s = 0.1 * shrink;
             
             love.graphics.rectangle(
               "fill",
               tileOffsetX(x + 0.5 - s * 0.5), 
               tileOffsetY(y + 0.5 - s * 0.5),
               tileSize(s),
               tileSize(s)
             );
             
             
        
        end,
        
        drawTile = function(x, y, block)
            
            local shrink = block.shrink;
            
            if (shrink == nil) then
                shrink = 1;
            elseif (shrink > 1.0) then
                shrink = 1;
            end
              
            
            if (block.isBomb) then        
              Assets.shaders.gem:send("bomb", 1);
            end
            
            shrink = easing.outBack(shrink, 0, 1, 1);
            love.graphics.setColor(block.config.color);
     
            Assets.shaders.gem:send("scale", {tileSize(shrink),tileSize(shrink)});
            Assets.shaders.gem:send("dimensions", {1,1});
            Assets.shaders.gem:send("facets", block.config.facets);
            
--          Assets.shaders.gem:send("bomb", 1);

          
            
            love.graphics.draw(Assets.meshes.quad, 
               tileOffsetX(x + ((1-shrink) * 0.5)), 
               tileOffsetY(y + ((1-shrink) * 0.5))
            );
                    
           Assets.shaders.gem:send("bomb", 0);
            
            
        end,
        
        pixToOffset = function(x, y)
            return (x - pts(dx)) / tileSize(1), (y - pts(dy)) / tileSize(1);
        end,
        
        rect = love.graphics.rectangle
    }

end


State.gfxLeft = generateGfxContext(1, 20, -5);
State.gfxRight = generateGfxContext(1, 140, -5);
State.gfxCenter = generateGfxContext(1, 60, -5);
State.gfx = State.gfxCenter;

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
        color = {0.0, 0.3, 0.95, 1.0}
    },
    
    Red = {
        color = {0.95, 0.1, 0.1, 1}
    },
    
    Green = {
        color = {0, 0.6, 0, 1}
    },
    
    Yellow = {
        color = {0.8, 0.7, 0.2, 1}
    },
    
    Cyan = {
      color = {0.0, 0.5, 0.8, 1}
    },
    
    Purple = {
      color = {0.6, 0.0, 0.7, 1.0}
    },
    
    Pink = {
      color = {0.8, 0.0, 0.5, 1.0}
    },
    
    FireRed = {
      color = {0.85, 0.13, 0.0, 1.0}
    },
    
    FireYellow = {
      color = {1.0, 1.0, 0.0, 1.0}
    },
    
    Cream = {
      color = {0.98, 0.9, 0.6, 1.0}
    },
    
    Hunter = {
      color = {0.2, 0.5, 0.15, 1.0}
    },
    
    White = {
      color = {0.8, 0.8, 0.8, 1.0}
    },
    
    Obsidian = {
      color = {0.2, 0.2, 0.4, 1.0}
    },
    
    Gold = {
      color = {0.85,0.6,0.2,1.0}
    },
    
    Silver = {
      color = {0.65, 0.65, 0.85}
    },
    
    Bronze = {
      color = {0.2, 0.1, 0.0, 1.0}
    }
}

BlockTypeArray = {};

do 
  local bi = 1;
  for k,v in pairs(BlockType) do
    v.index = bi;
    v.facets = 4;
    BlockTypeArray[bi] = v;
    bi = bi + 1;
  end
end

SpamBlockArray = {BlockType.Green, BlockType.Yellow}

function Grid:nextLevel()
    
    self:setLevel( (self.levelNumber or 0) + 1 );
end

function Grid:displayText(text) 

  self.textAnim:addAnimation(text, nil, {
        duration = 2,
        x = State.gfx.tileOffsetX(self.numCols * 0.5),
        y = State.gfx.tileOffsetY(self.numRows * 0.5),
        size = State.gfx.fontScale(2)
    });

end

local ColorConfigs = {
  [Themes.RedBlue] = {
     blockConfigs = {BlockType.Red, BlockType.Blue};
     bombChance = 0.25;
  },
  
  [Themes.GoldSilver] = {
     blockConfigs = {BlockType.Gold, BlockType.Silver};
     bombChance = 0.25;
  },
  
  [Themes.Olympic] = {
    blockConfigs = {BlockType.Gold, BlockType.Silver, BlockType.Bronze};
    bombChance = 0.5;
  },
  
  [Themes.XMAS] = {
    blockConfigs = {BlockType.Red, BlockType.White, BlockType.Green};
    bombChance = 0.5;
  },
  
  
  [Themes.Fire3] = {
    blockConfigs = {BlockType.FireRed, BlockType.FireYellow, BlockType.Obsidian};
    bombChance = 0.55;
  },
  
   [Themes.RGB] = {
    blockConfigs = {BlockType.Blue, BlockType.Red, BlockType.Green};
    bombChance = 0.5;
  },
  
  
  [Themes.PurpleYellow] = {
    blockConfigs = {BlockType.Purple, BlockType.Yellow};
    bombChance = 0.25;
  },
  
  [Themes.PinkCyan] = {
    blockConfigs = {BlockType.Pink, BlockType.Cyan};
    bombChance = 0.25;
  },
  
  [Themes.Fire] = {
    blockConfigs = {BlockType.FireYellow, BlockType.FireRed};
    bombChance = 0.25;
  },
  
  [Themes.HunterCream] = {
    blockConfigs= {BlockType.Hunter, BlockType.Cream},
    bombChance = 0.25;
  }
}

function Grid:setLevel(n)
    if (type(n) == "number") then
        if (LEVELS[n] == nil) then
          n = 1;
        end
        
        local prevLevel = LEVELS[n-1];
        
        if (prevLevel and State.score < prevLevel[4]) then
          State.score = prevLevel[4];
        end
        
        self.multi = false;
    else
        self.multi = true;
    end
    
    local level = LEVELS[n];
    
    self.levelNumber = n;
    self.danger = 0;
    
    local config = ColorConfigs[level[1]];
 
    
    config.maxRows = 15;
    
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
    self.animating = 0;

    for r = 1, self.config.maxRows do
        self:addRow();
    end
    
    self:recycle();
    self:recycle();
    
    self:dropOrphans();
    
    resize(State.width, State.height);
    
    
    if (not self.multi) then
        self:displayText("Level ".. self.levelNumber);
    end
    
    
    self.minigrid = {};
    
    for r = 1, self.numRows do
      self.minigrid[r] = {}
    for c = 1, self.numCols do
    
      self.minigrid[r][c] = {};
      
    end
    end
    
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
    
    self:setLevel("multi");

end


function Grid:updateEffects(state)

  local didPlay = false;
  local highestRow = -1;
  
  self.animating = self.animating - state.dt * 1.5;
  
  self:eachBlock(function(blk, r, c)
  
    if (blk.shrink ~= nil) then
        blk.shrink = blk.shrink - state.dt * 8.5;
        self.animating = 1;
        
        if (blk.shrink < 0) then
            blk.shrink = nil;
            blk.willBurst = nil;
        end
    end
  
    if (blk.willBurst and blk.shrink < 1.0) then
    
        blk.willBurst = nil;
        
        state.score = state.score + 10;

        if (not didPlay) then
            didPlay = true;
            Assets.sounds.chip:play();
        end
        
        self.textAnim:addAnimation("+10", nil, {
            duration = 0.5,
            x = state.gfx.tileOffsetX(c + 0.2),
            y = state.gfx.tileOffsetY(r + 0.7 + self.yOffset),
            size = State.gfx.fontScale(1)
        });
    end
    
    if (blk.status == 1 and r > highestRow) then
      highestRow = r;
    end
  
  end);
  
  self.danger = highestRow / self.numRows;

  didPlay = false;
  self:eachGem(function(gem)
  
    if (gem.shrink ~= nil) then
                
        self.animating = 1;

        if (gem.shrink > 1) then
            gem.shrink = gem.shrink - state.dt * 8.5;
        elseif (gem.shrink < 0) then
            gem.shrink = nil;
            self.gems[gem.id] = nil;
        else
            --gem.shrink = gem.shrink - state.dt * 10.0 / math.min(gem.w, gem.h);
            gem.shrink = gem.shrink - state.dt * 8.0 / math.min(gem.w, gem.h);
        end
    end
  
    if (gem.willBurst and gem.shrink < 1.0) then
    
        if (not didPlay) then
            didPlay = true;
            Assets.sounds.glass:play();
        end
        
        local gmScore = self:gemScore(gem.w, gem.h);
    
        state.score = state.score + gmScore;
    
        gem.willBurst = nil;
        self.textAnim:addAnimation("+" .. gmScore, nil, {
            duration = 1.5,
            x = state.gfx.tileOffsetX(gem.c + 0.2 * gem.w),
            y = state.gfx.tileOffsetY(gem.r + self.yOffset + 0.7 * gem.h),
            size = State.gfx.fontScale(2)
        });
        
        local s = love.graphics.newParticleSystem(Assets.images.shard, 150);
        s:setParticleLifetime(0.5, 1.0) 
        s:setEmissionRate(0)
        s:setSizes(0.05, 0.03)
        s:setEmissionArea("uniform", state.gfx.tileSize(gem.w * 0.4), state.gfx.tileSize(gem.h * 0.4), 0, false);
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

        if (not self.multi) then
            gem.shards = s;
        end
        
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
  
  local p = (State.score - base) / (LEVELS[self.levelNumber][4] - base);
  
  p = math.max(p, 0.0);
  p = math.min(p, 1.0);
  return p;
  
end

function Grid:drawProgressBar(state, gfx)
    
    if (self.levelNumber == "multi") then return end
    
    local dangerThresh = 0.55;
    local dangerFlash = math.max((self.danger - dangerThresh) * 2.0, 0.0); 
    dangerFlash = math.abs(0.5 * dangerFlash * math.cos(State.clock * 6.0));

    self.dangerFlash = dangerFlash;
   
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
        gfx.tileSize(w), gfx.tileSize(self.config.maxRows - 1) * self:getPercentFinished()
    );
    
    love.graphics.setColor(0.5 + dangerFlash, 0.5 - dangerFlash * 0.5, 0.5 - dangerFlash, 0.5 + dangerFlash);
    
    gfx.rect("line", 
        gfx.tileOffsetX(o), gfx.tileOffsetY(2), 
        gfx.tileSize(w), gfx.tileSize(self.config.maxRows - 1)
    );

end

function Grid:drawBorder(gfx)
 love.graphics.setColor(1,1,1,1);
    
    love.graphics.setShader(Assets.shaders.border);
    Assets.shaders.border:send("scale", {gfx.tileSize(1), gfx.tileSize(1)});
    
    love.graphics.draw(Assets.meshes.border,
      gfx.tileOffsetX(1),
      gfx.tileOffsetY(2)
    );
    
    love.graphics.setShader();
end;

function Grid:draw(state, gfx)
   

   
    local clr = love.graphics.setColor;
   
    --self:drawBorder(gfx); 
      
    self:drawProgressBar(state, gfx);
    
    love.graphics.setLineWidth(state.unit);
    love.graphics.setColor(0.0, 0.0, 0.0, 1.0);

    love.graphics.setScissor( gfx.tileOffsetX(1), gfx.tileOffsetY(2), gfx.tileSize(self.numCols), gfx.tileSize(self.numRows - 1))
    
    gfx.rect("fill", 
        gfx.tileOffsetX(1), gfx.tileOffsetY(2), 
        gfx.tileSize(self.numCols), gfx.tileSize(self.numRows - 1)
    );
    
    love.graphics.setShader(Assets.shaders.gem);

        
    --draw blocks
    self:eachBlock(function(blk,r , c)
        
        clr(blk.config.color);
        
        if (blk.gem) then
            
            --
        
        elseif (blk.status == 1) then
            
            gfx.drawTile(c, r + self.yOffset, blk);
                        
        elseif (blk.shrink) then
        
            gfx.drawTile(c, r + self.yOffset, blk);
            
        end   
    end);
    
    --draw gems
    for k,gem in pairs(self.gems) do
        if (gem) then
    
            gfx.drawGem(gem, self.yOffset);
          
        end
    end
    
    love.graphics.setShader();

    love.graphics.setScissor(0, 0, State.width, State.height);
    
    local dangerFlash = self.dangerFlash or 0;
    love.graphics.setColor(0.5 + dangerFlash, 0.5 - dangerFlash * 0.5, 0.5 - dangerFlash, 0.5 + dangerFlash);

    gfx.rect("line", 
        gfx.tileOffsetX(1), gfx.tileOffsetY(2), 
        gfx.tileSize(self.numCols), gfx.tileSize(self.config.maxRows - 1)
    );
    
    self:eachGem(function(gem) 
      
      love.graphics.setColor(gem.config.color);
    
       if (gem.shards) then        
          love.graphics.draw(gem.shards, 
            gfx.tileOffsetX(gem.c + gem.w * 0.5),
            gfx.tileOffsetY(gem.r + gem.h * 0.5 + self.yOffset) 
          );
        end  
    end);
    
    if (self.textAnim) then
        self.textAnim:draw();
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

function Grid:serialize(dataOut)
    
    self:eachBlock(function(blk, r, c)
    
      self.minigrid[r][c].s = blk.status;
      self.minigrid[r][c].c = blk.config.index;
      
      if (blk.gem) then
        self.minigrid[r][c].s = 0;
      end
      
    end);
    
    
    dataOut.numRows = self.numRows;
    dataOut.numCols = self.numCols;
    dataOut.yOffset = self.yOffset;
    dataOut.minigrid = self.minigrid;
    --dataOut.blocks = self.blocks;
    
    dataOut.gems = self.gems;

end

function Grid:deserialize(dataIn)
    
    if (dataIn == nil) then return end
    
    for k,v in pairs(dataIn) do
        self[k] = v;
    end

    if (self.minigrid) then
      self:eachBlock(function(blk, r, c) 

        blk.status = self.minigrid[r][c].s;
        blk.config = BlockTypeArray[self.minigrid[r][c].c];
        blk.gem = nil;
        blk.shrink = nil;
      end);
    end
    
end

function Grid:triggerBlock(br, bc)
    --Assets.sounds.bomb:play();

    local config = self.blocks[br][bc].config;
    local toCheck = Queue:new{};
    
    self.animating = 1;
    local clearAll = false;
    
    local tmpScore = State.score;
    
    toCheck:pushright({br, bc, 0});
    
    while(not toCheck:isEmpty()) do
        
        local current = toCheck:popleft();
        local r,c = current[1], current[2];
        local dist = current[3];
        
        if (self.blocks[r] and self.blocks[r][c]) then
            blk = self.blocks[r][c];
            if (blk.status == 1 and (blk.config == config or clearAll)) then
            
                blk.status = 0;
                
                if (blk.gem) then
                
                    if (blk.gem.shrink == nil) then
                        blk.gem.shrink = blk.gem.shrink or (1 + dist);
                        blk.gem.willBurst = true;
                        local score = self:gemScore(blk.gem.w, blk.gem.h);
                        --State.score = State.score + score;
                        tmpScore = tmpScore + score;
                    else
                        dist = dist - 1;
                    end
                    
                    
                else
                    --State.score = State.score + 10;
                    tmpScore = tmpScore + 10;
                    blk.shrink = 1 + dist;
                    blk.willBurst = true;
                end
                
                toCheck:pushright{r-1, c, dist+1};
                toCheck:pushright{r+1, c, dist+1};
                toCheck:pushright{r, c+1, dist+1};
                toCheck:pushright{r, c-1, dist+1};
            
            end

            if (not self.multi and tmpScore > LEVELS[self.levelNumber][4]) then
                clearAll = true;
                State.launcher:pause();
            end
        end
    
    end
end

function Grid:gemScore(w, h)
    
    if (w <= 1 or h <= 1) then
        return 0;
    end
    
    return math.min(w,h) * 100 + math.max(w,h) * 10;
    
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
    
    if (br >= self.numRows or pr >= self.numRows) then
        
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
    local maxShrink = -1;
    
    self:eachBlock(function(block)
        block.checked = false;
        block.canBeFilled = false;
        
        if (block.shrink and block.shrink > maxShrink) then
            maxShrink = block.shrink;
        end
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
            if (block.gem) then
                block.gem.shrink = maxShrink + 2;
                block.shrink = nil;
                block.gem.willBurst = true;
            else
                block.shrink = maxShrink + 2;
                block.willBurst = true;
            end
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
        self.loseFlag = true;
        
    end      
    
    return didLose;

end

function Grid:pause()
    self.paused = true;
end

function Grid:unpause()
  self.paused = false;
end

function Grid:updateRemote(state)
    
    self.textAnim:update(state.dt);

end

function Grid:update(state)

    self:updateEffects(state);
    self.textAnim:update(state.dt);
    
    if (State.paused or self.paused) then
        return
    end;
    
    if (self.musicCounter and self.musicCounter > 0) then
      self.musicCounter = self.musicCounter - state.dt;
      if (self.musicCounter <= 0) then
        Assets.sounds.music:play();
      end
    end
    
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
    
    --self.position:addScaled(self.direction, state.dt * GEM_SPEED);
    
end

function Projectile:draw(gfx)
    
    if (self.isBomb) then
        love.graphics.setColor(1, 1, 1, 1);
    else
        love.graphics.setColor(self.config.color);
    end
    
    gfx.drawTile(self.position.x, self.position.y, self);

end


Launcher = Class:new();

function Launcher:init()
    
    
    self.indicatorDelta = vec2(0, 1);
    self.indicatorAngle = 0;
    self.reloadTime = 0;
        
    self:reset();
    
end

function Launcher:reset()
    self.bombTracker = 1;
    self.spamAmt = 0;
    self.projectiles = {};
    self.position = vec2(State.grid.numCols / 2 + 0.5, State.grid.config.maxRows + 1.2);
    self.projectileUUID = 1;
    
    self.nextProjectile = self:createProjectile();
    self.nextProjectile.position:copy(self.position);
    self.nextProjectile.shrink = 1.0;
    self.projectileOnDeck = self:createProjectile();
    
end

function Launcher:createProjectile()
    
    local projectile = Projectile:new({
        position = vec2(self.position.x , self.position.y + 1.0),
        uuid = self.projectileUUID,
        shrink = 0.3
    });
    
    self.bombTracker = self.bombTracker + 1;
    local chance = (1.0 - State.grid.config.bombChance) * 50.0 * math.random();
    
    if (self.bombTracker > chance) then
        
        projectile.config = {
            color = {1,1,1,1},
            facets = 3
        };
    
        projectile.isBomb = true;
        self.bombTracker = 1;
    else
        projectile.config = State.grid:sampleBlockConfigs();
    end
    
    self.projectileUUID = self.projectileUUID + 1;
    
    return projectile;
    
end

function Launcher:fire(x, y) 

    if (State.paused or self.paused or self.reloadTime < 1.0) then
        return
    end

    self.reloadTime = 0;
    
    Assets.sounds.zap:play();
    
    local projectile = self.nextProjectile;
    
    if (x == nil) then
        projectile.direction = vec2(self.indicatorDelta.x, self.indicatorDelta.y);
    else
        projectile.direction = vec2(x - self.position.x, y - self.position.y);  
    end
    
    projectile.direction:normalize();
    projectile.direction.y = math.min(projectile.direction.y, - 0.5);
    projectile.direction:normalize();

    projectile.position = vec2(self.position.x, self.position.y);    
    --projectile.uuid = self.projectileUUID;

    
    self.projectiles[projectile.uuid] = projectile;
    --self.projectileUUID = self.projectileUUID + 1;
    
    self.nextProjectile = self.projectileOnDeck;
    self.nextProjectile.shrink = 1.0;
    self.nextProjectile.position:set(self.position.x, self.position.y);
    self.projectileOnDeck = self:createProjectile();
    
end

function Launcher:eachProjectile(fn)

    for uuid, proj in pairs(self.projectiles) do
        if proj then
            fn(proj);
        end
    end
    
end

math.sign = function(x) 
    if (x == 0) then return 0 else return x / math.abs(x) end;
end

function Launcher:setTarget(x, y)

  local cx, cy = self.indicatorDelta.x, self.indicatorDelta.y;
  
  self.indicatorDelta:set(x, y);
  self.indicatorDelta:sub(self.position);
  self.indicatorDelta:normalize();
  
  if (self.indicatorDelta.y > -0.3) then
    self.indicatorDelta:set(cx, cy);
  end
  
  self.indicatorAngle = -math.sign(self.indicatorDelta.x) * math.acos(-self.indicatorDelta.y);
  
end

local indicatorTemp = vec2(0,0);
function Launcher:drawIndicator(gfx)
  
  if (self.reloadTime < 1.0) then
    return;
  end
  
  local cycleT = State.clock % 1.0 - 1.0;
  --cycleT = 0;
  
  for i = 1, 4 do
  
    --cycle = (cycle + 0.4) % 1.2;
    
    local increment = i;    

    indicatorTemp:set(self.position.x, self.position.y);
    indicatorTemp:addScaled(self.indicatorDelta, increment * 1);
    
    gfx.drawIndicator(indicatorTemp.x, indicatorTemp.y, (math.sin(-State.clock * 10.0 + i) * 0.1 + 0.8) * (2.0 - (i * 0.4)));
    
  end

end

function Launcher:drawProjectile(proj, gfx)
  
    gfx.drawTile(proj.position.x, proj.position.y, proj);
  
end

function Launcher:draw(gfx)
    
    love.graphics.setShader(Assets.shaders.gem);
    
      love.graphics.setScissor( gfx.tileOffsetX(1), gfx.tileOffsetY(2), gfx.tileSize(State.grid.numCols), gfx.tileSize(State.grid.numRows - 1))
    
    self:eachProjectile(function(proj) 
      self:drawProjectile(proj, gfx);
    end);

    love.graphics.setScissor(0, 0, State.width, State.height);

    
    self:drawProjectile(self.nextProjectile, gfx);
    self:drawProjectile(self.projectileOnDeck, gfx);
    love.graphics.setShader();

    self:drawIndicator(gfx);
end

function Launcher:pause()
    self.paused = true;
end

function Launcher:update(state)

    self.reloadTime = self.reloadTime + state.dt / RELOAD_DURATION;

    self:eachProjectile(function(proj) 
        
        --[[
        proj:update(state)

        if State.grid:considerProjectile(proj) then
            self.projectiles[proj.uuid] = nil;
        end
        ]]
        
        for i = 1,10 do
        
            proj.position:addScaled(proj.direction, state.dt * GEM_SPEED / 10.0);
            if state.grid:considerProjectile(proj) then
                self.projectiles[proj.uuid] = nil;
                return;
            end
        end
        
    end);
    
    if (self.spamAmt > 0.0) then
        
        local tmp = math.floor(self.spamAmt);
        self.spamAmt = self.spamAmt - state.dt * 3;
        
        if (self.spamAmt < tmp) then
            self:launchSpam()
        end
        
    end

end


function Launcher:launchSpam()
    
    local proj = Projectile:new({
        position = vec2(randFloat(1, State.grid.numCols), self.position.y),
        direction = vec2(-randFloat(0.15, 0.15), -1),
        uuid = self.projectileUUID,
        config = SpamBlockArray[math.random(2)]
    });
    
    proj.direction:setMag(1.3);
    self.projectiles[self.projectileUUID] = proj;
    
    self.projectileUUID = self.projectileUUID + 1;

end

function Launcher:spam(amt)

    self.spamAmt = self.spamAmt + amt;
    
end

function Launcher:rotate(angle)

    angle = angle * State.dt;
    
    if (math.abs(self.indicatorAngle + angle) > math.acos(0.3)) then
        return;
    end
    
    self.indicatorAngle = self.indicatorAngle + angle;
    self.indicatorDelta:set(-math.sin(self.indicatorAngle), -math.cos(self.indicatorAngle));
    
    
end

function resize(w, h)
    State.width = w;
    State.height = h;
    State.unit = h * POINT_SIZE; --math.min(w * POINT_SIZE, h * POINT_SIZE)
    
    local centerx = w / 2;
    
    local halfTiles = 4;
    
    if (State.grid and State.grid.numCols) then
        halfTiles = State.grid.numCols / 2;
    end
      
    local oldCenter = State.gfxCenter;
    
    
    State.gfxCenter = generateGfxContext(1, 
      centerx / State.gfx.pts(1) - State.gfx.tileSize(halfTiles + 1) / State.gfx.pts(1), 
      -5
     );
     
     State.gfxLeft = generateGfxContext(1, centerx / State.gfx.pts(1) - State.gfx.tileSize(9) / State.gfx.pts(1), -5);
     
     State.gfxRight = generateGfxContext(1, centerx / State.gfx.pts(1) + State.gfx.tileSize(0) / State.gfx.pts(1), -5);
     
     if (State.gfx == oldCenter) then
      State.gfx = State.gfxCenter;
     else 
      State.gfx = State.gfxLeft
     end

end


function love.resize(w, h)
    resize(w,h);
end

local spamState = {
    
    lastScore = nil

}


function client.connect() -- Called on connect from server
    print("Connected")
end

function client.disconnect() -- Called on disconnect from server
    print("disconnected")
end


function client.receive(msg) 
   
   if (msg.lost) then
    
      if (msg.lost ~= client.id) then
        State.grid:displayText("Winner");
        Assets.sounds.win:play();
      else
        State.grid:displayText("Loser");
        Assets.sounds.lose:play();
      end
      
      
    State.score = 0;
    State.grid:setLevel("multi");
    State.grid:unpause()
    
   end
   
end


function drawUI(state)

    love.graphics.setColor(1,1,1,1);
    
    local fsize = State.gfx.fontScale(2)
    love.graphics.print("Lv " .. State.grid.levelNumber, State.gfx.tileOffsetX(1), State.gfx.tileOffsetY(1.2), 0, fsize, fsize);
    
    if (State.grid and State.grid.levelNumber ~= "multi") then
      love.graphics.print(State.score .. " / " .. State.grid.config.scoreNeeded,  State.gfx.tileOffsetX(State.grid.numCols - 2), State.gfx.tileOffsetY(1.2), 0, fsize, fsize);
    end
    
end


function drawMultiplayer()

  if (State.remoteGrid) then
      State.remoteGrid:draw(State, State.gfxRight);
  end
  
  if (State.remoteLauncher) then
      setmetatable(State.remoteLauncher, Launcher);
      State.remoteLauncher:draw(State.gfxRight);
  end

end

SaveData = {
  level=1,
  score=0,
  bestScore=0
};

function loadSaveData()
  
  local file = love.filesystem.read("GemzenSave.txt");
  
  if (file == nil) then
    return
  end
  
  function splitString(inputstr, sep)
      if sep == nil then
              sep = "%s"
      end
      local t={} ; i=1
      for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
              t[i] = str
              i = i + 1
      end
      return t
  end
  
  local fields = splitString(file, ";");
  
  
  for k,v in pairs(fields) do
    
    local parts = splitString(v, "=");
    SaveData[parts[1]] = tonumber(parts[2]);
    
  end
  
  
  State.score = SaveData.score;
end

function writeSaveData()


  SaveData.level = State.grid.levelNumber;
  SaveData.score = State.score;
  SaveData.bestScore = math.max(SaveData.bestScore, State.score);

  local file = love.filesystem.write("GemzenSave.txt", "level="..SaveData.level..";score="..SaveData.score..";best_score="..SaveData.bestScore);	

  
end

function goNextLevel()
  
    if (LEVELS[State.grid.levelNumber+1] == nil) then
      State.mode = State.credits;
      
      State.grid.levelNumber = 1;
      State.grid.numCols = 8;
      resize(State.width, State.height);
      SaveData.score = 0;
      
      writeSaveData();
      
      return;
    end

   State.grid:nextLevel();
   resize(State.width, State.height);
   State.launcher:reset();
   Assets.sounds.win:play();
   
   writeSaveData();
end

local cnt = 0;
local stateshare = {};


TypeMap = {
  v2 = Vec2,
  prj = Projectile,
  lnch = Launcher
}

for k,v in pairs(TypeMap) do
  v.typename = k;
end

function updateMultiplayer()

    State.grid:serialize(stateshare);
    
    client.home.gridState = stateshare;
    client.home.score = State.score; 
    client.home.launcher = State.launcher;
    
    if (State.grid.loseFlag) then
      State.grid.loseFlag = false;
      State.grid:pause();
      client.send({
        lost = client.id,
      });
    end
    
    if (client.share.players ~= nil) then
    
        local remoteState = nil;
        
        for id, v in pairs(client.share.players) do
           if (client.id ~= id) then
              remoteState = v
           end
        end
        
        if (not remoteState) then
          remoteState = client.share.players[client.id]
        end
    
        --play yourself
        --local remoteState = client.share.players[client.id]
        
        --State.remoteGrid:deserialize(remoteState.gridState);
        State.remoteGrid:deserialize(stateshare);
        
        
        if (remoteState.launcher) then
          State.remoteLauncher = remoteState.launcher;
        end
        
        --Spam player
        
        local remoteScore = remoteState.score or 0;
        
        if (not spamState.lastScore) then
          spamState.lastScore = remoteScore
          return;
        end
        
        if (remoteScore - spamState.lastScore > SPAM_INCREMENT) then
            
            local amt = math.floor((remoteScore - spamState.lastScore) / SPAM_INCREMENT);
            spamState.lastScore = remoteScore;
            State.launcher:spam(amt);
        
        elseif (remoteScore < spamState.lastScore) then
            spamState.lastScore = remoteScore;
        end
    end
    
    
    State.remoteGrid:updateRemote(State);

end


local GameMode = Class:new();

function GameMode:keypressed(k) end
function GameMode:mousemoved(x,y) end
function GameMode:mousepressed(x,y) end

State.mode = GameMode:new();

local MenuMode = GameMode:new();

function MenuMode:init()
    
    local buttonShift = 1;

    self.elems = Array:new {
    
        UI.Button:new {
            text = "Continue",
            x = State.gfx.tileOffsetX(1),
            y = State.gfx.tileOffsetY(6 + buttonShift),
            width = State.gfx.tileSize(7),
            height = State.gfx.tileSize(2),
            --color = BlockType.Red.color,
            gem = {
                c = 1,
                r = 6 + buttonShift,
                w = 7,
                h = 2,
                shrink = 1,
                config = BlockType.Red
            },
            size = State.gfx.fontScale(2),
            action = function() 
                State.play:initSingleplayer(false);
                State.launcher:reset();
                State.mode = State.play;
                Assets.sounds.glass:play()
            end
        },
        
        
        UI.Button:new {
        
            text = "New Game",
            x = State.gfx.tileOffsetX(1),
            y = State.gfx.tileOffsetY(9 + buttonShift),
            width = State.gfx.tileSize(7),
            height = State.gfx.tileSize(2),
            --color = BlockType.Blue.color,
            size = State.gfx.fontScale(2),
            gem = {
                c = 1,
                r = 9 + buttonShift,
                w = 7,
                h = 2,
                shrink = 1,
                config = BlockType.Green
            },
            action = function() 
                State.play:initSingleplayer(true); 
                State.launcher:reset();
                State.mode = State.play;
                Assets.sounds.glass:play()
            end
        },
        
        UI.Button:new {
        
            text = "Multiplayer",
            x = State.gfx.tileOffsetX(1),
            y = State.gfx.tileOffsetY(12 + buttonShift),
            width = State.gfx.tileSize(7),
            height = State.gfx.tileSize(2),
            --color = BlockType.Blue.color,
            size = State.gfx.fontScale(2),
            gem = {
                c = 1,
                r = 12 + buttonShift,
                w = 7,
                h = 2,
                shrink = 1,
                config = BlockType.Blue
            },
            action = function() 
                State.play:initMultiplayer(); 
                State.launcher:reset();
                State.mode = State.play;
                Assets.sounds.glass:play()
            end
        }
        
    };
    
end

function MenuMode:draw()
    
    self.elems:each(function(elem)
        
        elem.x = State.gfx.tileOffsetX(1)
        elem.y = State.gfx.tileOffsetY(elem.gem.r)
        elem.width = State.gfx.tileSize(elem.gem.w)
        elem.height = State.gfx.tileSize(elem.gem.h)
        elem.size = State.gfx.fontScale(3),
        
        love.graphics.setShader(Assets.shaders.gem)

        State.gfx.drawGem(elem.gem, 0);        
        love.graphics.setShader();

        elem:draw();
        
    end);
    
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
    --love.graphics.draw(Assets.images.gypsum, State.gfx.tileOffsetX(2.1),State.gfx.tileOffsetY(3), 0, State.gfx.pts(1) * 0.15, State.gfx.pts(1) * 0.15); 
        love.graphics.setFont(Assets.fonts.megrim);

    love.graphics.print("GemZen", State.gfx.tileOffsetX(0.22),State.gfx.tileOffsetY(2), 0, State.gfx.fontScale(3), State.gfx.fontScale(3));
    
    love.graphics.setFont(Assets.fonts.sans);
end

function MenuMode:update(dt)


end

function MenuMode:mousemoved(x,y)

    
    self.elems:each(function(elem)
        if(elem:isHover(x,y)) then
            if (elem.gem.shrink < 1) then
              elem.gem.shrink = 1;
              Assets.sounds.chip:play();
            end
        else
            elem.gem.shrink = 0.95;
        end
    end);
    
end

function MenuMode:mousepressed(x, y)

    self.elems:each(function(elem)
        
        if(elem:isHover(x,y)) then
            elem.action();
        end
        
    end);

end

local CreditMode = GameMode:new()

function CreditMode:update(dt)
  
  State.clock = State.clock + dt;
  State.bgTime = State.bgTime - math.max(dt * 50.0, (State.bgTime + State.clock) * dt);
  
end

function CreditMode:mousepressed()
  
  if (State.clock + State.bgTime < 0.0) then
    
    State.score = 0;
    State.clock = 0;
    State.bgTime = 1000;
    State.bgScroll = 0;
    State.grid.textAnim = TextAnimator:new();
  
    writeSaveData();
    
    State.mode = State.menu;
  end

end

function CreditMode:draw()

  love.graphics.setFont(Assets.fonts.megrim);
  love.graphics.print("You Win!", State.gfx.tileOffsetX(-0.2),State.gfx.tileOffsetY(3), 0, State.gfx.fontScale(3), State.gfx.fontScale(3));
  love.graphics.setFont(Assets.fonts.sans);
  
  love.graphics.print("by Oliver Castaneda", State.gfx.tileOffsetX(2),State.gfx.tileOffsetY(7), 0, State.gfx.fontScale(2), State.gfx.fontScale(2));

  
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
  love.graphics.setShader(Assets.shaders.ruby);
  Assets.shaders.ruby:send("scale", {State.gfx.tileSize(5), State.gfx.tileSize(5)});
  Assets.shaders.ruby:send("time", State.clock);
  
  love.graphics.draw(Assets.meshes.quad, 
    State.gfx.tileOffsetX(2),
    State.gfx.tileOffsetY(9)
  );
  
  love.graphics.setShader();
    
  
end


local PlayMode = GameMode:new()

function PlayMode:initMultiplayer()

    State.grid:setLevel("multi");
    
    State.remoteGrid = Grid:new();
    
    State.remoteLauncher = nil;
    
    if not USE_CASTLE_CONFIG then
      client.start('localhost:22122')
    end
    
    self.multi = true;
    
    State.gfx = State.gfxLeft;
end

function PlayMode:initSingleplayer(reset)

    Assets.sounds.music:play();
    
    loadSaveData();
    
    if (reset) then
      SaveData.level = 1;
      SaveData.score = 0;
      State.score = 0;
    end
    
    
    State.grid.numCols = LEVELS[SaveData.level][2];
    resize(State.width, State.height);

    State.gfx = State.gfxCenter;
    State.play.multi = false; 
    State.grid:setLevel(SaveData.level);
    State.gfx = State.gfxCenter;

    if (reset) then
      writeSaveData();
    end
    
end

function PlayMode:update(dt)
    if (State.paused) then
      return
    end
    
    --cnt = cnt + 1;
    --if (cnt % 50 == 0) then print(dt) end

    State.dt = dt;
    State.clock = State.clock + dt;
    if (State.clock > 10000) then
      State.clock = 1000;
    end
    
    State.launcher:update(State);
    
    
    State.launcher:rotate(
        (State.keyboard.a or State.keyboard.left or 0) -
        (State.keyboard.d or State.keyboard.right or 0)
    ); 
    
    local grid = State.grid;
    grid:update(State);

    if (not self.multi and State.score > grid.config.scoreNeeded) then
        grid:pause();
        State.launcher:pause();
        
        if (not grid.animating or grid.animating <= 0) then
            grid.paused = false;
            State.launcher.paused = false;
            State.bgScroll = 1;
            goNextLevel();
        end
        
    end
    
    if (not self.multi and grid.loseFlag) then
      grid.loseFlag = false;
      if (grid.levelNumber ~= "multi") then
            Assets.sounds.lose:play();
            Assets.sounds.music:stop();
            grid.musicCounter = 3.0;
            local prevLevel = LEVELS[grid.levelNumber - 1];
            if (prevLevel ~= nil) then
                State.score = prevLevel[4];
            else
                State.score = 0;
            end
            State.bgScroll = -1;
            grid:setLevel(grid.levelNumber);
        end
    end
    
    if (self.multi and client.connected) then  
      updateMultiplayer();
    end
end

function PlayMode:draw()
   
  State.grid:draw(State, State.gfx);
  State.launcher:draw(State.gfx);
 
  if (self.multi and client.connected) then
    drawMultiplayer();
  elseif (self.multi and not client.connected) then
    love.graphics.setColor(1,1,1,1);
   
    love.graphics.print("Waiting to connect, or service unavailable...",
      State.gfxRight.tileOffsetX(1),
      State.gfxRight.tileOffsetY(3),
      0,
      State.gfxRight.fontScale(1),
      State.gfxRight.fontScale(1)
    );
  end
  
  
  drawUI(State);

end


function PlayMode:mousemoved(x, y)

  if (State.paused) then return end;
  
  local tx, ty = State.gfx.pixToOffset(x, y);
  State.launcher:setTarget(tx - 0.5, ty - 0.5);
   
end

function PlayMode:mousepressed(x, y)
    
    local tx, ty = State.gfx.pixToOffset(x, y);
    State.launcher:fire(tx - 0.5, ty - 0.5);
end

function PlayMode:keypressed(k)

    if (k == "space") then
        State.launcher:fire();
    end
    
   if (k == "p" or k == "escape") then
        State.paused = not State.paused;
    end
    
    --Debugging
    
    --[[
    
    if (k == "o") then
        goNextLevel();
    end
    
    if (k == "l") then
      State.grid.didLose = true;
    end
    
    if (k == "f") then
     State.grid.levelNumber = 1;
     State.grid.numCols = 7;
      resize(State.width, State.height);
        State.mode = State.credits;
    end
    
    ]]

end

function client.load()
    local w, h = love.graphics.getDimensions();
    resize(w,h);
    
    --love.graphics.setBackgroundColor( 0.05, 0.05, 0.05 )
    
    Assets.sounds = {
      zap =     Sound:new("sounds/whoosh.wav", 3),
      chip = Sound:new("sounds/chip2.wav",  15),
      bounce =  Sound:new("sounds/bounce.wav",  5),
      attach =  Sound:new("sounds/ping.wav",  2),
      glass = Sound:new("sounds/glass2.wav",  15),
      lose = Sound:new("sounds/lose.wav"),
      win = Sound:new("sounds/win.wav"),
      music = love.audio.newSource("sounds/music.mp3", "static")
      --bomb = Sound:new("sounds/bomb.wav", 2)
    }  
    
    Assets.sounds.music:setVolume(VOLUME * 3.0);
    Assets.sounds.music:setLooping(true);
    
    for k,v in pairs(Assets.sounds) do
        v:setVolume(VOLUME);
    end
    
    Assets.sounds.zap:setVolume(0.5);
    Assets.sounds.attach:setVolume(VOLUME);
    --Assets.sounds.bomb:setVolume(VOLUME * 0);
    
    Assets.images = {
      --gem =  love.graphics.newImage("images/gem.png"),
      --sheen =  love.graphics.newImage("images/sheen.png"),
      shard =  love.graphics.newImage("images/shard.png"),
      gypsum = love.graphics.newImage("images/gypsum.png"),
      --bg = love.graphics.newImage("images/bg.png"),
      --bomb = love.graphics.newImage("images/bomb.png")
      --diamond = love.graphics.newImage("images/diamond.png")
    }
    
    Assets.fonts = {
        
        --[[
        pixel = love.graphics.newImageFont("images/imagefont.png",
                " abcdefghijklmnopqrstuvwxyz" ..
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
                "123456789.,!?-+/():;%&`'*#=[]\""),
         ]]    
        sans = love.graphics.newFont("fonts/OpenSans-ExtraBold.ttf", 30),
        megrim = love.graphics.newFont("fonts/Megrim.ttf", 100)
                
    
    }

    Assets.shaders = {
    
    --  border = shaders.borderShader(),
      background = Shaders.backgroundShader(),
      ruby = Shaders.rubyShader(),
      gem = Shaders.gemShader()
      
    };
    
    Assets.meshes = {
      
      quad = Shaders.quadMesh()
      --border = Shaders.makeBorderMesh(5, 15)
      
    };
    
    love.graphics.setFont(Assets.fonts.sans);
    
    State.score = 0;
    State.clock = 0;
    State.bgTime = 1000;
    State.bgScroll = 0;
    
    State.grid = Grid:new();
    State.launcher = Launcher:new{};
    
    State.menu = MenuMode:new();
    State.play = PlayMode:new();
    State.credits = CreditMode:new();
    
    State.mode = State.menu;
       
end

function client.update(dt)

  if (State.bgScroll ~= 0.0) then
    local sign = math.sign(State.bgScroll);
    State.bgScroll = State.bgScroll - sign * dt; 
    
    if (math.sign(State.bgScroll) ~= sign) then
      State.bgScroll = 0;
    end
    local scrollDiff = sign * easing.inOutExpo(math.abs(State.bgScroll), 0, 1, 1);
    
    State.bgTime = State.bgTime + scrollDiff;
    
    if (State.bgTime < 0) then
      State.bgTime = 0;
    end
  end
   
    
    State.mode:update(dt);

end

function client.draw()
  
  Assets.shaders.gem:send("time", State.clock);
 
  love.graphics.setShader(Assets.shaders.background);
  
  Assets.shaders.background:send("scale", {State.width, State.height});
  Assets.shaders.background:send("unit", State.unit);
  Assets.shaders.background:send("time", State.clock + State.bgTime);
  Assets.shaders.background:send("flash", State.grid.dangerFlash or 0);
  
  love.graphics.draw(Assets.meshes.quad, 0, 0);
  love.graphics.setShader();
  
  
  love.graphics.setBlendMode("alpha")
  State.mode:draw();
  
  
  if (State.paused) then
    Assets.sounds.music:setVolume(VOLUME * 0.0);

    love.graphics.setColor(0.0, 0.0, 0.0, 0.5);
    love.graphics.rectangle("fill", 0, 0, State.width, State.height);
  else
    Assets.sounds.music:setVolume(VOLUME * 3.0);
  end
  
end

function love.mousemoved( x, y )
 
    State.mode:mousemoved(x,y);
 
end


function love.mousepressed( x, y, button, istouch, presses )
    
    State.mode:mousepressed(x,y);

end

function love.keypressed(k)

    State.keyboard[k] = 1;
    
    State.mode:keypressed(k)

end

function love.keyreleased(k)

    State.keyboard[k] = 0;

end
