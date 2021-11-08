--
-- A new book class for SILE
-- 2021, Didier Willis
-- License: MIT
--
-- This is a work in progress, gradually tuning the default book
-- class from SILE to my needs and taste.
--   - Slightly different default page master (I found the gutter space too small)
--   - Sectioning commands obey styles (defined with the "styles" package)
--   - Chapters have page numbering
--   - Better handling of page headers
--
local plain = SILE.require("plain", "classes")
local omibook = plain { id = "omibook" }

local counters = SILE.require("packages/counters").exports

local styles = SILE.require("packages/styles").exports
styles.defineStyle("book:sectioning:base", {}, {
  paragraph = { indentbefore = false, indentafter = false } })
styles.defineStyle("book:part", { inherit = "book:sectioning:base" }, { font = { weight = 800, size = "+6" },
  paragraph = { skipbefore = "3cm", skipafter = "bigskip" } })
styles.defineStyle("book:chapter", { inherit = "book:sectioning:base" }, { font = { weight = 800, size = "+4" },
  paragraph = { skipafter = "bigskip" } })
styles.defineStyle("book:section", { inherit = "book:sectioning:base" },  { font = { weight = 800, size = "+2" },
  paragraph = { skipbefore = "bigskip", skipafter = "bigskip", breakafter = false } })
styles.defineStyle("book:subsection", { inherit = "book:sectioning:base"},  { font = { weight = 800, size = "+1" },
  paragraph = { skipbefore = "medskip", skipafter = "medskip", breakafter = false } })
styles.defineStyle("book:subsubsection", { inherit = "book:sectioning:base" },  { font = { weight = 800 },
  paragraph = { skipbefore = "smallskip", skipbefore = "smallskip"; breakafter = false } })
