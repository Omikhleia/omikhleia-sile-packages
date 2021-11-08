--
-- Lightweight enumerations and bullet lists
-- License: MIT
--
SILE.require("packages/counters")

SILE.scratch.liststyle = nil

SILE.settings.declare({
  parameter = "list.current.enumerate.depth",
  type = "integer",
  default = 0,
  help = "Current enumerate depth (nesting) - internal"
})

SILE.settings.declare({
  parameter = "list.current.itemize.depth",
  type = "integer",
  default = 0,
  help = "Current itemize depth (nesting) - internal"
})

SILE.settings.declare({
  parameter = "list.enumerate.leftmargin",
  type = "measurement",
  default = SILE.measurement("2em"),
  help = "Left margin (indentation) for enumerations"
})

SILE.settings.declare({
  parameter = "list.enumerate.labelindent",
  type = "measurement",
  default = SILE.measurement("0.5em"),
  help = "Label indentation for enumerations"
})

SILE.settings.declare({
  parameter = "list.enumerate.variant",
  type = "string or nil",
  default = nil,
  help = "Enumeration list variant (styling)"
})

SILE.settings.declare({
  parameter = "list.itemize.leftmargin",
  type = "measurement",
  default = SILE.measurement("1.5em"),
  help = "Left margin (indentation) for bullet lists (itemize)"
})

SILE.settings.declare({
  parameter = "list.itemize.variant",
  type = "string or nil",
  default = nil,
  help = "Bullet list variant (styling)"
})

local styles = SILE.require("packages/styles").exports

-- BEGIN STYLES
-- N.B. Commented out colors and fonts were for the show, lol.

-- Enumerate style
styles.defineStyle("list:enumerate:1", {}, {
  -- font = { weight = 800 },
  enumerate = { display = "arabic", before = "", after = "." }
})
styles.defineStyle("list:enumerate:2", {}, {
  enumerate = { display = "roman", before = "", after = "." }
})
styles.defineStyle("list:enumerate:3", {}, {
  -- color = { color = "blue" },
  enumerate = { display = "alpha", before = "", after = ")" }
})
styles.defineStyle("list:enumerate:4", {}, {
  -- color = { color = "red" },
  enumerate = { display = "arabic", before = "", after = ")" }
})
styles.defineStyle("list:enumerate:5", {}, {
  enumerate = { display = "arabic", before = "§", after = "." }
})

-- Alternate enumerate style
styles.defineStyle("list:enumerate-alternate:1", {}, {
  enumerate = { display = "Alpha", before = "", after = "." }
})
styles.defineStyle("list:enumerate-alternate:2", {}, {
  enumerate = { display = "Roman", before = "", after = "." }
})
styles.defineStyle("list:enumerate-alternate:3", {}, {
  enumerate = { display = "roman", before = "", after = "." }
})
styles.defineStyle("list:enumerate-alternate:4", {}, {
  font = { style = "italic" },
  enumerate = { display = "alpha", before = "", after = "." }
})
styles.defineStyle("list:enumerate-alternate:5", {}, {
  enumerate = { display = "U+2474" }
})

-- Itemize style
styles.defineStyle("list:itemize:1", {}, {
  -- color = { color = "red" },
  itemize = { bullet = "•" } -- black bullet
})
styles.defineStyle("list:itemize:2", {}, {
  itemize = { bullet = "◦" } -- circle bullet
})
styles.defineStyle("list:itemize:3", {}, {
  -- color = { color = "blue" },
  itemize = { bullet = "–" } -- en-dash
})
styles.defineStyle("list:itemize:4", {}, {
  itemize = { bullet = "•" } -- black bullet
})
styles.defineStyle("list:itemize:5", {}, {
  itemize = { bullet = "◦" } -- circle bullet
})
styles.defineStyle("list:itemize:6", {}, {
  -- color = { color = "blue" },
  itemize = { bullet = "–" } -- en-dash
})

