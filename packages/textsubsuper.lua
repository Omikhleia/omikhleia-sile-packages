--
-- Text superscript and subscript package for SILE
-- 2021, Didier Willis
-- Derived from the idea sketched by Simon Cozens
-- in https://github.com/sile-typesetter/sile/issues/1258
-- License: MIT
--

local textFeatCache = {}

local _key = function (options, text)
  return table.concat({
      text,
      options.family,
      ("%d"):format(options.weight),
      options.style,
      options.variant,
      options.features,
      options.filename,
    }, ";")
end

local textFeatCaching = function (options, text, status)
  local key = _key(options, text)
  if textFeatCache[key] == nil then
    textFeatCache[key] = status
  end
  return status
end

local checkFontFeatures = function (features, content)
  local text = SU.contentToString(content)
  if tonumber(text) ~= nil then
    -- Avoid caching any sequence of digits. Plus, we want
    -- consistency here.
    text="0123456789"
  end
  local fontOptions = SILE.font.loadDefaults({ features = features })
  local supported = textFeatCache[_key(fontOptions, text)]
  if supported ~= nil then
    return supported
  end

  local items1 = SILE.shaper:shapeToken(text, fontOptions)
  local items2 = SILE.shaper:shapeToken(text, SILE.font.loadDefaults({}))

  -- Don't mix up characters supporting the features with those
  -- not supporting them, as it would be ugly in most cases.
  if #items1 ~= #items2 then
    return textFeatCaching(fontOptions, text, false)
  end
  for i = 1, #items1 do
    if items1[i].width == items2[i].width and items1[i].height == items2[i].height then
      return textFeatCaching(fontOptions, text, false)
    end
  end
  return textFeatCaching(fontOptions, text, true)
end

local scriptSubOffset = "0.33ex"
local scriptSupOffset = "0.77ex"
local scriptSize = "1.414ex"

SILE.registerCommand("text:superscript", function (options, content)
  if type(content) ~= "table" then SU.error("Expected a table content in text:superscript") end
  if checkFontFeatures("+sups", content) then
    SILE.call("font", { features="+sups" }, content)
  else
    SU.warn("No true superscripts for '"..SU.contentToString(content).."', fallback to scaling")
    SILE.require("packages/raiselower")
    SILE.call("raise", { height = scriptSupOffset }, function ()
      SILE.call("font", { size = scriptSize }, content)
    end)
  end
end, "Typeset in superscript.")

SILE.registerCommand("text:subscript", function (options, content)
  if type(content) ~= "table" then SU.error("Expected a table content in text:subscript") end
  if checkFontFeatures("+subs", content) then
    SILE.call("font", { features="+subs" }, content)
  elseif checkFontFeatures("+sinf", content) then
    SU.warn("No true subscripts for '"..SU.contentToString(content).."', fallback to scientific inferiors")
    SILE.call("font", { features="+sinf" }, content)
  else
    SU.warn("No true subscripts for '"..SU.contentToString(content).."', fallback to scaling")
    SILE.require("packages/raiselower")
    SILE.call("lower", { height = scriptSubOffset}, function ()
      SILE.call("font", { size = scriptSize }, content)
    end)
  end
end, "Typeset in subscript.")

return {
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]

The \doc:keyword{textsubsuper} package provides two commands, \doc:code{\\text:superscript\{\doc:args{content}\}}
and \doc:code{\\text:subscript\{\doc:args{content}\}}.

They will use the native superscript or subscript characters, respectively, in a font, when available, instead of
scaling, raising or lowering characters, because most of the time the former will obviously look much better.

As of superscripts, that could for a number (e.g. in footnote calls), but also for letters (e.g. in century references in French,
\font[features=+smcp]{iv}\text:superscript{e}; or likewise in sequences in English, 12\text:superscript{th}).

As of subscripts, the most familiar example is in chemical formulas, for example
H\text:subscript{2}O or C\text:subscript{6}H\text:subscript{12}O\text:subscript{6}.

These commands do so by trying the \doc:code{+sups} font feature for superscripts, and the \doc:code{+subs}
or \doc:code{+sinf} feature for subscripts.

If the output is not different than \em{without} the feature, it implies that this OpenType feature is not
supported by the font (such as the default Gentium Plus font, that does not have these font
features\footnote{Though it does include, however, some of the Unicode super- and subscript characters,
but this very package does not try to address such a case.}): Scaling and raising or lowering is then applied.

By nature, this package is \em{not} intended to work with multiple levels of super- or subscripts.
Also note that it tries not to mix up characters supporting the features with those
not supporting them, as it would be somewhat ugly in most cases, so the scaling methods will
be applied if such a case occurs.

\end{document}]]
}

