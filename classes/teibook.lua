--
-- A (XML) TEI book class for SILE
-- 2021, The Sindarin Dictionary Project, Omikhleia, Didier Willis
-- License: MIT
--
-- This is the book-like class for (XML) TEI dictionaries.
-- It just defines the appropriate page masters, sectioning hooks
-- and loads all needed packages. The hard work processing the
-- XML content is done in the "teidict" package.
--
local plain = SILE.require("plain", "classes")
local teibook = plain { id = "teibook" }

local counters = SILE.require("packages/counters").exports

teibook.defaultFrameset = {
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

function teibook:twoColumnMaster()
  local gutterWidth = self.options.gutter or "3%pw"
  self:defineMaster({
    id = "right",
    firstContentFrame = "contentA",
    frames = {
      contentA = {
        left = "10%pw", -- was 8.3%pw
        right = "left(gutter)",
        top = "11.6%ph",
        bottom = "top(footnotesA)",
        next = "contentB",
        balanced = true
      },
      contentB = {
        left = "right(gutter)",
        width ="width(contentA)",
        right = "87.7%pw", -- was 86%pw
        top = "11.6%ph",
        bottom = "top(footnotesB)",
        balanced = true
      },
      gutter = {
        left = "right(contentA)",
        right = "left(contentB)",
        width = gutterWidth
      },
      folio = {
        left = "left(contentA)",
        right = "right(contentB)",
        top = "bottom(footnotesB)+3%ph",
        bottom = "bottom(footnotesB)+5%ph"
      },
      header = {
        left = "left(contentA)",
        right = "right(contentB)",
        top = "top(contentA)-5%ph", -- was -8%ph
        bottom = "top(contentA)-2%ph" -- was -3%ph
      },
      footnotesA = {
        left =  "left(contentA)",
        right = "right(contentA)",
        height = "0",
        bottom = "86.3%ph" -- was 83.3%ph
      },
      footnotesB = {
        left = "left(contentB)",
        right = "right(contentB)",
        height = "0",
        bottom = "86.3%ph" -- was 83.3%ph
      },
    }
  })
  self:defineMaster({
    id = "left",
    firstContentFrame = "contentA",
    frames = {
      contentA = {
        left = "12.3%pw", -- was 14%pw
        right = "left(gutter)",
        top = "11.6%ph",
        bottom = "top(footnotesA)",
        next = "contentB",
        balanced = true
      },
      contentB = {
        left = "right(gutter)",
        width = "width(contentA)",
        right = "90%pw", -- was 91.7%pw,
        top = "11.6%ph",
        bottom = "top(footnotesB)",
        balanced = true
      },
      gutter = {
        left = "right(contentA)",
        right = "left(contentB)",
        width = gutterWidth
      },
      folio = {
        left = "left(contentA)",
        right = "right(contentB)",
        top = "bottom(footnotesB)+3%ph",
        bottom = "bottom(footnotesB)+5%ph"
      },
      header = {
        left = "left(contentA)",
        right = "right(contentB)",
        top = "top(contentA)-5%ph", -- was -8%ph
        bottom = "top(contentA)-2%ph" -- was -3%ph
      },
      footnotesA = {
        left = "left(contentA)",
        right = "right(contentA)",
        height = "0",
        bottom = "86.3%ph" -- was 83.3%ph
      },
      footnotesB = {
        left = "left(contentB)",
        right = "right(contentB)",
        height = "0",
        bottom = "86.3%ph" -- was 83.3%ph
      },
    }
  })
end

local pageStyle

function teibook:setPageStyleTitle ()
  -- self:oneColumnMaster()
  -- Nothing to to for now, as the title page is generated
  -- via the TEI header, that normally comes first, and
  -- the initial page style is kind of ok for it.
  pageStyle = "cover"
end

function teibook:setPageStyleHeader ()
  -- self:oneColumnMaster()
  -- Nothing to to for now, as the TEI header normally comes first
  -- and the initial page style is kind of ok for it.
  pageStyle = "header"
end

function teibook:setPageStyleEntries ()
  self:twoColumnMaster()
  self.switchMaster("right")
  self.firstContentFrame = "contentA"
  pageStyle = "entries"
end

function teibook:setPageStyleBackmatter ()
  self:twoColumnMaster()
  self.switchMaster("right")
  self.firstContentFrame = "contentA"

  pageStyle = "backmatter"
end

function teibook:setPageStyleImpressum()
  self:defineMaster({
    id = "right",
    firstContentFrame = "content",
    frames = self.defaultFrameset
  })
  self:mirrorMaster("right", "left")
  self.switchMaster(SILE.documentState.documentClass:oddPage() and "right" or "left")
  self.firstContentFrame = "content"
  pageStyle = "backmatter"
end

function teibook:init ()
  -- Page masters
  self:loadPackage("masters")
  self:defineMaster({
      id = "right",
      firstContentFrame = "content",
      frames = self.defaultFrameset
    })
  self.firstContentFrame = "content"
  self:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })
  self:mirrorMaster("right", "left")
  self.switchMaster("right")

  -- And all other packages needed by the teidict package
  self:loadPackage("infonode")
  self:loadPackage("pdf")
  self:loadPackage("url")
  self:loadPackage("color")
  self:loadPackage("raiselower")
  self:loadPackage("rules")
  self:loadPackage("xmltricks")
  self:loadPackage("svg")
  self:loadPackage("teidict")

  return plain.init(self)
