
--Create a new color object
--a,b,c or table a for parameters, which can be integers up to 255, or floating point values 0 to 1, mode can be "rgb", "rgbf", "hsv", "hsl", "lch", defaults to rgb.
color = {}
color.__index = color

function newColor(a,b,c,d,mode)
  --Parse input and insert defaults where necessary.
  if type(a) == "table" then
    mode = b or "rgb"
    d = a[4] or (mode == "rgb" and 255) or 1
    c = a[3]
    b = a[2]
    a = a[1]
  end
  mode = (type(d) == "string" and d) or mode or "rgb"
  d = (type(d) == "string" and ((mode == "rgb" and 255) or 1)) or d
  local n = {}
  if mode == "rgb" then
    n[1], n[2], n[3], n[4]= a,b,c,d
    a,b,c,d = a/255, b/255, c/255, d/255
  elseif mode == "rgbf" then
    n[1], n[2], n[3], n[4] = math.floor(a*255), math.floor(b*255), math.floor(c*255), math.floor(d*255)
  elseif mode == "hsv" then
    n.h,n.s,n.v = a,b,c
    a,b,c = color:getRGB(a,b,c,"hsv")
    n[1], n[2], n[3], n[4] = math.floor(a*255), math.floor(b*255), math.floor(c*255), math.floor(d*255)
  elseif mode == "lch" then
    n.l,n.c,n.h = a,b,c
    a,b,c = color:getRGB(a,b,c,"lch")
    n[1], n[2], n[3], n[4] = math.floor(a*255), math.floor(b*255), math.floor(c*255), math.floor(d*255)
  end
  n.r = a
  n.g = b
  n.b = c
  n.a = d
  n.l = n.l or color:getLuma(a,b,c)
  n.c = n.c or color:getChroma(a,b,c)
  n.h = n.h or color:getHue(a,b,c)
  n.s = n.s or color:getSaturation(a,b,c)
  n.v = n.v or color:getValue(a,b,c)
  n.n = {255-n[1], 255-n[2], 255-n[3], n[4]}
  return setmetatable(n, color)
end

--Luma represents the intensity of a color in LCH
function color:getLuma(r,g,b)
  r,g,b = r or self.r, g or self.g, b or self.b
  return .3*r + .59*g + .11*b
end

--Chroma represents the richness of a color in LCH
function color:getChroma(r,g,b)
  r,g,b = r or self.r, g or self.g, b or self.b
  return math.max(r,g,b)-math.min(r,g,b)
end

--Hue abstractly represents the wavelength of light of a color, or more directly, where it would be placed on a color wheel.  Used in HSV and LCH.
function color:getHue(r,g,b)
  r,g,b = r or self.r, g or self.g, b or self.b
  c = color:getChroma(r,g,b)
  M = math.max(r,g,b)
  if c == 0 then
    return 0
  elseif M == r then
    return (g-b)/c%6/6
  elseif M == g then
    return ((b-r)/c+4)/6
  elseif M == b then
    return ((r-g)/c+2)/6
  end
end

--Saturation represents the richness of a color in HSV
function color:getSaturation(r,g,b)
  r,g,b = r or self.r, g or self.g, b or self.b
  local v = color:getValue(r,g,b)
  return (v == 0 and 0) or color:getChroma(r,g,b)/v
end

--Value represents the intensity of a color in HSV
function color:getValue(r,g,b)
  r,g,b = r or self.r, g or self.g, b or self.b
  return math.max(r,g,b)
end


--Conversion Functions

--LCH or HSV to RGB
function color:getRGB(a,b,c,mode)
  local C = (mode == "hsv" and b*c) or b
  local H = (mode == "hsv" and a) or c
  local X = C*(1-math.abs(6*H%2-1))
  local r,g,b = 0,0,0
  if H < (1/6) then
    r,g,b = C,X,0
  elseif H < (1/3) then
    r,g,b = X,C,0
  elseif H < (1/2) then
    r,g,b = 0,C,X
  elseif H < (2/3) then
    r,g,b = 0,X,C
  elseif H < (5/6) then
    r,g,b = X,0,C
  else
    r,g,b = C,0,X
  end
  if mode == "hsv" then    
    r,g,b = r+c-C, g+c-C, b+c-C
    return r,g,b
  elseif mode == "lch" then
    local m = a-(.3*r + .59*g + .11*b)
    r,g,b = r+m, g+m, b+m
    r,g,b = (r>1 and 1) or (r<0 and 0) or r, (g>1 and 1) or (g<0 and 0) or g, (b>1 and 1) or (b<0 and 0) or b
    return r,g,b
  end
end



--Mix functions

--weighted average of rgb components
function color:mixAvg(color, amt)
  amt = amt or .5
  tr = self.r*(1-amt)+color.r*amt
  tg = self.g*(1-amt)+color.g*amt
  tb = self.b*(1-amt)+color.b*amt
  return newColor(tr,tg,tb,"rgbf")
end

--additive mixing
function color:mixAdd(color, base)
  base = self or base
  tr = base.r + color.r
  tg = base.g + color.g
  tb = base.b + color.b
  tr,tg,tb = tr>1 and 1 or tr, tg>1 and 1 or tg, tb>1 and 1 or tb
  return newColor(tr,tg,tb,"rgbf")
end

--subtractive mixing
function color:mixSub(color, base)
  base = self or base
  tr = math.min(base.r, color.r)
  tg = math.min(base.g, color.g)
  tb = math.min(base.b, color.b)
  return newColor(tr,tg,tb,"rgbf")
end

function setColorHSV(h,s,v,a)
  a = a or 255
  local r,g,b = color:getRGB(h,s,v,"hsv")
  love.graphics.setColor(math.floor(r*255),math.floor(g*255),math.floor(b*255),a)
end

function setColorLCH(l,c,h,a)
  a = a or 255
  local r,g,b = color:getRGB(l,c,h,"lch")
  love.graphics.setColor(math.floor(r*255),math.floor(g*255),math.floor(b*255),a)
end

function color.__add(a,b)
  return a:mixAdd(b)
end

function color.__sub(a,b)
  return a:mixSub(b)
end
