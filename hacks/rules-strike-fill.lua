-- HACK: Adds OS/2 table parsing to the OpenType parser.
local hb = require "justenoughharfbuzz"
local vstruct = require "vstruct"
local ot = SILE.require("core.opentype-parser")

local function parseOs2(s)
  if s:len() <= 0 then
    return
  end
  local fd = vstruct.cursor(s)
  local header = vstruct.read(
      ">version:u2 xAvgCharWidth:i2 usWeightClass:u2 usWidthClass:u2 fsType:u2 ySubscriptXSize:i2 ySubscriptYSize:i2 ySubscriptXOffset:i2 ySubscriptYOffset:i2 ySuperscriptXSize:i2 ySuperscriptYSize:i2 ySuperscriptXOffset:i2 ySuperscriptYOffset:i2, yStrikeoutSize:i2 yStrikeoutPosition:i2",
      fd)
  return {
    yStrikeoutPosition = header.yStrikeoutPosition,
    yStrikeoutSize = header.yStrikeoutSize,
    -- Just for experimenting, will be later removed.
    ySubscriptXSize = header.ySubscriptXSize,
    ySubscriptYSize = header.ySubscriptYSize,
    ySubscriptXOffset = header.ySubscriptXOffset,
    ySubscriptYOffset = header.ySubscriptYOffset,
    ySuperscriptXSize = header.ySuperscriptXSize,
    ySuperscriptYSize = header.ySuperscriptYSize,
    ySuperscriptXOffset = header.ySuperscriptXOffset,
    ySuperscriptYOffset = header.ySuperscriptYOffset
  }
end

local oldParseFont = ot.parseFont
ot.parseFont = function(face)
  local font = oldParseFont(face)
  font.os2 = parseOs2(hb.get_table(face.data, face.index, "OS/2"))
  return font
end

local function getUnderlineParameters()
  -- local ot = require("core.opentype-parser")
  local fontoptions = SILE.font.loadDefaults({})
  local face = SILE.font.cache(fontoptions, SILE.shaper.getFace)
  local font = ot.parseFont(face)
  local upem = font.head.unitsPerEm
  local underlinePosition = font.post.underlinePosition / upem * fontoptions.size
  local underlineThickness = font.post.underlineThickness / upem * fontoptions.size
  return underlinePosition, underlineThickness
end

local function getStrikethroughParameters()
  -- local ot = SILE.require("core.opentype-parser")
  local fontoptions = SILE.font.loadDefaults({})
  local face = SILE.font.cache(fontoptions, SILE.shaper.getFace)
  local font = ot.parseFont(face)
  local upem = font.head.unitsPerEm
  local yStrikeoutPosition = font.os2.yStrikeoutPosition / upem * fontoptions.size
  local yStrikeoutSize = font.os2.yStrikeoutSize / upem * fontoptions.size
  return yStrikeoutPosition, yStrikeoutSize
end

local hrulefillglue = pl.class({
  _base = SILE.nodefactory.hfillglue,
  raise = SILE.measurement(),
  thickness = SILE.measurement("0.2pt"),
  outputYourself = function (self, typesetter, line)
    local outputWidth = SU.rationWidth(self.width, self.width, line.ratio):tonumber()
    local oldx = typesetter.frame.state.cursorX
    typesetter.frame:advancePageDirection(-self.raise)
    typesetter.frame:advanceWritingDirection(outputWidth)
    local newx = typesetter.frame.state.cursorX
    local newy = typesetter.frame.state.cursorY
    SILE.outputter:drawRule(oldx, newy, newx - oldx, self.thickness)
    typesetter.frame:advancePageDirection(self.raise)
  end,
})

SILE.registerCommand("hrulefill", function(options, _)
  local raise
  local thickness
  if options.position and options.raise then
    SU.error("hrulefill cannot have both position and raise parameters")
  end
  if options.thickness then
    thickness = SU.cast("measurement", options.thickness)
  end
  if options.position == "underline" then
    local underlinePosition, underlineThickness = getUnderlineParameters()
    thickness = thickness or underlineThickness
    raise = underlinePosition
  elseif options.position == "strikethrough" then
    local yStrikeoutPosition, yStrikeoutSize = getStrikethroughParameters()
    thickness = thickness or yStrikeoutSize
    raise = yStrikeoutPosition + thickness / 2
  elseif options.position then
    SU.error("Unknown hrulefill position '" .. options.position .. "'")
  else
    raise = SU.cast("measurement", options.raise or "0")
  end

  -- We also hacked pushExplicitGlue in weird ways, these hacks are becoming messy...
  -- Revert here to the original equivalent behavior.
  local node = hrulefillglue({
    raise = raise,
    thickness = thickness or SILE.measurement("0.2pt")
  })
  node.explicit = true
  node.discardable = false
  return SILE.typesetter:pushHorizontal(node)
end, "Add a huge horizontal hrule glue")

