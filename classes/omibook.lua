--
-- A new book class for SILE
-- 2021, Didier Willis
-- License: MIT
--
local plain = SILE.require("plain", "classes")
local omibook = plain { id = "omibook" }

local counters = SILE.require("packages/counters").exports

local styles = SILE.require("packages/styles").exports

-- sectioning styles
-- We extend style specifications with a sectioning section:
--   \sectioning[counters=<name>, level=<N>, display=<display>, open=<odd,any,unset>, header="odd,even,both,none", numberstyle]
styles.defineStyle("sectioning:base", {}, {
  paragraph = { indentbefore = false, indentafter = false }
})
styles.defineStyle("sectioning:part", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+6" },
  paragraph = { skipbefore = "3cm", align = "center", skipafter = "bigskip" },
  sectioning = { counter = "parts", level = 0, display = "ROMAN", open = "odd", numberstyle="sectioning:part:number" },
})
styles.defineStyle("sectioning:chapter", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+4" },
  paragraph = { skipafter = "bigskip" },
  sectioning = { counter = "sections", level = 1, display = "arabic", open = "odd", header="odd", numberstyle="sectioning:chapter:number" },
})
styles.defineStyle("sectioning:section", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+2" },
  paragraph = { skipbefore = "bigskip", skipafter = "bigskip", breakafter = false },
  sectioning = { counter = "sections", level = 2, display = "arabic", header="even", numberstyle="sectioning:other:number" },
})
styles.defineStyle("sectioning:subsection", { inherit = "sectioning:base"}, {
  font = { weight = 800, size = "+1" },
  paragraph = { skipbefore = "medskip", skipafter = "medskip", breakafter = false },
  sectioning = { counter = "sections", level = 3, display = "arabic", numberstyle="sectioning:other:number" },
})
styles.defineStyle("sectioning:subsubsection", { inherit = "sectioning:base" }, {
  font = { weight = 800 },
  paragraph = { skipbefore = "smallskip", skipbefore = "smallskip"; breakafter = false },
  sectioning = { counter = "sections", level = 4, display = "arabic", numberstyle="sectioning:other:number" },
})

styles.defineStyle("sectioning:part:number", {}, {
  font = { features = "+smcp" },
  label = { pre = "Part " },
  paragraph = { skipafter = "medskip", indentbefore = false, indentafter = false },
})
styles.defineStyle("sectioning:chapter:number", {}, {
  label = { pre = "Chapter ", post = "." },
  paragraph = { skipafter = "smallskip", indentbefore = false, indentafter = false },
})
styles.defineStyle("sectioning:other:number", {}, {
  label = { post = ". " }
})

-- folio styles
styles.defineStyle("folio:base", {}, {
  font = { size = "-0.5" }
})
styles.defineStyle("folio:even", { inherit = "folio:base" }, {
})
styles.defineStyle("folio:odd", { inherit = "folio:base" }, {
  paragraph = { align = "right" }
})
-- header styles
styles.defineStyle("header:base", {}, {
  font = { size = "-1" }
})
styles.defineStyle("header:even", { inherit = "header:base" }, {
})
styles.defineStyle("header:odd", { inherit = "header:base" }, {
  font = { style = "italic" },
  paragraph = { align = "right" }
})

omibook.defaultFrameset = {
  content = {
    left = "10%pw", -- was 8.3%pw
    right = "87.7%pw", -- was 86%pw
    top = "11.6%ph",
    bottom = "top(footnotes)"
  },
  folio = {
    left = "left(content)",
    right = "right(content)",
    top = "bottom(footnotes)+3%ph",
    bottom = "bottom(footnotes)+5%ph"
  },
  header = {
    left = "left(content)",
    right = "right(content)",
    top = "top(content)-5%ph", -- was -8%ph
    bottom = "top(content)-2%ph" -- was -3%ph
  },
  footnotes = {
    left = "left(content)",
    right = "right(content)",
    height = "0",
    bottom = "86.3%ph" -- was 83.3%ph
  }
}

