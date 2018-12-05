require 'math'

Vec2 = {}

function Vec2:new(v)
  
  v = v or {}
  
  o = {
    x = v.x or 0,
    y = v.y or 0
  }
  
  self.__index = self
  return setmetatable(o, self)
end

function Vec2:add(v)
  self.x = self.x + v.x
  self.y = self.y + v.y
end

function Vec2:addScaled(v, s)
  self.x = self.x + v.x * s;
  self.y = self.y + v.y * s;
end

function Vec2:clone()
    return Vec2:new({x=self.x, y=self.y});
end

function Vec2:addX(s)
    self.x = self.x + s;
end

function Vec2:addY(s)
    self.y = self.y + s;
end

function Vec2:sub(v)
  self.x = self.x - v.x
  self.y = self.y - v.y
end

function Vec2:mult(s)
  self.x = self.x * s
  self.y = self.y * s
end

function Vec2:div(s)
  if s  == nil or s == 0 then
    s = 1
  end
  
  self.x = self.x / s
  self.y = self.y / s
end

function Vec2:mag()
  return math.sqrt(self.x * self.x + self.y * self.y)
end

function Vec2:mag_sq()
  return self.x * self.x + self.y * self.y
end


function Vec2:dist(v)
  local dx = self.x - v.x
  local dy = self.y - v.y
  
  return math.sqrt(dx * dx + dy * dy)
end

function Vec2:dot(v)
  return self.x * v.x + self.y * v.y
end

function Vec2:normalize()
  local m = self:mag()
  if (m ~= 0 and m ~= 1) then
    self:div(m)
  end
end

function Vec2:limit(max)
  local m = self.mag_sq()
  if (m >= max * max) then
    self:normalize()
    self:mult(max)
  end
end

 function Vec2:setMag(length)
  self:normalize()
  self:mult(length)
 end
 
 function Vec2:heading()
  local angle = math.atan2(-self.y, self.x)
  return -1 * angle
end

function Vec2:rotate(theta)
  local tempx = self.x
  self.x = self.x * math.cos(theta) - self.y * math.sin(theta)
  self.y = tempx * math.sin(theta) + self.y * math.cos(theta)
end

function Vec2:angle_between(v1, v2)
  if v1.x == 0 and v1.y then 
    return 0
  end
  
  if v2.x == 0 and v2.y == 0 then
    return 0
  end
  
  local dot = v1.x * v2.x + v1.y * v2.y 
  local v1mag = math.sqrt(v1.x * v1.x + v1.y * v1.y)
  local v2mag = math.sqrt(v2.x * v2.x + v2.y * v2.y)
  local amt = dot / (v1mag * v2mag)
  
  if amt <= -1 then
    return math.pi
  elseif amt >= 1 then
    return 0
  end
  
  return math.acos(amt)
end

function Vec2:set(x, y)
  self.x = x
  self.y = y
end

function Vec2:copy(v2)
  self.x = v2.x
  self.y = v2.y
end

function Vec2:equals(o)
  o = o or {}
  return self.x == o.x and self.y == o.y
end

function Vec2:__tostring()
  return 'x = ' .. self.x  .. ', y = ' .. self.y
end

return Vec2

