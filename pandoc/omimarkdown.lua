-- SILE custom writer for pandoc.
-- 2022, Didier Willis
-- License: MIT
--
-- Invoke with: pandoc -t omimarkdown.lua xxx.md > xxx.sil
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua sample.lua' will
-- produce informative error messages if your code contains
-- syntax errors.

local pipe = pandoc.pipe
local stringify = (require "pandoc.utils").stringify

-- The global variable PANDOC_DOCUMENT contains the full AST of
-- the document which is going to be written. It can be used to
-- configure the writer.
local metadata = PANDOC_DOCUMENT.meta

local function split (source, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']+)'
  string.gsub(source, pattern, function(value) elements[#elements + 1] = value;  end);
  return elements
end
local function normalizeLang (lang)
  -- Pandoc says language should be a BCP 47 identifier such as "en-US",
  -- SILE only knows about "en" for now...
  return split(lang, "-")[1]
end

-- Character escaping (in text)
local function escape (s, in_attribute)
  return s:gsub("[%%\\{}]",
    function(x)
      if x == '%' then
        return '\\%'
      elseif x == '\\' then
        return '\\\\'
      elseif x == '{' then
        return '\\{'
      elseif x == '}' then
        return '\\}'
      else
        return x
      end
    end)
end
-- Character escaping (in parameters)
local function escapeStringParam(param)
  local r = stringify(param)
  return r:gsub('"', '\\"')
end

local function escapeStringOrTableParam(param)
  if type(param) == "table" then
    return escapeStringParam(table.concat(param, '; '))
  end
  return escapeStringParam(param)
end

local function getFileExtension(fname)
  -- extract file name and then extension
  return fname:match("[^/]+$"):match("[^.]+$")
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
-- FIXME: We don't need this for SILE, but left for later consideration.
local function attributes(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= "" then
      table.insert(attr_table, ' ' .. x .. '="' .. escape(y,true) .. '"')
    end
  end
  return table.concat(attr_table)
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}

-- Blocksep is used to separate block elements.
function Blocksep ()
  return "\n\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc (body, metadata, variables)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  local papersize = metadata.papersize and escapeStringParam(metadata.papersize) or "a4"
  local lang = metadata.lang and escapeStringParam(metadata.lang) or "en"
  local dir = metadata.dir == "rtl" and "RTL" or (metadata.dir == "ltr" and "LTR")
  local direction = dir and ", direction="..dir or ""
  local class = type(metadata.sile) == "table" and metadata.sile['class'] or "omibook"
  add('\\begin[papersize='..papersize..direction..', class='..class..']{document}')
  add('\\script[src=packages/enumitem]')
  add('\\script[src=packages/font-fallback]')
  add('\\script[src=packages/textsubsuper]')
  add('\\script[src=packages/ptable]')
  add('\\script[src=packages/image]')
  add('\\script[src=packages/url]')
  add('\\script[src=packages/rules]')
  add('\\script[src=packages/verbatim]')
  add('\\script[src=packages/svg]')
  add('\\script[src=packages/experimental/codehighlighter]')
  add('\\script[src=hacks/rules-strike-fill]% HACK') -- HACK

  local scripts = type(metadata.sile) == "table" and metadata.sile.scripts
  if type(scripts) == "table" and #scripts > 0 then
    for _, src in ipairs(scripts) do
      add('\\script[src='..escapeStringParam(src)..']')
    end
  elseif type(scripts) == "string" then
    add('\\script[src='..escapeStringParam(scripts)..']')
  end

  add('\\footnote:rule')
  add('\\neverindent') -- HACK FOR LATER

  add('\\language[main='..normalizeLang(lang)..']')
  local fontfamily = type(metadata.sile) == "table" and metadata.sile['font-family']
  if type(fontfamily) == "table" and #fontfamily > 0 then
    add('\\font[family='..escapeStringParam(fontfamily[1])..']')
    for fallback = 2, #fontfamily do
      add('\\font:add-fallback[family='..escapeStringParam(fontfamily[fallback])..']')
    end
  elseif type(fontfamily) == "string" then
    add('\\font[family='..escapeStringParam(fontfamily)..']')
  end
  local fontsize = type(metadata.sile) == "table" and metadata.sile['font-size']
  if fontsize then
    add('\\font[size='..escapeStringParam(fontsize)..']')
  end

  add(body)

  if metadata.title then
    add('\\pdf:metadata[key=Title, value="'..escapeStringParam(metadata.title)..'"]%')
  end
  if metadata.subject then
    add('\\pdf:metadata[key=Subject, value="'..escapeStringParam(metadata.subject)..'"]%')
  end
  if metadata.author then
    add('\\pdf:metadata[key=Author, value="'..escapeStringOrTableParam(metadata.author)..'"]%')
  end
  if metadata.keywords then
    add('\\pdf:metadata[key=Keywords, value="'..escapeStringOrTableParam(metadata.keywords)..'"]%')
  end
  add('\\end{document}')
  return table.concat(buffer,'\n') .. '\n'
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str (s)
  return escape(s)
end

function Space ()
  return " "
end

function SoftBreak ()
  return "\n"
end

function LineBreak ()
  return "\\cr\n"
end

function Emph (s)
  return "\\em{" .. s .. "}"
end

function Strong (s)
  return "\\font[weight=700]{" .. s .. "}"
end

function Subscript (s)
  return "\\textsubscript{" .. s .. "}"
end

function Superscript (s)
  return "\\textsuperscript{" .. s .. "}"
end

function SmallCaps (s)
  return "\\font[features=+smcp]{" .. s .. "}"
end

function Strikeout (s)
  return "\\strikethrough{" .. s .. "}"
end

function Link (s, src, tit, attr)
  if src:sub(1,1) == "#" then
    -- local hask link
    local dest = src:sub(2)
    return "\\pdf:link[dest=ref:".. dest .."]{".. s.."} (\\ref[marker="..src:sub(2).."]{})"
  end
  -- TODO
  -- If the URL is not external but a local file, what are we supposed to do?
  return "\\href[src=" .. src .. "]{" .. s .. "}"
end

function Image (s, src, tit, attr)
  local width, height = "",""
  if attr["width"] then
    width = ", width="..attr["width"]
  end
  if attr["height"] then
    width = ", height="..attr["height"]
  end
  if getFileExtension(src) == "svg" then
    return "\\svg[src=" .. src .. width .. height .."]"
  end
  return "\\img[src=" .. src .. width .. height .. "]"
end

function Code (s, attr)
  return "\\code{" .. escape(s) .. "}"
end

function InlineMath (s)
  return "NO SUPPORT YET (" .. escape(s) .. ")"
end

function DisplayMath (s)
  return "NO SUPPORT YET (" .. escape(s) .. ")"
end

function DoubleQuoted (s)
  return '“' .. s .. '”'
end

function Note (s)
  return "\\footnote{" .. s .. "}"
end

function Span (s, attr)
  local out = s

  if attr["lang"] then
    local cmd = "\\language[main="..normalizeLang(attr["lang"]).."]"
    out = cmd .."{"..out.."}"
  end
  if attr.class and string.match(' ' .. attr.class .. ' ',' underline ') then
    out = "\\underline{"..out.."}"
  end
  if attr["custom-style"] then
    out = "\\style:apply[name="..escapeStringParam(attr["custom-style"])..", discardable=true]{"
      .. out .. "}"
  end
  return out
end

function Cite (s, cs)
  local ids = {}
  for _ , cit in ipairs(cs) do
    -- HACK...
    -- Anyway this is a poor's man solution. At some stage, we'll want
    -- to use SILE's bibliography module, likely.
    local cit = (cit.citationId .. cit.citationSuffix):gsub("_"," ")
    table.insert(ids, cit)
  end
  return "(" .. table.concat(ids, '; ') .. ")" -- .. s
end

function Plain (s)
  return s
end

function Para (s)
  -- Nothing special to do:
  -- Normally SILE paragraphs are handled via the BlockSep, unless mistaken.
  return s
end

local h = {"chapter", "section", "subsection", "subsubsection"}
-- lev is an integer, the header level.
-- attrs come from {#identifier .class .class key=value key=value}
-- Pandoc also mentions the .unlisted class: if present in addition to unnumbered,
-- the heading will not be included in a table of contents. TODO ?
function Header (lev, s, attr)
  local opts = {}

  if attr.class and string.match(' ' .. attr.class .. ' ',' unnumbered ') then
    opts[#opts+1] = "numbering=false"
  end
  -- N.B. {-} is equivalent to .unnumbered, but Pandoc takes care of that.

  if attr.id then opts[#opts+1] = "marker="..attr.id end
  if lev <= #h then
    return "\\".. h[lev] .. "["..table.concat(opts,", ").."]{" .. s .. "}"
  end
  return "HEADER LEVEL "..lev.." NOT YET SUPPORTED"
  --- return "\\h" .. lev .. attributes(attr) ..  ">" .. s .. "</h" .. lev .. ">"
end

function BlockQuote (s)
  return "\\begin{blockquote}\n" .. s .. "\n\\end{blockquote}"
end

function HorizontalRule ()
  return "\\fullrule[raise=0.4em]"
end

function LineBlock (ls)
  local lines = {}
  for _, line in ipairs(ls) do
    -- Pandoc replaces the indentation spaces with U+00A0
    -- Let's be typographically sound and replace them with quad kerns...
    line = line:gsub("^[ ]+", function (match)
      return "\\kern[width="..utf8.len(match).."em]"
    end)
    lines[#lines + 1] = line .. "\\par" -- should it be \par or \cr... Oh well...
  end
  return table.concat(lines, '\n')
end

function CodeBlock (s, attr)
  return "\\begin[type=codehighlight, format=".. attr.class.."]{raw}\n" --
    .. s --.. escape(s) ..
    .. "\n\\end{raw}\n"
end

function BulletList (items)
  -- Pandoc User's Guide says it supports task lists, but it actually
  -- doesn't do anything specific and we have to check by ourselves
  -- Not all fonts have U+2610 BALLOT BOX and U+2612 BALLOT BOX WITH, though.
  local buffer = {}
  for _, item in ipairs(items) do
    local bullet = ""
    local bmark = item:sub(1, 4)
    if bmark == "[ ] " then
      bullet = "[bullet=☐]"
      item = item:sub(5)
    elseif bmark == "[x] " or bmark == "[X] " then
      bullet = "[bullet=☑]"
      item = item:sub(5)
    end
    table.insert(buffer, "\\item"..bullet.."{" .. item .. "}")
  end
  return "\\begin{itemize}\n" .. table.concat(buffer, "\n") .. "\n\\end{itemize}"
end

local listStyle = {
  -- DefaultStyle = no specified style
  Example = "arabic",
  Decimal = "arabic",
  UpperRoman = "Roman",
  LowerRoman = "roman",
  UpperAlpha = "Alpha",
  LowerAlpha = "alpha",
}

local listDelim = {
  -- DefaultDelim = no specified delimiter
  Example = "arabic",
  OneParen = { after = ")" },
  TwoParens = { before = "(", after = ")" },
  Period = { after = "." },
}

function OrderedList (items, start, numstyle, numdelim)
  -- N.B. start, numstyle, numdelim from haskell source (they weren't in the sample
  -- Lua custom writer):
  -- numstyle is one of DefaultStyle, Example, Decimal, UpperRoman, LowerRoman, UpperAlpha, LowerAlpha.
  -- numdelim is one of DefaultDelim, OneParen, TwoParens, Period
  -- for now we ignore them and let SILE's enumeration do their stuff. TODO
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, "\\item{" .. item .. "}")
  end
  local opts = {}
  if start then
    opts[#opts + 1] = "start="..start
  end
  local display = numstyle and listStyle[numstyle]
  if display then
    opts[#opts + 1] = "display="..display
  end
  local delimiters = numdelim and listDelim[numdelim]
  if delimiters then
    if delimiters.before then
      opts[#opts + 1] = "before="..delimiters.before
    end
    if delimiters.after then
      opts[#opts + 1] = "after="..delimiters.after
    end
  end
  opts = #opts and "["..table.concat(opts, ", ").."]" or ""
  return "\\begin"..opts.."{enumerate}\n" .. table.concat(buffer, "\n") .. "\n\\end{enumerate}"
end

function DefinitionList (items)
  local buffer = {}
  for _,item in pairs(items) do
    local k, v = next(item)
    -- Quick'n'dirty!! FIXME provide a better implementation
    table.insert(buffer, "\\font[weight=800]{" .. k .. "}")
    table.insert(buffer, "\\blockquote{" .. table.concat(v, "\\par") .. "}")
  end
  return table.concat(buffer, "\n")
end

-- Convert pandoc alignment to something we can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
local function cellAlign (align)
  if align == 'AlignLeft' then
    return 'left'
  elseif align == 'AlignRight' then
    return 'right'
  elseif align == 'AlignCenter' then
    return 'center'
  else
    return 'left'
  end
end

function CaptionedImage (src, tit, caption, attr)
  -- We don't use the "tit"...
  return "\\begin{figure}\n"
    .. Image(caption, src, tit, attr)
    .."\n"
    .. "\\caption{" .. escape(caption) .. "}\n\\end{figure}"
end

local function countCols (rows)
  local nCols = 0
  for _, row in ipairs(rows) do
    if #row > nCols then nCols = #row end
  end
  return nCols
end
-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table (caption, aligns, widths, headers, rows)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  local nCols = countCols(rows)

  -- I don't understand what Pandoc widths are, normalize them to 100%
  local cWidths = {}
  local totalWidth = 0
  for i = 1, nCols do
    totalWidth = totalWidth + (widths[i] and widths[i] ~= 0 and widths[i] or 1/nCols)
  end
  for i = 1, nCols do
    local w = (widths and widths[i] ~= 0 and widths[i] or 1/nCols)
    local wNorm = w / totalWidth
    cWidths[i] = string.format("%.0f%%lw", wNorm * 100)
  end

  if caption and caption ~= "" then
    add("\\begin{table}")
  else
  -- Hmm, should we center tables which are not captioned?
  -- The problem is more general, there are ways to put Markdown tables
  -- in blockquotes, or item lists, etc. and we do not handle them well
  -- whether captioned or not.
  --  add("\\begin{center}")
  end

  local header_row = {}
  local empty_header = true
  for i, h in ipairs(headers) do
     empty_header = empty_header and h == ""
  end
  local head = empty_header and "" or ", header=true"
  add('\\begin[cols='..table.concat(cWidths, " ")..head..']{ptable}')
  if not empty_header then
    add('\\begin[background=#eee]{row}')
    for i = 1, nCols do
      local cell = headers[i] or ''
      local align = ", halign="..cellAlign(aligns[i])
      add('\\cell[valign=middle'..align..']{'..cell..'}')
    end
    add('\\end{row}')
  end
  for _, row in ipairs(rows) do
    add('\\begin{row}')
    for i = 1, nCols do
      local cell = row[i] or ''
      local align = ", halign="..cellAlign(aligns[i])
      add('\\cell[valign=top'..align..']{'..cell..'}')
    end
    add('\\end{row}')
  end
  add('\\end{ptable}')

  if caption and caption ~= "" then
    add("\\caption{"..caption.."}")
    add("\\end{table}")
  else
   -- add("\\end{center}")
  end
  return table.concat(buffer,'\n')
end

function RawInline (format, str)
  local res
  if format == "sile" then
    res = str
  elseif format == "sile-lua" then
    res = "\\script{"..str.."}"
  else
    -- ignore unknown formats
   res = ''
  end
  return res
end

function RawBlock (format, str)
  return RawInline(format,str)
end

function Div (s, attr)
  local out = s
  if attr["lang"] then
    out = table.concat({
      "\\begin[main="..normalizeLang(attr["lang"]).."]{language}",
      out,
      "\\end{language}",
    }, "\n")
  end
  if attr["custom-style"] then
    out = table.concat({
      "\\begin[name="..escapeStringParam(attr["custom-style"])..", discardable=true]{style:apply:paragraph}",
      out,
      "\\end{style:apply:paragraph}",
    }, "\n")
  end
  return out
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index = function (_, key)
  io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
  return function() return "" end
end
setmetatable(_G, meta)
