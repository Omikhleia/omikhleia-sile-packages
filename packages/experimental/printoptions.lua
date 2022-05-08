--
-- Print options for professional printers
-- 2022, Didier Willis
-- License: MIT
-- Somewhat experimental...
-- Requires Inkscape and ImageMagick's convert to be available on the
-- system.
--

SILE.settings.declare({
  parameter = "printoptions.resolution",
  type = "integer or nil",
  default = nil,
  help = "If set, defines the target image resolution in dpi (dots per inch)"
})

SILE.settings.declare({
  parameter = "printoptions.rasterize",
  type = "integer",
  default = true,
  help = "When true and printoptions.resolution is set, SVG vectors are rasterized."
})

local handlePath = function (filename)
  local base = pl.path.basename(filename):match("(.+)%..+$")
  local ext = pl.path.extension(filename)
  if not base or not ext then SU.error("Cannot split path and extension in "..filename) end

  local dir = pl.path.join(pl.path.dirname(SILE.masterFilename), "converted")
  if not pl.path.exists(dir) then
    pl.path.mkdir(dir)
  end
  return pl.path.join(dir, base), ext
end

-- local imageOptimizer = function (filename)
--   -- FIXME This is for PNG only!!! Or use jpegoptim for JPEG...
--   local command = table.concat({
--     "optipng",
--     filename,
--     "-o7",
--     "-i0", -- no interlacing
--     "-full",
--   }, " ")

--   local result = os.execute(command)
--   if type(result) ~= "boolean" then result = (result == 0) end
--   if result then
--     SU.debug("printoptions", "Optimized "..filename)
--   end
--   return filename
-- end

local imageResolutionConverter = function (filename, width, resolution)
  local base, ext = handlePath(filename)
  local targetFilename = base .. "-img"..width.."_"..resolution..ext

  local sourceTime = pl.path.getmtime(filename)
  if sourceTime == nil then
    SU.debug("printoptions", "Source file not found "..filename)
    return nil
  end

  local targetTime = pl.path.getmtime(targetFilename)
  if targetTime ~= nil and targetTime > sourceTime then
    SU.debug("printoptions", "Source file already converted "..filename)
    return targetFilename
  end

  local command = table.concat({
    "convert",
    filename,
    "-units PixelsPerInch",
    "-resize "..width.."x\\>",
    "-density "..resolution,
    "-background white",
    "-flatten",
    "-colorspace LinearGray",
    targetFilename,
  }, " ")

  local result = os.execute(command)
  if type(result) ~= "boolean" then result = (result == 0) end
  if result then
    SU.debug("printoptions", "Converted "..filename.." to "..targetFilename)
    return targetFilename
    -- TODO: Do we need to optimize the image after resampling?
    -- In my tests it did not really improve the size of the PDF, but Most
    -- of my original (non-resampled) images were already optimized.
    -- This is also pretty slow, so we could introduce an option if this
    -- is ever wanted...
    -- return applyImageOptimization(targetFilename)
  else
    return nil
  end
end

local svgRasterizer = function (filename, width, _)
  local base, ext = handlePath(filename)
  if ext ~= ".svg" then SU.error("Expected SVG file for "..filename) end
  local targetFilename = base .. "-svg"..width..".png"

  local sourceTime = pl.path.getmtime(filename)
  if sourceTime == nil then
    SU.debug("printoptions", "Source file not found "..filename)
    return nil
  end

  local targetTime = pl.path.getmtime(targetFilename)
  if targetTime ~= nil and targetTime > sourceTime then
    SU.debug("printoptions", "Source file already converted "..filename)
    return targetFilename
  end

  -- Inkscape is better than imagemagick's convert at converting a SVG...
  -- But it handles badly the resolution...
  -- Anyway, we'll just convert to PNG and let the outputter resize the image.
  local toSvg = table.concat({
    "inkscape",
    filename,
    "-w "..width,
    "-o",
    targetFilename,
  }, " ")
  local result = os.execute(toSvg)
  if type(result) ~= "boolean" then result = (result == 0) end
  if result then
    SU.debug("printoptions", "Converted "..filename.." to "..targetFilename)
    return targetFilename
  else
    return nil
  end
