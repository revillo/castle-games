Sound = {}

function Sound:new(filename, cacheSize) 
  
  local o = {};
  o.sources = {};
  o.cacheSize = cacheSize or 2;
  o.sources[1] = love.audio.newSource(filename, "static");
  o.index = 1;
  o.volume = 1;
  for i = 2, o.cacheSize do
    o.sources[i] = o.sources[1]:clone();
  end
  
  self.__index = self;
  setmetatable(o, self);
  return o;

end

function Sound:play()

  self.sources[self.index]:play();
  self.index = (self.index % self.cacheSize) + 1;

end

function Sound:setVolume(vlm)
  
  for i = 1, self.cacheSize do
    self.sources[i]:setVolume(vlm);
  end
  
end


return Sound;
