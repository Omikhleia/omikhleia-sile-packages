--
-- Core logic for rough hand-drawn-like sketchs
-- Implemented: lines and rectangles
-- License: MIT
--

-- Not ported from rough.js, but the idea here is similar...

--
-- Pseudo-Random Number Generator (PRNG)
-- License: MIT
--

-- Why would a text processing software such as SILE need a PRNG,
-- where one would expect the reproduceability of the output?
--
-- Well, there are algorithms were a bit of randomness is expected
-- e.g. the rough "hand-drawn-like" drawing style, where one would
-- expect all rough graphics to look different. But using math.random
-- there would yield always different results... and using math.randomseed
-- is also problematic (it's global and could be affected elsewhere, etc.)
-- So one may need instead a fake PRNG, that spits out a seemingly uniform
-- distribution of "random" numbers.

-- (didier.willis@gmail.com) This Lua piece of code was found just on the
-- internet, where it was stated to be common in Monte Carlo randomizations.
-- I am not so lazy not to check, and traced it back to Sergei M. Prigarin,
-- _Spectral Models of Random Fields in Monte Carlo Methods_, 2001.
-- It is a "multiplicative generator", a popular type of modelling algorithms
-- of a sequence of pseudorandom numbers uniformly distributed on the interval
-- (0,1), initially studied by P.H. Lehmer around 1951.
-- This derivation, if I read correctly, has a 2^40 module and 5^17 mutiplier
-- (cycle length 2^38).
-- for information the seeds are (X1, X2), here set to (0, 1). The algorithm
-- could be seeded with other values. It's not clear to me which variant was
-- used (I didn't check the whole book), but it seems the constraints are
-- 0 < X1, X2 <= 2^20 and X2 being odd.
local A1, A2 = 727595, 798405  -- 5^17=D20*A1+A2
local D20, D40 = 1048576, 1099511627776  -- 2^20, 2^40
local X1, X2 = 0, 1
local random = function()
  local U = X2*A2
  local V = (X1*A2 + X2*A1) % D20
  V = (V*D20 + U) % D40
  X1 = math.floor(V/D20)
  X2 = V - X1*D20
  return V/D40
end

-- Partial port of the rough.js (https://github.com/rough-stuff/rough) JavaScript library.

-- From renderer.ts (private helpers)

local function _offset(min, max, ops, roughnessGain)
  return ops.roughness * (roughnessGain or 1) * ((random() * (max - min)) + min)
end

local function _offsetOpt(x, ops, roughnessGain)
  return _offset(-x, x, ops, roughnessGain or 1)
end

local function _line(x1, y1, x2, y2, o, move, overlay) -- returns an array of operations
  local lengthSq = math.pow((x1 - x2), 2) + math.pow((y1 - y2), 2)
  local length = math.sqrt(lengthSq)
  local roughnessGain = 1
  if length < 200 then
    roughnessGain = 1
  elseif length > 500 then
    roughnessGain = 0.4
  else
    roughnessGain = (-0.0016668) * length + 1.233334
  end

  local offset = o.maxRandomnessOffset or 0
  if (offset * offset * 100) > lengthSq then
    offset = length / 10
  end
  local halfOffset = offset / 2
  local divergePoint = 0.2 + random() * 0.2
  local midDispX = o.bowing * o.maxRandomnessOffset * (y2 - y1) / 200
  local midDispY = o.bowing * o.maxRandomnessOffset * (x1 - x2) / 200
  midDispX = _offsetOpt(midDispX, o, roughnessGain)
  midDispY = _offsetOpt(midDispY, o, roughnessGain)
  local ops = {}
  local randomHalf = function() return _offsetOpt(halfOffset, o, roughnessGain) end
  local randomFull = function() return _offsetOpt(offset, o, roughnessGain) end
  local preserveVertices = o.preserveVertices
  if move then
    if overlay then
      local t = {
        op = 'move',
        data = {
          x1 + (preserveVertices and 0 or randomHalf()),
          y1 + (preserveVertices and 0 or randomHalf()),
        }
      }
      ops[#ops+1] = t
    else
      local t = {
        op = 'move',
        data = {
          x1 + (preserveVertices and 0 or _offsetOpt(offset, o, roughnessGain)),
          y1 + (preserveVertices and 0 or _offsetOpt(offset, o, roughnessGain)),
        },
      }
      ops[#ops+1] = t
    end
  end
  if overlay then
    local t = {
      op = 'bcurveTo',
      data = {
          midDispX + x1 + (x2 - x1) * divergePoint + randomHalf(),
          midDispY + y1 + (y2 - y1) * divergePoint + randomHalf(),
          midDispX + x1 + 2 * (x2 - x1) * divergePoint + randomHalf(),
          midDispY + y1 + 2 * (y2 - y1) * divergePoint + randomHalf(),
          x2 + (preserveVertices and 0 or randomHalf()),
          y2 + (preserveVertices and 0 or randomHalf()),
        }
    }
    ops[#ops+1] = t
  else
    local t = {
      op = 'bcurveTo',
      data = {
        midDispX + x1 + (x2 - x1) * divergePoint + randomFull(),
        midDispY + y1 + (y2 - y1) * divergePoint + randomFull(),
        midDispX + x1 + 2 * (x2 - x1) * divergePoint + randomFull(),
        midDispY + y1 + 2 * (y2 - y1) * divergePoint + randomFull(),
        x2 + (preserveVertices and 0 or randomFull()),
        y2 + (preserveVertices and 0 or randomFull()),
      }
    }
    ops[#ops+1] = t
  end
  return ops
end

local function _doubleLine(x1, y1, x2, y2, o, filling)
    local singleStroke = filling and o.disableMultiStrokeFill or o.disableMultiStroke
    local o1 = _line(x1, y1, x2, y2, o, true, false)
    if singleStroke then
      return o1
    end
    local o2 = _line(x1, y1, x2, y2, o, true, true)
    -- fusing arrays
    local t = {}
    local n = 0
    for _,v in ipairs(o1) do
      n = n + 1
      t[n] = v
    end
    for _,v in ipairs(o2) do
      n = n + 1
      t[n] = v
    end
    return t
end

-- From renderer.ts (public functions)

local function line(x1, y1, x2, y2, o)
  return { type = 'path', ops = _doubleLine(x1, y1, x2, y2, o) }
end

local function linearPath(points, close, o)
  local len = #(points or {})
  if len >= 2 then
    local ops = {}
    for i = 1, len - 1 do
      local t = _doubleLine(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2], o)
      for k = 1, #t do
        ops[#ops+1] = t[k]
      end
    end
    if close then
      local t = _doubleLine(points[len][1], points[len][2], points[1][1], points[1][2], o)
      for k = 1, #t do
        ops[#ops+1] = t[k]
      end
    end
    return { type = 'path', ops = ops }
  elseif len == 2 then
    return line(points[1][1], points[1][2], points[2][1], points[2][2], o)
  end
  return { type = 'path', ops = {} }
end

local function polygon(points, o)
  return linearPath(points, true, o)
end

local function rectangle(x, y, width, height, o)
  local points = {
    {x, y},
    {x + width, y},
    {x + width, y + height},
    {x, y + height}
  }
  return polygon(points, o)
end

-- from geometry.ts

local function rotatePoints(points, center, degrees)
  if points and #points ~= 0 then
    local cx = center[1]
    local cy = center[2]
    local angle = (math.pi / 180) * degrees
    local cos = math.cos(angle)
    local sin = math.sin(angle)
    for _,p in ipairs(points) do
      local x = p[1]
      local y = p[2]
      p[1] = ((x - cx) * cos) - ((y - cy) * sin) + cx
      p[2] = ((x - cx) * sin) + ((y - cy) * cos) + cy
    end
  end
end

local function rotateLines(lines, center, degrees)
  local points = {}
  for _,line in ipairs(lines) do
    for _,l in ipairs(line) do
      points[#points + 1] = l
    end
  end
  rotatePoints(points, center, degrees);
end

-- from fillers/scan-line-hachure.ts

-- quick Lua shim...
local function table_splice(tbl, start, length) -- from xlua
  length = length or 1
  start = start or 1
  local endd = start + length
  local spliced = {}
  local remainder = {}
  for i,elt in ipairs(tbl) do
      if i < start or i >= endd then
        table.insert(spliced, elt)
      else
        table.insert(remainder, elt)
      end
  end
  return spliced, remainder
end
local function math_round (x) -- quick Lua shim
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

local function straightHachureLines (polygonList, gap)
  local vertexArray = {}
  for _,polygon in ipairs(polygonList) do
    -- local vertices = [...polygon]
    local vertices = polygon -- NOTE Should we make a copy? Why the spreading in JS ?
    if vertices[1][1] ~= vertices[#vertices][1] and vertices[1][2] ~= vertices[#vertices][2] then
      vertices[#vertices + 1] = { vertices[1][1], vertices[1][2] }
    end
    if #vertices > 2 then
      vertexArray[#vertexArray + 1] = vertices
    end
  end

  local lines = {}
  gap = math.max(gap, 0.1)

  -- Create sorted edges table
  local edges = {}

  for _,vertices in ipairs(vertexArray) do
    for i = 1, #vertices - 1 do
      local p1 = vertices[i]
      local p2 = vertices[i + 1]
      if p1[2] ~= p2[2] then
        local ymin = math.min(p1[2], p2[2])
        edges[#edges + 1] = {
          ymin = ymin,
          ymax = math.max(p1[2], p2[2]),
          x = (ymin == p1[2]) and p1[1] or p2[1],
          islope = (p2[1] - p1[1]) / (p2[2] - p1[2]),
        }
      end
    end
  end

  local f = function (e1, e2)
    if e1.ymin < e2.ymin then
      return true
    end
    if e1.ymin > e2.ymin then
      return false
    end
    if e1.x < e2.x then
      return true
    end
    if e1.x > e2.x then
      return false
    end
    if (e1.ymax < e2.ymax) then
      return true
    end
    if (e1.ymax > e2.ymax) then
     return false
    end
    return true
  end
  table.sort(edges, f)
  if #edges == 0 then
    return lines
  end

  -- Start scanning
  local activeEdges = {}
  local y = edges[1].ymin;
  while (#activeEdges > 0 or #edges > 0) do
    if #edges ~= 0 then
      local ix = 0
      for i = 1, #edges do
        if edges[i].ymin > y then
          break;
        end
        ix = i
      end
      local removed
      edges, removed = table_splice(edges, 1, ix)
      for _,e in ipairs(removed) do
        activeEdges[#activeEdges + 1] = { s = y, edge = e }
      end
    end
    activeEdges = pl.tablex.filter(activeEdges, function (ae)
     if ae.edge.ymax <= y then
       return false
     end
     return true;
    end)
    table.sort(activeEdges, function (ae1, ae2)
      if ae1.edge.x < ae2.edge.x then
        return true
      end
      return false
    end)

    -- fill between the edges
    if (#activeEdges > 1) then
      for i = 1, #activeEdges, 2 do
        local nexti = i + 1
        if nexti > #activeEdges then
          break
        end
        local ce = activeEdges[i].edge;
        local ne = activeEdges[nexti].edge;
        lines[#lines + 1] = {
          { math_round(ce.x), y },
          { math_round(ne.x), y },
        }
      end
    end

    y = y + gap
    for _,ae in ipairs(activeEdges) do
      ae.edge.x = ae.edge.x + (gap * ae.edge.islope)
    end
  end
  return lines
end


local function polygonHachureLines (polygonList, o)
  local angle = o.hachureAngle + 90;
  local gap = o.hachureGap
  if gap < 0 then
    gap = o.strokeWidth * 4
  end
  gap = math.max(gap, 0.1)

  local rotationCenter = {0, 0}
  if angle then
    for _,polygon in ipairs(polygonList) do
      rotatePoints(polygon, rotationCenter, angle)
    end
  end
  local lines = straightHachureLines(polygonList, gap)
  if angle then
    -- NOTE: This code was in rough.js but is not needed, right?
    -- for _,polygon in ipairs(polygonList) do
    --   rotatePoints(polygon, rotationCenter, -angle)
    -- end
    rotateLines(lines, rotationCenter, -angle)
  end
  return lines
end

-- from fillers/harchure-filler.ts

local HachureFiller = pl.class({
  fillPolygons = function (self, polygonList, o)
    local lines = polygonHachureLines(polygonList, o);
    local ops = self:renderLines(lines, o);
    return { type = 'fillSketch', ops = ops }
  end,

  renderLines = function (self, lines, o)
    local ops = {}
    for _,line in ipairs(lines) do
      local t = _doubleLine(line[1][1], line[1][2], line[2][1], line[2][2], o, true) -- NOTE removed helper
      for _,v in ipairs(t) do
        ops[#ops + 1] = v
      end
    end
    return ops;
  end,
})

-- a bit of hack renderer.ts
-- ...

local filler = HachureFiller()
local function patternFillPolygons(polygonList, o)
  return filler:fillPolygons(polygonList, o);
end

-- From generator.ts

local RoughGenerator = pl.class({
  defaultOptions = {
    maxRandomnessOffset = 2,
    roughness = 1,
    bowing = 1,
    stroke = '#000',
    strokeWidth = 1,
    -- curveTightness = 0,
    -- curveFitting = 0.95,
    -- curveStepCount = 9,
    fillStyle = 'hachure',
    -- fillWeight = -1,
    hachureAngle = -41,
    hachureGap = -1,
    -- dashOffset = -1,
    -- dashGap = -1,
    -- zigzagOffset = -1,
    -- seed = 0,
    disableMultiStroke = false,
    disableMultiStrokeFill = false,
    preserveVertices = false,
  },

  _init = function (self, options)
    if options then
      self.defaultOptions = self:_o(options)
    end
  end,

  _d = function (self, shape, sets, options)
    return { shape = shape, sets = sets or {}, options = options or self.defaultOptions }
  end,

  _o = function (self, options)
    return options and pl.tablex.union(self.defaultOptions, options) or self.defaultOptions
  end,

  line = function (self, x1, y1, x2, y2, options)
    local o = self:_o(options)
    return self:_d('line', { line(x1, y1, x2, y2, o) }, o)
  end,

  rectangle = function (self, x, y, width, height, options)
    local o = self:_o(options)

    local paths = {}
    local outline = rectangle(x, y, width, height, o)
    if o.fill then
      local points = { {x, y}, {x + width, y}, {x + width, y + height}, {x, y + height} }
      if o.fillStyle == 'solid' then
        SU.error("Rough fill (solid) not yet implemented.")
        -- paths.push(solidFillPolygon([points], o));
      else
        paths[#paths + 1] = patternFillPolygons({ points }, o)
      end
    end
    if o.stroke ~= 'none' then
      paths[#paths+1] = outline
    end
    return self:_d('rectangle', paths, o)
  end,
})

-- From svg.ts but adapted to output PDF graphic objects
-- The RoughPdf API is somewhat experimental and subject to changes

local RoughPdf = pl.class({
  opsToPath = function (self, drawing, fixedDecimals)
    local path = ''
    for _,item in ipairs(drawing.ops) do
      local data = item.data
      -- NOTE TODO: Initial code had:
      -- const data = ((typeof fixedDecimals === 'number') && fixedDecimals >= 0) ? (item.data.map((d) => +d.toFixed(fixedDecimals))) : item.data;
      if item.op == 'move' then
          path = path .. data[1] .. ' ' .. data[2] .. " m "
      elseif item.op == 'bcurveTo' then
          path = path .. data[1] .. " " .. data[2] .. " " .. data[3] .. " " .. data[4] .. " " .. data[5] .. " " .. data[6] .. " c "
      elseif item.op == "lineTo" then
          path = path .. data[1] .. " " ..  data[2] .. " l "
      end
    end
    return path -- .trim() TODO
  end,

  draw = function (self, drawable)
    local sets = drawable.sets or {}
    local o = drawable.options -- or this.getDefaultOptions(); TODO ??
    local precision = drawable.options.fixedDecimalPlaceDigits
    local g = {}
    for _,drawing in ipairs(sets) do
      local path
      if drawing.type == "path" then
        path = self:opsToPath(drawing, precision)
        -- NOTE the original implementation was doing the stroking, coloring etc. here.
      elseif drawing.type == "fillPath" then
        SU.error("Path filling not yet implemented.")
      elseif drawing.type == "fillSketch" then
        path = self:opsToPath(drawing, precision)
        -- NOTE as above stroking and coloring was done here.
      end
      if path then
        g[#g + 1] = path
      end
    end
    return table.concat(g, " ")
  end
})

-- Exports

return {
  RoughGenerator = RoughGenerator,
  RoughPdf = RoughPdf,
}