--
-- Simple charts for SILE
-- 2022, Didier Willis
-- License: MIT
--
SILE.require("packages/rotate")
SILE.require("packages/framebox")
SILE.require("packages/struts")

local graphics = require("packages.graphics.renderer")
local PathRenderer = graphics.PathRenderer
local RoughPainter = graphics.RoughPainter

-- COLOR HELPER FUNCTIONS

-- Converts an RGB (Red, Green, Blue) SILE color
-- to HSL (Hue, Saturation, Lightness) with with h, s, l in 0..1
local function rgbToHsl (color)
  local r, g, b = color.r, color.g, color.b
  local max = math.max(r, g, b)
  local min = math.min(r, g, b)
  local h, s
  local l = (max + min) / 2

  if min == max then
    -- achromatic
    h = 0
    s = 0
  else
    local d = max - min
    s = l > 0.5 and (d / (2 - max - min)) or (d / (max + min))
    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    else -- max == b
      h = (r - g) / d + 4
    end
    h = h / 6
  end
  return h, s, l
end

-- Small helper for HSL to RGB (see below)
local function hue2rgb (p, q, t)
  if t < 0 then t = t + 1 end
  if t > 1 then t = t - 1 end
  if t < 1/6 then return p + (q - p) * 6 * t end
  if t < 1/2 then return q end
  if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
  return p
end
-- Converts an HSL (Hue, Saturation, Lightness) with with h, s, l in 0..1
-- to RGB (Red, Green, Blue) SILE
local function hslToRgb (h, s, l)
  local r, g, b;

  if s == 0 then
    -- achromatic
    r = l
    g = l
    b = l
  else
    local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
    local p = 2 * l - q
    r = hue2rgb(p, q, h + 1/3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1/3)
  end
  return { r = r, g = g, b = b }
end

local function colorToHsl (color)
  if color.r then return rgbToHsl(color) end
  if color.k then
    -- First convert CMYK to RGB
    local kr = (1 - color.k)
    return rgbToHsl({
      r = (1 - color.c) * kr,
      g = (1 - color.m) * kr,
      b = (1 - color.y) * kr,
  })
  end
  if color.l then
    -- First convert Grayscale to RGB
    return rgbToHsl({
      r = color.l,
      g = color.l,
      b = color.l,
    })
  end
  SU.error("Invalid color specification")
end

-- MEASUREMENT HELPER FUNCTIONS

-- General note on these functions:
-- We measure all data by constructing hbox'es, so we work in a temporary
-- typesetter state that we can drop all those hboxes afterwards.
-- Let's also cancel the parindent, that may play ugly on the first box
-- in a "line"...
-- POTENTIAL OPTIM: cache boxes for values already seen?

-- Measure categories (first column without the header)
-- Returns the max height and width needed.
local function measureBiggestCategoryDimens (data)
  local maxWidth = SILE.length()
  local maxHeight = SILE.length()

  -- We'll measure all data by constructing an hbox, so work in a temporary
  -- typesetter state that we can drop all those hboxes afterwards.
  -- Let's also cancel parindent...
  SILE.typesetter:pushState()
  SILE.settings.temporarily(function ()
    SILE.settings.set("current.parindent", SILE.length())
    SILE.settings.set("document.parindent", SILE.length())
    for _, entry in ipairs(data) do
      local hbox = SILE.call("hbox", {}, { tostring(entry[1]) })
      if hbox.width > maxWidth then
        maxWidth = hbox.width
      end
      if hbox.height + hbox.depth > maxHeight then
        maxHeight = hbox.height + hbox.depth
      end
    end
    SILE.typesetter:popState()
  end)
  return maxWidth, maxHeight
end

-- Measure headers (first line without first item which is the category header)
-- Returns the max height and width needed.
local function measureBiggestHeadersDimens (data)
  local maxWidth = SILE.length()
  local maxHeight = SILE.length()

  SILE.typesetter:pushState()
  SILE.settings.temporarily(function ()
    SILE.settings.set("current.parindent", SILE.length())
    SILE.settings.set("document.parindent", SILE.length())
    for k = 2, #data.original_fieldnames do
      local entry = data.original_fieldnames[k]
      local hbox = SILE.call("hbox", {}, { tostring(entry) })
      if hbox.width > maxWidth then
        maxWidth = hbox.width
      end
      if hbox.height + hbox.depth > maxHeight then
        maxHeight = hbox.height + hbox.depth
      end
    end
    SILE.typesetter:popState()
  end)
  return maxWidth, maxHeight
end

