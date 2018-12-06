local Class = {}

function Class:new(o)
    o = o or {};
    
    setmetatable(o, self);
    self.__index = self;
    
    if (o.init) then
        o:init();
    end
    
    return o;
end

local Button = Class:new();

local DefaultBackgroundColor = {1,0,0,1}
local DefaultTextColor = {1,1,1,0.8}

function Button:draw()
    
    --love.graphics.setColor(self.backgroundColor or DefaultBackgroundColor);
    --love.graphics.rectangle("fill", self.x, self.y, self.width, self.height);  
    love.graphics.setColor(self.textColor or DefaultTextColor)
    love.graphics.print(self.text, self.x + self.size * 30, self.y + self.size * 15, 0, self.size, self.size);

end

function Button:isHover(x,y)
    
    return x > self.x and x < (self.x + self.width)
        and y > self.y and y < (self.y + self.height);
        
end

return {
    
    Button = Button
    
}