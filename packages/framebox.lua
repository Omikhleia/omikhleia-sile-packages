--
-- Fancy framed boxes for SILE
-- License: MIT
--
-- KNOWN ISSUE: RTL writing direction not supported yet. It issues a warning in that case (maybe)
-- and I cannot ensure how it will look... See also TODORTL comments, where things might go wrong,
-- but the standard \underline (rules package) also has some issues apparently, so there might be
-- more at stakes here...
--

-- SETTINGS

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

-- LOW-LEVEL REBOXING HELPERS

-- Rewraps an hbox into in another fake hbox, adding padding all around it
-- and an optional shadowsize to the depth.
-- It assumes the original hbox is NOT in the output queue
-- (i.e. was stolen back and stored).
local adjustPaddingHbox = function(hbox, padding, shadowsize)
  local shadowpadding = shadowsize or 0
  return { -- HACK NOTE: Efficient but might be bad to fake an hbox here without all methods.
    inner = hbox,
    width = hbox.width + 2 * padding + shadowpadding,
    height = hbox.height + padding,
    depth = hbox.depth + padding + shadowpadding,
    outputYourself = function(self, typesetter, line)
      typesetter.frame:advanceWritingDirection(padding)
      self.inner:outputYourself(SILE.typesetter, line)
      typesetter.frame:advanceWritingDirection(padding + shadowpadding)
    end
  }
end

-- Rewraps an hbox into in another hbox responsible for framing it,
-- via a path construction callback called with the target width,
-- height and depth (assuming 0, 0 as original point on the baseline)
-- and must return a PDF graphics.
-- It assumes the initial hbox is NOT in the output queue
-- (i.e. was stolen back and/or stored earlier).
-- It pushes the resulting hbox to the output queue
local frameHbox = function(hbox, shadowsize, pathfunc)
  local shadowpadding = shadowsize or 0
  SILE.typesetter:pushHbox({
    inner = hbox,
    width = hbox.width,
    height = hbox.height,
    depth = hbox.depth,
    outputYourself = function(self, typesetter, line)
      local saveX = typesetter.frame.state.cursorX
      local saveY = typesetter.frame.state.cursorY
      -- Scale to line to take into account strech/shrinkability
      local outputWidth = self:scaledWidth(line)
      -- Force advancing to get the new cursor position
      typesetter.frame:advanceWritingDirection(outputWidth)
      local newX = typesetter.frame.state.cursorX

      -- Compute the target width, height, depth for the frame
      -- TODORTL Should we add or substract the shadow padding?
      local w = (newX - saveX):tonumber() - shadowpadding
      local h = self.height:tonumber() + self.depth:tonumber() - shadowpadding
      local d = self.depth:tonumber() - shadowpadding

      if w < 0 or h < 0 then
        SU.warn("Got negative values ("..w.." ,"..h.."), framebox does not officialy support RTL yet!")
      end

      -- Compute the PDF graphics (path)
      -- TODORTL The various path functions in this package probably break in RTL, we might
      -- need to pass the x, y coordinates and have some extra logic for converting all these
      -- into PDF page spaces...
      local path = pathfunc(w, h, d)

      -- Draw the PDG graphics
      if path then
        SILE.outputter:drawSVG(path, saveX, saveY, w, h, 1)
      end

      -- Restore cursor position and output the content last (so it appears on top of the frame)
      typesetter.frame.state.cursorX = saveX
      self.inner:outputYourself(SILE.typesetter, line)
      typesetter.frame.state.cursorX = newX
    end
  })
end

-- PDF GRAPHICS PATH CONSTRUCTION

-- Builds a PDF graphic path from a starting position (x, y)
-- and a set of segments which can be either lines (2 coords)
-- or bezier curves (6 segments)
local makePath = function(x, y, segments)
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
local makeColor = function(color, stroke)
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

-- BASIC BOX-FRAMING COMMANDS

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
  hbox = adjustPaddingHbox(hbox, padding, shadowsize)

  frameHbox(hbox, shadowsize, function(w, h, d)
    -- just plain rectangles
    local path = table.concat({
      0, d, w, h, "re",
      makeColor(bordercolor, true), makeColor(fillcolor, false),
      borderwidth, "w",
      "B"
    }, " ")
    if shadowsize ~= 0 then
        path = table.concat({
        shadowsize, d + shadowsize, w, h, "re",
        makeColor(shadowcolor),
        "f",
        path
      }, " ")
    end
    return path
  end)
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
  hbox = adjustPaddingHbox(hbox, padding, shadowsize)

  frameHbox(hbox, shadowsize, function(w, h, d)
    local smallest = w < h and w or h
    cornersize = cornersize < 0.5 * smallest and cornersize or math.floor(0.5 * smallest)

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
    local y = d

    local path = table.concat({
      makePath(x, y, segments),
      makeColor(bordercolor, true), makeColor(fillcolor, false),
      borderwidth, "w",
      "B"
    }, " ")
    if shadowsize ~= 0 then
      path = table.concat({
        makePath(x + shadowsize, y + shadowsize, segments),
        makeColor(shadowcolor),
        borderwidth, "w",
        "f",
        path
      }, " ")
    end
    return path
  end)
end, "Frames content in a rounded box.")

local rough = require('rough')
local roughGenerator = rough.RoughGenerator()
local pathGenerator = rough.RoughPdf()