-- Alternate itemize style
styles.defineStyle("list:itemize-alternate:1", {}, {
  itemize = { bullet = "—" } -- em-dash
})
styles.defineStyle("list:itemize-alternate:2", {}, {
  itemize = { bullet = "•" } -- black bullet
})
styles.defineStyle("list:itemize-alternate:3", {}, {
  itemize = { bullet = "◦" } -- circle bullet
})
styles.defineStyle("list:itemize-alternate:4", {}, {
  itemize = { bullet = "–" } -- en-dash
})
styles.defineStyle("list:itemize-alternate:5", {}, {
  itemize = { bullet = "•" } -- black bullet
})
styles.defineStyle("list:itemize-alternate:6", {}, {
  itemize = { bullet = "◦" } -- circle bullet
})

local resolveEnumStyleDef = function (name)
  local stylespec = styles.resolveStyle(name)

  local styledef = {}
  if stylespec.enumerate then
    return {
      display = stylespec.enumerate.display or "arabic",
      after = stylespec.enumerate.after or "",
      before = stylespec.enumerate.before or "",
    }
  end
  if stylespec.itemize then
    return {
      bullet = stylespec.itemize.bullet or "•",
    }
  end

  SU.error("Style '"..name.."' is not a list style")
end

local checkEnumStyleName = function (name, defname)
  return SILE.scratch.styles[name] and name or defname
end

-- END STYLES

local trimLeft = function (str)
  return (str:gsub("^%s*", ""))
end
local trimRight = function (str)
  return (str:gsub("%s*$", ""))
end
local trim = function (str)
  return trimRight(trimLeft(str))
end

local enforceListType = function (listType)
  if listType ~= "enumerate" and listType ~= "itemize" then
    SU.error("List type shall be 'enumerate' or 'itemize'")
  end
end

local unichar = function (str)
  local hex = (str:match("[Uu]%+(%x+)") or str:match("0[xX](%x+)"))
  if hex then
    return tonumber("0x"..hex)
  end
  return nil
end

local doItem = function (options, content)
  local enumStyle = content._enumitem_.style
  local depth = content._enumitem_.depth
  local styleName = content._enumitem_.styleName
  local counter = content._enumitem_.counter
  local indent = content._enumitem_.indent

  local mark = SILE.call("hbox", {}, function ()
    SILE.call("style:apply", { name = styleName }, function ()
      if enumStyle.display then
        local cp = unichar(enumStyle.display)
        if cp then
          SILE.typesetter:typeset(luautf8.char(cp + counter - 1))
        else
          SILE.typesetter:typeset(enumStyle.before)
          SILE.typesetter:typeset(SILE.formatCounter({
            value = counter,
            display = enumStyle.display })
          )
          SILE.typesetter:typeset(enumStyle.after)
        end
      else
        local cp = unichar(enumStyle.bullet)
        if cp then
          SILE.typesetter:typeset(luautf8.char(cp))
        else
          SILE.typesetter:typeset(enumStyle.bullet)
        end
      end
    end)
  end)
  table.remove(SILE.typesetter.state.nodes) -- steal it back

  local stepback
  if enumStyle.display then
    -- The positionning is quite tentative... LaTeX would right justify the
    -- number (at least for roman numerals), i.e.
    --   i. Text
    --  ii. Text
    -- iii. Text.
    -- Other Office software do not do that...
    local labelIndent = SILE.settings.get("list.enumerate.labelindent"):absolute()
    stepback = indent - labelIndent
  else
    -- Center bullets in the indentation space
    stepback = indent / 2 + mark.width / 2
  end

  SILE.call("kern", { width = -stepback })
  -- reinsert the mark with modified length
  -- using \rebox caused an issue sometimes, not sure why, with the bullets
  -- appearing twice in output... but we can avoid it:
  -- reboxing an hbox was dumb anyway. We just need to fix its width before
  -- reinserting it in the text flow.
  mark.width = SILE.length(stepback)
  SILE.typesetter:pushHbox(mark)

  SILE.process(content)
  SILE.typesetter:leaveHmode()
end

