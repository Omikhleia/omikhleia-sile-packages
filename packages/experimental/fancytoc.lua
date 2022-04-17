--
-- Experimental fancy table of contents.
-- Only processed parts (level 0) and chapter (level 1) and display
-- them as some braced content.
--
local loadToc = SILE.documentState.documentClass.loadToc
if not loadToc then
  SU.error("The class does not export TOC loading")
end

local linkWrapper = function (dest, func)
  if dest and SILE.Commands["pdf:link"] then
    SILE.call("pdf:link", { dest = dest }, func)
  else
    func()
  end
end

SILE.registerCommand("tableofcontents", function (options, _)
  -- local depth = SU.cast("integer", options.depth or 1)
  -- local start = SU.cast("integer", options.start or 0)
  local linking = SU.boolean(options.linking, true)

  local toc = loadToc()
  if toc == false then
    SILE.call("tableofcontents:notocmessage")
    return
  end

  -- Temporarilly kill footnotes and labels (fragile)
  local oldFt = SILE.Commands["footnote"]
  SILE.Commands["footnote"] = function () end
  local oldLbl = SILE.Commands["label"]
  SILE.Commands["label"] = function () end

  local root = {}
  for i = 1, #toc do
    local item = toc[i]
    local level = item.level
    if level == 0 then
      root[#root + 1] = { item = item, children = {} }
    elseif level == 1 then
      local current = root[#root]
      if current then
        current.children[#current.children +1] = item
      end
    end
  end

  SILE.settings.temporarily(function()
    SILE.settings.set("current.parindent", SILE.nodefactory.glue())
    SILE.settings.set("document.parindent", SILE.nodefactory.glue())

    -- Quick and dirty for now...
    for _, v in ipairs(root) do
      SILE.call("medskip")
      SILE.call("parbox", { valign = "middle", width = "20%lw" }, function ()
        SILE.call("raggedright", {}, function ()
          SILE.call("font", { features="+smcp" }, v.item.label)
        end)
      end)
      SILE.call("hfill")
      SILE.call("bracebox", { bracewidth = "0.8em"}, function()
        SILE.call("parbox", { valign = "middle", width = "75%lw" }, function ()
          for _, c in ipairs(v.children) do
            SILE.call("parbox", { valign = "top", strut = "rule", minimize = true, width = "80%lw" }, function ()
              SILE.settings.set("document.lskip", SILE.length("1em"))
              SILE.settings.set("document.rskip", SILE.nodefactory.hfillglue())
              SILE.settings.set("document.parindent", SILE.length("-0.5em"))
              SILE.process(c.label)
            end)
            SILE.call("dotfill")
            linkWrapper(linking and c.link, function ()
              SILE.call("font", { features = "+onum"}, { c.pageno })
              --SILE.typesetter:typeset(c.pageno)
            end)
            SILE.call("par")
          end
        end)
      end)
      SILE.call("par")
    end
  end)

  SILE.Commands["footnote"] = oldFt
  SILE.Commands["label"] = oldLbl
end, "Output the table of contents.")
