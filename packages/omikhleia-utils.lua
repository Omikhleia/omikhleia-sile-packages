--
-- Utilities common to my packages for SILE
-- Omikhleia, 2021
-- License: MIT
--
-- This file is not intended to be used directly in SILE documents
-- and should be "required()" from packages needing it!

-- FIXME based on SILE.findInTree, but it seems bad to have it here
-- (We should not have to bother knowing the low level AST)
omikhleia = {}

omikhleia.extractFromTree = function (tree, command)
  for i=1, #tree do
    if type(tree[i]) == "table" and tree[i].command == command then
      return table.remove(tree, i)
      -- FIXME Just in case, shouldn't we check the command appears more than once in the tree
      -- and issue an error or warning?
    end
  end
end

