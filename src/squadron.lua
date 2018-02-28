Boid = {}
Boid.dmax = 16
Boid.dmax2 = Boid.dmax^2
Boid.speed = 30
Boid.stubborn = 5
Boid.restSpeed = 1
Boid.restSpeed2 = Boid.restSpeed^2
Boid.dist = 6
Boid.dist2 = Boid.dist^2
Boid.marchDist = 8
Boid.marchDist2 = Boid.marchDist^2

Boid.leader = nil
Boid.all = {}
Boid.__index = Boid

function Boid.new(pos)
  local self = setmetatable({}, Boid)
  
  self.pos = pos
  self.move = vector.new(0, 0)
  self.face = vector.new(0, 1)
  self.color = newColor(1-math.random()*.5, math.random(), math.random(), "lch")
  
  table.insert(Boid.all, self)
  
  return self
end

function Boid.newLeader(pos)
  local self = setmetatable({}, Boid)
  
  self.pos = pos
  self.move = vector.new(0, 0)
  self.face = vector.new(0, 1)
  self.color = newColor(1-math.random()*.5, math.random(), math.random(), "lch")
  
  self.speed = 35
  
  Boid.leader = self
  self.update = Boid.updateLeader
  
  return self
end

function Boid:update(dt, neb)
  local arrange = self.formPos and self.formPos.target - self.pos or vector.new(0, 0)
  local avoid = vector.new(0, 0)
  
  for i, n in ipairs(neb) do
    local diff = n.pos - self.pos
    if diff:mag2() < self.dist2 then
      avoid = -diff:rescale(100/diff:mag())
    end
  end
  
  self.move = avoid + arrange
  
  
  if self.move:mag2() < self.restSpeed2 then self.move = vector.new(0,0) end
  self.move = self.move:clamp(0, self.speed)
  self.face = (self.face + self.move * dt/self.stubborn):unit()--:clamp(0, 1)
  self.pos = self.pos + (self.move + self.face:rescale(self.move:proj(self.face):mag()))/2 * dt
  self.pos = self.pos + self.move * dt
end

function Boid:updateLeader(dt, neb)
  local mPos = vector.new(love.mouse.getPosition())
  self.move = mPos - self.pos
  
  if self.move:mag2() < self.restSpeed2 then self.move = vector.new(0,0) end
  self.move = self.move:clamp(0, self.speed)
  self.face = (self.face + self.move * dt/self.stubborn):unit()--:clamp(0, 1)
  self.pos = self.pos + (self.move + self.face:rescale(self.move:proj(self.face):mag()))/2 * dt
  
  if self.formation then self:updateFormation() end
end

function Boid:updateFormation()
  local lY = -self.face:unit()
  local lX = self.face:crossL():unit()
  for y = 1, self.formation.height do
    local w = #self.formation[y]
    for x = 1, w do
      self.formation[y][x].target = self.pos + lX * (x - (w+1)/2) * self.marchDist + lY * y * self.marchDist
    end
  end
end

function Boid:drawFormation()
  if not self.formation then return false end
  love.graphics.setColor(255, 255, 255, 31)
  for y = 1, self.formation.height do
    local w = #self.formation[y]
    for x = 1, w do
      love.graphics.circle("line", self.formation[y][x].target.x, self.formation[y][x].target.y, 4)
    end
  end
end

function Boid:createFormation(soldiers, width)
  local count = #soldiers
  local lY = -self.face:unit()
  local lX = self.face:crossL():unit()
  local i = 1
  self.formation = {width = width, height = math.ceil(count/width), count = count}
  for y = 1, self.formation.height do
    self.formation[y] = {}
    local w = (y == self.formation.height and (count-1) % width + 1) or width
    for x = 1, w do
      self.formation[y][x] = {}
      self.formation[y][x].target = lX * (x - (w+1)/2) + lY * y
      self.formation[y][x].soldier = soldiers[i]
      i = i+1
      self.formation[y][x].soldier.formPos = self.formation[y][x]
    end
  end
end

function Boid:addToFormation(soldier)
  
end

function Boid:removeFromFormation(soldier)
  local xp, yp = 0, 0
  for y = 1, self.formation.height do
    for x = 1, #self.formation[y] do
      if self.formation[y][x].soldier == soldier then
        xp, yp = x, y
        soldier.formPos = nil
      end
    end
  end
  
  if xp == 0 or yp == 0 then return false end
  local xpc = math.ceil(#self.formation[yp]/2) - xp
  
  for y = yp, #self.formation-1 do
    x1 = math.clamp(math.ceil(#self.formation[y]/2) - xpc, 1, #self.formation[y])
    x2 = math.clamp(math.ceil(#self.formation[y+1]/2) - xpc, 1, #self.formation[y+1])
    self.formation[y][x1].soldier = self.formation[y+1][x2].soldier
    self.formation[y][x1].soldier.formPos = self.formation[y][x1]
  end
  local x2 = math.clamp(math.ceil(#self.formation[#self.formation]/2) - xpc, 1, #self.formation[#self.formation])
  table.remove(self.formation[#self.formation], x2)
  if #self.formation[#self.formation] == 0 then
    self.formation[#self.formation] = nil
    self.formation.height = #self.formation
  end
end
