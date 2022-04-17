SILE.defaultTypesetter.pushGlue = function(self, spec)
  -- if SU.type(spec) ~= "table" then SU.warn("Please use pushHorizontal() to pass a premade node instead of a spec") end
  local node = SU.type(spec) == "glue" and spec or SILE.nodefactory.glue(spec)
  return self:pushHorizontal(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.defaultTypesetter.pushExplicitGlue = function(self, spec)
  local node = SU.type(spec) == "glue" and spec or SILE.nodefactory.glue(spec)
  node.explicit = true
  node.discardable = false
  return self:pushHorizontal(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.defaultTypesetter.pushVglue = function(self, spec)
  local node = SU.type(spec) == "vglue" and spec or SILE.nodefactory.vglue(spec)
  return self:pushVertical(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.defaultTypesetter.pushExplicitVglue = function(self, spec)
  local node = SU.type(spec) == "vglue" and spec or SILE.nodefactory.vglue(spec)
  node.explicit = true
  node.discardable = false
  return self:pushVertical(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.defaultTypesetter.computeLineRatio = function(_, breakwidth, slice)
  -- HACK #1362 VERY PARTIAL WORKAROUND
  -- This is not a real solution...
  -- At least be consistent with the nnode output routine, though all is wrong...
  local naturalTotals = SILE.length()
  local i = #slice
  while i > 1 do
    if slice[i].is_glue or slice[i].is_zero then
      if slice[i].value ~= "margin" then
        naturalTotals:___sub(slice[i].width)
      end
    elseif slice[i].is_discretionary then
      slice[i].used = true
      if slice[i].parent then
        slice[i].parent.hyphenated = true
      end
      naturalTotals:___sub(slice[i]:replacementWidth())
      naturalTotals:___add(slice[i]:prebreakWidth())
      slice[i].height = slice[i]:prebreakHeight()
      break
    else
      break
    end
    i = i - 1
  end

  local skipping = true
  for i, node in ipairs(slice) do

    if node.is_box then
      skipping = false

      if node.parent and not node.parent.hyphenated then
        --  print("PPP", node.parent.used)
        if not node.parent.xx then
          -- print("  PARENT", node.parent, node.parent.xx)
          naturalTotals:___add(node.parent:lineContribution())
        end
        node.parent.xx = true
      else
        -- print("   N", node)
        naturalTotals:___add(node:lineContribution())
      end
    elseif node.is_penalty and node.penalty == -10000 then -- -inf_bad
      skipping = false
    elseif node.is_discretionary then
      skipping = false
      if node.used then
        -- print("@  ", node:replacementWidth(), node:prebreakWidth())
        naturalTotals:___add(node:replacementWidth())
        slice[i].height = slice[i]:replacementHeight():absolute()
      end
      -- node.used = not node.parent.xx
    elseif not skipping then
      -- print(node)
      naturalTotals:___add(node.width)
    end
  end

  if slice[1].is_discretionary then
    naturalTotals:___sub(slice[1]:replacementWidth())
    naturalTotals:___add(slice[1]:postbreakWidth())
    slice[1].height = slice[1]:postbreakHeight()
  end
  local _left = breakwidth:tonumber() - naturalTotals:tonumber()
  local ratio = _left / naturalTotals[_left < 0 and "shrink" or "stretch"]:tonumber()
  -- TODO: See bug 620
  ratio = math.max(ratio, -1)
  return ratio
end

SILE.typesetter.pushGlue = SILE.defaultTypesetter.pushGlue
SILE.typesetter.pushExplicitGlue = SILE.defaultTypesetter.pushExplicitGlue
SILE.typesetter.pushVglue = SILE.defaultTypesetter.pushVglue
SILE.typesetter.pushExplicitVglue = SILE.defaultTypesetter.pushExplicitVglue
SILE.typesetter.computeLineRatio = SILE.defaultTypesetter.computeLineRatio