function omibook:init ()
  self:loadPackage("masters")
  self:defineMaster({
      id = "right",
      firstContentFrame = self.firstContentFrame,
      frames = self.defaultFrameset
    })
  self:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })
  self:mirrorMaster("right", "left")
  self:loadPackage("omitableofcontents")
  if not SILE.scratch.headers then SILE.scratch.headers = {} end
  self:loadPackage("omifootnotes", {
    insertInto = "footnotes",
    stealFrom = { "content" }
  })

  self:loadPackage("omirefs")
  self:loadPackage("omiheaders")

  -- override the standard foliostyle to rely on styles
  self:loadPackage("folio")
  SILE.registerCommand("foliostyle", function (_, content)
    SILE.call("noindent")
    if SILE.documentState.documentClass:oddPage() then
      SILE.call("style:apply:paragraph", { name = "folio:odd"}, content)
    else
      SILE.call("style:apply:paragraph", { name = "folio:even"}, content)
    end
  end)

  -- override document.parindent default
  SILE.settings.set("document.parindent", "1.25em")

  return plain.init(self)
end

omibook.newPage = function (self)
  self:switchPage()
  self:newPageInfo()
  return plain.newPage(self)
end

omibook.finish = function (self)
  local ret = plain.finish(self)
  self:writeToc()
  self:writeRefs()
  return ret
end

omibook.endPage = function (self)
  self:moveTocNodes()
  self:moveRefs()
  local headerContent = (self:oddPage() and SILE.scratch.headers.odd)
        or (not(self:oddPage()) and SILE.scratch.headers.even)
  if headerContent then
    self:outputHeader(headerContent)
  end
  return plain.endPage(self)
end

SILE.registerCommand("even-running-header", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.even = function () closure(content) end
end, "Text to appear on the top of the left page")

SILE.registerCommand("odd-running-header", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.odd = function () closure(content) end
end, "Text to appear on the top of the right page")

SILE.registerCommand("xxx:sectioning", function (options, content)
  local level = SU.cast("integer", SU.required(options, "level", "sectioning:sectioning"))
  local counter = SU.required(options, "counter", "sectioning:sectioning")
  local display = options.display or "arabic"
  local toclevel = level -- HACK level 0 stuff. Probably a bad design
  if level == 0 then level = 1 end 

  local number
  if SU.boolean(options.numbering, true) then
    SILE.call("increment-multilevel-counter", { id = counter, level = level, display = display })
    number = SILE.formatMultilevelCounter(counters.getMultilevelCounter(counter), { noleadingzero = true })
  end
  if SU.boolean(options.toc, true) then
    SILE.call("tocentry", { level = toclevel, number = number }, SU.subContent(content))
  end
  local lang = SILE.settings.get("document.language")
  if SU.boolean(options.numbering, true) then
    -- if options.prenumber then
    --   if SILE.Commands[options.prenumber .. ":"  .. lang] then
    --     options.prenumber = options.prenumber .. ":" .. lang
    --   end
    --   SILE.call(options.prenumber)
    -- end
    if options.numberstyle then
      local numSty = styles.resolveStyle(options.numberstyle)
      local pre = numSty.label and numSty.label.pre
      local post = numSty.label and numSty.label.post or " "
      SILE.call("style:apply:paragraph", { name = options.numberstyle }, function ()
        if pre then SILE.typesetter:typeset(pre) end
        SILE.call("show-multilevel-counter", { id = counter, noleadingzero = true })
        if post then SILE.typesetter:typeset(post) end
      end)
    else
      SILE.call("show-multilevel-counter", { id = counter, noleadingzero = true })
      SILE.typesetter:typeset(" ")
    end
  end
end)

omibook.registerCommands = function (_)
  plain.registerCommands()
end

SILE.registerCommand("omibook-double-page", function (_, _)
  -- NOTE: We do not use the "open-double-page" from the two side
  -- package as it has doesn't have the nice logic we have here:
  --  - check we are not already at the top of a page
  --  - disable neither and folio on blank even page
  -- I really had hard times to make this work correctly. It now
  -- seems ok, but it might be fragile.
  SILE.typesetter:leaveHmode() -- Important, flushes output queue.
  if #SILE.typesetter.state.outputQueue ~= 0 then
    -- We are not at the top of a page, eject the current content.
    SILE.call("supereject")
  end
  SILE.typesetter:leaveHmode() -- Important again...
  -- ... so now we are at the top of a page, and only need
  -- to add a blank page if we are not on an odd page.
  if not SILE.documentState.documentClass:oddPage() then
    SILE.typesetter:typeset("")
    SILE.typesetter:leaveHmode()
    SILE.call("nofoliosthispage")
    SILE.call("noheaderthispage")
    SILE.call("supereject")
  end
  SILE.typesetter:leaveHmode() -- and again!
end, "Open a double page without header and folio")

SILE.registerCommand("omibook-single-page", function (_, _)
  if SILE.scratch.counters.folio.value > 1 then
    SILE.typesetter:leaveHmode()
    SILE.call("supereject")
  end
  SILE.typesetter:leaveHmode()
end, "Open a single page")

