local getSpaceGlue = function(options, parameter) -- DIDIER HACK #1360
  local sg
  if SILE.settings.get("languages.fr.debugspace") then
    sg = SILE.nodefactory.kern("5spc")
  else
    sg = SILE.settings.get(parameter)
  end
  -- Return the absolute (kern) length of the specified spacing parameter
  -- with a particular set of font options.
  -- As for SILE.shapers.base.measureSpace(), which has the same type of
  -- logic, caching this doesn't seem to have any significant speedup.
  SILE.settings.temporarily(function ()
    SILE.settings.set("font.size", options.size)
    SILE.settings.set("font.family", options.family)
    SILE.settings.set("font.filename", options.filename)
    sg = sg:absolute()
  end)
  return sg
end

SILE.nodeMakers.fr.makeUnbreakableSpace = function (self, parameter)
  self:makeToken()
  self.lastnode = "glue"
  coroutine.yield(getSpaceGlue(self.options, parameter)) -- DIDIER HACK #1360
end