end

local outputter = SILE.outputter.drawImage
SILE.outputter.drawImage = function (self, filename, x, y, width, height)
  local resolution = SILE.settings.get("printoptions.resolution")
  if resolution and resolution > 0 then
    local targetw = math.ceil(SU.cast("number", width) * resolution / 72)
    local converted = imageResolutionConverter(filename, targetw, resolution)
    if converted then
      outputter(self, converted, x, y, width, height)
      return -- We are done replacing the original image by its resampled version.
    end
    SU.warn("Resolution failure for "..filename..", using original image")
  end
  outputter(self, filename, x, y, width, height)
end

SILE.require("packages/svg") -- We do this to enforce loading the \svg command now.
  -- so our version here can replace it and not be overriden

local svg = require("svg")
local _drawSVG = function (filename, svgdata, width, height, density)
  local svgfigure, svgwidth, svgheight = svg.svg_to_ps(svgdata, density)
  SU.debug("svg", string.format("PS: %s\n", svgfigure))
  local scalefactor = 1
  if width and height then
    -- local aspect = svgwidth / svgheight
    SU.error("SILE cannot yet change SVG aspect ratios, specify either width or height but not both")
  elseif width then
    scalefactor = width:tonumber() / svgwidth
  elseif height then
    scalefactor = height:tonumber() / svgheight
  end
  width = SILE.measurement(svgwidth * scalefactor)
  height = SILE.measurement(svgheight * scalefactor)
  scalefactor = scalefactor * density / 72

  local resolution = SILE.settings.get("printoptions.resolution")
  if resolution and resolution > 0 then
    local targetw = math.ceil(SU.cast("number", width) * resolution / 72)
    local converted = svgRasterizer(filename, targetw, resolution)
    if converted then
      SILE.require("packages/image")
      SILE.call("img", { src = converted, width = width })
      return -- We are done replacing the SVG by a raster image
    end
    SU.warn("Resolution failure for "..filename..", using original image")
  end

  SILE.typesetter:pushHbox({
      value = nil,
      height = height,
      width = width,
      depth = 0,
      outputYourself = function (self, typesetter)
        SILE.outputter:drawSVG(svgfigure, typesetter.frame.state.cursorX, typesetter.frame.state.cursorY, self.width, self.height, scalefactor)
        typesetter.frame:advanceWritingDirection(self.width)
      end
    })
end

SILE.registerCommand("svg", function (options, _)
  local fn = SU.required(options, "src", "filename")
  local width = options.width and SU.cast("measurement", options.width):absolute() or nil
  local height = options.height and SU.cast("measurement", options.height):absolute() or nil
  local density = options.density or 72
  local svgfile = io.open(fn)
  local svgdata = svgfile:read("*all")
  _drawSVG(fn, svgdata, width, height, density)
end)

return {
  documentation = [[\begin{document}
This experimental package provide a few settings that allow tuning
image resolution and vector rasterization, as often requested by
professional printers and print-on-demand services.

The \autodoc:setting{printoptions.resolution} setting, when set to an integer
value, defines the expected image resolution in dpi (dots per inch).
It could be set to 300 or 600 for final offset print or, say, to 150
or lower for a low-resolution PDF for reviewers and proofreaders.
Not only images are resampled to the target resolution (if they have
a higher resolution), but they are also converted to grayscale and
flattened with a white background. (Most professional printers require
the PDF to be flattened without transparency, which is not addressed here,
but the assumption here is that you might check what could happen
if transparency is improperly managed by your printer and/or you have
layered contents incorrectly ordered.)

The \autodoc:setting{printoptions.rasterize} setting defaults to true. If a
target image resolution is defined and this setting is left enabled,
then vector images are rasterized. It currently applies to SVG files,
redefining the \autodoc:command{\svg} command.

Converted images are placed in a \doc:code{converted} folder besides
the master file. Be cautious not having images with the same base filename
in different folders, to avoid conflicts!

The package requires Inkscape and ImageMagick's convert to be available
on your system.
\end{document}]]
}