require 'math'

Mat3 = {}


local v3 = {

    normalize = function(v)
        
        local scale = v[1] * v[1] + v[2] * v[2] + v[3] * v[3];
        scale = math.sqrt(scale);
        
        v.x = v.x / scale;
        v.y = v.y / scale;
        v.z = v.z / scale;
    
    end,
    
    dot = function(v1, v2)
       
        return v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3];
    
    end
}

function Mat3:new()
    local m = {{1, 0, 0}, {0, 1, 0}, {0, 0, 1}}
    self.__index = self;
    return setmetatable(m, self);
end

function Mat3:copy(m2)
    
    for i = 1,3 do for j = 1,3 do
        self[i][j] = m2[i][j]
    end end
    
end

local temp0 = Mat3:new();
function Mat3:multiply(m2)
    
    for i = 1,3 do for j = 1,3 do
        temp0[i][j] = 0
        for k = 1, 3 do
          temp0[i][j] = temp0[i][j] + self[i][k] * m2[k][j]
        end
    end end
    
    self:copy(temp0);

end

function Mat3:orthonormalize()
    
end

local temp1 = Mat3:new();
function Mat3:rotateAxisAngle(axis, angle)
    
    --v3.normalize(axis);
    
    local s = math.sin(angle);
    local c = math.cos(angle);
    local oc = 1.0 - c;
    local ax, ay, az = axis[1], axis[2], axis[3];
    
    temp1[1][1] = oc * ax * ax + c;
    temp1[1][2] = oc * ax * ay - az * s;
    temp1[1][3] = oc * az * ax + ay * s;
    
    temp1[2][1] = oc * ax * ay + az * s;
    temp1[2][2] = oc * ay * ay + c;
    temp1[2][3] = oc * ay * az - ax * s;
    
    temp1[3][1] = oc * az * ax - ay * s;
    temp1[3][2] = oc * ay * az + ax * s;
    temp1[3][3] = oc * az * az + c;
    
    self:multiply(temp1);
        
end

return Mat3

