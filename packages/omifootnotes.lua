-- 
-- Re-implementation of the footnotes package
-- 2021, Didier Willis
--
SILE.require("packages/abbr") -- for abbr:nbsp - MAYBE WE'LL CHANGE THIS
SILE.require("packages/textsubsuper") -- for text:superscript
SILE.require("packages/counters") -- used for counter formatting
SILE.require("packages/raiselower") -- NOT NEEDED NOW, NO?
SILE.require("packages/rebox") -- used by footnote:rule
SILE.require("packages/rules") -- used by footnote:rule
local insertions = SILE.require("packages/insertions")
SILE.scratch.counters.footnote = { value= 1, display= "arabic" }

local styles = SILE.require("packages/styles").exports
styles.defineStyle("footnote", {}, { font = { size = "-1" } })

-- Footnote separator and rule

SILE.registerCommand("footnote:separator", function (_, content)
  SILE.settings.pushState()
  local material = SILE.call("vbox", {}, content)
  SILE.scratch.insertions.classes.footnote.topBox = material
  SILE.settings.popState()
end, "Base function to create a footnote separator.")

SILE.registerCommand("footnote:rule", function (options, _)
  local width = SU.cast("measurement", options.width or "25%fw")
  local beforeskipamount = SU.cast("vglue", options.beforeskipamount or "2ex")
  local afterskipamount = SU.cast("vglue", options.afterskipamount or "1ex")
  local thickness = SU.cast("measurement", options.thickness or "0.5pt")
  SILE.call("footnote:separator", {}, function ()
    SILE.call("noindent")
    SILE.typesetter:pushExplicitVglue(beforeskipamount)
    SILE.call("rebox", {}, function ()
      SILE.call("hrule", { width = width, height = thickness })
    end)
    SILE.typesetter:leaveHmode()
    SILE.typesetter:pushExplicitVglue(afterskipamount)
  end)
end, "Small helper command (wrapper around footnote:separator) to set a footnote rule.")

-- Footnote reference call (within the text flow)

SILE.registerCommand("footnote:mark", function (options, _)
  if options.mark then
      SILE.call("text:superscript", {}, { options.mark })
  else
    local counter = SILE.formatCounter(SILE.scratch.counters.footnote)
    SILE.call("text:superscript", {}, { counter })
  end
end, "Command internally called to typeset the footnote call reference in the text flow.")

-- Footnote reference counter (within the footnote)

SILE.registerCommand("footnote:counter", function (options, _)
  SILE.call("noindent")
  if options.mark then
    SILE.call("text:superscript", {}, { options.mark })
  else
    local counter = SILE.formatCounter(SILE.scratch.counters.footnote)
    SILE.call("text:superscript", {}, { counter })
  end
  SILE.call("abbr:nbsp", { fixed = true })
end, "Command internally called to typeset the footnote counter in the footnote itself.")

-- Footnote insertion block max height and inter-skip tuning

SILE.registerCommand("footnote:options", function (options, _)
  if options["maxHeight"] then
    SILE.scratch.insertions.classes.footnote.maxHeight = SILE.length(options["maxHeight"])
  end
  if options["interInsertionSkip"] then
    SILE.scratch.insertions.classes.footnote.interInsertionSkip = SILE.length(options["interInsertionSkip"])
  end
end, "Command that can be used for tuning the maxHeight and interInsertionSkip for footnotes.")

SILE.registerCommand("footnote", function (options, content)
  SILE.call("footnote:mark", options)
  local opts = SILE.scratch.insertions.classes.footnote
  local f = SILE.getFrame(opts["insertInto"].frame)
  local oldT = SILE.typesetter
  SILE.typesetter = SILE.typesetter {}
  SILE.typesetter:init(f)
  SILE.typesetter.getTargetLength = function () return SILE.length(0xFFFFFF) end
  SILE.settings.pushState()
  -- Restore the settings to the top of the queue, which should be the document #986
  SILE.settings.toplevelState()

  -- Reset settings the document may have but should not be applied to footnotes
  -- See also same resets in folio package
  -- FIXME WHEN THIS IS RELEASED
  -- for _, v in ipairs({
  --   "current.hangAfter",
  --   "current.hangIndent",
  --   "linebreak.hangAfter",
  --   "linebreak.hangIndent" }) do
  --   SILE.settings.set(v, SILE.settings.defaults[v])
  -- end

  -- Apply the font before boxing, so relative baselineskip applies #1027
  local material
  SILE.call("style:apply", { name = "footnote" }, function ()
      material = SILE.call("vbox", {}, function ()
      SILE.call("footnote:counter", options)
      SILE.process(content)
    end)
  end)
  SILE.settings.popState()
  SILE.typesetter = oldT
  insertions.exports:insert("footnote", material)
  SILE.scratch.counters.footnote.value = SILE.scratch.counters.footnote.value + 1
end, "Typeset a footnote (main command for end-users)")

return {
  init = function (_, args)
    args = args or {}
    insertions.exports:initInsertionClass("footnote", {
        insertInto = args.insertInto or "footnotes",
        stealFrom = args.stealFrom or { "content" },
        maxHeight = SILE.length("75%ph"),
        topBox = SILE.nodefactory.vglue("2ex"),
        interInsertionSkip = SILE.length("1ex"),
      })
  end,
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]

The \doc:keyword{omifootnotes} package is a re-implementation of the
default \doc:keyword{footnotes} package from SILE.

In addition to the \doc:code{\\footnote} command, it provides
a \doc:code{\\footnote:rule} command as a convenient helper to set
a footnote rule. It may be called, early on in your documents, without options,
or one or several of the following:

\begin{doc:codes}
\\footnote:rule[length=\doc:args{length}, beforeskipamount=\doc:args{glue},\par
afterskipamount=\doc:args{glue}, thickness=\doc:args{length}]
\end{doc:codes}

The default values for these options are, in order, \doc:code{25\%fw},
\doc:code{2ex}, \doc:code{1ex} and \doc:code{0.5pt}.

It also redefines the way the footnote reference is formatted in the
footnote itself (that is, the internal \doc:code{\\footnote:counter} command),
to use a superscript counter. Both the footnote reference and the footnote
call (that is, the internal \doc:code{\\footnote:mark} command) are
configured to use actual superscript characters if supported by
the current font (see the \doc:keyword{textsubsuper} package)\footnote{You
can see a typical footnote here.}.

It also adds a new \doc:keyword{mark} option to the footnote command, which
allows typesetting a footnote with a specific marker instead of
a counter\footnote[mark=†]{As shown here, using \doc:code{\\footnote[mark=†]\{…\}}.}.
In that case, the footnote counter is not altered. Among other things, these custom
marks can be useful for editorial footnotes.

Finally, relying on the \doc:keyword{styles} package, the footnote content
is typeset according to the \doc:keyword{footnote} style (and this re-implementation
of the original footnote package, therefore, does not have a \doc:code{\\footnote:font}
hook).

\end{document}]]
}
