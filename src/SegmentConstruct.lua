--each segment constructor takes a boid and a boidState, returns a segment with component ex: boidState
local planners = {}
_planHelpers = {}

--Follow road towards center line at max velocity
function planners.centerMax(self, ex)
  local rd = self.road
  
  --find the points we will use to find the turning circle
  local int, seg = rd:intersectCenter(ex.pos, ex.pos + ex.vel * 5, ex.seg)
  local dir = nil
  if int ~= nil then
    dir = rd.points[seg].dir
  else
    int, seg = rd:intersectAt(ex.pos, ex.pos + ex.vel * 5, -1, ex.seg)  --try left
    if int ~= nil then
      dir = ex.vel:reflect(rd.points[seg % #rd.points + 1].l - rd.points[seg].l)
    else
      int, seg = rd:intersectAt(ex.pos, ex.pos + ex.vel * 5, 1, ex.seg)  --try right
      if int ~= nil then
        dir = ex.vel:reflect(rd.points[seg % #rd.points + 1].r - rd.points[seg].r)
      else
        return nil --give up and return nothing
      end
    end
  end
  
  local v1 = (dir):rej(ex.vel) --vector orthogonal to current velocity and towards the direction of the road
  local v2 = (dir:unit() - ex.vel:unit())  --vector between road direction and -car direction
  local c = vector.intersectPoint(ex.pos, v1, int, v2)  --center of the desired turning circle
  local r = ex.pos:dist(c)  --radius of turn
  local s = math.atan2(self.wheelBase, r * math.sgn(ex.vel:cross(c - ex.pos)))
  
  local v0 = ex.vel:mag()
  local dur = math.abs(ex.vel:angleBetween(dir) * 2) * r / v0 / 2
  local v = self.slipFigure.maxV(self, s, 0, 0)
  
  if v0 > v then
    s = math.sgn(s) * self.slipFigure.maxS(self, v0, 0, 0)
    local segment = Segment.newMain(dur, s, 0)
    segment.ex = segment:predict(self, ex)
    return segment
  else
    local a = self.slipFigure.maxA_S(self, s)
    local segment = Segment.newMain(dur, s, a)
    segment.ex = segment:predict(self, ex)
    return segment
  end
end

function planners.centerMin(self, ex)
  local rd = self.road
  
  --find the points we will use to find the turning circle
  local int, seg = rd:intersectCenter(ex.pos, ex.pos + ex.vel * 5, ex.seg)
  local dir = nil
  if int ~= nil then
    dir = rd.points[seg].dir
  else
    int, seg = rd:intersectAt(ex.pos, ex.pos + ex.vel * 5, -1, ex.seg)  --try left
    if int ~= nil then
      dir = ex.vel:reflect(rd.points[seg % #rd.points + 1].l - rd.points[seg].l)
    else
      int, seg = rd:intersectAt(ex.pos, ex.pos + ex.vel * 5, 1, ex.seg)  --try right
      if int ~= nil then
        dir = ex.vel:reflect(rd.points[seg % #rd.points + 1].r - rd.points[seg].r)
      else
        return nil --give up and return nothing
      end
    end
  end
  
  local v1 = (dir):rej(ex.vel) --vector orthogonal to current velocity and towards the direction of the road
  local v2 = (dir:unit() - ex.vel:unit())  --vector between road direction and -car direction
  local c = vector.intersectPoint(ex.pos, v1, int, v2)  --center of the desired turning circle
  local r = ex.pos:dist(c)  --radius of turn
  local s = math.atan2(self.wheelBase, r * math.sgn(ex.vel:cross(c - ex.pos)))
  
  local v0 = ex.vel:mag()
  local dur = math.abs(ex.vel:angleBetween(dir) * 2) * r / v0 / 3
  local v = self.slipFigure.maxV(self, s, 0, 0)
  
  if v0 > v then
    local b = self.bM * math.random()
    s = math.sgn(s) * self.slipFigure.maxS(self, v0, 0, b)
    local segment = Segment.newBrake(dur, s, b)
    segment.ex = segment:predict(self, ex)
    return segment
  else
    local b = self.slipFigure.maxB_S(self, s) * math.sqrt(math.random())
    local segment = Segment.newBrake(dur, s, b)
    segment.ex = segment:predict(self, ex)
    return segment
  end
end

function planners.random(self, ex)
  local s = (math.sqrt(math.random()) * self.sM) * math.random(-1, 1)
  local dur = 0.2 + math.random() * 1.2
  
  local v0 = ex.vel:mag()
  local v = self.slipFigure.maxV(self, s, 0, 0) * math.random()
  
  if v0 > v then s = math.sgn(s) * 0.9 * self.slipFigure.maxS(self, v0, 0, 0) end
  
  if math.random() > 0 then 
    local a = math.sqrt(math.random()) * self.slipFigure.maxA(self, math.max(v0, v), s)
    local segment = Segment.newMain(dur, s, a)
    segment.ex = segment:predict(self, ex)
    return segment
  else
    local b = math.sqrt(math.random()) * self.slipFigure.maxB(self, math.max(v0, v), s)
    local segment = Segment.newBrake(dur, s, b)
    segment.ex = segment:predict(self, ex)
    return segment
  end
end

function planners.holdLat(self, ex)
  local rd = self.road
  
  local d, l, seg = rd:roadSpace(ex.pos)
  local tPos = rd:cartesian(d + rd.points[seg].len, l, seg) --Magic constant
  local s = self:steerTo(ex.pos, ex.dir, tPos)
  
  local v0 = ex.vel:mag()
  local v = self.slipFigure.maxV(self, s, 0, 0)
  local dur = ex.pos:dist(tPos) / v0
  if dur == math.huge then dur = 0.1 end
  
  if v < v0 then
    local b = self.bM * 0.25--Magic constant
    s = math.sgn(s) * self.slipFigure.maxS(self, v0, 0, b) 
    local segment = Segment.newBrake(dur/2, s, b)
    segment.ex = segment:predict(self, ex)
    return segment
  else
    local a = lerp1(v0 * self.drag * math.random(), self.slipFigure.maxA_S(self, v0, s), math.random())
    local segment = Segment.newMain(dur, s, a)
    segment.ex = segment:predict(self, ex)
    return segment
  end
end

function planners.randomLat(self, ex)
  local rd = self.road
  
  local d, l, seg = rd:roadSpace(ex.pos)
  local tPos = rd:cartesian(d + rd.points[seg].len, math.random() * 2 - 1, seg) --Magic constant
  local s = self:steerTo(ex.pos, ex.dir, tPos)
  
  local v0 = ex.vel:mag()
  local v = self.slipFigure.maxV(self, s, 0, 0)
  local dur = ex.pos:dist(tPos) / v0
  if dur == math.huge then dur = 0.1 end
  
  if v < v0 then
    local b = self.bM * 0.25--Magic constant
    s = math.sgn(s) * self.slipFigure.maxS(self, v0, 0, b) 
    local segment = Segment.newBrake(dur/2, s, b)
    segment.ex = segment:predict(self, ex)
    return segment
  else
    local a = lerp1(v0 * self.drag * math.random(), self.slipFigure.maxA_S(self, s), math.random())
    local segment = Segment.newMain(dur, s, a)
    segment.ex = segment:predict(self, ex)
    return segment
  end
end

return planners