-- Measure value cells, assuming numbers
-- Returns:
--  - the max height and width needed,
--  - the max and min values
--  - the max number of columns
local function measureBiggestValueDimens (data)
  local maxWidth = SILE.length()
  local maxHeight = SILE.length()
  local minValue, maxValue
  local ncols = 0

  SILE.typesetter:pushState()
  SILE.settings.temporarily(function ()
    SILE.settings.set("current.parindent", SILE.length())
    SILE.settings.set("document.parindent", SILE.length())
    for _, entry in ipairs(data) do
      if #entry > ncols then
        ncols = #entry
      end
      for i = 2, #entry do
        local v = tonumber(entry[i]) or 0
        local hbox = SILE.call("hbox", {}, { tostring(v) })
        if hbox.width > maxWidth then
          maxWidth = hbox.width
        end
        if hbox.height + hbox.depth > maxHeight then
          maxHeight = hbox.height + hbox.depth
        end
        if not minValue or v < minValue then
          minValue = v
        end
        if not maxValue or v > maxValue then
          maxValue = v
        end
      end
    end
    SILE.typesetter:popState()
  end)
  return maxWidth, maxHeight, minValue, maxValue, ncols
end

-- TEXT SCALING TO SIZE

-- Compute the font size needed to fit the target width and
-- show the text accordingly.
-- FIXME. Ideally rotates the text if it would get too small
--   e.g. below a certain ratio (e.g. 0.6 would seem neat: in a 10pt
--   document, anything below 6pt gets too small to read)
local function textToScaledBox(text, width, dimenW, dimenH, angle)
  local fontOptions = SILE.font.loadDefaults({})
  local ratio = width.length:tonumber() / dimenW.length:tonumber()
  ratio = SU.min(ratio,1)
  if ratio > 0.0 then -- FIXME when rotation works: around 0.6
    -- E.g. for a 10pt font, start rotating below 6pt
    SILE.call("font", {size = fontOptions.size * ratio}, function()
      SILE.call("strut", { method = "rule"})
      SILE.process({ text })
    end)
  else
    ratio = width.length:tonumber() / dimenH.length:tonumber()
    ratio = SU.min(ratio, 0.9)
    SILE.call("font", {size = fontOptions.size * ratio}, function()
      SILE.call("strut", { method = "rule"})
      -- FIXME
      -- Rotate doesn't do what I quite wanted, but I am too bad at angles
      -- to understand what it does and how to fix it.
      SILE.call("rotate", { angle = angle }, function ()
        SILE.process({ text })
      end)
    end)
  end
end

-- GRAPH BAR CONSTRUCTION

-- ******************* EXPERIMENTAL EXPERIMENTAL EXPERIMENTAL *******************************
SILE.registerCommand("hbar", function (options, _)
  local value = tostring(options.value)
  local key = tostring(options.key)
  
  local rough = SU.boolean(options.rough, false)
  local maxW, maxH = options.maxW, options.maxH
  local maxCatW, maxCatH = options.maxCatW, options.maxCatH


  local width = SU.cast("length", options.width)
  local height = SU.cast("length", options.height)
  local depth = SU.cast("length", options.depth)
  local painter = PathRenderer(rough and RoughPainter() or nil)
  local borderwidth = SU.cast("measurement", options.borderwidth or "0.3pt"):tonumber()
  local bordercolor = options.bordercolor
  local fillcolor = options.fillcolor

  SILE.call("hbox", {}, function ()
    SILE.settings.temporarily(function ()
      textToScaledBox(value, 0.9 * width, maxW, maxH, -90)
    end)
  end)
  local hValueBox = table.remove(SILE.typesetter.state.nodes) -- steal it back
  SILE.call("hbox", {}, function ()
    SILE.settings.temporarily(function ()
      textToScaledBox(key, width, maxCatW, maxCatH, 90)
    end)
  end)
  local hKeyBox = table.remove(SILE.typesetter.state.nodes) -- steal it back
  if tonumber(value) < 0 then
    -- Swap value and key for negative values.
    local tmp = hKeyBox
    hKeyBox = hValueBox
    hValueBox = tmp
  end

  local boxH = hValueBox.height + hValueBox.depth
  local boxD = hKeyBox.height + hKeyBox.depth
  

  SILE.typesetter:pushHbox({
    width = width:absolute(),
    height = height:absolute() + boxH,
    depth = depth:absolute() + boxD,
    value = hValueBox,
    outputYourself= function (self, typesetter, line)
      local outputWidth = SU.rationWidth(self.width, self.width, line.ratio)

      -- Value
      local saveX = typesetter.frame.state.cursorX
      local saveY = typesetter.frame.state.cursorY
      typesetter.frame:advanceWritingDirection((self.width - hValueBox.width) /  2)
      typesetter.frame:advancePageDirection(-self.height + hValueBox.height)
      
      self.value:outputYourself(typesetter, {ratio = 1})
      typesetter.frame.state.cursorX = saveX
      typesetter.frame.state.cursorY = saveY
      --

      -- Key
      typesetter.frame:advanceWritingDirection((self.width - hKeyBox.width) /  2)
      typesetter.frame:advancePageDirection(self.depth - boxD + hKeyBox.height)
      
      hKeyBox:outputYourself(typesetter, {ratio = 1})
      typesetter.frame.state.cursorX = saveX
      typesetter.frame.state.cursorY = saveY
      --
     
      typesetter.frame:advancePageDirection(-self.height+boxH)
      local oldx = typesetter.frame.state.cursorX
      local oldy = typesetter.frame.state.cursorY
      typesetter.frame:advanceWritingDirection(outputWidth)
      typesetter.frame:advancePageDirection(self.height - boxH + self.depth - boxD)
      local newx = typesetter.frame.state.cursorX
      local newy = typesetter.frame.state.cursorY

      local path = painter:rectangle(0, 0, (newx - oldx):tonumber() , (newy - oldy):tonumber(), {
        fill = fillcolor, stroke = bordercolor, strokeWidth = borderwidth,
        preserveVertices = true,
        -- disableMultiStroke = true,
      })
      SILE.outputter:drawSVG(path, oldx, oldy, newx - oldx, 0, 1)   

      typesetter.frame:advancePageDirection(-self.depth + boxD)
    end
  })
end, "I am ugly to do it this way")  

