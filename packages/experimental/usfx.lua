--
-- USFX (Bible XML format) support
-- 2022, Didier Willis
-- License: MIT
-- IN PROGRESS. QUICK AND DIRTY PROOF OF CONCEPT
--
SILE.require("packages/xmltricks")

SILE.call("xmltricks:ignore", {}, { "languageCode rem id ide toc table" })
-- languageCode: Three-letter Ethnologue code or two-letter ISO language code, optionally followed
--   by a dialect indicator.
-- rem: Remark or comment, not for publication.
-- ide: Encoding of the corresponding USFM file. (Encoding of this XML file is given in the XML header.)
-- id: From the \id marker line. The first three characters of the contents of this element MUST
--   be the three-letter code for this book of the Bible (or FRT for front matter and BAK for back matter).
--   N.B.in the Segond Bible, at least, the id attribute on the <book> tag contains the Bible book code.

SILE.call("xmltricks:passthru", {}, { "h b qs it cs wj" })
-- qs: Special marking for "Selah." in the target language. This may cause right alignment of this word or phrase
--   in an otherwise left-aligned or fully justified paragraph, or may have no effect.
-- it: talic; not recommended for use. N.B. In the Segond Bible, marks some words or quotations in the comments,
--   interpretations, introductory text, etc. (e.g. in <p sfm="id">...)
-- cs: character style. N.B. In the Segond Bible, aways seem to be in the form of <cs sfm="ior">1:3–2:4</cs>
--  with a range of verses.
-- wj: Words of Jesus. N.B. In the Segond Bible, also applies to words of God apparently...

-- FIXME
-- h: Short book name for a running header, like "Matthew".
--  N.B. Should we use it, or expand the book id from the other provided XML files (e.g. BookNames.xml)?

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

SILE.registerCommand("q", function (options, content)
  -- FIXME for now same as p
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
  -- This format is a mess of loose structures (e.g. <ve />), we'd need to collect all <x>
  -- for a given verse, but the latter is not represented by an englobing stucture. This
  -- format is a mess ^^
end)

SILE.registerCommand("ord", function (options, content)
  -- ord: Ordinal number ending; may be superscripted and underlined.
  -- N.B. In the Segond Bible, used in introductory contents (p sfm=id, etc)
  SILE.call("textsuperscript", {}, content[0])
end)

SILE.registerCommand("b", function (options, content)
  -- b: Blank line between stanzas of poetry; not to be used before or after a section header. 
  --   This element should be empty. N.B. In the Segond Bible, often used in the Psalms...
  --   FIXME should perhaps be handled, but sometimes it is between p, sometimes between q, sometimes just
  --   after a c chapter, and not so consistently... so I am not sure how to treat it generically...
  -- A skip looks ugly for now...
  -- SILE.call("skip", { height = "1bs "})
end)
