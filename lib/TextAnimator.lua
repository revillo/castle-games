TextAnimator = {};


function TextAnimator:new() 
    local o = {};
    o.animations = {};
    o.animID = 1;
    setmetatable(o, self);
    self.__index = self;
    return o;
end


function TextAnimator:addAnimation(text, formatting, animationParams)

    self.animations[self.animID] = {
    
        text = text,
        formatting = formatting,
        params = animationParams,
        t = 0
    
    };
    
    self.animID = self.animID + 1;
    
end

function TextAnimator:eachAnim(fn)

    for i,anim in pairs(self.animations) do
        if (anim) then
            fn(anim, i)
        end
    end

end

function TextAnimator:update(dt)

    self:eachAnim(function(anim, i)
    
        anim.t = anim.t + (dt / anim.params.duration);
        
        if (anim.t > 1) then
            self.animations[i] = nil;
        end
    
    end);
    
    
end

function TextAnimator:draw()
    
    self:eachAnim(function(anim)
        local p = anim.params;
        love.graphics.setColor(1, 1, 1, p.alpha);
        love.graphics.print(anim.text, p.x, p.y, 0, p.size, p.size);
    end);

end


return TextAnimator;