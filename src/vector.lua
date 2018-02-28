--[[
Christoph Delta

If you stumble upon this in the released source for one of my games, and you think it might be useful to you, consider it Public Domain!  Please keep in mind however that this is probably not the most efficient, usable, well documented, or comprehensive vector math library out there, so you're better off checking around.

This file implements vectors and vector math, for use in making 2D games with Love2D.
It also includes some miscellaneous math functions I've found useful in gamedev, geometric stuff, random number generation, etcetera.
]]


vector = {}
vector.__index = vector

__newVector = {}
__newVector.__index = __newVector
__newVector.__call = function(x, y) return setmetatable({x=x, y=y}, vector) end
setmetatable(vector, __newVector)
  
math.tau = 2*math.pi

function vector.new(x, y)
  local v = {x=x, y=y}
  return setmetatable(v, vector)
end

function vector.fromPolar(r, a)
  return vector.new(r*math.cos(a), r*math.sin(a))
end

function vector:unpack()
  return self.x, self.y
end

function vector:copy()
  return vector.new(self.x, self.y)
end

--Length of self
function vector:mag()
  return math.sqrt(self.x*self.x+self.y*self.y)
end

--Square of length of self
function vector:mag2()
  return self.x*self.x+self.y*self.y
end

--Distance from self to v
function vector:dist(v)
  return math.sqrt((v.x-self.x)^2 + (v.y-self.y)^2)
end

--Square of distance from self to v
function vector:dist2(v)
  return (v.x-self.x)^2 + (v.y-self.y)^2
end

--I don't remember
--TODO: figure what this and rdistp do.
function vector:rdist(v, x)
  x = x or math.tau
  local a, b = math.min(self.x, v.x) % x, math.max(self.x, v.x) % x
  local xd = math.min(b - a, a - b + x)
  return math.sqrt((xd)^2 + (v.y-self.y)^2)
end

--
function vector:rdistp(v, x)
  x = x or math.tau
  local a, b = math.min(self.x, v.x) % x, math.max(self.x, v.x) % x
  local xd = math.min(b - a, a - b + x)
  return math.sqrt((xd*math.pi)^2 + (v.y-self.y)^2)
end

--vector pointing from self to v
function vector:rel(v)
  return vector.new(v.x-self.x, v.y-self.y)
end

--dot product of self with v
function vector:dot(v)
  return (self.x*v.x + self.y*v.y)
end

--vector rotated 90d widdershins
function vector:crossL()
  return vector.new(-self.y, self.x)
end

--vector rotated 90d clockwise
function vector:crossR()
  return vector.new(self.y, -self.x)
end

--2D cross product of self with v.  Miscellaneously useful.
function vector:cross(v)
  return (self.x*v.y - self.y*v.x)
end

--projection/rejection of self onto v
function vector:projRej(v)
  local p = v * (self:dot(v) / v:dot(v))
  return p, (self-p)
end

--projection of self onto v
function vector:proj(v)
  return v * (self:dot(v) / v:dot(v))
end

--rejection of self from v
function vector:rej(v)
  return self - v * (self:dot(v) / v:dot(v))
end

--reflect self from v
function vector:reflect(v)
  return self - v * (self * 2):dot(v) / v:mag2()
end

function vector:angle()
  return math.atan2(self.y, self.x)
end

function vector:angleTo(v)
  return (v - self):angle()
end

function vector:angleBetween(v)
  return math.atan2(v.y, v.x) - math.atan2(self.y, self.x)
end

function vector:unit()
  if self.x == 0 and self.y == 0 then self.x = 1 end
  return self / self:mag()
end

function vector:rescale(c)
  if self.x == 0 and self.y == 0 then self.x = 1 end
  return self * (c / self:mag())
end

function vector:clamp(min, max)
  local m2 = self:mag2()
  if m2 < min*min then return self:rescale(min) end
  if m2 > max*max then return self:rescale(max) end
  return self:copy()
end

function vector:rotate(a)
  local c, s = math.cos(a), math.sin(a)
  return vector.new(self.x*c - self.y*s, self.x*s + self.y*c)
end

function vector.__unm(v)
  return vector.new(-v.x, -v.y)
end

function vector.__mul(v, c)
  return vector.new(v.x*c, v.y*c)
end

function vector.__div(v, c)
  return vector.new(v.x/c, v.y/c)
end

function vector.__add(u, v)
  return vector.new(u.x+v.x, u.y+v.y)
end

function vector.__sub(u, v)
  return vector.new(u.x-v.x, u.y-v.y)
end

function vector.__eq(u, v)
  return u.x == v.x and u.y == v.y
end

function vector.__tostring(op)
  return ('[' .. (op.x or 0) .. ', ' .. (op.y or 0) .. ']')
end

function vector.degToRad(angle)
  return angle*math.pi/180
end

function math.clamp(x, m, M)
  return math.min(M, math.max(m, x))
end

function math.sgn(x)
  return (x >= 0 and 1 or -1)
end

function lerp1(a, b, x)
  return a + (b-a) * x
end

function lerp2(a, b, x)
  return a + (b-a) * x
end

function angleDiff(a, b)
  return math.abs((b - a + math.pi) % math.tau - math.pi)
end

function angleDiffsg(a, b)
  return (b - a + math.pi) % math.tau - math.pi
end

--checks if x is between a and b sweeping clockwise
function betweenAngles(a, b, x)
  return angleDiffsg(a, x) <= angleDiffsg(a, b)
end

function math.sigmoid(x)
  return 1/(1+2.71828^(-x))
end

function math.randouble(low, high)
  return math.random() * (high - low) + low
end

function math.quadratic(a, b, c)
  local d = math.sqrt(b*b - 4*a*c)
  return (-b+d)/(a*2), (-b-d)/(a*2)
end

--p and q are origins of the segments, r and s are the segments themselves
--returns t and u, which scale r and s respectively to get the intersection point
function vector.intersect(p, r, q, s)
  local rs = r:cross(s)
  local qp = q-p
  return qp:cross(s)/rs, qp:cross(r)/rs
end

function vector.intersectPoint(p, r, q, s)
  local t, u = vector.intersect(p, r, q, s)
  return p + r*t, t, u
end

vector.origin = vector.new(0, 0)