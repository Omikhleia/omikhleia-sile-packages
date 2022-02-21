--
-- Fancy framed boxes for SILE
-- License: MIT
--
SILE.settings.declare({
  parameter = "framebox.padding",
  type = "measurement",
  default = SILE.measurement("2pt"),
  help = "Padding applied to a framed box."
})

SILE.settings.declare({
  parameter = "framebox.borderwidth",
  type = "measurement",
  default = SILE.measurement("0.4pt"),
  help = "Border width applied to a frame box."
})

SILE.settings.declare({
  parameter = "framebox.cornersize",
  type = "measurement",
  default = SILE.measurement("5pt"),
  help = "Corner size (arc radius) for rounded boxes."
})

SILE.settings.declare({
  parameter = "framebox.shadowsize",
  type = "measurement",
  default = SILE.measurement("3pt"),
  help = "Shadow width applied to a framed box when dropped shadow is enabled."
})

-- Draw given paths on an hbox (wrapping it in another hbox).
-- It assumes the hbox is NOT in the output queue
-- (i.e. was stolen back and/or stored earlier).
local makefbox = function(hbox, padding, shadowsize, path, shadowpath)
  SILE.typesetter:pushHbox({
    inner = hbox,
    width = hbox.width + 2 * padding + shadowsize,
    height = hbox.height + padding,
    depth = hbox.depth + padding + shadowsize,
    outputYourself = function(self, typesetter, line)
      local saveY = typesetter.frame.state.cursorY
      local saveX = typesetter.frame.state.cursorX

      if shadowpath then
        SILE.outputter:drawSVG(shadowpath, saveX, saveY, self.width, self.height, 1)
      end
      SILE.outputter:drawSVG(path, saveX, saveY, self.width, self.height, 1)

      -- typesetter.frame.state.cursorY = saveY + padding
      typesetter.frame.state.cursorX = saveX + padding
      self.inner:outputYourself(SILE.typesetter, line)

      typesetter.frame.state.cursorY = saveY
      typesetter.frame.state.cursorX = saveX
      typesetter.frame:advanceWritingDirection(self.width)
    end
  })
end

-- Builds a PDF graphic path from a starting position (x, y)
-- and a set of segments which can be either lines (2 coords)
-- or bezier curves (6 segments)
local makepath = function(x, y, segments)
  local path = x .. " " .. y .. " m "
  for i = 1, #segments do
    local segment = segments[i]
    if #segment == 2 then
      -- line
      x = segment[1] + x
      y = segment[2] + y
      path = path .. x .. " " .. y .. " l "
    else
      -- bezier curve
      path = path .. (segment[1] + x) .. " " .. segment[2] + y .. " " .. (segment[3] + x) .. " " .. segment[4] + y ..
                 " " .. (segment[5] + x) .. " " .. segment[6] + y .. " c "
      x = segment[5] + x
      y = segment[6] + y
    end
  end
  return path
end

-- Builds a PDF graphic color (stroke or fill)
local makecolor = function(color, stroke)
  local colspec
  local colop
  if color.r then -- RGB
    colspec = table.concat({ color.r, color.g, color.b }, " ")
    colop = stroke and "RG" or "rg"
  elseif color.c then -- CMYK
    colspec = table.concat({ color.c, color.m, color.y, color.k }, " ")
    colop = stroke and "K" or "k"
  elseif color.l then -- Grayscale
    colspec = color.l
    colop = stroke and "G" or "g"
  else
    SU.error("Invalid color specification")
  end
  return colspec .. " " .. colop
end

SILE.registerCommand("framebox", function(options, content)
  local padding = SU.cast("measurement", options.padding or SILE.settings.get("framebox.padding")):tonumber()
  local borderwidth = SU.cast("measurement", options.borderwidth or SILE.settings.get("framebox.borderwidth")):tonumber()
  local bordercolor = SILE.colorparser(options.bordercolor or "black")
  local fillcolor = SILE.colorparser(options.fillcolor or "white")
  local shadow = SU.boolean(options.shadow, false)
  local shadowsize = shadow and SU.cast("measurement", options.shadowsize or SILE.settings.get("framebox.shadowsize")):tonumber() or 0
  local shadowcolor = shadow and SILE.colorparser(options.shadowcolor or "black")

  local hbox = SILE.call("hbox", {}, content)
  table.remove(SILE.typesetter.state.nodes) -- steal it back...

  local w = hbox.width:tonumber() + 2 * padding
  local h = hbox.height:tonumber() + hbox.depth:tonumber() + 2 * padding

  local shadowpath = shadowsize ~= 0 and table.concat({
    shadowsize, shadowsize, w, h, "re",
    makecolor(shadowcolor),
    "f"
  }, " ")
  local path = table.concat({
    0, 0, w, h, "re",
    makecolor(bordercolor, true), makecolor(fillcolor, false),
    borderwidth, "w",
    "B"
  }, " ")

  makefbox(hbox, padding, shadowsize, path, shadowpath)
end, "Frames content in a square box.")

