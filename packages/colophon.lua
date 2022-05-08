--
-- Circle-shaped colophons
-- 2021-2022, Didier Willis
-- License: MIT
--
SILE.require("packages/svg")
SILE.require("packages/rebox")
SILE.require("packages/raiselower")
SILE.require("packages/parbox")

SILE.scratch.colophon = {
  circle = {
    decorations = {
      debug = {
        src = "packages/colophons/circle-debug.svg",
        scale = 1
      },
      default = {
        src = "packages/colophons/circle.svg",
        scale = 1.25
      },
      decorative = {
        src = "packages/colophons/circle-decorative.svg",
        scale = 1.5
      },
      floral = {
        src = "packages/colophons/circle-floral.svg",
        scale = 1.66
      },
      ornamental = {
        src = "packages/colophons/circle-ornament.svg",
        scale = 1.42
      },
      elegant = {
        src = "packages/colophons/circle-elegant.svg",
        scale = 1.5
      },
      delicate = {
        src = "packages/colophons/circle-floral-delicate.svg",
        scale = 1.66
      },
      cornered = {
        src = "packages/colophons/circle-squared-corners.svg",
        scale = 1.33
      }
    }
  }
}

local internalScratch = {}

local function circleSetupLineLengths(options, oldSetupLineLengths)
  local adjustRatio = options.ratio and SU.cast("number", options.ratio)
  local bs = SILE.measurement("1bs"):tonumber()
  local ex = SILE.measurement("1ex"):tonumber()

  local setupLineLengths = function(self)
    -- Estimate the width this would reach if set all on a single line.
    local estimatedWidth = 0
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
    -- Setup the parShape method
    -- Oh again our lines assume fixed baselines, so we are in good
    -- company with Mr. Random.
    self.parShape = function (that, line)
      -- of course at the exact top of the circle the width would
      -- be null, so we offset that a bit by some x...
      local h = radius - (line - 1) * bs - 0.5 * ex
      local c = radius * radius - h * h
      local chord = c >= 0 and math.sqrt(c) or radius
      if chord > that.hsize then
        SU.error("Circle-shaped paragraph to big to fit the frame width")
      end

      local indent = that.hsize / 2 - chord
      return indent:tonumber(), SILE.measurement(2 * chord), indent:tonumber()
    end

    -- Store the computed radius for decorations, which will be computed
    -- at the very end...
    internalScratch.radius = radius
    internalScratch.offset = 0.5 * ex
    oldSetupLineLengths(self)
  end
  return setupLineLengths
end

local function getFigureScale(options)
  -- Get the figure and its scaling ratio.
  local figure = options.figure or "default"
  local decoration = SILE.scratch.colophon.circle.decorations[figure] or
                          SU.error("Unknown decoration '" .. figure .. "'")
  local scale = options.figurescale and SU.cast("number", options.figurescale) or decoration.scale
  if scale < 1 then
    SU.error("figurescale must be greater than 1")
  end
  return scale
end

local function circleDecoration(options)
  -- Retrieve the things we stored when line breaking occurred.
  local radius = internalScratch.radius or SU.error("Oops, broken implementation")

  -- Get the figure and its scaling ratio.
  local figure = options.figure or "default"
  local decoration = SILE.scratch.colophon.circle.decorations[figure] or
                         SU.error("Unknown decoration '" .. figure .. "'")
  local scale = options.figurescale and SU.cast("number", options.figurescale) or decoration.scale
  if scale < 1 then
    SU.error("figurescale must be greater than 1")
  end
  -- We are vertically aligned with the paragraph. In addition to a scaled radius raise,
  -- we have also that 0.5ex or so offset that we added to be sure the first line would
  -- have some width...
  local raise = - internalScratch.offset - 2 * radius + radius * (1 - scale)

  -- Now we should have everything to push the decoration as a zero-sized box,
  -- scaled and moved over the shaped paragraph.
  SILE.call("rebox", {
    height = 0,
    width = 0
  }, function()
        -- That is, centered...
    SILE.call("kern", {
      width = SILE.length("50%fw"):tonumber() - radius * scale -- - internalScratch.offset
    })

    -- Raised by the correction
    SILE.call("raise", {
      height = raise
    }, function()
        SILE.call("svg", {
          src = decoration.src,
          height = scale * 2 * radius
        })
    end)
  end)
end

