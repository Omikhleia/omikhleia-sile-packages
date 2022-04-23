--
-- Re-implementation of the tableofcontents package.
-- Hooks are removed and replaced by styles, allowing for a fully customizable TOC
--
SILE.scratch.tableofcontents = {}
local tableofcontents_ = {}

-- Styles
local styles = SILE.require("packages/styles").exports

-- The interpretation after the ~ below are just indicative, one could
-- customize everything differently. It corresponds to their use in
-- the omibook class, and their default (proposed) styling specifications
-- are based on the latter.
local tocStyles = {
  -- level0 ~ part
  { font = { weight = 800, size = "+1.5" },
    toc = { numbering = false, pageno = false },
    paragraph = { skipbefore = "medskip", indentbefore = false,
                  skipafter = "medskip", breakafter = false } },
  -- level1 ~ chapter
  { font = { weight = 800, size = "+1" },
    toc = { numbering = false, pageno = true, dotfill = false},
    paragraph = { indentbefore = false, skipafter = "smallskip" } },
  -- level2 ~ section
  { font = { size = "+1" },
    toc = { numbering = false, pageno = true, dotfill = true },
    paragraph = { indentbefore = false, skipafter = "smallskip" } },
  -- level3 ~ subsection
  { toc = { numbering = true, pageno = true, dotfill = false },
    paragraph = { indentbefore = true, skipafter = "smallskip" } },
  -- level4 ~ subsubsection
  { toc = { pageno = false },
    paragraph = { indentbefore = true, skipafter = "smallskip" } },
  -- level5 ~ figure
  { toc = { numbering = true, pageno = true, dotfill = true },
    numbering = { before = "Fig. ", after = ".", kern = "2spc" },
    paragraph = { indentbefore = false } },
  -- level6 ~ table
  { toc = { numbering = true, pageno = true, dotfill = true },
    numbering = { before = "Table ", after = ".", kern = "2spc" },
    paragraph = { indentbefore = false } },
  -- extra loosely defined levels, so we have them at hand if need be
  { toc = { pageno = false },
    paragraph = { indentbefore = true } },
  { toc = { pageno = false },
    paragraph = { indentbefore = true } },
  { toc = { pageno = false },
    paragraph = { indentbefore = true } },
}
for i = 1, #tocStyles do
  styles.defineStyle("toc:level"..(i-1), {}, tocStyles[i])
end