local doNestedList = function (listType, _, content)
  SILE.typesetter:leaveHmode()

  -- variant
  local variant = SILE.settings.get("list."..listType..".variant")
  local listAltStyleType = variant and listType.."-"..variant or listType

  -- depth
  local depth = SILE.settings.get("list.current."..listType..".depth") + 1
  SILE.settings.set("list.current."..listType..".depth", depth)

  -- styling
  local styleName = checkEnumStyleName("list:"..listAltStyleType..":"..depth, "list:"..listType..":"..depth)
  local enumStyle = resolveEnumStyleDef(styleName)

  -- indent
  local baseIndent = (depth == 1) and SILE.settings.get("document.parindent").width:absolute() or SILE.measurement("0pt")
  local listIndent = SILE.settings.get("list."..listType..".leftmargin"):absolute()

  -- processing
  SILE.settings.temporarily(function ()
    SILE.settings.set("current.parindent", SILE.nodefactory.glue())
    SILE.settings.set("document.parindent", SILE.nodefactory.glue())
    local lskip = SILE.settings.get("document.lskip") or SILE.nodefactory.glue()
    SILE.settings.set("document.lskip", SILE.nodefactory.glue(lskip.width + (baseIndent + listIndent)))
    -- We don't care about the rskip, do we?
  	-- SILE.settings.set("document.rskip", SILE.nodefactory.glue())

    local counter = 0
    for i = 1, #content do
        if type(content[i]) == "table" then
          if content[i].command == "item" then
            counter = counter + 1
            -- Enrich the node with internal properties
            content[i]._enumitem_ = {
              style = enumStyle,
              depth = depth,
              counter = counter,
              indent = listIndent,
              styleName = styleName
            }
          else
            enforceListType(content[i].command)
          end
          SILE.process({ content[i] })
        elseif type(content[i]) == "string" then
          -- All text nodes in ignored in structure tags.
          local text = trim(content[i])
          if text ~= "" then SU.warn("Ignored standalone text ("..text..")") end
        else
          SU.error("List structure error")
        end
    end
  end)
  depth = depth - 1
  SILE.settings.set("list.current."..listType..".depth", depth)
end

SILE.registerCommand("enumerate", function (options, content)
  doNestedList("enumerate", options, content)
end)

SILE.registerCommand("itemize", function (options, content)
  doNestedList("itemize", options, content)
end)

SILE.registerCommand("item", function (options, content)
  if not content._enumitem_ then
    SU.error("The item command shall not be called outside a list")
  end
  doItem(options, content)
end)

return {
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]

This package provides enumerations and bullet lists (a.k.a. \em{itemization}\kern[width=0.1em]), which can
be styled\footnote{So you can for instance pick up a color and a font for the bullet
symbol. Refer to our \doc:keyword{styles} package for details on how to set and configure
style specifications.} and, of course, nested together.

\smallskip

\em{Bullet lists.}
\novbreak

The \doc:code{itemize} environment initiates a bullet list.
Each item is, as could be guessed, wrapped in an \doc:code{\\item}
command.

The environment, as a structure or data model, can only contain item elements
and other lists. Any other element causes an error to be
reported, and any
text content is ignored with a warning.

\begin{itemize}
    \item{Lorem}
    \begin{itemize}
        \item{Ipsum}
        \begin{itemize}
            \item{Dolor}
            \begin{itemize}
                \item{Sit amet}
            \end{itemize}
        \end{itemize}
    \end{itemize}
\end{itemize}

The current implementation supports up to 6 indentation levels, which
are set according to the \doc:code{list:itemize:\doc:args{level}} styles.

On each level, the indentation is defined by the \doc:code{list.itemize.leftmargin}
setting (defaults to 1.5em) and the bullet is centered in that margin.

Note that if your document has a paragraph indent enabled at this point, it
is also added to the first list level.

The good typographic rules sometimes mandate a certain form of representation.
In French, for instance, the em-dash is far more common for the initial bullet
level than the black circle. When one typesets a book in a multi-lingual
context, changing all the style levels consistently would be appreciated.
The package therefore exposes a \doc:code{list.itemize.variant}
setting, to switch to an alternate set of styles, such as the following.

