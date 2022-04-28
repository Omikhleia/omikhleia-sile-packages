--
-- EAN-13 barcodes for SILE.
-- Didier Willis, 2022.
-- License: MIT
--
SILE.require("packages/rules")
SILE.require("packages/raiselower")

-- https://tug.org/TUGboat/Articles/tb15-4/tb45olsa.pdf
-- https://tsukurimashou.osdn.jp/ocr.php.en (Matthew Skala, July 1, 2021)

-- Tables for encoding the EAN-13 bars
-- See e.g. https://tug.org/TUGboat/Articles/tb15-4/tb45olsa.pdf for inspiration.
local tableA = { "3211", "2221", "2122", "1411", "1132", "1231", "1114", "1312", "1213", "3112" }
local tableB = { "1123", "1222", "2212", "1141", "2311", "1321", "4111", "2131", "3121", "2113" }
local tableSelector = { "AAAAAA", "AABABB", "AABBAB", "AABBBA", "ABAABB", "ABBAAB", "ABBBAA", "ABABAB", "ABABBA", "ABBABA" }

local ean13 = function (text)
  if type(text) ~= "string" or #text ~= 13 then SU.error("Invalid EAN-13 "..text) end
  -- TODO Here we should check consistency = it contains only digits and the control code is correct!
  local pattern = "111"
  local selector = tableSelector[tonumber(text[1]) + 1]
  for i = 2, 7 do
    local selectedTable = selector[i-1]
    local digit = tonumber(text[i]) + 1
    local pat = selectedTable == "A" and tableA[digit] or tableB[digit]
    pattern = pattern .. pat
  end
  pattern = pattern .. "11111"
  for i = 8, 13 do
    local digit = tonumber(text[i]) + 1
    local pat = tableA[digit]
    pattern = pattern .. pat
  end
  pattern = pattern .. "111"
  return pattern
end

local SC = {
  SC0 = 0.264, -- SC0 (80%)
  SC1 = 0.297, -- SC1 (90%)
  SC2 = 0.330, -- SC2 (100%) (default, recommended on a "consumer item")
  SC3 = 0.363, -- SC3 (110%)
  SC4 = 0.396, -- SC4 (120%)
  SC5 = 0.445, -- SC5 (135%)
  SC6 = 0.495, -- SC6 (150%) (minimum recommended for an "outer packaging")
  SC7 = 0.544, -- SC7 (165%)
  SC8 = 0.610, -- SC8 (185%)
  SC9 = 0.660, -- SC9 (200%) (recommended on an "outer packaging")
}

SILE.registerCommand("hrule:fixed", function (options, _) -- FIXME HACK #1382
  local width = SU.cast("length", options.width)
  local height = SU.cast("length", options.height)
  local depth = SU.cast("length", options.depth)
  SILE.typesetter:pushHbox({
    width = width:absolute(),
    height = height:absolute(),
    depth = depth:absolute(),
    value = options.src,
    outputYourself= function (self, typesetter, line)
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

SILE.registerCommand("ean13", function (options, _)
  local code = SU.required(options, "code", "valid EAN-13 code")
  local scale = options.scale or "SC2"
  local module = SC[scale]
  if not module then SU.error("Invalid EAN scale (SC0 to SC9): "..scale) end
  local pattern = ean13(code)
  local X = SILE.length(module.."mm")
  local H = 69.242424242 -- As per the standard, a minimal 22.85mm at standard X
  local hb = SILE.call("hbox", {}, function()
    SILE.call("kern", { width = 11 * X }) -- Quiet zone left = minimal 11X
    for i = 1, #pattern do
      local sz = tonumber(pattern[i]) * X
      if i%2 == 0 then
        -- space
        SILE.call("kern", { width = sz })
      else
        -- bar
        local numline = (i+1)/2
        local d = 0
        if numline == 1 or numline == 2 or numline == 15 or numline == 16 or numline == 29 or numline == 30 then
          d = 5 -- longer bars are 5X higher than shorter bars
        end
        SILE.call("hrule:fixed", { height = H * X, depth = d * X, width = sz }) -- bar
      end
    end
    -- The recommended typeface for the human readable interpretation is OCR-B
    -- at a height of 2.75mm at standard X
    -- Only an approximation here: we assume the font size corresponds to 9X...
    -- And honestly the kerning is somewhat random too, just good-looking with
    -- Matthew Skala's OCR B font.
    SILE.call("font", { family = "OCR B", size = X * 9 }, function()
      SILE.call("lower", { height = 8.3333 * X }, function()
        SILE.call("kern", { width = -103 * X })
        SILE.call("hbox", {}, { code[1] }) -- first digit
        SILE.call("kern", { width = 6.5 * X })
        SILE.call("hbox", {}, { code:sub(2,7) }) -- first sequence
        SILE.call("kern", { width = 6.5 * X })
        SILE.call("hbox", {}, { code:sub(8,13) }) -- last sequence
        SILE.call("kern", { width = 6.5 * X })
        local l = SILE.call("hbox", {}, { ">" }) -- closing bracket
        l.width = SILE.length() -- width cancelled not to affect the quiet right zone
      end)
    end)
    SILE.call("kern", { width = 7 * X }) -- Quiet zone right = minimal 7X
  end)
  -- Barcode height (including the number) = according to the standard, 25.93mm at standard X
  -- It means there's 9.3333X below the bars but we already took 5X for the longer bars.
  hb.depth = hb.depth + (4.3333) * X
end, "Typesets an EAN-13 barcode.")

return {
  documentation = [[\begin{document}
The \autodoc:package{barcodes/ean13} package allows to print out an EAN-13 barcode, suitable
for an ISBN (or ISSN, etc.)

The \autodoc:command{\ean13} command takes a mandatody \autodoc:parameter{code} parameter,
the numerical value of the EAN-13 code (without dashes and with its final control digit).
It checks its consistency and displays the corresponding barcode. By default, it uses the
recommended scale for a “consumer item” (SC2, with a “module” of 0.33mm). The size
can be changed by setting the \autodoc:parameter{scale} option to any of the standard
scales from SC0 to SC9. For the record, SC6 is the minimum recommended scale for an
“outer packaging” (SC9 being the default recommended scale for it).

The human readable interpretation below the barcode expects the font to be OCR-B. A free
implementation of this font is Matthew Skala’s July 2021 version,
at \url{https://tsukurimashou.osdn.jp/ocr.php.en}, recommended for use with this package.

Here is it in action \ean13[code=9782953989663, scale=SC0] at scale SC0…

…so you can see how it shows up with respect to the current baseline.

\end{document}]]
}
