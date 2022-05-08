-- All macros etc. needed by the blockquote

-- Dependencies
SILE.require("packages/pdf")
SILE.require("packages/couyards")
SILE.require("packages/epigraph")
SILE.require("packages/omipoetry")
SILE.require("packages/image")
SILE.require("packages/ptable")
SILE.require("packages/colophon")
SILE.require("packages/dropcaps")
SILE.require("packages/framebox")
SILE.require("packages/barcodes/ean13")
SILE.require("packages/experimental/fancytoc")
local styles = SILE.require("packages/styles").exports

-- Some small command definitions (helpers)
SILE.doTexlike([[%
\define[command=foreign:en]{\em{\language[main=en]{\process}}}%
\define[command=foreign:gr]{\em{\language[main=und]{\process}}}%
\define[command=smaller]{\style:font[size=-1]{\process}\par}%
\define[command=smallcaps]{\font[features=+smcp]{\process}}%
\define[command=nbsp]{\abbr:nbsp[fixed=true]{}}%
]])

-- Style redefinition
SILE.doTexlike([[%
% FIGURES
\style:redefine[name=figure:caption, as=_caption, inherit=true]{
  \font[style=normal, size=-1]
  \paragraph[align=block, breakbefore=false, skipbefore=smallskip]
}%
\style:define[name=figure:caption:number]{
  \numbering[before="Figure ", after=.]
  \font[features=+smcp]
}%
% SECTIONING
\style:redefine[name=sectioning:base, as=_secbase, inherit=true]{
  \paragraph[indentafter=true]
}%
\define[command=sectioning:section:hook]{}%
%
\style:redefine[name=sectioning:part:number, as=_partlabel, inherit=true]{
  \numbering[before="Livre "]
}%
\style:redefine[name=sectioning:section, as=_sec, inherit=true]{
  \font[size=0]
  \paragraph[skipbefore=medskip, skipafter=smallskip, breakafter=false]
}%
% HEADERS
\style:redefine[name=header:odd, as=_hdodd, inherit=true]{
  \paragraph[align=center]
  \font[style=italic]
}%
\style:redefine[name=header:even, as=_hdeven, inherit=true]{
  \paragraph[align=center]
  \font[style=italic]
}%
% Override class default, so as not to clear the odd running header...
\define[command=sectioning:part:hook]{
\noheaderthispage%
\nofoliothispage%
\even-running-header{}
\set-counter[id=foonote, value=1]
\set-multilevel-counter[id=sections, level=1, value=0]
}%
]])

-- Initial dropcaps wrapper
local vglueNoStretch = function (vg)
  return SILE.nodefactory.vglue(SILE.length(vg.height.length))
end
SILE.registerCommand("initial", function (options, content)
  SILE.settings.temporarily(function()
    SILE.settings.set("document.baselineskip", vglueNoStretch(SILE.settings.get("document.baselineskip")))
    SILE.call("dropcap", { lines = 2, family = "Zallman Caps", join = true },
      { options.letter })
    SILE.process(content)
    SILE.typesetter:leaveHmode()
  end)
end, "Simplified dropcap wrapper")

-- Partition environment
local extractFromTree = function (tree, command)
  for i=1, #tree do
    if type(tree[i]) == "table" and tree[i].command == command then
      return table.remove(tree, i)
    end
  end
end

styles.defineStyle("partition", {}, {
  paragraph = { skipafter = "smallskip", breakbefore=false,
                align = "center" },
})
styles.defineStyle("partition:caption", { inherit = "sectioning:base" }, {
  font = { style = "italic", size = "-0.5" },
  paragraph = { indentbefore = false, skipbefore = "smallskip",
                align = "center",
                breakafter = false, skipafter = "smallskip" },
  sectioning = { counter = "partitions", level = 1, display = "arabic",
                 toclevel = 7, bookmark = false,
                },
})

SILE.registerCommand("partition", function (options, content)
  if type(content) ~= "table" then SU.error("Expected a table content in partition") end
  local caption = extractFromTree(content, "caption")

  options.style = "partition:caption"
  if caption then
    SILE.call("sectioning", options, caption)
  end
  SILE.call("style:apply:paragraph", { name = "partition" }, content)
end, "Insert a partition.")

-- Redefine the ptable:cell:hook no-op command to do something
SILE.registerCommand("ptable:cell:hook", function(options, content)
  if options.style == "center" then
    SILE.call("center", {}, content)
  elseif options.style == "narrow" then
    SILE.settings.temporarily(function ()
      SILE.settings.set("document.parindent", SILE.nodefactory.glue())
      SILE.settings.set("current.parindent", SILE.nodefactory.glue())
      SILE.call("style:font", { size = "-0.5" }, content)
      SILE.call("par")
    end)
  else
    SILE.process(content)
  end
end)

-- Theatrical environment stuff
SILE.registerCommand("stage", function(options, content)
    SILE.call("style:apply:paragraph", { name = options.name }, content)
end)

SILE.doTexlike([[%
\style:define[name=speaker]{
   \font[features=+smcp]
   \paragraph[skipbefore=smallskip, indentbefore=false, breakafter=false, indentafter=true, align=center]
}%
\define[command=speaker]{\stage[name=speaker]{\process}}%
\style:define[name=didaskalia]{
   \font[style=italic, size=-0.5]
   \paragraph[indentbefore=false, breakafter=false, indentafter=true, align=center]
}%
\define[command=didaskalia]{\stage[name=didaskalia]{\process}}%
]])

-- "Choose You Own Adventure gamebook-like sections
SILE.registerCommand("gamebook", function (options, content)
  options.style = "sectioning:gamebook"
  SILE.call("sectioning", options, content)
end, "Begin a new chapter.")
SILE.registerCommand("goto", function (options, content)
  local marker = SU.required(options, "marker", "goto")
  SILE.call("font", { weight=700 }, function()
    SILE.call("ref", { marker = marker })
  end)
end)
SILE.doTexlike([[%
\style:define[name=sectioning:gamebook:number]{}%
\style:define[name=sectioning:gamebook]{%
  \font[weight=700]
  \paragraph[skipbefore=medskip,align=center]
  \sectioning[counter=gamebook,level=1,display=arabic, numberstyle=sectioning:gamebook:number,
    toclevel=9, bookmark=false]
}%
]])

-- Messy environment wrappers
SILE.doTexlike([[%
\define[command=oldbookwrapper]{%
\begin[family=Caslon Antique]{font}
% HACK. SILE is wrong on so many ways...
\set[parameter=shaper.spaceenlargementfactor, value=1.0]
% And so we must also recompute our French mess. DARN.
\set[parameter=languages.fr.guillspace, value=0.8spc plus 0.15spc minus 0.2666666spc]%
\set[parameter=languages.fr.thinspace, value=0.5spc]%
\set[parameter=languages.fr.colonspace, value=1spc plus 0.5spc minus 0.3333333spc]%
\process
\end{font}}%
%
\define[command=colophonwrapper]{%
\font[family=Cardinal Alternate, size=11pt]{%
\colophon[decoration=true,figure=decorative, ratio=1.03]{%
\set[parameter=linebreak.emergencyStretch, value=0.5em]{%
% HACK. SILE is wrong on so many ways...
\set[parameter=shaper.spaceenlargementfactor, value=1.0]%
% And so we must also recompute our French mess. DARN.
\set[parameter=languages.fr.guillspace, value=0.8spc plus 0.15spc minus 0.2666666spc]%
\set[parameter=languages.fr.thinspace, value=0.5spc]%
\set[parameter=languages.fr.colonspace, value=1spc plus 0.5spc minus 0.3333333spc]%
\process}}}}
]])
