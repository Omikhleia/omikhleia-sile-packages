--
-- Cross-references for SILE
-- 2021-2022, Didier Willis
-- License: MIT
--
SILE.scratch.refs = {} -- references being collated in this SILE run
local _refs = {} -- references from the previous SILE run
local _markers = {} -- references labels collated so far
local _missing = false -- flag set to true when a label could not be resolved

-- Collate label references.
-- This method shall be called by supporting classes at the end of each page.
local moveRefs = function (_)
  local node = SILE.scratch.info.thispage.ref
    if node then
    for i = 1, #node do
      local marker = node[i].marker
      -- We should already have warned the user below, do not spam them again
      -- if SILE.scratch.refs[marker] ~= nil then
        -- SU.warn("Duplicate label '"..marker.."': this is possibly an error")
      -- end
      node[i].pageno = SILE.formatCounter(SILE.scratch.counters.folio)
      SILE.scratch.refs[marker] = node[i]
    end
  end
end

-- Save the references to a file.
-- This method shall be called by supporting classes at the end of the
-- document.
local writeRefs = function (_)
  local tocdata = pl.pretty.write(SILE.scratch.refs)
  local tocfile, err = io.open(SILE.masterFilename .. '.ref', "w")
  if not tocfile then return SU.error(err) end
  tocfile:write("return " .. tocdata)
  tocfile:close()

  if not pl.tablex.deepcompare(SILE.scratch.refs, _refs) then
    io.stderr:write("\n! Warning: Label references have changed, please rerun SILE to update them.")
  elseif _missing then
    io.stderr:write("\n! Warning: There are unresolved label references.")
  end
end

-- Read the reference file.
-- This method is automatically called when the package is initialized.
-- References saved from a previous SILE run are thus available on
-- the next run. Multiple re-runs may be needed to obtain the correct
-- references.
local readRefs = function ()
  local reffile,_ = io.open(SILE.masterFilename .. '.ref')
  if not reffile then
    return
  end
  local doc = reffile:read("*all")
  local refs = assert(load(doc))()
  _refs = refs
end

-- For the lowest numbering scheme, we need to account for potential nesting,
-- so we expose a stack...
local _numbers = {}
local pushLabelRef = function (_, number)
  table.insert(_numbers, number)
