--
-- An epigraph package for SILE
-- Omikhleia, 2021
-- License: MIT
-- 
SILE.require("packages/rules")
local styles = SILE.require("packages/styles").exports
SILE.require("packages/omikhleia-utils")

SILE.settings.declare({
    parameter = "epigraph.beforeskipamount",
    type = "vglue",
    default = SILE.settings.get("plain.medskipamount"),
    help = "Vertical offset before an epigraph (defaults to a medium skip)."
  })

SILE.settings.declare({
    parameter = "epigraph.afterskipamount",
    type = "vglue",
    default = SILE.settings.get("plain.bigskipamount"),
    help = "Vertical offset after an epigraph (defaults to a big skip)."
  })

SILE.settings.declare({
    parameter = "epigraph.sourceskipamount",
    type = "vglue",
    default = SILE.settings.get("plain.smallskipamount"),
    help = "Vertical offset betwen an epigraph text and its source (defaults to a small skip)."
  })

SILE.settings.declare({
    parameter = "epigraph.parindent",
    type = "glue",
    default = SILE.settings.get("document.parindent"),
    help = "Paragraph identation in an epigraph (defaults to document paragraph indentation)."
  })

SILE.settings.declare({
    parameter = "epigraph.width",
    type = "length",
    default = SILE.length("60%lw"),
    help = "Width of an epigraph (defaults to 60% of the current line width)."
  })

SILE.settings.declare({
    parameter = "epigraph.rule",
    type = "length",
    default = SILE.length("0"),
    help = "Thickness of the rule drawn below an epigraph text (defaults to 0, meaning no rule)."
  })

SILE.settings.declare({
    parameter = "epigraph.align",
    type = "string",
    default = "right",
    help = "Position of an epigraph in the frame (right or left, defaults to right)."
  })

SILE.settings.declare({
    parameter = "epigraph.ragged",
    type = "boolean",
    default = false,
    help = "Whether an epigraph is ragged (defaults to false)."
  })

styles.defineStyle("epigraph:style", {}, { font = { size = -1 } })
styles.defineStyle("epigraph:source:style", {}, { font = { style="italic" } })

SILE.registerCommand("epigraph:font", function (_, _)
  SILE.call("font", { size = SILE.settings.get("font.size") - 1 })
end, "Font used for an epigraph")

SILE.registerCommand("epigraph:source:font", function (_, _)
  SILE.call("font", { style = "italic" })
end, "Font used for the epigraph source, if present.")

SILE.registerCommand("epigraph", function (options, content)
  SILE.settings.temporarily(function ()
    local beforeskipamount =
      options.beforeskipamount ~= nil and SU.cast("vglue", options.beforeskipamount)
      or SILE.settings.get("epigraph.beforeskipamount")
    local afterskipamount =
      options.afterskipamount ~= nil and SU.cast("vglue", options.afterskipamount)
      or SILE.settings.get("epigraph.afterskipamount")
    local sourceskipamount =
      options.sourceskipamount ~= nil and SU.cast("vglue", options.sourceskipamount)
      or SILE.settings.get("epigraph.sourceskipamount")
    local parindent =
      options.parindent ~= nil and SU.cast("glue", options.parindent)
      or SILE.settings.get("epigraph.parindent")
    local width =
      options.width ~= nil and SU.cast("length", options.width)
      or SILE.settings.get("epigraph.width")
    local rule =
      options.rule ~= nil and SU.cast("length", options.rule)
      or SILE.settings.get("epigraph.rule")
    local align =
      options.align ~= nil and SU.cast("string", options.align)
      or SILE.settings.get("epigraph.align")
    local ragged =
      options.ragged ~= nil and SU.cast("boolean", options.ragged)
      or SILE.settings.get("epigraph.ragged")

    local framew = SILE.typesetter.frame:width()
    local epigraphw = width:absolute()
    local skip = framew - epigraphw
    local source = omikhleia.extractFromTree(content, "source")
    SILE.typesetter:leaveHmode()
    SILE.typesetter:leaveHmode()
    SILE.typesetter:pushVglue(beforeskipamount)

    local l = ragged
      and SILE.length(skip, 1e10) -- some real huge strech
      or SILE.length({ length = skip }) 
    local glue = SILE.nodefactory.glue({ width = l })
    if align == "left" then
      SILE.settings.set("document.rskip", glue)
      SILE.settings.set("document.lskip", 0)
    else
      SILE.settings.set("document.lskip", glue)
      SILE.settings.set("document.rskip", 0)
    end 
 
    SILE.settings.set("document.parindent", parindent)
    SILE.call("style:apply", { name = "epigraph:style" }, function()
    SILE.process(content)
    if rule:tonumber() ~= 0 then
      SILE.typesetter:leaveHmode()
      SILE.call("noindent")
      SILE.call("raise", { height = "0.5ex" }, function ()
          SILE.call("hrule", {width = epigraphw, height = rule })
        end)
    end
    if source then
      SILE.typesetter:leaveHmode(1)
      if rule:tonumber() == 0 then
        SILE.typesetter:pushVglue(sourceskipamount)
      end
      SILE.call("style:apply", { name = "epigraph:source:style" }, function()
        SILE.call("raggedleft", {}, source)
      end)
    end
end)
    SILE.typesetter:leaveHmode()
    SILE.typesetter:pushVglue(afterskipamount)
  end)
end, "Displays an epigraph.")

return {
  documentation = [[\begin{document}
    \include[src=packages/epigraph-doc.sil]
  \end{document}]]
}

