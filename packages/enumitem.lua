-- 
-- Lightweight enumerations and bullet lists
-- VERY ROUGH STUFF, QUICK AND DIRTY IMPLEMENTATION
-- Many internal things will change after a proper refactor.
-- Look at the documentation, but do not expect the code to be stable.
-- License: MIT
--
SILE.require("packages/counters")
SILE.require("packages/rebox")

SILE.scratch.liststyle = nil

SILE.settings.declare({
  parameter = "list.enumerate.depth",
  type = "integer",
  default = 0,
  help = "Current enumerate depth (nesting) - internal"
})

SILE.settings.declare({
  parameter = "list.itemize.depth",
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
  local stylespec = SILE.scratch.styles[name] and SILE.scratch.styles[name]
  if not stylespec then SU.error("Style '"..name.."' does not exist") end

  -- FIXME Later: Recurse for style inheritance.
  local styledef = 
    --stylespec.inherit and resolveEnumStyleDef(stypespec.inherit) or 
    {}
  if stylespec.style.enumerate then
    styledef.display = stylespec.style.enumerate.display or styledef.display or "arabic"
    styledef.after = stylespec.style.enumerate.after or styledef.after or ""
    styledef.before = stylespec.style.enumerate.before or styledef.before or ""
    return styledef
  end
  if stylespec.style.itemize then
    styledef.bullet = stylespec.style.itemize.bullet or styledef.bullet or "*"
    return styledef
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

SILE.registerCommand("enumerate", function (options, content)
  SILE.typesetter:leaveHmode()

  -- options
  local listType = options.type or "enumerate"
  if listType ~= "enumerate" and listType ~= "itemize" then
    SU.error("List type shall be 'enumerate' or 'itemize'")
  end

  -- variant
  local variant = SILE.settings.get("list."..listType..".variant")
  local listAltStyleType = variant and listType.."-"..variant or listType
  
  -- depth
  local depth = SILE.settings.get("list."..listType..".depth") + 1
  SILE.settings.set("list."..listType..".depth", depth)

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

    local iElem = 0
    for i = 1, #content do
        if type(content[i]) == "table" then
          if content[i].command == "item" then
            iElem = iElem + 1
            -- FIXME I don't like this passing via options, was a quick'n dirty way.
            content[i].options._style = enumStyle
            content[i].options._depth = depth
            content[i].options._number = iElem
            content[i].options._indent = listIndent
            content[i].options._styleName = styleName
          else
            -- Propagate, if not overridden
            content[i].options.variant = content[i].options.variant or options.variant 
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
  SILE.settings.set("list."..listType..".depth", depth)
end)

local unichar = function (str)
  local hex = (str:match("[Uu]%+(%x+)") or str:match("0[xX](%x+)"))
  if hex then
    return tonumber("0x"..hex)
  end
  return nil
end

SILE.registerCommand("item", function (options, content)
  local enumStyle = options._style
  local depth = options._depth
  local styleName = options._styleName
  local number = options._number or 0
  local listIndent = options._indent or SILE.measurement()

  local mark = SILE.call("hbox", {}, function ()
    SILE.call("style:apply", { name = styleName }, function ()
      --SILE.call("show-counter", { id = "enumerate" .. depth })
      if enumStyle.display then
        local cp = unichar(enumStyle.display)
        if cp then
          print("codepoint", cp)
          SILE.typesetter:typeset(luautf8.char(cp + number - 1))
        else
          SILE.typesetter:typeset(enumStyle.before)
          SILE.typesetter:typeset(SILE.formatCounter({
            value = number,
            display = enumStyle.display })
          )
          SILE.typesetter:typeset(enumStyle.after)
        end
      else
        SILE.typesetter:typeset(enumStyle.bullet)
      end
    end)
  end)
  table.remove(SILE.typesetter.state.nodes) -- steal it back

  local stepback
  if enumStyle.display then
    -- Tentative...
    local labelIndent = SILE.settings.get("list.enumerate.labelindent"):absolute()
    stepback = listIndent - labelIndent
  else
    -- Center bullets in the indentation space
    stepback = listIndent / 2 + mark.width / 2
  end
 
  SILE.call("kern", { width = -stepback })
  SILE.call("rebox", { width = stepback }, function ()
    SILE.typesetter:pushHbox(mark)
  end)
  
  SILE.process(content)
  SILE.typesetter:leaveHmode()
end)

SILE.registerCommand("itemize", function (options, content)
  options.type = "itemize"
  SILE.call("enumerate", options, content)
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
you certainly guessed it already, the \doc:code{list.enumerate.variant}.

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