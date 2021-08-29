--
-- A command redefinition package for SILE
-- Omikhleia, 2021
-- License: MIT
--
-- Somehow a "hack", see description at the bottom of the file.
--
-- \redefine[command=command-name, as=saved-command-name]{content}
-- ...
-- \redefine[command=command-name, from=saved-command-name}
--
SILE.registerCommand("redefine", function (options, content)
  SU.required(options, "command", "defining command")

  if options.as then
    -- Case: \redefine[command=command-name, as=saved-command-name]{content}
    if SILE.Commands[options.as] ~= nil then
      SU.warn("Command " .. options.as .. " will be overwritten, are you sure?")
    end
    local cmd = SILE.Commands[options.command]
    if cmd == nil then
      SU.error("Command " .. option.command .. "does not exist!")
    end
    SILE.Commands[options.as] = cmd
    SILE.call("define", { command = options.command }, content) 
  elseif options.from then
    -- Case \redefine[command=command-name, from=saved-command-name}
    if content and type(content) == "table" and #content ~= 0 then
      SU.warn("Extraneous content in " .. options.command .. " redefinition is ignored!")
    end
    local cmd = SILE.Commands[options.from]
    if cmd == nil then
      SU.error("Command " .. option.from .. "does not exist!")
    end
    SILE.Commands[options.command] = cmd
    SILE.Commands[options.from] = nil
  else
    SU.error("Command redefinition needs a 'as' or 'from' parameter.")
  end
end, "Redefines a command saving the old version with another name, or restore it")

return {
  documentation = [[
  \begin{document}
    This package can be used to redefine a command under a new name.

    Sometimes one wants to redefine a command (e.g. a font swiching
    hook for some other command, etc.) but would also want to
    restore the initial command definition afterwards, or invoke
    the original definition from the newly redefined one.

    I didn't find a standard way for doing this, so ended up with this
    small "hack" package, that allows keeping the old definition
    under a new user-defined name, and later restoring
    it (clearing the saved version).
  \end{document}]]
}