styles.defineStyle("book:folio", {},  { font = { size = "-0.5" } })
styles.defineStyle("book:header:base", {},  { font = { size = "-1" } })
styles.defineStyle("book:header:left", { inherit = "book:header:base" }, {})
styles.defineStyle("book:header:right", { inherit = "book:header:base" }, { font = { style = "italic" } })


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

  -- override foliostyle
  self:loadPackage("folio")
  SILE.registerCommand("foliostyle", function (_, content)
    SILE.call("noindent")
    if SILE.documentState.documentClass:oddPage() then
      SILE.call("rightalign", {}, function()
        SILE.call("style:apply", { name = "book:folio"}, content)
      end)
    else
      SILE.call("style:apply", { name = "book:folio"}, content)
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
  local headerContent = (self:oddPage() and SILE.scratch.headers.right)
        or (not(self:oddPage()) and SILE.scratch.headers.left)
  self:outputHeader(headerContent)
  return plain.endPage(self)
end

SILE.registerCommand("left-running-head", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.left = function () closure(content) end
end, "Text to appear on the top of the left page")

SILE.registerCommand("right-running-head", function (_, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.right = function () closure(content) end
end, "Text to appear on the top of the right page")

SILE.registerCommand("book:sectioning", function (options, content)
  local level = SU.required(options, "level", "book:sectioning")
  local number
  if SU.boolean(options.numbering, true) then
    SILE.call("increment-multilevel-counter", { id = "sectioning", level = level })
    number = SILE.formatMultilevelCounter(counters.getMultilevelCounter("sectioning"))
  end
  if SU.boolean(options.toc, true) then
    SILE.call("tocentry", { level = level, number = number }, SU.subContent(content))
  end
  local lang = SILE.settings.get("document.language")
  if SU.boolean(options.numbering, true) then
    if options.prenumber then
      if SILE.Commands[options.prenumber .. ":"  .. lang] then
        options.prenumber = options.prenumber .. ":" .. lang
      end
      SILE.call(options.prenumber)
    end
    SILE.call("show-multilevel-counter", { id = "sectioning" })
    if options.postnumber then
      if SILE.Commands[options.postnumber .. ":" .. lang] then
        options.postnumber = options.postnumber .. ":" .. lang
      end
      SILE.call(options.postnumber)
    end
  end
end)

omibook.registerCommands = function (_)
  plain.registerCommands()
SILE.doTexlike([[%
\define[command=book:chapter:pre]{}%
\define[command=book:chapter:post]{\par\noindent}%
\define[command=book:section:post]{ }%
\define[command=book:subsection:post]{ }%
\define[command=book:subsubsection:post]{ }%
]])
end

SILE.registerCommand("omibook-double-page", function (_, _)
  -- NOTE: We do not use the "open-double-page" from the two side
  -- package as it has doesn't have the nice logic we have here
  -- (page 1 special case, and no header nor folio on blank
  -- even pages)
  if SILE.scratch.counters.folio.value > 1 then
    SILE.typesetter:leaveHmode()
    SILE.call("supereject")
    if SILE.documentState.documentClass:oddPage() then
      SILE.typesetter:typeset("")
      SILE.typesetter:leaveHmode()
      SILE.call("nofoliosthispage")
      SILE.call("noheaderthispage")
      SILE.call("supereject")
    end
  end
  SILE.typesetter:leaveHmode()
end, "Open a double page without header and folio")

SILE.registerCommand("part", function (options, content)
  SILE.call("omibook-double-page")
  SILE.call("hbox", {}, {}) -- HACK to ensure the vskip if any is applied... 
  SILE.call("style:apply:before", { name = "book:part" })
  SILE.call("noheaderthispage")
  SILE.call("nofoliosthispage")
  SILE.call("set-counter", { id = "footnote", value = 1 })
  SILE.call("center", {}, function ()
    SILE.call("style:apply", { name= "book:part" }, function ()
      SILE.call("book:sectioning", {
        numbering = false, -- options.numbering, NOT SUPPORTED FOR NOW FIXME
        -- By the way, we want to support books without parts and with them, and
        -- also sections without (numbered) chapters, so we need to have a closer
        -- look at how multilevel counters work, not to get 0.1 etc. :)
        toc = options.toc,
        level = 0,
        -- prenumber = "book:chapter:pre",
        -- postnumber = "book:chapter:post"
      }, content)
      SILE.process(content)
    end)
  end)
  SILE.call("bigskip")
end, "Begin a new chapter")

SILE.registerCommand("chapter", function (options, content)
  SILE.call("omibook-double-page")
  SILE.call("style:apply:before", { name = "book:chapter" })
  SILE.call("noheaderthispage")
  SILE.call("set-counter", { id = "footnote", value = 1 })
  SILE.call("style:apply", { name= "book:chapter" }, function ()
    SILE.call("book:sectioning", {
      numbering = options.numbering,
      toc = options.toc,
      level = 1,
      prenumber = "book:chapter:pre",
      postnumber = "book:chapter:post"
    }, content)
    SILE.process(content)
  end)
  SILE.call("left-running-head", {}, function ()
    SILE.call("style:apply", { name = "book:header:left" }, content)
  end)
  SILE.call("style:apply:after", { name = "book:chapter" })
  -- Chapters have page numbering (FIXME should be an option?)
  -- SILE.call("nofoliosthispage")
end, "Begin a new chapter")

SILE.registerCommand("section", function (options, content)
  SILE.typesetter:leaveHmode()
  SILE.call("goodbreak")
  SILE.call("style:apply:before", { name = "book:section" })
  SILE.call("style:apply", { name = "book:section"}, function ()
    SILE.call("book:sectioning", {
      numbering = options.numbering,
      toc = options.toc,
      level = 2,
      postnumber = "book:section:post"
    }, content)
    SILE.process(content)
  end)
  if not SILE.scratch.counters.folio.off then
    SILE.call("right-running-head", {}, function ()
      SILE.call("rightalign", {}, function ()
        SILE.call("style:apply", { name = "book:header:right" }, function()
          SILE.call("show-multilevel-counter", { id = "sectioning", level = 2 })
          SILE.typesetter:typeset(" ")
          SILE.process(content)
        end)
      end)
    end)
  end
  SILE.call("style:apply:after", { name = "book:section" })
  SILE.typesetter:inhibitLeading()
end, "Begin a new section")

SILE.registerCommand("subsection", function (options, content)
  SILE.typesetter:leaveHmode()
  SILE.call("goodbreak")
  SILE.call("style:apply:before", { name = "book:subsection" })
  SILE.call("style:apply", { name = "book:subsection" }, function ()
    SILE.call("book:sectioning", {
          numbering = options.numbering,
          toc = options.toc,
          level = 3,
          postnumber = "book:subsection:post"
        }, content)
    SILE.process(content)
  end)
  SILE.call("style:apply:after", { name = "book:subsection" })
  SILE.typesetter:inhibitLeading()
end, "Begin a new subsection")

SILE.registerCommand("subsubsection", function (options, content)
  SILE.typesetter:leaveHmode()
  SILE.call("goodbreak")
  SILE.call("style:apply:before", { name = "book:subsubsection" })
  SILE.call("style:apply", { name = "book:subsubsection" }, function ()
    SILE.call("book:sectioning", {
          numbering = options.numbering,
          toc = options.toc,
          level = 4,
          postnumber = "book:subsection:post"
        }, content)
    SILE.process(content)
  end)
  SILE.call("style:apply:after", { name = "book:subsubsection" })
  SILE.typesetter:inhibitLeading()
end, "Begin a new subsubsection")

return omibook