local resolveSectionStyleDef = function (name)
  local stylespec = styles.resolveStyle(name)

  if stylespec.sectioning then
    return {
      counter = stylespec.sectioning.counter or
        SU.error("Sectioning style '"..name.."' must have a counter"),
      display = stylespec.sectioning.display or "arabic",
      level = stylespec.sectioning.level or 1,
      open = stylespec.sectioning.open, -- nil = do not open a page
      numberstyle = stylespec.sectioning.numberstyle,
      goodbreak = stylespec.sectioning.goodbreak,
    }
  end

  SU.error("Style '"..name.."' is not a sectioning style")
end

SILE.registerCommand("sectioning:enter", function (options, content)
  local name = SU.required(options, "name", "sectioning:enter")
  local secStyle = resolveSectionStyleDef(name)
  if secStyle.open and secStyle.open ~= "unset" then
    -- Sectioning style that causes a page break.
    if secStyle.open == "odd" then
      SILE.call("omibook-double-page")
    else
      SILE.call("omibook-single-page")
    end
  else
    -- Sectioning style that doesn't cause a page break.
    -- Always good to allow a page break before it, though.
    SILE.typesetter:leaveHmode()
    if SU.boolean(secStyle.goodbreak, true) then
      SILE.call("goodbreak")
    end
  end
  return secStyle
end, "Enter a sectioning command = honor the <open> specification if defined, and return the substyle definition")

SILE.registerCommand("part", function (options, content)
  local secStyle = SILE.call("sectioning:enter", { name = "sectioning:part" })

  SILE.call("noheaders")
  SILE.call("nofolios")
  SILE.scratch.headers.odd = nil
  SILE.scratch.headers.even = nil

  SILE.call("set-counter", { id = "footnote", value = 1 })
  SILE.call("set-multilevel-counter", { id = "sections", level = 1, value = 0 })
    
  SILE.call("style:apply:paragraph", { name= "sectioning:part" }, function ()
    SILE.call("xxx:sectioning", {
      counter = secStyle.counter,
      display = secStyle.display,
      level = secStyle.level,
      numberstyle = secStyle.numberstyle, 
      numbering = options.numbering,
      toc = options.toc,
    }, content)
    SILE.process(content)
  end)
end, "Begin a new part")

SILE.registerCommand("chapter", function (options, content)
  local secStyle = SILE.call("sectioning:enter", { name = "sectioning:chapter" })

  -- The chapter pages have no header, and reset the footnote counter.
  SILE.call("noheaderthispage")
  SILE.call("set-counter", { id = "footnote", value = 1 })

  SILE.call("style:apply:paragraph", { name= "sectioning:chapter" }, function ()
    SILE.call("xxx:sectioning", {
      counter = secStyle.counter,
      display = secStyle.display,
      level = secStyle.level,
      numberstyle = secStyle.numberstyle, 
      numbering = options.numbering,
      toc = options.toc,
    }, content)
    SILE.process(content)
  end)
  SILE.call("even-running-header", {}, function ()
    SILE.call("style:apply:paragraph", { name = "header:even" }, content)
  end)
  SILE.typesetter:inhibitLeading()
end, "Begin a new chapter")

SILE.registerCommand("rawsection", function (options, content)
  local styleName = SU.required(options, "style", "rawsection")
  local secStyle = SILE.call("sectioning:enter", { name = styleName })

  SILE.call("style:apply:paragraph", { name = styleName }, function ()
    SILE.call("xxx:sectioning", {
      counter = secStyle.counter,
      display = secStyle.display,
      level = secStyle.level,
      numberstyle = secStyle.numberstyle, 
      numbering = options.numbering,
      toc = options.toc,
    }, content)
    SILE.process(content)
  end)
  SILE.typesetter:inhibitLeading()
end, "Begin a new simple raw section identified by its <style>")

SILE.registerCommand("section", function (options, content)
  local secStyle = SILE.call("sectioning:enter", { name = "sectioning:section" })

  SILE.call("style:apply:paragraph", { name = "sectioning:section"}, function ()
    SILE.call("xxx:sectioning", {
      counter = secStyle.counter,
      display = secStyle.display,
      level = secStyle.level,
      numberstyle = secStyle.numberstyle, 
      numbering = options.numbering,
      toc = options.toc,
    }, content)
    SILE.process(content)
  end)
  SILE.call("odd-running-header", {}, function ()
    SILE.call("style:apply:paragraph", { name = "header:odd" }, function()
      if SU.boolean(options.numbering, true) then
        SILE.call("show-multilevel-counter", { id = secStyle.counter, level = 2, noleadingzero = true })
        SILE.typesetter:typeset(" ")
      end
      SILE.process(content)
    end)
  end)
  SILE.typesetter:inhibitLeading()
end, "Begin a new section")

