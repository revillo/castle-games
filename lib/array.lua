Array = {};

function Array:new(t) 
    t = t or {};
    t.length = #t;
    self.__index = self;
    return setmetatable(t, self);
end

function Array:push(v) 
    self[self.length + 1] = v;
    self.length = self.length + 1;
end

function Array:pop() 
    if (self.length == 0) then
        return nil;
    end
    
    local tmp = self[self.length];
    table.remove(self, self.length);
    self.length = self.length - 1;
    return tmp;
end

function Array:each(fn) 

    for i = 1,self.length do
        fn(self[i]);
    end
    
end

function Array:removeValue(v)
  
  local i = 1;
  
  while (self[i] ~= nil) do
    
    if (self[i] == v) then
      table.remove(self, i);
      self.length = self.length - 1;
    else
      i = i + 1
    end
    
  end
  
end

function Array:last()
    
    return self[self.length];

end

function Array:shift()
  
  if (self.length > 0) then
    self.length = self.length - 1;
    table.remove(self, 1);
  end

end

function Array:first()
    return self[1];
end

function Array:log()
  for i = 1, self.length do
    print(self[i]);
  end
end

return Array