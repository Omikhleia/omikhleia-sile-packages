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
\script[src=packages/redefine]
\script[src=packages/autodoc-extras]

The \doc:keyword{redefine} package can be used to easily redefine a command under a new name.

Sometimes one may want to redefine a command (e.g. a font switching hook for some other
command, etc.), but would also want to restore the initial command definition afterwards
at some point, or to invoke the original definition from the newly redefined one.

This package is just some sort of quick “hack” in order to do it in an easy way from within
a document in SILE language. It is far from perfect,
it likely has implications if users start saving and restoring commands in a disordered way, but
it can do the magic in fairly reasonable symmetric cases.

The first syntax below allows one to change the definition of command \doc:args{name} to
new \doc:args{content}, but saving the previous definition to \doc:args{saved-name}:

\begin{doc:codes}
\\redefine[command=\doc:args{name}, as=\doc:args{saved-name}]\{\doc:args{content}\}
\end{doc:codes}

From now on, invoking \doc:code{\\\doc:args{name}} will result in the new definition to be applied,
while \doc:code{\\\doc:args{save-name}} will invoke the previous definition, whatever it was.

Of course, be sure to use a unique save name: otherwise, if overwriting an existing command,
you will get a warning, at your own risks...

If invoked without \doc:args{content}, the redefinition will just define an alias to the current
command:

\begin{doc:codes}
\\redefine[command=\doc:args{name}, as=\doc:args{saved-name}]
\end{doc:codes}

The following syntax allows one to restore command \doc:args{name} to whatever was saved
in \doc:args{saved-name}, and to clear the latter:

\begin{doc:codes}
\\redefine[command=\doc:args{name}, from=\doc:args{saved-name}]
\end{doc:codes}

So now on, \doc:code{\\\doc:args{name}} is restored to whatever was saved and \doc:code{\\\doc:args{saved-name}}
is no longer defined. Again, if the saved name corresponds to some existing command in a broader
scope, things may break.
\end{document}]]
}

