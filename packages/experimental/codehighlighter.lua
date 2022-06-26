-- Real experimental
-- Quick and dirty
local highlighter = require('syntaxhighlight')

-- Some lame style.
local theme = {
  class = '#4c6acf',
  comment = '#848183',
  constant = '#69a8cd',
  embedded = '#3f709b',
  error = '#4c6acf',
  ['function'] = '#69a8cd',
  -- identifier
  keyword = '#a68775',
  label = '#69a8cd',
  number = '#dbc4af',
  operator = '#9d859b',
  preprocessor = '#98eef9',
  regex = '#dbc4af',
  string = '#6a9d8f',
  ['type'] = '#9d859b',
  variable = '#a68775',
}

local function highlight(format, text)
  local elems = highlighter.totable(format, text)
  if elems then
    for _, tok in ipairs(elems) do
      local c
      for _, class in ipairs(tok.classes) do
        if theme[class] then
          c = theme[class]
          break
        end
      end
      if c then
        SILE.call("color", { color = c }, { tok.text })
      else
        if tok.text:match("\n") then
          -- HACK seems a blank line will be skipped there.
          SILE.typesetter:leaveHmode()
        end
        SILE.typesetter:typeset(tok.text)
      end
    end
  else
    SU.warn("No code hightlighter for '"..format.."'")
    SILE.typesetter:typeset(text)
  end
end

SILE.require("packages/parbox")

SILE.registerRawHandler("codehighlight", function (options, content)
  SILE.call("par")
  SILE.call("parbox", { strut = "character", width = "90%lw", padding = "0 0 7pt 0", border = "0 0 2pt 0", bordercolor = "220" }, function ()
    SILE.settings.temporarily(function()
      SILE.settings.set("typesetter.parseppattern", "\r?\n")
      SILE.settings.set("typesetter.obeyspaces", true)
      SILE.settings.set("document.rskip", SILE.nodefactory.hfillglue())
      SILE.settings.set("document.parindent", SILE.nodefactory.glue())
      SILE.settings.set("document.baselineskip", SILE.nodefactory.vglue())
      SILE.settings.set("document.lineskip", SILE.nodefactory.vglue("0.7ex"))
      SILE.call("verbatim:font")
      SILE.settings.set("document.spaceskip", SILE.length("1spc"))
      SILE.settings.set("shaper.variablespaces", false)
      --SILE.settings.set("document.language", "und") -- Nah, allow linebreaks for now...

      highlight(options.format, content[1])
      SILE.typesetter:leaveHmode()
    end)
  end)
  SILE.call("smallskip")
end)
