Segment = {}
Segment.__index = Segment

function Segment.new()
  
end

function Segment.newMain(duration, steer, acc)
  local self = setmetatable({}, Segment)
  
  self.acc = acc
  self.steer = steer
  self.dur = duration
  
  self.input = Segment.inputMain
  self.predict = Segment.predictMain
  
  return self
end

function Segment.newSteer(duration, start, target)
  local self = setmetatable({}, Segment)
  
  self.start = start
  self.target = target
  self.dur = duration
  
  self.input = Segment.inputSteer
  self.predict = Segment.predictSteer
  
  return self
end

function Segment.newBrake(duration, steer, brake)
  local self = setmetatable({}, Segment)
  
  self.brk = brake
  self.steer = steer
  self.dur = duration
  
  self.input = Segment.inputBrake
  self.predict = Segment.predictBrake
  
  return self
end

function Segment:input(boid, t)
  
end

function Segment:inputMain(boid, t)
  boid.steer = self.steer
  boid.acc = self.acc
  boid.brk = 0
end

function Segment:inputSteer(boid, t)
  boid.steer = self.start + (self.target - self.start) * t/self.duration
  boid.acc = boid.vel:mag() * self.drag
end

function Segment:inputBrake(boid, t)
  boid.steer = self.steer
  boid.brk = self.brk
  boid.acc = 0
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
--takes boid, expected start state, optional duration
--returns expected end state
function Segment:predict(boid, ex, dur)
  return ex
end

function Segment:predictMain(boid, ex, dur)
  dur = dur or self.dur
  
  local vm = self.acc/boid.drag --max velocity
  local r = boid.wheelBase/math.tan(self.steer) --turning radius
  local c = vector.fromPolar(r, ex.dir + math.pi/2)  --turning center
  
  local eD = vm * dur + (ex.vel:mag() - vm) * (1 - math.exp(-dur * boid.drag)) / boid.drag --expected distance
  local eV = vm + (ex.vel:mag() - vm) * math.exp(-dur * boid.drag) --expected velocity
  local eA = self.steer == 0 and ex.dir or ex.dir + eD / r --expected direction
  local ePos = self.steer == 0 and ex.pos + vector.fromPolar(eD, eA) or ex.pos + c + vector.fromPolar(r, eA - math.pi/2)  --expected change in position relative to current position and direction
  
  return {pos = ePos, dir = eA, vel = vector.fromPolar(eV, eA), str = self.str, seg = select(3, boid.road:relative(ePos, ex.seg or 1)), t = (ex.t or t) + dur}
end

function Segment:predictSteer(boid, ex, dur)
  dur = dur or self.dur
  
  local vo = (self.target - self.start) / self.dur
  local function phi(dt)
    return math.log(math.cos(self.start) / math.cos(self.start + vo * dt)) / v0
  end
  
  local eA = ex.dir + phi(dur) --expected direction
  local avgA = ex.dir + phi(dur/2) + phi(dur)/2 --estimate of average phi(t).  TODO: properly integrate or come up with a better estimate
  local ePos = ex.pos + vector.fromPolar(ex.vel:mag() * dur, avgA) --estimate of expected change in position
  
  return {pos = ePos, dir = eA, vel = vector.fromPolar(ex.vel:mag(), eA), str = lerp1(self.start, self.start, dur/self.dur), seg = select(3, boid.road:relative(ePos, ex.seg or 1)), t = (ex.t or t) + dur}
end

function Segment:predictBrake(boid, ex, dur)
  dur = dur or self.dur
  local v0 = ex.vel:mag()
  
  local sT = math.log((v0 * boid.drag + self.brk) / self.brk) / boid.drag  --stop time
  local r = boid.wheelBase/math.tan(self.steer) --turning radius
  local c = vector.fromPolar(r, ex.dir + math.pi/2)  --turning center
  
  if dur >= sT then
    local eD = -(self.brk / boid.drag) * sT + (v0 + (self.brk / boid.drag)) * (1 - math.exp(-sT * boid.drag)) / boid.drag
    local eA = ex.dir + eD / r
    local ePos = ex.pos + c + vector.fromPolar(r, eA - math.pi/2)
    
    return {pos = ePos, dir = eA, vel = vector.new(0, 0), str = self.str, seg = select(3, boid.road:relative(ePos, ex.seg or 1)), t = (ex.t or t) + dur}
  else
    local eD = -(self.brk / boid.drag) * dur + (v0 + (self.brk / boid.drag)) * (1 - math.exp(-dur * boid.drag)) / boid.drag
    local eV = -(self.brk / boid.drag) + (v0 + self.brk / boid.drag) * math.exp(-dur * boid.drag)
    local eA = ex.dir + eD / r
    local ePos = ex.pos + c + vector.fromPolar(r, eA - math.pi/2)
    
    return {pos = ePos, dir = eA, vel = vector.fromPolar(eV, eA), str = self.str, seg = select(3, boid.road:relative(ePos, ex.seg or 1)), t = (ex.t or t) + dur}
  end
end

function Segment:verify(Boid, Road, sPos, sV, sA)
  
end