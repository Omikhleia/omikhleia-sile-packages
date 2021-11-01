--
-- Circle-shaped colophons
-- 2021, Didier Willis
-- License: MIT
--
SILE.require("packages/svg")
SILE.require("packages/rebox")
SILE.require("packages/raiselower")

SILE.scratch.colophon = {
  circle = {
    decorations = {
      debug = { src = "packages/colophons/circle-debug.svg", scale = 1 },
      default = { src = "packages/colophons/circle.svg", scale = 1.25 },
      decorative = { src = "packages/colophons/circle-decorative.svg", scale = 1.5 },
      floral = { src = "packages/colophons/circle-floral.svg", scale = 1.66 },
      ornamental = { src = "packages/colophons/circle-ornament.svg", scale = 1.42 },
      elegant = { src = "packages/colophons/circle-elegant.svg", scale = 1.5 },
      delicate = { src = "packages/colophons/circle-floral-delicate.svg", scale = 1.66 },
      cornered = { src = "packages/colophons/circle-squared-corners.svg", scale = 1.33 }
    }
  }
}

local internalScratch = {}

local function circleSetupLineLengths(options)
  local adjustRatio = options.ratio and SU.cast("number", options.ratio)
  local bs = SILE.length("1bs"):tonumber()
  local ex = SILE.length("1ex"):tonumber()

  local setupLineLengths = function (self)
    -- Estimate the width this would reach if set all on a single line.
    local estimatedWidth = 0
    local estimatedHeight = bs
    for i = 1, #self.nodes do
      estimatedWidth = estimatedWidth + self.nodes[i].width.length.amount or 0
    end
    -- Of course we ignored streching (and shrinking), so it actually
    -- would be larger...
    -- To keep this mess simple, let's just adjust by a ratio,
    -- and if not provided, at a dice roll, say 1% by default...
    estimatedWidth = estimatedWidth * (adjustRatio or 1.01)

    -- Approximate the area taken by that theoretical single ligne. Of
    -- course here again we assume the paragraph contains text only within
    -- fixed baselines, so this is again a pretty fragile estimation.
    local area = estimatedWidth * bs

    -- Deduce from these rough estimates the closest circle radius that
    -- would correspond to the same area.
    local radius = math.sqrt(area / math.pi)

    -- We'll be lucky if it works decently :)
    -- Setup the parShape method, with a table for memoization.
    -- Oh again our lines assume fixed baselines, so we are in good
    -- company with Mr. Random.
    internalScratch.parShapes = {}
    self.parShape = function (self, line)
      if internalScratch.parShapes[line] then
        -- Return memoized values
        return internalScratch.parShapes[line]
      end
      -- of course at the exact top of the circle the width would
      -- be null, so we offset that a bit by some x...
      local h = radius - (line - 1) * bs - 0.5 * ex
      local c = radius * radius - h * h
      local chord = c >= 0 and math.sqrt(c) or radius
      if chord > self.hsize then SU.error("Circle-shaped paragraph to big to fit the frame width") end

      local indent = self.hsize / 2 - chord
      internalScratch.parShapes[line] = {
        width = SILE.measurement(2 * chord),
        left = indent:tonumber(),
        right = indent:tonumber()
      }
      -- print("SHAPE", line, internalScratch.parShapes[line].width, internalScratch.parShapes[line].left)
      return internalScratch.parShapes[line]
    end

    -- Assume we should never reach 500 lines. If it does, stop
    -- the mess.
    self.lastSpecialLine = 1000
    self.secondWidth = self.hsize
    self.secondIndent = 0
    self.easy_line = self.lastSpecialLine -- implies looseness=0
    -- Store the computed radius for decorations, which will be computed
    -- at the very end...
    internalScratch.radius = radius
  end
  return setupLineLengths
end