SILE.registerCommand("fullrule", function(options, _)
  local thickness = SU.cast("measurement", options.thickness or "0.2pt")
  local raise = SU.cast("measurement", options.raise or "0.5em")

  -- BEGIN DEPRECATION COMPATIBILITY
  if options.height then
    SU.deprecated("\\fullrule[…, height=…]", "\\fullrule[…, thickness=…]", "0.13.0", "0.14.0")
    thickness = SU.cast("measurement", options.height)
  end
  if not SILE.typesetter:vmode() then
    SU.deprecated("\\fullrule in horizontal mode", "\\hrule or \\hrulefill", "0.13.0", "0.14.0")
    if options.width then
      SU.deprecated("\\fullrule with width", "\\hrule and \\raise", "0.13.0", "0.14.0")
      SILE.call("raise", {
        height = raise
      }, function()
        SILE.call("hrule", {
          height = thickness,
          width = options.width
        })
      end)
    else
      -- This was very broken anyway, as it was overflowing the line.
      -- At least we try better...
      SILE.call("hrulefill", {
        raise = raise,
        thickness = thickness
      })
    end
    return
  end
  if options.width then
    SU.deprecated("\\fullrule with width", "\\hrule and \\raise", "0.13.0", "0.14.0")
    SILE.call("raise", {
      height = raise
    }, function()
      SILE.call("hrule", {
        height = thickness,
        width = options.width
      })
    end)
  end
  -- END DEPRECATION COMPATIBILITY

  SILE.typesetter:leaveHmode()
  SILE.call("noindent")
  SILE.call("hrulefill", {
    raise = raise,
    thickness = thickness
  })
  SILE.typesetter:leaveHmode()
end, "Draw a full width hrule centered on the current line")

SILE.registerCommand("underline", function(_, content)
  local underlinePosition, underlineThickness = getUnderlineParameters()

  local hbox = SILE.call("hbox", {}, content)
  table.remove(SILE.typesetter.state.nodes) -- steal it back...

  -- Re-wrap the hbox in another hbox responsible for boxing it at output
  -- time, when we will know the line contribution and can compute the scaled width
  -- of the box, taking into account possible stretching and shrinking.
  SILE.typesetter:pushHbox({
    inner = hbox,
    width = hbox.width,
    height = hbox.height,
    depth = hbox.depth,
    outputYourself = function(self, typesetter, line)
      local oldX = typesetter.frame.state.cursorX
      local Y = typesetter.frame.state.cursorY
      -- Build the original hbox.
      -- Cursor will be moved by the actual definitive size.
      self.inner:outputYourself(SILE.typesetter, line)
      local newX = typesetter.frame.state.cursorX
      -- Output a line.
      -- NOTE: According to the OpenType specs, underlinePosition is "the suggested distance of
      -- the top of the underline from the baseline" so it seems implied that the thickness
      -- should expand downwards
      SILE.outputter:drawRule(oldX, Y - underlinePosition, newX - oldX, underlineThickness)
    end
  })
end, "Underlines some content")

SILE.registerCommand("strikethrough", function(_, content)
  local yStrikeoutPosition, yStrikeoutSize = getStrikethroughParameters()

  local hbox = SILE.call("hbox", {}, content)
  table.remove(SILE.typesetter.state.nodes) -- steal it back...

  -- Re-wrap the hbox in another hbox responsible for boxing it at output
  -- time, when we will know the line contribution and can compute the scaled width
  -- of the box, taking into account possible stretching and shrinking.
  SILE.typesetter:pushHbox({
    inner = hbox,
    width = hbox.width,
    height = hbox.height,
    depth = hbox.depth,
    outputYourself = function(self, typesetter, line)
      local oldX = typesetter.frame.state.cursorX
      local Y = typesetter.frame.state.cursorY
      -- Build the original hbox.
      -- Cursor will be moved by the actual definitive size.
      self.inner:outputYourself(SILE.typesetter, line)
      local newX = typesetter.frame.state.cursorX
      -- Output a line.
      -- NOTE: The OpenType spec is not explicit regarding how the size
      -- (thickness) affects the position. We opt to distribute evenly
      SILE.outputter:drawRule(oldX, Y - yStrikeoutPosition - yStrikeoutSize / 2, newX - oldX, yStrikeoutSize)
    end
  })
end, "Strikes out some content")