end
local popLabelRef = function (_)
  if #_numbers > 0 then
    _numbers[#_numbers] = nil
  end
end

-- Link support when pdf:link is available
local linkWrapper = function (dest, func)
  if dest and SILE.Commands["pdf:link"] then
    SILE.call("pdf:link", { dest = dest }, func)
  else
    func()
  end
end

-- If a reference marker has already been met, it is above us (supra)
-- else it must be after us (infra).
  local isSupra = function(marker)
    return _markers[marker] ~= nil and true or false
  end

-- Leverage \tocentry (from the tableofcontents package) if available.
-- We do this do globally store the current section number.
-- This implies the user can only refer to sections actually entered in the
-- TOC. We would need another method if users eventually want want to refer
-- to a section not in the TOC, but is it sound?
local _currentTocEntry = {}
if SILE.Commands["tocentry"] then
  local oldTocEntry = SILE.Commands["tocentry"]
  SILE.registerCommand("tocentry", function (options, content)
    _currentTocEntry.number = options.number
    _currentTocEntry.content = content
    oldTocEntry(options, content)
  end)
end

-- LOW-LEVEL/INTERNAL COMMANDS

local dc = 1
SILE.registerCommand("refentry", function (options, content)
  if _markers[options.marker] ~= nil then
    SU.warn("Duplicate label '"..options.marker.."': this is possibly an error")
  end
  _markers[options.marker] = true -- Just store seen markers

  local dest
  if SILE.Commands["pdf:destination"] then
    dest = "ref" .. dc
    SILE.call("pdf:destination", { name = dest })
    dc = dc + 1
  end
  SILE.call("info", {
    category = "ref",
    value = {
      marker = options.marker,
      title = content,
      section = options.section,
      number = options.number,
      link = dest
      -- pageno will be added when nodes are moved
    }
  })
end, "Inserts a reference infonode.")

SILE.registerCommand("ref:unknown", function (options, _)
  SU.warn("Label reference '"..options.marker.."' has not yet been resolved")
  SILE.call("font", { weight = 800 }, { "‹missing reference›"})
  _missing = true
end, "Warns the user and outputs ‹missing reference› for unresolved label references.")

SILE.registerCommand("ref:supra", function (options, content)
  SILE.call("font", { style = "italic", language = "und" }, { "supra" })
end, "Relative reference is above (supra).")

SILE.registerCommand("ref:infra", function (options, content)
  SILE.call("font", { style = "italic", language = "und" }, { "infra" })
end, "Relative reference is below (infra).")

-- END-USER COMMANDS

SILE.registerCommand("label", function (options, content)
  local marker = SU.required(options, "marker", "label")
  local currentNumber = _numbers[#_numbers]
  SILE.call("refentry", { marker = marker, section = _currentTocEntry.number, number = currentNumber }, _currentTocEntry.content)
  -- We don't really expect a content, let's ship it out anyway.
  SILE.process(content)
end, "Registers a label reference at the current point in the document.")

SILE.registerCommand("ref", function (options, content)
  local marker = SU.required(options, "marker", "ref")
  local t = options.type or "default"

  local node = _refs[marker]
  if not node then
    SILE.call("ref:unknown", options)
  else
    linkWrapper(SU.boolean(options.linking, true) and node.link, function ()
      if t == "relative" then
        if isSupra(marker) then
          SILE.call("ref:supra")
        else
          SILE.call("ref:infra")
        end
      else
        if t == "page" then
          SILE.typesetter:typeset(""..node.pageno)
        elseif t == "section" then
          if not node.section then
            SILE.call("ref:unknown", options)
          else
            SILE.typesetter:typeset(""..node.section)
          end
        elseif t == "title" then
          if not node.title then
            SILE.call("ref:unknown", options)
          else
            SILE.process(node.title)
          end
        elseif t == "default" then
          -- Closest numbering in that order: number, section or page
          if not node.number then
            if not node.section then
              SILE.typesetter:typeset(""..node.pageno)
            else
              SILE.typesetter:typeset(""..node.section)
            end
          else
            SILE.typesetter:typeset(""..node.number)
          end
        else
          SU.error("Unknown reference type '"..t.."'")
        end
        if SU.boolean(options.relative, false) then
          SILE.typesetter:typeset(" ")
          if isSupra(marker) then
            SILE.call("ref:supra")
          else
            SILE.call("ref:infra")
          end
        end
      end
    end)
  end
  -- We don't really expect a content, let's ship it out anyway.
  SILE.process(content)
end, "Prints a reference for the given label marker.")

SILE.registerCommand("pageref", function (options, content)
  options.type = "page"
  SILE.call("ref", options, content)
end, "Convenience command to print a page reference.")

-- EXPORTS

return {
  exports = {
    writeRefs = writeRefs,
    moveRefs = moveRefs,
    pushLabelRef = pushLabelRef,
    popLabelRef = popLabelRef,
  },
  init = function (self)
    self:loadPackage("infonode")
    readRefs()
  end,
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]

The \label[marker=omirefs:head]\doc:keyword{omirefs} package provides tools for classes
and packages to support cross-references within a document.

From a document author perspective, the commands \doc:code{\\label} and \doc:code{\\ref}
are then available. Both take a \doc:code{marker} option, which can be any reference string.
They do not expect any argument; if one is passed, though, it is just processed as-is.

The \doc:code{\\label} command is used to reference a given point in a document. Let us
do it just here\label[marker=myref]. It does not print anything, but we now have
a reference, just before this sentence.

The \doc:code{\\ref} command is used to refer to the point with the specified marker and
print out a resolved value depending on the \doc:code{type} option.

The page number is always available as \doc:code{\\ref[marker=\doc:args{marker}, type=page]}\footnote{The
package also provides the \doc:code{\\pageref[marker=\doc:args{marker}]} command as a mere convenience
alias.}: our label is on page \pageref[marker=myref].

In a book-like class, the current sectioning level (chapter, section, etc.) is also
available\footnote{\label[marker=fn:example]Actually, the package currently leverages the \doc:code{\\tocentry}
command if it exists, so assumes section entries explicitly marked for being
excluded from the table of contents will not be referred to. That’s a guess in the
dark, so do not hesitate reporting an issue.}, by number or title.
The current section number corresponds to \doc:code{\\ref[marker=\doc:args{marker}, type=section]}.
So here we should be in \ref[marker=myref,type=section], if this documentation is included
in some sort of book.
The current section title corresponds to \doc:code{\\ref[marker=\doc:args{marker}, type=title]}.
Here, “\ref[marker=myref,type=title]” (with us adding the quotes).

If referencing a marker that does not exist or a section which is not
available\footnote[mark=§]{\label[marker=fn:example:with-mark]Perhaps we are not even
in a numbered section? Ok, this note is kind of obvious, not to say dumb.
But it should be a footnote with a mark instead of a counter, if a footnote package
supporting them (as this author’s \doc:keyword{omifootnotes} package) is active.
If so, you will see why \ref[marker=omirefs:fn, type=relative].},
a warning is reported and the printed output is \ref[marker=do:not:exist].

\label[marker=omirefs:fn]If this package is loaded after a footnote package, then we also get the footnote
number for a label in a footnote, with \doc:code{\\ref[marker=\doc:args{marker}, type=default]}.
For instance, let’s pretend with want to refer the reader to notes \ref[marker=fn:example,type=default]
and \ref[marker=fn:example:with-mark].

This \doc:code{default} type is actually the most general and, as its name implies,
the default one if you omit specifying a type. If the referenced label is not in a
numbered object such as a footnote — or say, in the future, a figure or table caption — then
the section number is printed. In other terms, you get the closest item numbering
value.

This author knows some editors are pedantic and actually confesses the same guilt. This
package therefore supports another type, \doc:code{relative}, which would not
have needed such a machinery. Easy, this package description started \ref[marker=omirefs:head,
type=relative] and ends \ref[marker=omirefs:foot, type=relative]. And it even accepts, on all
the above-mentioned flavors of the \doc:code{\\ref} command, a \doc:code{relative} option
that may be set to true. So it started on page \pageref[marker=omirefs:head,relative=true] and
ends on page \pageref[marker=omirefs:foot,relative=true]. Blatant pedantry, for sure, but
a fault confessed is half redressed. Let’s pretend that \em{sometimes}, it might help
obtaining better line breaks.

As a final note, if the \doc:keyword{pdf} package is loaded before using label commands,
then hyperlinks will be enabled on references. You may disable this behavior
by setting the \doc:code{linking} option to false on the \doc:code{\\ref} command.

\em{For class implementers:} The package exports two Lua methods, \doc:code{moveRefs()} and
\doc:code{writeRefs()}. The former should be called at the end of each page to collate
label references. The latter should be called at the end of the document, to save the
references to a file which is read when the package is initialized. Also, this package has
to be loaded after the table of contents package, as it updates its \doc:code{\\tocentry}
command.

\em{For packages implementers:} The package also exports two Lua methods, \doc:code{pushLabelRef()}
and \doc:code{popLabelRefs()}. The former takes a formatted number as argument. To enable
cross-referencing in your own package, whatever your numbering scheme is, you may test for their
availability in your supporting class
(e.g. checking \doc:code{SILE.documentState.documentClass.pushLabelRef} exists)
and then wrap your code within them.
\label[marker=omirefs:foot]

\end{document}]]
}
