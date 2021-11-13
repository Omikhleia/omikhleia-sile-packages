--
-- A style package for SILE
-- 2021, Didier Willis
-- License: MIT
--
SILE.scratch.styles = {
  -- Actual style specifications will go there (see defineStyle etc.)
  specs = {},
  -- Known aligns options, with the command implementing them.
  -- You can register extra options there.
  alignments = {
    center = "center",
    left = "raggedright",
    right = "raggedleft",
    -- be friendly with users...
    raggedright = "raggedright",
    raggedleft = "raggedleft",
  },
  -- Known skip options.
  -- You can add register skips there.
  skips = {
    smallskip = SILE.settings.get("plain.smallskipamount"),
    medskip = SILE.settings.get("plain.medskipamount"),
    bigskip = SILE.settings.get("plain.bigskipamount"),
  },
}

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
  if options.inherit and SILE.scratch.styles.specs[options.inherit] == nil then
    -- Should we really complain if inherited doesn't exist (yet)?
    -- (Well it avoids some obvious risks of cycle...)
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

local styleForSkip = function (skip, vbreak)
  local b = SU.boolean(vbreak, true)
  if skip then
    local vglue = SILE.scratch.styles.skips[skip] or SU.cast("vglue", skip)
    if not b then SILE.call("novbreak") end
    SILE.typesetter:pushExplicitVglue(vglue)
  end
  if not b then SILE.call("novbreak") end
end

local styleForAlignment = function (style, content, ba)
  if style.paragraph and style.paragraph.align then
    if style.paragraph.align and style.paragraph.align ~= "justify" then
      local alignCommand = SILE.scratch.styles.alignments[style.paragraph.align]
      if not alignCommand then
        SU.error("Invalid paragraph style alignment '"..style.paragraph.align.."'")
      end
      if not ba then SILE.call("novbreak") end
      SILE.typesetter:leaveHmode()
      -- Here we must apply the font, then the alignement, so that line heights are
      -- correct even on the last paragraph. But the color introduces hboxes so
      -- must be applied last, no to cause havoc with the noindent/indent and
      -- centering etc. environments
      if style.font then
        SILE.call("style:font", style.font, function ()
          SILE.call(alignCommand, {}, function ()
            styleForColor(style, content)
          end)
        end)
      else
        SILE.call(alignCommand, {}, function ()
          styleForColor(style, content)
        end)
      end
    else
      styleForFont(style, content)
      if not ba then SILE.call("novbreak") end
      SILE.call("par")
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
    SILE.call("par")
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
  SU.required(options, "name", "redefining style")

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
\include[src=packages/styles-doc.sil]
\end{document}]]
}

