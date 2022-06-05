--
-- USFX (Bible XML format) support
-- 2022, Didier Willis
-- License: MIT
-- IN PROGRESS. QUICK AND DIRTY PROOF OF CONCEPT
--
SILE.require("packages/xmltricks")

SILE.call("xmltricks:ignore", {}, { "languageCode rem id ide toc table" })
-- languageCode: Three-letter Ethnologue code or two-letter ISO language code, optionally followed
-- by a dialect indicator.
-- rem: Remark or comment, not for publication.

SILE.call("xmltricks:passthru", {}, { "h s xo xt q it ord b qs cs wj" })

SILE.registerCommand("book", function (options, content)
  -- This element contains one book of the Bible or optionally some front or back matter.
  -- The id attribute is for the three-letter code for this book of the Bible (or FRT for
  -- front matter and BAK for back matter).
  print("[Book " .. options.id .."]") -- Just to have a sdtout over that long document...
  SILE.process(content)
end)

local chap
local chapStart

SILE.registerCommand("v", function (options, content)
  if tonumber(options.id) ~= 1 then
    SILE.call("color", { color = "blue" }, function()
        SILE.call("textsuperscript", {}, { options.id })
    end)
    SILE.call("kern", { width = "1spc" })
  end
end)

SILE.registerCommand("ve", function (options, content)
  -- ve is used as a milestone element marking the end of a verse.
  -- Content, if any, is treated as a comment.
  -- It should be placed just after the last of the canonical text of a verse,
  -- but before any subtitles or headers associated with the next verse.
  -- SILE.call("par") -- Should we break paragraphs here? Unclear!
end)

SILE.registerCommand("p", function (options, content)
  -- The p element contains not only the \p marker's contents, but also every kind of paragraph
  -- and heading or title. If this is used for something other than \p, then the sfm attribute
  -- MUST be set to indicate which kind of paragraph, or heading is intended. Headings,
  -- and paragraphs are in the same group because they all correspond to paragraphs in a word
  -- processing document. This element includes \ps, \psi, and \nb. Note that some common paragraph
  -- elements (q, d, and s) could have been included in this element, too, but have their own element
  -- tags for convenience in manual editing of the XML.
  if not options.sfm then
    if chapStart then
      chapStart = false
      -- Problem here: we will want to use a "dropped capital" layout for the chapter number
      -- but some verses are one line long only. Heavy workaround: parbox the text in a typesetter
      -- state, steal that box, check its height and act depending on it...
      -- SILE.call("noindent")
      SILE.typesetter:pushState()
      local p = SILE.call("parbox", { width = "100%fw", valign="bottom", border="1pt" }, function()
            SILE.call("dropcap", { lines = 2, family = "Libertinus Serif",
              style = "italic", color = "#58101c", join = false },
              { chap .. " " })
            SILE.process(content)
        end)
      table.remove(SILE.typesetter.state.nodes) -- steal it back
      SILE.typesetter:popState()
      local h = p.height + p.depth
      SILE.typesetter:leaveHmode()
      
       SILE.call("dropcap", { lines = 2, family = "Libertinus Serif",
              style = "italic", color = "#58101c", join = false },
              { chap .. " " })
       SILE.process(content)
       SILE.call("par")
      
      if h:tonumber() < SILE.length("2bs"):tonumber() then SILE.call("skip", { height = "1bs" }) end
    else
      --SILE.call("color", { color = "blue" }, function()
      --    SILE.call("textsuperscript", {}, { options.id })
      -- end)
      SILE.call("kern", { width = "0.75spc" })
      SILE.process(content)
    end
    SILE.call("par")
  end
end)

SILE.registerCommand("c", function (options, content)
  chap = options.id
  chapStart = true
end)

SILE.registerCommand("s", function (options, content)
  -- Section heading (not part of the Scripture text).
  SILE.call("goodbreak")
  SILE.call("skip", { height = "1bs", discardable = true }) -- DOH
  SILE.call("noindent")
  SILE.call("color", { color = "#58101c" }, function()
    SILE.call("font", { family = "Libertinus Sans", style = "italic"  }, content)
  end)
  SILE.call("novbreak")
  SILE.call("par")
  SILE.call("novbreak")  
end)

SILE.registerCommand("x", function (options, content)
  SILE.call("color", { color = "#58101c" }, function()
    SILE.call("font", { style = "italic" }, function()
      SILE.call("textsuperscript", {}, { options.caller })
    end)
    SILE.call("kern", { width = "0.8spc" })
  end)
  -- FIXME xt, xo processing with insertions
  -- SILE.process(content)
end)