SILE.registerCommand("colophon", function (options, content)
  local oldT_breakIntoLines = SILE.typesetter.breakIntoLines
  local oldLB_setupLineLengths = SILE.linebreak.setupLineLengths
  local oldLB_parShape = SILE.linebreak.parShape
  local fontOpts = SILE.font.loadDefaults({})

  -- Ok, this first version of this package didn't use a parbox.
  -- Let's explain, then. If the decoration is flattened with
  -- transparency removed, it has to be _below_ the actual text.
  -- Yet, we only know the requested space (and radius) after
  -- typesetting the text. So we are gonna use a parbox for that,
  -- steal it back, add the decoration, and then re-add the parbox
  -- afterwards...
  SILE.typesetter:leaveHmode()
  local pbox = SILE.call("parbox", {
    width = "100%fw",
    valign = "top",
    strut = "none",
  }, function()
    SILE.settings.temporarily(function()
      -- Reapply out font in the parbox
      SILE.call("font", fontOpts)
      -- Increase a bit the tolerance, typesetting in circle is tough.
      SILE.settings.set("linebreak.tolerance", 2000)
      -- Clear paragraph indent
      SILE.settings.set("document.parindent", 0)
      -- Ensure baselineskip has no stretch:
      --  We do not need it now that we used a parbox
      -- Activate parshaping
      SILE.settings.set("linebreak.parShape", true)

      -- Override some default methods...
      local leadingGlue = true
      SILE.linebreak.setupLineLengths = circleSetupLineLengths(options, oldLB_setupLineLengths)
      SILE.typesetter.breakIntoLines = function(self, nodelist, breakWidth)
        local lines = oldT_breakIntoLines(self, nodelist, breakWidth)
        if SU.boolean(options.decoration, false) then
          if leadingGlue == false then SU.warn("Breaking more than one colophon paragraph with decoration?") end
          -- Here we do two additional things, once a paragraph has been broken into lines.
          -- We store the number of lines, which will be needed to compute the decoration
          -- later. Caution: it bluntly assumes the content is made of exactly one single
          -- paragraph. The warning above should maybe be an error.
          internalScratch.nbLines = #lines
          leadingGlue = false
        end
        return lines
      end

      SILE.process(content)
      SILE.typesetter:leaveHmode()
      -- Restore the original typesetter and linebreak.
      SILE.typesetter.breakIntoLines = oldT_breakIntoLines
      -- Also do not forget to deactivate the parShape method.
      SILE.linebreak.setupLineLengths = oldLB_setupLineLengths
      SILE.linebreak.parShape = oldLB_parShape
      SILE.settings.set("linebreak.parShape", false)
    end)
  end)
  table.remove(SILE.typesetter.state.nodes) -- steal it back

  local scale = getFigureScale(options)
  local ex = SILE.measurement("1ex"):tonumber()
  local offset = (scale - 1) * internalScratch.radius

  if SU.boolean(options.decoration, false) then
    SILE.typesetter:pushExplicitVglue(SILE.nodefactory.vglue(SILE.length(offset)))
    circleDecoration(options)
  end

  SILE.typesetter:pushHbox(pbox)
  SILE.typesetter:leaveHmode()
  if SU.boolean(options.decoration, false) then
    SILE.typesetter:pushExplicitVglue(SILE.nodefactory.vglue(SILE.length(offset + ex)))
  end
end, "Formats shaped paragraphs")

return {
  documentation = [[\begin{document}
\script[src=packages/url]
\script[src=packages/autodoc-extras]

Quoting Wikipedia, a colophon (/ˈkɒləfon/) is a brief statement containing information about
the publication of a book such as the place of publication, the publisher, and the date of
publication. Colophons are usually printed at the ends of books. The term colophon derives
from the Late Latin \em{colophōn}, from the Greek \em{κολοφών} (meaning “summit” or “finishing
touch”). The existence of colophons can be dated back to antiquity.

It is quite common for colophons to be surrounded by some sort of ornament. While regular
paragraphs are composed of square-shaped blocks, colophons may take various fancy shapes.
This is where the \autodoc:package{colophon} package may come into action. As one could have
guessed by its name, it provides
a \autodoc:command{\colophon} command that attempts shaping a paragraph into a circle,
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
cannot fit and will overflow outside the circle, so the option \autodoc:parameter{ratio}
can be used to manually provide a different value (e.g. 1.015 –the necessary
adjustment may be fairly small).

Let’s now consider ornaments. We want to show a nice ornamental
decoration around the shaped paragraph. Note the singular here. Your
content is not expected to span over multiple paragraphs. Well, it can,
but the logic for computing and displaying the decoration will fail or,
at best, be applied to the last paragraph, each being circles on their
own! Thus our third assumption is that the colophon contains only
one single paragraph.

To enable a decoration, set the \autodoc:parameter{decoration} option to true.
The default ornament (logically called \doc:code{default}) is just
a larger circle, i.e. with an extra amount of space. One can select
another ornamental figure by specifying the \autodoc:parameter{figure} option,
with a figure name (see below). All of them vary on the amount of space
they add around the circle, defined as a scaling ratio applied to the computed
base radius. This value, somewhat arbitrary or to the taste of this
author, can be overridden with the \autodoc:parameter{figurescale} option set to
some decimal number bigger than 1.

The figure is computed after the paragraph is shaped, so as to know
the space it actually took. Oh, by the way, the decoration does not expect
a page break to occur in a colophon. There are even other assumptions there,
but if you read up to this point, you probably got enough words of
caution\footnote{Suggestions and patches are of course welcome.}.

The pre-defined figures\footnote{The nice ones are all in
the public domain (CC0), from \url{https://freesvg.org}.}
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