local moveToc = function (_)
  local node = SILE.scratch.info.thispage.toc
  if node then
    for i = 1, #node do
      node[i].pageno = SILE.formatCounter(SILE.scratch.counters.folio)
      SILE.scratch.tableofcontents[#(SILE.scratch.tableofcontents)+1] = node[i]
    end
  end
end

local writeToc = function (_)
  local tocdata = pl.pretty.write(SILE.scratch.tableofcontents)
  local tocfile, err = io.open(SILE.masterFilename .. '.toc', "w")
  if not tocfile then return SU.error(err) end
  tocfile:write("return " .. tocdata)
  tocfile:close()

  if not pl.tablex.deepcompare(SILE.scratch.tableofcontents, tableofcontents_) then
    io.stderr:write("\n! Warning: table of contents has changed, please rerun SILE to update it.")
  end
end

local loadToc = function()
  if tableofcontents_ and #tableofcontents_ > 0 then
    -- already loaded
    return tableofcontents_
  end
  local tocfile, _ = io.open(SILE.masterFilename .. '.toc')
  if not tocfile then
    -- No TOC yet
    return false
  end
  local doc = tocfile:read("*all")
  local toc = assert(load(doc))()
  tableofcontents_ = toc
  return tableofcontents_
end

-- Warning for users of the legacy tableofcontents
SILE.registerCommand("tableofcontents:title", function (_, _)
  SU.error("The omitableofcontents package does not use the tableofcontents:title command.")
end)

SILE.registerCommand("tableofcontents", function (options, _)
  local depth = SU.cast("integer", options.depth or 3)
  local start = SU.cast("integer", options.start or 0)
  local linking = SU.boolean(options.linking, true)

  local toc = loadToc()
  if toc == false then
    SILE.call("tableofcontents:notocmessage")
    return
  end

  -- Temporarilly kill footnotes and labels (fragile)
  local oldFt = SILE.Commands["footnote"]
  SILE.Commands["footnote"] = function () end
  local oldLbl = SILE.Commands["label"]
  SILE.Commands["label"] = function () end


  for i = 1, #toc do
    local item = toc[i]
    if item.level >= start and item.level <= start + depth then
      SILE.call("tableofcontents:item", {
        level = item.level,
        pageno = item.pageno,
        number = item.number,
        link = linking and item.link
      }, item.label)
    end
  end

  SILE.Commands["footnote"] = oldFt
  SILE.Commands["label"] = oldLbl
end, "Output the table of contents.")

-- Flatten a node list into just its string representation.
-- (Similar to SU.contentToString(), but allows passing typeset
-- objects to functions that need plain strings).
local nodesToText = function (nodes)
  local spc = SILE.measurement("0.8spc"):tonumber()
  local string = ""
  for i = 1, #nodes do
    local node = nodes[i]
    if node.is_nnode or node.is_unshaped then
      string = string .. node:toText()
    elseif node.is_glue or node.is_kern then
      -- Not so sure about this one...
      if node.width:tonumber() > spc then
        string = string .. " "
      end
    elseif not (node.is_zerohbox or node.is_migrating) then
      -- Here, typically, the main case is an hbox.
      -- Even if extracting its content could be possible in regular cases
      -- (e.g. \raise), we cannot take a general decision, as it is a versatile
      -- object (e.g. \rebox) and its outputYourself could moreover have been
      -- redefine to do fancy things. Better warn and skip.
      SU.warn("Some content could not be converted to text: "..node)
    end
  end
  return string
end

local dc = 1
SILE.registerCommand("tocentry", function (options, content)
  local dest
  if SILE.Commands["pdf:destination"] then
    dest = "dest" .. dc
    SILE.call("pdf:destination", { name = dest })
    if SU.boolean(options.bookmark, true) then
      SILE.typesetter:pushState()
      -- Temporarilly kill footnotes and labels (fragile)
      local oldFt = SILE.Commands["footnote"]
      SILE.Commands["footnote"] = function () end
      local oldLbl = SILE.Commands["label"]
      SILE.Commands["label"] = function () end

      SILE.process(content)

      SILE.Commands["footnote"] = oldFt
      SILE.Commands["label"] = oldLbl

      local title = nodesToText(SILE.typesetter.state.nodes)
      SILE.typesetter:popState()

      SILE.call("pdf:bookmark", { title = title, dest = dest, level = options.level })
    end
    dc = dc + 1
  end
  SILE.call("info", {
    category = "toc",
    value = {
      label = content,
      level = (options.level or 1),
      number = options.number,
      link = dest
    }
  })
end, "Register an entry in the current TOC - low-level command.")

local linkWrapper = function (dest, func)
  if dest and SILE.Commands["pdf:link"] then
    return function()
      SILE.call("pdf:link", { dest = dest }, func)
    end
  else
    return func
  end
end

SILE.registerCommand("tableofcontents:item", function (options, content)
  local level = SU.cast("integer", SU.required(options, "level", "tableofcontents:levelitem"))
  if level < 0 or level > #tocStyles - 1 then SU.error("Invalid TOC level "..level) end

  local hasFiller = true
  local hasPageno = true
  local tocSty = styles.resolveStyle("toc:level"..level)
  if tocSty.toc then
    hasPageno = SU.boolean(tocSty.toc.pageno, true)
    hasFiller = hasPageno and SU.boolean(tocSty.toc.dotfill, true)
  end

  SILE.settings.temporarily(function ()
    SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.glue())
    SILE.call("style:apply:paragraph", { name = "toc:level"..level },
      linkWrapper(options.link, function ()
        if options.number then
          SILE.call("tableofcontents:levelnumber", { level = level }, function ()
            SILE.typesetter:typeset(options.number)
          end)
        end

        SILE.process(content)

        SILE.call(hasFiller and "dotfill" or "hfill")
        if hasPageno then
          SILE.typesetter:typeset(options.pageno)
        end
      end)
    )
  end)
end, "Typeset a TOC entry - internal.")

