--
-- A table package for SILE
-- Or rather "parbox-based tables", using the parbox package as a building block.
-- 2021, Didier Willis
-- License: MIT
--
SILE.require("packages/parbox")

-- UTILITY FUNCTIONS

-- Parse the cols specification "c1 c2 .. cN" and return
-- an array of numeric values (we work in absolute points afterwards).
local parseColumnSpec = function (colspec)
  local b = {}
  for token in SU.gtoke(colspec, "[, ]+") do
    if (token.string) then
      local value = SU.cast("length", token.string)
      b[#b+1] = value:tonumber()
    end
  end
  if #b == 0 then
    SU.error("Invalid table column specification")
  end
  return b
end

-- Compute a cell width from the column widths,
-- taking into account the cell spanning.
local computeCellWidth = function (col, span, cols)
  local width = 0
  if col > #cols or col + span - 1 > #cols then
    SU.error("Table contains an extraneous column")
  end
  for i = col, col + span - 1 do
    width = width + cols[i]
  end
  return width
end

-- Let's admit that these wall tables assembled from parboxes
-- can be pretty fragile if one starts messing up with glues,
-- etc. There are a number of "dangerous" settings we want to
-- disable temporarily where suitable... The parbox resets the
-- settings to top-level, so we enforce additional settings
-- on top of that... In a heavy-handed way (this function
-- might be call where uneeded strictly speaking but heh...)
local vglueNoStretch = function (vg)
  return SILE.nodefactory.vglue(SILE.length(vg.height.length))
end
local temporarilyClearFragileSettings = function (callback)
  SILE.settings.pushState()
  -- Kill that small lineskip thing that may move rows a bit.
  SILE.settings.set("document.lineskip", SILE.length())
  -- Kill stretchability at baseline and paragraph level.
  SILE.settings.set("document.baselineskip", vglueNoStretch(SILE.settings.get("document.baselineskip")))
  SILE.settings.set("document.parskip", vglueNoStretch(SILE.settings.get("document.parskip")))
  callback()
  SILE.settings.popState()
end

-- CLASSES

-- Used for the re-shaping pass (see below)

local cellNode = pl.class({
  type = "cellnode",
  cellBox = nil,
  valign = nil,
  _init = function (self, cellBox, valign)
    self.cellBox = cellBox
    self.valign = valign
  end,
  height = function (self)
    return self.cellBox.height + self.cellBox.depth
  end,
  adjustBy = function (self, adjustement)
    -- Correct the box by an amount. It was build with "middle" valign,
    -- so we distribute the adjustement evently
    self.cellBox.height = self.cellBox.height + adjustement / 2
    self.cellBox.depth = self.cellBox.depth + adjustement / 2
    -- Handle the alignment opton on cells
    if self.valign == "top" then
      -- Nothing to do
    elseif self.valign == "bottom" then
      self.cellBox.offset =  -adjustement
    else -- assume middle by default
      self.cellBox.offset = -adjustement / 2
    end
  end,
  shipout = function (self)
    SILE.typesetter:pushHbox(self.cellBox)
  end
})

local cellTableNode = pl.class({
  type = "celltablenode",
  rows = nil,
  width = nil,
  _init = function (self, rows, width)
    self.rows = rows
    self.width = width
  end,
  height = function(self)
    local h = 0
    for i = 1, #self.rows do
      h = self.rows[i]:height() + h
    end
    return h
  end,
  adjustBy = function(self, adjustement)
    -- Distribute the adjustment evenly on all all rows
    for i = 1, #self.rows do
      self.rows[i]:adjustBy(adjustement / #self.rows)
    end
  end,
  shipout = function (self)
    SILE.call("parbox", { width = self.width, strut = "character", valign = "middle" }, function()
      temporarilyClearFragileSettings(function()
        for i = 1, #self.rows do
          -- Set up queue but avoid a newPar?
          -- Apparently not needed here.
          -- SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes+1] = SILE.nodefactory.zerohbox()
          self.rows[i]:shipout()
        end
      end)
    end)
  end
})

local rowNode = pl.class({
  type = "rownode",
  cells = {},
  _init = function (self, cells)
    self.cells = cells
  end,
  height = function (self)
    local h = 0
    for i = 1, #self.cells do
      h = SU.max(self.cells[i]:height(), h)
    end
    return h
  end,
  adjustBy = function (self, adjustement)
    local minHeight = self:height() + (adjustement or 0)
    for i = 1, #self.cells do
      self.cells[i]:adjustBy(minHeight - self.cells[i]:height())
    end
  end,
  shipout = function (self)
      -- A regular hbox suffices here
      SILE.call("hbox", {}, function ()
      -- Important hack or a parindent occurs sometimes: Set up queue but avoid a newPar.
      -- We had do to the same weird magic in the parbox package too at one step, see the
      -- comment there.
      SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes+1] = SILE.nodefactory.zerohbox()

      for i = 1, #self.cells do
        self.cells[i]:shipout(width)
      end
    end)
    SILE.typesetter:leaveHmode()
  end
})

