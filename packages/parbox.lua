--
-- Paragraph blocks ("parbox") for SILE
-- A building block for more advanced concepts.
-- 2021, Didier Willis
-- License: MIT
--
SILE.require("packages/rebox")

SILE.settings.declare({
  parameter = "parbox.strut.character",
  type = "string",
  default = "|",
  help = "Strut character"
})

SILE.settings.declare({
  parameter = "parbox.strut.ruledepth",
  type = "length",
  default = SILE.length("0.3bs"),
  help = "Strut rule depth"
})

SILE.settings.declare({
  parameter = "parbox.strut.ruleheight",
  type = "length",
  default = SILE.length("1bs"),
  help = "Strut rule height"
})

-- Strut character (for a given font) will be used a lot, a bit dumb to recompute it each time.
-- So let's cache it.
local strutCache = {}
local _key = function (options)
  return table.concat({ options.family, ("%d"):format(options.weight), options.style,
                        options.variant, options.features, options.filename }, ";")
end
local characterStrut = function ()
  local key = _key(SILE.font.loadDefaults({}))
  local hbox = strutCache[key]
  if hbox then return hbox end
  local hbox = SILE.call("hbox", {}, { SILE.settings.get("parbox.strut.character") })
  table.remove(SILE.typesetter.state.nodes) -- steal it back
  strutCache[key] = hbox
  return hbox
end

SILE.registerCommand("strut", function (options, content)
  local method = options.method or "character"
  local show = SU.boolean(options.show, true)
  local strut
  if method == "rule" then
    strut = {
      height = SILE.settings.get("parbox.strut.ruleheight"):absolute(),
      depth = SILE.settings.get("parbox.strut.ruledepth"):absolute(),
      width = SILE.length()
    }
    if show then
      -- The "x" there could be anything, we just want to be sure we get a box
      SILE.call("rebox", { phantom = true, height = strut.height, depth = strut.depth, width = strut.width }, { "x" })
    end
  else
    strut = characterStrut()
    if show then
      SILE.call("rebox", { phantom = true, width = SILE.length() }, { SILE.settings.get("parbox.strut.character") })
    end
  end
  return strut
end, "Formats a strut box.")

local nb_ = 1
local parboxTempFrame = function (options)
  local cFrame = SILE.typesetter.frame
  local newFrame = SILE.newFrame({
    id = cFrame.id .. "_parbox_"..nb_
  })
  nb_ = nb_+1
  -- We don't even need to register it, we just use it temporarily.
  -- SILE.documentState.thisPageTemplate.frames[newFrame.id] = newFrame
  newFrame:constrain("top", SILE.length())
  newFrame:constrain("bottom", SILE.length())
  newFrame:constrain("left", SILE.length())
  newFrame:constrain("right", options.width)
  return newFrame
end

