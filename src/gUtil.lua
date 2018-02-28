--geometric utility functions


--u, v line segment
--c, r circle
function intersectSegCirc(u, v, c, r)
  local d = u:dist(v)
  return ((c.x - u.x) * (v.y * u.y) - (c.y - u.y) * (v.x - v.y))/d >= r
end

--u, v: line segment
--c, r: circle
--a, b: arc
--seg: line segment
--divides the arc into segments and checks each.  There is probably a simpler more mathy way, but I'm bored of algebra, so TODO
function intersectSegArc(u, v, c, r, a, b)
  local segSize = a-b / seg
  for i = 0, seg-1 do
    local w, x = c + vector.fromPolar(r, a + segSize*i), c + vector.fromPolar(r, a + segSize*(i-1)) --current arc segment
    local s, t = vector.intersect(u, v-u, w, x-w)
    if s <= 1 and t <= 1 then
      return u + (v-u) * s
    end
  end
  return false
end

--u, v line segment
--p point
function nearestOnSeg(u, v, p)
  local d = u:dist2(v)
  if d == 0 then return u end
  local t = ((p.x - u.x) * (v.x - u.x) + (p.y - u.y) * (v.y - u.y)) / d
  
  if t <= 0 then return u end
  if t >= 1 then return v end
  
  return u + (v - u)*t
end

function lambertW(z)
  
end
