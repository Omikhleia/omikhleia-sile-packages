
-- Quick and dirty experimental port of (a subset of) rough.js (https://github.com/rough-stuff/rough)

local function _offset(min, max, ops, roughnessGain)
  return ops.roughness * (roughnessGain or 1) * ((math.random() * (max - min)) + min)
end

local function _offsetOpt(x, ops, roughnessGain)
  return _offset(-x, x, ops, roughnessGain or 1)
end

local function _line(x1, y1, x2, y2, o, move, overlay)
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
  local divergePoint = 0.2 + math.random() * 0.3 -- 0.2 instead of 0.3 ???
  local midDispX = o.bowing * o.maxRandomnessOffset * (y2 - y1) / 200
  local midDispY = o.bowing * o.maxRandomnessOffset * (x1 - x2) / 200
  midDispX = _offsetOpt(midDispX, o, roughnessGain)
  midDispY = _offsetOpt(midDispY, o, roughnessGain)
  local ops = {}
  local randomHalf = function() return _offsetOpt(halfOffset, o, roughnessGain) end
  local randomFull = function() return _offsetOpt(offset, o, roughnessGain) end
  local preserveVertices = o.preserveVertices
  if move then
    -- print("move true")
    if overlay then
      -- print("overlay true")
      local t = {
        op = 'move',
        data = {
          x1 + (preserveVertices and 0 or randomHalf()),
          y1 + (preserveVertices and 0 or randomHalf()),
        }
      }
      ops[#ops+1] = t
      -- print("overlay end true", dump(ops))
    else
      -- print("overlay false")
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
  -- print("_line", dump(ops))
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
    for k,v in ipairs(o1) do
      n = n + 1
      t[n] = v
    end
    for k,v in ipairs(o2) do
      n = n + 1 
      t[n] = v
    end
    -- print("_doubleLine", dump(t), dump(o1), dump(o2))
    return t
end

--

local function line(x1, y1, x2, y2, o)
  return { type = 'path', ops = _doubleLine(x1, y1, x2, y2, o) }
end

local function linearPath(points, close, o)
  local len = #(points or {})
  -- print("LEN", len)
  if len >= 2 then
    local ops = {}
    for i = 1, len - 1 do
      local t = _doubleLine(points[i][1], points[i][2], points[i + 1][1], points[i + 1][2], o)
      for k = 1, #t do
        ops[#ops+1] = t[k]
      end
      -- print("here len >=2", dump(ops))
    end
    if close then
      local t = _doubleLine(points[len][1], points[len][2], points[1][1], points[1][2], o)
      for k = 1, #t do
        ops[#ops+1] = t[k]
      end
    end
    return { type = 'path', ops = ops }
  elseif len == 2 then
    SU.error("CHeck me")
    return line(points[1][1], points[1][2], points[2][1], points[2][2], o)
  end
  return { type = 'path', ops = {} }
end


local function polygon(points, o)
  -- print("polygon")
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

--

local RoughGenerator = pl.class({
  defaultOptions = {
    maxRandomnessOffset = 2,
    roughness = 1,
    bowing = 1,
    stroke = '#000',
    strokeWidth = 1,
    curveTightness = 0,
    curveFitting = 0.95,
    curveStepCount = 9,
    fillStyle = 'hachure',
    fillWeight = -1,
    hachureAngle = -41,
    hachureGap = -1,
    dashOffset = -1,
    dashGap = -1,
    zigzagOffset = -1,
    seed = 0,
    disableMultiStroke = false,
    disableMultiStrokeFill = false,
    preserveVertices = false,
  },

  _init = function (self, o)
    -- TODO merge passed options with defaultOptions...
  end,

  _d = function(self, shape, sets, options)
    return { shape = shape, sets = sets or {}, options = options or self.defaultOptions }
  end;

  rectangle = function (self, x, y, width, height, options)
    -- local o = this._o(options);
    -- TODO
    local o = self.defaultOptions

    local paths = {};
    local outline = rectangle(x, y, width, height, o);
    if o.fill then
      local points = { {x, y}, {x + width, y}, {x + width, y + height}, {x, y + height}};
      if o.fillStyle == 'solid' then
        -- TODO   paths.push(solidFillPolygon([points], o));
      else
        -- TODO paths.push(patternFillPolygons([points], o));
      end
    end
    if o.stroke ~= 'none' then
      -- print("OUTLINE", dump(outline))
      --for k = 1, #outline do
      --  print("----------- addint outline", outline[k])
        paths[#paths+1] = outline
      -- end
      -- print("\n-----outline", #outline, dump(paths))
    end
    return self:_d('rectangle', paths, o)
  end,
})

return {
  RoughGenerator = RoughGenerator,
}