local function readCsvFile (file)
  local data, err = pl.data.read(file, { csv = true, no_convert = true })
  if not data then
    SU.error("Failure to open CSV file "..file.." (" .. err .. ")")
  end
  return data
end

SILE.registerCommand("charts:bargraph:internal", function (options, content)
  local csvfile = SU.required(options, "csvfile", "bargraph")
  local data = readCsvFile(csvfile)
  local nbars = #data

  local maxW, maxH, minValue, maxValue, ncols = measureBiggestValueDimens(data)
  local maxCatW, maxCatH = measureBiggestCategoryDimens(data)
  local maxHeadW, maxHeadH = measureBiggestHeadersDimens(data)

  local fill = SILE.colorparser(options.xxxfillcolor or "#4880bf") -- FIXME coloring...
  local h, s, l = colorToHsl(fill)


  local barWidth = SILE.length("0.7em"):absolute() 
  local graphWidth = nbars * (ncols - 1) * barWidth
  local graphHeight = SILE.length("4em") -- graphWidth / 2

  -- Sorting and coloring
  local colorFn
  if not options.sort or options.sort == "none" then
    -- no sorting
    colorFn = function(h, s, l, index)
      return hslToRgb(h, s, l)
    end
  elseif options.sort == "ascending" then
    table.sort(data, function (a, b)
      return (tonumber(a[ncols]) or 0) < (tonumber(b[ncols]) or 0)
    end)
    colorFn = function(h, s, l, index)
      local cscale = (1.0 - l) / nbars
      return hslToRgb(h, s, l + cscale * (nbars - index))
    end
  elseif options.sort == "descending" then
    table.sort(data, function (a, b)
      return (tonumber(a[ncols]) or 0) > (tonumber(b[ncols]) or 0)
    end)
    colorFn = function(h, s, l, index)
      local cscale = (1.0 - l) / nbars
      return hslToRgb(h, s, l + cscale * (index - 1))
    end
  else
    SU.error("Invalid sort option '"..options.sort.."' for bargraph")
  end

  local delta = maxValue - minValue
  -- OOPS if delta == 0

  local bordercolor = SILE.colorparser(options.bordercolor or "#a0a0a0")
  

  local barInnerSep = (ncols > 2 and 0.15 or 0) * barWidth
  local barOutterSep = (ncols > 2 and 0.5 or 0.15) * barWidth


  for k, v in ipairs(data) do
    for iv = 2, ncols do
      local hh = (iv - 1) / (#v + 1)
      local fillcolor = colorFn(hh, s, l, k)
      --bordercolor =  hslToRgb(hh, s, l)
      local vx = (tonumber(v[iv]) or 0) / math.abs(delta) * graphHeight:tonumber()
      local key
      if ncols < 3 then
        key = v[1]
      else
        key = data.original_fieldnames[iv]
        maxCatH = maxHeadH
        maxCatW = maxHeadW
      end
      SILE.call("hbar", { rough = options.rough,
        height = vx > 0 and vx or 0,
        depth = vx < 0 and -vx or 0, width = barWidth, 
        sep = 0.15 * barWidth,
        maxH = maxH, maxW = maxW,
        maxCatH = maxCatH, maxCatW = maxCatW,
        fillcolor = fillcolor, bordercolor = bordercolor, value = tonumber(v[iv]) or 0,
          key =  key
        })
        if iv ~= ncols then SILE.call("kern", { width = barInnerSep }) end 
    end
    if k ~= nbars then SILE.call("kern", { width = barOutterSep }) end 
  end
end)

local function frameWrapper (framed, rough, func)
  if framed then
    if rough then
      SILE.call("roughbox", { padding = "1.5spc", borderwidth = 0.3 , singlestroke = true, enlarge = true, preserve = true }, function ()
        func()
      end)
    else
      SILE.call("framebox", { padding = "1.5spc", borderwidth = 0.3 }, function ()
        func()
      end)
    end
  else
    SILE.call("hbox", {}, function ()
      func()
    end)
  end
end

SILE.registerCommand("charts:bargraph", function (options, _)
  local rough = SU.boolean(options.rough, false)
  local framed = SU.boolean(options.framed, true)
  frameWrapper(framed, rough, function ()
    SILE.call("charts:bargraph:internal", options)
  end)
end)

return {
  documentation = [[\begin{document}
Simple charts/graphs. Still an experimental draft.
\end{document}]]
}