-- AST PROCESSING

local processTable = {}

processTable["cell"] = function (content, args, tablespecs)
    local span = SU.cast("integer", content.options.span or 1)
    local pad = tablespecs.cellpadding
    local width = computeCellWidth(args.col, span, tablespecs.cols)

    -- build the parbox...
    local cellBox = SILE.call("parbox", { width = width - 2 * pad,
              padding = pad,
              border = tablespecs.cellborder,
              valign = "middle", strut="character" }, function ()
      temporarilyClearFragileSettings(function()
        SILE.process(content)
      end)
    end)
    table.remove(SILE.typesetter.state.nodes) -- .. but steal it back...
    -- NOTE (reminder): when building the parbox, migrating nodes (e.g. footnote) 
    -- have been moved to the parent typesetter. Stealing the resulting box,
    -- doens't change that. But it occurs before pushing all boxes, I am
    -- unsure where footnotes for long tables spanning over multiple
    -- pages will end up!
    return cellNode(cellBox, content.options.valign)
  end

processTable["celltable"] = function (content, args, tablespecs)
    local span = SU.cast("integer", content.options.span or 1)
    local pad = tablespecs.cellborder
    local width = computeCellWidth(args.col, span, tablespecs.cols)
    local rows = {}
    for i = 1, #content do
      if type(content[i]) == "table" then
        if content[i].command == "row" then
          local row = content[i]
          local node = processTable["row"](row, { width = width, col = args.col }, tablespecs)
          rows[#rows+1] = node
        else
          SU.error("Unexpected '"..content[i].command.."' in celltable")
        end
      end
      -- All text nodes are silently ignored
    end
    return cellTableNode(rows, width)
  end

processTable["row"] = function (content, args, tablespecs)
    SILE.settings.set("document.lineskip", SILE.length())
    local iCell = args.col and args.col or 1
    local cells = {}
    for i = 1, #content do
      if type(content[i]) == "table" then
        local subcell = content[i].command
        if subcell == "cell" or subcell == "celltable" then
          local cell = content[i]
          local node = processTable[subcell](cell, { col = iCell }, tablespecs)
          cells[#cells+1] = node
          iCell = iCell + (cell.options.span and cell.options.span or 1)
        else
          SU.error("Unexpected '"..content[i].command.."' in row")
        end
      end
      -- All text nodes are silently ignored
    end
    return rowNode(cells)
  end

-- COMMAND

-- The table building logic works as follows:
--  1. Parse the AST
--      - Computing widths, spans, etc. on the way
--      - Constructed an object hierarchy
--      - Each true cell is pre-composed in a middle-aligned parbox that is
--        stolen back from the output queue
--  2. Adjust each element in the object hierarchy (= re-shaping)
--      - All lines and cells have consistent height
--      - For cells, apply the alignment.
--  3. Shipout the resulting content
--      - Building the boxes for rows and celltables
--      - Re-using the adjusted boxes for cells.
--
-- For developers, note that there is only one exposed command, "table".
-- The "row", "cell", "celltable" are AST nodes without command in the global
-- scope, so they only exist within the table.
-- All parboxes are constructed middle-aligned, and with "character" strut,
-- which sounds correct for easy height adjustement afterwards.

SILE.registerCommand("ptable", function (options, content)
  local cols = parseColumnSpec(SU.required(options, "cols", "ptable"))
  local cellpadding = SU.cast("length", options.cellpading or "4pt")
  local cellborder = SU.cast("length", options.cellborder or "0.3pt")

  local totalWidth = SU.sum(cols)
  local tablespecs = {
    cols = cols,
    cellpadding = cellpadding,
    cellborder = cellborder
  }

  SILE.typesetter:leaveHmode()
  SILE.call("medskip")

  temporarilyClearFragileSettings(function()
    SILE.settings.set("document.parindent", SILE.length())
    local iRow = 1
    for i = 1, #content do
      if type(content[i]) == "table" then
        if content[i].command == "row" then
          local row = content[i]
          local node = processTable["row"](row, { width = totalWidth, row = iRow }, tablespecs)
          node:adjustBy(0)
          node:shipout()
          iRow = iRow + 1
        else
            SU.error("Unexpected '"..content[i].command.."' in table")
        end
      end
      -- All text nodes in ignored
    end
  end)
  SILE.typesetter:leaveHmode()
  SILE.call("medskip")
end)

return {
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]
\script[src=packages/ptable]

The \doc:keyword{ptable} package provides commands to typeset flexible tables.\footnote{The
name stands for \em{perfect table}… No, just kidding, it stands for \em{parbox-based table},
as the so-called “parbox” is the underlying building block. You don’t have to understand it to
use this package, though.}

There are many different ways tables could be declared. TeX, LaTeX and friends do it in
a certain way. HTML and other W3C standards do it differently. And in the wild world of
XML document formats and specifications, there are many other syntaxes, from fairly
simple to highly complex ones (TEI, OASIS, DITA, CALS…), so this package, while
influenced by some of them, does not try to mimic a specific one in particular.

\smallskip

\em{Table structure.}
\novbreak

The tables proposed here are based on pre-determined column widths, provided
via the mandatory \doc:code{cols} option of the \doc:code{\\ptable} environment.
It implies that the column widths do not automatically adapt to the content,
but inversely that the content will be line-broken etc. to horizontally fit in
fixed-width cells.

That column specification is a space-separated
list of widths (indirectly also determining the expected number
of columns). Let us illustrate it with “50\%fw 50\%fw”.

\begin[cols=50%fw 50%fw]{ptable}
  \begin{row}
    \cell{A\footnote{By the way, footnotes in tables are supported.}}
    \cell{B}
  \end{row}
  \begin{row}
    \cell{C}
    \cell{D}
  \end{row}
\end{ptable}

The other options are \doc:code{cellpadding} (defaults to 4pt) and
\doc:code{cellborder} (defaults to 0.5pt; set it to zero to disable
the borders).

A \doc:code{\\ptable} can only contain \doc:code{\\row} elements. Any other element causes
an error to be reported, and any text content is silently ignored.

In turn, a \doc:code{\\row} can only contain \doc:code{\\cell} or \doc:code{\\celltable}
elements, with the same rules applying. It does not have any option.

The \doc:code{\\cell} is the final element containing text or actually anything
you may want, including complete paragraphs, images, etc. It has two options
(\doc:code{span} and \doc:code{valign}) that will be described later.

The \doc:code{\\celltable} is a specific type of cell related to cells spanning over
multiple rows. It has only one option (\doc:code{span}) and will be addressed later
too.

\smallskip

\em{Cell content.}
\novbreak

For now, let us stick with regular cells. As stated, their content could
be anything. Each cell can be regarded as an idenpendent mini-frame.
Notably, the “frame width” within a cell is actually that of this cell,
meaning that any command relying on it adapts correctly.\footnote{The
“frame height” on the other hand is not known yet as the cells will
vertically adapt automatically to the content.}. That is true to for other
frame-related relative units, such as the line length.

We could illustrate it with many commands, but allow us some \em{inception}
with tables-within-tables, all using “60\%fw 40\%fw” as column specification.

\begin[cols=60%fw 40%fw]{ptable}
  \begin{row}
    \cell{%
\begin[cols=60%fw 40%fw]{ptable}
  \begin{row}
    \cell{%
\begin[cols=60%fw 40%fw]{ptable}
  \begin{row}
    \cell{A}
    \cell{B}
  \end{row}
\end{ptable}
    }
    \cell{C}
  \end{row}
\end{ptable}
    }
    \cell{D}
  \end{row}
\end{ptable}

Notice how each embedded table is relative to its parent cell width,
and the column heights are automatically adjusted. By default,
the content is middle-aligned but this is where the \doc:code{valign}
cell option may be used. Let’s set it to “top” for C and
“bottom” for D.

\begin[cols=60%fw 40%fw]{ptable}
  \begin{row}
    \cell{
\begin[cols=60%fw 40%fw]{ptable}
  \begin{row}
    \cell{
\begin[cols=60%fw 40%fw]{ptable}
  \begin{row}
    \cell{A}
    \cell{B}
  \end{row}
\end{ptable}
    }
    \cell[valign=top]{C}
  \end{row}
\end{ptable}
    }
    \cell[valign=bottom]{D}
  \end{row}
\end{ptable}

\em{Column and row spanning.}
\novbreak

By default, each cell takes up the width of one column.
You can allow some cells to span over multiple columns, using
the \doc:code{span} option with the appropriate value, e.g. 2 below
on cell A. This is also what some office programs call “merging”.

\begin[cols=50%fw 50%fw]{ptable}
  \begin{row}
    \cell[span=2]{A}
  \end{row}
  \begin{row}
    \cell{B}
    \cell{C}
  \end{row}
\end{ptable}

So far, so easy. But what about spanning over multiple rows?
Each cell takes up, by default, the height of one row… and in this
table package, one cannot change that fact. 

Instead of “merging”, we however have “splitting”, in that
direction. You will still specify a \em{single cell}, but of a special type
which turns out to be a (sub-)table. The command
for that purpose is the abovementioned \doc:code{celltable}.
It can only contain rows, so it is really an inner table used
as a cell.

\begin[cols=50%fw 50%fw]{ptable}
  \begin{row}
    \cell{A}
    \begin{celltable}
      \begin{row}
        \cell{B}
      \end{row}
      \begin{row}
        \cell{C}
      \end{row}
    \end{celltable}
  \end{row}
\end{ptable}

In other terms, the above table has only one row, but
the second cell is divided into two sub-rows. Other
than that, this special type of cell remains a cell,
so the column heights will automatically be adjusted
if need be (evenly distributed between the sub-rows)…
and as a cell, too, it supports the \doc:code{span} option
for column spanning. One might thus achieve fairly
complex layouts.\footnote{Exercise left to the reader: can
you craft the same table but with the C and E columns
merged?}

\begin[cols=33.333%fw 33.333%fw 33.333%fw]{ptable}
  \begin{row}
    \cell{A.}
    \cell{B.}
    \cell{C.}
  \end{row}
  \begin{row}
    \cell[span=2]{D.}
    \cell{E}
  \end{row}
  \begin{row}
    \cell{F.}
    \begin[span=2]{celltable}
      \begin{row}
        \cell{G.}
        \cell{H.}
      \end{row}
      \begin{row}
        \cell[span=2]{I.}
      \end{row}
    \end{celltable}
  \end{row}
\end{ptable}

\em{Other considerations.}
\novbreak

Due to the way the table is built by assembling boxes,
page breaks may only occur between first-level rows.
With tables involving cell splitting, it might be difficult
to get a good break-point.

Each cell being a mini-frame, it resets its settings
to their top-level (i.e. document) values. Some hook
should likely be provided to alter the cell style (fonts, indents, etc.)
Also, this package does not support a header row that would be repeated
on each page.\footnote{Patches are welcome.}

\end{document}]]
}