SILE.registerCommand("roughbox", function(options, content)
  local padding = SU.cast("measurement", options.padding or SILE.settings.get("framebox.padding")):tonumber()
  local borderwidth = SU.cast("measurement", options.borderwidth or SILE.settings.get("framebox.borderwidth")):tonumber()
  local bordercolor = SILE.colorparser(options.bordercolor or "black")
  local fillcolor = options.fillcolor and SILE.colorparser(options.fillcolor)

  local enlarge = SU.boolean(options.enlarge, false)

  local hbox = SILE.call("hbox", {}, content)
  table.remove(SILE.typesetter.state.nodes) -- steal it back...
  if enlarge then
    hbox = adjustPaddingHbox(hbox, padding)
  end


  local roughOpts = {}
  if options.roughness then roughOpts.roughness = SU.cast("number", options.roughness) end
  if options.bowing then roughOpts.bowing = SU.cast("number", options.bowing) end
  roughOpts.preserveVertices = SU.boolean(options.preserve, false)
  roughOpts.disableMultiStroke = SU.boolean(options.singlestroke, false)
  roughOpts.strokeWidth = borderwidth

  frameHbox(hbox, shadowsize, function(w, h, d)
    local x = 0
    local y = d
    if not enlarge then
      x = -padding
      y = d - padding
      h = h + 2 * padding
      w = w + 2 * padding
    end

    local drawable = roughGenerator:rectangle(x, y, w, h, roughOpts)
    local p = pathGenerator:draw(drawable)

    local path = table.concat({
      p,
      makeColor(bordercolor, true),
      borderwidth, "w",
      "S" -- stroke only
    }, " ")

    if fillcolor then
      roughOpts.fill = true
      roughOpts.stroke = "none"
      local fdrawable = roughGenerator:rectangle(x, y, w, h, roughOpts)
      local fp = pathGenerator:draw(fdrawable)
      local fillpath = table.concat({
        fp,
        makeColor(fillcolor, true),
        borderwidth, "w",
        "S" -- stroke only
      }, " ")
      path = fillpath .. " " .. path
    end
    return path
  end)
end, "Frames content in a rough box.")

-- EXPERIMENTAL (UNDOCUMENTED)

SILE.registerCommand("roughunder", function (options, content)
  local bordercolor = SILE.colorparser(options.bordercolor or "black")
  local fillcolor = options.fillcolor and SILE.colorparser(options.fillcolor)

  -- Begin taken from the original underline command (rules package)
  local ot = SILE.require("core/opentype-parser")
  local fontoptions = SILE.font.loadDefaults({})
  local face = SILE.font.cache(fontoptions, SILE.shaper.getFace)
  local font = ot.parseFont(face)
  local upem = font.head.unitsPerEm
  local underlinePosition = -font.post.underlinePosition / upem * fontoptions.size
  local underlineThickness = font.post.underlineThickness / upem * fontoptions.size
  -- End taken from the original underline command (rules package)

  local hbox = SILE.call("hbox", {}, content)
  table.remove(SILE.typesetter.state.nodes) -- steal it back...

  local roughOpts = {}
  if options.roughness then roughOpts.roughness = SU.cast("number", options.roughness) end
  if options.bowing then roughOpts.bowing = SU.cast("number", options.bowing) end
  roughOpts.preserveVertices = true
  roughOpts.disableMultiStroke = true
  roughOpts.strokeWidth = underlineThickness

  frameHbox(hbox, nil, function(w, h, d)
    -- NOTE: Using some 1.5 factor, since those sketchy lines are probably best a bit more
    -- lowered than intended...
    local y = h + 1.5 * underlinePosition
    local drawable = roughGenerator:line(0, y, w, y, roughOpts)
    local p = pathGenerator:draw(drawable)

    local path = table.concat({
      p,
      makeColor(bordercolor, true),
      underlineThickness, "w",
      "S" -- stroke only
    }, " ")
    return path -- path
  end)
end, "Underlines some content (experimental)")

return {
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]
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

Last but not least, there is the \doc:code{\\roughbox} command that frames its content in a
\em{sketchy}, hand-drawn-like style\footnote{The implementation is based on a partial port of
the \em{rough.js} JavaScript library.}: \roughbox[bordercolor=#59b24c]{a rough box.}

As above, the \doc:code{padding}, \doc:code{borderwidth} and \doc:code{bordercolor} options apply,
as well as \doc:code{fillcolor}: \roughbox[bordercolor=#b94051,fillcolor=220]{rough \em{hachured} box.}

Sketching options are \doc:code{roughness} (numerical value indicating how rough the drawing is; 0 would
be a perfect  rectangle, the default value is 1 and there is no upper limit to this value but a value
over 10 is mostly useless), \doc:code{bowing} (numerical value indicating how curvy the lines are when
drawing a sketch; a value of 0 will cause straight lines and the default value is 1),
\doc:code{preserve} (defaults to false; when set to true, the locations of the end points are not
randomized) and \doc:code{singlestroke} (defaults to false; if set to true, a single stroke is applied
to sketch the shape instead of multiple strokes).
For instance, here is a single-stroked \roughbox[bordercolor=#59b24c, singlestroke=true]{rough box.}

Compared to the previous box framing commands, rough boxes by default do not take up more horizontal
and vertical space due to their padding, as if the sketchy box was indeed manually added
upon an existing text, without altering line height and spacing. Set the \doc:code{enlarge}
option to true \roughbox[bordercolor=#22427c, enlarge=true]{to revert} this behavior (but also note
that due to their rough style, these boxes may still sometimes overlap with surrounding content).

As final notes, the box logic provided in this package applies to the natural size of the box content.

Thus \roundbox{a}, \roundbox{b} and \roundbox{p.}

To avoid such an effect, one could for instance consider inserting a \doc:code{\\strut} in the content.
This command is provided by the \doc:keyword{struts} package.

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