SILE.registerCommand("roundbox", function(options, content)
  local padding = SU.cast("measurement", options.padding or SILE.settings.get("framebox.padding")):tonumber()
  local borderwidth = SU.cast("measurement", options.borderwidth or SILE.settings.get("framebox.borderwidth")):tonumber()
  local bordercolor = SILE.colorparser(options.bordercolor or "black")
  local fillcolor = SILE.colorparser(options.fillcolor or "white")
  local shadow = SU.boolean(options.shadow, false)
  local shadowsize = shadow and SU.cast("measurement", options.shadowsize or SILE.settings.get("framebox.shadowsize")):tonumber() or 0
  local shadowcolor = shadow and SILE.colorparser(options.shadowcolor or "black")

  local cornersize = SU.cast("measurement", options.cornersize or SILE.settings.get("framebox.cornersize")):tonumber()

  local hbox = SILE.call("hbox", {}, content)
  table.remove(SILE.typesetter.state.nodes) -- steal it back...

  local w = hbox.width:tonumber() + 2 * padding
  local h = hbox.height:tonumber() + hbox.depth:tonumber() + 2 * padding

  local smallest = w < h and w or h
  cornersize = cornersize < 0.5 * smallest and cornersize or math.floor(0.5 * smallest)

  -- MAYBE LATER: alternative option to set the diameter of the corners arcs to a factor of the lessor
  -- of the width and height of the box, e.g.
  -- local factor = 0.33
  -- local rx = w < h and math.floor(w * factor) or math.floor(h * factor)


  local rx = cornersize
  local ry = rx

  local arc = 4 / 3 * (1.4142135623730951 - 1)
  -- table of segments (2 coords) or bezier curves (6 coords)
  local segments = {
    {(w - 2 * rx), 0}, {(rx * arc), 0, rx, ry - (ry * arc), rx, ry}, {0, (h - 2 * ry)},
    {0, (ry * arc), -(rx * arc), ry, -rx, ry}, {(-w + 2 * rx), 0},
    {-(rx * arc), 0, -rx, -(ry * arc), -rx, -ry}, {0, (-h + 2 * ry)},
    {0, -(ry * arc), (rx * arc), -ry, rx, -ry}
  }
  -- starting point
  local x = rx
  local y = 0

  local shadowpath = shadowsize ~= 0 and table.concat({
    makepath(x + shadowsize, y + shadowsize, segments),
    makecolor(shadowcolor),
    borderwidth, "w",
    "f"
  }, " ")
  local path = table.concat({
    makepath(x, y, segments),
    makecolor(bordercolor, true), makecolor(fillcolor, false),
    borderwidth, "w",
    "B"
  }, " ")

  makefbox(hbox, padding, shadowsize, path, shadowpath)
end, "Frames content in a rounded box.")

local RoughGenerator = require('packages/framebox-rough').RoughGenerator
local RoughPdf = require('packages/framebox-rough').RoughPdf

-- function dump(o, p) -- UGLY DEBUG STUFF FIXME REMOVE
--   p = p or 1
--   local pad = ""
--   for i = 1, p do pad = pad .. " " end
--   if type(o) == 'table' then
--      local s = '{ '
--      for k,v in pairs(o) do
--         if type(k) ~= 'number' then k = '"'..k..'"' end
--         s = s .. '\n  ['.. pad .. k..'] = ' .. dump(v, p+1) .. ','
--      end
--      return s .. '} '
--   else
--      return tostring(o)
--   end
-- end

SILE.registerCommand("roughbox", function(options, content)
  local padding = SU.cast("measurement", options.padding or SILE.settings.get("framebox.padding")):tonumber()
  local borderwidth = SU.cast("measurement", options.borderwidth or SILE.settings.get("framebox.borderwidth")):tonumber()
  local bordercolor = SILE.colorparser(options.bordercolor or "black")

  local hbox = SILE.call("hbox", {}, content)
  table.remove(SILE.typesetter.state.nodes) -- steal it back...

  local w = hbox.width:tonumber() + 2 * padding
  local h = hbox.height:tonumber() + hbox.depth:tonumber() + 2 * padding

  local roughOpts = {}
  if options.roughness then roughOpts.roughness = SU.cast("number", options.roughness) end
  if options.bowing then roughOpts.bowing = SU.cast("number", options.bowing) end
  roughOpts.preserveVertices = SU.boolean(options.preserve, false)
  roughOpts.disableMultiStroke = SU.boolean(options.singlestroke, false)

  local roughGenerator = RoughGenerator()
  local drawable = roughGenerator:rectangle(0, 0, w, h, roughOpts)
  local pathGenerator = RoughPdf()
  local p = pathGenerator:draw(drawable)

  local path = table.concat({
    p,
    makecolor(bordercolor, true),
    borderwidth, "w",
    "S" -- stroke only
  }, " ")

  makefbox(hbox, padding, shadowsize, path, shadowpath)
end, "Frames content in a rough box.")

