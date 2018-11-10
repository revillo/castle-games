Queue = {}

function Queue:new (o)
  o = o or {};
  o.first = 0;
  o.last = -1;
  setmetatable(o, self);
  self.__index = self;
  return o;
end

function Queue:isEmpty()
  
  return self.first > self.last;

end

function Queue:pushleft (value)
  local first = self.first - 1
  self.first = first
  self[first] = value
end

function Queue:pushright (value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

function Queue:popleft ()
  local first = self.first
  if first > self.last then return nil end
  local value = self[first]
  self[first] = nil        -- to allow garbage collection
  self.first = first + 1
  return value
end

function Queue:popright ()
  local last = self.last
  if self.first > last then return nil end
  local value = self[last]
  self[last] = nil         -- to allow garbage collection
  self.last = last - 1
  return value
end
    
 return Queue;