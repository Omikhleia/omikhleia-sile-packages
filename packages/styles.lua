--
-- A style package for SILE
-- License: MIT
--
SILE.scratch.styles = {
  -- Actual style specifications will go there (see defineStyle etc.)
  specs = {},
  -- Known aligns options, with the command implementing them.
  -- Users can register extra options in this table.
  alignments = {
    center = "center",
    left = "raggedright",
    right = "raggedleft",
    -- be friendly with users...
    raggedright = "raggedright",
    raggedleft = "raggedleft",
  },
  -- Known skip options.
  -- Users can add register custom skips there.
  skips = {
    smallskip = SILE.settings.get("plain.smallskipamount"),
    medskip = SILE.settings.get("plain.medskipamount"),
    bigskip = SILE.settings.get("plain.bigskipamount"),
  },
}

SILE.registerCommand("style:font", function (options, content)
  local size = tonumber(options.size)
  local opts = pl.tablex.copy(options) -- shallow copy
  if size then
    opts.size = SILE.settings.get("font.size") + size
  end

  SILE.call("font", opts, content)
end, "Applies a font, with additional support for relative sizes.")

SILE.registerCommand("style:define", function (options, content)
  local name = SU.required(options, "name", "style:define")
  if options.inherit and SILE.scratch.styles.specs[options.inherit] == nil then
    SU.error("Unknown inherited named style '" .. options.inherit .. "'.")
  end
  if options.inherit and options.inherit == options.name then
    SU.error("Named style '" .. options.name .. "' cannot inherit itself.")
  end
  SILE.scratch.styles.specs[name] = { inherit = options.inherit, style = {} }
  for i=1, #content do
    if type(content[i]) == "table" and content[i].command then
        SILE.scratch.styles.specs[name].style[content[i].command] = content[i].options
    end
  end
end, "Defines a named style.")

-- Very naive cascading...
local styleForColor = function (style, content)
  if style.color then
    SILE.call("color", style.color, content)
  else
    SILE.process(content)
  end
end
local styleForFont = function (style, content)
  if style.font then
    SILE.call("style:font", style.font, function ()
      styleForColor(style, content)
    end)
  else
    styleForColor(style, content)
  end
end

local styleForSkip = function (skip, vbreak)
  local b = SU.boolean(vbreak, true)
  if skip then
    local vglue = SILE.scratch.styles.skips[skip] or SU.cast("vglue", skip)
    if not b then SILE.call("novbreak") end
    SILE.typesetter:pushExplicitVglue(vglue)
  end
  if not b then SILE.call("novbreak") end
end

local styleForAlignment = function (style, content, breakafter)
  if style.paragraph and style.paragraph.align then
    if style.paragraph.align and style.paragraph.align ~= "justify" then
      local alignCommand = SILE.scratch.styles.alignments[style.paragraph.align]
      if not alignCommand then
        SU.error("Invalid paragraph style alignment '"..style.paragraph.align.."'")
      end
      if not breakafter then SILE.call("novbreak") end
      SILE.typesetter:leaveHmode()
      -- Here we must apply the font, then the alignement, so that line heights are
      -- correct even on the last paragraph. But the color introduces hboxes so
      -- must be applied last, no to cause havoc with the noindent/indent and
      -- centering etc. environments
      if style.font then
        SILE.call("style:font", style.font, function ()
          SILE.call(alignCommand, {}, function ()
            styleForColor(style, content)
            if not breakafter then SILE.call("novbreak") end
          end)
        end)
      else
        SILE.call(alignCommand, {}, function ()
          styleForColor(style, content)
          if not breakafter then SILE.call("novbreak") end
        end)
      end
    else
      styleForFont(style, content)
      if not breakafter then SILE.call("novbreak") end
      -- NOTE: SILE.call("par") would cause a parskip to be inserted.
      -- Not really sure whether we expect this here or not.
      SILE.typesetter:leaveHmode()
    end
  else
    styleForFont(style, content)
  end
end

