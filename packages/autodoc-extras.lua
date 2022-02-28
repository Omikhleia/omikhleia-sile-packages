
SILE.doTexlike([[%
\define[command=doc:keyword]{\font[family=Libertinus Sans, weight=600]{\process}}
\define[command=doc:code]{\font[family=Libertinus Sans, weight=600]{\process}}
\define[command=doc:codes]{\par\smallskip\doc:code{\process}\par\smallskip}
\define[command=doc:args]{⟨\em{\process}\kern[width=0.1em]⟩}
]])

SILE.require("packages/url")

local oldCode = SILE.Commands["code"]
local oldUrl = SILE.Commands["url"]
SILE.registerCommand("url", function (options, content)
  -- Kill code formatting in URLs, it's ugly.
  -- We restore the \code command afterwards, in case someone needs it however.
  SILE.Commands["code"] = function(_, content)
    SILE.process(content)
  end

  SILE.typesetter:typeset("<")
  oldUrl(options, content)
  SILE.typesetter:typeset(">")

  SILE.Commands["code"] = oldCode
end)