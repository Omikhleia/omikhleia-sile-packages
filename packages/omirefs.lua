--
-- Cross-references for SILE
-- 2021, Didier Willis
-- License: MIT
--
SILE.scratch.refs = {}
local _refs = {}
local _missing = false
local _markers = {}

local moveRefs = function (_)
  local node = SILE.scratch.info.thispage.ref
    if node then
    for i = 1, #node do
      local marker = node[i].marker
      -- We should already have warned the user below, do not spam him.
      -- if SILE.scratch.refs[marker] ~= nil then
        -- SU.warn("Duplicate label '"..marker.."': this is possibly an error")
      -- end
      node[i].pageno = SILE.formatCounter(SILE.scratch.counters.folio)
      SILE.scratch.refs[marker] = node[i]
    end
  end
end

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

local readRefs = function ()
  local reffile,_ = io.open(SILE.masterFilename .. '.ref')
  if not reffile then
    return
  end
  local doc = reffile:read("*all")
  local refs = assert(load(doc))()
  _refs = refs
end

local linkWrapper = function (dest, func)
  if dest and SILE.Commands["pdf:link"] then
    SILE.call("pdf:link", { dest = dest }, func)
  else
    func()
  end
end

-- Leverage tocentry
-- QUESTION: Should we actually do this, or rather leverage book:sectioning?
-- The user might perhaps want to refer to a section not in the TOC.
-- I have no idea, so let's go ahead for now.
local _currentTocEntry = {}
if SILE.Commands["tocentry"] then
  local oldTocEntry = SILE.Commands["tocentry"]
  SILE.registerCommand("tocentry", function (options, content)
    _currentTocEntry.number = options.number
    _currentTocEntry.content = content
    oldTocEntry(options, content)
  end)
end

-- Leverage footnote
local _currentFn = nil
if SILE.Commands["footnote"] then
  local oldFn = SILE.Commands["footnote"]
  SILE.registerCommand("footnote", function (options, content)
    -- Be friendly with omifootnotes that support a mark option :)
    _currentFn = options.mark or SILE.formatCounter(SILE.scratch.counters.footnote)
    oldFn(options, content)
    _currentFn = nil
  end)
end

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
      footnote = options.footnote,
      number = options.number, -- For other packages to tweak it.
      link = dest
      -- pageno is added when nodes are moved
    }
  })
end, "Inserts a reference infonode (low-level command)")

local isSupra = function(marker)
  return _markers[marker] ~= nil and true or false
end

SILE.registerCommand("label", function (options, content)
  local marker = SU.required(options, "marker", "label")
  SILE.call("refentry", { marker = marker, section = _currentTocEntry.number, footnote = _currentFn }, _currentTocEntry.content)
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
      elseif t == "_footnote_" then
        -- See command footnoteref
        -- No intended to be used directly so not documented.
        if not node.footnote then
          SILE.call("ref:unknown", options)
        else
          SILE.call("footnote:mark", { mark = node.footnote })
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
          -- Sections can contains footnotes, and all of these
          -- can contain other numbered elements. I don't think
          -- we need more than that.
          if not node.number then
            if not node.footnote then
              if not node.section then
                SILE.call("ref:unknown", options)
              else
                SILE.typesetter:typeset(""..node.section)
              end
            else
              SILE.typesetter:typeset(""..node.footnote)
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

SILE.registerCommand("ref:unknown", function (options, _)
  SU.warn("Label reference '"..options.marker.."' has not yet been resolved")
  SILE.call("font", { weight = 800 }, { "‹missing reference›"})
  _missing = true
end, "Warns the user and prints ‹missing reference› for unresolved label references.")

SILE.registerCommand("ref:supra", function (options, content)
  SILE.call("font", { style = "italic", language = "und" }, { "supra" })
end, "Relative reference is above (supra).")

SILE.registerCommand("ref:infra", function (options, content)
  SILE.call("font", { style = "italic", language = "und" }, { "infra" })
end, "Relative reference is below (infra).")

SILE.registerCommand("pageref", function (options, content)
  options.type = "page"
  SILE.call("ref", options, content)
end, "Convenience command to print a page reference.")

-- This command, which is defined if the omifootnotes package is active,
-- allows to fake a footnote call to an existing footnote using
-- a label reference. Let's not document it for now, I am not convinced
-- it should be kept. I'll have it if I even need it, or I'll take
-- the decision to remove it at some point.
if SILE.Commands["footnote:mark"] then
  -- The standard footnotes package has (at the time of writing)
  -- footnotemark, not footnote:mark as the omifootnotes package.
  -- We'll need support for the mark option, so let's expect this
  -- doesn't change and we can check it this way...
  SILE.registerCommand("footnoteref", function (options, content)
    options.type = "_footnote_"
    SILE.call("ref", options, content)
  end, "Convenience command to format a reference as a footnote call.")
end

return {
  exports = { writeRefs = writeRefs, moveRefs = moveRefs },
  init = function (self)
    self:loadPackage("infonode")
    readRefs()
  end,
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]

The \label[marker=omirefs:head]\doc:keyword{omirefs} package provides tools for classes
and packages to support cross-references within a document.
It exports two Lua functions, \doc:code{moveRefs()} and \doc:code{writeRefs()}.
The former should be called at the end of each page to collate label references.
The latter should be called at the end of the document, to save the references to a file
which is read when the package is initialized.

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
\label[marker=omirefs:foot]
\end{document}]]
}