SILE.registerCommand("subsection", function (options, content)
  options.style = "sectioning:subsection"
  SILE.call("rawsection", options, content)
end, "Begin a new subsection")

SILE.registerCommand("subsubsection", function (options, content)
  options.style = "sectioning:subsubsection"
  SILE.call("rawsection", options, content)
end, "Begin a new subsubsection")

-- BEGIN TEMPORARY
-- This should go in the core SILE distribution once enough tested...

SILE.formatMultilevelCounter = function (counter, options)
  local maxlevel = options and options.level and SU.min(options.level, #counter.value) or #counter.value
  local minlevel = 1
  local out = {}
  if options and SU.boolean(options.noleadingzero, true) then
    -- skip leading zeros
    while counter.value[minlevel] == 0 do minlevel = minlevel + 1 end
  end
  for x = minlevel, maxlevel do
    out[x - minlevel + 1] = SILE.formatCounter({ display = counter.display[x], value = counter.value[x] })
  end
  return table.concat(out, ".")
end

local function getMultilevelCounter(id)
  local counter = SILE.scratch.counters[id]
  if not counter then
    counter = { value= { 0 }, display= { "arabic" }, format = SILE.formatMultilevelCounter }
    SILE.scratch.counters[id] = counter
  end
  return counter
end

SILE.registerCommand("set-multilevel-counter", function (options, _)
  local value = SU.cast("integer", SU.required(options, "value", "set-multilevel-counter"))
  local level = SU.cast("integer", SU.required(options, "level", "set-multilevel-counter"))

  local counter = getMultilevelCounter(options.id)
  local currentLevel = #counter.value

  if level == currentLevel then
    -- e.g. set to x the level 3 of 1.2.3 => 1.2.x
    counter.value[level] = value
  elseif level > currentLevel then
    -- Fill all missing levels in-between
    -- e.g. set to x the level 3 of 1 = 1.0...
    while level - 1 > currentLevel do -- e.g.  
      currentLevel = currentLevel + 1
      counter.value[currentLevel] = 0
      counter.display[currentLevel] = counter.display[currentLevel - 1]
    end
    -- ... and the 1.0.x with default display (in case the option below is absent)
    currentLevel = currentLevel + 1
    counter.value[level] = value
    counter.display[level] = counter.display[currentLevel - 1]
  else -- level < currentLevel
    counter.value[level] = value
    -- Reset all greater levels
    -- e.g. set to x the level 2 of 1.2.3 => 1.x
    while currentLevel > level do
      counter.value[currentLevel] = nil
      counter.display[currentLevel] = nil
      currentLevel = currentLevel - 1
    end
  end
  if options.display then counter.display[currentLevel] = options.display end
end, "Sets the counter named by the <id> option to <value>; sets its display type (roman/Roman/arabic) to type <display>.")


SILE.registerCommand("increment-multilevel-counter", function (options, _)
  local counter = getMultilevelCounter(options.id)
  local currentLevel = #counter.value
  local level = tonumber(options.level) or currentLevel
  if level == currentLevel then
    counter.value[level] = counter.value[level] + 1
  elseif level > currentLevel then
    while level > currentLevel do
      currentLevel = currentLevel + 1
      counter.value[currentLevel] = (options.reset == false) and counter.value[currentLevel -1 ] or 1
      counter.display[currentLevel] = counter.display[currentLevel - 1]
    end
  else -- level < currentLevel
    counter.value[level] = counter.value[level] + 1
    while currentLevel > level do
      if not (options.reset == false) then counter.value[currentLevel] = nil end
      counter.display[currentLevel] = nil
      currentLevel = currentLevel - 1
    end
  end
  if options.display then counter.display[currentLevel] = options.display end
end, "Increments the value of the multilevel counter <id> at the given <level> or the current level.")

SILE.registerCommand("show-multilevel-counter", function (options, _)
  local counter = getMultilevelCounter(options.id)

  SILE.typesetter:typeset(SILE.formatMultilevelCounter(counter, options))
end, "Outputs the value of the multilevel counter <id>.")

-- END TEMPORARY

return omibook