end

teibook.newPage = function (self)
  self:switchPage()
  self:newPageInfo()
  return plain.newPage(self)
end

teibook.finish = function (self)
  local ret = plain.finish(self)
  return ret
end

teibook.endPage = function (self)
  if pageStyle == "entries" and SILE.scratch.info.thispage.teientry then
    -- Running headers in the dictionary section will have the following form:
    -- first-entry         - folio -       last-entry
    SILE.typesetNaturally(SILE.getFrame("header"), function ()
      SILE.settings.pushState()
      SILE.settings.toplevelState()
      SILE.settings.set("document.parindent", SILE.nodefactory.glue())
      SILE.settings.set("current.parindent", SILE.nodefactory.glue())
      SILE.settings.set("document.lskip", SILE.nodefactory.glue())
      SILE.settings.set("document.rskip", SILE.nodefactory.glue())
      local foliotext = "— "..SILE.formatCounter(SILE.scratch.counters.folio).." —" -- Note: U+2014 — em dash

      -- Some boxing needed, so we can easilycenter the folio number in between
      -- first and last references
      local folio = SILE.call("hbox", {}, function()
        SILE.typesetter:typeset(foliotext)
      end)
      table.remove(SILE.typesetter.state.nodes)
      local first = SILE.call("hbox", {}, function ()
        SILE.call("first-entry-reference")
      end)
      local l = SILE.measurement("100%lw"):tonumber()
      SILE.typesetter:pushGlue({ width = l  / 2 - first.width:tonumber() - folio.width:tonumber() / 2 })

      SILE.typesetter:typeset(foliotext)

      SILE.call("hfill")
      local last = SILE.call("hbox", {}, function ()
        SILE.call("last-entry-reference")
      end)
      SILE.typesetter:leaveHmode()

      SILE.settings.set("current.parindent", SILE.nodefactory.glue())
      SILE.call("raise", { height = "0.475ex" }, function()
        SILE.call("fullrule", { height = "0.33pt" })
      end)
      SILE.typesetter:leaveHmode()
      SILE.settings.popState()
    end)
  end
  return plain.endPage(self)
end

SILE.registerCommand("first-entry-reference", function (_, _)
  local refs = SILE.scratch.info.thispage.teientry
  if refs then
    SILE.call("orth", refs[1].options, refs[1])
  end
end, "Outputs the first entry reference on the page.")

