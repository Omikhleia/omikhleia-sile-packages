SILE.require("packages/rules")
SILE.registerCommand("hrule", function(options, _) -- FIXME HACK #1382
  local width = SU.cast("length", options.width)
  local height = SU.cast("length", options.height)
  local depth = SU.cast("length", options.depth)
  SILE.typesetter:pushHbox({
    width = width:absolute(),
    height = height:absolute(),
    depth = depth:absolute(),
    value = options.src,
    outputYourself = function(self, typesetter, line)
      local outputWidth = SU.rationWidth(self.width, self.width, line.ratio)
      typesetter.frame:advancePageDirection(-self.height)
      local oldx = typesetter.frame.state.cursorX
      local oldy = typesetter.frame.state.cursorY
      typesetter.frame:advanceWritingDirection(outputWidth)
      typesetter.frame:advancePageDirection(self.height + self.depth)
      local newx = typesetter.frame.state.cursorX
      local newy = typesetter.frame.state.cursorY
      SILE.outputter:drawRule(oldx, oldy, newx - oldx, newy - oldy)
      typesetter.frame:advancePageDirection(-self.depth) --- DARN HERE IS A FIX FOR #1382
    end
  })
end, "Creates a rectangular blob of ink of width <width>, height <height> and depth <depth>")
