local function init(class, _)
  if SILE.version < "v0.13.0" then
    SILE.require("packages/image")
    SILE.require("packages/converters")
    SILE.doTexlike([[%
\converters:register[from=.dot,to=.png,command=dot -Tpng -Gdpi=300 $SOURCE -o$TARGET]
]])
  else
    class:loadPackage("image")
    class:loadPackage("converters")
    class:registerPostinit(function()
      SILE.doTexlike([[%
\converters:register[from=.dot,to=.png,command=dot -Tpng -Gdpi=300 $SOURCE -o$TARGET]
]])
    end)
  end
end

SILE.scratch.xformat = SILE.scratch.xformat or {}

local function registerCommands(_)
  SILE.registerRawHandler("dot", function(options, content)
    local dotstuff = content[1]
    local ix = (SILE.scratch.xformat.count or 0) + 1
    -- FIXME perhaps use real temporary files, not the hack here
    local tmpname = SILE.masterFilename .. "_converted_" .. ix .. '.dot'
    SILE.scratch.xformat.count = ix
  
    local fd, err = io.open(tmpname, "w")
    if not fd then return SU.error(err) end
    fd:write(dotstuff)
    fd:flush()
    fd:close()
    SILE.call("img", {
      src = tmpname,
      width = options.width,
      height = options.height
    })
    local status, err = os.remove(tmpname)
    if not status then return SU.warn(err) end
  end)
end

if SILE.version < "v0.13.0" then
  local class = SILE.documentState.documentClass
  registerCommands(class)
end

return {
  init = init,
  registerCommands = registerCommands,
  documentation = [[\begin{document}
Quick and dirty DOT support.
\end{document}]]
}