local function circleDecoration(options, radius, nbLines)
  local bs = SILE.length("1bs"):tonumber()
  local ex = SILE.length("1ex"):tonumber()
  -- Retrieve the things we stored when line breaking occurred.
  local radius = internalScratch.radius or SU.error("Oops, broken implementation")
  local nbLines = internalScratch.nbLines or SU.error("Oops, broken implementation")

  -- Remember the extra ratio etc. we used when computing the circle radius, and all the
  -- discussion on stretching and shrinking? So we may not end up exactly with the
  -- theoretical radius. Let's compute how much we missed (positive or negative).
  local missingHeight = bs * nbLines - 2 * radius

  -- Get the figure and its scaling ratio.
  local figure = options.figure or "default"
  local decoration = SILE.scratch.colophon.circle.decorations[figure] or SU.error("Unknown decoration '"..figure.."'")
  local scale = options.figurescale and SU.cast("number", options.figurescale) or decoration.scale
  if scale < 1 then SU.error("figurescale must be greater than 1") end

  -- We are just on the line below the shaped paragraph. So we have 1bs too much, and also
  -- that 0.5ex we added to be sure the first line would have some width. In addition
  -- to the missing height, we have to take them into account.
  local raise = 0.5 * (bs - 0.5 * ex) + missingHeight

  -- Now we should have everything to push the decoration as a zero-sized box,
  -- scaled and moved over the shaped paragraph.
  SILE.typesetter:leaveHmode()
  -- That is, centered...
  SILE.call("kern", { width= SILE.length("50%fw"):tonumber() - radius * scale })
  SILE.call("rebox", { height = 0, width = 0 }, function ()
    -- Raised by the correction
    SILE.call("raise", { height = raise }, function ()
      -- Lowered according to the scaling ratio (yes we could have done that
      -- and the above in a single command, it just more legible this way
      -- though).
      SILE.call("lower", { height = (scale - 1) * radius }, function ()
        SILE.call("svg", { src = decoration.src, height = scale * 2 * radius })
      end)
    end)
  end)
  SILE.typesetter:leaveHmode();

  -- And finally add a vertical glue after the paragraph, to take into
  -- account the extra space needed by the decoration.
  local offset = (scale - 1) * (radius - missingHeight / 2) - ex
  SILE.typesetter:pushExplicitVglue(SILE.nodefactory.vglue(SILE.length(offset)))
end

SILE.registerCommand("colophon", function (options, content)
  local oldT_breakIntoLines = SILE.typesetter.breakIntoLines
  local oldLB_setupLineLengths = SILE.linebreak.setupLineLengths

  SILE.typesetter:leaveHmode()
  SILE.settings.temporarily(function()
    -- Increase a bit the tolerance, typesetting in circle is tough.
    SILE.settings.set("linebreak.tolerance", 2000)
    -- Clear paragraph indent and ensure baselineskip has no stretch.
    SILE.settings.set("document.baselineskip", "1.2em")
    SILE.settings.set("document.parindent", 0)

    -- Override some default methods...
    local leadingGlue = true
    SILE.linebreak.setupLineLengths = circleSetupLineLengths(options)
    SILE.typesetter.breakIntoLines = function (self, nodelist, breakWidth)
      local lines = oldT_breakIntoLines(self, nodelist, breakWidth)
      if SU.boolean(options.decoration, false) then
        if leadingGlue == false then SU.warn("Breaking more than one colophon paragraph with decoration?") end
        -- Here we do two additional things, once a paragraph has been broken into lines.
        -- 1. We store the number of lines, which will be needed to compute the decoration
        --    later. Caution: it bluntly assumes the content is made of exactly one single
        --    paragraph. The warning above should maybe be an error.
        -- 1. We also insert a vertical glue corresponding to the extra space needed for
        --    the decoration.
        internalScratch.nbLines = #lines
        local bs = SILE.length("1bs"):tonumber()
        local ex = SILE.length("1ex"):tonumber()
        local figure = options.figure or "default"
        local decoration = SILE.scratch.colophon.circle.decorations[figure] or SU.error("Unknown decoration '"..figure.."'")
        local scale = decoration.scale
        local offset = (scale - 1) * internalScratch.radius / 2 + ex
        local node = SILE.nodefactory.vglue(SILE.length(offset))
        node.explicit = true
        node.discardable = false
        table.insert(lines[1].nodes, 1, node)
        leadingGlue = false
      end
      return lines
    end
    SILE.process(content)
    SILE.typesetter:leaveHmode();

    -- Restore the original typesetter and linebreak.
    SILE.typesetter.breakIntoLines = oldT_breakIntoLines
    SILE.linebreak.setupLineLengths = oldLB_setupLineLengths
    -- Also do not forget to deactivate the parShape method.
    SILE.linebreak.parShape = nil

    -- When all is done, we construct the decoration...
    if SU.boolean(options.decoration, false) then
      circleDecoration(options)
    end
  end)
end, "Formats shaped paragraphs")

