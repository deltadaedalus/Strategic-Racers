require "road"
require "segment"
require "gUtil"

Boid = {}
Boid.__index = Boid

Boid.planners = require("SegmentConstruct")
Boid.newPlanDepth = 4
Boid.maxPlanDepth = 4
Boid.dmax = 16
Boid.dmax2 = Boid.dmax^2
Boid.wheelBase = 8

Boid.fM = 20  --max resistive acceleration of friction
Boid.aM = 10  --max acceleration torque
Boid.bM = 20  --max braking torque
Boid.sM = 1   --max steering angle

Boid.tickDrag = 0.1
Boid.drag = Boid.tickDrag / (1 + Boid.tickDrag * 1/60)

Boid.slipFigure = {
  --max Steer given Velocity and Acceleration
  maxS = function(boid, v, a, b)
    return math.min(math.abs(math.atan(boid.wheelBase/(v*v) * math.sqrt(boid.fM^2 - math.abs(a-b)^2))), boid.sM) end,
  
  --max Acceleration given Velocity and Steer
  maxA = function(boid, v, s)
    local a = math.min(math.sqrt(math.max(boid.fM^2 - ((v*v / boid.wheelBase) * math.tan(s))^2), 0), boid.aM)
    return a end,
    
  --max Brake given Velocity and Steer (same as accel but different maximum)
  maxB = function(boid, v, s)
    return math.min(math.sqrt(math.max(boid.fM^2 - ((v*v / boid.wheelBase) * math.tan(s))^2, 0)), boid.bM) end,
    
  --max Velocity given Steer and Acceleration
  maxV = function(boid, s, a, b)
    local v = math.sqrt(boid.wheelBase * math.sqrt(boid.fM^2 - math.abs(a-b)^2) / math.abs(math.tan(s)))
    --print(v, s, a, b)
    return v end,
  
  --max Acceleration given only Steer
  maxA_S = function(boid, s)
    local q = (boid.drag * boid.drag * boid.wheelBase / math.abs(math.tan(s)))^2
    return math.min(math.sqrt(q/2 * -(math.sqrt(1 + (4 * boid.fM / q) ) - 1) ), boid.aM)
  end,
  
  --max Brake given only Steer
  maxB_S = function(boid, s)
    local q = (boid.drag * boid.drag * boid.wheelBase / math.abs(math.tan(s)))^2
    return math.min(math.sqrt(q/2 * -(math.sqrt(1 + (4 * boid.fM / q) ) - 1) ), boid.bM)
  end,
}

Boid__index = Boid

function Boid.new()
  local self = setmetatable({}, Boid)
  self.seed = math.random() * 65535
  self.color = {math.random(32, 255), math.random(32, 255), math.random(32, 255)}
  
  self.pos = vector.new(0, 0)
  self.vel = vector.new(0, 0)
  
  self.dir = 0
  self.spd = 0
  
  self.brk = 0
  self.acc = 0
  self.steer = 0
  
  self.plan = {
  }
  
  self.road = nil
  self.roadSeg = 1
  
  return self
end

function Boid:update(dt, neb)
  --[[self.acc = love.math.noise(t + self.seed) * 60
  self.brk = math.max(2 * love.math.noise(t + self.seed * 2) - 1, 0)
  self.steer = 2 * love.math.noise(t - self.seed) - 1]]
  self:followPlan()
  
  _, s = self.road:checkPoint(self.pos, self.seg)
  if s == nil then 
    _, _, self.seg = self.road:relative(self.pos, self.seg)
  else self.seg = s end
  
  if self.steer ~= 0 then
    local r = self.wheelBase / math.tan(self.steer)  --turning radius
    local av = self.spd/r --angular velocity
    self.dir = self.dir + av * dt
  else
    self.dir = self.dir
  end
  
  self.spd = self.spd + self.acc * dt
  --self.vel = self.vel * math.cos(self.steer)^dt
  self.spd = math.max(self.spd - self.brk * dt, 0)
  self.spd = self.spd - self.spd * self.tickDrag * dt
  
  self.vel = vector.fromPolar(self.spd, self.dir)
  self.pos = self.pos + self.vel * dt
  --print(self.brk, self.spd, self.dir, self.vel, self.pos)
end

function Boid:draw()
  love.graphics.setColor(self.color[1]/2, self.color[2]/2, self.color[3]/2)
  self:drawPath()
  
  local forward = vector.fromPolar(1, self.dir)
  local right = forward:crossR()
  
  local br = self.pos - forward * self.wheelBase/2 + right * self.wheelBase/3
  local bl = self.pos - forward * self.wheelBase/2 - right * self.wheelBase/3
  local f = self.pos + forward * self.wheelBase/2
  
  love.graphics.setColor(0, 0, 0)
  love.graphics.setLineWidth(6)
  love.graphics.polygon("line", f.x, f.y, br.x, br.y, bl.x, bl.y)
  love.graphics.setColor(self.color)
  love.graphics.polygon("fill", f.x, f.y, br.x, br.y, bl.x, bl.y)
  
  --self:drawRoadInfo()
