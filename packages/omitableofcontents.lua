--
-- Partial re-implementation of the tableofcontents package
-- 2021, Didier Willis
--
--
-- Overrides a few definitions only.
--
local defaultTocPackage = SILE.require("packages/tableofcontents").exports

-- Override useless commands. This doesn't prevent them to be redefined, though,
-- but may prevent casual use of them...
SILE.registerCommand("tableofcontents:title", function (_, _)
  SU.error("The omitableofcontents package should not use the tableofcontents:title command.")
end)

-- Go for styles FIXME = TEMPORARY DEFINITIONS AWAITING FOR PROPER SUPPORT IN THE STYLES PACKAGE
local styles = SILE.require("packages/styles").exports
local tocStyles = {
  -- level1 ~ chapter
  { font = { weight = 800, size = "+2" }, toc = { number = true, dotfill = false} },
  -- level2 ~ section
  { font = { size = "+1" } },
  -- level3 ~ subsection
  { toc = { pageno = false } }
}
styles.defineStyle("toc:level1", {}, tocStyles[1])
styles.defineStyle("toc:level2", {}, tocStyles[2])
styles.defineStyle("toc:level3", {}, tocStyles[3])

-- Override tableofcontents:item
--
-- Reminder: this is called with options (level, pageno, number, link) and the text as content.
local oldTocItem = SILE.Commands["tableofcontents:item"]
SILE.Commands["omitableofcontents:old:tocitem"] = oldTocItem
SILE.registerCommand("tableofcontents:item", function (options, content)
  local level = tonumber(options.level)
  local hasFiller = true
  local hasPageno = true
  if tocStyles[level].toc then
    hasPageno = SU.boolean(tocStyles[level].toc.pageno, true)
    hasFiller = hasPageno and SU.boolean(tocStyles[level].toc.dotfill, true)
  end

  if not hasPageno then
    options.pageno = ""
  end

  if hasFiller then
    SILE.call("omitableofcontents:old:tocitem", options, content)
  else
    -- hack the dotfill that the old command uses to be an hfill in that case
    local oldDotFill = SILE.Commands["dotfill"]
    SILE.registerCommand("dotfill", function (_, _)
      SILE.call("hfill")
    end)
    SILE.call("omitableofcontents:old:tocitem", options, content)
    -- restore the dotfill
    SILE.Commands["dotfill"] = oldDotFill
  end
end)

SILE.registerCommand("omitableofcontents:levelitem", function (options, content)
  local level = SU.cast("integer", SU.required(options, "level", "omitableofcontents:level"))
  if level < 0 or level > 3 then SU.error("Invalid TOC level "..level) end
  SILE.call("style:apply", { name = "toc:level"..level }, content)
end)

SILE.registerCommand("omitableofcontents:levelnumber", function (options, content)
  local level = SU.cast("integer", SU.required(options, "level", "omitableofcontents:level"))
  if level < 0 or level > 3 then SU.error("Invalid TOC level "..level) end
  if tocStyles[level].toc and tocStyles[level].toc.number then
    SILE.process(content)
  end
end)

return {
  exports = { writeToc = defaultTocPackage.writeToc, moveTocNodes = defaultTocPackage.moveTocNodes },
  init = function (self)
    self:loadPackage("infonode")
    self:loadPackage("leaders")
    -- Override almost all formatting commands there:
    SILE.doTexlike([[%
\define[command=tableofcontents:notocmessage]{\tableofcontents:headerfont{Rerun SILE to process table of contents!}}%
\define[command=tableofcontents:header]{}%
\define[command=tableofcontents:footer]{}%
\define[command=tableofcontents:level1item]{\bigskip\noindent\omitableofcontents:levelitem[level=1]{\process}\medskip}%
\define[command=tableofcontents:level2item]{\noindent\omitableofcontents:levelitem[level=2]{\process}\smallskip}%
\define[command=tableofcontents:level3item]{\indent\omitableofcontents:levelitem[level=3]{\process}\smallskip}%
\define[command=tableofcontents:level1number]{\omitableofcontents:levelnumber[level=1]{\process}}%
\define[command=tableofcontents:level2number]{\omitableofcontents:levelnumber[level=2]{\process}}%
\define[command=tableofcontents:level3number]{\omitableofcontents:levelnumber[level=3]{\process}}%
]])

  end,
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]

The \doc:code{omitableofcontents} package is a wrapper around the \doc:code{tableofcontents} package,
redefining some of its default behaviors.

First, it clears the table header and cancels the language-dependent title that the
default implementation provides.
This author thinks that such a package should only do one thing well: typesetting the table
of contents, period. Any title (if one is even desired) should be left to the sole decision
of the user, e.g. explicitely defined with a \doc:code{\\chapter[numbering=false]\{…\}}
command or any other appropriate sectioning command, and with whatever additional content
one may want in between. Even if LaTeX has a default title for the table of contents,
there is no strong reason to do the same. It cannot be general: One could
want “Table of Contents”, “Contents”, “Summary”, “Topics”, etc. depending of the type of
book. It feels wrong and cumbersome to always get a default title and have to override
it, while it is so simple to just add a consistently-styled section above the table…

Moreover, this package overrides all the level formatting commands to rely on
styles (using the \doc:keyword{styles} package), with specific options for the
TOC. The style specifications, besides the formatting of the text, also include:

• Displaying the page number or not,

• Filling the line with dots (default) or not,

• Displaying the section number or not.

Other than that, everything else from the standard package applies.

\end{document}]]
}
