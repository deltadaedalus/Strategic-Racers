WINW, WINH = 540, 540
SCALE = 1

love.graphics.setLineStyle("rough")
math.randomseed(os.time())

require "ColorOfBabel"
require "vector"
require "car"

function love.load()
  love.window.setMode(WINW * SCALE, WINH * SCALE)
  love.window.setFullscreen(false)
  t = 0
  
  birds = {}
  rows = {}
  rowIndex = {}
  testRoad = Road.load("Tracks/track3.lua", vector.new(-WINW/2, -WINH/2))
  
  for i = 1, 10 do
    birds[i] = Boid.new(vector.new(math.random() * WINW, math.random() * WINH))
    birds[i].color = newColor(math.random(), 0.5 + math.random()/2, 1, "hsv")
    birds[i].road = testRoad
    birds[i].planners = {
      Boid.planners.holdLat, 
      Boid.planners.randomLat,}
    
    birds[i].pos = vector.new(50, 50)
    birds[i].dir = math.random() * math.tau
    birds[i].spd = 5
    birds[i].vel = vector.fromPolar(birds[i].spd, birds[i].dir)
  end
end

function love.update(dt)
  t = t+dt
  love.window.setTitle(love.timer.getFPS() .. "   " .. #birds)
  
  for i, b in ipairs(birds) do  --Update each car
    for i = 1, 15 do b:update(dt/15) end
  end
  
  for i, b in ipairs(birds) do  --Delete things that have ended up places they shouldn't
    if b.pos.x ~= b.pos.x or b.pos.y ~= b.pos.y then table.remove(birds, i) end
  end
end

function love.draw()
  love.graphics.translate(WINW/2, WINH/2)
  love.graphics.scale(SCALE)
  love.graphics.setColor(192, 192, 192)
  testRoad:draw()
  
  for i, b in ipairs(birds) do  --draw each car
    b:draw()
  end
end

function drawRoadSpace(base, s)
  love.graphics.setColor(255, 255, 255)
  love.graphics.setLineWidth(2)
  for i, p in ipairs(testRoad.points) do
    love.graphics.line(base.x + p.start * s.x, base.y, base.x + (p.start + p.len) * s.x, base.y)
    love.graphics.line(base.x + p.start * s.x, base.y + s.y, base.x + (p.start + p.len) * s.x, base.y + s.y)
    love.graphics.line(base.x + p.start * s.x, base.y - s.y, base.x + (p.start + p.len) * s.x, base.y - s.y)
    love.graphics.line(base.x + p.start * s.x, base.y - s.y, base.x + p.start * s.x, base.y + s.y)
  end
  
  for i, b in ipairs(birds) do
    local pos = vector.new()
    pos.x, pos.y = b.road:roadSpace(b.pos)
    pos.x = pos.x * s.x
    pos.y = -pos.y * s.y
    pos = pos + base
    love.graphics.setColor(b.color)
    love.graphics.circle("fill", pos.x, pos.y, 3)
  end
end

function sortRowColumn(birds)
  birds, rows, rowIndex = bucketSort(birds, function(a) return math.floor(a.pos.y/Boid.dmax) end)
  for y = 1, #rows do
    _, rows[y].cols, rows[y].colIndex = bucketSort(birds, function(a) return math.floor(a.pos.x/Boid.dmax) end, rows[y].i, rows[y].i+rows[y].n-1)
  end
  return rows, rowIndex
end

function findNeighbors(birds, neighbors, rows, rowIndex, dMax)
  for i = 1, #birds do
    neighbors[i] = {}
  end
  
  for i, b in ipairs(birds) do  --Parallelize here
    local r, c = math.floor(b.pos.y/b.dmax), math.floor(b.pos.x/b.dmax)
    
    --first do all birds past b in [r, c]
    local row = rows[rowIndex[r]]
    local col = row.cols[row.colIndex[c]]
    for j = i+1, col.i + col.n - 1 do
      local bc = birds[j]
      if b.pos:dist2(bc.pos) < b.dmax2 then
        table.insert(neighbors[i], bc)
        table.insert(neighbors[j], b)
      end
    end
    
    --second do all birds in [r, c+1]
    if row.colIndex[c+1] ~= nil then
      local col = row.cols[row.colIndex[c+1]]
      for j = col.i, col.i + col.n - 1 do
        local bc = birds[j]
        if b.pos:dist2(bc.pos) < b.dmax2 then
          table.insert(neighbors[i], bc)
          table.insert(neighbors[j], b)
        end
      end
    end
    
    --third do all birds in [r+1, c-1 to c+1]
    if rowIndex[r+1] ~= nil then
      local row = rows[rowIndex[r+1]]
      for cn = c-1, c+1 do if row.colIndex[cn] ~= nil then
        local col = row.cols[row.colIndex[cn]]
        for j = col.i, col.i + col.n - 1 do
          local bc = birds[j]
          if b.pos:dist2(bc.pos) < b.dmax2 then
            table.insert(neighbors[i], bc)
            table.insert(neighbors[j], b)
          end
        end
      end end
    end
    
  end
end

function bucketSort(t, keyf, l, h)
  l = l or 1
  h = h or #t
  buckets = {}
  
  for i = l, h do
    local k = keyf(t[i])
    buckets[k] = buckets[k] or {}
    table.insert(buckets[k], t[i])
  end
  
  local i = l
  local b = {}
  local bi = {}
  for k, bucket in pairs(buckets) do
    table.insert(b, {i = i, n = #bucket})
    bi[k] = #b
    for j, v in ipairs(bucket) do
      t[i] = v
      i = i+1
    end
  end
  
  return t, b, bi
end

function firstLess(t, k, keyf, l, h)
  l = l or 1
  h = h or #t
  while l ~= h do
    local m = math.floor(l + h / 2)
    if keyf(t[m]) <= k then l = m+1 else h = m end
  end
  return l
end

function math.bound(v, min, max) return math.max(math.min(v, max), min) end

function love.keypressed(key)
  if key == 'escape' then love.event.quit() end
end