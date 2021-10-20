
SILE.doTexlike([[%
\define[command=doc:keyword]{\font[family=Libertinus Sans, weight=600]{\process}}
\define[command=doc:code]{\font[family=Libertinus Sans, weight=600]{\process}}
\define[command=doc:codes]{\par\smallskip\doc:code{\process}\par\smallskip}
\define[command=doc:args]{⟨\em{\process}\kern[width=0.1em]⟩}
]])

SILE.require("packages/url")

local oldCode = SILE.Commands["code"]
SILE.registerCommand("doc:url", function (options, content)
  -- Overidde code in URLs
  SILE.Commands["code"] = function(_, content)
    SILE.process(content)
  end

  SILE.typesetter:typeset("<")
  SILE.call("url", options, content)
  SILE.typesetter:typeset(">")

  SILE.Commands["code"] = oldCode
end)