local function dumpOptions(v)
  local opts = {}
  for k, v in pairs(v) do
    opts[#opts+1] = k.."="..v
  end
  return table.concat(opts, ", ")
end
local function dumpStyle (name)
  local stylespec = SILE.scratch.styles.specs[name]
  if not stylespec then return "(undefined)" end

  local desc = {}
  for k, v in pairs(stylespec.style) do
    desc[#desc+1] = k .. "[" .. dumpOptions(v).."]"
  end
  local textspec = table.concat(desc, ", ")
  if stylespec.inherit then
    if #textspec > 0 then
      textspec = stylespec.inherit.." > "..textspec
    else
      textspec = "< "..stylespec.inherit
    end
  end
  return textspec
end

local function resolveStyle (name)
  local stylespec = SILE.scratch.styles.specs[name]
  if not stylespec then SU.error("Style '"..name.."' does not exist") end

  if stylespec.inherit then
    local inherited = resolveStyle(stylespec.inherit)
    -- Deep merging the specification options
    local sty = pl.tablex.deepcopy(stylespec.style)
    for k, v in pairs(inherited) do
      if sty[k] then
        sty[k] = pl.tablex.union(v, sty[k])
      else
        sty[k] = v
      end
    end
    return sty
  end
  return stylespec.style
end

-- APPLY A CHARACTER STYLE

SILE.registerCommand("style:apply", function (options, content)
  local name = SU.required(options, "name", "style:apply")
  local styledef = resolveStyle(name)

  styleForFont(styledef, content)
end, "Applies a named style to the content.")

-- APPLY A PARAGRAPH STYLE

SILE.registerCommand("style:apply:paragraph", function (options, content)
  local name = SU.required(options, "name", "style:apply:paragraph")
  local styledef = resolveStyle(name)
  local parSty = styledef.paragraph

  if parSty then
    local bb = SU.boolean(parSty.breakbefore, true)
    if #SILE.typesetter.state.nodes then
      if not bb then SILE.call("novbreak") end
      SILE.typesetter:leaveHmode()
    end
    styleForSkip(parSty.skipbefore, parSty.breakbefore)
    if SU.boolean(parSty.indentbefore, true) then
      SILE.call("indent")
    else
      SILE.call("noindent")
    end
  end

  local ba = not parSty and true or SU.boolean(parSty.breakafter, true)
  styleForAlignment(styledef, content, ba)

  if parSty then
    if not ba then SILE.call("novbreak") end
    -- NOTE: SILE.call("par") would cause a parskip to be inserted.
    -- Not really sure whether we expect this here or not.
    SILE.typesetter:leaveHmode()
    styleForSkip(parSty.skipafter, parSty.breakafter)
    if SU.boolean(parSty.indentafter, true) then
      SILE.call("indent")
    else
      SILE.call("noindent")
    end
  end
end, "Applies the paragraph style entirely.")

-- STYLE REDEFINITION

SILE.registerCommand("style:redefine", function (options, content)
  SU.required(options, "name", "style:redefined")

  if options.as then
    if options.as == options.name then
      SU.error("Style '" .. options.name .. "' should not be redefined as itself.")
    end

    -- Case: \style:redefine[name=style-name, as=saved-style-name]
    if SILE.scratch.styles.specs[options.as] ~= nil then
      SU.error("Style '" .. options.as .. "' would be overwritten.") -- Let's forbid it for now.
    end
    local sty = SILE.scratch.styles.specs[options.name]
    if sty == nil then
      SU.error("Style '" .. options.name .. "' does not exist!")
    end
    SILE.scratch.styles.specs[options.as] = sty

    -- Sub-case: \style:redefine[name=style-name, as=saved-style-name, inherit=true/false]{content}
    -- TODO We could accept another name in the inherit here? Use case?
    if content and (type(content) ~= "table" or #content ~= 0) then
      SILE.call("style:define", { name = options.name, inherit = SU.boolean(options.inherit, false) and options.as }, content)
    end
  elseif options.from then
    if options.from == options.name then
      SU.error("Style '" .. option.name .. "' should not be restored from itself, ignoring.")
    end

    -- Case \style:redefine[name=style-name, from=saved-style-name]
    if content and (type(content) ~= "table" or #content ~= 0) then
      SU.warn("Extraneous content in '" .. options.name .. "' is ignored.")
    end
    local sty = SILE.scratch.styles.specs[options.from]
    if sty == nil then
      SU.error("Style '" .. option.from .. "' does not exist!")
    end
    SILE.scratch.styles.specs[options.name] = sty
    SILE.scratch.styles.specs[options.from] = nil
  else
    SU.error("Style redefinition needs a 'as' or 'from' parameter.")
  end
end, "Redefines a style saving the old version with another name, or restores it.")

-- DEBUG OR DOCUMENTATION

SILE.registerCommand("style:show", function (options, content)
  local name = SU.required(options, "name", "style:show")

  SILE.typesetter:typeset(dumpStyle(name))
end, "Ouputs a textual (human-readable) description of a named style.")

-- EXPORTS

return {
  exports = {
    -- programmatically define a style
    defineStyle = function(name, opts, styledef)
      SILE.scratch.styles.specs[name] = { inherit = opts.inherit, style = styledef }
    end,
    -- resolve a style (incl. inherited fields)
    resolveStyle = resolveStyle,
    -- human-readable specification for debug (text)
    dumpStyle = dumpStyle
  },
  documentation = [[\begin{document}
\script[src=packages/color]
\script[src=packages/unichar]
\script[src=packages/enumitem]
\script[src=packages/autodoc-extras]

The \doc:keyword{styles} package aims at easily defining “styling specifications”.
It is intended to be used by other packages or classes, rather than directly—though
users might of course use the commands provided herein to customize some styling
definitions according to their needs.

How can one customize the various SILE environments they use in their writings?
For instance, in order to apply a different font or even a color to section
titles, a specific rendering for some entry levels in a table of contents and different
vertical skips here or there? They have several ways, already:

\begin{itemize}
\item{The implementation might provide settings that they can tune.}
\item{The implementation might be kind enough to provide a few “hooks” that they can change.}
\item{Otherwise, they have no other solution but digging into the class or package source code
  and rewrite the impacted commands, with the risk that they will not get updates, fixes and
  changes if the original implementation is modified in a later release.}
\end{itemize}

The last solution is clearly not satisfying. The first too, is unlikely, as class
and package authors cannot decidely expose everything in settings (which are not really
provided, one could even argue, for that purpose). Most “legacy” packages and classes
therefore rely on hooks. This degraded solution, however, may raise several concerns.
Something may seem wrong (though of course it is a matter of taste and could be debated).

\begin{enumerate}
\item{Many commands have “font hooks” indeed, with varying implementations,
    such as \doc:code{pullquote:font} and \doc:code{book:right-running-head-font} to quote
    just a few. None of these seem to have the same type of name. Their scope too is not
    always clear. But what if one also wants, for instance, to specify a color? 
    Of course, in many cases, the hook could be redefined to apply that wanted color
    to the content… But, er, isn’t it called \doc:code{…font}? Something looks amiss.}
\item{Those hooks often have fixed definitions, e.g. footnote text at 9pt, chapter heading
  at 22pt, etc. This doesn’t depend on the document main font size. LaTeX, years before,
  was only a bit better here, defining different relative sizes (but assuming a book is
  always typeset in 10pt, 11pt or 12pt).}
\item{Many commands, say book sectioning, rely on hard-coded vertical skips. But what if
  one wants a different vertical spacing? Two solutions come to mind, either redefining
  the relevant commands (say \doc:code{\\chapter}), but we noted the flaws of that
  method, or temporarily redefining the skips (say, \doc:code{\\bigskip})… In a way,
  it all sounds very clumsy, cumbersome, somehow \em{ad hoc}, and… here, LaTeX-like.
  Which is not necessarily wrong (there is no offense intended here), but why not try
  a different approach?}
\end{enumerate}

Indeed, \em{why not try a different approach}. Actually, this is what most modern
word-processing software have been doing for a while, be it Microsoft Word or Libre/OpenOffice
and cognates… They all introduce the concept of “styles”, in actually three forms at
least: character styles, paragraph styles and page styles; But also frame styles, 
list styles and table styles, to list a few others. This package is an attempt at
implementing such ideas, or a subset of them, in SILE. We do not intend to cover
all the inventory of features provided in these software via styles.
First, because some of them already have matching mechanisms, or even of a superior
design, in SILE. Page masters, for instances, are a neat concept, and we do not
really need to address them differently. This implementation therefore focuses
on some practical use cases. The styling paradigm proposed here has two aims:

\begin{itemize}
\item{Avoid programmable hooks as much as possible,}
\item{Replace them with a formal abstraction that can be shared between implementations.}
\end{itemize}

% We will even use our own fancy paragraph style for internal sectioning below.
\style:define[name=internal-sectioning]{
    \font[style=italic]
    \paragraph[skipbefore=smallskip, skipafter=smallskip, breakafter=false]
}
\define[command=P]{\style:apply:paragraph[name=internal-sectioning]{\process}}

\P{Regular styles.}

To define a (character) style, one uses the following syntax (with any of the internal
elements being optional):

\begin{doc:codes}
\\style:define[name=\doc:args{name}]\{
\par\quad\\font[\doc:args{font specification}]
\par\quad\\color[color=\doc:args{color}]
\par\}
\end{doc:codes}

\style:define[name=style@example]{
    \font[family=Libertinus Serif, features=+smcp, style=italic]
    \color[color=blue]
}

Can you guess how this \style:apply[name=style@example]{Style} was defined?
Note that despite their command-like syntax, the elements in style
specifications are not (necessarily) corresponding to actual commands.
It just uses that familiar syntax as a convenience.\footnote{Technically-minded readers may
also note it is also very simple to implement that way, just relying
on SILE’s standard parser and its underlying AST.}

A style can also inherit from a previously-defined style:

\begin{doc:codes}
\\style:define[name=\doc:args{name}, inherit=\doc:args{other-name}]\{
\par\quad…
\par\}
\end{doc:codes}

This simple style inheritance mechanism is actually quite powerful, allowing
you to re-use or redefine (see further below) existing styles and just
override the elements you want.

\P{Styles for the table of contents.}

The style specification, besides the formatting commands, includes:

\begin{itemize}
\item{Displaying the page number or not,}
\item{Filling the line with dots or not (which, obviously, is only meaningful if the previous option is
      set to true),}
\item{Displaying the section number or not.}
\end{itemize}

\begin{doc:codes}
\\style:define[name=\doc:args{name}]\{
\par\quad{}…
\par\quad\\toc[pageno=\doc:args{boolean}, dotfill=\doc:args{boolean}, numbering=\doc:args{boolean}]
\par\}
\end{doc:codes}

Note that by nature, TOC styles are also paragraph styles (see further below). Moreover,
they also accept an extra specification, which is applied when \doc:code{number} is true, defining:

\begin{itemize}
\item{The text to prepend to the number,}
\item{The text to append to the number,}
\item{The kerning space added after it (defaults to 1spc).}
\end{itemize}

\begin{doc:codes}
\quad{}\\numbering[before=\doc:args{string}, after=\doc:args{string}, kern=\doc:args{length}]
\end{doc:codes}

The pre- and post-strings can be set to false, if you need to disable
an inherited value.

\P{Character styles for bullet lists.}

The style specification includes the character to use as bullet. The other character
formatting commands should of course apply to the bullet too.

\begin{doc:codes}
\\style:define[name=\doc:args{name}]\{
\par\quad{}…
\par\quad\\itemize[bullet=\doc:args{character}]
\par\}
\end{doc:codes}

The bullet can be either entered directly as a character, or provided as a Unicode codepoint in
hexadecimal (U+xxxx).

\P{Character styles for enumerations.}

The style specification includes:

\begin{itemize}
\item{The display type (format) of the item, as “arabic”, “roman”, etc.}
\item{The text to prepend to the value,}
\item{The text to append to the value.}
\end{itemize}

\begin{doc:codes}
\\style:define[name=\doc:args{name}]\{
\par\quad{}…
\par\quad\\enumerate[display=\doc:args{string}, before=\doc:args{string}, after=\doc:args{string}]
\par\}
\end{doc:codes}

The specification also accepts another extended syntax:

\begin{doc:codes}
\\style:define[name=\doc:args{name}]\{
\par\quad{}…
\par\quad\\enumerate[display=\doc:args{U+xxxx}]
\par\}
\end{doc:codes}

\smallskip

Where the display format is provided as a Unicode codepoint in hexadecimal, supposed to
represent the glyph for “1”. It allows using a subsequent range of Unicode characters
as number labels, even though the font may not include any OpenType feature to enable
these automatically. For instance, one could specify U+2474 \unichar{U+2474} (“parenthesized digit one”)…
or, why not, U+2460 \unichar{U+2460}, U+2776 \unichar{U+2776} or even U+24B6 \unichar{U+24B6}, and so on.
It obviously requires the font to have these characters, and due to the way how Unicode is
done, the enumeration to stay within a range corresponding to expected characters.

The other character formatting commands should of course apply to the full label.

\P{Paragraph styles.}

To define a paragraph style, one uses the following syntax (with any of the internal
elements being optional):

\begin{doc:codes}
\\style:define[name=\doc:args{name}]\{
\par\quad{}…
\par\quad\\paragraph[skipbefore=\doc:args{glue|skip}, indentbefore=\doc:args{boolean}
\par\qquad{}skipafter=\doc:args{glue|skip}, indentafter=\doc:args{boolean},
\par\qquad{}breakbefore=\doc:args{boolean}, breakafter=\doc:args{boolean},
\par\qquad{}align=\doc:args{center|right|left|justify}]
\par\}
\end{doc:codes}

The specification includes:

\begin{itemize}
\item{The amount of vertical space before the paragraph, as a variable length or a well-known named skip
    (bigskip, medskip, smallskip).}
\item{Whether indentation is applied to this paragraph (defaults to true). Book sectioning commands,
    typically, usually set it to false, for the section title not to be indented.}
\item{The amount of vertical space after the paragraph, as a variable length or a well-known named skip
    (bigskip, medskip, smallskip).}
\item{Whether indentation is applied to the next paragraph (defaults to true). Book sectioning commands,
    typically, may set it to false or true.\footnote{The usual convention for English
    books is to disable the first paragraph indentation after a section title. The French convention, however,
    is to always indent regular paragraphs, even after a section title.}}
\item{Whether a page break may occur before or after this paragraph (defaults to true). Book sectioning commands,
    typically, would set the after-break to false.}
\item{The paragraph alignment (center, left, right or justify—the latter is the default but may be
    useful to overwrite an inherited alignment).}
\end{itemize}

\P{Advanced paragraph styles.}

As specified above, the styles specifications do not provide any way to configure
the margins (i.e. left and right skips) and other low-level paragraph formatting
options.

\script{
-- We use long names with @ in them just to avoid messing with document
-- styles a user might have defined, but obviously this could just be
-- called "block" or whathever.
SILE.registerCommand("style@blockindent", function (options, content)
  SILE.settings.temporarily(function ()
    local indent = SILE.length("2em")
    SILE.settings.set("document.rskip", SILE.nodefactory.glue(indent))
    SILE.settings.set("document.lskip", SILE.nodefactory.glue(indent))
    SILE.process(content)
    SILE.call("par")
  end)
end, "Typesets its contents in a blockquote.")
SILE.scratch.styles.alignments["block@example"] = "style@blockindent"
}
\style:define[name=style@block]{
    \font[size=-1]
    \paragraph[skipbefore=smallskip, skipafter=smallskip, align=block@example]
}

\begin[name=style@block]{style:apply:paragraph}
But it does not mean this is not possible at all.
You can actually define your own command in Lua that sets these things at
your convenience, and register it with some name in
the \doc:code{SILE.scratch.styles.alignments} array,
so it gets known and is now a valid alignment option.

It allows you to easily extend the styles while still getting the benefits
from their other features.
\end{style:apply:paragraph}

Guess what, it is actually what we did here in code, to typeset the above
“block-indented” paragraph. Similarly, you can also register your own skips
by name in \doc:code{SILE.scratch.styles.skips} so that to use them
in the various paragraph skip options.

As it can be seen in the example above, moreover, what we call a paragraph
here in our styling specification is actually a “paragraph block”—nothing
forbids you to typeset more than one actual paragraph in that environment.
The vertical skip and break options apply before and after that whole block,
not within it; this is by design, notably so as to achieve that kind of
block-indented quotes.

\P{Applying a character style.}

To apply a character style to some content, one just has to do:

\begin{doc:codes}
\\style:apply[name=\doc:args{name}]\{\doc:args{content}\}
\end{doc:codes}

\P{Applying a paragraph style.}

Likewise, the following command applies the whole paragraph style to its content, that is:
the skips and options applying before the content, the character style and the alignment
on the content itself, and finally the skips and options applying after it.

\begin{doc:codes}
\\style:apply:paragraph[name=\doc:args{name}]\{\doc:args{content}\}
\end{doc:codes}

Why a specific command, you may ask? Sometimes, one may want to just apply only the
(character) formatting specifications of a style.

\P{Applying the other styles.}

A style is a versatile concept and a powerful paradigm, but for some advanced usages it
cannot be fully generalized in a single package. The sectioning, table of contents or
enumeration styles all require support from other packages. This package just provides
them a general framework to play with. Actually we refrained for checking many things
in the style specifications, so one could possibly extend them with new concepts and
benefit from the proposed core features and simple style inheritance model.

\P{Redefining styles.}

Regarding re-definitions now, the first syntax below allows one to change the definition
of style \doc:args{name} to new \doc:args{content}, but saving the previous definition to \doc:args{saved-name}:

\begin{doc:codes}
\\style:redefine[name=\doc:args{name}, as=\doc:args{saved-name}]\{\doc:args{content}\}
\end{doc:codes}

From now on, style {\\\doc:args{name}} corresponds to the new definition,
while \doc:code{\\\doc:args{saved-name}} corresponds to previous definition, whatever it was.

Another option is to add the \doc:code{inherit} option to true, as show below:
\begin{doc:codes}
\\style:redefine[name=\doc:args{name}, as=\doc:args{saved-name}, inherit=true]\{\doc:args{content}\}
\end{doc:codes}

From now on, style {\\\doc:args{name}} corresponds to the new definition as above, but
also inherits from \doc:code{\\\doc:args{saved-name}} — in other terms, both are applied. This allows
one to only leverage the new definition, basing it on the older one.

Note that if invoked without \doc:args{content}, the redefinition will just define an alias to the current
style (and in that case, obviously, the \doc:code{inherit} flag is not supported).
It is not clear whether there is an interesting use case for it (yet), but here you go:

\begin{doc:codes}
\\style:redefine[name=\doc:args{name}, as=\doc:args{saved-name}]
\end{doc:codes}

Finally, the following syntax allows one to restore style \doc:args{name} to whatever was saved
in \doc:args{saved-name}, and to clear the latter:

\begin{doc:codes}
\\style:redefine[name=\doc:args{name}, from=\doc:args{saved-name}]
\end{doc:codes}

So now on, \doc:code{\\\doc:args{name}} is restored to whatever was saved and \doc:code{\\\doc:args{saved-name}}
is no longer defined.

These style redefinion mechanisms are, obviously, at the core of customization.

\P{Additional goodies.}

The package also defines a \doc:code{\\style:font} command, which is basically the same as the
standard \doc:code{\\font} command, but additionaly supports relative sizes with respect to
the current \doc:code{font.size}. It is actually the command used when applying a font style
specification. For the sake of illustration, let’s assume the following definitions:

\begin{doc:codes}
\\style:define[name=smaller]\{\\font[size=-1]\}

\\style:define[name=bigger]\{\\font[size=+1]\}

\\define[command=smaller]\{\\style:apply[name=smaller]\{\\process\}\}

\\define[command=bigger]\{\\style:apply[name=bigger]\{\\process\}\}
\end{doc:codes}

\style:define[name=smaller]{\font[size=-1]}
\style:define[name=bigger]{\font[size=+1]}
\define[command=smaller]{\style:apply[name=smaller]{\process}}
\define[command=bigger]{\style:apply[name=bigger]{\process}}

Then:

\begin{doc:codes}
Normal \\smaller\{Small \\smaller\{Tiny\}\},

Normal \\bigger\{Big \\bigger\{Great\}\}.
\end{doc:codes}

Yields: Normal \smaller{Small \smaller{Tiny}}, Normal \bigger{Big \bigger{Great}}.

\end{document}]]
}

