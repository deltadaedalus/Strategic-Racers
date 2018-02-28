Road = {}
Road.__index = Road

function Road.new()
  local self = setmetatable({}, road)
  self.points = {}
  return self
end

function Road:addPoint(pos, w)
  local p = {pos = pos, w = w}
  
  if #self.points >= 2 then
    local pp = self.points[#self.points]
    local pf = ((pp.pos - self.points[#self.points-1].pos) + (p.pos - pp.pos)):unit()
    pp.l = pp.pos + pf:crossL() * pp.w
    pp.r = pp.pos + pf:crossR() * pp.w
    pp.dir = p.pos - pp.pos
    pp.len = pp.pos:dist(p.pos)

    local np = self.points[1]
    local nf = ((np.pos - p.pos) + (self.points[2].pos - np.pos)):unit()
    np.l = np.pos + nf:crossL() * np.w
    np.r = np.pos + nf:crossR() * np.w
    np.dir = self.points[2].pos - np.pos
    np.len = np.pos:dist(self.points[2].pos)
    
    local f = ((p.pos - pp.pos) + (np.pos - p.pos)):unit()
    p.l = p.pos + f:crossL() * p.w
    p.r = p.pos + f:crossR() * p.w
    p.dir = np.pos - p.pos
    p.len = p.pos:dist(np.pos)
  else
    p.l = p.pos
    p.r = p.pos
  end
  
  table.insert(self.points, p)
  return p, #self
end

function Road:findLength()
  self.len = 0
  for i, p in ipairs(self.points) do
    p.start = self.len
    self.len = self.len + p.len
  end
end

function Road.load(filename, offset)
  offset = offset or vector.new(0, 0)
  local self = setmetatable({}, Road)
  self.points = {}
  
  local data = love.filesystem.load(filename)().layers[1].objects[1] 
  local w = data.properties.Width
  for i, p in ipairs(data.polyline) do
    self:addPoint(vector.new(p.x + data.x, p.y + data.y) + offset, w * (0.25 + love.math.noise(i/5) * 1.5))
  end
  
  self:findLength()
  
  return self
end

function Road:draw(showSpace)
  local pp = self.points[#self.points]
  local np = self.points[2]
  
  for i, p in ipairs(self.points) do
    np = self.points[i % #self.points + 1]
    
    if showSpace then
      for i = 2, 19 do
        i = 21-i
        love.graphics.setColor(191/i, 191/i, 191/i)
        local l, r = lerp2(p.pos, p.l, i), lerp2(p.pos, p.r, i)
        local pl, pr = lerp2(pp.pos, pp.l, i), lerp2(pp.pos, pp.r, i)
        love.graphics.line(l.x, l.y, r.x, r.y)
        love.graphics.line(pl.x, pl.y, l.x, l.y)
        love.graphics.line(pr.x, pr.y, r.x, r.y)
        love.graphics.line(pp.pos.x, pp.pos.y, p.pos.x, p.pos.y)
      end
    end
    
    love.graphics.setColor(191, 191, 191)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(p.l.x, p.l.y, p.r.x, p.r.y)
    love.graphics.line(pp.l.x, pp.l.y, p.l.x, p.l.y)
    love.graphics.line(pp.r.x, pp.r.y, p.r.x, p.r.y)
    love.graphics.line(pp.pos.x, pp.pos.y, p.pos.x, p.pos.y)
    
    pp = p
  end
end

function Road:checkPoint(p, startIndex, count)
  local i = startIndex or 1
  count = count or #self.points
  
  for _ = 1, count do
    if self:checkSection(p, i) then return true, i end
    i = i % #self.points + 1
  end
  
  return false
end

function Road:checkSection(p, i)
  local s1 = self.points[i]
  local s2 = self.points[i % #self.points + 1] 
  
  if (s1.l - s1.r):cross(p - s1.r) > 0 then return false end
  if (s2.l - s1.l):cross(p - s1.l) > 0 then return false end
  if (s2.r - s2.l):cross(p - s2.l) > 0 then return false end
  if (s1.r - s2.r):cross(p - s2.r) > 0 then return false end
  
  return true
end

function Road:checkArc(c, r, a, b, startIndex)
  local arcLen = math.abs(r * b-a)
  local i = startIndex or 1
  
  while arcLen > 0 do
    local j = i % #self.points + 1
    
    arcLen = arcLen - math.min(self.points[i].l:dist(self.points[j].l), self.points[i].r:dist(self.points[j].r))
    
    local lcross = intersectSegArc(self.points[i].l, self.points[j].l, c, r, a, b)
    if lcross then return lcross, 'l' end
    local rcross = intersectSegArc(self.points[i].r, self.points[j].r, c, r, a, b)
    if rcross then return rcross, 'r' end
    
    i = j
  end
end

--returns:
--nearest point on the road
--direction of the road at that point
--index of the nearest section
function Road:relative(p, startIndex, count)
  local i = startIndex or 1
  count = count or #self.points
  local minI = i
  local minN = self.points[i].pos
  local minD2 = math.huge
  
  for _ = 1, count do
    local j = i % #self.points + 1
    local n = nearestOnSeg(self.points[i].pos, self.points[j].pos, p)
    local d2 = n:dist2(p)
    
    if d2 <= minD2 then
      minI = i
      minN = n
      minD2 = d2
    end
    
    i = j
  end
  
  local s = self.points[minI]
  local ns = self.points[minI % #self.points + 1]
  local dir = ((minN - s.pos) + (ns.pos - minN)):unit()
  local pos = self.points[minI].start + minN:dist(self.points[minI].pos)
  
  return minN, dir, minI, pos
end

--segment p, q
function Road:intersectCenter(p, q, startIndex)
  local len = p:dist(q)
  local i = startIndex or 1
  
  while len > 0 do
    local j = i % #self.points + 1
    len = len - math.min(self.points[i].l:dist(self.points[j].l), self.points[i].r:dist(self.points[j].r))
    
    local ip, t, u = vector.intersectPoint(p, q-p, self.points[i].pos, self.points[i].dir)
    if t >= 0 and t <= 1 and u >= 0 and u <= 1 then return ip, i end
    
    i = j
  end
  
  return nil
end

--segment p, q
--lat lateral position on road from -1(left edge) to +1(right edge)
function Road:intersectAt(p, q, lat, startIndex)
  local len = p:dist(q)
  local i = startIndex or 1
  local pi = self.points[i].pos + (self.points[i].r - self.points[i].pos) * lat
  
  while len > 0 do
    local j = i % #self.points + 1
    local pj = self.points[j].pos + (self.points[j].r - self.points[j].pos) * lat
    
    len = len - math.min(self.points[i].l:dist(self.points[j].l), self.points[i].r:dist(self.points[j].r))
    
    
    local ip, t, u = vector.intersectPoint(p, q-p, pi, pj-pi)
    if t >= 0 and t <= 1 and u >= 0 and u <= 1 then return ip, i end
    
    i = j
    pi = pj
  end
  
  return nil
end

function Road:valueStateChange(start, finish)
  local sNear, sDir, sSeg, sRPos = self:relative(start.pos)
  local fNear, fDir, fSeg, fRPos = self:relative(finish.pos)
  
  local distVal = (angleDiffsg(sRPos * math.tau / self.len, fRPos * math.tau / self.len) * self.len / math.tau)
  distVal = distVal * (1 + 1/(finish.t - (start.t or t)))
  local dirVal = math.cos(finish.vel:angleBetween(fDir))
  local velVal = finish.vel:mag()
  
  local value = distVal + (velVal * dirVal)
  if not self:checkPoint(finish.pos) then value = value - sNear:dist(finish.pos) end
  
  
  return value
end

--transforms road space into cartesian space
function Road:cartesian(fwd, lat, startIndex)
  local i = startIndex or 1
  fwd = fwd % self.len
  
  --find section
  for _ = 1, #self.points do
    local j = i % #self.points + 1
    if fwd >= self.points[i].start and j == 1 or fwd < self.points[j].start then break end
    i = j
  end
  
  local pi = self.points[i]
  local pj = self.points[i % #self.points + 1]
  local d = ((fwd - pi.start) / pi.len)
  local cpos = pi.pos + (pj.pos - pi.pos) * d
  local cr = pi.r + (pj.r - pi.r) * d
  
  local pos = cpos + (cr - cpos) * lat
  return pos
end

--transforms cartesian space into road space
function Road:roadSpace(p, startIndex, count)
  local i = startIndex or 1
  local minI = nil
  local minLat2 = math.huge
  
  for _ = 1, count or #self.points do
    local j = i % #self.points + 1
    local pi, pj = self.points[i], self.points[j]
    
    if (pi.l - pi.r):cross(p - pi.r) < 0 and (pj.r - pj.l):cross(p - pj.l) < 0 then
      if self:checkSection(p, i) then
        minI = i
        break
      end
      
      local lat2 = (p-pi.pos):rej(pj.pos-pi.pos):mag2()
      if lat2 <= minLat2 then
        minI = i
        minLat2 = lat2
      end
    end
    
    i = j
  end
  
  local pi, pj = self.points[minI], self.points[minI % #self.points + 1]
  
  local z, b, u, v = p - pi.pos, pj.pos - pi.pos, pi.r - pi.pos, pj.r - pi.pos
  local tb = z:cross(u) + z:cross(b) - z:cross(v)
  
  local _, d = math.quadratic(b:cross(v) - b:cross(u), tb + b:cross(u), u:cross(z))
  local l, _ = math.quadratic(u:cross(v) - u:cross(b), tb + u:cross(b), b:cross(z))
  d = ((d * pi.len) + self.points[minI].start) % self.len
  return d, l, minI
end