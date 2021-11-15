--
-- A new book class for SILE
-- 2021, Didier Willis
-- License: MIT
--
local plain = SILE.require("plain", "classes")
local omibook = plain { id = "omibook" }

local styles = SILE.require("packages/styles").exports
SILE.require("packages/sectioning")

-- Sectioning styles

styles.defineStyle("sectioning:base", {}, {
  paragraph = { indentbefore = false, indentafter = false }
})
styles.defineStyle("sectioning:part", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+6" },
  paragraph = { skipbefore = "15%fh", align = "center", skipafter = "bigskip" },
  sectioning = { counter = "parts", level = 1, display = "ROMAN",
                 toclevel = 0,
                 open = "odd", numberstyle="sectioning:part:number",
                 hook = "sectioning:part:hook" },
})
styles.defineStyle("sectioning:chapter", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+4" },
  paragraph = { skipafter = "bigskip", align = "left" },
  sectioning = { counter = "sections", level = 1, display = "arabic",
                 toclevel = 1,
                 open = "odd", numberstyle="sectioning:chapter:number",
                 hook = "sectioning:chapter:hook" },
})
styles.defineStyle("sectioning:section", { inherit = "sectioning:base" }, {
  font = { weight = 800, size = "+2" },
  paragraph = { skipbefore = "bigskip", skipafter = "medskip", breakafter = false },
  sectioning = { counter = "sections", level = 2, display = "arabic",
                 toclevel = 2,
                 numberstyle="sectioning:other:number",
                 hook = "sectioning:section:hook" },
})
styles.defineStyle("sectioning:subsection", { inherit = "sectioning:base"}, {
  font = { weight = 800, size = "+1" },
  paragraph = { skipbefore = "medskip", skipafter = "medskip", breakafter = false },
  sectioning = { counter = "sections", level = 3, display = "arabic",
                 toclevel = 3,
                 numberstyle="sectioning:other:number" },
})
styles.defineStyle("sectioning:subsubsection", { inherit = "sectioning:base" }, {
  font = { weight = 800 },
  paragraph = { skipbefore = "smallskip", skipbefore = "smallskip"; breakafter = false },
  sectioning = { counter = "sections", level = 4, display = "arabic",
                 toclevel = 4,
                 numberstyle="sectioning:other:number" },
})

styles.defineStyle("sectioning:part:number", {}, {
  font = { features = "+smcp" },
  numbering = { before = "Part ", standalone = true },
})
styles.defineStyle("sectioning:chapter:number", {}, {
  font = { size = "-1" },
  numbering = { before = "Chapter ", after = ".", standalone = true },
})
styles.defineStyle("sectioning:other:number", {}, {
  numbering = { after = "." }
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
  font = { size = "-1" },
  paragraph = { indentbefore = false, indentafter = false }
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
  SILE.scratch.headers.even = function ()
    closure(function ()
      SILE.call("style:apply:paragraph", { name = "header:even" }, content)
    end)
  end
end, "Text to appear on the top of the left page")

SILE.registerCommand("odd-running-header", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.odd = function ()
    closure(function ()
      SILE.call("style:apply:paragraph", { name = "header:odd" }, content)
    end)
  end
end, "Text to appear on the top of the right page")

omibook.registerCommands = function (_)
  plain.registerCommands()
end

SILE.registerCommand("sectioning:part:hook", function (options, content)
  -- Parts cancel headers and folios
  SILE.call("noheaderthispage")
  SILE.call("nofoliosthispage")
  SILE.scratch.headers.odd = nil
  SILE.scratch.headers.even = nil

  -- Parts reset footnotes and chapters
  SILE.call("set-counter", { id = "footnote", value = 1 })
  SILE.call("set-multilevel-counter", { id = "sections", level = 1, value = 0 })
end, "Applies part hooks (counter resets, footers and headers, etc.)")

SILE.registerCommand("sectioning:chapter:hook", function (options, content)
  -- Chapters re-enable folios, have no header, and reset the footnote counter.
  SILE.call("noheaderthispage")
  SILE.call("folios")
  SILE.call("set-counter", { id = "footnote", value = 1 })

  -- Chapters, here, go in the even header.
  SILE.call("even-running-header", {}, content)
end, "Applies chapter hooks (counter resets, footers and headers, etc.)")

SILE.registerCommand("sectioning:section:hook", function (options, content)
  -- Sections, here, go in the odd header.
  SILE.call("odd-running-header", {}, function ()
    if SU.boolean(options.numbering, true) then
      SILE.call("show-multilevel-counter", {
        id = options.counter, 
        level = options.level,
        noleadingzero = true
      })
      SILE.typesetter:typeset(" ")
    end
    SILE.process(content)
  end)
end, "Applies section hooks (footers and headers, etc.)")

SILE.registerCommand("part", function (options, content)
  options.style = "sectioning:part"
  SILE.call("sectioning", options, content)
end, "Begin a new part")

SILE.registerCommand("chapter", function (options, content)
  options.style = "sectioning:chapter"
  SILE.call("sectioning", options, content)
end, "Begin a new chapter")

SILE.registerCommand("section", function (options, content)
  options.style = "sectioning:section"
  SILE.call("sectioning", options, content)
end, "Begin a new section")

SILE.registerCommand("subsection", function (options, content)
  options.style = "sectioning:subsection"
  SILE.call("sectioning", options, content)
end, "Begin a new subsection")

SILE.registerCommand("subsubsection", function (options, content)
  options.style = "sectioning:subsubsection"
  SILE.call("sectioning", options, content)
end, "Begin a new subsubsection")

return omibook