SILE.registerCommand("tableofcontents:levelnumber", function (options, content)
  local level = SU.cast("integer", SU.required(options, "level", "tableofcontents:levelnumber"))
  if level < 0 or level > #tocStyles - 1 then SU.error("Invalid TOC level "..level) end

  local tocSty = styles.resolveStyle("toc:level"..level)

  if tocSty.toc and SU.boolean(tocSty.toc.numbering, false) then
    local pre = tocSty.numbering and tocSty.numbering.before
    local post = tocSty.numbering and tocSty.numbering.after
    local kern = tocSty.numbering and tocSty.numbering.kern or "1spc"
    if pre and pre ~= "false" then SILE.typesetter:typeset(pre) end
    SILE.process(content)
    if post and post ~= "false" then
      SILE.typesetter:typeset(post)
    end
    SILE.call("kern", { width = kern })
  end
end, "Typeset the (section) number in a TOC entry - internal.")

return {
  exports = { writeToc = writeToc, moveToc = moveToc,
    moveTocNodes = moveToc, -- for compatibility
    loadToc = loadToc,
  },
  init = function (self)
    self:loadPackage("infonode")
    self:loadPackage("leaders")
    SILE.doTexlike([[%
\define[command=tableofcontents:notocmessage]{Rerun SILE to process table of contents!}%
]])
  end,
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]
\script[src=packages/enumitem]

The \autodoc:package{omitableofcontents} package is a re-implementation of the
default \autodoc:package{tableofcontents} package from SILE. As its original ancestor,
it provides tools for classes to create tables of contents.

It exports two Lua functions, \doc:code{moveToc()} and \doc:code{writeToc()}.
The former should be called at the end of each page to collate the table of
contents.
The latter should be called at the end of the document, to save the table of
contents to a file which is read when the package is initialized. This is because
a table of contents (written out with the \autodoc:command{\tableofcontents} command)
is usually found at the start of a document, before the entries have been processed.
Because of this, documents with a table of contents need to be processed at least
twice—once to collect the entries and work out which pages they are on,
then to write the table of contents.

At a low-level, when you are implementing sectioning commands such
as \autodoc:command[check=false]{\chapter} or \autodoc:command[check=false]{\section}, your
class should call the \autodoc:command{\tocentry[level=<integer>, number=<string>]{<section title>}}
command to register a table of contents entry. Or you can alleviate your work by using a package
that does it all for you, such as \autodoc:package{sectioning}.

From a document author perspective, this package just provides the above-mentioned
\autodoc:command{\tableofcontents} command.

It accepts a \autodoc:parameter{depth} option to control the depth of the content added to the table
(defaults to 3) and a \autodoc:parameter{start} option to control at which level the table
starts (defaults to 0)

If the \autodoc:package{pdf} package is loaded before using sectioning commands,
then a PDF document outline will be generated.
Moreover, entries in the table of contents will be active links to the
relevant sections. To disable the latter behavior, pass \autodoc:parameter{linking=false} to
the \autodoc:command{\tableofcontents} command.

As opposed to the original implementation, this package clears the table header
and cancels the language-dependent title that the default implementation provides.
This author thinks that such a package should only do one thing well: typesetting the table
of contents, period. Any title (if one is even desired) should be left to the sole decision
of the user, e.g. explicitely defined with a \autodoc:command[check=false]{\chapter[numbering=false]{…}}
command or any other appropriate sectioning command, and with whatever additional content
one may want in between. Even if LaTeX has a default title for the table of contents,
there is no strong reason to do the same. It cannot be general: One could
want “Table of Contents”, “Contents”, “Summary”, “Topics”, etc. depending of the type of
book. It feels wrong and cumbersome to always get a default title and have to override
it, while it is so simple to just add a consistently-styled section above the table…

Moreover, this package does not support all the “hooks” that its ancestor had.
Rather, the entry level formatting logic entirely relies on styles (using the
\autodoc:package{styles} package), the styles used being
\doc:code{toc:level0} to \doc:code{toc:level9}. They provides several
specific options that the original package did not have, allowing you to customize
nearly all aspects of your tables of contents.

\end{document}]]
}