return {
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]
\script[src=packages/framebox]
\script[src=packages/parbox]

As its name implies, the \doc:keyword{framebox} package provide several horizontal box framing goodies.

The \doc:code{\\framebox} command frames its content in a \framebox{square box.}

The frame border width relies on the
\doc:code{framebox.borderwidth} setting (defaults to 0.4pt), unless the \doc:code{borderwidth} option
is explicitly specified as command argument.

The padding distance between the content and the frame relies on the
\doc:code{framebox.padding} setting (defaults to 2pt), again unless the \doc:code{padding} option
is explicitly specified.

If the \doc:code{shadow} option is set to true, a \framebox[shadow=true]{dropped shadow} is applied.

The shadow width (or offset size) relies on the
\doc:code{framebox.shadowsize} setting (defaults to 3pt), unless the \doc:code{shadowsize} option
is explicitly specified.

With the well-named \doc:code{bordercolor}, \doc:code{fillcolor} and \doc:code{shadowcolor} options, one can
also specify how the box is \framebox[shadow=true, bordercolor=#b94051, fillcolor=#ecb0b8, shadowcolor=220]{colored.}

The color specifications are the same as defined in the \doc:keyword{color} package.

The \doc:code{\\roundbox} command frames its content in a \roundbox{rounded box.}

It supports the same options, so one can have a \roundbox[shadow=true]{dropped shadow} too.

Or likewise, \roundbox[shadow=true, bordercolor=#b94051, fillcolor=#ecb0b8, shadowcolor=220]{apply colors.}

The radius of the rounded corner arc relies on the \doc:code{framebox.cornersize} setting (defaults to 5pt),
unless the \doc:code{cornersize} option, as usual, is explicitly specified as argument to the command.
(If one of the sides of the boxed content is smaller than that, then the maximum allowed rounding effect
will be computed instead.)

Last but not least, there is the experimental \doc:code{\\roughbox} command that frames its content in a
\em{sketchy}, hand-drawn-like style\footnote{The implementation is based on a partial port of
the \em{rough.js} JavaScript library.}: \roughbox[bordercolor=#59b24c]{a rough box.}

As above, the \doc:code{padding}, \doc:code{borderwidth} and \doc:code{bordercolor} options apply.

Sketching options are \doc:code{roughness} (numerical value indicating how rough the drawing is; 0 would
be a perfect  rectangle, the default value is 1 and there is no upper limit to this value but a value
over 10 is mostly useless), \doc:code{bowing} (numerical value indicating how curvy the lines are when
drawing a sketch; a value of 0 will cause straight lines and the default value is 1),
\doc:code{preserve} (defaults to false; when set to true, the locations of the end points are not
randomized) and \doc:code{singlestroke} (defaults to false; if set to true, a single stroke is applied
to sketch the shape instead of multiple strokes).
For instance, here is a single-stroked \roughbox[bordercolor=#59b24c, singlestroke=true]{rough box.}

As final notes, the box logic provided in this package applies to the natural size of the box content.

Thus \roundbox{a}, \roundbox{b} and \roundbox{p.}

To avoid such an effect, one could for instance consider inserting a \doc:code{\\strut} in the content.
This command is provided by the \doc:keyword{parbox} package.

Thus now \roundbox{\strut{}a}, \roundbox{\strut{}b} and \roundbox{\strut{}p.}

The latter package can also be used to shape whole paragraphs into an horizontal box. It may make a good
candidate if you want to use the commands provided here around paragraphs:

\center{\framebox[shadow=true]{\parbox[valign=middle,width=4cm]{This is a long content as a boxed paragraph.}}}

\smallskip
And as real last words, obviously, framed boxes are just horizonal boxes – so they will not be subject
to line-breaking and the users are warned that they have to check that their content doesn’t cause
the line to overflow. Also, as can be seen in the examples above, the padding and the dropped shadow may
naturally alter the line height.

\end{document}]]
}
