--
-- A style package for SILE
-- 2021, Didier Willis
-- License: MIT
--
-- NOT YET.... NO SURE IT IS THAT USEFUL
-- \pagestyle
--   pagesize?
--   orientation?
--   margins x 4?
--   folo numbering i.e. 1,2,3, i,ii,ii, A, B, C etc.
--   color (nore, color, gradient, weird stuff) or image?
--   header
        -- on off
        -- same left right
        -- same first page
        -- margins (left, right)
        -- spacing = rather where is that box
--   footer
--      same stuf
--   border ...
--   columns ??
--   footnote configuration?

SILE.scratch.styles = {}

local function shallowcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
  else
    copy = orig
  end
  return copy
end

SILE.registerCommand("style:font", function (options, content)
  local size = tonumber(options.size)
  local opts = shallowcopy(options)
  if size then
    opts.size = SILE.settings.get("font.size") + size
  end

  SILE.call("font", opts, content)
end, "Applies a font, with additional support for relative sizes.")


SILE.registerCommand("style:define", function (options, content)
  local name = SU.required(options, "name", "style:define")
  if options.inherit and SILE.scratch.styles[options.inherit] == nil then
    -- Should we really complain if inherited doesn't exist (yet)?
    -- (Well it avoids some obvious risks of cycle...)
    SU.error("Unknown inherited named style '" .. options.inherit .. "'.")
  end
  if options.inherit and options.inherit == options.name then
    SU.error("Named style '" .. options.name .. "' cannot inherit itself.")
  end
  SILE.scratch.styles[name] = { inherit = options.inherit, style = {} }
  for i=1, #content do
    if type(content[i]) == "table" and content[i].command then
        SILE.scratch.styles[name].style[content[i].command] = content[i].options
    end
  end
end, "Defines a named style.")

-- Very naive cascading for now...
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

local knownSkips = {
  smallskip = SILE.settings.get("plain.smallskipamount"),
  medskip = SILE.settings.get("plain.medskipamount"),
  bigskip = SILE.settings.get("plain.bigskipamount"),
}
local styleForParagraph = function (skip, vbreak)
  local b = SU.boolean(vbreak, true)
  if not b then SILE.call("novbreak") end
  SILE.typesetter:leaveHmode()
  if skip then
    local vglue = knownSkips[skip] or SU.cast("vglue", skip)
    if not b then SILE.call("novbreak") end
    SILE.typesetter:pushExplicitVglue(vglue)
  end
  if not b then SILE.call("novbreak") end
end

local knownAligns = {
  center = "center",
  left = "raggedright",
  right = "raggedleft",
  -- be friendly with users...
  raggedright = "raggedright",
  raggedleft = "raggedleft"
}

local styleForAlignment = function (style, content)
  if style.paragraph and style.paragraph.align and style.paragraph.align ~= "justify" then
    local alignCommand = knownAligns[style.paragraph.align]
    if not alignCommand then
      SU.error("Invalid paragraph style alignment '"..style.paragraph.align.."'")
    end
    SILE.call(alignCommand, {}, function ()
      styleForFont(style, content)
    end)
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
  local stylespec = SILE.scratch.styles[name]
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
  local stylespec = SILE.scratch.styles[name]
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

-- Undocumented and reserved for casual testing.
-- SILE.registerCommand("style:apply:before", function (options, _)
--   local name = SU.required(options, "name", "style:apply:before")
--   local styledef = resolveStyle(name)
--   local parSty = styledef.paragraph

--   if parSty then
--     if parSty.skipbefore and #SILE.typesetter.state.outputQueue == 0 then
--       -- FIXME: If we are at a top a page, how to make sure the vskip
--       -- is honored? Without inserting an empty hbox that would cause
--       -- a mess with regular sections etc.
--       -- Is this the proper way?
--       SILE.typesetter:initline()
--     end
--     styleForParagraph(parSty.skipbefore, parSty.breakbefore)
--     if SU.boolean(parSty.indentbefore, true) then
--       SILE.call("indent")
--     else
--       SILE.call("noindent")
--     end
--   end
-- end, "Applies the paragraph-before style - undocumented.")

-- SILE.registerCommand("style:apply:after", function (options, _)
--   local name = SU.required(options, "name", "style:apply:after")
--   local styledef = resolveStyle(name)
--   local parSty = styledef.paragraph

--   if parSty then
--     styleForParagraph(parSty.skipafter, parSty.breakafter)
--     if SU.boolean(parSty.indentafter, true) then
--       SILE.call("indent")
--     else
--       SILE.call("noindent")
--     end
--   end
-- end, "Applies the paragraph-after style - undocumented.")

SILE.registerCommand("style:apply:paragraph", function (options, content)
  local name = SU.required(options, "name", "style:apply:paragraph")
  local styledef = resolveStyle(name)
  local parSty = styledef.paragraph

  if parSty then
    if parSty.skipbefore and #SILE.typesetter.state.outputQueue == 0 then
      -- FIXME: If we are at a top a page, how to make sure the vskip
      -- is honored? Without inserting an empty hbox that would cause
      -- a mess with regular sections etc.?
      -- Is this the proper way?
      SILE.typesetter:initline()
    end
    styleForParagraph(parSty.skipbefore, parSty.breakbefore)
    if SU.boolean(parSty.indentbefore, true) then
      SILE.call("indent")
    else
      SILE.call("noindent")
    end
  end

  styleForAlignment(styledef, content)

  if parSty then
    styleForParagraph(parSty.skipafter, parSty.breakafter)
    if SU.boolean(parSty.indentafter, true) then
      SILE.call("indent")
    else
      SILE.call("noindent")
    end
  end
end, "Applies the paragraph style entirely.")

-- STYLE REDEFINITION

SILE.registerCommand("style:redefine", function (options, content)
  SU.required(options, "name", "redefining style")

  if options.as then
    if options.as == options.name then
      SU.error("Style '" .. options.name .. "' should not be redefined as itself.")
    end

    -- Case: \style:redefine[name=style-name, as=saved-style-name]
    if SILE.scratch.styles[options.as] ~= nil then
      SU.error("Style '" .. options.as .. "' would be overwritten.") -- Let's forbid it for now.
    end
    local sty = SILE.scratch.styles[options.name]
    if sty == nil then
      SU.error("Style '" .. options.name .. "' does not exist!")
    end
    SILE.scratch.styles[options.as] = sty

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
    local sty = SILE.scratch.styles[options.from]
    if sty == nil then
      SU.error("Style '" .. option.from .. "' does not exist!")
    end
    SILE.scratch.styles[options.name] = sty
    SILE.scratch.styles[options.from] = nil
  else
    SU.error("Style redefinition needs a 'as' or 'from' parameter.")
  end
end, "Redefines a style saving the old version with another name, or restores it.")

return {
  exports = {
    -- programmatically define a style
    defineStyle = function(name, opts, styledef)
      SILE.scratch.styles[name] = { inherit = opts.inherit, style = styledef }
    end,
    -- resolve a style (incl. inherited fields)
    resolveStyle = resolveStyle,
    -- human-readable specification for debug (text)
    dumpStyle = dumpStyle
  },
  documentation = [[\begin{document}
\include[src=packages/styles-doc.sil]
\end{document}]]
}

