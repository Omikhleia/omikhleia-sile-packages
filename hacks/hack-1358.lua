SILE.nodeMakers.unicode.handleWordBreak = function (self, item)
  -- self:makeToken() -- <---------------- HACK DIDIER REMOVED #1358
  if self:isSpace(item.text) then
    -- Spacing word break
    self:makeToken() -- <-------------- HACK DIDIER MOVED HERE #1358
    self:makeGlue(item)
  else -- a word break which isn't a space
    self:addToken(item.text, item)
  end
end