-- Move migrating content (e.g. footnotes) from
-- a typesetter to another
local moveMigrating = function (fromTypesetter, toTypesetter)
  local nodelist = fromTypesetter.state.nodes
  
  local hasStartedMigration = false
  
  local i = 1
  while i <= #nodelist do
    if nodelist[i].is_migrating then
      if not hasStartedMigration then
        -- In some complex table scenario using lots of embedded parboxes, with parindent
        -- enabled, something went wrong (weird extra spacing). There was no issue with
        -- parindent to 0.
        -- Found elsewhere in the code, about such zerobox: "Setup queue but avoid calling newPar"
        -- and indeed, seems to fix my issue. Not sure what it really does, there might be dragons
        -- here.
        toTypesetter.state.nodes[#toTypesetter.state.nodes+1] = SILE.nodefactory.zerohbox()
        hasStartedMigration = false
      end
      toTypesetter:pushHorizontal(nodelist[i])
      table.remove(nodelist, i)
    else
      i = i + 1
    end
  end
end

local parboxFraming = function (options, content)
  local nodes
  local oldTypesetter = SILE.typesetter
  local parboxTypesetter
  local innerVbox

  SILE.settings.pushState()
  SILE.settings.toplevelState()  
  parboxTypesetter = SILE.defaultTypesetter {}

  local originalLeaveHmode = parboxTypesetter.leaveHmode
  parboxTypesetter.leaveHmode = function (self, _)
    -- Move migrating material
    moveMigrating(parboxTypesetter, oldTypesetter)
    -- NEVER output, just gather the nodes, hence the enforced 1 here.
    originalLeaveHmode(self, 1)
  end
  -- Finally we don't need to override the endline
  -- method, we enforced the 1 in leaveHMode.
  -- parboxTypesetter.endline = function (self)
  --   self:leaveHmode(1)
  --   SILE.documentState.documentClass.endPar(self)
  -- end
  parboxTypesetter.frame = parboxTempFrame(options)
  parboxTypesetter:init(parboxTypesetter.frame)
  SILE.typesetter = parboxTypesetter

  SILE.process(content)
  parboxTypesetter:leaveHmode(1)
  innerVbox = parboxTypesetter.state.outputQueue

  SILE.typesetter = oldTypesetter
  SILE.settings.popState()
  return innerVbox
end

local drawBorders = function (x, y, w, h, border)
  -- There's a little ugly tweak here, the bottom border is drawn below the box.
  -- So that successive vertical parboxes have overlapping borders.
  -- Tables (ptable package) rely on it... That's not perfect, but might not be
  -- too much noticeable with normal border thickness below 1pt...
  if border[1] > 0 then SILE.outputter:drawRule(x, y, w, border[1]) end
  if border[2] > 0 then SILE.outputter:drawRule(x, y + h, w, border[2]) end
  if border[3] > 0 then SILE.outputter:drawRule(x, y, border[3], h + border[2]) end
  if border[4] > 0 then SILE.outputter:drawRule(x + w, y, border[4], h + border[2]) end
end

local insertStruts = function (vboxlist, strut)
  -- The core assumption here is that first/last vboxes are actual text
  -- lines. Could be wrong...
  for i = 1, #vboxlist do
    if vboxlist[i].is_vbox and vboxlist[i].height < strut.height then
      vboxlist[i].height = strut.height -- Hack height of first vbox
      break
    end
  end
  for i = #vboxlist, 1, - 1 do
    if vboxlist[i].is_vbox and vboxlist[i].depth < strut.depth then
      vboxlist[i].depth = strut.depth -- Hack depth of first vbox
      break 
    end
  end
end

local parseBorderOrPadding = function (rawspec, opt)
  local spec
  if type(rawspec) == "table" then
    spec = rawspec
  else
    spec = {}
    for token in SU.gtoke(rawspec, "[ ]+") do
      if(token.string) then
        local value = SU.cast("length", token.string)
        spec[#spec+1] = value:tonumber()
      end
    end
  end
  if #spec == 1 then
    return { spec[1], spec[1], spec[1], spec[1] }
  end
  if #spec ~= 4 then SU.error("Invalid "..opt.." specification: "..textspec) end
  return spec
end

SILE.registerCommand("parbox", function (options, content)
  local width = SU.required(options, "width", "parbox")
  local strut = options.strut or "none"
  local border = options.border and parseBorderOrPadding(options.border, "border") or { 0, 0, 0, 0 }
  local valign = options.valign or "top"
  local padding = options.padding and parseBorderOrPadding(options.padding, "padding") or { 0, 0, 0, 0 }

  width = SU.cast("length", width):absolute()

  local vboxes = parboxFraming({ width = width }, content)

  local strutDimen
  if strut == "rule" then
    strutDimen = SILE.call("strut", { method = "rule" })
    insertStruts(vboxes, strutDimen)
  elseif strut == "character" then
    strutDimen = SILE.call("strut", { method = "character" })
    insertStruts(vboxes, strutDimen)
  else
    strutDimen = { height = SILE.length(0), depth = SILE.length(0) }
  end

  local totalHeight = 0
  for i = 1, #vboxes do
    -- Try to cancel stretching/shrinking
    -- But we don't inspect the internal content of the vboxes, maybe
    -- they could have stretching/shrinking too?
    vboxes[i].height = SILE.length(vboxes[i].height:tonumber())
    vboxes[i].depth = SILE.length(vboxes[i].depth:tonumber())

    totalHeight = totalHeight + vboxes[i].height + vboxes[i].depth 
  end

  local z0 = SILE.length(0)
  local depth, height
  if valign == "bottom" then
    depth = z0 + strutDimen.depth + padding[2]
    height = totalHeight - strutDimen.depth + padding[1]
  elseif valign == "middle" then
    depth = totalHeight / 2 - strutDimen.height / 2 + strutDimen.depth / 2 + (padding[2] + padding[1]) / 2
    height = totalHeight / 2 + strutDimen.height / 2 - strutDimen.depth / 2 + (padding[2] + padding[1]) / 2
  else -- valign == top
    depth = totalHeight - strutDimen.height + padding[1]
    height = z0 + strutDimen.height + padding[1]
  end

  return SILE.typesetter:pushHbox({
    width = width + padding[3] + padding[4],
    depth = depth:absolute(),
    height = height:absolute(),
    inner = vboxes,
    valign = valign,
    padding = padding,
    offset = SILE.length(), -- INTERNAL: See comment below.
    border = border,
    outputYourself= function (self, typesetter, line)
      local saveY = typesetter.frame.state.cursorY
      local saveX = typesetter.frame.state.cursorX

      typesetter.frame.state.cursorY = saveY - self.height
      drawBorders(
        typesetter.frame.state.cursorX:tonumber(),
        typesetter.frame.state.cursorY:tonumber(),
        self.width:tonumber(),
        self.depth:tonumber() + self.height:tonumber(),
        self.border
      )

      -- Process each vbox
      typesetter.frame.state.cursorY = typesetter.frame.state.cursorY + self.padding[1] - self.offset
      for i = 1, #self.inner do
        typesetter.frame.state.cursorX = saveX + self.padding[3]
        self.inner[i]:outputYourself(SILE.typesetter, self.inner[i])
      end

      typesetter.frame.state.cursorY = saveY
      typesetter.frame.state.cursorX = saveX
      typesetter.frame:advanceWritingDirection(self.width)
    end
  })
  -- The offset parameter in the pbox above is for INTERNAL use.
  -- The "ptable" package (parbox-base tables) sets it to tweak and adjust cells.
  -- Kind of a mixed concern here, but it's an easy trick to avoid re-implementing
  -- a bunch of things.
end)

return {
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]
\script[src=packages/parbox]

A paragraph box (“parbox”) is an horizontal box (so technically an hbox)
that contains, as its name implies, one or more paragraphs (so the displayed content
is actually made of vbox’es and vertical glues). The only mandatory
option on the \doc:code{\\parbox} command is its \doc:code{width}.
Most of the time, the parbox will be higher that a (regular) text line,
so the option \doc:code{valign} allows to specify the vertical alignment: top, middle,
bottom. Alignment is relative to the current baseline.

Some important concepts and good stuff are described at the end of this documentation
section, but for now let us show a top-aligned parbox.

\smallskip

(1A) \parbox[width=37%fw, valign=top, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\smallskip

And a bottom-aligned parbox.

(1B) \parbox[width=37%fw, valign=bottom, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\smallskip

Finally, the middle-aligned parbox.

(1C) \parbox[width=37%fw, valign=middle, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\medskip

As can be seen, there are however a few issues, if the parbox is intended to be
used (as here) in a regular text flow: the interpretation of “baseline” is
pretty strict, but perhaps unexpected; the line boxing is strict too
and is affected depending on ascenders or descenders. To get what is 
logically a more expected output, one would need some vertical adjustment,
which comes in the form of a “strut” (see further below). Let us try again, but
this time with the \doc:code{strut} option set to “character” (the default, which was used
above, corresponds to “none”).

\smallskip

(2A) \parbox[width=37%fw, valign=top, strut=character, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\smallskip

(2B) \parbox[width=37%fw, valign=bottom, strut=character, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\smallskip

(2C) \parbox[width=37%fw, valign=middle, strut=character, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\medskip

Or we can set it to “rule”.

\smallskip

(3A) \parbox[width=37%fw, valign=top, strut=rule, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\smallskip

(3B) \parbox[width=37%fw, valign=bottom, strut=rule, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\smallskip

(3C) \parbox[width=37%fw, valign=middle, strut=rule, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\medskip

In professional typesetting, a “strut” is a rule with no width but a certain height
and depth, to help guaranteeing that an element has a certain minimal height and depth,
e.g. in tabular environments or in boxes.
Two possible implementations are proposed, one based on a character, defined
via the \doc:code{parbox.strut.character} setting, by default the vertical bar (|), and one relative to the
current baseline skip, via the \doc:code{parbox.strut.ruledepth} and \doc:code{parbox.strut.ruleheight}
settings, by default respectively 0.3bs and 1bs, following the same
definition as in LaTeX. So they do not achieve exactly the same effect:
the former should ideally be a character that covers the maximum ascender and descender
heights in the current font; the other uses an alignment at the baseline skip level
assuming it is reasonably fixed. The standalone command, would you need it, is \doc:code{\\strut[method=…]},
where the method can be “character” (default) or “rule”. It returns the dimensions (for use
in Lua code). If needed, the \doc:code{show} option indicates whether the rule should inserted at this
point (defaults to true).

Footnotes (and migrating material) in a parbox are transferred to the upper
context. So they work as expected, but it is the main rationale behind the rule-based strut
above: footnote calls may consist in raised and scaled content, so you might need a bit
more spacing than just a character-derived ascender height.\footnote{The other reason is,
of course, that the character-based method depends on the font size, which might not be the
same inside the parbox and outside. None of the methods is perfect, as line spacing may
also vary depending on the selected algorithm and settings.}

Let us try parboxes of different heights and footnotes in parboxes…

\smallskip

(4) \parbox[width=37%fw, strut=character, border=0.5pt]{\lorem[words=8]

\center{centered}

\raggedleft{I am ragged\break left}

\medskip

A paragraph after a skip.\footnote{Footnote from 4, left parbox.}
}
(…)
\parbox[width=37%fw, strut=character, border=0.5pt]{\lorem[words=16]\footnote{Footnote
from 4, right parbox.}
} (…)

\smallskip

Another option is \doc:code{padding}, with a length applied on all sides of
the parbox. Say, with 5pt.\footnote{If the padding does not seem to be the
same on the sides and on the top and bottom, it is due to the strut.}

\smallskip

(5) \parbox[width=37%fw, valign=middle, strut=character, padding=5pt, border=0.5pt]{one\par
\lorem[words=8]\par
two}

\smallskip

And finally, all the above examples were all framed specifying a \doc:code{border} option
(as a thickness length, here set to 0.5pt), but obviously the border is not enabled by default, i.e. set to zero.

\smallskip

(6) \parbox[width=37%fw, valign=middle]{one\par
\lorem[words=8]\par
two}

\smallskip

The border and the padding can be specified as a single length (applying on all sides) or a string
containing a space-separated list of four lengths (“top bottom left right”).

We have shown several examples but haven’t mentioned yet what could be one
of the \em{most important concepts} underlying these paragraph boxes: each
of them initializes its own typesetter instance and a dedicated (temporary)
frame.\footnote{For
technically-minded users, the frame is just used to wrap the processing in a constrained
width. The content is afterwards extracted and re-boxed.}
A consequence of the latter remark is that the frame width
(and units expressed in percentages of it) inside the parbox is the actual
width of the parbox. Another notable effect is that centering and right or left
flushing work as expected, out-of-the-box, as could have already been guessed from
example 4 above.
Another important point is that each parbox pushes and resets SILE’s settings
to their top-level values, so that the content inside the parbox may tweak 
them, e.g. fonts, right and left skips, etc. without affecting anything else,
especially other embedded parboxes.

In other terms, the parbox acts as as a sort of semi-independent mini-frame.
In the example below, showing all these features, a centered parbox in italic contains
another parbox, each having a size set to 65\%fw.

\smallskip

(7) \parbox[width=65%fw, valign=middle, strut=character, border=0.5pt]{%
\begin{center}
\font[style=italic]%
A centered parbox in italic.

(7X) \parbox[width=65%fw, valign=middle, strut=character, border=0.5pt]{
Another parbox that does not inherit these
things.\footnote{Footnote from 7X, to see it “cascades”
up to the main frame and the printed page.}} (…)
\par
Isn’t it cool?
\end{center}
}

\smallskip

So to recap, the parbox allows one to set up paragraphs inside
a text box. One word, though, on things that may fail. The struts are
implemented by tweaking the height and depth of the first and last vbox
in the parbox, but with complex content, this might not be very robust.
Likewise, the content may include vertical glues and elements that can
be stretched or shrinked. The implementation attempts at removing
them on the first level, but deeply nested elements might cause
issues. It is a powerful tool and it can be a basis for advanced
box models or for tabular elements\footnote{Cells in complex tables
can be regarded as a good use case for paragraph boxes. See the
\doc:keyword{ptable} package.}, etc.
But be warned there could be some edge-cases. Also, it is worth noting
the current implementation has not been experimented yet in right-to-left
or vertical writing direction.
\end{document}]]
}
