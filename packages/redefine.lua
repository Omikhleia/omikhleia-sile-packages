--
-- A command redefinition package for SILE
-- 2021, Didier Willis
-- License: MIT
--
-- Somehow a "hack", see description.
--
-- \redefine[command=command-name, as=saved-command-name]{content}
-- Or
-- \redefine[command=command-name, as=saved-command-name]
-- ...
-- \redefine[command=command-name, from=saved-command-name]
--
SILE.registerCommand("redefine", function (options, content)
  SU.required(options, "command", "redefining command")

  if options.as then
    if options.as == options.command then
      SU.error("Command " .. options.command .. " should not be redefined as itself.")
    end

    -- Case: \redefine[command=command-name, as=saved-command-name]
    if SILE.Commands[options.as] ~= nil then
      SU.warn("Command " .. options.as .. " is overwritten, are you sure? At your risks...")
    end
    local cmd = SILE.Commands[options.command]
    if cmd == nil then
      SU.error("Command " .. options.command .. " does not exist!")
    end
    SILE.Commands[options.as] = cmd

    -- Sub-case: \redefine[command=command-name, as=saved-command-name]{content}
    if content and (type(content) ~= "table" or #content ~= 0) then
      SILE.call("define", { command = options.command }, content)
    end
  elseif options.from then
    if options.from == options.command then
      SU.error("Command " .. options.command .. " should not be restored from itself, ignoring.")
    end

    -- Case \redefine[command=command-name, from=saved-command-name]
    if content and (type(content) ~= "table" or #content ~= 0) then
      SU.warn("Extraneous content in " .. options.command .. " redefinition is ignored!")
    end
    local cmd = SILE.Commands[options.from]
    if cmd == nil then
      SU.error("Command " .. options.from .. " does not exist!")
    end
    SILE.Commands[options.command] = cmd
    SILE.Commands[options.from] = nil
  else
    SU.error("Command redefinition needs a 'as' or 'from' parameter.")
  end
end, "Redefines a command saving the old version with another name, or restores it.")

return {
  documentation = [[\begin{document}
    \include[src=packages/redefine-doc.sil]
  \end{document}]]
}