SILE.registerCommand("last-entry-reference", function (_, _)
  local refs = SILE.scratch.info.thispage.teientry
  if refs then
    SILE.call("orth", refs[#(refs)].options, refs[#(refs)])
  end
end, "Outputs the last entry reference on the page")

local styles = SILE.require("packages/styles").exports
styles.defineStyle("teibook:titlepage", {}, { font = { family = "Libertinus Sans", size = "20pt" } })
styles.defineStyle("teibook:impressum", {}, { font = { style = "italic", features = "+hlig,+salt" } })

SILE.registerCommand("teibook:titlepage", function (_, content)
  -- the content contains the title
  SILE.documentState.documentClass:setPageStyleTitle();
  SILE.call("nofolios")
  SILE.call("hbox", {}, {})
  SILE.call("vfill")
  SILE.call("style:apply", { name = "teibook:titlepage" }, function ()
    SILE.call("raggedleft", {}, function()
      SILE.process(content)
      SILE.typesetter:leaveHmode()
    end)
  end)
  SILE.call("vfill")
  SILE.call("hbox", {}, {})
  SILE.call("eject")
end, "Generates the title page.")

SILE.registerCommand("teibook:header", function (_, _)
  SILE.documentState.documentClass:setPageStyleTitle();
  SILE.call("nofolios")
end, "Enters the TEI header section.")

SILE.registerCommand("teibook:entries", function (_, _)
  SILE.typesetter:leaveHmode()
  SILE.call("supereject")
  if SILE.documentState.documentClass:oddPage() then
    SILE.typesetter:typeset("")
    SILE.typesetter:leaveHmode()
    SILE.call("supereject")
  end
  SILE.typesetter:leaveHmode()
  SILE.documentState.documentClass:setPageStyleEntries();
  SILE.call("nofolios")
end, "Enters the TEI dictionary section (i.e. a TEI.div0 typed as such).")

SILE.registerCommand("teibook:backmatter", function (_, _)
  SILE.typesetter:leaveHmode()
  SILE.call("supereject")
  if SILE.documentState.documentClass:oddPage() then
    SILE.typesetter:typeset("")
    SILE.typesetter:leaveHmode()
    SILE.call("nofoliosthispage")
    SILE.call("supereject")
  end
  SILE.typesetter:leaveHmode()
  SILE.documentState.documentClass:setPageStyleBackmatter();
  SILE.call("folios")
end, "Enters the backmatter section (generated).")

SILE.registerCommand("teibook:impressum", function (_, content)
  -- the content contains the impressum
  SILE.typesetter:leaveHmode()
  SILE.call("supereject")
  if SILE.documentState.documentClass:oddPage() then
    SILE.typesetter:typeset("")
    SILE.typesetter:leaveHmode()
    SILE.call("nofoliosthispage")
    SILE.call("supereject")
  end
  SILE.typesetter:leaveHmode()
  SILE.documentState.documentClass:setPageStyleImpressum();
  SILE.call("nofolios")

  SILE.call("hbox", {}, {})
  SILE.call("vfill")
  SILE.typesetter:leaveHmode()
  SILE.call("style:apply", { name = "teibook:impressum" }, function ()
    SILE.call("center", {}, function()
      SILE.process(content)
    end)
  end)
  SILE.call("hbox", {}, {})
  SILE.typesetter:leaveHmode()
  SILE.call("break")
end, "Enters the impressum section (generated).")

-- SKIPS
-- Dictionaries are composed of plenty of small entry paragraphs, so we'd better
-- have our own vertical spacing commands...
--   teibook:smallskip is used between entries
--   teibook:medskip is used after milestones (i.e. heading letters)
--   teibook:bigskip is used before milestones
local skips = {
  small = "0.2em plus 0.15em minus 0.1em", -- regular smallskip is 3pt plus 1pt minus 1pt
  med = "0.6em", -- fixed, regular medskip is 6pt plus 2pt minus 2pt
  big = "1.8em plus 1.2em minus 0.6em" -- regular bigskip is 12pt plus 4pt minus 4pt
}

for k, v in pairs(skips) do
  SILE.settings.declare({
      parameter = "teibook." .. k .. "skipamount",
      type = "vglue",
      default = SILE.nodefactory.vglue(v),
      help = "Amount of a \\teibook:" .. k .. "skip"
    })
  SILE.registerCommand("teibook:"..k .. "skip", function (_, _)
    SILE.typesetter:leaveHmode()
    SILE.typesetter:pushExplicitVglue(SILE.settings.get("teibook." .. k .. "skipamount"))
  end, "Skip vertically by a teibook:" .. k .. " amount")
end

return teibook