end

function Boid:drawPath()
  local exs = self.plan.splitState
  for i, v in ipairs(self.plan) do
    love.graphics.circle("fill", v.ex.pos.x, v.ex.pos.y, 2)
    local pex = exs
    for i = 1, 9 do
      local ex = v:predict(self, exs, v.dur * i/10)
      love.graphics.circle("fill", ex.pos.x, ex.pos.y, 1)
    end
    exs = v:predict(self, exs)
  end
end

function Boid:drawRoadInfo()
  local n, dir, i = self.road:relative(self.pos)
  
  love.graphics.line(self.pos.x, self.pos.y, n.x, n.y)
  love.graphics.line(self.pos.x, self.pos.y, self.pos.x + dir.x * 10, self.pos.y + dir.y * 10)
end

--[[
boidState struct:
  pos: vector
  dir: number (angle)
  vel: vector
  str: number (angle)
  seg: number (index)
  t: number (time)
]]
function Boid:getState()
  return {
    pos = self.pos:copy(),
    dir = self.dir,
    vel = self.vel:copy(),
    str = self.str,
    seg = self.seg,
    t = t,
  }
end

function Boid:buildPlan(depth, ex, start)
  start = start or ex
  
  local bestPlan, bestValue = {}, 0
  for i, planner in pairs(self.planners) do
    local seg = planner(self, ex)
    if seg ~= nil then
      local plan, value = {}, 0
      if depth <= 1 then
        plan, value = {}, self.road:valueStateChange(start, seg.ex)
      else
        plan, value = self:buildPlan(depth-1, seg.ex, start)
      end
      if value >= bestValue then
        bestPlan = plan
        table.insert(bestPlan, 1, seg)
        bestValue = value
      end
    end
  end
  
  return bestPlan, bestValue
end


function Boid:adjustPlan(ex, start, breadth, depth, broken)
  ex = ex or self
  start = start or ex
  breadth = breadth or 2
  depth = depth or 1
  
  local bestPlan, bestValue = {}, 0
  for i = (broken and 1 or 0), breadth do
    local seg = (i == 0 and self.plan[depth]) or self.planners[math.random(1, #self.planners)](self, ex)
    if seg ~= nil then
      local plan, value = {}, 0
      if depth >= #self.plan+1 or depth >= self.maxPlanDepth then
         plan, value = {}, self.road:valueStateChange(start, seg.ex)
      else
        plan, value = self:adjustPlan(seg.ex, start, breadth, depth+1, i ~= 0)
      end
      if value >= bestValue then
        bestPlan = plan
        table.insert(bestPlan, 1, seg)
        bestValue = value
      end
    end
  end
  
  return bestPlan, bestValue
end

function Boid:findNewPlan()
  self.plan = self:buildPlan(self.newPlanDepth, self)
  self.plan.splitTime = t
  self.plan.splitState = self:getState()
end

function Boid:followPlan()
  if #self.plan >= 2 then
    if t > self.plan.splitTime + self.plan[1].dur then
      table.remove(self.plan, 1)
      if #self.plan == 0 then self:findNewPlan() end
      self.plan.splitTime = t
      self.plan.splitState = self:getState()
      
      local ex = self.plan.splitState
      for i, v in ipairs(self.plan) do
        v.ex = v:predict(self, ex)
        ex = v.ex
      end
    end
  else
    self:findNewPlan()
  end
  
  if math.random() > 0.99 then
    local old = self.plan
    self.plan = self:adjustPlan(self, self, 3)
    self.plan.splitTime = self.plan[1] == old[1] and old.splitTime or t
    self.plan.splitState = self.plan[1] == old[1] and old.splitState or self:getState()
  end
  
  if #self.plan >= 1 then self.plan[1]:input(self, t - self.plan.splitTime) end
end

--returns steer to reach target given position and direction
function Boid:steerTo(pos, dir, target)
  local c = vector.intersectPoint((pos + target)/2, (target - pos):crossL(), pos, (target-pos):rej(vector.fromPolar(1, dir)))
  local r = c:dist(pos)
  local s = math.atan2(self.wheelBase, r)
  s = s * math.sgn(angleDiffsg((pos-c):angle(), dir))
  return s
end

--[[
boidState struct:
  pos
  dir
  vel
  str
  seg
]]
  