return {
  documentation = [[\begin{document}
\script[src=packages/svg]
\script[src=packages/autodoc-extras]

Quoting Wikipedia, a colophon (/ˈkɒləfon/) is a brief statement containing information about
the publication of a book such as the place of publication, the publisher, and the date of
publication. Colophons are usually printed at the ends of books. The term colophon derives
from the Late Latin \em{colophōn}, from the Greek \em{κολοφών} (meaning “summit” or “finishing
touch”). The existence of colophons can be dated back to antiquity.

It is quite common for colophons to be surrounded by some sort of ornament. While regular
paragraphs are composed of square-shaped blocks, colophons may take various fancy shapes.
This is where the \doc:keyword{colophon} package may come into action. As one could have
guessed by its name, it provides
a \doc:code{\\colophon} command that attempts shaping a paragraph into a circle,
which radius is \em{automatically} computed so that the text fills the circle.

Typesetting text in a circle, however, can be tough. The first and last lines do not have
much place to play with. Even with hyphenation, one is no guaranteed that the text can be
broken at appropriate places and will not overflow. And one cannot be sure, either, that the
very last line, by nature incomplete, can fit well in that circle. No need to say, it works
better with a decently long text. Shaping a small sentence into a circle is likely to yield
poor results. This type of colophon might not be appropriate for short statements.

In other terms, there are many reasons why it may go wrong and one should have
a basic understanding on how this package works, as there are several wild
assumptions.

The current implementation, to avoid multiple passes, just tries
to estimate the area the content would have taken if set all on a single line.
This is our first assumption: we are inherently dealing with \em{lines
of text}, shaping the paragraph at the line-breaking algorithm level and
therefore assuming the line height to be reasonably constant. So do not expect miracles
if your content contains other things than text or font changes, etc. that could affect
the line spacing. Actually, if you want to typeset a colophon in a given font,
we even recommend wrapping the font change command around the colophon, rather
than inside.

Based on this rough and fragile estimation, we can deduce the radius of
a circle that has the same area. But of course, we cannot know yet whether the lines
will be stretched (or even shrinked, but we cannot hope too much for it with
such a shape) when justified into the circle. This is the second assumption:
the above estimation is likely too small, as stretching will occur with little
doubts. So the implemention adjusts the estimated length by a ratio, with an
\em{arbitrary} value of 1.01 (i.e. we expect the line stretchability
to globally reach 1\% at most). There will still be cases where the paragraph
cannot fit and will overflow outside the circle, so the option \doc:code{ratio}
can be used to manually provide a different value (e.g. 1.015 –the necessary
adjustment may be fairly small).

Let’s now consider ornaments. We want to show a nice ornamental
decoration around the shaped paragraph. Note the singular here. Your
content is not expected to span over multiple paragraphs. Well, it can,
but the logic for computing and displaying the decoration will fail or,
at best, be applied to the last paragraph, each being circles on their
own! Thus our third assumption is that the colophon contains only
one single paragraph.

To enable a decoration, set the \doc:code{decoration} option to true.
The default ornament (logically called \doc:code{default}) is just
a larger circle, i.e. with an extra amount of space. One can select
another ornamental figure by specifying the \doc:code{figure} option,
with a figure name (see below). All of them vary on the amount of space
they add around the circle, defined as a scaling ratio applied to the computed
base radius. This value, somewhat arbitrary or to the taste of this
author, can be overridden with the \doc:code{figurescale} option set to
some decimal number bigger than 1.

The figure is computed after the paragraph is shaped, so as to know
the space it actually took. Oh, by the way, the decoration does not expect
a page break to occur in a colophon. There are even other assumptions there,
but if you read up to this point, you probably got enough words of
caution\footnote{Suggestions and patches are of course welcome.}.

The pre-defined figures\footnote{The nice ones are all in
the public domain (CC0), from \doc:url{https://freesvg.org}.}
are \doc:code{default}, \doc:code{debug}, \doc:code{decorative},
\doc:code{floral}, \doc:code{ornamental}, \doc:code{elegant},
\doc:code{delicate}, and \doc:code{cornered}. Most of these names are
quite random, so here you are, in random order too:

\medskip

\script{
local size = SILE.length("100%fw") / 5
SILE.require("packages/rebox")
SILE.require("packages/raiselower")
SILE.call("noindent")
SILE.call("raggedright", {}, function()
  for k, v in pairs(SILE.scratch.colophon.circle.decorations) do
    SILE.call("rebox", { height = 0, width = 0 }, function ()
      SILE.call("raise", { height = size / 2.2 }, function ()
        SILE.call("kern", { width = SILE.length("1.2em") })
        SILE.call("font", { size = SILE.settings.get("font.size") - 1, style = "italic" }, { k })
      end)
    end)
    SILE.call("svg", { src = v.src, width = size })
    SILE.call("quad")
   SILE.typesetter:typeset(" ")
  end
end)
}

\end{document}]]
}