\set[parameter=list.itemize.variant, value=alternate]{%
\begin{itemize}
    \item{Lorem}
    \begin{itemize}
        \item{Ipsum}
        \begin{itemize}
            \item{Dolor}
            \begin{itemize}
                \item{Sit amet}
            \end{itemize}
        \end{itemize}
    \end{itemize}
\end{itemize}
}

The alternate styles are expected to be named \doc:code{list:itemize-\doc:args{variant}:\doc:args{level}}
and the package comes along with a pre-defined “alternate” variant using the em-dash.\footnote{This author is
obviously French…} A good typographer is not expected to switch variants in the middle of a list, so the effect
has not been checked. Be a good typographer.

\smallskip

\em{Enumerations.}
\novbreak

The \doc:code{enumerate} environment initiates an enumeration.
Each item shall, again, be wrapped in an \doc:code{\\item}
command. This environment too is regarded as a structure, so the same rules
as above apply.

\begin{enumerate}
    \item{Lorem}
    \begin{enumerate}
        \item{Ipsum}
        \begin{enumerate}
            \item{Dolor}
            \begin{enumerate}
                \item{Sit amet}
                \begin{enumerate}
                    \item{Consectetur}
                \end{enumerate}
            \end{enumerate}
        \end{enumerate}
    \end{enumerate}
\end{enumerate}

The current implementation supports up to 5 indentation levels, which
are set according to the \doc:code{list:enumerate:\doc:args{level}} styles.

On each level, the indentation is defined by the \doc:code{list.enumerate.leftmargin}
setting (defaults to 2em). Note, again, that if your document has a paragraph indent enabled
at this point, it is also added to the first list level. And… ah, at least something less
repetitive than a raw list of features. \em{Quite obviously}, we cannot center the label.
Roman numbers, folks, if any reason is required. The \doc:code{list.enumerate.labelindent}
setting specifies the distance between the label and the previous indentation level (defaults
to 0.5em). Tune these settings at your convenience depending on your styles. If there is a more
general solution to this subtle issue, this author accepts patches.\footnote{TeX typesets
the enumeration label ragged left. Other Office software do not.}

As for bullet lists, switching to an alternate set of styles is possible with,
you certainly guessed it already, the \doc:code{list.enumerate.variant} setting.

\set[parameter=list.enumerate.variant, value=alternate]{%
\begin{enumerate}
    \item{Lorem}
    \begin{enumerate}
        \item{Ipsum}
        \begin{enumerate}
            \item{Dolor}
            \begin{enumerate}
                \item{Sit amet}
                \begin{enumerate}
                    \item{Consectetur}
                \end{enumerate}
            \end{enumerate}
        \end{enumerate}
    \end{enumerate}
\end{enumerate}
}

The alternate styles are expected to be \doc:code{list:enumerate-\doc:args{variant}:\doc:args{level}},
how imaginative, and the package comes along with a pre-defined “alternate” variant, just because.

\smallskip

\em{Nesting.}
\novbreak

Both environment can be nested, \em{of course}. The way they do is best illustrated by
an example.

\set[parameter=list.itemize.variant, value=alternate]{%
\begin[variant=alternate]{enumerate}
    \item{Lorem}
    \begin{enumerate}
        \item{Ipsum}
        \begin{itemize}
            \item{Dolor}
            \begin{enumerate}
                \item{Sit amet}
                \begin{itemize}
                    \item{Consectetur}
                \end{itemize}
            \end{enumerate}
        \end{itemize}
    \end{enumerate}
\end{enumerate}
}

\smallskip

\em{Other considerations.}
\novbreak

Do not expect these fragile lists to work in any way in centered or ragged-right environments, or
with fancy line-breaking features such as hanged or shaped paragraphs. Please be a good
typographer. Also, these lists have not been experimented yet in right-to-left
or vertical writing direction.

\end{document}]]
}