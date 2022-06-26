SILE.defaultTypesetter.computeLineRatio = function(_, breakwidth, slice)
  -- This somewhat wrong, see #1362.
  -- This is a very partial workaround, at least made consistent with the
  -- nnode outputYourself routine expectation (which is somewhat wrong too)
  local naturalTotals = SILE.length()

  local n = #slice
  while n > 1 do
    if slice[n].is_glue or slice[n].is_zero then
      if slice[n].value ~= "margin" then
        naturalTotals:___sub(slice[n].width)
      end
    elseif slice[n].is_discretionary then
      slice[n].used = true
      if slice[n].parent then
        slice[n].parent.hyphenated = true
      end
      naturalTotals:___sub(slice[n]:replacementWidth())
      naturalTotals:___add(slice[n]:prebreakWidth())
      slice[n].height = slice[n]:prebreakHeight()
      break
    else
      break
    end
    n = n - 1
  end

  local seenNodes = {}
  local skipping = true
  for i, node in ipairs(slice) do
    if node.is_box then
      skipping = false
      if node.parent and not node.parent.hyphenated then
        if not seenNodes[node.parent] then
          naturalTotals:___add(node.parent:lineContribution())
        end
        seenNodes[node.parent] = true
      else
        naturalTotals:___add(node:lineContribution())
      end
    elseif node.is_penalty and node.penalty == -10000 then -- inf_bad
      skipping = false
    elseif node.is_discretionary then
      skipping = false
      if node.used then
        naturalTotals:___add(node:replacementWidth())
        slice[i].height = slice[i]:replacementHeight():absolute()
      end
    elseif not skipping then
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
  -- Here a previous comment said: TODO: See bug 620
  -- But the latter seems to suggest capping the ratio if greater than 1, which is wrong.
  ratio = math.max(ratio, -1)
  return ratio, naturalTotals
end

SILE.typesetter.computeLineRatio = SILE.defaultTypesetter.computeLineRatio
